import SwiftUI
import EventKit

struct ReminderAlertView: View {
    let reminder: EKReminder
    let onAction: (AlertAction) -> Void

    @State private var timeRemaining: String = ""
    @State private var timer: Timer?

    @State private var pulseAnimation = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.92)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if let dueDate = reminder.dueDateComponents?.date {
                    Text(formatDateHeader(dueDate))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 40)
                }

                Spacer()

                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        Text(reminder.title ?? "Untitled Reminder")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 60)
                    }

                    VStack(spacing: 12) {
                        Text(timeRemaining)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 48)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                Color.orange.opacity(pulseAnimation ? 0.6 : 0.3),
                                                Color.yellow.opacity(pulseAnimation ? 0.6 : 0.3)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                    )

                    if let notes = reminder.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, 80)
                            .padding(.top, 8)
                    }
                }

                Spacer()

                HStack(spacing: 16) {
                    ReminderButton(
                        title: "dismiss",
                        shortcut: "ESC",
                        color: Color.white.opacity(0.12),
                        textColor: .white.opacity(0.9)
                    ) {
                        onAction(.dismiss)
                    }

                    ReminderButton(
                        title: "snooze (2min)",
                        shortcut: "S",
                        color: Color.orange.opacity(0.85),
                        textColor: .white
                    ) {
                        onAction(.snooze)
                    }

                    ReminderButton(
                        title: "open",
                        shortcut: "O",
                        color: Color.white.opacity(0.12),
                        textColor: .white.opacity(0.9)
                    ) {
                        onAction(.open)
                    }

                    ReminderButton(
                        title: "done",
                        shortcut: "↩",
                        color: Color.green,
                        textColor: .white,
                        isPrimary: true
                    ) {
                        onAction(.complete)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            updateTimeRemaining()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                updateTimeRemaining()
            }
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func updateTimeRemaining() {
        guard let dueDate = reminder.dueDateComponents?.date else {
            timeRemaining = "Reminder Due Now"
            return
        }

        let now = Date()
        let interval = dueDate.timeIntervalSince(now)

        if interval <= 0 {
            timeRemaining = "Reminder Due Now"
        } else {
            let minutes = Int(interval) / 60

            if minutes > 0 {
                timeRemaining = "Reminder Due In \(minutes) min\(minutes == 1 ? "" : "s")"
            } else {
                let seconds = Int(interval)
                timeRemaining = "Reminder Due In \(seconds) sec\(seconds == 1 ? "" : "s")"
            }
        }
    }

    private func formatDateHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d • h:mm a"
        return formatter.string(from: date)
    }
}

struct ReminderButton: View {
    let title: String
    let shortcut: String
    let color: Color
    let textColor: Color
    var isPrimary: Bool = false

    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 17, weight: isPrimary ? .semibold : .medium))
                    .foregroundColor(textColor)

                Text(shortcut)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(textColor.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                isPrimary ? Color.green.opacity(0.5) : Color.clear,
                                lineWidth: isPrimary ? 2 : 0
                            )
                    )
                    .shadow(color: isPrimary ? Color.green.opacity(0.3) : Color.clear, radius: 12, x: 0, y: 4)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
