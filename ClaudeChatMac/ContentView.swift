import SwiftUI

struct ContentView: View {
  @StateObject private var claudeService = ClaudeService()
  @State private var inputText = ""
  @State private var showWelcome = true
  
  var body: some View {
    ZStack {
      Color(NSColor.windowBackgroundColor)
        .ignoresSafeArea()
      
      if showWelcome && claudeService.messages.isEmpty {
        welcomeView
      } else {
        chatView
      }
    }
  }
  
  var welcomeView: some View {
    VStack(spacing: 30) {
      VStack(spacing: 8) {
        Text("⚡️ FRIDAY RAISES $15M SEED FUNDING")
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
          Text("Launch It.")
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
            Text("Sign in to Generate")
              .font(.system(size: 13, weight: .medium))
              .foregroundColor(.white)
              .padding(.horizontal, 20)
              .padding(.vertical, 8)
              .background(Color.blue)
              .cornerRadius(6)
          }
          .buttonStyle(.plain)
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
        
        TextField("Ask Claude anything...", text: $inputText, axis: .vertical)
          .textFieldStyle(.plain)
          .font(.system(size: 14))
          .lineLimit(1...6)
          .disabled(claudeService.isProcessing)
          .onSubmit {
            sendMessage()
          }
        
        Button(action: sendMessage) {
          Image(systemName: claudeService.isProcessing ? "stop.circle.fill" : "arrow.up.circle.fill")
            .font(.system(size: 24))
            .foregroundColor(inputText.isEmpty ? Color(NSColor.tertiaryLabelColor) : .blue)
        }
        .buttonStyle(.plain)
        .disabled(inputText.isEmpty && !claudeService.isProcessing)
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
