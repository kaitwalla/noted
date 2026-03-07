import SwiftUI
import os.log

private let logger = Logger(subsystem: "dev.kait.noted", category: "TiptapContentView")

/// Renders Tiptap JSON content with interactive task checkboxes
struct TiptapContentView: View {
    let content: NoteContent
    let plainText: String
    let textColor: Color
    var onContentChanged: ((NoteContent, String) -> Void)?

    @Environment(\.themeColors) var themeColors

    var body: some View {
        let nodes = tiptapNodes
        if nodes.isEmpty {
            if !plainText.isEmpty && plainText != "[image]" {
                Text(plainText)
                    .foregroundColor(textColor)
                    .textSelection(.enabled)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(nodes.indices, id: \.self) { i in
                    renderNode(nodes[i], path: [i])
                }
            }
        }
    }

    // MARK: - Parse

    private func childNodes(_ value: Any?) -> [[String: Any]] {
        if let arr = value as? [[String: Any]] { return arr }
        if let arr = value as? [Any] { return arr.compactMap { $0 as? [String: Any] } }
        return []
    }

    private var tiptapNodes: [[String: Any]] {
        let raw = content.rawJSON["content"]
        let nodes = childNodes(raw)
        if !nodes.isEmpty {
            // Check if these are flat paragraphs containing markdown text
            // (created via NoteContent.text() which wraps plain text in paragraphs)
            if looksLikeMarkdownInParagraphs(nodes) {
                let text = extractTextFromParagraphs(nodes)
                return parseMarkdownToNodes(text)
            }
            return nodes
        }
        // Old format: {"type": "text", "content": "markdown string"}
        if let text = raw as? String, !text.isEmpty {
            return parseMarkdownToNodes(text)
        }
        return []
    }

