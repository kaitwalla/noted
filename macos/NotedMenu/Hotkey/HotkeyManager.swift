import Foundation
import Carbon
import AppKit

final class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    // Quick Note hotkey
    private var quickNoteHotkeyRef: EventHotKeyRef?
    var onQuickNoteHotkeyPressed: (() -> Void)?

    // Notebook toggle hotkey
    private var notebookHotkeyRef: EventHotKeyRef?
    var onNotebookHotkeyPressed: (() -> Void)?

    private var eventHandler: EventHandlerRef?

    // Quick Note hotkey: Default Cmd+Shift+N
    @Published var quickNoteKeyCode: UInt32 {
        didSet { UserDefaults.standard.set(quickNoteKeyCode, forKey: "hotkeyKeyCode") }
    }
    @Published var quickNoteModifiers: UInt32 {
        didSet { UserDefaults.standard.set(quickNoteModifiers, forKey: "hotkeyModifiers") }
    }

    // Notebook hotkey: Default Cmd+Shift+O
    @Published var notebookKeyCode: UInt32 {
        didSet { UserDefaults.standard.set(notebookKeyCode, forKey: "notebookHotkeyKeyCode") }
    }
    @Published var notebookModifiers: UInt32 {
        didSet { UserDefaults.standard.set(notebookModifiers, forKey: "notebookHotkeyModifiers") }
    }

    // Legacy compatibility
    var onHotkeyPressed: (() -> Void)? {
        get { onQuickNoteHotkeyPressed }
        set { onQuickNoteHotkeyPressed = newValue }
    }
    var keyCode: UInt32 {
        get { quickNoteKeyCode }
        set { quickNoteKeyCode = newValue }
    }
    var modifiers: UInt32 {
        get { quickNoteModifiers }
        set { quickNoteModifiers = newValue }
    }

    private init() {
        // Load saved values or use defaults
        let savedKeyCode = UserDefaults.standard.object(forKey: "hotkeyKeyCode") as? UInt32
        let savedModifiers = UserDefaults.standard.object(forKey: "hotkeyModifiers") as? UInt32

        // Quick Note default: Cmd+Shift+N (N = 45)
        self.quickNoteKeyCode = savedKeyCode ?? 45
        self.quickNoteModifiers = savedModifiers ?? UInt32(cmdKey | shiftKey)

        // Notebook default: Cmd+Shift+O (O = 31)
        let savedNotebookKeyCode = UserDefaults.standard.object(forKey: "notebookHotkeyKeyCode") as? UInt32
        let savedNotebookModifiers = UserDefaults.standard.object(forKey: "notebookHotkeyModifiers") as? UInt32
        self.notebookKeyCode = savedNotebookKeyCode ?? 31
        self.notebookModifiers = savedNotebookModifiers ?? UInt32(cmdKey | shiftKey)
    }

    func register() {
        unregister()

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { (_, event, _) -> OSStatus in
            var hotkeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                            nil, MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)

            switch hotkeyID.id {
            case 1:
                HotkeyManager.shared.onQuickNoteHotkeyPressed?()
            case 2:
                HotkeyManager.shared.onNotebookHotkeyPressed?()
            default:
                break
            }
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &eventHandler)

        // Register Quick Note hotkey (ID: 1)
        let quickNoteHotkeyID = EventHotKeyID(signature: OSType(0x4E4F5445), id: 1) // "NOTE"
        let status1 = RegisterEventHotKey(
            quickNoteKeyCode,
            quickNoteModifiers,
            quickNoteHotkeyID,
            GetApplicationEventTarget(),
            0,
            &quickNoteHotkeyRef
        )
        if status1 != noErr {
            print("Failed to register quick note hotkey: \(status1)")
        }

        // Register Notebook hotkey (ID: 2)
        let notebookHotkeyID = EventHotKeyID(signature: OSType(0x4E4F5445), id: 2) // "NOTE"
        let status2 = RegisterEventHotKey(
            notebookKeyCode,
            notebookModifiers,
            notebookHotkeyID,
            GetApplicationEventTarget(),
            0,
            &notebookHotkeyRef
        )
        if status2 != noErr {
            print("Failed to register notebook hotkey: \(status2)")
        }
    }

    func unregister() {
        if let ref = quickNoteHotkeyRef {
            UnregisterEventHotKey(ref)
            quickNoteHotkeyRef = nil
        }
        if let ref = notebookHotkeyRef {
            UnregisterEventHotKey(ref)
            notebookHotkeyRef = nil
        }
    }

    func updateHotkey(keyCode: UInt32, modifiers: UInt32) {
        self.quickNoteKeyCode = keyCode
        self.quickNoteModifiers = modifiers
        register()
    }

    func updateNotebookHotkey(keyCode: UInt32, modifiers: UInt32) {
        self.notebookKeyCode = keyCode
        self.notebookModifiers = modifiers
        register()
    }

    // Helper to get current hotkey string for display
    var hotkeyString: String {
        formatHotkey(keyCode: quickNoteKeyCode, modifiers: quickNoteModifiers)
    }

    var notebookHotkeyString: String {
        formatHotkey(keyCode: notebookKeyCode, modifiers: notebookModifiers)
    }

    private func formatHotkey(keyCode: UInt32, modifiers: UInt32) -> String {
        var parts: [String] = []

        if modifiers & UInt32(cmdKey) != 0 { parts.append("Cmd") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("Shift") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("Option") }
        if modifiers & UInt32(controlKey) != 0 { parts.append("Control") }

        if let char = keyCodeToString(keyCode) {
            parts.append(char)
        }

        return parts.joined(separator: "+")
    }

    private func keyCodeToString(_ keyCode: UInt32) -> String? {
        let keyMap: [UInt32: String] = [
            // Letters
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
            31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
            // Numbers
            18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 25: "9", 26: "7", 28: "8", 29: "0",
            // Punctuation
            24: "=", 27: "-", 30: "]", 33: "[", 39: "'", 41: ";", 42: "\\", 43: ",", 44: "/", 47: ".", 50: "`",
            // Special keys
            36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Escape",
            // Arrow keys
            123: "←", 124: "→", 125: "↓", 126: "↑",
            // Function keys
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
            // Other
            114: "Help", 115: "Home", 116: "PgUp", 117: "Delete→", 119: "End", 121: "PgDn"
        ]
        return keyMap[keyCode]
    }
}
