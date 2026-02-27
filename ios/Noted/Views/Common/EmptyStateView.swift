import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var action: (() -> Void)?
    var actionTitle: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(.secondary.opacity(0.5))
                .symbolEffect(.pulse, options: .repeating.speed(0.5))

            Text(title)
                .font(.title2)
                .fontWeight(.semibold)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let action = action, let actionTitle = actionTitle {
                Button {
                    action()
                } label: {
                    Text(actionTitle)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Pre-configured empty states
extension EmptyStateView {
    static var noNotebooks: EmptyStateView {
        EmptyStateView(
            icon: "book.closed",
            title: "No Notebooks",
            subtitle: "Create a notebook to start organizing your notes"
        )
    }

    static var noNotes: EmptyStateView {
        EmptyStateView(
            icon: "bubble.left.and.bubble.right",
            title: "No Notes Yet",
            subtitle: "Start typing below to add your first note"
        )
    }

    static var noSearchResults: EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "No Results",
            subtitle: "Try a different search term"
        )
    }

    static var noTodos: EmptyStateView {
        EmptyStateView(
            icon: "checkmark.circle",
            title: "All Done!",
            subtitle: "No pending to-dos. Create a note and mark it as a to-do to see it here."
        )
    }

    static var noReminders: EmptyStateView {
        EmptyStateView(
            icon: "bell",
            title: "No Reminders",
            subtitle: "Add a reminder to a note to see it here"
        )
    }

    static var offline: EmptyStateView {
        EmptyStateView(
            icon: "wifi.slash",
            title: "You're Offline",
            subtitle: "Your notes are saved locally and will sync when you're back online"
        )
    }
}

#Preview {
    EmptyStateView.noNotebooks
}
