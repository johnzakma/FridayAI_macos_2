import SwiftUI

struct Message: Identifiable {
  let id = UUID()
  let content: String
  let isUser: Bool
  let timestamp: Date
}

struct MessageView: View {
  let message: Message
  
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      if !message.isUser {
        Image(systemName: "sparkles")
          .font(.system(size: 16))
          .foregroundColor(.blue)
          .frame(width: 32, height: 32)
          .background(Color.blue.opacity(0.1))
          .clipShape(Circle())
      }
      
      VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
        Text(message.content)
          .font(.system(size: 14))
          .foregroundColor(Color(NSColor.labelColor))
          .textSelection(.enabled)
          .padding(12)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(message.isUser ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
          )
        
        Text(formatTime(message.timestamp))
          .font(.system(size: 11))
          .foregroundColor(Color(NSColor.tertiaryLabelColor))
      }
      .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
      
      if message.isUser {
        Image(systemName: "person.circle.fill")
          .font(.system(size: 16))
          .foregroundColor(Color(NSColor.tertiaryLabelColor))
          .frame(width: 32, height: 32)
          .background(Color(NSColor.controlBackgroundColor))
          .clipShape(Circle())
      }
    }
  }
  
  func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }
}
