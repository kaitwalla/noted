import SwiftUI
import UIKit

// MARK: - Theme Definition

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case warmPaper = "Warm Paper"
    case hacker = "Hacker"
    case retrowave = "Retrowave"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .warmPaper: return "sun.max.fill"
        case .hacker: return "terminal.fill"
        case .retrowave: return "sparkles"
        }
    }

    var description: String {
        switch self {
        case .system: return "Follow system appearance"
        case .warmPaper: return "Warm sepia tones"
        case .hacker: return "Dark with green accents"
        case .retrowave: return "Neon purple & cyan"
        }
    }
}

// MARK: - Theme Colors

struct ThemeColors {
    let background: Color
    let secondaryBackground: Color
    let tertiaryBackground: Color
    let text: Color
    let secondaryText: Color
    let accent: Color
    let accentSecondary: Color
    let border: Color
    let success: Color
    let error: Color

    // UIColor versions for UIKit components
    var uiBackground: UIColor { UIColor(background) }
    var uiSecondaryBackground: UIColor { UIColor(secondaryBackground) }
    var uiTertiaryBackground: UIColor { UIColor(tertiaryBackground) }
    var uiText: UIColor { UIColor(text) }
    var uiSecondaryText: UIColor { UIColor(secondaryText) }
    var uiAccent: UIColor { UIColor(accent) }

    // Default system colors (used before ThemeManager is initialized)
    static let system = ThemeColors(
        background: Color(uiColor: .systemBackground),
        secondaryBackground: Color(uiColor: .secondarySystemBackground),
        tertiaryBackground: Color(uiColor: .tertiarySystemBackground),
        text: Color(uiColor: .label),
        secondaryText: Color(uiColor: .secondaryLabel),
        accent: Color.accentColor,
        accentSecondary: Color.accentColor.opacity(0.8),
        border: Color(uiColor: .separator),
        success: Color.green,
        error: Color.red
    )
}

// MARK: - Theme Manager

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private let themeKey = "selectedTheme"

    @Published var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: themeKey)
            updateAppearance()
        }
    }

    var colors: ThemeColors {
        ThemeManager.colors(for: currentTheme)
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: themeKey),
           let theme = AppTheme(rawValue: saved) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .system
        }
    }

    func updateAppearance() {
        // Update the window's user interface style
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        switch currentTheme {
        case .system:
            window.overrideUserInterfaceStyle = .unspecified
        case .warmPaper:
            window.overrideUserInterfaceStyle = .light
        case .hacker, .retrowave:
            window.overrideUserInterfaceStyle = .dark
        }
    }

    // MARK: - Theme Color Definitions

    static func colors(for theme: AppTheme) -> ThemeColors {
        switch theme {
        case .system:
            return systemColors

        case .warmPaper:
            return ThemeColors(
                background: Color(red: 0.98, green: 0.96, blue: 0.90),        // Cream
                secondaryBackground: Color(red: 0.95, green: 0.92, blue: 0.85), // Slightly darker cream
                tertiaryBackground: Color(red: 0.92, green: 0.88, blue: 0.80),  // Light tan
                text: Color(red: 0.25, green: 0.20, blue: 0.15),                // Dark brown
                secondaryText: Color(red: 0.45, green: 0.40, blue: 0.35),       // Medium brown
                accent: Color(red: 0.70, green: 0.45, blue: 0.25),              // Warm orange-brown
                accentSecondary: Color(red: 0.55, green: 0.35, blue: 0.20),     // Darker accent
                border: Color(red: 0.85, green: 0.80, blue: 0.70),              // Light brown border
                success: Color(red: 0.35, green: 0.55, blue: 0.30),             // Muted green
                error: Color(red: 0.75, green: 0.30, blue: 0.25)                // Muted red
            )

        case .hacker:
            return ThemeColors(
                background: Color(red: 0.05, green: 0.05, blue: 0.05),          // Near black
                secondaryBackground: Color(red: 0.08, green: 0.10, blue: 0.08), // Slightly green-tinted black
                tertiaryBackground: Color(red: 0.12, green: 0.15, blue: 0.12),  // Dark green-gray
                text: Color(red: 0.0, green: 0.90, blue: 0.0),                  // Bright green
                secondaryText: Color(red: 0.0, green: 0.60, blue: 0.0),         // Dimmer green
                accent: Color(red: 0.0, green: 1.0, blue: 0.0),                 // Pure green
                accentSecondary: Color(red: 0.0, green: 0.75, blue: 0.0),       // Slightly dimmer
                border: Color(red: 0.0, green: 0.30, blue: 0.0),                // Dark green
                success: Color(red: 0.0, green: 1.0, blue: 0.0),                // Bright green
                error: Color(red: 1.0, green: 0.3, blue: 0.3)                   // Red (contrast)
            )

        case .retrowave:
            return ThemeColors(
                background: Color(red: 0.08, green: 0.05, blue: 0.15),          // Deep purple-black
                secondaryBackground: Color(red: 0.12, green: 0.08, blue: 0.22), // Slightly lighter purple
                tertiaryBackground: Color(red: 0.18, green: 0.12, blue: 0.30),  // Purple
                text: Color(red: 1.0, green: 0.95, blue: 1.0),                  // Near white with pink tint
                secondaryText: Color(red: 0.75, green: 0.65, blue: 0.85),       // Soft lavender
                accent: Color(red: 1.0, green: 0.0, blue: 0.60),                // Hot pink
                accentSecondary: Color(red: 0.0, green: 0.90, blue: 0.90),      // Cyan
                border: Color(red: 0.50, green: 0.0, blue: 0.50),               // Purple
                success: Color(red: 0.0, green: 0.90, blue: 0.90),              // Cyan
                error: Color(red: 1.0, green: 0.2, blue: 0.4)                   // Hot pink-red
            )
        }
    }

    private static var systemColors: ThemeColors {
        ThemeColors(
            background: Color(uiColor: .systemBackground),
            secondaryBackground: Color(uiColor: .secondarySystemBackground),
            tertiaryBackground: Color(uiColor: .tertiarySystemBackground),
            text: Color(uiColor: .label),
            secondaryText: Color(uiColor: .secondaryLabel),
            accent: Color.accentColor,
            accentSecondary: Color.accentColor.opacity(0.8),
            border: Color(uiColor: .separator),
            success: Color.green,
            error: Color.red
        )
    }
}

// MARK: - Environment Key

private struct ThemeColorsKey: EnvironmentKey {
    static let defaultValue: ThemeColors = ThemeColors.system
}

extension EnvironmentValues {
    var themeColors: ThemeColors {
        get { self[ThemeColorsKey.self] }
        set { self[ThemeColorsKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    func themed() -> some View {
        self.environment(\.themeColors, ThemeManager.shared.colors)
    }
}
