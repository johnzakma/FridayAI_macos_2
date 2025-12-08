import SwiftUI

struct ContentView: View {
  @StateObject private var claudeService = ClaudeService()
  @State private var inputText = ""
  @State private var showWelcome = true
  
  var body: some View {
    ZStack {
      Color(NSColor.windowBackgroundColor)
        .ignoresSafeArea()

      if claudeService.needsDirectorySelection {
        directoryPickerView
      } else if showWelcome && claudeService.messages.isEmpty {
        welcomeView
      } else {
        chatView
      }

      // Permission overlay
      if let permission = claudeService.pendingPermission {
        permissionOverlay(permission: permission)
      } else if let rulePrompt = claudeService.pendingRulePrompt {
        rulePromptOverlay(prompt: rulePrompt)
      }
    }
  }

  func permissionOverlay(permission: PermissionRequest) -> some View {
    ZStack {
      Color.black.opacity(0.5)
        .ignoresSafeArea()
        .onTapGesture {
          // Prevent dismissing on background tap
        }

      VStack(spacing: 20) {
        VStack(spacing: 12) {
          Image(systemName: "lock.shield")
            .font(.system(size: 48))
            .foregroundColor(.blue)

          Text("Permission Required")
            .font(.system(size: 20, weight: .semibold))

          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("Tool:")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(NSColor.secondaryLabelColor))
              Text(permission.toolName)
                .font(.system(size: 13, weight: .semibold))
            }

            HStack(alignment: .top) {
              Text("Location:")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(NSColor.secondaryLabelColor))
              VStack(alignment: .leading) {
                Text(permission.cwd)
                  .font(.system(size: 13))
                  .foregroundColor(.blue)
              }
            }

            if let input = permission.toolInput as? [String: Any], !input.isEmpty {
              VStack(alignment: .leading, spacing: 4) {
                Text("Details:")
                  .font(.system(size: 13, weight: .medium))
                  .foregroundColor(Color(NSColor.secondaryLabelColor))
                ForEach(Array(input.keys.prefix(3)), id: \.self) { key in
                  if let value = input[key] {
                    HStack {
                      Text("• \(key):")
                        .font(.system(size: 12))
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                      Text("\(String(describing: value).prefix(50))")
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(1)
                    }
                  }
                }
              }
            }
          }
          .padding()
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color(NSColor.controlBackgroundColor))
          .cornerRadius(8)
        }

        HStack(spacing: 12) {
          Button(action: {
            claudeService.denyPermission(permission.id)
          }) {
            Text("Deny")
              .font(.system(size: 14, weight: .medium))
              .foregroundColor(.red)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 10)
              .background(Color.red.opacity(0.1))
              .cornerRadius(8)
          }
          .buttonStyle(.plain)

          Button(action: {
            claudeService.approvePermission(permission.id)
          }) {
            Text("Allow")
              .font(.system(size: 14, weight: .medium))
              .foregroundColor(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 10)
              .background(Color.blue)
              .cornerRadius(8)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(24)
      .frame(maxWidth: 450)
      .background(Color(NSColor.windowBackgroundColor))
      .cornerRadius(16)
      .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
  }

  func buttonBackground(for style: RuleActionOption.Style) -> Color {
    switch style {
    case .primary:
      return Color.blue
    case .secondary:
      return Color(NSColor.controlBackgroundColor)
    case .destructive:
      return Color.red.opacity(0.15)
    }
  }

  func buttonForeground(for style: RuleActionOption.Style) -> Color {
    switch style {
    case .primary:
      return .white
    case .secondary:
      return Color(NSColor.labelColor)
    case .destructive:
      return .red
    }
  }

  func rulePromptOverlay(prompt: RulePromptData) -> some View {
    ZStack {
      Color.black.opacity(0.45)
        .ignoresSafeArea()

      VStack(spacing: 18) {
        VStack(spacing: 8) {
          Text(prompt.title)
            .font(.system(size: 20, weight: .semibold))
          Text(prompt.message)
            .font(.system(size: 13))
            .foregroundColor(Color(NSColor.secondaryLabelColor))
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 4)

        VStack(spacing: 10) {
          ForEach(prompt.actions) { action in
            Button(action: {
              claudeService.performRuleAction(promptId: prompt.id, actionId: action.id)
            }) {
              Text(action.label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(buttonForeground(for: action.style))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(buttonBackground(for: action.style))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(24)
      .frame(maxWidth: 420)
      .background(Color(NSColor.windowBackgroundColor))
      .cornerRadius(16)
      .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
  }

  var directoryPickerView: some View {
    VStack(spacing: 30) {
      VStack(spacing: 16) {
        Image(systemName: "folder.badge.plus")
          .font(.system(size: 64))
          .foregroundColor(.blue)

        Text("Select Workspace Directory")
          .font(.system(size: 28, weight: .semibold))

        Text("Choose where Friday AI can read and write files.\nThis directory will be used for the current session.")
          .font(.system(size: 14))
          .foregroundColor(Color(NSColor.secondaryLabelColor))
          .multilineTextAlignment(.center)
          .padding(.horizontal, 40)
      }

      Button(action: {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select Workspace"
        panel.message = "Choose a directory where Friday AI can work"

        if panel.runModal() == .OK, let url = panel.url {
          claudeService.selectWorkspaceDirectory(url.path)
        }
      }) {
        HStack(spacing: 8) {
          Image(systemName: "folder.fill")
          Text("Choose Directory")
        }
        .font(.system(size: 15, weight: .medium))
        .foregroundColor(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.blue)
        .cornerRadius(8)
      }
      .buttonStyle(.plain)

      if let workspace = claudeService.workspaceDirectory {
        Text("Selected: \(workspace)")
          .font(.system(size: 12))
          .foregroundColor(Color(NSColor.tertiaryLabelColor))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
  
  var welcomeView: some View {
    VStack(spacing: 30) {
      VStack(spacing: 8) {
        Text("⚡️ Introducing FRIDAY AI")
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(.white)
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .background(
            Capsule()
              .fill(Color.orange.opacity(0.9))
          )
        
        Spacer().frame(height: 40)
        
        VStack(spacing: -10) {
          Text("Think It.")
            .font(.system(size: 72, weight: .light, design: .serif))
          Text("Type It.")
            .font(.system(size: 72, weight: .light, design: .serif))
          Text("Create It.")
            .font(.system(size: 72, weight: .light, design: .serif))
        }
        .foregroundColor(Color(NSColor.labelColor))
        
        Text("Build production-ready **internal tools**")
          .font(.system(size: 18, weight: .regular))
          .foregroundColor(Color(NSColor.secondaryLabelColor))
          .padding(.top, 20)
      }
      
      VStack(spacing: 12) {
        HStack(spacing: 12) {
          Image(systemName: "sparkles")
            .foregroundColor(Color(NSColor.tertiaryLabelColor))
          
          TextField("Build Idea Logger", text: $inputText)
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .onSubmit {
              sendMessage()
            }
          
          Spacer()
          
          Button(action: sendMessage) {
            Text("Generate")
              .font(.system(size: 13, weight: .medium))
              .foregroundColor(.white)
              .padding(.horizontal, 20)
              .padding(.vertical, 8)
              .background(inputText.isEmpty ? Color.gray : Color.blue)
              .cornerRadius(6)
          }
          .buttonStyle(.plain)
          .disabled(inputText.isEmpty)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
      }
      .frame(maxWidth: 700)
      .padding(.horizontal, 40)
      
      HStack(spacing: 20) {
        quickActionButton(icon: "music.note", title: "Clone Spotify")
        quickActionButton(icon: "lightbulb", title: "Idea Logger")
        quickActionButton(icon: "calendar", title: "Consult Plus")
        quickActionButton(icon: "star", title: "Surprise Me")
      }
      .padding(.top, 10)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
  
  func quickActionButton(icon: String, title: String) -> some View {
    Button(action: {
      inputText = title
      sendMessage()
    }) {
      HStack {
        Image(systemName: icon)
          .font(.system(size: 13))
        Text(title)
          .font(.system(size: 13))
      }
      .foregroundColor(Color(NSColor.secondaryLabelColor))
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(Color(NSColor.controlBackgroundColor))
      .cornerRadius(8)
    }
    .buttonStyle(.plain)
  }
  
  var chatView: some View {
    VStack(spacing: 0) {
      // Header with New Conversation button
      HStack {
        Text("Friday AI")
          .font(.system(size: 16, weight: .semibold))

        Spacer()

        if let workspace = claudeService.workspaceDirectory {
          Text("📁 \(URL(fileURLWithPath: workspace).lastPathComponent)")
            .font(.system(size: 11))
            .foregroundColor(Color(NSColor.secondaryLabelColor))
        }

        if let sessionId = claudeService.currentSessionId {
          Text("Session: \(sessionId.prefix(8))...")
            .font(.system(size: 11))
            .foregroundColor(Color(NSColor.secondaryLabelColor))
        }

        Button(action: {
          let panel = NSOpenPanel()
          panel.canChooseFiles = false
          panel.canChooseDirectories = true
          panel.allowsMultipleSelection = false
          panel.canCreateDirectories = true
          panel.prompt = "Change Workspace"
          panel.message = "Choose a new workspace directory"

          if panel.runModal() == .OK, let url = panel.url {
            claudeService.selectWorkspaceDirectory(url.path)
            claudeService.startNewConversation()
          }
        }) {
          HStack(spacing: 4) {
            Image(systemName: "folder")
            Text("Change")
          }
          .font(.system(size: 12))
          .foregroundColor(.orange)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(Color.orange.opacity(0.1))
          .cornerRadius(6)
        }
        .buttonStyle(.plain)

        Button(action: {
          claudeService.startNewConversation()
        }) {
          HStack(spacing: 4) {
            Image(systemName: "plus.circle")
            Text("New")
          }
          .font(.system(size: 12))
          .foregroundColor(.blue)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(Color.blue.opacity(0.1))
          .cornerRadius(6)
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(Color(NSColor.controlBackgroundColor))

      Divider()

      ScrollView {
        ScrollViewReader { proxy in
          VStack(spacing: 16) {
            ForEach(claudeService.messages) { message in
              MessageView(message: message)
                .id(message.id)
            }
          }
          .padding(24)
          .onChange(of: claudeService.messages.count) { _ in
            if let lastMessage = claudeService.messages.last {
              withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
              }
            }
          }
        }
      }
      
      Divider()
      
      HStack(spacing: 12) {
        Image(systemName: "sparkles")
          .foregroundColor(Color(NSColor.tertiaryLabelColor))
          .font(.system(size: 16))

        ZStack(alignment: .topLeading) {
          if inputText.isEmpty {
            Text("Ask Claude anything...")
              .font(.system(size: 14))
              .foregroundColor(Color(NSColor.placeholderTextColor))
              .padding(.leading, 4)
              .padding(.top, 8)
          }

          EnterKeyTextEditor(text: $inputText, onEnter: {
            if !inputText.isEmpty && !claudeService.isProcessing {
              sendMessage()
            }
          })
          .font(.system(size: 14))
          .frame(minHeight: 20, maxHeight: 100)
          .disabled(claudeService.isProcessing)
        }

        Button(action: sendMessage) {
          Image(systemName: claudeService.isProcessing ? "stop.circle.fill" : "arrow.up.circle.fill")
            .font(.system(size: 24))
            .foregroundColor(inputText.isEmpty ? Color(NSColor.tertiaryLabelColor) : .blue)
        }
        .buttonStyle(.plain)
        .disabled(inputText.isEmpty && !claudeService.isProcessing)
        .keyboardShortcut(.return, modifiers: [.command])
      }
      .padding(16)
      .background(Color(NSColor.controlBackgroundColor))
    }
  }
  
  func sendMessage() {
    guard !inputText.isEmpty else { return }
    showWelcome = false
    claudeService.sendMessage(inputText)
    inputText = ""
  }
}

// Custom TextEditor that handles Enter key
struct EnterKeyTextEditor: NSViewRepresentable {
  @Binding var text: String
  var onEnter: () -> Void

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSTextView.scrollableTextView()
    let textView = scrollView.documentView as! NSTextView

    textView.delegate = context.coordinator
    textView.isRichText = false
    textView.font = .systemFont(ofSize: 14)
    textView.textColor = .labelColor
    textView.backgroundColor = .clear
    textView.drawsBackground = false
    textView.isAutomaticQuoteSubstitutionEnabled = false

    return scrollView
  }

  func updateNSView(_ nsView: NSScrollView, context: Context) {
    let textView = nsView.documentView as! NSTextView
    if textView.string != text {
      textView.string = text
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  class Coordinator: NSObject, NSTextViewDelegate {
    var parent: EnterKeyTextEditor

    init(_ parent: EnterKeyTextEditor) {
      self.parent = parent
    }

    func textDidChange(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else { return }
      parent.text = textView.string
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
      if commandSelector == #selector(NSResponder.insertNewline(_:)) {
        // Check if Shift key is held
        if NSEvent.modifierFlags.contains(.shift) {
          // Insert newline
          textView.insertNewlineIgnoringFieldEditor(nil)
          return true
        } else {
          // Send message
          parent.onEnter()
          return true
        }
      }
      return false
    }
  }
}
