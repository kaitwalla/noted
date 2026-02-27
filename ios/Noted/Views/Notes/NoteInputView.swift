import SwiftUI
import UIKit

struct NoteInputView: View {
    let onSend: (String) -> Void
    var onImageSelected: ((UIImage) -> Void)?

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Image picker button
            if let onImageSelected = onImageSelected {
                ImagePickerButton { image in
                    onImageSelected(image)
                }
            }

            // Text input
            TextField("Type a note...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused($isFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)

            // Send button
            Button {
                sendNote()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundStyle(canSend ? .accent : .secondary)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .onSubmit {
            if canSend {
                sendNote()
            }
        }
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendNote() {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        HapticService.shared.mediumTap()
        onSend(content)
        text = ""
    }
}

#Preview {
    VStack {
        Spacer()
        NoteInputView { content in
            print("Send: \(content)")
        }
    }
}
