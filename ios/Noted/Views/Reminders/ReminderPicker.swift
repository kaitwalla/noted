import SwiftUI

struct ReminderPicker: View {
    @Binding var selectedDate: Date?
    @State private var date = Date()
    @State private var showCustomPicker = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Quick options
                Section("Quick Options") {
                    Button {
                        selectDate(laterToday)
                    } label: {
                        Label {
                            HStack {
                                Text("Later Today")
                                Spacer()
                                Text(formatTime(laterToday))
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "clock")
                        }
                    }
                    .disabled(laterToday == nil)

                    Button {
                        selectDate(tomorrowMorning)
                    } label: {
                        Label {
                            HStack {
                                Text("Tomorrow Morning")
                                Spacer()
                                Text(formatDate(tomorrowMorning))
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "sunrise")
                        }
                    }

                    Button {
                        selectDate(nextWeek)
                    } label: {
                        Label {
                            HStack {
                                Text("Next Week")
                                Spacer()
                                Text(formatDate(nextWeek))
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "calendar")
                        }
                    }
                }

                // Custom date/time
                Section("Custom") {
                    Button {
                        showCustomPicker = true
                    } label: {
                        Label("Pick Date & Time", systemImage: "calendar.badge.clock")
                    }
                }

                // Remove reminder
                if selectedDate != nil {
                    Section {
                        Button(role: .destructive) {
                            selectedDate = nil
                            dismiss()
                        } label: {
                            Label("Remove Reminder", systemImage: "bell.slash")
                        }
                    }
                }
            }
            .navigationTitle("Set Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCustomPicker) {
                CustomDatePicker(
                    date: $date,
                    onSave: {
                        selectedDate = date
                        dismiss()
                    }
                )
            }
        }
    }

    private var laterToday: Date? {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)

        // Set to next hour
        let hour = calendar.component(.hour, from: now)
        if hour >= 21 { return nil } // Too late today

        components.hour = hour + 1
        components.minute = 0

        return calendar.date(from: components)
    }

    private var tomorrowMorning: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.day! += 1
        components.hour = 9
        components.minute = 0
        return calendar.date(from: components)!
    }

    private var nextWeek: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.day! += 7
        components.hour = 9
        components.minute = 0
        return calendar.date(from: components)!
    }

    private func selectDate(_ date: Date?) {
        guard let date = date else { return }
        selectedDate = date
        dismiss()
    }

    private func formatTime(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct CustomDatePicker: View {
    @Binding var date: Date
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DatePicker(
                "Reminder",
                selection: $date,
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Pick Date & Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                }
            }
        }
    }
}

#Preview {
    ReminderPicker(selectedDate: .constant(nil))
}
