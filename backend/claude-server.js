import { query } from '@anthropic-ai/claude-agent-sdk';
import { createInterface } from 'readline';
import fs from 'fs';
import { promises as fsPromises } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const readline = createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

// Resolve workspace path from Swift (or fall back to ~/FridayWorkspace)
const fallbackHome = process.env.HOME || process.cwd();
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const resolvedWorkspace =
  process.env.FRIDAY_WORKSPACE || path.join(fallbackHome, 'FridayWorkspace');
const workspacePath = path.resolve(resolvedWorkspace);

// Load automation rules
const rulesFilePath = path.join(__dirname, 'rules', 'rules.json');
let automationRules = [];
try {
  const rulesRaw = fs.readFileSync(rulesFilePath, 'utf8');
  const parsedRules = JSON.parse(rulesRaw);
  if (Array.isArray(parsedRules)) {
    automationRules = parsedRules;
  } else if (Array.isArray(parsedRules.rules)) {
    automationRules = parsedRules.rules;
  } else {
    console.error('[DEBUG] rules.json is missing a rules array');
  }
} catch (error) {
  console.error(`[DEBUG] Failed to load automation rules: ${error.message}`);
}

// Ensure workspace exists so Claude can cd into it
try {
  fs.mkdirSync(workspacePath, { recursive: true });
} catch (error) {
  console.error(`[DEBUG] Failed to create workspace ${workspacePath}: ${error.message}`);
}

// Track current session ID for conversation continuity
let currentSessionId = null;

// Track pending permission requests
const pendingPermissions = new Map();
let permissionIdCounter = 0;
const handledToolUseIds = new Set();
const pendingRulePrompts = new Map();
let rulePromptCounter = 0;

const WEB_EXTENSIONS = new Set(['.html', '.css', '.scss', '.js', '.jsx', '.ts', '.tsx', '.vue', '.svelte']);
const BACKEND_EXTENSIONS = new Set(['.py', '.rb', '.go', '.rs', '.java', '.cs', '.php', '.kt', '.swift', '.ts', '.js']);

function createQueryContext(metadata = {}) {
  return {
    origin: metadata.origin || 'user',
    ruleId: metadata.ruleId || null,
    toolUses: [],
    createdFiles: [],
    detectedArtifacts: new Set(),
    fileExtensions: new Set(),
    triggeredRuleIds: new Set()
  };
}

function snapshotContext(context) {
  return {
    origin: context.origin,
    ruleId: context.ruleId,
    toolUses: context.toolUses,
    createdFiles: context.createdFiles,
    detectedArtifacts: Array.from(context.detectedArtifacts),
    fileExtensions: Array.from(context.fileExtensions)
  };
}

function recordToolUse(context, toolName, toolInput, toolUseId) {
  if (!context) return;
  const normalizedName = (toolName || 'tool').toLowerCase();
  context.toolUses.push({
    name: normalizedName,
    toolUseId: toolUseId || null,
    input: safeSerialize(toolInput)
  });
}

function classifyArtifactFromPath(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  if (WEB_EXTENSIONS.has(ext)) {
    return 'web_app';
  }
  if (BACKEND_EXTENSIONS.has(ext)) {
    if (filePath.toLowerCase().includes('server') || filePath.toLowerCase().includes('api')) {
      return 'backend_service';
    }
    return 'code';
  }
  if (filePath.toLowerCase().includes('package.json')) {
    return 'node_project';
  }
  return null;
}

function registerCreatedFile(context, filePath, toolName) {
  if (!context) return;
  context.createdFiles.push({
    path: filePath,
    toolName
  });
  const ext = path.extname(filePath).toLowerCase();
  if (ext) {
    context.fileExtensions.add(ext);
  }
  const artifact = classifyArtifactFromPath(filePath);
  if (artifact) {
    context.detectedArtifacts.add(artifact);
  }
}

function renderTemplate(template = '', data = {}) {
  if (!template) {
    return '';
  }
  return template.replace(/{{\s*([^}]+)\s*}}/g, (_, rawKey) => {
    const key = rawKey.trim();
    const value = data[key];
    if (value === undefined || value === null) {
      return '';
    }
    if (Array.isArray(value)) {
      return value.join(', ');
    }
    return String(value);
  });
}

