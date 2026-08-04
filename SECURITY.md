# Security Policy

## Reporting a vulnerability

Please report vulnerabilities privately via
[GitHub's private vulnerability reporting](https://github.com/greenjacketcoder/reveille/security/advisories/new)
rather than opening a public issue. You should get an initial response within
a few days.

## Scope notes

- **Update integrity**: releases are signed with Sparkle (EdDSA); the app
  verifies signatures against a pinned public key before installing any
  update. Anything that could bypass that verification is in scope and
  high priority.
- **Untrusted input**: calendar and reminder contents (titles, notes,
  locations, URLs) are treated as untrusted — anyone can send an invite
  that lands in a calendar. Meeting links are matched by host allowlist
  and must be `https` (or FaceTime's scheme). Bypasses of that matching
  are in scope.
- **Known limitation**: releases are currently ad-hoc signed, not
  notarized (Apple Developer Program enrollment pending). Gatekeeper
  warnings on first launch are expected until then; this is tracked and
  not itself a reportable finding.

## Supported versions

Only the [latest release](https://github.com/greenjacketcoder/reveille/releases/latest)
receives fixes.

## Repository and release-chain protections

- Release artifacts are signed with EdDSA and verified by Sparkle before any
  update is applied, independent of Gatekeeper.
- Each release publishes the SHA-256 of its `.dmg` so a fresh download can be
  verified by hand.
- Release builds are checked in CI for the `get-task-allow` debug entitlement
  and the release fails if it is ever present.
- The Sparkle CLI used for signing is pinned by SHA-256; GitHub Actions are
  pinned to commit SHAs.
- Workflow tokens are least-privilege: read-only except the release workflow,
  which needs `contents: write` to publish.
- `main` and `v*` tags are protected against deletion and force-push.
- Secret scanning with push protection, Dependabot alerts and automated
  security fixes, CodeQL scanning, and private vulnerability reporting are all
  enabled.

## Known residual risk

The Sparkle signing key is held as a GitHub Actions secret, so an attacker who
compromised the repository owner's GitHub account could sign a malicious
update. Strong account 2FA is therefore part of this project's security
posture, not incidental to it.
