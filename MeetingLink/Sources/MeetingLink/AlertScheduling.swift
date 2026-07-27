import Foundation

/// Pure, testable scheduling/formatting logic extracted from the app so it can
/// be unit-tested in CI (the app-side methods were verified only with
/// throwaway scripts). No EventKit or AppKit dependency — callers pass in
/// plain values.
public enum AlertScheduling {

    /// Dedup key for "already alerted this event occurrence." Recurring events
    /// share one identifier across every occurrence, so the identifier alone
    /// would suppress a later occurrence of the same series on the same day.
    /// Combining it with the occurrence's start time keeps occurrences
    /// distinct while still de-duplicating repeat checks of the same one.
    public static func alertKey(identifier: String?, start: Date) -> String {
        let id = identifier ?? "unknown"
        return "\(id)@\(Int(start.timeIntervalSince1970))"
    }

    /// Menu-bar label like "Standup · 4m". Truncates long titles to keep the
    /// menu bar from overflowing.
    public static func menuBarString(title rawTitle: String?, minutesUntilStart mins: Int, maxTitleLength: Int = 24) -> String {
        let countdown: String
        if mins < 1 {
            countdown = "now"
        } else if mins < 60 {
            countdown = "\(mins)m"
        } else {
            let h = mins / 60, m = mins % 60
            countdown = m == 0 ? "\(h)h" : "\(h)h \(m)m"
        }

        var title = rawTitle ?? "Meeting"
        if title.count > maxTitleLength {
            title = String(title.prefix(maxTitleLength - 1)) + "…"
        }
        return "\(title) · \(countdown)"
    }

    /// How long to defer a snoozed alert. Normally the chosen duration, but
    /// capped so snooze never overshoots the meeting: if the chosen duration
    /// would land within a minute of (or past) the start, re-alert one minute
    /// before start instead, clamped to a 1-second floor.
    public static func snoozeDelay(chosenMinutes: Int, secondsUntilStart: TimeInterval) -> TimeInterval {
        let chosen = TimeInterval(chosenMinutes * 60)
        if secondsUntilStart - chosen < 60 {
            return max(secondsUntilStart - 60, 1)
        }
        return chosen
    }
}
