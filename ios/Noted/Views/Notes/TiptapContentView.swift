import SwiftUI

/// Renders Tiptap JSON content with interactive task checkboxes
struct TiptapContentView: View {
    let content: NoteContent
    let textColor: Color
    let accentColor: Color
    let successColor: Color
    let secondaryTextColor: Color
    var onContentChanged: ((NoteContent, String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            let nodes = tiptapNodes
            ForEach(nodes.indices, id: \.self) { i in
                renderNode(nodes[i], path: [i])
            }
        }
    }

    // MARK: - Parse

    private var tiptapNodes: [[String: Any]] {
        (content.rawJSON["content"] as? [[String: Any]]) ?? []
    }

    // MARK: - Render

    @ViewBuilder
    private func renderNode(_ node: [String: Any], path: [Int]) -> some View {
        let type = node["type"] as? String ?? ""
        let children = node["content"] as? [[String: Any]] ?? []

        switch type {
        case "paragraph":
            if children.isEmpty {
                Text("").frame(height: 4)
            } else {
                Text(inlineText(children))
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case "heading":
            let level = (node["attrs"] as? [String: Any])?["level"] as? Int ?? 1
            Text(inlineText(children))
                .font(headingFont(level))
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)

        case "bulletList":
            VStack(alignment: .leading, spacing: 2) {
                ForEach(children.indices, id: \.self) { i in
                    renderNode(children[i], path: path + [i])
                }
            }

        case "orderedList":
            VStack(alignment: .leading, spacing: 2) {
                ForEach(children.indices, id: \.self) { i in
                    renderNode(children[i], path: path + [i])
                }
            }

        case "listItem":
            HStack(alignment: .top, spacing: 4) {
                Text("\u{2022}")
                    .foregroundColor(secondaryTextColor)
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(children.indices, id: \.self) { i in
                        renderNode(children[i], path: path + [i])
                    }
                }
            }

        case "taskList":
            VStack(alignment: .leading, spacing: 4) {
                ForEach(children.indices, id: \.self) { i in
                    renderNode(children[i], path: path + [i])
                }
            }

        case "taskItem":
            let attrs = node["attrs"] as? [String: Any]
            let checked = attrs?["checked"] as? Bool ?? false
            HStack(alignment: .top, spacing: 6) {
                Button {
                    toggleTaskItem(at: path, currentlyChecked: checked)
                } label: {
                    Image(systemName: checked ? "checkmark.square.fill" : "square")
                        .font(.system(size: 16))
                        .foregroundColor(checked ? successColor : secondaryTextColor)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    ForEach(children.indices, id: \.self) { i in
                        renderNode(children[i], path: path + [i])
                            .strikethrough(checked)
                            .foregroundColor(checked ? secondaryTextColor : textColor)
                    }
                }
            }

        case "codeBlock":
            let code = children.map { $0["text"] as? String ?? "" }.joined()
            Text(code)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)

        case "blockquote":
            HStack(spacing: 8) {
                Rectangle()
                    .fill(secondaryTextColor.opacity(0.4))
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(children.indices, id: \.self) { i in
                        renderNode(children[i], path: path + [i])
                    }
                }
            }

        case "horizontalRule":
            Divider()

        default:
            if !children.isEmpty {
                ForEach(children.indices, id: \.self) { i in
                    renderNode(children[i], path: path + [i])
                }
            }
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
        var json = content.rawJSON
        guard var topNodes = json["content"] as? [[String: Any]] else { return }

        func toggle(nodes: inout [[String: Any]], remaining: ArraySlice<Int>) -> Bool {
            guard let idx = remaining.first, idx < nodes.count else { return false }
            let rest = remaining.dropFirst()

            if rest.isEmpty {
                var attrs = nodes[idx]["attrs"] as? [String: Any] ?? [:]
                attrs["checked"] = !currentlyChecked
                nodes[idx]["attrs"] = attrs
                return true
            } else {
                var children = nodes[idx]["content"] as? [[String: Any]] ?? []
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

    private func extractPlainText(from nodes: [[String: Any]]) -> String {
        nodes.map { node -> String in
            if let text = node["text"] as? String { return text }
            if let children = node["content"] as? [[String: Any]] {
                return extractPlainText(from: children)
            }
            return ""
        }.joined()
    }
}
