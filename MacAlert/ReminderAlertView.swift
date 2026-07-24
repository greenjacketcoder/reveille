import SwiftUI
import EventKit

/// Reminder alert in the same Daybreak/Nightshift panel language as the
/// meeting alert, minus the agenda rail (reminders don't belong to the
/// day-timeline in the same way; a single focused card is calmer).
struct ReminderAlertView: View {
    let reminder: EKReminder
    let onAction: (AlertAction) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var now = Date()
    @State private var timer: Timer?

    private var palette: AlertPalette { AlertPalette.palette(for: colorScheme) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: brand + live clock
                HStack {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(palette.accent)
                            .frame(width: 12, height: 12)
                        Text("Reveille")
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                            .foregroundColor(palette.textPrimary)
                    }
                    Spacer()
                    Text(clockString)
                        .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                        .foregroundColor(palette.textQuaternary)
                }
                .padding(.horizontal, 28)
                .frame(height: 52)
                .overlay(alignment: .bottom) { Rectangle().fill(palette.hairline).frame(height: 1) }

                VStack(alignment: .leading, spacing: 0) {
                    dueLine
                        .padding(.bottom, 22)

                    Text(reminder.title ?? "Untitled Reminder")
                        .font(.system(size: 42, weight: .medium, design: .serif))
                        .foregroundColor(palette.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .padding(.bottom, 18)

                    if let notes = reminder.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 13.5))
                            .foregroundColor(palette.textTertiary)
                            .lineLimit(3)
                            .padding(.vertical, 13)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(alignment: .top) { Rectangle().fill(palette.hairlineStrong).frame(height: 1) }
                            .overlay(alignment: .bottom) { Rectangle().fill(palette.hairlineStrong).frame(height: 1) }
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 10) {
                        PanelButton(title: "Mark Done", style: .primary, palette: palette) {
                            onAction(.complete)
                        }

                        PanelButton(title: "Snooze 2 min", style: .secondary, palette: palette) {
                            onAction(.snooze)
                        }

                        PanelButton(title: "Open in Reminders", style: .secondary, palette: palette) {
                            onAction(.open)
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
            .frame(width: 680, height: 400)
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

    private var dueLine: some View {
        let interval = reminder.dueDateComponents?.date?.timeIntervalSince(now) ?? 0
        return Group {
            if interval <= 0 {
                (Text("Due ") + Text("now").fontWeight(.bold).foregroundColor(palette.accent))
            } else if interval < 60 {
                (Text("Due in ") + Text("\(Int(interval)) seconds").fontWeight(.bold).foregroundColor(palette.accent))
            } else {
                let m = Int(interval) / 60
                (Text("Due in ") + Text("\(m) minute\(m == 1 ? "" : "s")").fontWeight(.bold).foregroundColor(palette.accent))
            }
        }
        .font(.system(size: 17, weight: .medium))
        .foregroundColor(palette.textTertiary)
    }

    private var clockString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: now)
    }
}
