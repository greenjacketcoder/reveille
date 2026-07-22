#!/usr/bin/env python3
"""Inserts a new <item> into appcast.xml for a freshly signed release.
Called by .github/workflows/release.yml after building, packaging, and
Sparkle-signing a .dmg. Newest release goes first (Sparkle reads top-down).
"""
import argparse
import re
import sys
from datetime import datetime, timezone

ITEM_TEMPLATE = """        <item>
            <title>Version {version}</title>
            <sparkle:releaseNotesLink>{notes_url}</sparkle:releaseNotesLink>
            <pubDate>{pub_date}</pubDate>
            <enclosure
                url="{dmg_url}"
                sparkle:version="{build}"
                sparkle:shortVersionString="{version}"
                length="{length}"
                type="application/octet-stream"
                sparkle:edSignature="{signature}"
            />
            <sparkle:minimumSystemVersion>{min_os}</sparkle:minimumSystemVersion>
        </item>
"""


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--appcast", default="appcast.xml")
    p.add_argument("--version", required=True, help="CFBundleShortVersionString, e.g. 0.2")
    p.add_argument("--build", required=True, help="CFBundleVersion")
    p.add_argument("--length", required=True)
    p.add_argument("--signature", required=True)
    p.add_argument("--url", required=True, help="Direct .dmg download URL")
    p.add_argument("--notes-url", required=True)
    p.add_argument("--min-os", default="13.0")
    args = p.parse_args()

    with open(args.appcast, "r") as f:
        content = f.read()

    item_xml = ITEM_TEMPLATE.format(
        version=args.version,
        build=args.build,
        length=args.length,
        signature=args.signature,
        dmg_url=args.url,
        notes_url=args.notes_url,
        min_os=args.min_os,
        pub_date=datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S +0000"),
    )

    # Insert right after <language>...</language>, before any existing items
    # or the placeholder template comment.
    marker = re.search(r"<language>.*?</language>\s*\n", content)
    if not marker:
        print("Could not find <language> tag in appcast.xml", file=sys.stderr)
        sys.exit(1)

    insert_at = marker.end()

    # Strip the placeholder "No releases yet" comment block the first time
    # a real release is added, so it doesn't sit above real items forever.
    content = re.sub(r"\s*<!--\s*\n\s*No releases yet.*?-->\n", "\n", content, flags=re.DOTALL)
    marker = re.search(r"<language>.*?</language>\s*\n", content)
    insert_at = marker.end()

    new_content = content[:insert_at] + item_xml + content[insert_at:]

    with open(args.appcast, "w") as f:
        f.write(new_content)

    print(f"Added v{args.version} (build {args.build}) to {args.appcast}")


if __name__ == "__main__":
    main()