function buildTemplateData(contextSnapshot) {
  const createdFileList = contextSnapshot.createdFiles.map((file) => {
    try {
      return path.relative(workspacePath, file.path);
    } catch {
      return file.path;
    }
  });

  const detectedArtifacts = contextSnapshot.detectedArtifacts || [];
  let artifactDescriptor = 'the project';
  if (detectedArtifacts.includes('web_app')) {
    artifactDescriptor = 'the web application';
  } else if (detectedArtifacts.includes('backend_service')) {
    artifactDescriptor = 'the backend service';
  } else if (detectedArtifacts.length > 0) {
    artifactDescriptor = `the ${detectedArtifacts[0].replace('_', ' ')}`;
  }

  return {
    createdFileCount: contextSnapshot.createdFiles.length,
    createdFileList,
    createdFilesSentence: createdFileList.join(', '),
    workspacePath,
    artifactDescriptor,
    artifactTypes: detectedArtifacts
  };
}

function renderRulePrompt(rule, templateData) {
  const prompt = rule.prompt || {};
  const title = renderTemplate(prompt.title || rule.name || 'Additional action', templateData);
  const message = renderTemplate(prompt.message || '', templateData);
  const actions = (prompt.actions || []).map((action) => ({
    id: action.id,
    label: renderTemplate(action.label || 'Continue', templateData),
    style: action.style || 'primary',
    type: action.type || 'dismiss'
  }));
  return { title, message, actions };
}

function ruleMatchesContext(rule, context) {
  if (!rule?.triggers) {
    return false;
  }
  const triggers = rule.triggers;

  if (typeof triggers.minCreatedFiles === 'number' && context.createdFiles.length < triggers.minCreatedFiles) {
    return false;
  }

  if (Array.isArray(triggers.extensions) && triggers.extensions.length > 0) {
    const hasExtension = triggers.extensions.some((ext) => context.fileExtensions.has(ext));
    if (!hasExtension) {
      return false;
    }
  }

  if (Array.isArray(triggers.requireTools) && triggers.requireTools.length > 0) {
    const toolNames = context.toolUses.map((entry) => entry.name);
    const hasRequiredTool = triggers.requireTools.some((tool) => toolNames.includes(tool.toLowerCase()));
    if (!hasRequiredTool) {
      return false;
    }
  }

  if (Array.isArray(triggers.artifactTypes) && triggers.artifactTypes.length > 0) {
    const artifacts = context.detectedArtifacts;
    const hasArtifact = triggers.artifactTypes.some((type) => artifacts.has(type));
    if (!hasArtifact) {
      return false;
    }
  }

  return true;
}

function evaluateAutomationRules(context) {
  if (!context || context.origin !== 'user' || automationRules.length === 0) {
    return [];
  }

  const results = [];
  for (const rule of automationRules) {
    if (!rule || context.triggeredRuleIds.has(rule.id)) continue;
    if (!ruleMatchesContext(rule, context)) continue;

    const snapshot = snapshotContext(context);
    const templateData = buildTemplateData(snapshot);
    const renderedPrompt = renderRulePrompt(rule, templateData);
    results.push({
      rule,
      contextSnapshot: snapshot,
      renderedPrompt,
      templateData
    });
    context.triggeredRuleIds.add(rule.id);
  }
  return results;
}

function generateRulePromptId(ruleId) {
  rulePromptCounter += 1;
  return `${ruleId || 'rule'}-${Date.now()}-${rulePromptCounter}`;
}

function safeSerialize(value, depth = 0) {
  if (depth > 5) {
    return '[truncated]';
  }
  if (
    value === null ||
    typeof value === 'string' ||
    typeof value === 'number' ||
    typeof value === 'boolean'
  ) {
    return value;
  }
  if (typeof value === 'bigint') {
    return value.toString();
  }
  if (Array.isArray(value)) {
    return value.map((item) => safeSerialize(item, depth + 1));
  }
  if (typeof value === 'object') {
    const serialized = {};
    for (const [key, nested] of Object.entries(value)) {
      serialized[key] = safeSerialize(nested, depth + 1);
    }
    return serialized;
  }
  return String(value);
}

