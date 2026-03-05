import SwiftUI
import AppKit
import os.log

private let logger = Logger(subsystem: "dev.kait.noted", category: "NoteBubbleView")

// MARK: - Static Date Formatters

private enum DateFormatters {
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    static let dayAndTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, h:mm a"
        return formatter
    }()

    static let dateAndTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter
    }()
}

/// Individual note display with markdown rendering and images
struct NoteBubbleView: View {
    let note: Note
    let images: [NoteImage]
    var onCheckboxToggle: ((String) -> Void)?

    @Environment(\.themeColors) var themeColors
    @State private var loadedImages: [UUID: NSImage] = [:]
    @State private var imageLoadTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Todo checkbox + content
            HStack(alignment: .top, spacing: 8) {
                if note.isTodo {
                    Image(systemName: note.isDone ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(note.isDone ? themeColors.success : themeColors.secondaryText)
                        .font(.system(size: 14))
                }

                VStack(alignment: .leading, spacing: 4) {
                    // Note content with markdown (interactive checkboxes)
                    if !note.plainText.isEmpty && note.plainText != "[image]" {
                        MarkdownContentView(
                            text: note.plainText,
                            textColor: Color(note.isDone ? themeColors.secondaryText : themeColors.text),
                            onCheckboxToggle: onCheckboxToggle
                        )
                        .strikethrough(note.isDone)
                    }

                    // Images
                    if !images.isEmpty {
                        imageGrid
                    }

                    // Link previews
                    if let previews = note.linkPreviews, !previews.isEmpty {
                        ForEach(previews) { preview in
                            LinkPreviewCard(preview: preview)
                        }
                    }
                }
            }

            // Timestamp
            Text(formatDate(note.createdAt))
                .font(.caption2)
                .foregroundColor(themeColors.secondaryText)
        }
        .padding(10)
        .background(themeColors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .task(id: images.map(\.id)) {
            await loadImages()
        }
        .onDisappear {
            // Cancel pending image loads and release memory
            imageLoadTask?.cancel()
            loadedImages.removeAll()
        }
    }

    @ViewBuilder
    private var imageGrid: some View {
        let columns = [
            GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 4)
        ]

        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(images) { image in
                if let nsImage = loadedImages[image.id] {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 60, maxWidth: 120, minHeight: 60, maxHeight: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.5)
                        )
                }
            }
        }
    }

    private func loadImages() async {
        // Load images in parallel
        await withTaskGroup(of: (UUID, NSImage?).self) { group in
            for image in images {
                guard loadedImages[image.id] == nil,
                      let urlString = image.url,
                      let url = URL(string: urlString) else { continue }

                group.addTask {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        return (image.id, NSImage(data: data))
                    } catch {
                        logger.warning("Failed to load image \(image.id): \(error.localizedDescription)")
                        return (image.id, nil)
                    }
                }
            }

            for await (imageId, nsImage) in group {
                if let nsImage = nsImage {
                    loadedImages[imageId] = nsImage
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return DateFormatters.timeOnly.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday, \(DateFormatters.timeOnly.string(from: date))"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            return DateFormatters.dayAndTime.string(from: date)
        } else {
            return DateFormatters.dateAndTime.string(from: date)
        }
    }
}
