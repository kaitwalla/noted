import SwiftUI
import AppKit
import Combine

// MARK: - Menu Panel Controller

@MainActor
class MenuPanelController: NSObject {
    static let shared = MenuPanelController()

    private var panel: NSPanel?
    private weak var appViewModel: AppViewModel?
    private var themeCancellable: AnyCancellable?
    private weak var statusItemButton: NSStatusBarButton?
    private var clickOutsideMonitor: Any?

    func setAppViewModel(_ vm: AppViewModel) {
        self.appViewModel = vm
    }

    func setStatusItemButton(_ button: NSStatusBarButton) {
        self.statusItemButton = button
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

        guard let panel = panel, let button = statusItemButton else { return }

        // Position below the status item
        let buttonRect = button.window?.convertToScreen(button.convert(button.bounds, to: nil)) ?? .zero
        let panelSize = panel.frame.size

        let x = buttonRect.midX - panelSize.width / 2
        let y = buttonRect.minY - panelSize.height - 4

        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.makeKeyAndOrderFront(nil)

        // Remove existing monitor if any
        if let existingMonitor = clickOutsideMonitor {
            NSEvent.removeMonitor(existingMonitor)
            clickOutsideMonitor = nil
        }

        // Monitor for clicks outside the panel to dismiss
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let panel = self?.panel, panel.isVisible {
                if !panel.frame.contains(NSEvent.mouseLocation) {
                    self?.hidePanel()
                }
            }
        }
    }

    func hidePanel() {
        // Remove click outside monitor
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
        panel?.orderOut(nil)
    }

    private func createPanel() {
        let panelSize = NSSize(width: 200, height: 220)

        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
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

        let contentView = MenuPanelView(
            onDismiss: { [weak self] in self?.hidePanel() },
            onOpenNotebooks: { [weak self] in
                self?.hidePanel()
                MainPanelController.shared.togglePanel()
            },
            onQuickNote: { [weak self] in
                self?.hidePanel()
                QuickNotePanelController.shared.togglePanel()
            },
            onSettings: { [weak self] in
                self?.hidePanel()
                SettingsPanelController.shared.showPanel()
            },
            onCheckUpdates: { [weak self] in
                self?.hidePanel()
                UpdateService.shared.checkForUpdates()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
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

// MARK: - Menu Panel View

struct MenuPanelView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.themeColors) var themeColors
    @State private var showLogoutConfirmation = false

    var onDismiss: () -> Void
    var onOpenNotebooks: () -> Void
    var onQuickNote: () -> Void
    var onSettings: () -> Void
    var onCheckUpdates: () -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Menu items
            VStack(spacing: 2) {
                menuItem(title: "Open Notebooks", icon: "book.closed", action: onOpenNotebooks)
                menuItem(title: "Quick Note", icon: "note.text", action: onQuickNote)

                Divider()
                    .background(themeColors.border)
                    .padding(.vertical, 4)

                menuItem(title: "Settings...", icon: "gearshape", action: onSettings)
                menuItem(title: "Check for Updates...", icon: "arrow.triangle.2.circlepath", action: onCheckUpdates)

                if appViewModel.isAuthenticated {
                    Divider()
                        .background(themeColors.border)
                        .padding(.vertical, 4)

                    menuItem(title: "Log Out", icon: "rectangle.portrait.and.arrow.right", action: {
                        showLogoutConfirmation = true
                    })
                }

                Divider()
                    .background(themeColors.border)
                    .padding(.vertical, 4)

                menuItem(title: "Quit Noted", icon: "power", action: onQuit)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
        }
        .frame(width: 200)
        .background(themeColors.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(themeColors.border.opacity(0.5), lineWidth: 1)
        )
        .background {
            // Hidden button to capture Esc key
            Button("") { onDismiss() }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
        }
        .alert("Log Out?", isPresented: $showLogoutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Log Out", role: .destructive) {
                onDismiss()
                appViewModel.logout()
            }
        } message: {
            Text("This will clear all local data and cached images.")
        }
    }

    private func menuItem(title: String, icon: String, action: @escaping () -> Void) -> some View {
        MenuItemButton(title: title, icon: icon, themeColors: themeColors, action: action)
    }
}

// MARK: - Menu Item Button

struct MenuItemButton: View {
    let title: String
    let icon: String
    let themeColors: ThemeColors
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(themeColors.accent)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(themeColors.text)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isHovered ? themeColors.accent.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
