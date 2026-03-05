import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.themeColors) var themeColors
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            if appViewModel.isCheckingAuth {
                // Show loading while checking stored auth
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(width: 260, height: 100)
            } else if appViewModel.isAuthenticated {
                switch appViewModel.viewState {
                case .notebooks:
                    notebooksView
                case .noteStream(let notebook):
                    NoteStreamView(notebook: notebook)
                }
            } else {
                LoginView()
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(themeColors.background)
    }

    private var notebooksView: some View {
        VStack(spacing: 0) {
            // Header with user email
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(themeColors.secondaryText)
                Text(appViewModel.user?.email ?? "")
                    .font(.caption)
                    .foregroundColor(themeColors.secondaryText)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(themeColors.background)

            Divider()
                .background(themeColors.border)

            // Notebooks list
            VStack(alignment: .leading, spacing: 0) {
                Text("NOTEBOOKS")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(themeColors.secondaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                ForEach(appViewModel.notebooks) { notebook in
                    notebookRow(notebook)
                }
            }

            Divider()
                .background(themeColors.border)

            // Hotkey hints
            VStack(spacing: 4) {
                HStack {
                    Text("Quick Note:")
                        .font(.caption)
                        .foregroundColor(themeColors.secondaryText)
                    Spacer()
                    Text(HotkeyManager.shared.hotkeyString)
                        .font(.caption)
                        .foregroundColor(themeColors.secondaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(themeColors.tertiaryBackground)
                        .cornerRadius(4)
                }
                HStack {
                    Text("Toggle Notebook:")
                        .font(.caption)
                        .foregroundColor(themeColors.secondaryText)
                    Spacer()
                    Text(HotkeyManager.shared.notebookHotkeyString)
                        .font(.caption)
                        .foregroundColor(themeColors.secondaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(themeColors.tertiaryBackground)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()
                .background(themeColors.border)

            // Actions
            VStack(spacing: 0) {
                Button(action: { showSettings = true }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Settings...")
                        Spacer()
                    }
                    .foregroundColor(themeColors.text)
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
                    .foregroundColor(themeColors.text)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Divider()
                .background(themeColors.border)

                Button(action: { NSApp.terminate(nil) }) {
                    HStack {
                        Image(systemName: "power")
                        Text("Quit Noted")
                        Spacer()
                    }
                    .foregroundColor(themeColors.text)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        }
        .frame(width: 260)
        .frame(maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appViewModel)
                .themed()
                .background(themeColors.background)
        }
    }

    private func notebookRow(_ notebook: Notebook) -> some View {
        Button(action: {
            appViewModel.openNoteStream(for: notebook)
        }) {
            HStack {
                Image(systemName: "book.closed")
                    .foregroundColor(themeColors.accent)
                Text(notebook.title)
                    .foregroundColor(themeColors.text)
                    .lineLimit(1)
                Spacer()
                if notebook.id.uuidString == appViewModel.defaultNotebookId {
                    Image(systemName: "checkmark")
                        .foregroundColor(themeColors.accent)
                        .font(.caption)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(themeColors.secondaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(notebook.id.uuidString == appViewModel.defaultNotebookId
            ? themeColors.accent.opacity(0.1)
            : Color.clear)
        .contextMenu {
            Button {
                appViewModel.defaultNotebookId = notebook.id.uuidString
            } label: {
                Label("Set as Default", systemImage: "checkmark.circle")
            }
        }
    }
}
