import Foundation
import Carbon
import AppKit

final class HotkeyManager {
    static let shared = HotkeyManager()

    private var hotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    var onHotkeyPressed: (() -> Void)?

    // Default: Cmd+Shift+N
    @Published var keyCode: UInt32 {
        didSet { UserDefaults.standard.set(keyCode, forKey: "hotkeyKeyCode") }
    }
    @Published var modifiers: UInt32 {
        didSet { UserDefaults.standard.set(modifiers, forKey: "hotkeyModifiers") }
    }

    private init() {
        // Load saved values or use defaults
        let savedKeyCode = UserDefaults.standard.object(forKey: "hotkeyKeyCode") as? UInt32
        let savedModifiers = UserDefaults.standard.object(forKey: "hotkeyModifiers") as? UInt32

        // Default: Cmd+Shift+N (N = 45)
        self.keyCode = savedKeyCode ?? 45
        self.modifiers = savedModifiers ?? UInt32(cmdKey | shiftKey)
    }

    func register() {
        unregister()

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { (_, event, _) -> OSStatus in
            HotkeyManager.shared.onHotkeyPressed?()
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &eventHandler)

        let hotkeyID = EventHotKeyID(signature: OSType(0x4E4F5445), id: 1) // "NOTE"

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if status != noErr {
            print("Failed to register hotkey: \(status)")
        }
    }

    func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
    }

    func updateHotkey(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        register()
    }

    // Helper to get current hotkey string for display
    var hotkeyString: String {
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
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
            20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
            29: "0", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N",
            46: "M"
        ]
        return keyMap[keyCode]
    }
}
