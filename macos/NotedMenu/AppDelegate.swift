import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let appViewModel = AppViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from dock
        NSApp.setActivationPolicy(.accessory)

        // Setup menu bar
        setupStatusItem()

        // Setup hotkey
        setupHotkey()

        // Setup quick note panel
        QuickNotePanelController.shared.setAppViewModel(appViewModel)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Noted")
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 280, height: 400)
        popover?.behavior = .transient
        popover?.animates = true
        popover?.contentViewController = NSHostingController(
            rootView: MenuBarView().environmentObject(appViewModel)
        )
    }

    private func setupHotkey() {
        HotkeyManager.shared.onHotkeyPressed = { [weak self] in
            self?.showQuickNote()
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

        QuickNotePanelController.shared.showPanel()
    }
}
