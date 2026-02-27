import UIKit

final class HapticService {
    static let shared = HapticService()

    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() {
        // Prepare generators for responsiveness
        lightGenerator.prepare()
        mediumGenerator.prepare()
        selectionGenerator.prepare()
    }

    /// Light tap - for small UI interactions
    func lightTap() {
        lightGenerator.impactOccurred()
        lightGenerator.prepare()
    }

    /// Medium tap - for sending notes, confirming actions
    func mediumTap() {
        mediumGenerator.impactOccurred()
        mediumGenerator.prepare()
    }

    /// Heavy tap - for significant actions like delete
    func heavyTap() {
        heavyGenerator.impactOccurred()
        heavyGenerator.prepare()
    }

    /// Selection feedback - for toggling, selecting
    func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    /// Success notification - for successful operations
    func success() {
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }

    /// Warning notification
    func warning() {
        notificationGenerator.notificationOccurred(.warning)
        notificationGenerator.prepare()
    }

    /// Error notification
    func error() {
        notificationGenerator.notificationOccurred(.error)
        notificationGenerator.prepare()
    }
}
