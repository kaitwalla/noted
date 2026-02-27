import SwiftUI
import UIKit

struct ImageViewer: View {
    let image: UIImage
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero
    @State private var saveStatus: SaveStatus = .idle

    private enum SaveStatus: Equatable {
        case idle
        case saving
        case success
        case error(String)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(x: offset.width + dragOffset.width, y: offset.height + dragOffset.height)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale = min(max(scale * delta, 1), 5)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                if scale < 1.0 {
                                    withAnimation {
                                        scale = 1.0
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .updating($dragOffset) { value, state, _ in
                                if scale > 1 {
                                    state = value.translation
                                } else if abs(value.translation.height) > abs(value.translation.width) {
                                    state = CGSize(width: 0, height: value.translation.height)
                                }
                            }
                            .onEnded { value in
                                if scale > 1 {
                                    offset = CGSize(
                                        width: offset.width + value.translation.width,
                                        height: offset.height + value.translation.height
                                    )
                                } else if value.translation.height > 100 {
                                    onDismiss()
                                }
                            }
                    )
                    .gesture(
                        TapGesture(count: 2)
                            .onEnded {
                                withAnimation {
                                    if scale > 1 {
                                        scale = 1
                                        offset = .zero
                                    } else {
                                        scale = 2
                                    }
                                }
                            }
                    )
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding()
                }
            }
            .overlay(alignment: .bottom) {
                HStack(spacing: 20) {
                    Button {
                        saveImageToPhotos()
                    } label: {
                        HStack(spacing: 6) {
                            if case .saving = saveStatus {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            } else if case .success = saveStatus {
                                Image(systemName: "checkmark")
                            } else {
                                Image(systemName: "square.and.arrow.down")
                            }
                            Text(saveButtonText)
                        }
                        .font(.subheadline)
                    }
                    .disabled(saveStatus == .saving)

                    ShareLink(item: Image(uiImage: image), preview: SharePreview("Image", image: Image(uiImage: image))) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.subheadline)
                    }
                }
                .foregroundStyle(.white)
                .padding()
                .background(.ultraThinMaterial.opacity(0.5))
                .cornerRadius(12)
                .padding(.bottom, 40)
            }
            .overlay {
                if case .error(let message) = saveStatus {
                    VStack {
                        Spacer()
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                            .padding(.bottom, 120)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .statusBarHidden()
    }

    private var saveButtonText: String {
        switch saveStatus {
        case .idle: return "Save"
        case .saving: return "Saving..."
        case .success: return "Saved!"
        case .error: return "Save"
        }
    }

    private func saveImageToPhotos() {
        saveStatus = .saving
        HapticService.shared.lightTap()

        let imageSaver = ImageSaver { success, error in
            DispatchQueue.main.async {
                if success {
                    saveStatus = .success
                    HapticService.shared.success()
                    // Reset after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if case .success = saveStatus {
                            saveStatus = .idle
                        }
                    }
                } else {
                    let message = error?.localizedDescription ?? "Failed to save image"
                    saveStatus = .error(message)
                    HapticService.shared.error()
                    // Reset after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        if case .error = saveStatus {
                            saveStatus = .idle
                        }
                    }
                }
            }
        }
        imageSaver.saveImage(image)
    }
}

// Helper class to handle UIImageWriteToSavedPhotosAlbum callback
private class ImageSaver: NSObject {
    private let completion: (Bool, Error?) -> Void

    init(completion: @escaping (Bool, Error?) -> Void) {
        self.completion = completion
        super.init()
    }

    func saveImage(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }

    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer?) {
        completion(error == nil, error)
    }
}

struct ImageViewerSheet: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ImageViewer(image: image) {
            dismiss()
        }
    }
}

#Preview {
    ImageViewer(image: UIImage(systemName: "photo")!) {}
}
