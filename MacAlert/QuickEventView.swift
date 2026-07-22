import SwiftUI
import EventKit

struct QuickEventView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var calendarManager: CalendarManagerWrapper
    @ObservedObject var settings: SettingsManager

    @State private var title = ""
    @State private var startDate = Date()
    @State private var selectedDuration = 30
    @State private var customDuration = 60
    @State private var notes = ""
    @State private var selectedCalendar: EKCalendar?
    @State private var selectedLinkName: String? = nil
    @State private var showingSuccess = false

    let durationPresets = [15, 30, 60, 120, 240]

    var body: some View {
        VStack(spacing: 20) {
            Text("Quick Add Meeting")
                .font(.title)
                .bold()

            Form {
                Section(header: Text("Meeting Details")) {
                    TextField("Title", text: $title)

                    DatePicker("Start Time", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                }

                Section(header: Text("Duration")) {
                    Picker("Duration", selection: $selectedDuration) {
                        ForEach(durationPresets, id: \.self) { minutes in
                            Text(formatDuration(minutes)).tag(minutes)
                        }
                        Text("Custom...").tag(-1)
                    }
                    .pickerStyle(.segmented)

                    if selectedDuration == -1 {
                        HStack {
                            TextField("Minutes", value: $customDuration, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Text("minutes")
                        }
                    }
                }

                Section(header: Text("Optional")) {
                    TextEditor(text: $notes)
                        .frame(height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )

                    if !calendarManager.calendars.isEmpty {
                        Picker("Calendar", selection: $selectedCalendar) {
                            ForEach(calendarManager.calendars, id: \.calendarIdentifier) { calendar in
                                HStack {
                                    Circle()
                                        .fill(Color(calendar.color))
                                        .frame(width: 10, height: 10)
                                    Text(calendar.title)
                                }
                                .tag(calendar as EKCalendar?)
                            }
                        }
                    }

                    if !settings.personalMeetingLinks.isEmpty {
                        Picker("Meeting Link", selection: $selectedLinkName) {
                            Text("None").tag(nil as String?)
                            ForEach(settings.personalMeetingLinks.keys.sorted(), id: \.self) { name in
                                Text(name).tag(name as String?)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Create Meeting") {
                    createMeeting()
                }
                .keyboardShortcut(.return)
                .disabled(title.isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 500, height: 550)
        .alert("Meeting Created", isPresented: $showingSuccess) {
            Button("OK") {
                dismiss()
            }
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            return "\(hours)h"
        }
    }

    private func createMeeting() {
        let duration = selectedDuration == -1 ? customDuration : selectedDuration
        let linkURL = selectedLinkName.flatMap { settings.personalMeetingLinks[$0] }

        let success = calendarManager.manager.createEvent(
            title: title,
            startDate: startDate,
            durationMinutes: duration,
            notes: notes.isEmpty ? nil : notes,
            calendar: selectedCalendar,
            meetingLinkURL: linkURL
        )

        if success {
            showingSuccess = true
        }
    }
}

class CalendarManagerWrapper: ObservableObject {
    let manager = CalendarManager()
    @Published var calendars: [EKCalendar] = []

    init() {
        loadCalendars()
    }

    func loadCalendars() {
        calendars = manager.getCalendars()
    }
}
