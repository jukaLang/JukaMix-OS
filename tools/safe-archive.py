#!/usr/bin/env python3
"""Inspect ZIP/TAR packages without extracting unsafe entries."""
from __future__ import annotations
import argparse
from pathlib import Path, PurePosixPath
import stat
import tarfile
import zipfile

PROTECTED = ("Roms/", "BIOS/", "Saves/", "States/")

def safe_name(name: str) -> bool:
    normalized = name.replace("\\", "/")
    path = PurePosixPath(normalized)
    return bool(normalized) and not normalized.startswith("/") and ".." not in path.parts

def protected(name: str) -> bool:
    normalized = name.replace("\\", "/").lstrip("./")
    return any(normalized.casefold().startswith(item.casefold()) for item in PROTECTED)

def inspect_zip(path: Path) -> list[str]:
    errors = []
    with zipfile.ZipFile(path) as archive:
        for item in archive.infolist():
            mode = (item.external_attr >> 16) & 0o170000
            if not safe_name(item.filename):
                errors.append(f"unsafe path: {item.filename}")
            if protected(item.filename):
                errors.append(f"protected destination: {item.filename}")
            if mode == stat.S_IFLNK:
                errors.append(f"symbolic link: {item.filename}")
    return errors

def inspect_tar(path: Path) -> list[str]:
    errors = []
    with tarfile.open(path) as archive:
        for item in archive.getmembers():
            if not safe_name(item.name):
                errors.append(f"unsafe path: {item.name}")
            if protected(item.name):
                errors.append(f"protected destination: {item.name}")
            if item.issym() or item.islnk() or item.isdev():
                errors.append(f"unsafe entry type: {item.name}")
    return errors

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()
    try:
        errors = inspect_zip(args.archive) if zipfile.is_zipfile(args.archive) else inspect_tar(args.archive)
    except (OSError, zipfile.BadZipFile, tarfile.TarError) as error:
        print(f"ERROR: {error}")
        return 2
    for error in errors:
        print(f"ERROR: {error}")
    if errors:
        return 1
    print(f"OK: {args.archive}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
