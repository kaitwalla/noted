import SwiftUI

struct TagChip: View {
    let tag: Tag
    var isSelected: Bool = false
    var showRemove: Bool = false
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 4) {
            Text(tag.name)
                .font(.caption)
                .fontWeight(.medium)

            if showRemove {
                Button {
                    onRemove?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(tag.swiftUIColor.opacity(isSelected ? 0.3 : 0.15))
        )
        .overlay(
            Capsule()
                .strokeBorder(tag.swiftUIColor.opacity(isSelected ? 1 : 0.5), lineWidth: 1)
        )
        .foregroundStyle(tag.swiftUIColor)
    }
}

struct TagChipRow: View {
    let tags: [Tag]

    var body: some View {
        if !tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tags) { tag in
                        TagChip(tag: tag)
                    }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        TagChip(tag: Tag(
            id: UUID(),
            name: "Work",
            color: "#FF5733",
            createdAt: Date()
        ))

        TagChip(tag: Tag(
            id: UUID(),
            name: "Personal",
            color: "#33A1FF",
            createdAt: Date()
        ), isSelected: true)

        TagChip(tag: Tag(
            id: UUID(),
            name: "Ideas",
            color: "#33FF57",
            createdAt: Date()
        ), showRemove: true)

        TagChipRow(tags: [
            Tag(id: UUID(), name: "Work", color: "#FF5733", createdAt: Date()),
            Tag(id: UUID(), name: "Urgent", color: "#FF3333", createdAt: Date()),
            Tag(id: UUID(), name: "Review", color: "#33A1FF", createdAt: Date())
        ])
    }
    .padding()
}
