import SwiftUI
import AppKit
import Combine

// MARK: - Layout Constants

private enum PanelLayout {
    /// Padding from screen edges
    static let screenEdgePadding: CGFloat = 20
    /// Extra padding for size clamping (2x edge padding)
    static let screenSizePadding: CGFloat = 40
    /// Vertical offset when centering (above center)
    static let centerVerticalOffset: CGFloat = 50
}

/// Controller for the main floating panel (notebooks, notes)
@MainActor
class MainPanelController: NSObject {
    static let shared = MainPanelController()

    private var panel: NSPanel?
    private weak var appViewModel: AppViewModel?
    private var themeCancellable: AnyCancellable?

    private let frameKey = "MainPanelFrame"
    private let defaultSize = NSSize(width: 340, height: 500)
    private let minSize = NSSize(width: 280, height: 300)

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
                newFrame.size.width = min(newFrame.size.width, screenRect.width - PanelLayout.screenSizePadding)
                newFrame.size.height = min(newFrame.size.height, screenRect.height - PanelLayout.screenSizePadding)

                // Check if saved position is on the current screen
                let savedCenter = NSPoint(x: savedFrame.midX, y: savedFrame.midY)
                let isOnCurrentScreen = screenRect.contains(savedCenter)

                if isOnCurrentScreen {
                    // Keep position but ensure it's fully visible
                    newFrame.origin.x = max(screenRect.minX + PanelLayout.screenEdgePadding,
                                            min(newFrame.origin.x, screenRect.maxX - newFrame.width - PanelLayout.screenEdgePadding))
                    newFrame.origin.y = max(screenRect.minY + PanelLayout.screenEdgePadding,
                                            min(newFrame.origin.y, screenRect.maxY - newFrame.height - PanelLayout.screenEdgePadding))
                } else {
                    // Center on current screen
                    newFrame.origin.x = screenRect.midX - newFrame.width / 2
                    newFrame.origin.y = screenRect.midY - newFrame.height / 2 + PanelLayout.centerVerticalOffset
                }

                panel.setFrame(newFrame, display: true)
                panel.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            } else {
                setDefaultFrame(for: panel, in: screenRect)
            }
        } else {
            setDefaultFrame(for: panel, in: screenRect)
        }
    }

    private func setDefaultFrame(for panel: NSPanel, in screenRect: NSRect) {
        let panelSize = panel.frame.size.width >= minSize.width ? panel.frame.size : defaultSize
        let clampedWidth = min(panelSize.width, screenRect.width - PanelLayout.screenSizePadding)
        let clampedHeight = min(panelSize.height, screenRect.height - PanelLayout.screenSizePadding)

        let x = screenRect.midX - clampedWidth / 2
        let y = screenRect.midY - clampedHeight / 2 + PanelLayout.centerVerticalOffset

        panel.setFrame(NSRect(x: x, y: y, width: clampedWidth, height: clampedHeight), display: true)

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

        updatePanelContent(panel)

        self.panel = panel

        // Observe theme changes
        themeCancellable = ThemeManager.shared.$currentTheme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePanelTheme()
            }
    }

    private func updatePanelContent(_ panel: NSPanel) {
        guard let appViewModel = appViewModel else { return }

        let contentView = MainPanelView(
            onDismiss: { [weak self] in self?.hidePanel() }
        )
        .environmentObject(appViewModel)
        .themed()
        .ignoresSafeArea()

        panel.contentView = NSHostingView(rootView: contentView)
    }

    private func updatePanelTheme() {
        guard let panel = panel else { return }
        updatePanelContent(panel)
    }
}

// MARK: - Main Panel View

struct MainPanelView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.themeColors) var themeColors
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Image(systemName: "book.closed.fill")
                    .foregroundColor(themeColors.accent)
                Text("Noted")
                    .font(.headline)
                    .foregroundColor(themeColors.text)

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(themeColors.secondaryText)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                // Hidden button to capture Esc key
                Button("") { onDismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                    .opacity(0)
            }

            Divider()
                .background(themeColors.border)

            // Main content
            if !appViewModel.isAuthenticated {
                LoginView()
            } else {
                switch appViewModel.viewState {
                case .notebooks:
                    NotebookListView()
                case .noteStream(let notebook):
                    NoteStreamView(notebook: notebook)
                }
            }
        }
        .frame(minWidth: 280, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
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
}

// MARK: - Notebook List View

struct NotebookListView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.themeColors) var themeColors

    var body: some View {
        VStack(spacing: 0) {
            if appViewModel.isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Spacer()
            } else if appViewModel.notebooks.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "book.closed")
                        .font(.title)
                        .foregroundColor(themeColors.secondaryText)
                    Text("No notebooks")
                        .font(.caption)
                        .foregroundColor(themeColors.secondaryText)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(appViewModel.notebooks) { notebook in
                            NotebookRow(notebook: notebook) {
                                appViewModel.openNoteStream(for: notebook)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .task {
            await appViewModel.loadNotebooks()
        }
    }
}

struct NotebookRow: View {
    let notebook: Notebook
    let onTap: () -> Void
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.themeColors) var themeColors

    var isDefault: Bool {
        appViewModel.defaultNotebook?.id == notebook.id
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "book.closed")
                    .font(.system(size: 14))
                    .foregroundColor(themeColors.accent)

                Text(notebook.title)
                    .font(.body)
                    .foregroundColor(themeColors.text)
                    .lineLimit(1)

                Spacer()

                if isDefault {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(themeColors.accent)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(themeColors.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                appViewModel.defaultNotebookId = notebook.id.uuidString
            } label: {
                Label(isDefault ? "Default Notebook" : "Set as Default",
                      systemImage: isDefault ? "star.fill" : "star")
            }
            .disabled(isDefault)
        }
    }
}
