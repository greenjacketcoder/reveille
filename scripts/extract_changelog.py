#!/usr/bin/env python3
"""Prints the CHANGELOG.md section for a given version (without the heading).
Used by the release workflow so GitHub Release notes come from the curated
changelog rather than only auto-generated commit lists. Exits non-zero if the
version has no section, which fails the release loudly - same philosophy as
the tag/version match check: a release without changelog notes is a mistake.
"""
import re
import sys

def main():
    if len(sys.argv) != 2:
        print("usage: extract_changelog.py <version>", file=sys.stderr)
        sys.exit(2)
    version = sys.argv[1]

    with open("CHANGELOG.md") as f:
        content = f.read()

    # Match "## [X.Y.Z] - date" through the next "## [" heading or link refs
    pattern = rf"^## \[{re.escape(version)}\][^\n]*\n(.*?)(?=^## \[|^\[)"
    m = re.search(pattern, content, re.DOTALL | re.MULTILINE)
    if not m:
        print(f"::error::CHANGELOG.md has no section for version {version}. "
              f"Add a '## [{version}]' entry before tagging.", file=sys.stderr)
        sys.exit(1)

    print(m.group(1).strip())

if __name__ == "__main__":
    main()
