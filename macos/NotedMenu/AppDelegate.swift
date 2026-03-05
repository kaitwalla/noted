import AppKit
import SwiftUI
import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let appViewModel = AppViewModel()
    private var themeCancellable: AnyCancellable?
    private var iconObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from dock
        NSApp.setActivationPolicy(.accessory)

        // Apply initial theme appearance
        ThemeManager.shared.updateAppearance()

        // Setup menu bar
        setupStatusItem()

        // Setup hotkey
        setupHotkey()

        // Setup panels
        QuickNotePanelController.shared.setAppViewModel(appViewModel)
        MainPanelController.shared.setAppViewModel(appViewModel)
        SettingsPanelController.shared.setAppViewModel(appViewModel)

        // Observe theme changes
        themeCancellable = ThemeManager.shared.$currentTheme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenu()
            }

        // Initialize UpdateService (Sparkle will check for updates automatically based on Info.plist settings)
        _ = UpdateService.shared
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateMenuBarIcon()
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Observe icon changes
        iconObserver = NotificationCenter.default.addObserver(
            forName: .menuBarIconDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateMenuBarIcon()
            }
        }

        updateMenu()
    }

    private func updateMenu() {
        let menu = NSMenu()

        // Open Notebooks
        let openItem = NSMenuItem(title: "Open Notebooks", action: #selector(openNotebooks), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        // Quick Note
        let quickNoteItem = NSMenuItem(title: "Quick Note", action: #selector(showQuickNote), keyEquivalent: "")
        quickNoteItem.target = self
        menu.addItem(quickNoteItem)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Check for Updates
        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Noted", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func statusItemClicked(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .leftMouseUp {
            // Left click - toggle main panel
            statusItem?.menu = nil
            MainPanelController.shared.togglePanel()

            // Re-enable menu for right-click
            DispatchQueue.main.async { [weak self] in
                self?.updateMenu()
            }
        }
        // Right click will show the menu automatically
    }

    private func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }

        // Load saved icon style or use default
        var iconStyle = MenuBarIconStyle.default
        if let savedIcon = UserDefaults.standard.string(forKey: "menuBarIconStyle"),
           let saved = MenuBarIconStyle(rawValue: savedIcon) {
            iconStyle = saved
        }

        button.image = iconStyle.createMenuBarImage()
    }

    private func setupHotkey() {
        HotkeyManager.shared.onQuickNoteHotkeyPressed = { [weak self] in
            self?.showQuickNoteAction()
        }
        HotkeyManager.shared.onNotebookHotkeyPressed = { [weak self] in
            self?.openNotebooksAction()
        }
        HotkeyManager.shared.register()
    }

    // MARK: - Menu Actions

    @objc private func openNotebooks() {
        openNotebooksAction()
    }

    @objc private func showQuickNote() {
        showQuickNoteAction()
    }

    @objc private func openSettings() {
        SettingsPanelController.shared.showPanel()
    }

    @objc private func checkForUpdates() {
        UpdateService.shared.checkForUpdates()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Actions

    private func openNotebooksAction() {
        // If panel is already visible, toggle it closed
        if MainPanelController.shared.isVisible {
            MainPanelController.shared.hidePanel()
            return
        }

        // Navigate to default notebook if authenticated
        if appViewModel.isAuthenticated, let notebook = appViewModel.defaultNotebook {
            appViewModel.openNoteStream(for: notebook)
        }
        MainPanelController.shared.showPanel()
    }

    private func showQuickNoteAction() {
        // Don't show if not authenticated
        guard appViewModel.isAuthenticated else {
            MainPanelController.shared.showPanel()
            return
        }

        QuickNotePanelController.shared.togglePanel()
    }
}

// MARK: - Settings Panel Controller

@MainActor
class SettingsPanelController: NSObject {
    static let shared = SettingsPanelController()

    private var panel: NSPanel?
    private weak var appViewModel: AppViewModel?
    private var themeCancellable: AnyCancellable?

    func setAppViewModel(_ vm: AppViewModel) {
        self.appViewModel = vm
    }

    func showPanel() {
        if panel == nil {
            createPanel()
        }

        guard let panel = panel else { return }

        // Center on screen
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let panelSize = panel.frame.size
            let x = screenRect.midX - panelSize.width / 2
            let y = screenRect.midY - panelSize.height / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hidePanel() {
        panel?.orderOut(nil)
    }

    private func createPanel() {
        guard let appViewModel = appViewModel else { return }

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 650),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        panel.title = "Settings"
        panel.level = .floating
        panel.isReleasedWhenClosed = false

        updatePanelContent(panel, appViewModel: appViewModel)

        self.panel = panel

        // Observe theme changes
        themeCancellable = ThemeManager.shared.$currentTheme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePanelTheme()
            }
    }

    private func updatePanelContent(_ panel: NSPanel, appViewModel: AppViewModel) {
        let contentView = SettingsView(onDismiss: { [weak self] in
            self?.hidePanel()
        })
        .environmentObject(appViewModel)
        .themed()

        panel.contentView = NSHostingView(rootView: contentView)
    }

    private func updatePanelTheme() {
        guard let panel = panel, let appViewModel = appViewModel else { return }
        updatePanelContent(panel, appViewModel: appViewModel)
    }
}
