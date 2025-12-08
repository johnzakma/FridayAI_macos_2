import SwiftUI

enum MessageType {
  case user
  case assistant
  case thinking
  case toolUse(toolName: String)
  case toolResult(toolName: String, isError: Bool)
}

struct Message: Identifiable {
  let id = UUID()
  let content: String
  let isUser: Bool
  let timestamp: Date
  let messageType: MessageType

  init(content: String, isUser: Bool, timestamp: Date, messageType: MessageType? = nil) {
    self.content = content
    self.isUser = isUser
    self.timestamp = timestamp
    self.messageType = messageType ?? (isUser ? .user : .assistant)
  }
}

struct MessageView: View {
  let message: Message

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      if !message.isUser {
        iconView
      }

      VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
        contentView

        if !isStateMessage {
          Text(formatTime(message.timestamp))
            .font(.system(size: 11))
            .foregroundColor(Color(NSColor.tertiaryLabelColor))
        }
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

  @ViewBuilder
  var iconView: some View {
    switch message.messageType {
    case .thinking:
      Image(systemName: "brain")
        .font(.system(size: 16))
        .foregroundColor(.purple)
        .frame(width: 32, height: 32)
        .background(Color.purple.opacity(0.1))
        .clipShape(Circle())
    case .toolUse:
      Image(systemName: "hammer.fill")
        .font(.system(size: 16))
        .foregroundColor(.orange)
        .frame(width: 32, height: 32)
        .background(Color.orange.opacity(0.1))
        .clipShape(Circle())
    case .toolResult:
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 16))
        .foregroundColor(.green)
        .frame(width: 32, height: 32)
        .background(Color.green.opacity(0.1))
        .clipShape(Circle())
    default:
      Image(systemName: "sparkles")
        .font(.system(size: 16))
        .foregroundColor(.blue)
        .frame(width: 32, height: 32)
        .background(Color.blue.opacity(0.1))
        .clipShape(Circle())
    }
  }

  @ViewBuilder
  var contentView: some View {
    switch message.messageType {
    case .user:
      Text(message.content)
        .font(.system(size: 14))
        .foregroundColor(Color(NSColor.labelColor))
        .textSelection(.enabled)
        .padding(12)
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(Color.blue.opacity(0.1))
        )

    case .thinking:
      HStack(spacing: 8) {
        ProgressView()
          .scaleEffect(0.7)
        Text(message.content)
          .font(.system(size: 13, design: .rounded))
          .italic()
          .foregroundColor(Color(NSColor.secondaryLabelColor))
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(Color.purple.opacity(0.05))
      )

    case .toolUse(let toolName):
      HStack(spacing: 8) {
        ProgressView()
          .scaleEffect(0.7)
        VStack(alignment: .leading, spacing: 2) {
          Text("Using: \(toolName)")
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.orange)
          Text(message.content)
            .font(.system(size: 12))
            .foregroundColor(Color(NSColor.secondaryLabelColor))
        }
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(Color.orange.opacity(0.05))
      )

    case .toolResult(let toolName, let isError):
      HStack(spacing: 8) {
        Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
          .foregroundColor(isError ? .red : .green)
        Text("Completed: \(toolName)")
          .font(.system(size: 13))
          .foregroundColor(Color(NSColor.secondaryLabelColor))
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill((isError ? Color.red : Color.green).opacity(0.05))
      )

    case .assistant:
      MarkdownRenderer(text: message.content)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(Color(NSColor.controlBackgroundColor))
        )
        .textSelection(.enabled)
    }
  }

  var isStateMessage: Bool {
    switch message.messageType {
    case .thinking, .toolUse, .toolResult:
      return true
    default:
      return false
    }
  }
  
  func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }
}

private struct MarkdownRenderer: View {
  private let blocks: [MarkdownBlock]

