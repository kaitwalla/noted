import SwiftUI
import AppKit

/// iMessage-style link preview card
struct LinkPreviewCard: View {
    let preview: LinkPreview

    @Environment(\.themeColors) var themeColors
    @State private var previewImage: NSImage?
    @State private var faviconImage: NSImage?

    var body: some View {
        Link(destination: URL(string: preview.url) ?? URL(string: "about:blank")!) {
            VStack(alignment: .leading, spacing: 0) {
                // Preview image
                if let image = previewImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipped()
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Site header with favicon
                    HStack(spacing: 4) {
                        if let favicon = faviconImage {
                            Image(nsImage: favicon)
                                .resizable()
                                .frame(width: 12, height: 12)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                        }

                        if let siteName = preview.siteName {
                            Text(siteName.uppercased())
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(themeColors.secondaryText)
                                .lineLimit(1)
                        }
                    }

                    // Title
                    if let title = preview.title {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(themeColors.text)
                            .lineLimit(2)
                    }

                    // Description
                    if let description = preview.description {
                        Text(description)
                            .font(.system(size: 12))
                            .foregroundColor(themeColors.secondaryText)
                            .lineLimit(2)
                    }
                }
                .padding(10)
            }
            .background(themeColors.tertiaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(themeColors.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 280)
        .onAppear {
            loadImages()
        }
    }

    private func loadImages() {
        // Load preview image
        if let imageUrlString = preview.imageUrl,
           let url = URL(string: imageUrlString) {
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = NSImage(data: data) {
                        await MainActor.run {
                            previewImage = image
                        }
                    }
                } catch {
                    // Silently fail - image is optional
                }
            }
        }

        // Load favicon
        if let faviconUrlString = preview.faviconUrl,
           let url = URL(string: faviconUrlString) {
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = NSImage(data: data) {
                        await MainActor.run {
                            faviconImage = image
                        }
                    }
                } catch {
                    // Silently fail - favicon is optional
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        LinkPreviewCard(preview: LinkPreview(
            id: UUID(),
            url: "https://example.com",
            title: "Example Website - A Great Place to Visit",
            description: "This is a description of the example website that provides useful information.",
            imageUrl: nil,
            faviconUrl: nil,
            siteName: "example.com"
        ))

        LinkPreviewCard(preview: LinkPreview(
            id: UUID(),
            url: "https://github.com",
            title: "GitHub: Let's build from here",
            description: "GitHub is where over 100 million developers shape the future of software.",
            imageUrl: nil,
            faviconUrl: nil,
            siteName: "github.com"
        ))
    }
    .padding()
    .background(Color.black)
}
