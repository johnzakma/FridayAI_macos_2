import Foundation

class ClaudeService: ObservableObject {
  @Published var messages: [Message] = []
  @Published var isProcessing = false
  
  private var process: Process?
  private var inputPipe = Pipe()
  private var outputPipe = Pipe()
  
  init() {
    startBackendProcess()
  }
  
  func startBackendProcess() {
    process = Process()
    
    guard let nodePath = findNodePath() else {
      print("Node.js not found")
      return
    }
    
    let backendPath = Bundle.main.resourcePath! + "/../../../backend/claude-server.js"
    
    process?.executableURL = URL(fileURLWithPath: nodePath)
    process?.arguments = [backendPath]
    process?.standardInput = inputPipe
    process?.standardOutput = outputPipe
    
    outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      if data.count > 0, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        DispatchQueue.main.async {
          self?.handleResponse(json)
        }
      }
    }
    
    do {
      try process?.run()
    } catch {
      print("Failed to start Node.js process: \(error)")
    }
  }
  
  func findNodePath() -> String? {
    let paths = ["/usr/local/bin/node", "/opt/homebrew/bin/node", "/usr/bin/node"]
    return paths.first { FileManager.default.fileExists(atPath: $0) }
  }
  
  func sendMessage(_ text: String) {
    guard !text.isEmpty else { return }
    
    messages.append(Message(content: text, isUser: true, timestamp: Date()))
    isProcessing = true
    
    let query = ["type": "query", "message": text]
    if let jsonData = try? JSONSerialization.data(withJSONObject: query),
       let jsonString = String(data: jsonData, encoding: .utf8) {
      inputPipe.fileHandleForWriting.write((jsonString + "\n").data(using: .utf8)!)
    }
  }
  
  private func handleResponse(_ json: [String: Any]) {
    guard let type = json["type"] as? String else { return }
    
    switch type {
    case "chunk":
      if let text = json["text"] as? String {
        if let lastMessage = messages.last, !lastMessage.isUser {
          messages[messages.count - 1] = Message(
            content: lastMessage.content + text,
            isUser: false,
            timestamp: lastMessage.timestamp
          )
        } else {
          messages.append(Message(content: text, isUser: false, timestamp: Date()))
        }
      }
    case "complete":
      isProcessing = false
    case "error":
      isProcessing = false
      if let errorMsg = json["message"] as? String {
        messages.append(Message(content: "Error: \(errorMsg)", isUser: false, timestamp: Date()))
      }
    default:
      break
    }
  }
  
  deinit {
    process?.terminate()
  }
}
