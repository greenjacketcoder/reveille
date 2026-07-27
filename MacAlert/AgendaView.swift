import SwiftUI
import EventKit
import MeetingLink

/// The menu-bar dropdown: today's remaining events in the Daybreak/Nightshift
/// language, each with a one-click Join for detected meeting links, plus the
/// app actions (Quick Add, Preferences, updates, quit) that used to live in
/// the plain NSMenu.
struct AgendaView: View {
    let events: [EKEvent]
    var allDayEvents: [EKEvent] = []
    var tomorrowEvents: [EKEvent] = []
    let onJoin: (EKEvent) -> Void
    let onQuickAdd: () -> Void
    let onPreferences: () -> Void
    let onCheckForUpdates: () -> Void
    let onQuit: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var now = Date()
    @State private var timer: Timer?

    private var palette: AlertPalette { AlertPalette.palette(for: colorScheme) }

    private var upcoming: [EKEvent] {
        events.filter { $0.endDate > now }.sorted { $0.startDate < $1.startDate }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(palette.hairline)

            if upcoming.isEmpty && allDayEvents.isEmpty && tomorrowEvents.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        // All-day banner (today)
                        ForEach(Array(allDayEvents.enumerated()), id: \.offset) { _, event in
                            AllDayRow(event: event, palette: palette)
                        }
                        if !allDayEvents.isEmpty && (!upcoming.isEmpty || !tomorrowEvents.isEmpty) {
                            Divider().overlay(palette.hairline).padding(.vertical, 4)
                        }

                        // Today's remaining timed events
                        ForEach(Array(upcoming.enumerated()), id: \.offset) { _, event in
                            AgendaRow(event: event, now: now, palette: palette, onJoin: onJoin)
                        }

                        // Tomorrow
                        if !tomorrowEvents.isEmpty {
                            SectionLabel(text: "Tomorrow", palette: palette)
                            ForEach(Array(tomorrowEvents.enumerated()), id: \.offset) { _, event in
                                AgendaRow(event: event, now: now, palette: palette, onJoin: onJoin)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                }
                .frame(maxHeight: 380)
            }

            Divider().overlay(palette.hairline)
            footer
        }
        .frame(width: 320)
        .background(palette.background)
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in now = Date() }
        }
        .onDisappear { timer?.invalidate() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(palette.accent)
                .frame(width: 10, height: 10)
            Text("Today")
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundColor(palette.textPrimary)
            Spacer()
            Text(dateString)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(palette.textQuaternary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("No more meetings today")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(palette.textSecondary)
            Text("Enjoy the quiet.")
                .font(.system(size: 11))
                .foregroundColor(palette.textQuaternary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var footer: some View {
        HStack(spacing: 0) {
            FooterButton(title: "Quick Add", systemImage: "plus.circle", palette: palette, action: onQuickAdd)
            FooterButton(title: "Settings", systemImage: "gearshape", palette: palette, action: onPreferences)
            Spacer()
            FooterMenu(palette: palette, onCheckForUpdates: onCheckForUpdates, onQuit: onQuit)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: now)
    }
}

private struct AgendaRow: View {
    let event: EKEvent
    let now: Date
    let palette: AlertPalette
    let onJoin: (EKEvent) -> Void

    @State private var isHovered = false

    private var meetingURL: URL? {
        // Same host-allowlisted detection the alert uses.
        if let url = event.url, MeetingLinkDetector.isMeetingURL(url) { return url }
        let text = (event.notes ?? "") + " " + (event.location ?? "")
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
        for m in matches {
            if let r = Range(m.range, in: text), let u = URL(string: String(text[r])),
               MeetingLinkDetector.isMeetingURL(u) { return u }
        }
        return nil
    }

    private var isNow: Bool { event.startDate <= now && event.endDate > now }

    var body: some View {
        HStack(spacing: 10) {
            Text(timeString)
                .font(.system(size: 11, weight: isNow ? .semibold : .medium, design: .monospaced))
                .foregroundColor(isNow ? palette.accent : palette.textTertiary)
                .frame(width: 46, alignment: .leading)

            Text(event.title ?? "Untitled")
                .font(.system(size: 13, weight: isNow ? .semibold : .regular))
                .foregroundColor(palette.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 4)

            if let url = meetingURL {
                Button {
                    onJoin(event)
                } label: {
                    Text("Join")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(palette.accentContrast)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(palette.accent))
                }
                .buttonStyle(.plain)
                .help(url.absoluteString)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isHovered ? palette.hairline : (isNow ? palette.rail : Color.clear))
        )
        .onHover { isHovered = $0 }
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: event.startDate)
    }
}

private struct SectionLabel: View {
    let text: String
    let palette: AlertPalette

    var body: some View {
        HStack {
            Text(text.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(palette.textQuaternary)
                .tracking(0.5)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 2)
    }
}

private struct AllDayRow: View {
    let event: EKEvent
    let palette: AlertPalette

    var body: some View {
        HStack(spacing: 10) {
            Text("All day")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(palette.textTertiary)
                .frame(width: 46, alignment: .leading)
            Text(event.title ?? "Untitled")
                .font(.system(size: 13))
                .foregroundColor(palette.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 7).fill(palette.rail))
    }
}

private struct FooterButton: View {
    let title: String
    let systemImage: String
    let palette: AlertPalette
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isHovered ? palette.textPrimary : palette.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(isHovered ? palette.hairline : Color.clear))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct FooterMenu: View {
    let palette: AlertPalette
    let onCheckForUpdates: () -> Void
    let onQuit: () -> Void

    var body: some View {
        Menu {
            Button("Check for Updates…", action: onCheckForUpdates)
            Divider()
            Button("Quit Reveille", action: onQuit)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 13))
                .foregroundColor(palette.textSecondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .padding(.horizontal, 6)
    }
}
