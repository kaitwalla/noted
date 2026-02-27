import SwiftUI
import UIKit

struct AsyncNoteImage: View {
    let imageId: UUID
    let url: String?
    var maxHeight: CGFloat = 200

    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var showingFullScreen = false
    @State private var loadingTaskId: UUID?

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxHeight: maxHeight)
                    .clipped()
                    .cornerRadius(12)
                    .onTapGesture {
                        showingFullScreen = true
                    }
            } else if isLoading {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 150)
                    .overlay {
                        ProgressView()
                    }
            } else if loadFailed {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 100)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.secondary)
                            Text("Failed to load")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Retry") {
                                Task {
                                    await loadImage()
                                }
                            }
                            .font(.caption)
                        }
                    }
            }
        }
        .task(id: imageId) {
            // Task automatically cancelled when imageId changes
            await loadImage()
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            if let image = image {
                ImageViewerSheet(image: image)
            }
        }
    }

    private func loadImage() async {
        // Track this load operation
        let currentLoadId = imageId
        loadingTaskId = currentLoadId

        isLoading = true
        loadFailed = false
        image = nil

        // Check cache first (synchronous)
        if let cached = await ImageService.shared.getCachedImage(id: imageId) {
            // Verify we're still loading the same image
            guard loadingTaskId == currentLoadId else { return }
            image = cached
            isLoading = false
            return
        }

        do {
            let loadedImage: UIImage
            if let urlString = url, !urlString.isEmpty {
                loadedImage = try await ImageService.shared.downloadImage(from: urlString, id: imageId)
            } else {
                loadedImage = try await ImageService.shared.downloadImage(id: imageId)
            }

            // Verify we're still loading the same image (race condition protection)
            guard loadingTaskId == currentLoadId else { return }

            image = loadedImage
            isLoading = false
        } catch {
            // Verify we're still loading the same image
            guard loadingTaskId == currentLoadId else { return }

            isLoading = false
            loadFailed = true
            #if DEBUG
            print("Image load failed for \(imageId): \(error.localizedDescription)")
            #endif
        }
    }
}

#Preview {
    AsyncNoteImage(imageId: UUID(), url: nil)
        .padding()
}
