#!/usr/bin/env python3
# Duplicate ROM finder for JukaMix OS.
#
# Finds exact content duplicates (same size + same md5) inside one system
# directory and stashes the extras into /mnt/SDCARD/Data/duplicates/<system>/.
# Files are MOVED, never deleted, so a mistaken run is trivially reversible.
# Dot-folders (e.g. .multi-disc) and app/playlist files are ignored.
#
# Usage: python3.11 "Duplicate Finder.py" <system roms dir>
# Prints a TOTAL_DUPLICATES=<n> and TOTAL_SAVED_MB=<mb> line for the UI.

import hashlib
import os
import shutil
import sys
from pathlib import Path

# SD card root; override with JUKAMIX_SD_ROOT for host-side testing.
SD_ROOT = Path(os.environ.get("JUKAMIX_SD_ROOT", "/mnt/SDCARD"))

CHUNK = 64 * 1024
SKIP_SUFFIXES = {".m3u", ".txt", ".launch", ".db", ".png", ".jpg", ".jpeg"}
SKIP_NAMES = {"Roms_cache7.db"}


def usage():
    print('Usage: python3.11 "Duplicate Finder.py" <system roms dir>')
    sys.exit(1)


def md5_of(path):
    h = hashlib.md5()
    with open(path, "rb") as fh:
        while True:
            block = fh.read(CHUNK)
            if not block:
                break
            h.update(block)
    return h.hexdigest()


if len(sys.argv) != 2:
    usage()

roms_dir = Path(sys.argv[1]).resolve()
if not roms_dir.is_dir():
    print(f"Directory not found: {roms_dir}")
    sys.exit(1)

system = roms_dir.name
dup_root = SD_ROOT / "Data/duplicates" / system

# Group candidate files by size, then confirm with a full md5.
by_size = {}
for entry in os.scandir(roms_dir):
    if not entry.is_file():
        continue
    name = entry.name
    if name.startswith(".") or name in SKIP_NAMES:
        continue
    if Path(name).suffix.lower() in SKIP_SUFFIXES:
        continue
    try:
        size = entry.stat().st_size
    except OSError:
        continue
    if size > 0:
        by_size.setdefault(size, []).append(entry.path)

moved = 0
saved = 0
for size, paths in by_size.items():
    if len(paths) < 2:
        continue
    groups = {}
    for p in paths:
        try:
            groups.setdefault(md5_of(p), []).append(p)
        except OSError:
            continue
    for digest, group in groups.items():
        if len(group) < 2:
            continue
        group.sort()
        keeper = group[0]
        for dup in group[1:]:
            dup_path = Path(dup)
            dup_root.mkdir(parents=True, exist_ok=True)
            dest = dup_root / dup_path.name
            try:
                shutil.move(str(dup_path), str(dest))
            except OSError as exc:
                print(f"  skip {dup_path.name}: {exc}")
                continue
            moved += 1
            saved += size
            print(f"  dup: {dup_path.name} -> Data/duplicates/{system}/{dup_path.name} (kept {Path(keeper).name})")

print(f"TOTAL_DUPLICATES={moved}")
print(f"TOTAL_SAVED_MB={saved // (1024 * 1024)}")