function describeToolUse(toolName, toolInput) {
  if (!toolInput || typeof toolInput !== 'object') {
    return `Allow Claude to use ${toolName}`;
  }

  const pathHint =
    toolInput.file_path ||
    toolInput.path ||
    toolInput.destination ||
    toolInput.destination_path ||
    toolInput.target_path;

  if (pathHint) {
    return `${toolName} on ${pathHint}`;
  }

  if (toolInput.command) {
    return `${toolName}: ${String(toolInput.command).slice(0, 120)}`;
  }

  return `Allow Claude to use ${toolName}`;
}

function waitForPermissionDecision(permissionId, signal) {
  return new Promise((resolve, reject) => {
    const cleanup = () => {
      pendingPermissions.delete(permissionId);
      if (signal) {
        signal.removeEventListener('abort', abortHandler);
      }
    };

    const abortHandler = () => {
      cleanup();
      console.error(`[DEBUG] Permission ${permissionId} aborted by Claude runtime`);
      console.log(
        JSON.stringify({
          type: 'permission_cancelled',
          permission_id: permissionId
        })
      );
      reject(new Error('Permission request aborted by Claude runtime'));
    };

    pendingPermissions.set(permissionId, {
      resolve: (decision) => {
        cleanup();
        resolve(decision);
      },
      reject: (error) => {
        cleanup();
        reject(error);
      }
    });

    if (signal) {
      if (signal.aborted) {
        abortHandler();
        return;
      }
      signal.addEventListener('abort', abortHandler, { once: true });
    }
  });
}

async function handlePermissionGate({ toolName, toolInput, suggestions, signal, toolUseID }) {
  const permissionId = permissionIdCounter++;
  const serializableInput = safeSerialize(toolInput);
  const description = describeToolUse(toolName, serializableInput);

  console.error(
    `[DEBUG] Requesting permission #${permissionId} for tool ${toolName} (${description})`
  );

  console.log(
    JSON.stringify({
      type: 'permission_request',
      permission_id: permissionId,
      tool_name: toolName,
      tool_use_id: toolUseID,
      tool_input: serializableInput,
      description,
      cwd: workspacePath,
      suggestions
    })
  );

  let decision;
  try {
    decision = await waitForPermissionDecision(permissionId, signal);
  } catch (error) {
    // Claude cancelled the tool call (user doesn't need to act)
    console.error(`[DEBUG] Permission ${permissionId} aborted: ${error.message}`);
    return {
      behavior: 'deny',
      message: 'Permission request cancelled',
      interrupt: false
    };
  }

  const approved = Boolean(decision?.approved);

  if (approved) {
    const updatedInput =
      decision?.updatedInput && typeof decision.updatedInput === 'object'
        ? decision.updatedInput
        : toolInput;

    const updatedPermissions =
      Array.isArray(decision?.updatedPermissions) && decision.updatedPermissions.length > 0
        ? decision.updatedPermissions
        : Array.isArray(suggestions) && suggestions.length > 0
          ? suggestions
          : undefined;

    return {
      behavior: 'allow',
      updatedInput,
      updatedPermissions
    };
  }

  return {
    behavior: 'deny',
    message: decision?.message || 'User denied this request',
    interrupt: decision?.interrupt ?? true
  };
}

