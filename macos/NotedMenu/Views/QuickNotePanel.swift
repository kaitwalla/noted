import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine

// MARK: - Layout Constants

private enum QuickPanelLayout {
    /// Padding from screen edges
    static let screenEdgePadding: CGFloat = 20
    /// Extra padding for size clamping (2x edge padding)
    static let screenSizePadding: CGFloat = 40
    /// Vertical offset when centering (above center)
    static let centerVerticalOffset: CGFloat = 50
}

/// Custom panel that can become key window (required for borderless panels to accept keyboard input)
class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
class QuickNotePanelController: NSObject {
    static let shared = QuickNotePanelController()

    private var panel: NSPanel?
    private var viewModel = QuickNoteViewModel()
    private weak var appViewModel: AppViewModel?
    private var themeCancellable: AnyCancellable?

    private let frameKey = "QuickNotePanelFrame"
    private let defaultSize = NSSize(width: 500, height: 300)
    private let minSize = NSSize(width: 350, height: 200)

    func setAppViewModel(_ vm: AppViewModel) {
        self.appViewModel = vm
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    func togglePanel() {
        if isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        if panel == nil {
            createPanel()
        }

        // Clear transient state (errors, success) but preserve note content
        viewModel.clearTransientState()

        guard let panel = panel else { return }

        // Get the screen where the mouse currently is
        let mouseLocation = NSEvent.mouseLocation
        let currentScreen = NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        } ?? NSScreen.main ?? NSScreen.screens.first

        guard let screen = currentScreen else {
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let screenRect = screen.visibleFrame

        // Try to restore saved frame
        if let frameString = UserDefaults.standard.string(forKey: frameKey) {
            let savedFrame = NSRectFromString(frameString)
            // Only use saved frame if it has valid dimensions
            if savedFrame.size.width >= minSize.width && savedFrame.size.height >= minSize.height {
                var newFrame = savedFrame

                // Clamp size to fit within screen
                newFrame.size.width = min(newFrame.size.width, screenRect.width - QuickPanelLayout.screenSizePadding)
                newFrame.size.height = min(newFrame.size.height, screenRect.height - QuickPanelLayout.screenSizePadding)

                // Check if saved position is on the current screen
                let savedCenter = NSPoint(x: savedFrame.midX, y: savedFrame.midY)
                let isOnCurrentScreen = screenRect.contains(savedCenter)

                if isOnCurrentScreen {
                    // Keep position but ensure it's fully visible
                    newFrame.origin.x = max(screenRect.minX + QuickPanelLayout.screenEdgePadding,
                                            min(newFrame.origin.x, screenRect.maxX - newFrame.width - QuickPanelLayout.screenEdgePadding))
                    newFrame.origin.y = max(screenRect.minY + QuickPanelLayout.screenEdgePadding,
                                            min(newFrame.origin.y, screenRect.maxY - newFrame.height - QuickPanelLayout.screenEdgePadding))
                } else {
                    // Center on current screen
                    newFrame.origin.x = screenRect.midX - newFrame.width / 2
                    newFrame.origin.y = screenRect.midY - newFrame.height / 2 + QuickPanelLayout.centerVerticalOffset
                }

                panel.setFrame(newFrame, display: true)
            } else {
                setDefaultFrame(for: panel, in: screenRect)
            }
        } else {
            setDefaultFrame(for: panel, in: screenRect)
        }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hidePanel() {
        // Save frame before hiding
        if let panel = panel {
            let frameString = NSStringFromRect(panel.frame)
            UserDefaults.standard.set(frameString, forKey: frameKey)
        }
        panel?.orderOut(nil)
    }

    private func setDefaultFrame(for panel: NSPanel, in screenRect: NSRect) {
        let panelSize = panel.frame.size.width >= minSize.width ? panel.frame.size : defaultSize
        let clampedWidth = min(panelSize.width, screenRect.width - QuickPanelLayout.screenSizePadding)
        let clampedHeight = min(panelSize.height, screenRect.height - QuickPanelLayout.screenSizePadding)

        let x = screenRect.midX - clampedWidth / 2
        let y = screenRect.midY - clampedHeight / 2 + QuickPanelLayout.centerVerticalOffset

        panel.setFrame(NSRect(x: x, y: y, width: clampedWidth, height: clampedHeight), display: true)
    }

    func refocusPanel() {
        guard let panel = panel else { return }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createPanel() {
        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: defaultSize),
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.minSize = minSize
        panel.hasShadow = true

        let contentView = QuickNoteView(
            viewModel: viewModel,
            appViewModel: appViewModel,
            onDismiss: { [weak self] in self?.hidePanel() },
            onCancel: { [weak self] in
                self?.viewModel.reset()
                self?.hidePanel()
            }
        )
        .themed()
        .ignoresSafeArea()

        panel.contentView = NSHostingView(rootView: contentView)

        self.panel = panel

        // Observe theme changes
        themeCancellable = ThemeManager.shared.$currentTheme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePanelTheme()
            }
    }

    private func updatePanelTheme() {
        guard let panel = panel else { return }

        // Recreate content view to pick up new theme colors
        let contentView = QuickNoteView(
            viewModel: viewModel,
            appViewModel: appViewModel,
            onDismiss: { [weak self] in self?.hidePanel() },
            onCancel: { [weak self] in
                self?.viewModel.reset()
                self?.hidePanel()
            }
        )
        .themed()
        .ignoresSafeArea()

        panel.contentView = NSHostingView(rootView: contentView)
    }
}

struct QuickNoteView: View {
    @ObservedObject var viewModel: QuickNoteViewModel
    var appViewModel: AppViewModel?
    var onDismiss: () -> Void
    var onCancel: () -> Void

