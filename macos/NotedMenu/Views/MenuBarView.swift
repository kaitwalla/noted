import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            if appViewModel.isAuthenticated {
                authenticatedView
            } else {
                LoginView()
            }
        }
    }

    private var authenticatedView: some View {
        VStack(spacing: 0) {
            // Header with user email
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.secondary)
                Text(appViewModel.user?.email ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Notebooks list
            VStack(alignment: .leading, spacing: 0) {
                Text("NOTEBOOKS")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                ForEach(appViewModel.notebooks) { notebook in
                    notebookRow(notebook)
                }
            }

            Divider()

            // Hotkey hint
            HStack {
                Text("Quick Note:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(HotkeyManager.shared.hotkeyString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: .tertiarySystemFill))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Actions
            VStack(spacing: 0) {
                Button(action: { showSettings = true }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Settings...")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Button(action: appViewModel.logout) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Log Out")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Divider()

                Button(action: { NSApp.terminate(nil) }) {
                    HStack {
                        Image(systemName: "power")
                        Text("Quit Noted")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        }
        .frame(width: 260)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appViewModel)
        }
    }

    private func notebookRow(_ notebook: Notebook) -> some View {
        Button(action: {
            appViewModel.defaultNotebookId = notebook.id.uuidString
        }) {
            HStack {
                Image(systemName: "book.closed")
                    .foregroundColor(.accentColor)
                Text(notebook.title)
                    .lineLimit(1)
                Spacer()
                if notebook.id.uuidString == appViewModel.defaultNotebookId {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                        .font(.caption)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(notebook.id.uuidString == appViewModel.defaultNotebookId
            ? Color.accentColor.opacity(0.1)
            : Color.clear)
    }
}
