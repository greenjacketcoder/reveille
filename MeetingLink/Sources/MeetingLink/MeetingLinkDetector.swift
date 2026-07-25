import Foundation

/// Central authority for what counts as a meeting link. Matching is done on
/// the parsed URL's host against an allowlist — never by substring on the
/// full URL string. Calendar events are untrusted input (anyone can email an
/// invite that lands in the calendar), and substring matching let a crafted
/// URL like https://evil.example/?r=https://zoom.us/ earn a trusted,
/// provider-labeled Join button. Web schemes must be https.
public enum MeetingLinkDetector {
    public struct Provider: Equatable {
        public let name: String
        public let badgeLetter: String
        /// Exact hosts and registrable domains (subdomains of these match).
        public let domains: [String]

        public init(name: String, badgeLetter: String, domains: [String]) {
            self.name = name
            self.badgeLetter = badgeLetter
            self.domains = domains
        }
    }

    public static let providers: [Provider] = [
        Provider(name: "Zoom", badgeLetter: "Z", domains: ["zoom.us"]),
        Provider(name: "Google Meet", badgeLetter: "M", domains: ["meet.google.com"]),
        Provider(name: "Microsoft Teams", badgeLetter: "T", domains: ["teams.microsoft.com", "teams.live.com"]),
        Provider(name: "Discord", badgeLetter: "D", domains: ["discord.gg", "discord.com"]),
        Provider(name: "Slack", badgeLetter: "S", domains: ["slack.com"]),
        Provider(name: "Webex", badgeLetter: "W", domains: ["webex.com"]),
        Provider(name: "GoToMeeting", badgeLetter: "G", domains: ["gotomeeting.com", "gotomeet.me"]),
        Provider(name: "Whereby", badgeLetter: "W", domains: ["whereby.com"]),
        Provider(name: "Jitsi", badgeLetter: "J", domains: ["meet.jit.si", "jitsi.org"]),
        Provider(name: "RingCentral", badgeLetter: "R", domains: ["ringcentral.com", "v.ringcentral.com"]),
        Provider(name: "BlueJeans", badgeLetter: "B", domains: ["bluejeans.com"]),
        Provider(name: "Skype", badgeLetter: "S", domains: ["skype.com", "join.skype.com"]),
    ]

    /// Returns the matching provider if this URL is a legitimate meeting
    /// link per the allowlist, nil otherwise.
    public static func provider(for url: URL) -> Provider? {
        guard let scheme = url.scheme?.lowercased() else { return nil }

        if scheme == "facetime" || scheme == "facetime-audio" {
            return Provider(name: "FaceTime", badgeLetter: "F", domains: [])
        }

        // Web meeting links must be https — no http, and no other schemes.
        guard scheme == "https", let host = url.host?.lowercased() else { return nil }

        for provider in providers {
            for domain in provider.domains {
                if host == domain || host.hasSuffix("." + domain) {
                    return provider
                }
            }
        }
        return nil
    }

    public static func isMeetingURL(_ url: URL) -> Bool {
        provider(for: url) != nil
    }
}
