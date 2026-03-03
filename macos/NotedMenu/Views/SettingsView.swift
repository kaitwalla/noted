import SwiftUI
import ServiceManagement
import Carbon

struct SettingsView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.dismiss) var dismiss

    @State private var launchAtLogin = false
    @State private var selectedNotebookId: String = ""
    @State private var apiURL: String = ""
    @State private var isRecordingHotkey = false
    @State private var hotkeyDisplay: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                // Default Notebook
                Section("Default Notebook") {
                    Picker("Notebook", selection: $selectedNotebookId) {
                        ForEach(appViewModel.notebooks) { notebook in
                            Text(notebook.title).tag(notebook.id.uuidString)
                        }
                    }
                    .onChange(of: selectedNotebookId) { _, newValue in
                        appViewModel.defaultNotebookId = newValue
                    }
                }

                // Hotkey
                Section("Global Hotkey") {
                    HStack {
                        Text("Quick Note:")
                        Spacer()
                        HotkeyRecorderButton(
                            isRecording: $isRecordingHotkey,
                            hotkeyDisplay: $hotkeyDisplay
                        )
                    }
                    Text("Click the button and press your desired shortcut")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Reset to Cmd+Shift+N") {
                        HotkeyManager.shared.updateHotkey(keyCode: 45, modifiers: UInt32(cmdKey | shiftKey))
                        hotkeyDisplay = HotkeyManager.shared.hotkeyString
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }

                // Launch at Login
                Section("Startup") {
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, newValue in
                            setLaunchAtLogin(newValue)
                        }
                }

                // API URL
                Section("Server") {
                    TextField("API URL", text: $apiURL)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            saveAPIURL()
                        }
                    Text("Default: \(APIService.defaultURL)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Button("Reset to Default") {
                            apiURL = APIService.defaultURL
                            saveAPIURL()
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 400, height: 480)
        .onAppear {
            selectedNotebookId = appViewModel.defaultNotebookId
            launchAtLogin = SMAppService.mainApp.status == .enabled
            apiURL = APIService.apiURL
            hotkeyDisplay = HotkeyManager.shared.hotkeyString
        }
    }

    private func saveAPIURL() {
        let trimmed = apiURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, URL(string: trimmed) != nil {
            APIService.apiURL = trimmed
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    }
}

// MARK: - Hotkey Recorder

struct HotkeyRecorderButton: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var hotkeyDisplay: String

    func makeNSView(context: Context) -> HotkeyRecorderNSButton {
        let button = HotkeyRecorderNSButton()
        button.title = hotkeyDisplay.isEmpty ? "Click to record" : hotkeyDisplay
        button.bezelStyle = .rounded
        button.target = context.coordinator
        button.action = #selector(Coordinator.buttonClicked)
        button.coordinator = context.coordinator
        return button
    }

    func updateNSView(_ nsView: HotkeyRecorderNSButton, context: Context) {
        if isRecording {
            nsView.title = "Press shortcut..."
        } else {
            nsView.title = hotkeyDisplay.isEmpty ? "Click to record" : hotkeyDisplay
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: HotkeyRecorderButton

        init(_ parent: HotkeyRecorderButton) {
            self.parent = parent
        }

        @objc func buttonClicked() {
            parent.isRecording = true
        }

        func handleKeyEvent(_ event: NSEvent) {
            guard parent.isRecording else { return }

            let keyCode = UInt32(event.keyCode)
            var modifiers: UInt32 = 0

            if event.modifierFlags.contains(.command) { modifiers |= UInt32(cmdKey) }
            if event.modifierFlags.contains(.shift) { modifiers |= UInt32(shiftKey) }
            if event.modifierFlags.contains(.option) { modifiers |= UInt32(optionKey) }
            if event.modifierFlags.contains(.control) { modifiers |= UInt32(controlKey) }

            // Require at least one modifier
            guard modifiers != 0 else { return }

            HotkeyManager.shared.updateHotkey(keyCode: keyCode, modifiers: modifiers)
            parent.hotkeyDisplay = HotkeyManager.shared.hotkeyString
            parent.isRecording = false
        }
    }
}

class HotkeyRecorderNSButton: NSButton {
    weak var coordinator: HotkeyRecorderButton.Coordinator?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        coordinator?.handleKeyEvent(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if coordinator?.parent.isRecording == true {
            coordinator?.handleKeyEvent(event)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
