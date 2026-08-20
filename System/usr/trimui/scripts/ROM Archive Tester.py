#!/usr/bin/env python3
# ROM archive integrity tester for JukaMix OS.
#
# Tests every .zip inside one system directory (checksum-based, via the
# stdlib zipfile module) and stashes broken archives into
# /mnt/SDCARD/Data/archives-corrupt/<system>/. Files are MOVED, never deleted.
# Non-zip formats (.7z, .chd, ...) are skipped with a note.
#
# Usage: python3.11 "ROM Archive Tester.py" <system roms dir>
# Prints a TESTED=<n> and TOTAL_CORRUPT=<n> line for the UI.

import os
import shutil
import sys
import zipfile
from pathlib import Path

# SD card root; override with JUKAMIX_SD_ROOT for host-side testing.
SD_ROOT = Path(os.environ.get("JUKAMIX_SD_ROOT", "/mnt/SDCARD"))


def usage():
    print('Usage: python3.11 "ROM Archive Tester.py" <system roms dir>')
    sys.exit(1)


if len(sys.argv) != 2:
    usage()

roms_dir = Path(sys.argv[1]).resolve()
if not roms_dir.is_dir():
    print(f"Directory not found: {roms_dir}")
    sys.exit(1)

system = roms_dir.name
corrupt_root = SD_ROOT / "Data/archives-corrupt" / system

tested = 0
corrupt = 0
for entry in sorted(os.scandir(roms_dir), key=lambda e: e.name):
    if not entry.is_file():
        continue
    name = entry.name
    if name.startswith("."):
        continue
    ext = Path(name).suffix.lower()
    if ext != ".zip":
        continue
    tested += 1
    bad = False
    try:
        with zipfile.ZipFile(entry.path) as zf:
            bad = zf.testzip() is not None
    except (zipfile.BadZipFile, OSError):
        bad = True
    if bad:
        corrupt_root.mkdir(parents=True, exist_ok=True)
        dest = corrupt_root / name
        try:
            shutil.move(entry.path, str(dest))
        except OSError as exc:
            print(f"  skip {name}: {exc}")
            continue
        corrupt += 1
        print(f"  corrupt: {name} -> Data/archives-corrupt/{system}/{name}")

print(f"TESTED={tested}")
print(f"TOTAL_CORRUPT={corrupt}")
