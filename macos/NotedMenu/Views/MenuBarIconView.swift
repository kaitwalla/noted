import SwiftUI
import AppKit

extension Notification.Name {
    static let menuBarIconDidChange = Notification.Name("menuBarIconDidChange")
}

enum MenuBarIconStyle: String, CaseIterable, Identifiable {
    case noteSwirl = "Note Swirl"
    case messageLines = "Message Lines"
    case messageDots = "Message Dots"
    case messageDot = "Message Dot"

    var id: String { rawValue }

    static var `default`: MenuBarIconStyle { .noteSwirl }

    /// The asset name in the asset catalog
    var assetName: String {
        switch self {
        case .noteSwirl: return "NoteSwirl"
        case .messageLines: return "MessageLines"
        case .messageDots: return "MessageDots"
        case .messageDot: return "MessageDot"
        }
    }
}

// MARK: - SwiftUI Preview View
struct MenuBarIconView: View {
    let style: MenuBarIconStyle
    let size: CGFloat

    init(style: MenuBarIconStyle, size: CGFloat = 18) {
        self.style = style
        self.size = size
    }

    var body: some View {
        Image(style.assetName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}

// MARK: - NSImage Extension
extension MenuBarIconStyle {
    @MainActor
    func createMenuBarImage() -> NSImage {
        guard let image = NSImage(named: assetName) else {
            // Fallback to system image if asset not found
            return NSImage(systemSymbolName: "note.text", accessibilityDescription: "Noted") ?? NSImage()
        }
        image.isTemplate = true
        return image
    }
}
