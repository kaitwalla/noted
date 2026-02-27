import Foundation
import SwiftUI
import UIKit

struct Tag: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var color: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, color
        case createdAt = "created_at"
    }

    var swiftUIColor: Color {
        guard let color = color else { return .accentColor }
        return Color(hex: color) ?? .accentColor
    }
}

struct TagCreateRequest: Codable {
    let name: String
    let color: String?
}

// Color extension for hex parsing
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
