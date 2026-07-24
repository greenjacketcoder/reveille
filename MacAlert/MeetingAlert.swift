import SwiftUI
import EventKit

enum AlertAction {
    case join
    case snooze
    case dismiss
    case complete   // reminder-only: mark the reminder as done
    case open       // reminder-only: open Reminders.app
}

// MARK: - Palette (design: "Daybreak" light / "Nightshift" dark, section 9 of the redesign)

/// Color system from the chosen redesign. Same structure in both schemes so
/// macOS can flip appearance automatically; only the values change.
struct AlertPalette {
    let background: Color        // panel detail-side background
    let rail: Color              // sidebar background
    let hairline: Color          // borders / dividers
    let hairlineStrong: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let textQuaternary: Color
    let accent: Color            // cool navy family
    let accentContrast: Color    // text on accent
    let cardShadow: Color
    let secondaryButtonFill: Color

    static func palette(for scheme: ColorScheme) -> AlertPalette {
        if scheme == .dark {
            // 9b Nightshift
            return AlertPalette(
                background: Color(red: 0x26/255, green: 0x2A/255, blue: 0x33/255),
                rail: Color(red: 0x14/255, green: 0x16/255, blue: 0x1B/255),
                hairline: Color.white.opacity(0.10),
                hairlineStrong: Color.white.opacity(0.16),
                textPrimary: Color(red: 0xE8/255, green: 0xEA/255, blue: 0xEE/255),
                textSecondary: Color(red: 0xC3/255, green: 0xC8/255, blue: 0xD1/255),
                textTertiary: Color(red: 0x8B/255, green: 0x93/255, blue: 0xA0/255),
                textQuaternary: Color(red: 0x73/255, green: 0x7A/255, blue: 0x86/255),
                accent: Color(red: 0x7C/255, green: 0x9A/255, blue: 0xD8/255),
                accentContrast: Color(red: 0x12/255, green: 0x15/255, blue: 0x1B/255),
                cardShadow: Color.white.opacity(0.08),
                secondaryButtonFill: Color.white.opacity(0.07)
            )
        } else {
            // 9a Daybreak
            return AlertPalette(
                background: Color(red: 0xEE/255, green: 0xEE/255, blue: 0xEA/255),
                rail: Color(red: 0xE4/255, green: 0xE3/255, blue: 0xDD/255),
                hairline: Color(red: 0x14/255, green: 0x18/255, blue: 0x20/255).opacity(0.10),
                hairlineStrong: Color(red: 0x14/255, green: 0x18/255, blue: 0x20/255).opacity(0.16),
                textPrimary: Color(red: 0x1B/255, green: 0x1E/255, blue: 0x24/255),
                textSecondary: Color(red: 0x3D/255, green: 0x43/255, blue: 0x4E/255),
                textTertiary: Color(red: 0x5C/255, green: 0x64/255, blue: 0x70/255),
                textQuaternary: Color(red: 0x9A/255, green: 0xA1/255, blue: 0xAC/255),
                accent: Color(red: 0x35/255, green: 0x54/255, blue: 0x7E/255),
                accentContrast: Color(red: 0xF7/255, green: 0xF6/255, blue: 0xF1/255),
                cardShadow: Color(red: 0x14/255, green: 0x18/255, blue: 0x20/255).opacity(0.08),
                secondaryButtonFill: Color(red: 0xF7/255, green: 0xF6/255, blue: 0xF1/255)
            )
        }
    }
}

// MARK: - Meeting link detection (host-allowlisted)

/// Central authority for what counts as a meeting link. Matching is done on
/// the parsed URL's host against an allowlist - never by substring on the
/// full URL string. Calendar events are untrusted input (anyone can email an
/// invite that lands in the calendar), and substring matching let a crafted
/// URL like https://evil.example/?r=https://zoom.us/ earn a trusted,
/// provider-labeled Join button. Web schemes must be https.
enum MeetingLinkDetector {
    struct Provider {
        let name: String
        let badgeLetter: String
        /// Exact hosts and registrable domains (subdomains of these match).
        let domains: [String]
    }

    static let providers: [Provider] = [
        Provider(name: "Zoom", badgeLetter: "Z", domains: ["zoom.us"]),
        Provider(name: "Google Meet", badgeLetter: "M", domains: ["meet.google.com"]),
        Provider(name: "Microsoft Teams", badgeLetter: "T", domains: ["teams.microsoft.com", "teams.live.com"]),
        Provider(name: "Discord", badgeLetter: "D", domains: ["discord.gg", "discord.com"]),
        Provider(name: "Slack", badgeLetter: "S", domains: ["slack.com"]),
    ]

    /// Returns the matching provider if this URL is a legitimate meeting
    /// link per the allowlist, nil otherwise.
    static func provider(for url: URL) -> Provider? {
        guard let scheme = url.scheme?.lowercased() else { return nil }

        if scheme == "facetime" || scheme == "facetime-audio" {
            return Provider(name: "FaceTime", badgeLetter: "F", domains: [])
        }

        // Web meeting links must be https - no http, and no other schemes.
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

    static func isMeetingURL(_ url: URL) -> Bool {
        provider(for: url) != nil
    }
}

// Kept as the view-facing type; now just a thin wrapper over the detector.
struct MeetingProvider {
    let name: String
    let badgeLetter: String

