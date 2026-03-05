import Foundation
import AppKit

/// Manages local image caching with LRU eviction
@MainActor
final class ImageCacheService {
    static let shared = ImageCacheService()

    /// Maximum cache size in bytes (500MB)
    private let maxCacheSize: Int64 = 500 * 1024 * 1024

    /// Directory for cached images
    private var cacheDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let cacheDir = appSupport.appendingPathComponent("NotedMenu/Images", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        return cacheDir
    }

    private init() {}

    // MARK: - Save Image

    /// Save image data to cache and return the local path
    /// - Parameters:
    ///   - data: Image data to save
    ///   - filename: Original filename
    /// - Returns: Local path relative to cache directory
    func saveImage(_ data: Data, filename: String) throws -> String {
        let uuid = UUID().uuidString
        let ext = (filename as NSString).pathExtension.isEmpty ? "jpg" : (filename as NSString).pathExtension
        let localFilename = "\(uuid).\(ext)"

        let fileURL = cacheDirectory.appendingPathComponent(localFilename)
        try data.write(to: fileURL)

        // Update access time for LRU
        try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)

        // Check cache size and evict if needed
        try evictIfNeeded()

        return localFilename
    }

    /// Save image data for a specific note
    /// - Parameters:
    ///   - data: Image data to save
    ///   - noteId: Note ID this image belongs to
    ///   - filename: Original filename
    /// - Returns: Local path relative to cache directory
    func saveImage(_ data: Data, noteId: UUID, filename: String) throws -> String {
        // Use note ID as prefix for easier cleanup
        let uuid = UUID().uuidString
        let ext = (filename as NSString).pathExtension.isEmpty ? "jpg" : (filename as NSString).pathExtension
        let localFilename = "\(noteId.uuidString)_\(uuid).\(ext)"

        let fileURL = cacheDirectory.appendingPathComponent(localFilename)
        try data.write(to: fileURL)

        // Update access time for LRU
        try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)

        // Check cache size and evict if needed
        try evictIfNeeded()

        return localFilename
    }

    // MARK: - Load Image

    /// Get the full URL for a local path
    func getImageURL(localPath: String) -> URL {
        return cacheDirectory.appendingPathComponent(localPath)
    }

    /// Load image from cache
    /// - Parameter localPath: Local path relative to cache directory
    /// - Returns: NSImage if found, nil otherwise
    func loadImage(localPath: String) -> NSImage? {
        let fileURL = cacheDirectory.appendingPathComponent(localPath)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        // Update access time for LRU
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)

        return NSImage(contentsOf: fileURL)
    }

    /// Load image data from cache
    /// - Parameter localPath: Local path relative to cache directory
    /// - Returns: Image data if found, nil otherwise
    func loadImageData(localPath: String) -> Data? {
        let fileURL = cacheDirectory.appendingPathComponent(localPath)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        // Update access time for LRU
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)

        return try? Data(contentsOf: fileURL)
    }

    /// Check if an image exists in cache
    func imageExists(localPath: String) -> Bool {
        let fileURL = cacheDirectory.appendingPathComponent(localPath)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    // MARK: - Download and Cache

    /// Download an image from URL and cache it
    /// - Parameters:
    ///   - url: Remote image URL
    ///   - noteId: Note ID this image belongs to
    /// - Returns: Local path if successful, nil otherwise
    func downloadAndCache(url: URL, noteId: UUID) async -> String? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }

            let filename = url.lastPathComponent.isEmpty ? "image.jpg" : url.lastPathComponent
            return try saveImage(data, noteId: noteId, filename: filename)

        } catch {
            return nil
        }
    }

    // MARK: - Delete

    /// Delete a cached image
    func deleteImage(localPath: String) {
        let fileURL = cacheDirectory.appendingPathComponent(localPath)
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Delete all cached images for a note
    func deleteImagesForNote(noteId: UUID) {
        let prefix = noteId.uuidString

        guard let files = try? FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path) else {
            return
        }

        for file in files where file.hasPrefix(prefix) {
            let fileURL = cacheDirectory.appendingPathComponent(file)
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    // MARK: - Cache Management

    /// Get current cache size in bytes
    func getCacheSize() -> Int64 {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path) else {
            return 0
        }

        var totalSize: Int64 = 0
        for file in files {
            let fileURL = cacheDirectory.appendingPathComponent(file)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let size = attrs[.size] as? Int64 {
                totalSize += size
            }
        }

        return totalSize
    }

    /// Evict oldest files if cache exceeds size limit
    private func evictIfNeeded() throws {
        var currentSize = getCacheSize()

        guard currentSize > maxCacheSize else { return }

        // Get all files with modification dates
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path) else {
            return
        }

        var filesWithDates: [(url: URL, date: Date, size: Int64)] = []

        for file in files {
            let fileURL = cacheDirectory.appendingPathComponent(file)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let modDate = attrs[.modificationDate] as? Date,
               let size = attrs[.size] as? Int64 {
                filesWithDates.append((fileURL, modDate, size))
            }
        }

        // Sort by date (oldest first)
        filesWithDates.sort { $0.date < $1.date }

        // Get pending image paths that shouldn't be evicted
        let pendingPaths = Set((try? LocalDataStore.shared.fetchPendingImages().compactMap { $0.localPath }) ?? [])

        // Evict oldest files until under limit
        for fileInfo in filesWithDates {
            guard currentSize > maxCacheSize else { break }

            let filename = fileInfo.url.lastPathComponent

            // Don't evict pending uploads
            if pendingPaths.contains(filename) {
                continue
            }

            try? FileManager.default.removeItem(at: fileInfo.url)
            currentSize -= fileInfo.size
        }
    }

    /// Clear entire cache
    func clearCache() {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path) else {
            return
        }

        // Get pending image paths that shouldn't be deleted
        let pendingPaths = Set((try? LocalDataStore.shared.fetchPendingImages().compactMap { $0.localPath }) ?? [])

        for file in files {
            // Don't delete pending uploads
            if pendingPaths.contains(file) {
                continue
            }

            let fileURL = cacheDirectory.appendingPathComponent(file)
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Get formatted cache size string
    func getFormattedCacheSize() -> String {
        let size = getCacheSize()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
