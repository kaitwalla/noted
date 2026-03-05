import SwiftUI
import AppKit

/// NSViewRepresentable wrapper for NSTextView with live markdown styling
struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .systemFont(ofSize: NSFont.systemFontSize)
    var textColor: NSColor = .labelColor
    var isEditable: Bool = true
    var focusTrigger: UUID? = nil
    var onCommit: (() -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = MarkdownNSTextView()
        textView.delegate = context.coordinator
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.font = font
        textView.textColor = textColor

        // Configure text container for wrapping
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        // Store reference for updates
        textView.markdownFont = font
        textView.markdownTextColor = textColor
        textView.onCommit = onCommit

        scrollView.documentView = textView

        // Unregister drag types so drops go to SwiftUI
        textView.unregisterDraggedTypes()

        // Set initial text
        if !text.isEmpty {
            textView.string = text
            textView.applyMarkdownStyling()
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? MarkdownNSTextView else { return }

        textView.markdownFont = font
        textView.markdownTextColor = textColor
        textView.isEditable = isEditable
        textView.onCommit = onCommit

        // Only update text if it changed from outside
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.applyMarkdownStyling()
            textView.selectedRanges = selectedRanges
        }

        // Focus handling - trigger when focusTrigger changes
        if let trigger = focusTrigger, trigger != context.coordinator.lastFocusTrigger {
            context.coordinator.lastFocusTrigger = trigger
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextView
        var lastFocusTrigger: UUID?
        var hasInitiallyFocused = false

        init(_ parent: MarkdownTextView) {
            self.parent = parent
            self.lastFocusTrigger = nil  // Start with nil so first update triggers focus
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? MarkdownNSTextView else { return }

            // Update binding
            parent.text = textView.string

            // Apply markdown styling
            textView.applyMarkdownStyling()
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Handle Cmd+Return for commit
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if NSEvent.modifierFlags.contains(.command) {
                    parent.onCommit?()
                    return true
                }
            }
            return false
        }
    }
}

/// Custom NSTextView subclass with markdown styling support
class MarkdownNSTextView: NSTextView {
    var markdownFont: NSFont = .systemFont(ofSize: NSFont.systemFontSize)
    var markdownTextColor: NSColor = .labelColor
    var onCommit: (() -> Void)?

    // Prevent drag and drop from inserting content
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return false
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return false
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        // Do nothing
    }

    func applyMarkdownStyling() {
        guard let textStorage = textStorage else { return }

        // Preserve cursor position
        let savedRanges = selectedRanges

        // Get styled attributed string
        let styled = MarkdownParser.attributedString(
            from: string,
            baseFont: markdownFont,
            textColor: markdownTextColor
        )

        // Apply to text storage
        textStorage.beginEditing()
        textStorage.setAttributedString(styled)
        textStorage.endEditing()

        // Restore cursor position (validate ranges first)
        let newLength = textStorage.length
        let validRanges = savedRanges.compactMap { rangeValue -> NSValue? in
            let range = rangeValue.rangeValue
            // Clamp range to valid bounds
            let location = min(range.location, newLength)
            let length = min(range.length, newLength - location)
            return NSValue(range: NSRange(location: location, length: length))
        }

        if !validRanges.isEmpty {
            self.selectedRanges = validRanges
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var text = "Hello **bold** and *italic* with `code` and ~~strikethrough~~"

        var body: some View {
            VStack {
                MarkdownTextView(text: $text)
                    .frame(height: 100)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text("Raw: \(text)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(width: 400)
        }
    }

    return PreviewWrapper()
}
