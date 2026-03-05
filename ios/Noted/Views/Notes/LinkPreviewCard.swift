import SwiftUI

/// iMessage-style link preview card for iOS
struct LinkPreviewCard: View {
    let preview: LinkPreview
    @Environment(\.themeColors) private var colors

    var body: some View {
        Link(destination: URL(string: preview.url) ?? URL(string: "about:blank")!) {
            VStack(alignment: .leading, spacing: 0) {
                // Preview image
                if let imageUrlString = preview.imageUrl,
                   let url = URL(string: imageUrlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 140)
                                .clipped()
                        case .failure:
                            EmptyView()
                        case .empty:
                            Rectangle()
                                .fill(colors.secondaryText.opacity(0.1))
                                .frame(height: 140)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.8)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                }

                // Content
                VStack(alignment: .leading, spacing: 6) {
                    // Site header with favicon
                    HStack(spacing: 6) {
                        if let faviconUrlString = preview.faviconUrl,
                           let url = URL(string: faviconUrlString) {
                            AsyncImage(url: url) { phase in
                                if case .success(let image) = phase {
                                    image
                                        .resizable()
                                        .frame(width: 14, height: 14)
                                        .clipShape(RoundedRectangle(cornerRadius: 2))
                                }
                            }
                        }

                        if let siteName = preview.siteName {
                            Text(siteName.uppercased())
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(colors.secondaryText)
                                .lineLimit(1)
                        }
                    }

                    // Title
                    if let title = preview.title {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(colors.text)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    // Description
                    if let description = preview.description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(colors.secondaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(12)
            }
            .background(colors.tertiaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(colors.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 280)
    }
}

#Preview {
    VStack(spacing: 16) {
        LinkPreviewCard(preview: LinkPreview(
            id: UUID(),
            url: "https://example.com",
            title: "Example Website - A Great Place to Visit",
            description: "This is a description of the example website.",
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
}
