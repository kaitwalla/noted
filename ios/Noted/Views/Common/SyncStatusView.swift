import SwiftUI

struct SyncStatusView: View {
    let syncService = SyncService.shared
    let networkMonitor = NetworkMonitor.shared

    @State private var lastSyncText: String = ""
    @State private var isSyncing = false

    var body: some View {
        HStack(spacing: 8) {
            // Connection status
            if !networkMonitor.isConnected {
                Label("Offline", systemImage: "wifi.slash")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if isSyncing {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Syncing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Label(lastSyncText, systemImage: "checkmark.icloud")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            updateLastSyncText()
        }
        .onChange(of: syncService.isSyncing) { _, newValue in
            isSyncing = newValue
            if !newValue {
                updateLastSyncText()
            }
        }
    }

    private func updateLastSyncText() {
        if let lastSync = syncService.lastSyncTime {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            lastSyncText = formatter.localizedString(for: lastSync, relativeTo: Date())
        } else {
            lastSyncText = "Not synced"
        }
    }
}

// Toolbar modifier for easy addition
struct SyncStatusToolbarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .status) {
                    SyncStatusView()
                }
            }
    }
}

extension View {
    func withSyncStatus() -> some View {
        modifier(SyncStatusToolbarModifier())
    }
}

#Preview {
    NavigationStack {
        Text("Content")
            .navigationTitle("Test")
            .withSyncStatus()
    }
}
