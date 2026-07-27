# Roadmap

Where Reveille is headed. This is a direction, not a promise — priorities shift.
For released changes, see [CHANGELOG.md](CHANGELOG.md).

## Shipped

- Full-screen meeting alerts with a calm, structured panel (agenda rail, live countdown, provider-labeled Join)
- Automatic light/dark appearance, plus a manual Match System / Light / Dark override
- Apple Reminders support (complete, snooze, open from the alert)
- Quick Add Meeting with duration presets, calendar selection, and saved-link auto-fill
- Menu-bar countdown showing the next meeting's title and time-until
- Menu-bar agenda dropdown — today's meetings with one-click join
- Host-allowlisted meeting-link detection (Zoom, Google Meet, Teams, Discord, Slack, FaceTime, Webex, GoToMeeting, Whereby, Jitsi, RingCentral, BlueJeans, Skype)
- Configurable, precise snooze
- Automatic updates (Sparkle, EdDSA-signed), notarization pending

## Next

In rough priority order (see linked issues):

1. **Launch at login** ([#7](https://github.com/greenjacketcoder/reveille/issues/7)) — auto-start so a reboot doesn't silently stop alerts.
2. **Global hotkey to join the next meeting** ([#8](https://github.com/greenjacketcoder/reveille/issues/8)) — one keystroke from anywhere.
3. **Open in native app vs. browser** ([#9](https://github.com/greenjacketcoder/reveille/issues/9)) — join Zoom/Teams in their app if preferred.
4. **Configurable menu-bar display** ([#10](https://github.com/greenjacketcoder/reveille/issues/10)) — icon-only / title / countdown.
5. **Notarization** — Apple Developer Program enrollment, so downloads launch without the Gatekeeper workaround.

## Considering

- **Ad-hoc instant meeting** ([#11](https://github.com/greenjacketcoder/reveille/issues/11)) — create a meeting now and join it; needs a privacy-preserving link source.
- **Tomorrow + all-day events in the dropdown** — the agenda is today-only right now.
- **AppleScript / Shortcuts hooks on join** — e.g. pause music or set Do Not Disturb when joining.
- **"Running late" action** — notify the organizer with one tap from the alert. Needs a clear, privacy-respecting mechanism.
- **Homebrew cask** — `brew install reveille` for command-line-comfortable users.

## Not planned

These conflict with Reveille's core positioning (local-only, no accounts, no telemetry) and aren't planned unless that positioning changes:

- **Third-party task integrations requiring accounts/API tokens** (e.g. Todoist) — would introduce outbound calls to a third party and account linking. Apple Reminders is supported precisely because it stays on-device.
- **Direct Google Calendar (or other cloud) integration** — Calendar.app already syncs every major provider on-device, without Reveille needing OAuth or network access to your calendar data.
- **Usage analytics / meeting stats tracking** — this is telemetry by another name, even kept local.

## Requests

Have an idea? Open an [issue](https://github.com/greenjacketcoder/reveille/issues)
with the `enhancement` label, or 👍 an existing one to signal interest.