    static func detect(from url: URL?) -> MeetingProvider? {
        guard let url = url else { return nil }
        if let p = MeetingLinkDetector.provider(for: url) {
            return MeetingProvider(name: p.name, badgeLetter: p.badgeLetter)
        }
        return nil
    }
}

// MARK: - Main alert view

struct MeetingAlertView: View {
    let event: EKEvent
    var todaysEvents: [EKEvent] = []
    var meetingURL: URL? = nil
    let onAction: (AlertAction) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var now = Date()
    @State private var timer: Timer?

    private var palette: AlertPalette { AlertPalette.palette(for: colorScheme) }
    private var provider: MeetingProvider? { MeetingProvider.detect(from: meetingURL) }

    var body: some View {
        ZStack {
            // Dimmed backdrop over whatever's on screen — the alert still owns
            // the whole display, but the panel reads as a calm sheet, not a wall.
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            HStack(spacing: 0) {
                agendaRail
                    .frame(width: 280)
                detailPane
            }
            .frame(width: 920, height: 570)
            .background(palette.background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.45), radius: 40, x: 0, y: 24)
        }
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                now = Date()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    // MARK: Agenda rail (left sidebar)

    private var agendaRail: some View {
        VStack(spacing: 0) {
            // Brand header
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(palette.accent)
                    .frame(width: 12, height: 12)
                Text("Reveille")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundColor(palette.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 22)
            .frame(height: 52)
            .overlay(alignment: .bottom) { Rectangle().fill(palette.hairline).frame(height: 1) }

            // Date
            HStack {
                Text(dayHeader)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(palette.textQuaternary)
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Agenda
            VStack(spacing: 1) {
                ForEach(Array(agendaItems.enumerated()), id: \.offset) { _, item in
                    switch item {
                    case .nowLine:
                        HStack(spacing: 9) {
                            Text(timeShort(now))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(palette.accent)
                                .frame(width: 36, alignment: .leading)
                            Rectangle().fill(palette.accent).frame(height: 1.5)
                            Circle().fill(palette.accent).frame(width: 6, height: 6)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                    case .event(let e, let isNext, let isPast):
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(timeShort(e.startDate))
                                .font(.system(size: 12, weight: isNext ? .semibold : .medium, design: .monospaced))
                                .foregroundColor(isNext ? palette.accent : (isPast ? palette.textQuaternary : palette.textTertiary))
                                .frame(width: 40, alignment: .leading)
                            Text(e.title ?? "Untitled")
                                .font(.system(size: isNext ? 13.5 : 13, weight: isNext ? .semibold : .medium))
                                .foregroundColor(isNext ? palette.textPrimary : (isPast ? palette.textQuaternary : palette.textTertiary))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, isNext ? 9 : 7)
                        .padding(.vertical, isNext ? 11 : 9)
                        .background(
                            isNext
                                ? AnyView(RoundedRectangle(cornerRadius: 8).fill(palette.background).shadow(color: palette.cardShadow, radius: 2, x: 0, y: 1))
                                : AnyView(Color.clear)
                        )
                    }
                }
            }
            .padding(.horizontal, 15)

            Spacer(minLength: 8)

            // Footer count
            HStack {
                Text("\(todaysEvents.count) event\(todaysEvents.count == 1 ? "" : "s") today")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(palette.textQuaternary)
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .overlay(alignment: .top) { Rectangle().fill(palette.hairline).frame(height: 1) }
        }
        .frame(maxHeight: .infinity)
        .background(palette.rail)
        .overlay(alignment: .trailing) { Rectangle().fill(palette.hairline).frame(width: 1) }
    }

    private enum AgendaItem {
        case event(EKEvent, isNext: Bool, isPast: Bool)
        case nowLine
    }

    /// Today's events with a "now" marker inserted before the alerting event.
    private var agendaItems: [AgendaItem] {
        let list = todaysEvents.isEmpty ? [event] : todaysEvents
        var items: [AgendaItem] = []
        var nowInserted = false
        for e in list {
            let isTarget = e.eventIdentifier == event.eventIdentifier
                || (e.title == event.title && e.startDate == event.startDate)
            if isTarget && !nowInserted {
                items.append(.nowLine)
                nowInserted = true
            }
            items.append(.event(e, isNext: isTarget, isPast: e.startDate < now && !isTarget))
        }
        return items
    }

    // MARK: Detail pane (right side)

    private var detailPane: some View {
        VStack(spacing: 0) {
            // Top bar: live clock
            HStack {
                Spacer()
                Text(clockString)
                    .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                    .foregroundColor(palette.textQuaternary)
            }
            .padding(.horizontal, 28)
            .frame(height: 52)
            .overlay(alignment: .bottom) { Rectangle().fill(palette.hairline).frame(height: 1) }

            VStack(alignment: .leading, spacing: 0) {
                // Countdown
                countdownLine
                    .padding(.bottom, 22)

                // Title (serif, per the design system)
                Text(event.title ?? "Untitled Meeting")
                    .font(.system(size: 42, weight: .medium, design: .serif))
                    .foregroundColor(palette.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .padding(.bottom, 18)

                // Time range + link row, hairline-bounded
                HStack(spacing: 14) {
                    Text(timeRange)
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundColor(palette.textSecondary)

                    if let url = meetingURL, let provider = provider {
                        Rectangle()
                            .fill(palette.hairlineStrong)
                            .frame(width: 1, height: 16)

                        HStack(spacing: 8) {
                            Text(provider.badgeLetter)
                                .font(.system(size: 10, weight: .bold, design: .serif))
                                .foregroundColor(palette.accentContrast)
                                .frame(width: 20, height: 20)
                                .background(RoundedRectangle(cornerRadius: 5).fill(palette.accent))

                            Text(displayLink(url))
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(palette.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            CopyLinkButton(url: url, palette: palette)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 13)
                .overlay(alignment: .top) { Rectangle().fill(palette.hairlineStrong).frame(height: 1) }
                .overlay(alignment: .bottom) { Rectangle().fill(palette.hairlineStrong).frame(height: 1) }
                .padding(.bottom, 24)

                // Notes (kept from the current app; the design's avatar row was
                // explicitly flagged in the doc as placeholder to be replaced)
                if let notes = event.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 13.5))
                        .foregroundColor(palette.textTertiary)
                        .lineLimit(3)
                }

                Spacer(minLength: 0)

                // Actions
                HStack(spacing: 10) {
                    PanelButton(
                        title: meetingURL != nil ? "Join \(provider?.name ?? "Meeting")" : "OK, got it",
                        style: .primary,
                        palette: palette
                    ) {
                        onAction(.join)
                    }

                    PanelButton(title: "Snooze 2 min", style: .secondary, palette: palette) {
                        onAction(.snooze)
                    }

                    Spacer()

                    PanelButton(title: "Dismiss (esc)", style: .text, palette: palette) {
                        onAction(.dismiss)
                    }
                }
            }
            .padding(.top, 42)
            .padding(.horizontal, 46)
            .padding(.bottom, 34)
        }
    }

    private var countdownLine: some View {
        let interval = event.startDate.timeIntervalSince(now)
        return Group {
            if interval <= 0 {
                (Text("Starting ") + Text("now").fontWeight(.bold).foregroundColor(palette.accent))
            } else if interval < 60 {
                (Text("Starts in ") + Text("\(Int(interval)) seconds").fontWeight(.bold).foregroundColor(palette.accent))
            } else {
                let m = Int(interval) / 60
                (Text("Starts in ") + Text("\(m) minute\(m == 1 ? "" : "s")").fontWeight(.bold).foregroundColor(palette.accent))
            }
        }
        .font(.system(size: 17, weight: .medium))
        .foregroundColor(palette.textTertiary)
    }

    // MARK: Formatting helpers

    private var dayHeader: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: now)
    }

    private var clockString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: now)
    }

