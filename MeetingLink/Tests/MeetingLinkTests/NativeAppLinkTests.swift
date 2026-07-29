import XCTest
@testable import MeetingLink

final class NativeAppLinkTests: XCTestCase {

    private func native(_ s: String) -> String? {
        guard let url = URL(string: s) else { return nil }
        return NativeAppLink.nativeURL(for: url)?.absoluteString
    }

    // MARK: Zoom

    func testZoomJoinLinkRewrites() {
        XCTAssertEqual(native("https://zoom.us/j/1234567890"),
                       "zoommtg://zoom.us/join?confno=1234567890")
    }

    func testZoomSubdomainRewritesToCanonicalHost() {
        XCTAssertEqual(native("https://us02web.zoom.us/j/9876543210"),
                       "zoommtg://zoom.us/join?confno=9876543210")
    }

    func testZoomPasswordIsCarriedThrough() {
        let out = native("https://zoom.us/j/1234567890?pwd=SeCrEt123")
        XCTAssertEqual(out, "zoommtg://zoom.us/join?confno=1234567890&pwd=SeCrEt123")
    }

    func testZoomSAndWPathsRewrite() {
        XCTAssertEqual(native("https://zoom.us/s/555"), "zoommtg://zoom.us/join?confno=555")
        XCTAssertEqual(native("https://zoom.us/w/777"), "zoommtg://zoom.us/join?confno=777")
    }

    /// Personal-room links aren't meeting numbers — browser fallback is correct.
    func testZoomPersonalRoomFallsBackToBrowser() {
        XCTAssertNil(native("https://zoom.us/my/alexroom"))
    }

    /// Non-numeric ids are rejected rather than forwarded into the scheme URL.
    func testZoomNonNumericIdRejected() {
        XCTAssertNil(native("https://zoom.us/j/notanumber"))
        XCTAssertNil(native("https://zoom.us/j/123abc"))
    }

    func testZoomBareDomainNoPathFallsBack() {
        XCTAssertNil(native("https://zoom.us/"))
    }

    // MARK: Microsoft Teams

    func testTeamsMeetupJoinRewrites() {
        let out = native("https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc/0?context=%7b%22Tid%22%3a%22x%22%7d")
        XCTAssertNotNil(out)
        XCTAssertTrue(out!.hasPrefix("msteams:/l/meetup-join/"), "got \(out!)")
        XCTAssertTrue(out!.contains("context="), "query should be preserved")
    }

    func testTeamsNonMeetingPathFallsBack() {
        XCTAssertNil(native("https://teams.microsoft.com/_#/conversations/general"))
    }

    // MARK: Jitsi

    func testJitsiRewrites() {
        XCTAssertEqual(native("https://meet.jit.si/ReveilleStandup"),
                       "jitsi-meet://meet.jit.si/ReveilleStandup")
    }

    func testJitsiNoRoomFallsBack() {
        XCTAssertNil(native("https://meet.jit.si/"))
    }

    // MARK: Providers with no reliable desktop scheme → browser

    func testProvidersWithoutNativeSchemeReturnNil() {
        XCTAssertNil(native("https://meet.google.com/abc-defg-hij"))
        XCTAssertNil(native("https://myteam.slack.com/archives/x"))
        XCTAssertNil(native("https://discord.gg/abcd"))
        XCTAssertNil(native("https://acme.webex.com/meet/alex"))
        XCTAssertNil(native("https://whereby.com/room"))
    }

    // MARK: Security — rewriting is gated on the allowlist

    /// The substring-injection attack must not produce a native URL either.
    func testRejectsSubstringInjection() {
        XCTAssertNil(native("https://evil.example/j/1234567890?r=https://zoom.us/"))
    }

    /// Suffix-spoofed host must not be rewritten.
    func testRejectsSuffixSpoof() {
        XCTAssertNil(native("https://zoom.us.evil.example/j/1234567890"))
    }

    /// http must not be rewritten (the detector rejects it upstream).
    func testRejectsHTTPDowngrade() {
        XCTAssertNil(native("http://zoom.us/j/1234567890"))
    }

    func testRejectsNonMeetingURL() {
        XCTAssertNil(native("https://example.com/j/1234567890"))
    }

    func testHasNativeURLConvenience() {
        XCTAssertTrue(NativeAppLink.hasNativeURL(for: URL(string: "https://zoom.us/j/1")!))
        XCTAssertFalse(NativeAppLink.hasNativeURL(for: URL(string: "https://meet.google.com/x")!))
    }
}
