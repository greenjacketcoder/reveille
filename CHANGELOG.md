# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- Keyboard shortcuts (Enter to join/complete, Escape to dismiss, S to snooze) not working in meeting and reminder alerts. The alert windows use a borderless style, and a plain `NSWindow` never becomes key for borderless windows by default — so keystrokes never reached the alert regardless of what the SwiftUI content did. Reminder alerts previously had no keyboard handling at all.

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

[Unreleased]: https://github.com/greenjacketcoder/reveille/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/greenjacketcoder/reveille/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/greenjacketcoder/reveille/releases/tag/v0.1.0
