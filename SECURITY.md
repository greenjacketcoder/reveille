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
