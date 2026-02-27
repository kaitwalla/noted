import PhotosUI
import SwiftUI
import UIKit

struct ImagePickerButton: View {
    let onImageSelected: (UIImage) -> Void

    @State private var showingOptions = false
    @State private var showingCamera = false
    @State private var selectedItem: PhotosPickerItem?

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        Menu {
            if isCameraAvailable {
                Button {
                    showingCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }
            }

            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
            }
        } label: {
            Image(systemName: "photo")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView { image in
                onImageSelected(image)
            }
        }
        .onChange(of: selectedItem) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        onImageSelected(image)
                    }
                }
            }
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    ImagePickerButton { _ in
        // Preview handler
    }
}
