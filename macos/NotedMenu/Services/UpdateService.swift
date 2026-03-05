import Foundation
import AppKit
import Sparkle

/// Manages app updates using Sparkle framework
@MainActor
final class UpdateService: NSObject, ObservableObject {
    static let shared = UpdateService()

    /// The Sparkle updater controller
    private var updaterController: SPUStandardUpdaterController!

    /// Published state for UI binding
    @Published var canCheckForUpdates = false
    @Published var lastUpdateCheckDate: Date?
    @Published var automaticallyChecksForUpdates: Bool = true {
        didSet {
            updaterController.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        }
    }

    /// Current app version
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// Current build number
    var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private override init() {
        super.init()

        // Initialize Sparkle updater
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        // Sync initial state
        automaticallyChecksForUpdates = updaterController.updater.automaticallyChecksForUpdates

        // Observe canCheckForUpdates
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)

        // Observe lastUpdateCheckDate
        updaterController.updater.publisher(for: \.lastUpdateCheckDate)
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastUpdateCheckDate)
    }

    /// Check for updates (user-initiated)
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    /// Get the underlying updater for menu integration
    var updater: SPUUpdater {
        updaterController.updater
    }
}

// MARK: - SwiftUI Menu Integration

import SwiftUI

/// A SwiftUI view that wraps the Sparkle "Check for Updates" functionality
struct CheckForUpdatesView: View {
    @ObservedObject private var updateService = UpdateService.shared

    var body: some View {
        Button("Check for Updates...") {
            updateService.checkForUpdates()
        }
        .disabled(!updateService.canCheckForUpdates)
    }
}