async function processQuery(userMessage, sessionId = null, metadata = {}) {
  console.error(`[DEBUG] Starting processQuery with message: ${userMessage}`);
  console.error(`[DEBUG] Workspace path: ${workspacePath}`);

  try {
    let fullResponse = '';
    let messageSessionId = null;
    const queryContext = createQueryContext(metadata);

    // Build query options
    const queryOptions = {
      model: 'claude-sonnet-4-5',
      cwd: workspacePath,  // Operate inside the selected workspace
      additionalDirectories: [workspacePath],  // Let Claude access files there
      permissionMode: 'default',
      canUseTool: (toolName, toolInput, { signal, suggestions, toolUseID }) =>
        handlePermissionGate({ toolName, toolInput, suggestions, signal, toolUseID }),
      mcpServers: {
        filesystem: {
          command: 'npx',
          args: [
            '@modelcontextprotocol/server-filesystem',
            workspacePath  // Pass workspace as allowed directory
          ],
          env: {
            ALLOWED_PATHS: workspacePath
          }
        }
      }
    };

    console.error(`[DEBUG] Query options built successfully`);

    // If we have a session ID, resume that session
    if (sessionId) {
      queryOptions.resume = sessionId;
      console.log(JSON.stringify({ type: 'info', message: `Resuming session: ${sessionId}` }));
    }

    console.error(`[DEBUG] About to call query() with prompt: "${userMessage}"`);
    console.error(`[DEBUG] Query options keys: ${Object.keys(queryOptions).join(', ')}`);

    for await (const message of query({
      prompt: userMessage,
      options: queryOptions
    })) {
      console.error(`[DEBUG] Received message in loop`);
      // Debug: Log all message types
      console.error(`[DEBUG] Message type: ${message.type}, keys: ${Object.keys(message).join(', ')}`);
      if (message.type === 'assistant' && message.message) {
        console.error(`[DEBUG] Assistant message structure: ${JSON.stringify(message.message, null, 2)}`);
      }

      // Capture session ID from any message
      if (message.session_id && !messageSessionId) {
        messageSessionId = message.session_id;
        currentSessionId = message.session_id;
        // Send session ID to Swift
        console.log(JSON.stringify({
          type: 'session',
          session_id: message.session_id
        }));
      }

      // Handle different message types
      if (message.type === 'text') {
        fullResponse += message.text;
        console.log(JSON.stringify({ type: 'chunk', text: message.text }));
      } else if (message.type === 'assistant') {
        // Assistant messages may contain tool calls
        const assistantMsg = message.message;
        if (assistantMsg && Array.isArray(assistantMsg.content)) {
          for (const content of assistantMsg.content) {
            if (content.type === 'tool_use') {
              await handleToolUsePersistence(content.name, content.input, content.id, queryContext);
              console.log(JSON.stringify({
                type: 'tool_use',
                tool_name: content.name || 'tool',
                tool_use_id: content.id,
                input: content.input
              }));
            } else if (content.type === 'text' && content.text) {
              // Stream assistant text
              fullResponse += content.text;
              console.log(JSON.stringify({ type: 'chunk', text: content.text }));
            }
          }
        } else if (assistantMsg && assistantMsg.content && typeof assistantMsg.content === 'string') {
          // Simple text content
          fullResponse += assistantMsg.content;
          console.log(JSON.stringify({ type: 'chunk', text: assistantMsg.content }));
        } else {
          // Show generic processing state for assistant messages without clear content
          console.log(JSON.stringify({
            type: 'thinking',
            content: 'Processing...'
          }));
        }
      } else if (message.type === 'thinking') {
        // Send thinking state to Swift
        console.log(JSON.stringify({
          type: 'thinking',
          content: message.thinking || message.content || 'Thinking...'
        }));
      } else if (message.type === 'tool_use') {
        // Send tool use state to Swift
        await handleToolUsePersistence(message.name, message.input, message.tool_use_id, queryContext);
        console.log(JSON.stringify({
          type: 'tool_use',
          tool_name: message.name || 'tool',
          tool_use_id: message.tool_use_id,
          input: message.input
        }));
      } else if (message.type === 'tool_result') {
        // Send tool result state to Swift
        console.log(JSON.stringify({
          type: 'tool_result',
          tool_name: message.tool_name || message.tool_use_id || 'tool',
          is_error: message.is_error || false
        }));
      } else if (message.type === 'result' && message.subtype === 'success') {
        console.log(JSON.stringify({
          type: 'complete',
          result: message.result,
          session_id: currentSessionId
        }));
        const promptedRules = evaluateAutomationRules(queryContext);
        for (const prompt of promptedRules) {
          const promptId = generateRulePromptId(prompt.rule.id);
          pendingRulePrompts.set(promptId, {
            rule: prompt.rule,
            contextSnapshot: prompt.contextSnapshot
          });
          console.log(JSON.stringify({
            type: 'rule_prompt',
            prompt_id: promptId,
            rule_id: prompt.rule.id,
            title: prompt.renderedPrompt.title,
            message: prompt.renderedPrompt.message,
            actions: prompt.renderedPrompt.actions
          }));
        }
      }
    }
  } catch (error) {
    console.error(`[DEBUG] Error in processQuery: ${error.message}`);
    console.error(`[DEBUG] Error stack: ${error.stack}`);
    console.log(JSON.stringify({ type: 'error', message: error.message }));
  }
}

