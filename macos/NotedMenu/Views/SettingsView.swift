import SwiftUI
import ServiceManagement
import Carbon

struct SettingsView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @StateObject private var updateService = UpdateService.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.themeColors) var themeColors
    var onDismiss: (() -> Void)?

    @State private var launchAtLogin = false
    @State private var selectedNotebookId: String = ""
    @State private var apiURL: String = ""
    @State private var isRecordingQuickNote = false
    @State private var quickNoteHotkeyDisplay: String = ""
    @State private var isRecordingNotebook = false
    @State private var notebookHotkeyDisplay: String = ""
    @State private var keyMonitor: Any?
    @State private var selectedMenuBarIcon: MenuBarIconStyle = .noteSwirl

    var body: some View {
        VStack(spacing: 16) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(themeColors.text)

            ScrollView {
                VStack(spacing: 16) {
                    // Theme
                    settingsSection("Appearance") {
                        ForEach(AppTheme.allCases) { theme in
                            themeRow(theme)
                        }
                    }

                    // Menu Bar Icon
                    settingsSection("Menu Bar Icon") {
                        ForEach(MenuBarIconStyle.allCases) { iconStyle in
                            menuBarIconRow(iconStyle)
                        }
                    }

                    // Default Notebook
                    settingsSection("Default Notebook") {
                        ForEach(appViewModel.notebooks) { notebook in
                            notebookRow(notebook)
                        }
                    }

                    // Hotkeys
                    settingsSection("Global Hotkeys") {
                        VStack(alignment: .leading, spacing: 12) {
                            // Quick Note hotkey
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Quick Note:")
                                        .foregroundColor(themeColors.text)
                                    Spacer()
                                    hotkeyButton(
                                        display: quickNoteHotkeyDisplay,
                                        isRecording: isRecordingQuickNote
                                    ) {
                                        isRecordingNotebook = false
                                        isRecordingQuickNote = true
                                    }
                                }
                                Text("Opens quick note panel")
                                    .font(.caption)
                                    .foregroundColor(themeColors.secondaryText)
                            }

                            Divider()

                            // Notebook toggle hotkey
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Toggle Notebook:")
                                        .foregroundColor(themeColors.text)
                                    Spacer()
                                    hotkeyButton(
                                        display: notebookHotkeyDisplay,
                                        isRecording: isRecordingNotebook
                                    ) {
                                        isRecordingQuickNote = false
                                        isRecordingNotebook = true
                                    }
                                }
                                Text("Opens menu bar popover")
                                    .font(.caption)
                                    .foregroundColor(themeColors.secondaryText)
                            }
                        }

                        Text("Click a button and press your desired shortcut")
                            .font(.caption)
                            .foregroundColor(themeColors.secondaryText)
                            .padding(.top, 4)

                        HStack(spacing: 12) {
                            Button("Reset Quick Note") {
                                HotkeyManager.shared.updateHotkey(keyCode: 45, modifiers: UInt32(cmdKey | shiftKey))
                                quickNoteHotkeyDisplay = HotkeyManager.shared.hotkeyString
                            }
                            Button("Reset Toggle") {
                                HotkeyManager.shared.updateNotebookHotkey(keyCode: 31, modifiers: UInt32(cmdKey | shiftKey))
                                notebookHotkeyDisplay = HotkeyManager.shared.notebookHotkeyString
                            }
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .foregroundColor(themeColors.accent)
                    }

                    // Launch at Login
                    settingsSection("Startup") {
                        Toggle("Launch at Login", isOn: $launchAtLogin)
                            .toggleStyle(.switch)
                            .foregroundColor(themeColors.text)
                            .onChange(of: launchAtLogin) { _, newValue in
                                setLaunchAtLogin(newValue)
                            }
                    }

                    // Updates
                    settingsSection("Updates") {
                        VStack(alignment: .leading, spacing: 12) {
                            // Current version info
                            HStack {
                                Text("Version:")
                                    .foregroundColor(themeColors.text)
                                Spacer()
                                Text("\(updateService.currentVersion) (Build \(updateService.currentBuild))")
                                    .foregroundColor(themeColors.secondaryText)
                            }

                            Divider()

                            // Auto-check toggle
                            Toggle("Check for updates automatically", isOn: $updateService.automaticallyChecksForUpdates)
                                .toggleStyle(.switch)
                                .foregroundColor(themeColors.text)

                            // Check for updates button
                            HStack {
                                Button {
                                    updateService.checkForUpdates()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                        Text("Check for Updates...")
                                    }
                                    .foregroundColor(themeColors.accent)
                                }
                                .buttonStyle(.borderless)
                                .disabled(!updateService.canCheckForUpdates)

                                Spacer()
                            }

                            // Last check info
                            if let lastCheck = updateService.lastUpdateCheckDate {
                                Text("Last checked: \(lastCheck.formatted(.relative(presentation: .named)))")
                                    .font(.caption)
                                    .foregroundColor(themeColors.secondaryText)
                            }

                            Text("Updates are downloaded and installed automatically when available.")
                                .font(.caption)
                                .foregroundColor(themeColors.secondaryText)
                        }
                    }

                    // API URL
                    settingsSection("Server") {
                        TextField("API URL", text: $apiURL)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                saveAPIURL()
                            }
                        Text("Default: \(APIService.defaultURL)")
                            .font(.caption)
                            .foregroundColor(themeColors.secondaryText)
                        Button("Reset to Default") {
                            apiURL = APIService.defaultURL
                            saveAPIURL()
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .foregroundColor(themeColors.accent)
                    }
                }
                .padding(.horizontal, 4)
            }

            HStack {
                Spacer()
                Button {
                    if let onDismiss = onDismiss {
                        onDismiss()
                    } else {
                        dismiss()
                    }
                } label: {
                    Text("Done")
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(themeColors.accent)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(width: 400, height: 650)
        .background(themeColors.background)
        .onAppear {
            selectedNotebookId = appViewModel.defaultNotebookId
            launchAtLogin = SMAppService.mainApp.status == .enabled
            apiURL = APIService.apiURL
            quickNoteHotkeyDisplay = HotkeyManager.shared.hotkeyString
            notebookHotkeyDisplay = HotkeyManager.shared.notebookHotkeyString
            if let savedIcon = UserDefaults.standard.string(forKey: "menuBarIconStyle"),
               let iconStyle = MenuBarIconStyle(rawValue: savedIcon) {
                selectedMenuBarIcon = iconStyle
            }
        }
        .onDisappear {
            stopKeyMonitor()
        }
        .onChange(of: isRecordingQuickNote) { _, recording in
            if recording { startKeyMonitor() } else if !isRecordingNotebook { stopKeyMonitor() }
        }
        .onChange(of: isRecordingNotebook) { _, recording in
            if recording { startKeyMonitor() } else if !isRecordingQuickNote { stopKeyMonitor() }
        }
    }

    private func startKeyMonitor() {
        stopKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let keyCode = UInt32(event.keyCode)

            var modifiers: UInt32 = 0
            if event.modifierFlags.contains(.command) { modifiers |= UInt32(cmdKey) }
            if event.modifierFlags.contains(.shift) { modifiers |= UInt32(shiftKey) }
            if event.modifierFlags.contains(.option) { modifiers |= UInt32(optionKey) }
            if event.modifierFlags.contains(.control) { modifiers |= UInt32(controlKey) }

            // Require at least one modifier
            guard modifiers != 0 else { return event }

            // Ignore modifier-only keys
            let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63] // Cmd, Shift, Ctrl, Option, Fn variants
            guard !modifierKeyCodes.contains(event.keyCode) else { return event }

            if self.isRecordingQuickNote {
                HotkeyManager.shared.updateHotkey(keyCode: keyCode, modifiers: modifiers)
                self.quickNoteHotkeyDisplay = HotkeyManager.shared.hotkeyString
                self.isRecordingQuickNote = false
            } else if self.isRecordingNotebook {
                HotkeyManager.shared.updateNotebookHotkey(keyCode: keyCode, modifiers: modifiers)
                self.notebookHotkeyDisplay = HotkeyManager.shared.notebookHotkeyString
                self.isRecordingNotebook = false
            }
            return nil // Consume the event
        }
    }

    private func stopKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
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

    // MARK: - Section Helper

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(themeColors.secondaryText)

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(themeColors.secondaryBackground)
            .cornerRadius(8)
        }
    }

    private func themeRow(_ theme: AppTheme) -> some View {
        Button {
            themeManager.currentTheme = theme
        } label: {
            HStack(spacing: 12) {
                Image(systemName: themeManager.currentTheme == theme ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(themeManager.currentTheme == theme ? themeColors.accent : themeColors.secondaryText)

                Image(systemName: theme.icon)
                    .foregroundColor(themeColors.accent)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.rawValue)
                        .foregroundColor(themeColors.text)
                    Text(theme.description)
                        .font(.caption)
                        .foregroundColor(themeColors.secondaryText)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func notebookRow(_ notebook: Notebook) -> some View {
        Button {
            selectedNotebookId = notebook.id.uuidString
            appViewModel.defaultNotebookId = notebook.id.uuidString
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selectedNotebookId == notebook.id.uuidString ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedNotebookId == notebook.id.uuidString ? themeColors.accent : themeColors.secondaryText)

                Image(systemName: "book.closed")
                    .foregroundColor(themeColors.accent)

                Text(notebook.title)
                    .foregroundColor(themeColors.text)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func menuBarIconRow(_ iconStyle: MenuBarIconStyle) -> some View {
        Button {
            selectedMenuBarIcon = iconStyle
            UserDefaults.standard.set(iconStyle.rawValue, forKey: "menuBarIconStyle")
            NotificationCenter.default.post(name: .menuBarIconDidChange, object: iconStyle)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selectedMenuBarIcon == iconStyle ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedMenuBarIcon == iconStyle ? themeColors.accent : themeColors.secondaryText)

                MenuBarIconView(style: iconStyle, size: 20)
                    .foregroundColor(themeColors.accent)

                Text(iconStyle.rawValue)
                    .foregroundColor(themeColors.text)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func hotkeyButton(display: String, isRecording: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(isRecording ? "Press shortcut..." : (display.isEmpty ? "Click to set" : display))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(isRecording ? themeColors.accent : themeColors.text)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(themeColors.tertiaryBackground)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? themeColors.accent : themeColors.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

}
