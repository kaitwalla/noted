import Foundation
import AppKit

/// Shared image processing utilities for note images
enum ImageProcessor {

    /// Default maximum dimension for resized images
    static let defaultMaxDimension: CGFloat = 2000

    /// Converts an NSImage to JPEG data
    /// - Parameter image: The image to convert
    /// - Returns: JPEG data or nil if conversion fails
    static func imageToJpegData(_ image: NSImage) -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    }

    /// Resizes an image if it exceeds the maximum dimension
    /// - Parameters:
    ///   - image: The image to potentially resize
    ///   - originalData: The original JPEG data
    ///   - maxDimension: Maximum width or height (defaults to 2000)
    /// - Returns: Original data if within bounds, otherwise resized JPEG data
    static func resizeImageIfNeeded(
        _ image: NSImage,
        _ originalData: Data,
        maxDimension: CGFloat = defaultMaxDimension
    ) -> Data {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else {
            return originalData
        }

        let scale = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)

        // Verify image is valid before resizing
        guard image.cgImage(forProposedRect: nil, context: nil, hints: nil) != nil else {
            return originalData
        }

        let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(newSize.width),
            pixelsHigh: Int(newSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )

        guard let bitmapRep = bitmapRep else {
            return originalData
        }

        bitmapRep.size = newSize
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        NSGraphicsContext.current?.imageInterpolation = .high

        let destRect = NSRect(origin: .zero, size: newSize)
        let sourceRect = NSRect(origin: .zero, size: size)
        image.draw(in: destRect, from: sourceRect, operation: .copy, fraction: 1.0)

        NSGraphicsContext.restoreGraphicsState()

        if let data = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) {
            return data
        }
        return originalData
    }
}
