import Foundation
import EventKit
import AppKit

class CalendarManager {
    private let eventStore = EKEventStore()

    func requestAccess(completion: @escaping (Bool) -> Void) {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { granted, error in
                completion(granted)
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, error in
                completion(granted)
            }
        }
    }

    func requestRemindersAccess(completion: @escaping (Bool) -> Void) {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToReminders { granted, error in
                completion(granted)
            }
        } else {
            eventStore.requestAccess(to: .reminder) { granted, error in
                completion(granted)
            }
        }
    }

    func getUpcomingEvents(withinMinutes minutes: Int) -> [EKEvent]? {
        let now = Date()
        let future = Calendar.current.date(byAdding: .minute, value: minutes, to: now)!

        let predicate = eventStore.predicateForEvents(withStart: now, end: future, calendars: nil)
        let events = eventStore.events(matching: predicate)

        return events.filter { event in
            let timeUntilEvent = event.startDate.timeIntervalSince(now)
            return timeUntilEvent > 0 && timeUntilEvent <= Double(minutes * 60)
        }.sorted { $0.startDate < $1.startDate }
    }

    func getUpcomingReminders(withinMinutes minutes: Int) -> [EKReminder] {
        let calendars = eventStore.calendars(for: .reminder)
        let now = Date()

        let predicate = eventStore.predicateForReminders(in: calendars)
        var upcomingReminders: [EKReminder] = []

        let semaphore = DispatchSemaphore(value: 0)

        eventStore.fetchReminders(matching: predicate) { reminders in
            if let reminders = reminders {
                upcomingReminders = reminders.filter { reminder in
                    guard let dueDate = reminder.dueDateComponents?.date else { return false }
                    let timeUntil = dueDate.timeIntervalSince(now)
                    return timeUntil > 0 && timeUntil <= Double(minutes * 60) && !reminder.isCompleted
                }.sorted { ($0.dueDateComponents?.date ?? Date()) < ($1.dueDateComponents?.date ?? Date()) }
            }
            semaphore.signal()
        }

        semaphore.wait()
        return upcomingReminders
    }

    func getCalendars() -> [EKCalendar] {
        return eventStore.calendars(for: .event)
    }

    /// Marks a reminder as completed and saves the change back to EventKit.
    /// Returns false if the save fails (e.g. reminder was deleted elsewhere).
    @discardableResult
    func completeReminder(_ reminder: EKReminder) -> Bool {
        reminder.isCompleted = true
        do {
            try eventStore.save(reminder, commit: true)
            return true
        } catch {
            return false
        }
    }

    /// Opens the Reminders app. EventKit has no supported API to deep-link
    /// to a specific reminder, so this opens the app generally rather than
    /// navigating to the exact item.
    func openRemindersApp() {
        if let remindersURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.reminders") {
            NSWorkspace.shared.openApplication(at: remindersURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    func createEvent(title: String, startDate: Date, durationMinutes: Int, notes: String?, calendar: EKCalendar?, meetingLinkURL: String? = nil) -> Bool {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = Calendar.current.date(byAdding: .minute, value: durationMinutes, to: startDate)
        event.notes = notes
        event.calendar = calendar ?? eventStore.defaultCalendarForNewEvents

        if let meetingLinkURL, let url = URL(string: meetingLinkURL) {
            event.url = url
        }

        do {
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }
}
