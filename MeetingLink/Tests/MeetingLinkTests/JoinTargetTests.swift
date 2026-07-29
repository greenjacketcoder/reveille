import XCTest
@testable import MeetingLink

final class JoinTargetTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func win(_ startOffsetMin: Double, _ endOffsetMin: Double, link: Bool = true) -> JoinTarget.Window {
        JoinTarget.Window(
            start: now.addingTimeInterval(startOffsetMin * 60),
            end: now.addingTimeInterval(endOffsetMin * 60),
            hasLink: link
        )
    }

    func testPicksInProgressOverUpcoming() {
        // index 0 starts in 10 min; index 1 is running right now
        let windows = [win(10, 40), win(-5, 25)]
        XCTAssertEqual(JoinTarget.index(in: windows, now: now), 1)
    }

    func testPicksSoonestUpcomingWhenNothingRunning() {
        let windows = [win(60, 90), win(15, 45), win(120, 150)]
        XCTAssertEqual(JoinTarget.index(in: windows, now: now), 1)
    }

    func testEarliestStartingWinsAmongOverlappingInProgress() {
        let windows = [win(-5, 30), win(-20, 30)]
        XCTAssertEqual(JoinTarget.index(in: windows, now: now), 1)
    }

    func testSkipsMeetingsWithoutLinks() {
        // The running meeting has no link, so fall through to the upcoming one
        let windows = [win(-5, 25, link: false), win(30, 60, link: true)]
        XCTAssertEqual(JoinTarget.index(in: windows, now: now), 1)
    }

    func testIgnoresFinishedMeetings() {
        let windows = [win(-120, -60), win(45, 75)]
        XCTAssertEqual(JoinTarget.index(in: windows, now: now), 1)
    }

    func testNilWhenNothingJoinable() {
        XCTAssertNil(JoinTarget.index(in: [], now: now))
        XCTAssertNil(JoinTarget.index(in: [win(30, 60, link: false)], now: now))
        // only past meetings
        XCTAssertNil(JoinTarget.index(in: [win(-120, -60)], now: now))
    }

    /// A meeting that ends exactly now is over; one starting exactly now is on.
    func testBoundaryConditions() {
        XCTAssertNil(JoinTarget.index(in: [win(-30, 0)], now: now), "ends exactly now = finished")
        XCTAssertEqual(JoinTarget.index(in: [win(0, 30)], now: now), 0, "starts exactly now = in progress")
    }
}
