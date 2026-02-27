import SwiftUI

struct SettingsView: View {
    @Bindable var authViewModel: AuthViewModel
    @State private var showLogoutConfirmation = false
    @State private var showClearDataConfirmation = false
    @State private var isSyncing = false
    @State private var notificationsEnabled = true

    private let syncService = SyncService.shared
    private let notificationService = NotificationService.shared
    private let imageService = ImageService.shared
    private let networkMonitor = NetworkMonitor.shared

    var body: some View {
        NavigationStack {
            List {
                // Account section
                Section("Account") {
                    if let user = authViewModel.currentUser {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.accent)

                            VStack(alignment: .leading) {
                                Text(user.email)
                                    .font(.body)
                                Text("Member since \(formatDate(user.createdAt))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Button(role: .destructive) {
                        showLogoutConfirmation = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                // Sync section
                Section {
                    HStack {
                        Label("Status", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        if isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if networkMonitor.isConnected {
                            Text("Connected")
                                .foregroundStyle(.green)
                        } else {
                            Text("Offline")
                                .foregroundStyle(.orange)
                        }
                    }

                    HStack {
                        Label("Last Sync", systemImage: "clock")
                        Spacer()
                        Text(lastSyncText)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        Task {
                            await performSync()
                        }
                    } label: {
                        HStack {
                            Label("Sync Now", systemImage: "arrow.clockwise")
                            if isSyncing {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isSyncing || !networkMonitor.isConnected)
                } header: {
                    Text("Sync")
                } footer: {
                    Text("Your notes are stored locally and synced when online.")
                }

                // Notifications section
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Reminder Notifications", systemImage: "bell.badge")
                    }
                    .onChange(of: notificationsEnabled) { _, newValue in
                        if newValue {
                            Task {
                                await notificationService.requestPermission()
                            }
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Receive notifications for note reminders.")
                }

                // Storage section
                Section {
                    Button {
                        Task {
                            await imageService.clearCache()
                        }
                    } label: {
                        Label("Clear Image Cache", systemImage: "photo.stack")
                    }

                    Button(role: .destructive) {
                        showClearDataConfirmation = true
                    } label: {
                        Label("Clear All Local Data", systemImage: "trash")
                    }
                } header: {
                    Text("Storage")
                } footer: {
                    Text("Clearing local data will remove all offline notes. They will be restored on next sync if you're signed in.")
                }

                // About section
                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://noted.app/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }

                    Link(destination: URL(string: "https://noted.app/terms")!) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }

                    Link(destination: URL(string: "mailto:support@noted.app")!) {
                        Label("Contact Support", systemImage: "envelope")
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Sign Out",
                isPresented: $showLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    authViewModel.logout()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .confirmationDialog(
                "Clear All Data",
                isPresented: $showClearDataConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear Data", role: .destructive) {
                    syncService.clearSyncData()
                    Task {
                        await imageService.clearCache()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all locally stored notes and images. Your data will be restored from the server on next sync.")
            }
            .task {
                notificationsEnabled = await notificationService.isAuthorized()
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var lastSyncText: String {
        guard let lastSync = syncService.lastSyncTime else {
            return "Never"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastSync, relativeTo: Date())
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func performSync() async {
        isSyncing = true
        do {
            try await syncService.sync()
        } catch {
            // Sync errors are handled silently for now
        }
        isSyncing = false
    }
}

#Preview {
    SettingsView(authViewModel: AuthViewModel())
}