    /// Check if nodes are all simple paragraphs that contain markdown syntax
    private func looksLikeMarkdownInParagraphs(_ nodes: [[String: Any]]) -> Bool {
        let allParagraphs = nodes.allSatisfy { ($0["type"] as? String) == "paragraph" }
        guard allParagraphs else { return false }

        // Check if any paragraph text looks like markdown
        for node in nodes {
            let text = childNodes(node["content"]).compactMap { $0["text"] as? String }.joined()
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") || trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") ||
               trimmed.range(of: #"^\[[ xX]?\]"#, options: .regularExpression) != nil ||
               trimmed.range(of: #"^[-*]\s*\[[ xX]?\]"#, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }

    /// Extract plain text from flat paragraph nodes, joining with newlines
    private func extractTextFromParagraphs(_ nodes: [[String: Any]]) -> String {
        nodes.map { node in
            childNodes(node["content"]).compactMap { $0["text"] as? String }.joined()
        }.joined(separator: "\n")
    }

    /// Parse a plain-text markdown string into Tiptap-like node dicts
    private func parseMarkdownToNodes(_ text: String) -> [[String: Any]] {
        let lines = text.components(separatedBy: "\n")
        var nodes: [[String: Any]] = []
        var pendingTaskItems: [[String: Any]] = []
        var pendingBulletItems: [[String: Any]] = []

        func flushTasks() {
            if !pendingTaskItems.isEmpty {
                nodes.append(["type": "taskList", "content": pendingTaskItems as [Any]])
                pendingTaskItems = []
            }
        }
        func flushBullets() {
            if !pendingBulletItems.isEmpty {
                nodes.append(["type": "bulletList", "content": pendingBulletItems as [Any]])
                pendingBulletItems = []
            }
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Headings: # ## ###
            if trimmed.hasPrefix("#") {
                flushTasks(); flushBullets()
                var level = 0
                var idx = trimmed.startIndex
                while idx < trimmed.endIndex && trimmed[idx] == "#" && level < 3 {
                    level += 1
                    idx = trimmed.index(after: idx)
                }
                // Skip space after hashes
                if idx < trimmed.endIndex && trimmed[idx] == " " {
                    idx = trimmed.index(after: idx)
                }
                let title = String(trimmed[idx...])
                nodes.append([
                    "type": "heading",
                    "attrs": ["level": level] as [String: Any],
                    "content": [["type": "text", "text": title] as [String: Any]] as [Any]
                ])
                continue
            }

            // Task items: [] text, [x] text, - [] text, - [x] text
            if let match = trimmed.range(of: #"^[-*]?\s*\[([ xX]?)\]\s*(.+)$"#, options: .regularExpression) {
                flushBullets()
                let content = String(trimmed[match])
                let checked = content.contains("[x]") || content.contains("[X]")
                let textStart = content.range(of: "] ")!.upperBound
                let taskText = String(content[textStart...])
                pendingTaskItems.append([
                    "type": "taskItem",
                    "attrs": ["checked": checked] as [String: Any],
                    "content": [
                        ["type": "paragraph", "content": [["type": "text", "text": taskText] as [String: Any]] as [Any]] as [String: Any]
                    ] as [Any]
                ])
                continue
            }

            // Bullet items: - text, * text
            if let _ = trimmed.range(of: #"^[-*]\s+(.+)$"#, options: .regularExpression) {
                flushTasks()
                let textStart = trimmed.firstIndex(of: " ")!
                let bulletText = String(trimmed[trimmed.index(after: textStart)...])
                pendingBulletItems.append([
                    "type": "listItem",
                    "content": [
                        ["type": "paragraph", "content": [["type": "text", "text": bulletText] as [String: Any]] as [Any]] as [String: Any]
                    ] as [Any]
                ])
                continue
            }

            // Regular paragraph (or empty line)
            flushTasks(); flushBullets()
            if trimmed.isEmpty {
                nodes.append(["type": "paragraph", "content": [] as [Any]])
            } else {
                nodes.append([
                    "type": "paragraph",
                    "content": [["type": "text", "text": trimmed] as [String: Any]] as [Any]
                ])
            }
        }

        flushTasks(); flushBullets()
        return nodes
    }

    // MARK: - Render

    private func renderNode(_ node: [String: Any], path: [Int]) -> AnyView {
        let type = node["type"] as? String ?? ""
        let children = childNodes(node["content"])

        switch type {
        case "paragraph":
            if children.isEmpty {
                return AnyView(Text("").frame(height: 4))
            } else {
                return AnyView(
                    Text(inlineText(children))
                        .foregroundColor(textColor)
                        .textSelection(.enabled)
                )
            }

        case "heading":
            let level = (node["attrs"] as? [String: Any])?["level"] as? Int ?? 1
            return AnyView(
                Text(inlineText(children))
                    .font(headingFont(level))
                    .foregroundColor(textColor)
                    .textSelection(.enabled)
            )

        case "bulletList":
            return AnyView(VStack(alignment: .leading, spacing: 2) {
                ForEach(children.indices, id: \.self) { i in
                    renderNode(children[i], path: path + [i])
                }
            })

        case "orderedList":
            return AnyView(VStack(alignment: .leading, spacing: 2) {
                ForEach(children.indices, id: \.self) { i in
                    renderNode(children[i], path: path + [i])
                }
            })

        case "listItem":
            return AnyView(HStack(alignment: .top, spacing: 4) {
                Text("\u{2022}")
                    .foregroundColor(themeColors.secondaryText)
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(children.indices, id: \.self) { i in
                        renderNode(children[i], path: path + [i])
                    }
                }
            })

        case "taskList":
            return AnyView(VStack(alignment: .leading, spacing: 4) {
                ForEach(children.indices, id: \.self) { i in
                    renderNode(children[i], path: path + [i])
                }
            })

        case "taskItem":
            let attrs = node["attrs"] as? [String: Any]
            let checked = attrs?["checked"] as? Bool ?? false
            return AnyView(HStack(alignment: .top, spacing: 6) {
                Button {
                    toggleTaskItem(at: path, currentlyChecked: checked)
                } label: {
                    Image(systemName: checked ? "checkmark.square.fill" : "square")
                        .font(.system(size: 14))
                        .foregroundColor(checked ? themeColors.success : themeColors.secondaryText)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    ForEach(children.indices, id: \.self) { i in
                        renderNode(children[i], path: path + [i])
                            .strikethrough(checked)
                            .foregroundColor(checked ? themeColors.secondaryText : textColor)
                    }
                }
            })

        case "codeBlock":
            let code = children.map { $0["text"] as? String ?? "" }.joined()
            return AnyView(
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(themeColors.tertiaryBackground)
                    .cornerRadius(6)
                    .textSelection(.enabled)
            )

        case "blockquote":
            return AnyView(HStack(spacing: 8) {
                Rectangle()
                    .fill(themeColors.secondaryText.opacity(0.4))
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(children.indices, id: \.self) { i in
                        renderNode(children[i], path: path + [i])
                    }
                }
            })

        case "horizontalRule":
            return AnyView(Divider())

        default:
            if !children.isEmpty {
                return AnyView(VStack(alignment: .leading, spacing: 2) {
                    ForEach(children.indices, id: \.self) { i in
                        renderNode(children[i], path: path + [i])
                    }
                })
            }
            return AnyView(EmptyView())
        }
    }

    // MARK: - Inline text

    private func inlineText(_ nodes: [[String: Any]]) -> AttributedString {
        var result = AttributedString()
        for node in nodes {
            let text = node["text"] as? String ?? ""
            guard !text.isEmpty else { continue }

            var attributed = AttributedString(text)
            if let marks = node["marks"] as? [[String: Any]] {
                for mark in marks {
                    let markType = mark["type"] as? String ?? ""
                    switch markType {
                    case "bold":
                        attributed.font = .body.bold()
                    case "italic":
                        attributed.font = .body.italic()
                    case "code":
                        attributed.font = .system(.body, design: .monospaced)
                        attributed.backgroundColor = Color.secondary.opacity(0.15)
                    case "strike":
                        attributed.strikethroughStyle = .single
                    case "link":
                        if let href = (mark["attrs"] as? [String: Any])?["href"] as? String,
                           let url = URL(string: href) {
                            attributed.link = url
                        }
                    default:
                        break
                    }
                }
            }
            result += attributed
        }
        return result
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .title2.bold()
        case 2: return .title3.bold()
        case 3: return .headline
        default: return .headline
        }
    }

