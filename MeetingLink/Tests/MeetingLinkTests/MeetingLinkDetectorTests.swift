import XCTest
@testable import MeetingLink

final class MeetingLinkDetectorTests: XCTestCase {

    private func name(_ s: String) -> String? {
        guard let url = URL(string: s) else { return nil }
        return MeetingLinkDetector.provider(for: url)?.name
    }

    // MARK: Legitimate links are accepted

    func testAcceptsZoom() {
        XCTAssertEqual(name("https://zoom.us/j/123"), "Zoom")
    }

    func testAcceptsZoomSubdomain() {
        XCTAssertEqual(name("https://us02web.zoom.us/j/123"), "Zoom")
    }

    func testAcceptsGoogleMeet() {
        XCTAssertEqual(name("https://meet.google.com/abc-defg-hij"), "Google Meet")
    }

    func testAcceptsTeams() {
        XCTAssertEqual(name("https://teams.microsoft.com/l/meetup-join/xyz"), "Microsoft Teams")
    }

    func testAcceptsDiscordInvite() {
        XCTAssertEqual(name("https://discord.gg/abcd"), "Discord")
    }

    func testAcceptsSlack() {
        XCTAssertEqual(name("https://myteam.slack.com/archives/x"), "Slack")
    }

    func testAcceptsWebex() {
        XCTAssertEqual(name("https://mycompany.webex.com/meet/user"), "Webex")
    }

    func testAcceptsGoToMeeting() {
        XCTAssertEqual(name("https://gotomeet.me/roomname"), "GoToMeeting")
    }

    func testAcceptsWhereby() {
        XCTAssertEqual(name("https://whereby.com/roomname"), "Whereby")
    }

    func testAcceptsJitsi() {
        XCTAssertEqual(name("https://meet.jit.si/roomname"), "Jitsi")
    }

    func testAcceptsRingCentral() {
        XCTAssertEqual(name("https://v.ringcentral.com/join/123456789"), "RingCentral")
    }

    func testAcceptsBlueJeans() {
        XCTAssertEqual(name("https://bluejeans.com/123456789"), "BlueJeans")
    }

    func testAcceptsSkype() {
        XCTAssertEqual(name("https://join.skype.com/abcdef123456"), "Skype")
    }

    func testAcceptsFaceTimeScheme() {
        XCTAssertEqual(name("facetime://user@example.com"), "FaceTime")
    }

    // MARK: Attack cases are rejected

    /// Substring injection: the malicious host is evil.example; a trusted
    /// domain merely appears in the query string.
    func testRejectsSubstringInjection() {
        XCTAssertNil(name("https://evil.example/?r=https://zoom.us/"))
    }

    /// Suffix spoof: trusted domain is a prefix of the real (evil) host.
    func testRejectsSuffixSpoof() {
        XCTAssertNil(name("https://zoom.us.evil.example/j/123"))
    }

    /// Lookalike registrable domain.
    func testRejectsLookalikeDomain() {
        XCTAssertNil(name("https://notzoom.us/j/123"))
        XCTAssertNil(name("https://evilzoom.us/j/123"))
    }

    /// http downgrade — cleartext is never a real meeting link.
    func testRejectsHTTP() {
        XCTAssertNil(name("http://zoom.us/j/123"))
    }

    /// Non-meeting schemes.
    func testRejectsOtherSchemes() {
        XCTAssertNil(name("javascript:alert(1)"))
        XCTAssertNil(name("file:///etc/passwd"))
        XCTAssertNil(name("data:text/html,hi"))
    }

    /// Plain unrelated URL.
    func testRejectsUnrelatedURL() {
        XCTAssertNil(name("https://example.com/some/page"))
    }

    func testIsMeetingURLConvenience() {
        XCTAssertTrue(MeetingLinkDetector.isMeetingURL(URL(string: "https://zoom.us/j/1")!))
        XCTAssertFalse(MeetingLinkDetector.isMeetingURL(URL(string: "https://evil.example/?r=https://zoom.us/")!))
    }
}
