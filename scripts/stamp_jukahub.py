#!/usr/bin/env python3
"""Stamp the JukaHub patch index with a release stamp and matching URLs.

The tracked Apps/JukaHub/patch/packages.json is a template. The release build
(build_release.sh) and the CI workflow both call this so the image ships a
packages.json whose version and release URLs reference the release that
actually contains it; otherwise JukaHub's Patch view 404s.

Usage: stamp_jukahub.py <packages.json> <stamp>
"""

import json
import sys


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} <packages.json> <stamp>", file=sys.stderr)
        return 2
    path, ver = sys.argv[1], sys.argv[2]

    with open(path, encoding="utf-8") as f:
        data = json.load(f)

    for pkg in data.get("packages", []):
        if pkg.get("id") != "jukamix-os":
            continue
        pkg["version"] = ver
        pkg["archive_url"] = (
            "https://github.com/jukaLang/JukaMix-OS/releases/download/"
            f"JukaMix_{ver}/JukaMix_{ver}.zip"
        )
        pkg["manifest_url"] = (
            "https://github.com/jukaLang/JukaMix-OS/releases/download/"
            f"JukaMix_{ver}/manifest.txt"
        )
        pkg["files"] = [
            {"src": f"JukaMix_{ver}.zip", "dest": f"/JukaMix_{ver}.zip"}
        ]

    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
