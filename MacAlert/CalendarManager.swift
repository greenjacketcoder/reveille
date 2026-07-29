import Foundation
import EventKit
import AppKit

class CalendarManager {
    private let eventStore = EKEventStore()

    /// Shared instance so views reuse the app's authorized store instead of
    /// creating throwaway EKEventStores (which may not be ready to read, and
    /// each of which carries its own EventKit overhead).
    static let shared = CalendarManager()

    /// What level of calendar access the app actually has. Needed because
    /// write-only access still lets EventKit calls succeed while returning
    /// nothing to read — which looks identical to "still loading" unless the
    /// UI checks explicitly.
    enum Access: Equatable {
        case notDetermined
        case denied
        /// "Add Events Only" — Reveille can create events but cannot read
        /// them, so alerts cannot work at all in this state.
        case writeOnly
        case full
        case unknown
    }

    var eventAccess: Access {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            switch status {
            case .notDetermined: return .notDetermined
            case .restricted, .denied: return .denied
            case .writeOnly: return .writeOnly
            case .fullAccess: return .full
            @unknown default: return .unknown
            }
        } else {
            switch status {
            case .notDetermined: return .notDetermined
            case .restricted, .denied: return .denied
            case .authorized: return .full
            @unknown default: return .unknown
            }
        }
    }

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

    /// All of today's events (midnight to midnight), for the alert's agenda rail.
    func getTodaysEvents() -> [EKEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        return eventStore.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
    }

    /// The next event today that hasn't started yet, for the menu-bar
    /// countdown. Nil if nothing remains today.
    func getNextEvent() -> EKEvent? {
        let now = Date()
        return getTodaysEvents().first { $0.startDate > now }
    }

    /// Today's all-day events (which getTodaysEvents excludes), for the
    /// agenda dropdown's all-day banner.
    func getTodaysAllDayEvents() -> [EKEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        return eventStore.events(matching: predicate)
            .filter { $0.isAllDay }
            .sorted { ($0.title ?? "") < ($1.title ?? "") }
    }

    /// Tomorrow's timed events, for the agenda dropdown's "Tomorrow" section.
    func getTomorrowsEvents() -> [EKEvent] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday),
              let endOfTomorrow = calendar.date(byAdding: .day, value: 2, to: startOfToday) else { return [] }
        let predicate = eventStore.predicateForEvents(withStart: startOfTomorrow, end: endOfTomorrow, calendars: nil)
        return eventStore.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
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
        // Need a target calendar: the one passed in, or the system default.
        // If neither exists, there's nowhere to save — fail rather than crash.
        guard let targetCalendar = calendar ?? eventStore.defaultCalendarForNewEvents else {
            return false
        }
        guard let endDate = Calendar.current.date(byAdding: .minute, value: durationMinutes, to: startDate) else {
            return false
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = notes
        event.calendar = targetCalendar

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