// Global error handlers
process.on('uncaughtException', (error) => {
  console.error(`[FATAL] Uncaught exception: ${error.message}`);
  console.error(`[FATAL] Stack: ${error.stack}`);
  console.log(JSON.stringify({ type: 'error', message: `Fatal error: ${error.message}` }));
});

process.on('unhandledRejection', (reason, promise) => {
  console.error(`[FATAL] Unhandled rejection at:`, promise, 'reason:', reason);
  console.log(JSON.stringify({ type: 'error', message: `Unhandled rejection: ${reason}` }));
});

readline.on('line', async (line) => {
  try {
    const data = JSON.parse(line);
    if (data.type === 'query') {
      // Accept session_id from Swift for conversation continuity
      await processQuery(data.message, data.session_id || null, data.metadata || {});
    } else if (data.type === 'new_session') {
      // Start a fresh conversation
      currentSessionId = null;
      handledToolUseIds.clear();
      pendingRulePrompts.clear();
      console.log(JSON.stringify({ type: 'info', message: 'Started new conversation' }));
    } else if (data.type === 'permission_response') {
      // Handle permission response from Swift
      const permissionId = data.permission_id;
      const handler = pendingPermissions.get(permissionId);

      if (handler) {
        handler.resolve({
          approved: Boolean(data.approved),
          updatedInput: data.updated_input,
          updatedPermissions: data.updated_permissions,
          alwaysAllow: Boolean(data.always_allow),
          message: data.message,
          interrupt: data.interrupt
        });
        console.error(
          `[DEBUG] Permission ${permissionId} ${data.approved ? 'approved' : 'denied'}`
        );
      } else {
        console.error(`[DEBUG] No pending permission for id ${permissionId}`);
      }
    } else if (data.type === 'rule_action') {
      await handleRuleActionMessage(data);
    }
  } catch (error) {
    console.log(JSON.stringify({ type: 'error', message: 'Invalid input format' }));
  }
});

console.log(JSON.stringify({ type: 'ready' }));
async function handleRuleActionMessage(data) {
  const promptId = data.prompt_id;
  const actionId = data.action_id;
  if (!promptId || !actionId) {
    console.error('[DEBUG] rule_action missing prompt_id or action_id');
    return;
  }

  const pending = pendingRulePrompts.get(promptId);
  if (!pending) {
    console.error(`[DEBUG] No pending rule prompt for id ${promptId}`);
    return;
  }
  pendingRulePrompts.delete(promptId);

  const rule = pending.rule;
  const actions = rule?.prompt?.actions || [];
  const actionConfig = actions.find((action) => action.id === actionId);
  if (!actionConfig) {
    console.error(`[DEBUG] No action ${actionId} for rule ${rule?.id}`);
    return;
  }

  const baseStatus = {
    type: 'rule_action_status',
    prompt_id: promptId,
    rule_id: rule?.id || 'unknown',
    action_id: actionId
  };

  console.log(JSON.stringify({ ...baseStatus, status: 'started' }));

  if (actionConfig.type === 'followup_prompt') {
    const templateData = buildTemplateData(pending.contextSnapshot);
    const followupPrompt =
      renderTemplate(actionConfig.promptTemplate || actionConfig.prompt, templateData) ||
      '';

    if (!followupPrompt.trim()) {
      console.error(`[DEBUG] Rule ${rule?.id} has empty followup prompt`);
      console.log(JSON.stringify({ ...baseStatus, status: 'error', message: 'Rule action missing prompt' }));
      return;
    }

    try {
      await processQuery(followupPrompt, currentSessionId, {
        origin: 'rule_action',
        ruleId: rule?.id || null
      });
      console.log(JSON.stringify({ ...baseStatus, status: 'completed' }));
    } catch (error) {
      console.error(`[DEBUG] Rule action followup failed: ${error.message}`);
      console.log(JSON.stringify({ ...baseStatus, status: 'error', message: error.message }));
    }
  } else {
    console.log(JSON.stringify({ ...baseStatus, status: 'dismissed' }));
  }
}

