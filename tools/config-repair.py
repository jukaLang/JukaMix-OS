#!/usr/bin/env python3
"""Validate JSON files and atomically restore the newest valid backup."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import shutil
import tempfile

def valid(path: Path) -> bool:
    try:
        with path.open("r", encoding="utf-8") as handle:
            json.load(handle)
        return True
    except (OSError, UnicodeError, json.JSONDecodeError):
        return False

def atomic_copy(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=destination.name + ".", dir=destination.parent)
    os.close(fd)
    try:
        shutil.copy2(source, temporary)
        os.replace(temporary, destination)
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("config", type=Path)
    parser.add_argument("--backup-glob", default="*.bak*")
    args = parser.parse_args()

    if valid(args.config):
        print(f"OK: {args.config}")
        return 0

    candidates = sorted(
        args.config.parent.glob(args.backup_glob),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    for candidate in candidates:
        if valid(candidate):
            broken = args.config.with_suffix(args.config.suffix + ".broken")
            if args.config.exists():
                atomic_copy(args.config, broken)
            atomic_copy(candidate, args.config)
            print(f"RESTORED: {args.config} from {candidate}")
            return 0

    print(f"ERROR: no valid configuration or backup for {args.config}")
    return 1

if __name__ == "__main__":
    raise SystemExit(main())
