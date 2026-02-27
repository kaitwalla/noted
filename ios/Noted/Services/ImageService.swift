import Foundation
import UIKit

actor ImageService {
    static let shared = ImageService()

    private let api = APIService.shared
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let backgroundQueue = DispatchQueue(label: "com.noted.imageCache", qos: .utility)

    #if DEBUG
    private let baseURL = URL(string: "http://localhost:8080/api")!
    #else
    private let baseURL = URL(string: "https://api.noted.app/api")!
    #endif

    nonisolated private var cacheDirectory: URL {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("images", isDirectory: true)
    }

    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB

        // Create cache directory
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Upload

    func uploadImage(_ image: UIImage, noteId: UUID) async throws -> NoteImage {
        // Critical: Check authentication before upload
        guard let token = api.authToken else {
            throw ImageError.unauthorized
        }

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ImageError.compressionFailed
        }

        let boundary = UUID().uuidString
        let url = baseURL.appendingPathComponent("images")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Build multipart body without force unwraps
        var body = Data()
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"note_id\"\r\n\r\n")
        body.appendString("\(noteId.uuidString)\r\n")
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n")
        body.appendString("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.appendString("\r\n")
        body.appendString("--\(boundary)--\r\n")

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw ImageError.unauthorized
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: nil)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let noteImage = try decoder.decode(NoteImage.self, from: data)

        // Cache the uploaded image
        cache.setObject(image, forKey: noteImage.id.uuidString as NSString)
        await saveToFileCacheAsync(image, id: noteImage.id)

        return noteImage
    }

    // MARK: - Fetch Images for Note

    nonisolated func fetchImages(noteId: UUID) async throws -> [NoteImage] {
        try await APIService.shared.get("notes/\(noteId.uuidString)/images")
    }

    // MARK: - Download

    func downloadImage(id: UUID) async throws -> UIImage {
        // Check memory cache
        if let cached = cache.object(forKey: id.uuidString as NSString) {
            return cached
        }

        // Check file cache
        if let fileImage = loadFromFileCache(id: id) {
            cache.setObject(fileImage, forKey: id.uuidString as NSString)
            return fileImage
        }

        // Download from server
        let url = baseURL.appendingPathComponent("images/\(id.uuidString)")

        var request = URLRequest(url: url)
        if let token = api.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: nil)
        }

        guard let image = UIImage(data: data) else {
            throw ImageError.invalidImageData
        }

        // Cache the image
        cache.setObject(image, forKey: id.uuidString as NSString)
        await saveToFileCacheAsync(image, id: id)

        return image
    }

    // MARK: - Download from URL

    func downloadImage(from urlString: String, id: UUID) async throws -> UIImage {
        // Check memory cache
        if let cached = cache.object(forKey: id.uuidString as NSString) {
            return cached
        }

        // Check file cache
        if let fileImage = loadFromFileCache(id: id) {
            cache.setObject(fileImage, forKey: id.uuidString as NSString)
            return fileImage
        }

        // Download from URL
        guard let url = URL(string: urlString) else {
            throw ImageError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: nil)
        }

        guard let image = UIImage(data: data) else {
            throw ImageError.invalidImageData
        }

        // Cache the image
        cache.setObject(image, forKey: id.uuidString as NSString)
        await saveToFileCacheAsync(image, id: id)

        return image
    }

    // MARK: - Cache Management

    func getCachedImage(id: UUID) -> UIImage? {
        if let cached = cache.object(forKey: id.uuidString as NSString) {
            return cached
        }

        if let fileImage = loadFromFileCache(id: id) {
            cache.setObject(fileImage, forKey: id.uuidString as NSString)
            return fileImage
        }

        return nil
    }

    func clearCache() {
        cache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Private

    private func saveToFileCacheAsync(_ image: UIImage, id: UUID) async {
        // Perform file I/O on background queue to avoid blocking
        await withCheckedContinuation { continuation in
            backgroundQueue.async { [self] in
                guard let data = image.jpegData(compressionQuality: 0.9) else {
                    continuation.resume()
                    return
                }
                let fileURL = cacheDirectory.appendingPathComponent("\(id.uuidString).jpg")
                try? data.write(to: fileURL)
                continuation.resume()
            }
        }
    }

    private func loadFromFileCache(id: UUID) -> UIImage? {
        let fileURL = cacheDirectory.appendingPathComponent("\(id.uuidString).jpg")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - Data Extension for Safe String Appending

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

enum ImageError: Error, LocalizedError {
    case compressionFailed
    case invalidImageData
    case invalidURL
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .invalidImageData:
            return "Invalid image data received"
        case .invalidURL:
            return "Invalid image URL"
        case .unauthorized:
            return "Please sign in to upload images"
        }
    }
}
