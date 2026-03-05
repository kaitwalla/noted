import SwiftUI

/// Small indicator showing sync status for a note
struct SyncStatusIndicator: View {
    let status: SyncStatus
    @Environment(\.themeColors) var themeColors

    var body: some View {
        Image(systemName: status.iconName)
            .font(.system(size: 10))
            .foregroundColor(iconColor)
            .help(helpText)
    }

    private var iconColor: Color {
        switch status {
        case .synced:
            return themeColors.secondaryText
        case .pendingCreate, .pendingUpdate:
            return themeColors.accent
        case .pendingDelete:
            return themeColors.secondaryText
        case .conflict:
            return .orange
        }
    }

    private var helpText: String {
        switch status {
        case .synced:
            return "Synced"
        case .pendingCreate:
            return "Pending upload"
        case .pendingUpdate:
            return "Pending sync"
        case .pendingDelete:
            return "Pending deletion"
        case .conflict:
            return "Conflict - tap to resolve"
        }
    }
}

/// Larger sync status view for settings/status displays
struct SyncStatusView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.themeColors) var themeColors

    private let syncService = SyncService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: appViewModel.isOnline ? "wifi" : "wifi.slash")
                    .foregroundColor(appViewModel.isOnline ? .green : .orange)

                Text(appViewModel.isOnline ? "Online" : "Offline")
                    .font(.headline)
                    .foregroundColor(themeColors.text)

                Spacer()

                if appViewModel.isSyncing {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Syncing...")
                            .font(.caption)
                            .foregroundColor(themeColors.secondaryText)
                    }
                }
            }

            if appViewModel.pendingCount > 0 {
                HStack {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.caption)
                        .foregroundColor(themeColors.accent)
                    Text("\(appViewModel.pendingCount) pending changes")
                        .font(.caption)
                        .foregroundColor(themeColors.secondaryText)
                }
            }

            if appViewModel.hasConflicts {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Some notes have conflicts")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            if let lastSync = syncService.lastSyncTime {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(themeColors.secondaryText)
                    Text("Last sync: \(lastSync.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundColor(themeColors.secondaryText)
                }
            }

            if let error = syncService.lastError {
                HStack {
                    Image(systemName: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
            }

            // Manual sync button
            Button {
                Task {
                    await appViewModel.triggerSync()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Sync Now")
                }
            }
            .buttonStyle(.bordered)
            .disabled(!appViewModel.isOnline || appViewModel.isSyncing)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(themeColors.secondaryBackground)
        )
    }
}
