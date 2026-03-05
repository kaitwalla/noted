import Foundation
import AppKit
import SwiftUI

/// Shared markdown-to-AttributedString converter for live styling
/// Keeps markers visible while applying styling (inline preview mode)
enum MarkdownParser {

    // MARK: - Patterns

    // Headers at start of line
    private static let h1Pattern = try! NSRegularExpression(pattern: #"^(# .+)$"#, options: [.anchorsMatchLines])
    private static let h2Pattern = try! NSRegularExpression(pattern: #"^(## .+)$"#, options: [.anchorsMatchLines])
    private static let h3Pattern = try! NSRegularExpression(pattern: #"^(### .+)$"#, options: [.anchorsMatchLines])

    // Inline styles - match including markers
    private static let boldPattern = try! NSRegularExpression(pattern: #"\*\*(.+?)\*\*"#, options: [])
    private static let italicPattern = try! NSRegularExpression(pattern: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, options: [])
    private static let inlineCodePattern = try! NSRegularExpression(pattern: #"`([^`\n]+)`"#, options: [])
    private static let strikethroughPattern = try! NSRegularExpression(pattern: #"~~(.+?)~~"#, options: [])

    // Code blocks (``` ... ```)
    private static let codeBlockPattern = try! NSRegularExpression(pattern: #"```[\s\S]*?```"#, options: [])

    // MARK: - Public API

    /// Converts markdown text to NSAttributedString for NSTextView
    /// Keeps markers visible while applying styling
    static func attributedString(
        from text: String,
        baseFont: NSFont = .systemFont(ofSize: NSFont.systemFontSize),
        textColor: NSColor = .labelColor
    ) -> NSAttributedString {
        // Create paragraph style with increased line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 2

        let mutableString = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: baseFont,
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ]
        )

        let fullRange = NSRange(location: 0, length: text.utf16.count)

        // Apply styles (order matters - code blocks first to prevent inner parsing)
        applyCodeBlockStyle(to: mutableString, in: fullRange, baseFont: baseFont)
        applyHeaderStyles(to: mutableString, in: fullRange, baseFont: baseFont)
        applyInlineCodeStyle(to: mutableString, in: fullRange, baseFont: baseFont)
        applyBoldStyle(to: mutableString, in: fullRange, baseFont: baseFont)
        applyItalicStyle(to: mutableString, in: fullRange, baseFont: baseFont)
        applyStrikethroughStyle(to: mutableString, in: fullRange)

        return mutableString
    }

    /// Converts markdown text to SwiftUI AttributedString
    /// - Parameters:
    ///   - text: The markdown text to parse
    ///   - baseFont: The base font to use (defaults to body)
    ///   - textColor: The base text color (defaults to primary)
    static func swiftUIAttributedString(
        from text: String,
        baseFont: Font = .body,
        textColor: Color = .primary
    ) -> AttributedString {
        do {
            var attributed = try AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
            // Apply base styling to the entire string
            attributed.font = baseFont
            attributed.foregroundColor = textColor
            return attributed
        } catch {
            var attributed = AttributedString(text)
            attributed.font = baseFont
            attributed.foregroundColor = textColor
            return attributed
        }
    }

    // MARK: - Header Styles

    private static func applyHeaderStyles(
        to attributedString: NSMutableAttributedString,
        in range: NSRange,
        baseFont: NSFont
    ) {
        let text = attributedString.string

        // H1 - largest with extra spacing
        let h1Style = NSMutableParagraphStyle()
        h1Style.lineSpacing = 4
        h1Style.paragraphSpacingBefore = 12
        h1Style.paragraphSpacing = 8
        let h1Font = NSFont.systemFont(ofSize: baseFont.pointSize * 1.5, weight: .bold)
        applyPattern(h1Pattern, to: attributedString, in: range, text: text, attributes: [
            .font: h1Font,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: h1Style
        ])

        // H2 - medium with spacing
        let h2Style = NSMutableParagraphStyle()
        h2Style.lineSpacing = 4
        h2Style.paragraphSpacingBefore = 10
        h2Style.paragraphSpacing = 6
        let h2Font = NSFont.systemFont(ofSize: baseFont.pointSize * 1.3, weight: .semibold)
        applyPattern(h2Pattern, to: attributedString, in: range, text: text, attributes: [
            .font: h2Font,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: h2Style
        ])

        // H3 - small with spacing
        let h3Style = NSMutableParagraphStyle()
        h3Style.lineSpacing = 4
        h3Style.paragraphSpacingBefore = 8
        h3Style.paragraphSpacing = 4
        let h3Font = NSFont.systemFont(ofSize: baseFont.pointSize * 1.15, weight: .semibold)
        applyPattern(h3Pattern, to: attributedString, in: range, text: text, attributes: [
            .font: h3Font,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: h3Style
        ])
    }

    // MARK: - Code Block Style

    private static func applyCodeBlockStyle(
        to attributedString: NSMutableAttributedString,
        in range: NSRange,
        baseFont: NSFont
    ) {
        let text = attributedString.string
        let monoFont = NSFont.monospacedSystemFont(ofSize: baseFont.pointSize * 0.9, weight: .regular)

        applyPattern(codeBlockPattern, to: attributedString, in: range, text: text, attributes: [
            .font: monoFont,
            .foregroundColor: NSColor.secondaryLabelColor,
            .backgroundColor: NSColor.quaternaryLabelColor
        ])
    }

    // MARK: - Inline Styles

    private static func applyInlineCodeStyle(
        to attributedString: NSMutableAttributedString,
        in range: NSRange,
        baseFont: NSFont
    ) {
        let text = attributedString.string
        let monoFont = NSFont.monospacedSystemFont(ofSize: baseFont.pointSize * 0.9, weight: .regular)

        // Skip ranges that are already in code blocks
        applyPatternSkippingCodeBlocks(inlineCodePattern, to: attributedString, in: range, text: text, attributes: [
            .font: monoFont,
            .foregroundColor: NSColor.systemPink,
            .backgroundColor: NSColor.quaternaryLabelColor
        ])
    }

    private static func applyBoldStyle(
        to attributedString: NSMutableAttributedString,
        in range: NSRange,
        baseFont: NSFont
    ) {
        let text = attributedString.string
        let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)

        applyPatternSkippingCodeBlocks(boldPattern, to: attributedString, in: range, text: text, attributes: [
            .font: boldFont
        ])
    }

    private static func applyItalicStyle(
        to attributedString: NSMutableAttributedString,
        in range: NSRange,
        baseFont: NSFont
    ) {
        let text = attributedString.string
        let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)

        applyPatternSkippingCodeBlocks(italicPattern, to: attributedString, in: range, text: text, attributes: [
            .font: italicFont
        ])
    }

    private static func applyStrikethroughStyle(
        to attributedString: NSMutableAttributedString,
        in range: NSRange
    ) {
        let text = attributedString.string

        applyPatternSkippingCodeBlocks(strikethroughPattern, to: attributedString, in: range, text: text, attributes: [
            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            .strikethroughColor: NSColor.secondaryLabelColor,
            .foregroundColor: NSColor.secondaryLabelColor
        ])
    }

    // MARK: - Helpers

    /// Applies attributes to all matches of a pattern (keeps original text, just styles it)
    private static func applyPattern(
        _ pattern: NSRegularExpression,
        to attributedString: NSMutableAttributedString,
        in range: NSRange,
        text: String,
        attributes: [NSAttributedString.Key: Any]
    ) {
        let matches = pattern.matches(in: text, options: [], range: range)
        for match in matches {
            let matchRange = match.range(at: 0)
            guard matchRange.location != NSNotFound else { continue }
            attributedString.addAttributes(attributes, range: matchRange)
        }
    }

    /// Applies attributes to matches, but skips any that overlap with code blocks
    private static func applyPatternSkippingCodeBlocks(
        _ pattern: NSRegularExpression,
        to attributedString: NSMutableAttributedString,
        in range: NSRange,
        text: String,
        attributes: [NSAttributedString.Key: Any]
    ) {
        // Find all code block ranges to skip
        let codeBlockRanges = codeBlockPattern.matches(in: text, options: [], range: range).map { $0.range(at: 0) }

        let matches = pattern.matches(in: text, options: [], range: range)
        for match in matches {
            let matchRange = match.range(at: 0)
            guard matchRange.location != NSNotFound else { continue }

            // Skip if this match is inside a code block
            let isInCodeBlock = codeBlockRanges.contains { codeRange in
                let matchStart = matchRange.location
                let matchEnd = matchRange.location + matchRange.length
                let codeStart = codeRange.location
                let codeEnd = codeRange.location + codeRange.length
                return matchStart >= codeStart && matchEnd <= codeEnd
            }

            if !isInCodeBlock {
                attributedString.addAttributes(attributes, range: matchRange)
            }
        }
    }
}
