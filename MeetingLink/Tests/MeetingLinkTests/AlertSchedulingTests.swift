import XCTest
@testable import MeetingLink

final class AlertSchedulingTests: XCTestCase {

    // MARK: alertKey — recurring-event de-duplication

    func testDistinctOccurrencesGetDistinctKeys() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let occ1 = AlertScheduling.alertKey(identifier: "RECUR", start: base)
        let occ2 = AlertScheduling.alertKey(identifier: "RECUR", start: base.addingTimeInterval(5 * 3600))
        XCTAssertNotEqual(occ1, occ2, "two occurrences of the same series must not collide")
    }

    func testSameOccurrenceDeduplicates() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(
            AlertScheduling.alertKey(identifier: "RECUR", start: base),
            AlertScheduling.alertKey(identifier: "RECUR", start: base),
            "the same occurrence must produce a stable key"
        )
    }

    func testNilIdentifierIsSafe() {
        let key = AlertScheduling.alertKey(identifier: nil, start: Date(timeIntervalSince1970: 1))
        XCTAssertEqual(key, "unknown@1")
    }

    // MARK: menuBarString

    func testMenuBarMinutes() {
        XCTAssertEqual(AlertScheduling.menuBarString(title: "Standup", minutesUntilStart: 4), "Standup · 4m")
    }

    func testMenuBarNow() {
        XCTAssertEqual(AlertScheduling.menuBarString(title: "Design Review", minutesUntilStart: 0), "Design Review · now")
    }

    func testMenuBarHoursExact() {
        XCTAssertEqual(AlertScheduling.menuBarString(title: "All hands", minutesUntilStart: 120), "All hands · 2h")
    }

    func testMenuBarHoursAndMinutes() {
        XCTAssertEqual(AlertScheduling.menuBarString(title: "Planning", minutesUntilStart: 90), "Planning · 1h 30m")
    }

    func testMenuBarTruncatesLongTitles() {
        let long = "Quarterly Business Review With The Whole Org"
        let out = AlertScheduling.menuBarString(title: long, minutesUntilStart: 12)
        XCTAssertTrue(out.hasSuffix(" · 12m"))
        // 24-char cap: 23 chars + ellipsis
        XCTAssertTrue(out.hasPrefix(String(long.prefix(23)) + "…"))
    }

    func testMenuBarNilTitleFallback() {
        XCTAssertEqual(AlertScheduling.menuBarString(title: nil, minutesUntilStart: 3), "Meeting · 3m")
    }

    // MARK: snoozeDelay — smart cap

    func testSnoozeFullWhenPlentyOfTime() {
        XCTAssertEqual(AlertScheduling.snoozeDelay(chosenMinutes: 2, secondsUntilStart: 600), 120, accuracy: 0.5)
        XCTAssertEqual(AlertScheduling.snoozeDelay(chosenMinutes: 5, secondsUntilStart: 600), 300, accuracy: 0.5)
    }

    func testSnoozeCapsToOneMinuteBeforeStart() {
        // 10 min out, snooze 10 → would overshoot, cap to 9 min (540s)
        XCTAssertEqual(AlertScheduling.snoozeDelay(chosenMinutes: 10, secondsUntilStart: 600), 540, accuracy: 0.5)
        // 5 min out, snooze 15 → cap to 4 min (240s)
        XCTAssertEqual(AlertScheduling.snoozeDelay(chosenMinutes: 15, secondsUntilStart: 300), 240, accuracy: 0.5)
    }

    func testSnoozeClampsToFloorWhenVeryClose() {
        // 30s out, snooze 5 → clamp to 1s floor
        XCTAssertEqual(AlertScheduling.snoozeDelay(chosenMinutes: 5, secondsUntilStart: 30), 1, accuracy: 0.5)
    }
}
