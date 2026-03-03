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
    @State private var isDragging = false

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

            // Pending images preview
            if !viewModel.pendingImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(viewModel.pendingImages.enumerated()), id: \.element.id) { index, pending in
                            ZStack(alignment: .topTrailing) {
                                Image(nsImage: pending.image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                Button {
                                    viewModel.removeImage(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.6)))
                                }
                                .buttonStyle(.plain)
                                .offset(x: 4, y: -4)
                            }
                        }

                        // Keep full size toggle
                        Toggle(isOn: $viewModel.keepFullSize) {
                            Text("Full size")
                                .font(.caption)
                        }
                        .toggleStyle(.checkbox)
                        .padding(.leading, 8)
                    }
                    .padding(.vertical, 4)
                }
            }

            // Text editor with drop support
            TextEditor(text: $viewModel.noteText)
                .font(.body)
                .frame(minHeight: 80, maxHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isDragging ? Color.accentColor : Color.clear, lineWidth: 2)
                                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: isDragging ? [5] : []))
                        )
                )
                .focused($isTextFieldFocused)
                .onDrop(of: [.image, .fileURL], isTargeted: $isDragging) { providers in
                    handleDrop(providers: providers)
                    return true
                }

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
                .disabled(!canSend || viewModel.isSending)
            }
        }
        .padding(16)
        .frame(width: 400)
        .onAppear {
            isTextFieldFocused = true
        }
    }

    private var canSend: Bool {
        !viewModel.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !viewModel.pendingImages.isEmpty
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.image") {
                provider.loadObject(ofClass: NSImage.self) { image, _ in
                    if let nsImage = image as? NSImage {
                        DispatchQueue.main.async {
                            viewModel.addImages([nsImage])
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url") { item, _ in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil),
                       let image = NSImage(contentsOf: url) {
                        DispatchQueue.main.async {
                            viewModel.addImages([image])
                        }
                    }
                }
            }
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
