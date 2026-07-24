# Roadmap

Where Reveille is headed. This is a direction, not a promise — priorities shift.
For released changes, see [CHANGELOG.md](CHANGELOG.md).

## Shipped

- Full-screen meeting alerts with a calm, structured panel (agenda rail, live countdown, provider-labeled Join)
- Automatic light/dark appearance, plus a manual Match System / Light / Dark override
- Apple Reminders support (complete, snooze, open from the alert)
- Quick Add Meeting with duration presets, calendar selection, and saved-link auto-fill
- Menu-bar countdown showing the next meeting's title and time-until
- Host-allowlisted meeting-link detection (Zoom, Google Meet, Teams, Discord, Slack, FaceTime)
- Automatic updates (Sparkle, EdDSA-signed), notarization pending

## Next

- **Menu-bar agenda dropdown** — click the icon to see today's meetings with one-click join, in the same visual language as the alert.
- **More meeting providers** — expand detection beyond the current six (Webex, GoToMeeting, Whereby, Jitsi, RingCentral, BlueJeans, and others). Now that detection lives in a tested package, each addition is one allowlist entry plus a test.
- **Notarization** — Apple Developer Program enrollment, so downloads launch without the Gatekeeper workaround.

## Considering

- **"Running late" action** — notify the organizer with one tap from the alert. Needs a clear, privacy-respecting mechanism before it's worth building.
- **Homebrew tap** — `brew install` distribution for command-line-comfortable users.
- **Week-at-a-glance view** — a broader agenda surface beyond today.

## Not planned

These conflict with Reveille's core positioning (local-only, no accounts, no telemetry) and aren't planned unless that positioning changes:

- **Third-party task integrations requiring accounts/API tokens** (e.g. Todoist) — would introduce outbound calls to a third party and account linking. Apple Reminders is supported precisely because it stays on-device.
- **Usage analytics / meeting stats tracking** — this is telemetry by another name, even kept local.

## Requests

Have an idea? Open an [issue](https://github.com/greenjacketcoder/reveille/issues)
with the `enhancement` label, or 👍 an existing one to signal interest.
