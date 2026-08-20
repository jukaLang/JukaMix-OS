#!/usr/bin/env python3
import argparse
import os
import shutil
import stat
import zipfile
from pathlib import Path, PurePosixPath

parser = argparse.ArgumentParser(description="Inspect and safely extract a ZIP archive.")
parser.add_argument("archive")
parser.add_argument("destination")
parser.add_argument("--inspect-only", action="store_true")
args = parser.parse_args()

archive = Path(args.archive)
destination = Path(args.destination).resolve()

def normalized_member(name):
    if "\\" in name:
        raise ValueError(f"backslash path rejected: {name}")
    item = PurePosixPath(name)
    if item.is_absolute() or ".." in item.parts:
        raise ValueError(f"unsafe path rejected: {name}")
    if not item.parts or item.parts[0] in ("", "."):
        raise ValueError(f"invalid path rejected: {name}")
    return item

with zipfile.ZipFile(archive) as zf:
    checked = []
    for info in zf.infolist():
        item = normalized_member(info.filename)
        mode = info.external_attr >> 16
        if stat.S_ISLNK(mode) or stat.S_ISCHR(mode) or stat.S_ISBLK(mode) or stat.S_ISFIFO(mode):
            raise SystemExit(f"special file rejected: {info.filename}")
        checked.append((info, item))

    print(f"Archive inspection passed: {len(checked)} entries")
    if args.inspect_only:
        raise SystemExit(0)

    destination.mkdir(parents=True, exist_ok=True)
    for info, item in checked:
        target = (destination / Path(*item.parts)).resolve()
        if destination not in target.parents and target != destination:
            raise SystemExit(f"path escaped destination: {info.filename}")
        if info.is_dir():
            target.mkdir(parents=True, exist_ok=True)
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        with zf.open(info) as src, target.open("wb") as dst:
            shutil.copyfileobj(src, dst)
        mode = (info.external_attr >> 16) & 0o777
        if mode:
            os.chmod(target, mode & 0o755)
