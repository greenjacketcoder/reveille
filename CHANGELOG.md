# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.7] - 2026-07-29

### Added
- "Show alerts on" preference (Preferences → General → Alerts): choose whether full-screen alerts appear on the display with the pointer or always on your primary display.

### Fixed
- Alerts could appear as a small window stranded in a screen corner instead of covering the display. If macOS reported no active screen — which happens around display sleep/wake, screen lock, and monitor connect/disconnect — the alert window was never given a frame at all, so it kept the panel's intrinsic size at whatever position the system picked. Alerts now always get a frame, with a fallback chain.
- The Calendars tab in Preferences could sit on "Loading calendars…" indefinitely. It now reports what's actually happening: your calendar list, "no calendars enabled", or the specific access problem — with an "Open Privacy Settings" button and a Refresh action. It calls out macOS's "Add Events Only" access in particular, which silently prevents meeting alerts from working at all.
- Showing an alert no longer adds Edit / View / Window / Help menus to the menu bar. Activating the app for an alert makes macOS display its application menu; that menu is now trimmed to just the app menu.

## [0.1.6] - 2026-07-29

### Added
- "Open meetings in" preference (Preferences → General → Joining): join in the provider's desktop app instead of a browser tab. Supports Zoom, Microsoft Teams, and Jitsi; anything else — or a link whose desktop app isn't installed — opens in your browser as before.
- Optional global shortcut to join (Preferences → General → Joining): press it from any app to join the meeting that's running now, or the next one with a link. Choose from ⌃⌥⌘J / M / K / ↩. Off by default, and if nothing is joinable it opens the agenda instead so the press always does something visible. Requires no extra system permissions.

### Changed
- Internal: the recurring-event de-duplication key, menu-bar countdown formatting, and snooze timing now live in the unit-tested support package, so their behaviour is verified in CI on every change.

### Removed
- Deleted an unused leftover menu-bar implementation file from the original project.

## [0.1.5] - 2026-07-27

### Added
- Launch at login: an opt-in toggle in Preferences → General to start Reveille automatically when you log in, so a reboot doesn't silently stop meeting alerts. Backed by the system login-items service, so it stays in sync with System Settings.
- Expanded meeting-provider detection: Webex, GoToMeeting, Whereby, Jitsi, RingCentral, BlueJeans, and Skype (contributed by @Borisserz).
- About tab now shows a plain-language privacy summary — what Reveille accesses (calendars/reminders, locally), and that there's no account, no analytics, and network is used only for updates and opening links you click.
- The menu-bar agenda dropdown now also shows today's all-day events and a "Tomorrow" section, instead of only today's remaining timed meetings.

### Changed
- Full-screen alerts now appear on the display you're actively using (the one with the pointer) rather than always the main display — better for multi-monitor setups.
- Snooze no longer overshoots a meeting: if the chosen snooze duration would land at or after the start time, it instead re-alerts one minute before the meeting begins.

## [0.1.4] - 2026-07-24

### Added
- Menu-bar countdown: the menu bar now shows the next meeting's title and a live countdown next to the icon (e.g. "Standup · 4m"), so the app is useful between alerts, not only at alert time. Can be turned off in Preferences → General.
- Menu-bar agenda dropdown: clicking the icon opens today's remaining meetings in the Daybreak/Nightshift language, each with a one-click Join for detected meeting links, plus Quick Add / Settings / updates / quit in the footer.
- Configurable snooze duration (2 / 5 / 10 / 15 minutes) in Preferences → General.

### Changed
- Snooze now re-shows the alert at a precise time rather than waiting for the next calendar poll, so a snoozed alert can't land minutes late when the sync interval is long.
- The menu-bar "next meeting" view now covers the whole day instead of only the next hour.

### Fixed
- Quick Add now shows a clear error when a meeting can't be saved (no writable calendar, missing permission) instead of silently doing nothing.
- Recurring events no longer suppress alerts for later occurrences: alert de-duplication now distinguishes individual occurrences rather than keying on the shared recurring-event identifier.

## [0.1.3] - 2026-07-24

