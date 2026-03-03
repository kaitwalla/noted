import SwiftUI
import AppKit

@MainActor
class QuickNotePanelController: NSObject {
    static let shared = QuickNotePanelController()

    private var panel: NSPanel?
    private var viewModel = QuickNoteViewModel()
    private weak var appViewModel: AppViewModel?

    func setAppViewModel(_ vm: AppViewModel) {
        self.appViewModel = vm
    }

    func showPanel() {
        if panel == nil {
            createPanel()
        }

        viewModel.reset()

        guard let panel = panel else { return }

        // Center on screen
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let panelSize = panel.frame.size
            let x = screenRect.midX - panelSize.width / 2
            let y = screenRect.midY - panelSize.height / 2 + 100
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hidePanel() {
        panel?.orderOut(nil)
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.title = "Quick Note"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .windowBackgroundColor

        let contentView = QuickNoteView(
            viewModel: viewModel,
            appViewModel: appViewModel,
            onDismiss: { [weak self] in self?.hidePanel() }
        )

        panel.contentView = NSHostingView(rootView: contentView)

        self.panel = panel
    }
}

struct QuickNoteView: View {
    @ObservedObject var viewModel: QuickNoteViewModel
    var appViewModel: AppViewModel?
    var onDismiss: () -> Void

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.accentColor)
                Text("Quick Note")
                    .font(.headline)
                Spacer()
                if let notebook = appViewModel?.defaultNotebook {
                    HStack(spacing: 4) {
                        Image(systemName: "book.closed")
                            .font(.caption)
                        Text(notebook.title)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }

            // Text editor
            TextEditor(text: $viewModel.noteText)
                .font(.body)
                .frame(minHeight: 80, maxHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)
                .focused($isTextFieldFocused)

            // Error message
            if let error = viewModel.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // Success message
            if viewModel.showSuccess {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Note saved!")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            // Actions
            HStack {
                Text("Cmd+Return to send, Esc to cancel")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Send") {
                    sendNote()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(viewModel.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
            }
        }
        .padding(16)
        .frame(width: 400)
        .onAppear {
            isTextFieldFocused = true
        }
    }

    private func sendNote() {
        guard let notebookId = appViewModel?.defaultNotebook?.id else {
            viewModel.error = "No notebook selected"
            return
        }

        Task {
            let success = await viewModel.sendNote(to: notebookId)
            if success {
                try? await Task.sleep(nanoseconds: 500_000_000)
                onDismiss()
            }
        }
    }
}