    // MARK: - Toggle task

    private func toggleTaskItem(at path: [Int], currentlyChecked: Bool) {
        // Old format: content is a plain string with markdown
        if let text = content.rawJSON["content"] as? String {
            toggleTaskInMarkdown(text, at: path, currentlyChecked: currentlyChecked)
            return
        }

        // Tiptap JSON format
        var json = content.rawJSON
        var topNodes = childNodes(json["content"])
        guard !topNodes.isEmpty else { return }

        func toggle(nodes: inout [[String: Any]], remaining: ArraySlice<Int>) -> Bool {
            guard let idx = remaining.first, idx < nodes.count else { return false }
            let rest = remaining.dropFirst()

            if rest.isEmpty {
                var attrs = nodes[idx]["attrs"] as? [String: Any] ?? [:]
                attrs["checked"] = !currentlyChecked
                nodes[idx]["attrs"] = attrs
                return true
            } else {
                var children = childNodes(nodes[idx]["content"])
                if toggle(nodes: &children, remaining: rest) {
                    nodes[idx]["content"] = children
                    return true
                }
                return false
            }
        }

        if toggle(nodes: &topNodes, remaining: path[...]) {
            json["content"] = topNodes
            let newContent = NoteContent(rawJSON: json)
            let newPlainText = extractPlainText(from: topNodes)
            onContentChanged?(newContent, newPlainText)
        }
    }

    /// Toggle a task checkbox in old-format markdown text
    private func toggleTaskInMarkdown(_ text: String, at path: [Int], currentlyChecked: Bool) {
        var lines = text.components(separatedBy: "\n")
        let pattern = try! NSRegularExpression(pattern: #"^[-*]?\s*\[([ xX]?)\]\s+"#)

        // The path for a taskItem inside a taskList is [taskListNodeIndex, taskItemIndex]
        // Walk parsed nodes to find which sequential task line this corresponds to
        let nodes = parseMarkdownToNodes(text)
        var targetTaskIndex = -1
        var count = 0
        outer: for (i, node) in nodes.enumerated() {
            if let type = node["type"] as? String, type == "taskList" {
                let items = childNodes(node["content"])
                for (j, _) in items.enumerated() {
                    if path == [i, j] {
                        targetTaskIndex = count
                        break outer
                    }
                    count += 1
                }
            }
        }
        guard targetTaskIndex >= 0 else { return }

        // Find and toggle the targetTaskIndex-th task line
        var taskIndex = 0
        for (lineIdx, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            if pattern.firstMatch(in: trimmed, range: range) != nil {
                if taskIndex == targetTaskIndex {
                    if currentlyChecked {
                        lines[lineIdx] = line.replacingOccurrences(of: "[x]", with: "[]", options: .caseInsensitive)
                    } else {
                        lines[lineIdx] = line.replacingOccurrences(of: "[]", with: "[x]")
                    }
                    break
                }
                taskIndex += 1
            }
        }

        let newText = lines.joined(separator: "\n")
        let newContent = NoteContent(rawJSON: ["type": "text", "content": newText])
        onContentChanged?(newContent, newText)
    }

    private func extractPlainText(from nodes: [[String: Any]]) -> String {
        nodes.map { node -> String in
            if let text = node["text"] as? String { return text }
            if let children = node["content"] as? [Any] {
                return extractPlainText(from: children.compactMap { $0 as? [String: Any] })
            }
            return ""
        }.joined()
    }
}
