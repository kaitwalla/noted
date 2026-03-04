import AppKit
import SwiftUI
import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let appViewModel = AppViewModel()
    private var viewStateCancellable: AnyCancellable?
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

        // Setup quick note panel
        QuickNotePanelController.shared.setAppViewModel(appViewModel)

        // Observe theme changes
        themeCancellable = ThemeManager.shared.$currentTheme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePopoverContent()
            }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateMenuBarIcon()
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Observe icon changes
        iconObserver = NotificationCenter.default.addObserver(
            forName: .menuBarIconDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateMenuBarIcon()
        }

        popover = NSPopover()
        popover?.contentSize = popoverSize(for: appViewModel.viewState)
        popover?.behavior = .transient
        popover?.animates = true
        popover?.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(appViewModel)
                .themed()
        )

        // Observe view state changes to resize popover
        viewStateCancellable = appViewModel.$viewState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updatePopoverSize(for: state)
            }
    }

    private func popoverSize(for state: MenuViewState) -> NSSize {
        switch state {
        case .notebooks:
            return NSSize(width: 280, height: 400)
        case .noteStream:
            return NSSize(width: 320, height: 500)
        }
    }

    private func updatePopoverSize(for state: MenuViewState) {
        guard let popover = popover else { return }
        let newSize = popoverSize(for: state)
        popover.contentSize = newSize
    }

    private func updatePopoverContent() {
        // Recreate the content view to pick up new theme colors
        popover?.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(appViewModel)
                .themed()
        )
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
            self?.showQuickNote()
        }
        HotkeyManager.shared.onNotebookHotkeyPressed = { [weak self] in
            self?.toggleNotebook()
        }
        HotkeyManager.shared.register()
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showQuickNote() {
        // Don't show if not authenticated
        guard appViewModel.isAuthenticated else {
            togglePopover()
            return
        }

        QuickNotePanelController.shared.togglePanel()
    }

    private func toggleNotebook() {
        guard let button = statusItem?.button, let popover = popover else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Navigate to last selected notebook (default notebook)
            if appViewModel.isAuthenticated, let notebook = appViewModel.defaultNotebook {
                appViewModel.openNoteStream(for: notebook)
            }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
