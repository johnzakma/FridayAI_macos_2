# Friday AI macOS App

Native SwiftUI front-end + Node-based Claude Agent SDK backend, wrapped in a macOS experience that manages permissions, file operations, and custom automation rules.

## Project Structure & File Guide

| Path | Purpose |
| --- | --- |
| `ClaudeChatMac/` | SwiftUI macOS app (UI, process management, overlays). |
| `ClaudeChatMac/ContentView.swift` | Main UI layout (chat, overlays, directory picker). |
| `ClaudeChatMac/ClaudeService.swift` | Manages the Node subprocess, pipes JSON, tracks sessions, permissions, rule prompts. |
| `ClaudeChatMac/MessageView.swift` | Renders chat bubbles, Markdown, tool badges. Contains inline `MarkdownRenderer`. |
| `ClaudeChatMac/ClaudeChatMac.entitlements` | Sandbox configuration (user-selected read/write, networking). |
| `backend/` | Node.js agent bridge and configuration. |
| `backend/claude-server.js` | Core Node entrypoint – streams to Claude SDK, mediates permissions, evaluates rules, persists files immediately. |
| `backend/rules/rules.json` | Declarative automation rules (e.g., “Offer to run the generated app”). Add/edit rules here. |
| `backend/package.json` | Node dependencies (`@anthropic-ai/claude-agent-sdk`). |
| `build-app.sh`, `update.sh` | Utility scripts (legacy). |
| `claude_sdk_documentation.md`, `log.md`, `setup-instructions.md` | Reference material. |

### SwiftUI Layer

- **Directory selection:** `ContentView` forces the user to pick a workspace, stored in `ClaudeService.workspaceDirectory`, passed to Node via `FRIDAY_WORKSPACE`.
- **Messaging:** `ClaudeService` streams JSON lines, emits `Message` models; `MessageView` renders them with Markdown, code fences, tables, and custom tool labels.
- **Permission overlay:** triggered by `permission_request` messages (from Node permission bridge).
- **Rule overlay:** triggered by `rule_prompt` messages; buttons call `performRuleAction`, which sends `{"type":"rule_action"}` envelopes back to Node.
- **New assistant bubbles:** `shouldStartNewAssistantMessage` controls whether streamed chunks append to the current assistant message or start a new bubble after each tool.

### Node Backend

- **Process management:** `claude-server.js` reads stdin, writes stdout; each `query` message spawns a `query()` async iterator from the Claude Agent SDK.
- **Permission control:** `permissionMode: 'default'` + `canUseTool` callback emit custom `permission_request` objects. Swift approves via `permission_response`.
- **Filesystem writes:** Every `FileWrite` / `Write` / `FileEdit` tool is persisted immediately through `persistFileWrite` / `persistFileEdit`, ensuring files exist under the selected workspace even before Claude finishes.
- **Workspace safety:** `normalizeWorkspaceTarget` expands `~`, enforces absolute paths inside the user folder, and rejects anything outside.
- **Rule engine:** `automationRules` is loaded from `backend/rules/rules.json` on startup. Each rule specifies `triggers`, `prompt` text, and actions (dismiss or `followup_prompt`). After a successful turn, `evaluateAutomationRules` emits `rule_prompt` events; chosen actions optionally submit follow-up prompts to Claude.
- **Rule actions:** `handleRuleActionMessage` maps user selection → follow-up instructions (e.g., “Run the application you just built”). The new prompt runs through the same pipeline, so behavior can be extended by adding new rules rather than editing the backend.

## Setup

### Prerequisites

- macOS 13+
- Xcode + Command Line Tools (`xcode-select --install`)
- Node.js 18+
- Claude API key in your environment (`ANTHROPIC_API_KEY`)

### Installing Dependencies

```bash
cd backend
npm install
```

Swift dependencies are handled through the Xcode project (`ClaudeChatMac.xcodeproj`).

### Running

1. Open `ClaudeChatMac.xcodeproj` in Xcode.
2. Edit the run scheme → Environment Variables → add `ANTHROPIC_API_KEY`.
3. `Shift + Cmd + K` (Clean Build Folder), then `Cmd + R` to launch.
4. When prompted, pick a workspace directory – this is the only directory Claude can read/write.
5. Chat normally; accept permission prompts; when a rule prompt appears, choose the action you want (e.g., “Run application”).

## Adding / Editing Rules

1. Edit `backend/rules/rules.json`.
2. Each rule supports:
   - `id`, `name`, `description`.
   - `triggers`: `minCreatedFiles`, `extensions`, `requireTools`, `artifactTypes`, etc.
   - `prompt`: title, message, list of `actions`. Actions can be dismissals or `followup_prompt` that submits a programmatic follow-up to Claude.
3. Rebuild/restart the app—the backend picks up the JSON at launch.

Example (`backend/rules/rules.json`):

```json
{
  "id": "offer_run_generated_code",
  "triggers": {
    "minCreatedFiles": 1,
    "extensions": [".js", ".html"],
    "requireTools": ["write"]
  },
  "prompt": {
    "title": "Run the generated project?",
    "message": "I created {{createdFileCount}} file(s): {{createdFilesSentence}}...",
    "actions": [
      {
        "id": "run_generated_app",
        "style": "primary",
        "type": "followup_prompt",
        "promptTemplate": "The user wants to run {{artifactDescriptor}}..."
      },
      { "id": "skip_run", "style": "secondary", "type": "dismiss" }
    ]
  }
}
```

## Permission Flow

1. Claude attempts a tool call → `canUseTool` emits `permission_request` JSON.
2. Swift shows overlay, user chooses Allow/Deny → `permission_response`.
3. SDK resumes tool execution; writes and edits are flushed to disk immediately after the tool inputs arrive.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Files not appearing | Confirm workspace is writable (entitlements) and the Node logs show “Saved file immediately”. |
| Permission modal loops | Make sure Swift sends `permission_response` with the `permission_id` from the backend. |
| Rule prompts never appear | Ensure `backend/rules/rules.json` is valid JSON and matches triggers (check Node logs). |
| Node can’t find Claude SDK | Run `npm install` inside `backend/`. |
| No API key | Verify Xcode scheme includes `ANTHROPIC_API_KEY`. |

For deeper logs, check the Xcode console (Swift prints `📥`, `🔐`, etc.) and the Node stderr forwarded into the Swift console (`⚠️ Backend error`).

## License

MIT – see root repo for details. Feel free to adapt the Swift frontend, Node backend, or rule engine for other MCP/Claude scenarios. PRs welcome!***