function normalizeWorkspaceTarget(targetPath) {
  if (!targetPath || typeof targetPath !== 'string') {
    return null;
  }

  const expanded =
    targetPath.startsWith('~') && fallbackHome
      ? path.join(fallbackHome, targetPath.slice(1))
      : targetPath;
  const absolutePath = path.isAbsolute(expanded)
    ? expanded
    : path.join(workspacePath, expanded);
  const normalizedTarget = path.normalize(absolutePath);
  const normalizedWorkspace = path.normalize(workspacePath);
  const workspaceWithSep = normalizedWorkspace.endsWith(path.sep)
    ? normalizedWorkspace
    : `${normalizedWorkspace}${path.sep}`;

  if (
    normalizedTarget === normalizedWorkspace ||
    normalizedTarget.startsWith(workspaceWithSep)
  ) {
    return normalizedTarget;
  }

  throw new Error(
    `Target path ${normalizedTarget} is outside of workspace ${normalizedWorkspace}`
  );
}

async function persistFileWrite(input, queryContext) {
  const resolvedPath = normalizeWorkspaceTarget(input.file_path);
  if (!resolvedPath) {
    throw new Error('Missing file_path for FileWrite');
  }
  const dir = path.dirname(resolvedPath);
  await fsPromises.mkdir(dir, { recursive: true });
  await fsPromises.writeFile(resolvedPath, input.content ?? '', 'utf8');
  console.error(`[DEBUG] Saved file immediately: ${resolvedPath}`);
  registerCreatedFile(queryContext, resolvedPath, 'filewrite');
}

async function persistFileEdit(input, queryContext) {
  const resolvedPath = normalizeWorkspaceTarget(input.file_path);
  if (!resolvedPath) {
    throw new Error('Missing file_path for FileEdit');
  }
  const oldString = input.old_string ?? '';
  const newString = input.new_string ?? '';
  if (!oldString) {
    throw new Error('FileEdit missing old_string');
  }

  let existingContent;
  try {
    existingContent = await fsPromises.readFile(resolvedPath, 'utf8');
  } catch (error) {
    console.error(`[DEBUG] Failed to read ${resolvedPath} before edit: ${error.message}`);
    return;
  }

  let updatedContent;
  if (input.replace_all) {
    updatedContent = existingContent.split(oldString).join(newString);
  } else {
    updatedContent = existingContent.replace(oldString, newString);
  }

  if (updatedContent === existingContent) {
    console.error(
      `[DEBUG] FileEdit made no changes to ${resolvedPath} (pattern not found?)`
    );
    return;
  }

  await fsPromises.writeFile(resolvedPath, updatedContent, 'utf8');
  console.error(`[DEBUG] Applied edit immediately: ${resolvedPath}`);
  registerCreatedFile(queryContext, resolvedPath, 'fileedit');
}

async function handleToolUsePersistence(toolName, toolInput, toolUseId, queryContext) {
  if (!toolName || !toolInput) {
    return;
  }

  if (toolUseId && handledToolUseIds.has(toolUseId)) {
    return;
  }

  const normalizedName = String(toolName).toLowerCase();
  try {
    recordToolUse(queryContext, toolName, toolInput, toolUseId);
    if (
      normalizedName === 'filewrite' ||
      normalizedName === 'write' ||
      normalizedName === 'createfile'
    ) {
      if (toolInput.file_path && typeof toolInput.content === 'string') {
        await persistFileWrite(toolInput, queryContext);
        if (toolUseId) handledToolUseIds.add(toolUseId);
      }
    } else if (
      normalizedName === 'fileedit' ||
      normalizedName === 'editfile' ||
      normalizedName === 'edit'
    ) {
      if (
        toolInput.file_path &&
        typeof toolInput.old_string === 'string' &&
        typeof toolInput.new_string === 'string'
      ) {
        await persistFileEdit(toolInput, queryContext);
        if (toolUseId) handledToolUseIds.add(toolUseId);
      }
    }
  } catch (error) {
    console.error(`[DEBUG] Local persistence failed for ${toolName}: ${error.message}`);
  }

  // Prevent unbounded growth
  if (handledToolUseIds.size > 500) {
    handledToolUseIds.clear();
  }
}
