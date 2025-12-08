import Foundation
import Darwin

struct PermissionRequest: Identifiable {
  let id: Int
  let toolName: String
  let toolInput: [String: Any]
  let description: String
  let cwd: String
}

struct RuleActionOption: Identifiable {
  enum Style: String {
    case primary
    case secondary
    case destructive
  }

  let id: String
  let label: String
  let style: Style
}

struct RulePromptData: Identifiable {
  let id: String
  let ruleId: String
  let title: String
  let message: String
  let actions: [RuleActionOption]
}

class ClaudeService: ObservableObject {
  @Published var messages: [Message] = []
  @Published var isProcessing = false
  @Published var currentSessionId: String?
  @Published var workspaceDirectory: String?
  @Published var needsDirectorySelection = true
  @Published var pendingPermission: PermissionRequest?
  @Published var pendingRulePrompt: RulePromptData?

  private var process: Process?
  private var inputPipe = Pipe()
  private var outputPipe = Pipe()
  private var rulePromptQueue: [RulePromptData] = []
  private var shouldStartNewAssistantMessage = true
  private var backendShutdownRequested = false

  init() {
    print("🚀🚀🚀 NEW CODE IS RUNNING - VERSION 3.0 🚀🚀🚀")
    signal(SIGPIPE, SIG_IGN)
  }

  func selectWorkspaceDirectory(_ path: String) {
    print("✅ Workspace directory selected: \(path)")
    workspaceDirectory = path
    needsDirectorySelection = false

    // Restart backend with new workspace
    if process != nil {
      backendShutdownRequested = true
      process?.terminate()
      process = nil
    }
    startBackendProcess()
  }

  func startBackendProcess() {
    guard let workspacePath = workspaceDirectory else {
      print("⚠️ No workspace directory selected, backend not started")
      return
    }
    pendingPermission = nil
    pendingRulePrompt = nil
    rulePromptQueue.removeAll()

    backendShutdownRequested = false
    process = Process()

    print("🔍 Looking for Node.js...")
    guard let nodePath = findNodePath() else {
      print("❌ Node.js not found after checking all locations")
      return
    }

    print("✅ Will use Node.js at: \(nodePath)")

    let backendPath = Bundle.main.resourcePath! + "/backend/claude-server.js"

    // Check if backend file exists
    if !FileManager.default.fileExists(atPath: backendPath) {
      print("❌ Backend file not found at: \(backendPath)")
      return
    }

    print("✅ Starting backend process...")
    print("   Node path: \(nodePath)")
    print("   Backend path: \(backendPath)")
    print("   Node file exists: \(FileManager.default.fileExists(atPath: nodePath))")

    inputPipe = Pipe()
    outputPipe = Pipe()

    process?.executableURL = URL(fileURLWithPath: nodePath)
    process?.arguments = [backendPath]
    process?.standardInput = inputPipe
    process?.standardOutput = outputPipe

    // Also capture stderr for error logging
    let errorPipe = Pipe()
    process?.standardError = errorPipe

    errorPipe.fileHandleForReading.readabilityHandler = { handle in
      let data = handle.availableData
      if data.count > 0, let errorString = String(data: data, encoding: .utf8) {
        print("⚠️ Backend error: \(errorString)")
      }
    }

    // Pass ANTHROPIC_API_KEY to Node.js process
    var environment = ProcessInfo.processInfo.environment
    if let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] {
      print("✅ API key found (length: \(apiKey.count))")
      environment["ANTHROPIC_API_KEY"] = apiKey
    } else {
      print("❌ ANTHROPIC_API_KEY not set!")
    }

    // Add node binary directory to PATH so child processes can find node
    let nodeDir = (nodePath as NSString).deletingLastPathComponent
    if let existingPath = environment["PATH"] {
      environment["PATH"] = "\(nodeDir):\(existingPath)"
    } else {
      environment["PATH"] = "\(nodeDir):/usr/local/bin:/usr/bin:/bin"
    }
    print("✅ Set PATH to: \(environment["PATH"] ?? "unknown")")

    // Set the workspace path
    environment["FRIDAY_WORKSPACE"] = workspacePath
    print("✅ Set workspace to: \(workspacePath)")

    process?.environment = environment

    outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      if data.count > 0 {
        if let outputString = String(data: data, encoding: .utf8) {
          print("📥 Received from backend: \(outputString)")
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
          DispatchQueue.main.async {
            self?.handleResponse(json)
          }
        }
      }
    }

    process?.terminationHandler = { [weak self] proc in
      DispatchQueue.main.async {
        self?.handleBackendTermination(status: proc.terminationStatus, reason: proc.terminationReason)
      }
    }

    do {
      try process?.run()
      print("✅ Backend process started (PID: \(process?.processIdentifier ?? 0))")
    } catch {
      print("❌ Failed to start Node.js process: \(error)")
    }
  }
  
  func findNodePath() -> String? {
    // Try to find node via login shell (which loads .bashrc, .zshrc, etc.)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["-l", "-c", "which node"]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
      try process.run()
      process.waitUntilExit()

      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      if let output = String(data: data, encoding: .utf8) {
        let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !path.isEmpty && FileManager.default.fileExists(atPath: path) {
          print("✅ Found node at: \(path)")
          return path
        } else {
          print("⚠️ 'which node' returned: \(output)")
        }
      }
    } catch {
      print("⚠️ Failed to run 'which node': \(error)")
    }

    // Try common paths as fallback
    let commonPaths = [
      "/usr/local/bin/node",
      "/opt/homebrew/bin/node",
      "/usr/bin/node",
      "\(NSHomeDirectory())/.nvm/versions/node/v22.17.0/bin/node"
    ]

    for path in commonPaths {
      if FileManager.default.fileExists(atPath: path) {
        print("✅ Found node at common path: \(path)")
        return path
      }
    }

    print("❌ Could not find node in any location")
    return nil
  }
  
  func sendMessage(_ text: String) {
    guard !text.isEmpty else { return }

    print("📤 Sending message: \(text)")
    messages.append(Message(content: text, isUser: true, timestamp: Date()))
    shouldStartNewAssistantMessage = true
    isProcessing = true

    guard process?.isRunning == true else {
      print("❌ Backend process not running; prompting for workspace restart")
      messages.append(Message(
        content: "Backend is unavailable. Please reselect a workspace to restart it.",
        isUser: false,
        timestamp: Date(),
        messageType: .assistant
      ))
      isProcessing = false
      needsDirectorySelection = true
      return
    }

    // Include session_id if we have one for conversation continuity
    var query: [String: Any] = ["type": "query", "message": text]
    if let sessionId = currentSessionId {
      query["session_id"] = sessionId
      print("📤 Continuing session: \(sessionId)")
    } else {
      print("📤 Starting new session")
    }

    if let jsonData = try? JSONSerialization.data(withJSONObject: query),
       let jsonString = String(data: jsonData, encoding: .utf8) {
      print("📤 JSON sent: \(jsonString)")
      inputPipe.fileHandleForWriting.write((jsonString + "\n").data(using: .utf8)!)
    }
  }

  func startNewConversation() {
    print("🆕 Starting new conversation")
    currentSessionId = nil
    messages.removeAll()
    pendingPermission = nil
    pendingRulePrompt = nil
    rulePromptQueue.removeAll()
    shouldStartNewAssistantMessage = true

    // Notify backend to clear its session
    let command = ["type": "new_session"]
    if let jsonData = try? JSONSerialization.data(withJSONObject: command),
       let jsonString = String(data: jsonData, encoding: .utf8) {
      inputPipe.fileHandleForWriting.write((jsonString + "\n").data(using: .utf8)!)
    }
  }

  func approvePermission(_ permissionId: Int) {
    print("✅ Approving permission \(permissionId)")
    let response = ["type": "permission_response", "permission_id": permissionId, "approved": true] as [String : Any]
    if let jsonData = try? JSONSerialization.data(withJSONObject: response),
       let jsonString = String(data: jsonData, encoding: .utf8) {
      inputPipe.fileHandleForWriting.write((jsonString + "\n").data(using: .utf8)!)
    }
    pendingPermission = nil
  }

  func denyPermission(_ permissionId: Int) {
    print("❌ Denying permission \(permissionId)")
    let response = ["type": "permission_response", "permission_id": permissionId, "approved": false] as [String : Any]
    if let jsonData = try? JSONSerialization.data(withJSONObject: response),
       let jsonString = String(data: jsonData, encoding: .utf8) {
      inputPipe.fileHandleForWriting.write((jsonString + "\n").data(using: .utf8)!)
    }
    pendingPermission = nil
  }

  private func handleResponse(_ json: [String: Any]) {
    guard let type = json["type"] as? String else {
      print("⚠️ Response missing 'type' field")
      return
    }

    print("📨 Handling response type: \(type)")

    switch type {
    case "ready":
      print("✅ Backend is ready")
    case "permission_request":
      // Handle permission request
      if let permissionId = json["permission_id"] as? Int,
         let toolName = json["tool_name"] as? String,
         let description = json["description"] as? String,
         let cwd = json["cwd"] as? String {
        print("🔐 Permission request: \(toolName)")
        let toolInput = json["tool_input"] as? [String: Any] ?? [:]
        pendingPermission = PermissionRequest(
          id: permissionId,
          toolName: toolName,
          toolInput: toolInput,
          description: description,
          cwd: cwd
        )
      }
    case "permission_cancelled":
      if let permissionId = json["permission_id"] as? Int {
        print("ℹ️ Permission \(permissionId) cancelled by backend")
      }
      pendingPermission = nil
    case "session":
      // Backend sent us the session ID
      if let sessionId = json["session_id"] as? String {
        currentSessionId = sessionId
        print("💾 Session ID saved: \(sessionId)")
      }
    case "info":
      // Log info messages from backend
      if let infoMessage = json["message"] as? String {
        print("ℹ️ Backend: \(infoMessage)")
      }
    case "rule_prompt":
      if let prompt = parseRulePrompt(json) {
        print("🧩 Rule prompt received: \(prompt.title)")
        enqueueRulePrompt(prompt)
      }
    case "rule_action_status":
      if let status = json["status"] as? String {
        let ruleId = json["rule_id"] as? String ?? "unknown"
        let actionId = json["action_id"] as? String ?? "action"
        print("🧩 Rule \(ruleId) action \(actionId) status: \(status)")
      }
    case "thinking":
      // Show thinking state
      if let content = json["content"] as? String {
        print("🧠 Thinking: \(content)")
        // Remove previous thinking message if exists
        if let lastMessage = messages.last, case .thinking = lastMessage.messageType {
          messages.removeLast()
        }
        messages.append(Message(
          content: content,
          isUser: false,
          timestamp: Date(),
          messageType: .thinking
        ))
      }
    case "tool_use":
      // Show tool use state
      if let toolName = json["tool_name"] as? String {
        let friendlyName = friendlyToolName(toolName)
        print("🔨 Using tool: \(friendlyName)")
        // Remove previous thinking message if exists
        if let lastMessage = messages.last, case .thinking = lastMessage.messageType {
          messages.removeLast()
        }

        let inputDescription: String
        if let input = json["input"] as? [String: Any] {
          inputDescription = summarizeToolInput(input)
        } else {
          inputDescription = "Processing..."
        }

        messages.append(Message(
          content: inputDescription,
          isUser: false,
          timestamp: Date(),
          messageType: .toolUse(toolName: friendlyName)
        ))
      }
    case "tool_result":
      // Show tool result state
      if let toolName = json["tool_name"] as? String {
        let isError = json["is_error"] as? Bool ?? false
        let friendlyName = friendlyToolName(toolName)
        print("✅ Tool completed: \(friendlyName), error: \(isError)")
        // Remove previous tool use message if exists
        if let lastMessage = messages.last, case .toolUse = lastMessage.messageType {
          messages.removeLast()
        }

        messages.append(Message(
          content: "",
          isUser: false,
          timestamp: Date(),
          messageType: .toolResult(toolName: friendlyName, isError: isError)
        ))
        shouldStartNewAssistantMessage = true
      }
    case "chunk":
      if let text = json["text"] as? String {
        print("📝 Received chunk: \(text.prefix(50))...")
        // Remove any state messages (thinking, tool use, tool result)
        while let lastMessage = messages.last, case .thinking = lastMessage.messageType {
          messages.removeLast()
        }
        while let lastMessage = messages.last, case .toolUse = lastMessage.messageType {
          messages.removeLast()
        }
        while let lastMessage = messages.last, case .toolResult = lastMessage.messageType {
          messages.removeLast()
        }

        let trimmed = text
        let canAppendToLastAssistant: Bool = {
          guard let lastMessage = messages.last, !lastMessage.isUser else { return false }
          if case .assistant = lastMessage.messageType {
            return true
          }
          return false
        }()

        if shouldStartNewAssistantMessage || !canAppendToLastAssistant {
          messages.append(Message(
            content: trimmed,
            isUser: false,
            timestamp: Date(),
            messageType: .assistant
          ))
        } else if let lastMessage = messages.popLast() {
          let combined = Message(
            content: lastMessage.content + trimmed,
            isUser: false,
            timestamp: lastMessage.timestamp,
            messageType: .assistant
          )
          messages.append(combined)
        }
        shouldStartNewAssistantMessage = false
      }
    case "complete":
      print("✅ Response complete")
      // Remove any remaining state messages
      while let lastMessage = messages.last,
            case .thinking = lastMessage.messageType {
        messages.removeLast()
      }
      while let lastMessage = messages.last,
            case .toolUse = lastMessage.messageType {
        messages.removeLast()
      }
      while let lastMessage = messages.last,
            case .toolResult = lastMessage.messageType {
        messages.removeLast()
      }

      // Handle complete responses that have a result field
      if let result = json["result"] as? String {
        print("📝 Received complete result: \(result.prefix(100))...")
        // Check if we already have a message from chunks, if not create new one
        if let lastMessage = messages.last, !lastMessage.isUser, !lastMessage.content.isEmpty {
          // Already have content from chunks, don't overwrite
          print("   (Already have message content from chunks)")
        } else {
          // No chunks received, this is the complete response
          messages.append(Message(
            content: result,
            isUser: false,
            timestamp: Date(),
            messageType: .assistant
          ))
        }
      }
      isProcessing = false
      shouldStartNewAssistantMessage = true
    case "error":
      print("❌ Error from backend")
      isProcessing = false
      shouldStartNewAssistantMessage = true
      if let errorMsg = json["message"] as? String {
        print("   Error message: \(errorMsg)")
        messages.append(Message(
          content: "Error: \(errorMsg)",
          isUser: false,
          timestamp: Date(),
          messageType: .assistant
        ))
      }
    default:
      print("⚠️ Unknown response type: \(type)")
      break
    }
  }
  
  deinit {
    if process != nil {
      backendShutdownRequested = true
      process?.terminate()
    }
  }

  func performRuleAction(promptId: String, actionId: String) {
    let payload: [String: Any] = [
      "type": "rule_action",
      "prompt_id": promptId,
      "action_id": actionId
    ]
    if let jsonData = try? JSONSerialization.data(withJSONObject: payload),
       let jsonString = String(data: jsonData, encoding: .utf8) {
      inputPipe.fileHandleForWriting.write((jsonString + "\n").data(using: .utf8)!)
    }
    advanceRulePromptQueue()
  }

  private func parseRulePrompt(_ json: [String: Any]) -> RulePromptData? {
    guard
      let promptId = json["prompt_id"] as? String,
      let ruleId = json["rule_id"] as? String,
      let title = json["title"] as? String,
      let message = json["message"] as? String,
      let actionsJSON = json["actions"] as? [[String: Any]]
    else {
      return nil
    }

    let parsedActions: [RuleActionOption] = actionsJSON.compactMap { actionJSON in
      guard
        let actionId = actionJSON["id"] as? String,
        let label = actionJSON["label"] as? String
      else { return nil }
      let styleString = (actionJSON["style"] as? String)?.lowercased() ?? "primary"
      let style = RuleActionOption.Style(rawValue: styleString) ?? .primary
      return RuleActionOption(id: actionId, label: label, style: style)
    }

    guard !parsedActions.isEmpty else {
      return nil
    }

    return RulePromptData(
      id: promptId,
      ruleId: ruleId,
      title: title,
      message: message,
      actions: parsedActions
    )
  }

  private func enqueueRulePrompt(_ prompt: RulePromptData) {
    if pendingRulePrompt == nil {
      pendingRulePrompt = prompt
    } else {
      rulePromptQueue.append(prompt)
    }
  }

  private func advanceRulePromptQueue() {
    if !rulePromptQueue.isEmpty {
      pendingRulePrompt = rulePromptQueue.removeFirst()
    } else {
      pendingRulePrompt = nil
    }
  }

  private func handleBackendTermination(status: Int32, reason: Process.TerminationReason) {
    if backendShutdownRequested {
      backendShutdownRequested = false
      return
    }

    print("💥 Backend terminated (status: \(status), reason: \(reason == .uncaughtSignal ? "signal" : "exit"))")
    process = nil
    isProcessing = false
    pendingPermission = nil
    pendingRulePrompt = nil
    rulePromptQueue.removeAll()
    shouldStartNewAssistantMessage = true

    if !needsDirectorySelection {
      messages.append(Message(
        content: "The Claude backend exited (code \(status)). Please reselect your workspace to restart it.",
        isUser: false,
        timestamp: Date(),
        messageType: .assistant
      ))
      needsDirectorySelection = true
    }
  }

  private func friendlyToolName(_ raw: String) -> String {
    let lowercased = raw.lowercased()
    switch lowercased {
    case "write", "filewrite", "createfile":
      return "Writing file"
    case "fileedit", "edit":
      return "Editing file"
    case "fileread", "read":
      return "Reading file"
    case "bash":
      return "Terminal command"
    case "todowrite", "todo":
      return "Task tracker"
    case "glob":
      return "Searching files"
    case "grep":
      return "Searching content"
    default:
      return raw
    }
  }

  private func summarizeToolInput(_ input: [String: Any]) -> String {
    if let filePath = input["file_path"] as? String {
      return filePath
    }
    if let command = input["command"] as? String {
      return command
    }
    if let description = input["description"] as? String {
      return description
    }
    if let pattern = input["pattern"] as? String {
      return pattern
    }
    if let todos = input["todos"] as? [[String: Any]] {
      let total = todos.count
      let openItems = todos.filter { ($0["status"] as? String) != "completed" }.count
      return "\(total) tasks (\(openItems) open)"
    }
    if let path = input["path"] as? String {
      return path
    }
    return input.keys.joined(separator: ", ")
  }
}