    @Environment(\.themeColors) var themeColors
    @State private var focusTrigger = UUID()

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                // Left: Quick Note + notebook
                HStack(spacing: 6) {
                    Image(systemName: "note.text")
                        .foregroundColor(themeColors.accent)
                    Text("Quick Note")
                        .font(.headline)
                        .foregroundColor(themeColors.text)
                    if let notebook = appViewModel?.defaultNotebook {
                        Text("→")
                            .font(.caption)
                            .foregroundColor(themeColors.secondaryText)
                        Text(notebook.title)
                            .font(.subheadline)
                            .foregroundColor(themeColors.secondaryText)
                    }
                }

                Spacer()

                // Center: Image button (also a drop target)
                Button {
                    openImagePicker()
                } label: {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 20))
                        .foregroundColor(themeColors.secondaryText)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(themeColors.tertiaryBackground)
                        )
                }
                .buttonStyle(.plain)
                .help("Add image or drop here")
                .onDrop(of: [.image, .fileURL], isTargeted: nil) { providers in
                    handleImageDrop(providers: providers)
                    return true
                }

                Spacer()

                // Right: Close button
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(themeColors.secondaryText)
                }
                .buttonStyle(.plain)
                .help("Close (keep content)")
            }
            .background {
                // Hidden button to capture Esc key for cancel action
                Button("") { onCancel() }
                    .keyboardShortcut(.escape, modifiers: [])
                    .opacity(0)
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

            // Text editor with image drop support and live markdown styling
            MarkdownTextView(
                text: $viewModel.noteText,
                font: .systemFont(ofSize: NSFont.systemFontSize),
                textColor: themeColors.nsText,
                focusTrigger: focusTrigger,
                onCommit: sendNote
            )
            .frame(minHeight: 100, maxHeight: .infinity)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeColors.tertiaryBackground)
            )
            .onDrop(of: [.image, .fileURL], isTargeted: nil) { providers in
                handleImageDrop(providers: providers)
                return true
            }

            // Error message
            if let error = viewModel.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(themeColors.error)
            }

            // Success message
            if viewModel.showSuccess {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(themeColors.success)
                    Text("Note saved!")
                        .font(.caption)
                        .foregroundColor(themeColors.success)
                }
            }

            // Actions
            HStack {
                Text("Cmd+Return to send · Esc to cancel")
                    .font(.caption)
                    .foregroundColor(themeColors.secondaryText)

                Spacer()

                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)

                Button("Send") {
                    sendNote()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!canSend || viewModel.isSending)
            }
        }
        .padding(16)
        .frame(minWidth: 350, maxWidth: .infinity, maxHeight: .infinity)
        .background(themeColors.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(themeColors.border.opacity(0.5), lineWidth: 1)
        )
        .overlay(alignment: .bottomTrailing) {
            // Resize handle
            ResizeHandle()
                .padding(4)
        }
    }

    private var canSend: Bool {
        !viewModel.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !viewModel.pendingImages.isEmpty
    }

    private func openImagePicker() {
        let picker = NSOpenPanel()
        picker.allowsMultipleSelection = true
        picker.canChooseFiles = true
        picker.canChooseDirectories = false
        picker.allowedContentTypes = [.image, .jpeg, .png, .gif, .heic]

        if picker.runModal() == .OK {
            let images = picker.urls.compactMap { NSImage(contentsOf: $0) }
            viewModel.addImages(images)
        }

        // Refocus text view after picker closes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            QuickNotePanelController.shared.refocusPanel()
            self.focusTrigger = UUID()
        }
    }

    private func handleImageDrop(providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.image") {
                provider.loadObject(ofClass: NSImage.self) { image, _ in
                    if let nsImage = image as? NSImage {
                        Task { @MainActor in
                            self.viewModel.addImages([nsImage])
                            QuickNotePanelController.shared.refocusPanel()
                            self.focusTrigger = UUID()
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url") { item, _ in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        Task { @MainActor in
                            if let image = NSImage(contentsOf: url) {
                                self.viewModel.addImages([image])
                                QuickNotePanelController.shared.refocusPanel()
                                self.focusTrigger = UUID()
                            }
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

// MARK: - Resize Handle

/// Visual resize handle for the bottom-right corner - indicates the panel is resizable
struct ResizeHandle: View {
    @Environment(\.themeColors) var themeColors

    var body: some View {
        // Visual grip lines like macOS window resize indicators
        VStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<(3 - row), id: \.self) { _ in
                        Circle()
                            .fill(themeColors.secondaryText.opacity(0.3))
                            .frame(width: 3, height: 3)
                    }
                }
            }
        }
        .frame(width: 14, height: 14)
    }
}
