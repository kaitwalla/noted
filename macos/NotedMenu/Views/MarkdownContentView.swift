import SwiftUI

/// A view that renders markdown content with interactive checkboxes
struct MarkdownContentView: View {
    let text: String
    let textColor: Color
    var onCheckboxToggle: ((String) -> Void)?

    @Environment(\.themeColors) var themeColors

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(parsedLines.indices, id: \.self) { index in
                lineView(for: parsedLines[index], at: index)
            }
        }
    }

    @ViewBuilder
    private func lineView(for line: ParsedLine, at index: Int) -> some View {
        switch line {
        case .checkbox(let isChecked, let content):
            HStack(alignment: .top, spacing: 6) {
                Button {
                    toggleCheckbox(at: index)
                } label: {
                    Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                        .font(.system(size: 14))
                        .foregroundColor(isChecked ? themeColors.success : themeColors.secondaryText)
                }
                .buttonStyle(.plain)
                .help(isChecked ? "Mark as incomplete" : "Mark as complete")

                Text(parseInlineMarkdown(content, isChecked: isChecked))
                    .strikethrough(isChecked)
                    .foregroundColor(isChecked ? themeColors.secondaryText : textColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }

        case .text(let attributedString):
            Text(attributedString)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private func toggleCheckbox(at index: Int) {
        var lines = text.components(separatedBy: "\n")
        guard index < lines.count else { return }

        let line = lines[index]

        // Toggle the checkbox state
        if line.hasPrefix("- [ ] ") {
            lines[index] = "- [x] " + String(line.dropFirst(6))
        } else if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
            lines[index] = "- [ ] " + String(line.dropFirst(6))
        }

        let newText = lines.joined(separator: "\n")
        onCheckboxToggle?(newText)
    }

    // MARK: - Parsing

    private enum ParsedLine {
        case checkbox(isChecked: Bool, content: String)
        case text(AttributedString)
    }

    private var parsedLines: [ParsedLine] {
        let lines = text.components(separatedBy: "\n")
        return lines.map { line in
            if line.hasPrefix("- [ ] ") {
                return .checkbox(isChecked: false, content: String(line.dropFirst(6)))
            } else if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
                return .checkbox(isChecked: true, content: String(line.dropFirst(6)))
            } else {
                return .text(parseLine(line))
            }
        }
    }

    private func parseLine(_ line: String) -> AttributedString {
        // Check for headers
        if line.hasPrefix("### ") {
            let content = String(line.dropFirst(4))
            return parseInlineMarkdown(content, font: .headline)
        } else if line.hasPrefix("## ") {
            let content = String(line.dropFirst(3))
            return parseInlineMarkdown(content, font: .title3.bold())
        } else if line.hasPrefix("# ") {
            let content = String(line.dropFirst(2))
            return parseInlineMarkdown(content, font: .title2.bold())
        } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
            // Bullet list
            let content = String(line.dropFirst(2))
            var bullet = AttributedString("• ")
            bullet.foregroundColor = textColor
            return bullet + parseInlineMarkdown(content)
        } else {
            return parseInlineMarkdown(line)
        }
    }

    private func parseInlineMarkdown(_ text: String, font: Font = .body, isChecked: Bool = false) -> AttributedString {
        do {
            var attributed = try AttributedString(
                markdown: text,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )
            attributed.font = font
            attributed.foregroundColor = isChecked ? themeColors.secondaryText : textColor
            return attributed
        } catch {
            var attributed = AttributedString(text)
            attributed.font = font
            attributed.foregroundColor = isChecked ? themeColors.secondaryText : textColor
            return attributed
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var text = """
        # Header 1
        ## Header 2
        ### Header 3

        - [ ] Unchecked task
        - [x] Checked task
        - [ ] Another task

        - Bullet point
        * Another bullet

        Regular text with **bold** and *italic*.
        """

        var body: some View {
            VStack(alignment: .leading) {
                MarkdownContentView(
                    text: text,
                    textColor: Color.primary
                ) { newText in
                    text = newText
                }

                Divider()

                Text("Raw:")
                    .font(.caption.bold())
                Text(text)
                    .font(.caption)
                    .foregroundColor(Color.secondary)
            }
            .padding()
            .frame(width: 400)
            .environment(\.themeColors, ThemeManager.shared.colors)
        }
    }

    return PreviewWrapper()
}
