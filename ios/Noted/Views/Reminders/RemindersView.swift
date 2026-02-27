import SwiftUI

struct RemindersView: View {
    @State private var viewModel = RemindersViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.reminders.isEmpty {
                    ProgressView()
                } else if viewModel.reminders.isEmpty {
                    ContentUnavailableView(
                        "No Reminders",
                        systemImage: "bell",
                        description: Text("Add a reminder to a note to see it here")
                    )
                } else {
                    List {
                        ForEach(groupedReminders, id: \.title) { group in
                            Section(group.title) {
                                ForEach(group.reminders) { reminder in
                                    ReminderRow(
                                        reminder: reminder,
                                        onClear: {
                                            Task {
                                                await viewModel.clearReminder(reminder.id)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.fetchReminders()
                    }
                }
            }
            .navigationTitle("Reminders")
            .task {
                await viewModel.fetchReminders()
            }
        }
    }

    private var groupedReminders: [ReminderGroup] {
        let calendar = Calendar.current
        let now = Date()

        var overdue: [ReminderItem] = []
        var today: [ReminderItem] = []
        var tomorrow: [ReminderItem] = []
        var thisWeek: [ReminderItem] = []
        var later: [ReminderItem] = []

        for reminder in viewModel.reminders {
            if reminder.reminderAt < now {
                overdue.append(reminder)
            } else if calendar.isDateInToday(reminder.reminderAt) {
                today.append(reminder)
            } else if calendar.isDateInTomorrow(reminder.reminderAt) {
                tomorrow.append(reminder)
            } else if let weekFromNow = calendar.date(byAdding: .day, value: 7, to: now),
                      reminder.reminderAt < weekFromNow {
                thisWeek.append(reminder)
            } else {
                later.append(reminder)
            }
        }

        var groups: [ReminderGroup] = []

        if !overdue.isEmpty {
            groups.append(ReminderGroup(title: "Overdue", reminders: overdue))
        }
        if !today.isEmpty {
            groups.append(ReminderGroup(title: "Today", reminders: today))
        }
        if !tomorrow.isEmpty {
            groups.append(ReminderGroup(title: "Tomorrow", reminders: tomorrow))
        }
        if !thisWeek.isEmpty {
            groups.append(ReminderGroup(title: "This Week", reminders: thisWeek))
        }
        if !later.isEmpty {
            groups.append(ReminderGroup(title: "Later", reminders: later))
        }

        return groups
    }
}

struct ReminderGroup {
    let title: String
    let reminders: [ReminderItem]
}

struct ReminderItem: Identifiable {
    let id: UUID
    let notebookId: UUID
    let content: String
    let reminderAt: Date
    let notebookTitle: String
}

struct ReminderRow: View {
    let reminder: ReminderItem
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.content)
                    .lineLimit(2)

                HStack {
                    Image(systemName: "book.closed")
                        .font(.caption2)
                    Text(reminder.notebookTitle)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)

                HStack {
                    Image(systemName: "bell.fill")
                        .font(.caption2)
                    Text(formatDate(reminder.reminderAt))
                        .font(.caption)
                }
                .foregroundStyle(isOverdue ? .red : .secondary)
            }

            Spacer()

            Button {
                onClear()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var isOverdue: Bool {
        reminder.reminderAt < Date()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    RemindersView()
}
