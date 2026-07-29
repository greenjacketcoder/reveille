import Foundation

/// Which meeting a "join now" action should target.
///
/// Pure and testable so the rule is pinned by CI rather than by hand-checking:
/// an in-progress meeting wins over an upcoming one (if you're late to a call
/// that's already running, that's the one you want), and only meetings with a
/// joinable link are candidates.
public enum JoinTarget {

    /// A meeting reduced to just what the choice depends on.
    public struct Window: Equatable {
        public let start: Date
        public let end: Date
        public let hasLink: Bool

        public init(start: Date, end: Date, hasLink: Bool) {
            self.start = start
            self.end = end
            self.hasLink = hasLink
        }
    }

    /// Index of the meeting to join, or nil if nothing is joinable.
    ///
    /// Preference order:
    /// 1. A meeting currently in progress (start <= now < end) with a link —
    ///    the earliest-starting one if several overlap.
    /// 2. Otherwise the soonest upcoming meeting with a link.
    public static func index(in windows: [Window], now: Date) -> Int? {
        let joinable = windows.enumerated().filter { $0.element.hasLink }

        let inProgress = joinable
            .filter { $0.element.start <= now && $0.element.end > now }
            .min { $0.element.start < $1.element.start }
        if let inProgress {
            return inProgress.offset
        }

        let upcoming = joinable
            .filter { $0.element.start > now }
            .min { $0.element.start < $1.element.start }
        return upcoming?.offset
    }
}