    private var timeRange: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        let end = DateFormatter()
        end.dateFormat = "h:mm a"
        return "\(f.string(from: event.startDate)) – \(end.string(from: event.endDate))"
    }

    private func timeShort(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "H:mm"
        return f.string(from: date)
    }

    private func displayLink(_ url: URL) -> String {
        var s = url.absoluteString
        for prefix in ["https://www.", "https://", "http://www.", "http://"] {
            if s.hasPrefix(prefix) { s.removeFirst(prefix.count); break }
        }
        return s
    }
}

// MARK: - Shared panel components

struct CopyLinkButton: View {
    let url: URL
    let palette: AlertPalette
    @State private var copied = false
    @State private var isHovered = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.absoluteString, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
        } label: {
            Text(copied ? "Copied" : "Copy")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(copied ? palette.accent : palette.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isHovered ? palette.hairline : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(palette.hairlineStrong, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct PanelButton: View {
    enum Style { case primary, secondary, text }

    let title: String
    let style: Style
    let palette: AlertPalette
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: style == .text ? 13.5 : 14, weight: style == .primary ? .semibold : .medium))
                .foregroundColor(foreground)
                .padding(.horizontal, style == .text ? 6 : (style == .primary ? 22 : 18))
                .padding(.vertical, 11)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(style == .secondary ? palette.hairlineStrong : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    private var foreground: Color {
        switch style {
        case .primary: return palette.accentContrast
        case .secondary: return palette.textPrimary
        case .text: return isHovered ? palette.textPrimary : palette.textQuaternary
        }
    }

    private var background: Color {
        switch style {
        case .primary: return isHovered ? palette.accent.opacity(0.85) : palette.accent
        case .secondary: return isHovered ? palette.hairline : palette.secondaryButtonFill
        case .text: return Color.clear
        }
    }
}
