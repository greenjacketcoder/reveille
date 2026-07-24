# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- The built app and its executable are now named `Reveille` (previously `MacAlert` internally), so the running process appears as "Reveille" in Activity Monitor instead of the old internal name. The bundle identifier is unchanged, so existing permissions, preferences, and updates carry over.

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

[Unreleased]: https://github.com/greenjacketcoder/reveille/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/greenjacketcoder/reveille/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/greenjacketcoder/reveille/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/greenjacketcoder/reveille/releases/tag/v0.1.0
