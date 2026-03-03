import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.dismiss) var dismiss

    @State private var launchAtLogin = false
    @State private var selectedNotebookId: String = ""

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
                        Text(HotkeyManager.shared.hotkeyString)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(nsColor: .tertiarySystemFill))
                            .cornerRadius(4)
                    }
                    Text("Default: Cmd+Shift+N")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Launch at Login
                Section("Startup") {
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, newValue in
                            setLaunchAtLogin(newValue)
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
        .frame(width: 350, height: 320)
        .onAppear {
            selectedNotebookId = appViewModel.defaultNotebookId
            launchAtLogin = SMAppService.mainApp.status == .enabled
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