### Security
- Meeting-link detection now matches the parsed URL host against a provider allowlist instead of substring-matching the whole URL. Previously, a crafted calendar invite with a URL like `https://evil.example/?r=https://zoom.us/` would earn a trusted, provider-labeled Join button; lookalike and suffix-spoofed domains are now rejected, and web meeting links must be `https`. The detection logic now lives in a separate, unit-tested Swift package (14 tests covering the attack cases), run in CI on every change.
- Personal Meeting Links now require `https` (or FaceTime's scheme); plain `http` links are rejected.
- Release pipeline hardening: the Sparkle CLI tools download is verified against a pinned SHA-256 before signing, and GitHub Actions are pinned to commit SHAs. Dependabot keeps both fresh, and CodeQL scanning runs on every push.

### Changed
- The built app and its executable are now named `Reveille` (previously `MacAlert` internally), so the running process appears as "Reveille" in Activity Monitor instead of the old internal name. The bundle identifier is unchanged, so existing permissions, preferences, and updates carry over.
- The About tab shows just the version number, without the internal build counter.

### Fixed
- Preferences and Quick Add windows are now released when closed instead of staying resident for the app's lifetime, so memory no longer accumulates after each interaction.

## [0.1.2] - 2026-07-24

### Added
- Redesigned meeting alert: a calm panel over a dimmed backdrop with today's agenda in a sidebar rail (with a "now" line and the alerting meeting highlighted), a live countdown, a serif title, and a copyable meeting-link row with a provider-labeled Join button
- Automatic light/dark appearance for the alert (Daybreak and Nightshift schemes), following the system setting
- In-app appearance override: Match System / Light / Dark, in Preferences → General
- Custom trumpet app icon and matching menu bar icon (a nod to reveille, the bugle call)
- Reminder alerts redesigned in the same visual language, with Mark Done / Snooze / Open in Reminders / Dismiss

### Changed
- Preferences overhauled: native grouped forms across all tabs, popup pickers, sound preview at your configured volume, URL validation with Enter-to-submit in Meeting Links, the real app icon in About, and a taller default window so nothing clips

### Fixed
- Keyboard shortcuts (Enter to join/complete, Escape to dismiss, S to snooze, O to open a reminder) not working in meeting and reminder alerts — the borderless alert window could never become key, so keystrokes never reached it; reminder alerts previously had no keyboard handling at all
- On-screen shortcut hints showed stale Command-key combinations (⌘S, ⌘↩) after the shortcuts were changed to plain keys

## [0.1.1] - 2026-07-23

### Fixed
- `Sparkle.framework` failing to load in installed builds, silently preventing the app from launching outside of Xcode. Sparkle's official binary release is signed with its own Apple Developer Team ID; since Reveille is ad-hoc signed (no Team ID yet, pending Apple Developer Program enrollment), macOS's hardened runtime Library Validation blocked loading it. Added `com.apple.security.cs.disable-library-validation` to the app's entitlements.

## [0.1.0] - 2026-07-23

Initial public release.

### Added
- Full-screen, FaceTime-style meeting alerts with automatic meeting-link detection (Zoom, Google Meet, Microsoft Teams, Discord, Slack, FaceTime), snooze, and one-click join
- Apple Reminders support, including marking reminders complete or opening them in Reminders.app directly from the alert
- Quick Add Meeting with duration presets, calendar selection, and auto-filled personal meeting links
- Configurable sync interval, alert timing, and 7 built-in alert sounds with previews and volume control
- Personal Meeting Links for one-click access to recurring rooms
- Retry-with-backoff for calendar/reminders access acquisition
- Automatic updates via Sparkle, with EdDSA-signed releases
- Release automation via GitHub Actions: tag push builds, packages, and Sparkle-signs a `.dmg`, updates the appcast, and publishes a GitHub Release

[Unreleased]: https://github.com/greenjacketcoder/reveille/compare/v0.1.7...HEAD
[0.1.7]: https://github.com/greenjacketcoder/reveille/compare/v0.1.6...v0.1.7
[0.1.6]: https://github.com/greenjacketcoder/reveille/compare/v0.1.5...v0.1.6
[0.1.5]: https://github.com/greenjacketcoder/reveille/compare/v0.1.4...v0.1.5
[0.1.4]: https://github.com/greenjacketcoder/reveille/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/greenjacketcoder/reveille/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/greenjacketcoder/reveille/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/greenjacketcoder/reveille/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/greenjacketcoder/reveille/releases/tag/v0.1.0
