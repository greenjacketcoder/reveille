import Foundation

/// Rewrites an already-validated meeting link into the provider's native-app
/// URL scheme, for users who prefer joining in the desktop client rather than
/// a browser tab.
///
/// Security notes:
/// - Rewriting only happens for URLs that already passed
///   `MeetingLinkDetector.provider(for:)` — the host allowlist stays the single
///   gate. This type never inspects an unvalidated URL.
/// - Native URLs are built from *parsed components* (meeting id, path, query),
///   never by string-substituting the scheme on an attacker-influenced string,
///   so a crafted link can't smuggle content into the constructed scheme URL.
/// - Returning `nil` means "no reliable native equivalent — use the browser."
///   That's the correct outcome for providers without a documented desktop
///   scheme, not a gap to paper over with guesses.
public enum NativeAppLink {

    /// The native-app equivalent of a meeting URL, or nil if this provider has
    /// no reliable desktop scheme (or the link isn't in a rewritable form).
    public static func nativeURL(for url: URL) -> URL? {
        // Gate on the allowlist first. Unvalidated URLs are never rewritten.
        guard let provider = MeetingLinkDetector.provider(for: url) else { return nil }

        switch provider.name {
        case "Zoom":
            return zoomURL(from: url)
        case "Microsoft Teams":
            return teamsURL(from: url)
        case "Jitsi":
            return jitsiURL(from: url)
        default:
            // Google Meet, Slack, Discord, Webex, GoToMeeting, Whereby,
            // RingCentral, BlueJeans, Skype: no documented, stable desktop
            // join scheme we can construct safely. Browser is correct.
            return nil
        }
    }

    /// Whether a native rewrite exists for this URL.
    public static func hasNativeURL(for url: URL) -> Bool {
        nativeURL(for: url) != nil
    }

    // MARK: - Per-provider rewrites

    /// zoommtg://zoom.us/join?confno=<id>[&pwd=<pwd>]
    ///
    /// Only rewrites numeric-meeting-id links (/j/, /s/, /w/). Personal-room
    /// links (/my/<name>) aren't meeting numbers, so they fall back to the
    /// browser rather than being guessed at.
    private static func zoomURL(from url: URL) -> URL? {
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2 else { return nil }
        let kind = parts[0].lowercased()
        guard ["j", "s", "w"].contains(kind) else { return nil }

        let id = parts[1]
        // Meeting ids are digits only — reject anything else outright rather
        // than forwarding arbitrary text into the scheme URL.
        guard !id.isEmpty, id.allSatisfy({ $0.isNumber }) else { return nil }

        var components = URLComponents()
        components.scheme = "zoommtg"
        components.host = "zoom.us"
        components.path = "/join"

        var query = [URLQueryItem(name: "confno", value: id)]
        if let pwd = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name.lowercased() == "pwd" })?.value,
            !pwd.isEmpty {
            query.append(URLQueryItem(name: "pwd", value: pwd))
        }
        components.queryItems = query

        return components.url
    }

    /// msteams:/l/meetup-join/<rest> — Microsoft's documented deep-link form.
    /// Only meetup-join links are rewritten; other Teams URLs go to the browser.
    private static func teamsURL(from url: URL) -> URL? {
        guard url.path.hasPrefix("/l/meetup-join/") else { return nil }

        var components = URLComponents()
        components.scheme = "msteams"
        components.path = url.path
        components.query = url.query

        return components.url
    }

    /// jitsi-meet://<host>/<room> — the Jitsi Meet desktop app's scheme.
    private static func jitsiURL(from url: URL) -> URL? {
        guard let host = url.host, !host.isEmpty else { return nil }
        let room = url.pathComponents.filter { $0 != "/" }
        guard !room.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = "jitsi-meet"
        components.host = host
        components.path = "/" + room.joined(separator: "/")

        return components.url
    }
}