  init(text: String) {
    self.blocks = MarkdownRenderer.parseBlocks(from: text)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ForEach(blocks) { block in
        blockView(block)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder
  private func blockView(_ block: MarkdownBlock) -> some View {
    switch block.kind {
    case .paragraph(let attributed):
      Text(attributed)
        .font(.system(size: 14))
        .foregroundColor(Color(NSColor.labelColor))
        .multilineTextAlignment(.leading)
        .lineSpacing(4)
    case .code(let language, let content):
      VStack(alignment: .leading, spacing: 6) {
        if let language, !language.isEmpty {
          Text(language.uppercased())
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(Color(NSColor.secondaryLabelColor))
        }
        ScrollView(.horizontal, showsIndicators: true) {
          Text(content)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(Color(NSColor.textColor))
            .textSelection(.enabled)
            .padding(8)
            .background(
              RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
            )
        }
      }
      .padding(4)
    case .table(let headers, let rows):
      MarkdownTableView(headers: headers, rows: rows)
    }
  }

  private static func parseBlocks(from text: String) -> [MarkdownBlock] {
    let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
    let lines = normalized.components(separatedBy: "\n")
    var blocks: [MarkdownBlock] = []
    var paragraphLines: [String] = []
    var index = 0

    func flushParagraph() {
      let combined = paragraphLines.joined(separator: "\n")
      paragraphLines.removeAll()
      guard !combined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
      let attributed = (try? AttributedString(
        markdown: combined,
        options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
      )) ?? AttributedString(combined)
      blocks.append(MarkdownBlock(kind: .paragraph(attributed)))
    }

    while index < lines.count {
      let line = lines[index]
      let trimmed = line.trimmingCharacters(in: .whitespaces)

      if trimmed.hasPrefix("```") {
        flushParagraph()
        let language = trimmed.replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespaces)
        index += 1
        var codeLines: [String] = []
        while index < lines.count && !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
          codeLines.append(lines[index])
          index += 1
        }
        if index < lines.count {
          index += 1
        }
        let codeContent = codeLines.joined(separator: "\n")
        blocks.append(MarkdownBlock(kind: .code(language: language, content: codeContent)))
        continue
      }

      if MarkdownTableParser.isTableHeader(trimmedLine: trimmed, nextLine: lines[safe: index + 1]) {
        flushParagraph()
        let (tableBlock, advancedIndex) = MarkdownTableParser.extractTable(from: lines, startingAt: index)
        blocks.append(tableBlock)
        index = advancedIndex
        continue
      }

      if trimmed.isEmpty {
        flushParagraph()
        index += 1
        continue
      }

      paragraphLines.append(line)
      index += 1
    }

    flushParagraph()
    return blocks
  }
}

private struct MarkdownBlock: Identifiable {
  enum Kind {
    case paragraph(AttributedString)
    case code(language: String?, content: String)
    case table(headers: [String], rows: [[String]])
  }

  let id = UUID()
  let kind: Kind
}

private struct MarkdownTableView: View {
  let headers: [String]
  let rows: [[String]]

  var body: some View {
    VStack(spacing: 0) {
      tableRow(headers, isHeader: true)
        .background(Color(NSColor.controlAccentColor).opacity(0.1))

      Divider()

      ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
        tableRow(row, isHeader: false)
          .background(index.isMultiple(of: 2) ? Color(NSColor.controlBackgroundColor).opacity(0.6) : Color.clear)
        if index != rows.count - 1 {
          Divider()
        }
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color(NSColor.separatorColor).opacity(0.6), lineWidth: 1)
    )
  }

  @ViewBuilder
  private func tableRow(_ values: [String], isHeader: Bool) -> some View {
    let totalColumns = max(headers.count, values.count)
    HStack(spacing: 0) {
      ForEach(0..<totalColumns, id: \.self) { index in
        let displayText = index < values.count ? values[index] : ""
        Text(displayText)
          .font(.system(size: 13, weight: isHeader ? .semibold : .regular, design: .default))
          .foregroundColor(isHeader ? Color(NSColor.labelColor) : Color(NSColor.secondaryLabelColor))
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, 6)
          .padding(.horizontal, 8)
      }
    }
  }
}

private enum MarkdownTableParser {
  static func isTableHeader(trimmedLine: String, nextLine: String?) -> Bool {
    guard trimmedLine.contains("|"),
          let nextLine = nextLine?.trimmingCharacters(in: .whitespaces),
          nextLine.range(of: #"^\s*\|?(\s*:?-+:?\s*\|)+\s*$"#, options: .regularExpression) != nil
    else {
      return false
    }
    return true
  }

  static func extractTable(from lines: [String], startingAt index: Int) -> (MarkdownBlock, Int) {
    var currentIndex = index
    let headerLine = lines[currentIndex]
    let headers = splitRow(headerLine)

    currentIndex += 2

    var rows: [[String]] = []
    while currentIndex < lines.count {
      let line = lines[currentIndex]
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.isEmpty || !trimmed.contains("|") {
        break
      }
      let parsedRow = splitRow(line)
      rows.append(padRow(parsedRow, to: headers.count))
      currentIndex += 1
    }

    let block = MarkdownBlock(kind: .table(headers: headers, rows: rows))
    return (block, currentIndex)
  }

  private static func splitRow(_ line: String) -> [String] {
    var trimmed = line.trimmingCharacters(in: .whitespaces)
    if trimmed.hasPrefix("|") {
      trimmed.removeFirst()
    }
    if trimmed.hasSuffix("|") {
      trimmed.removeLast()
    }
    return trimmed
      .components(separatedBy: "|")
      .map { $0.trimmingCharacters(in: .whitespaces) }
  }

  private static func padRow(_ row: [String], to count: Int) -> [String] {
    if row.count >= count {
      return row
    }
    var padded = row
    while padded.count < count {
      padded.append("")
    }
    return padded
  }
}

private extension Collection {
  subscript(safe index: Index) -> Element? {
    guard indices.contains(index) else { return nil }
    return self[index]
  }
}
