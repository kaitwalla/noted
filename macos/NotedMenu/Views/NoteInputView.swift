import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Compact note input at the bottom of the note stream
struct NoteInputView: View {
    let notebookId: UUID
    var onNoteSent: () -> Void

    @Environment(\.themeColors) var themeColors
    @State private var noteText = ""
    @State private var pendingImages: [PendingImage] = []
    @State private var keepFullSize = false
    @State private var isSending = false
    @State private var isDragging = false
    @State private var error: String?
    @State private var focusTrigger: UUID? = nil

    var body: some View {
        VStack(spacing: 8) {
            // Error message
            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(themeColors.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Pending images preview
            if !pendingImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(pendingImages.enumerated()), id: \.element.id) { index, pending in
                            ZStack(alignment: .topTrailing) {
                                Image(nsImage: pending.image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))

                                Button {
                                    removeImage(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.6)))
                                }
                                .buttonStyle(.plain)
                                .offset(x: 4, y: -4)
                            }
                        }

                        Toggle(isOn: $keepFullSize) {
                            Text("Full")
                                .font(.caption2)
                        }
                        .toggleStyle(.checkbox)
                        .controlSize(.small)
                    }
                }
            }

            // Input row
            HStack(spacing: 8) {
                // Image picker button
                Button {
                    openImagePicker()
                } label: {
                    Image(systemName: isDragging ? "photo.badge.plus" : "photo")
                        .font(.system(size: 18))
                        .foregroundColor(isDragging ? themeColors.accent : themeColors.secondaryText)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isDragging ? themeColors.accent.opacity(0.15) : themeColors.tertiaryBackground)
                        )
                }
                .buttonStyle(.plain)
                .help("Add image")
                .onDrop(of: [.image, .fileURL], isTargeted: $isDragging) { providers in
                    handleDrop(providers: providers)
                    return true
                }

                // Text input with markdown
                MarkdownTextView(
                    text: $noteText,
                    font: .systemFont(ofSize: 13),
                    textColor: themeColors.nsText,
                    focusTrigger: focusTrigger,
                    onCommit: sendNote
                )
                .frame(height: 36)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeColors.tertiaryBackground)
                )

                // Send button
                Button {
                    sendNote()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(canSend ? themeColors.accent : themeColors.secondaryText)
                }
                .buttonStyle(.plain)
                .disabled(!canSend || isSending)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(themeColors.background)
    }

    private var canSend: Bool {
        !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingImages.isEmpty
    }

    private func sendNote() {
        guard canSend, !isSending else { return }

        isSending = true
        error = nil

        Task {
            do {
                let hasText = !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let content = hasText ? noteText : ""

                let request = NoteCreateRequest(
                    content: .text(content),
                    plainText: content,
                    isTodo: false,
                    isDone: false
                )

                let note: Note = try await APIService.shared.post(
                    "notebooks/\(notebookId.uuidString)/notes",
                    body: request
                )

                // Upload images
                for pending in pendingImages {
                    let imageData: Data
                    if keepFullSize {
                        imageData = pending.data
                    } else {
                        imageData = ImageProcessor.resizeImageIfNeeded(pending.image, pending.data)
                    }

                    _ = try await APIService.shared.uploadImage(
                        imageData,
                        filename: "image.jpg",
                        noteId: note.id,
                        keepFullSize: keepFullSize
                    )
                }

                // Clear and notify
                await MainActor.run {
                    noteText = ""
                    pendingImages.removeAll()
                    keepFullSize = false
                    isSending = false
                    onNoteSent()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isSending = false
                }
            }
        }
    }

    private func removeImage(at index: Int) {
        guard index < pendingImages.count else { return }
        pendingImages.remove(at: index)
    }

    private func openImagePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image, .jpeg, .png, .gif, .heic]

        if panel.runModal() == .OK {
            let images = panel.urls.compactMap { NSImage(contentsOf: $0) }
            addImages(images)
        }
    }

    private func addImages(_ images: [NSImage]) {
        for image in images {
            if let data = ImageProcessor.imageToJpegData(image) {
                pendingImages.append(PendingImage(image: image, data: data))
            }
        }
        // Restore focus to text input after adding images
        focusTrigger = UUID()
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadObject(ofClass: NSImage.self) { image, _ in
                    if let nsImage = image as? NSImage {
                        Task { @MainActor in
                            addImages([nsImage])
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        Task { @MainActor in
                            if let image = NSImage(contentsOf: url) {
                                addImages([image])
                            }
                        }
                    }
                }
            }
        }
    }
}
