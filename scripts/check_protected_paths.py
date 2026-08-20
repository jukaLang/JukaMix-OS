#!/usr/bin/env python3
import argparse
from pathlib import PurePosixPath

parser = argparse.ArgumentParser(description="Reject update paths that target protected user data.")
parser.add_argument("paths", nargs="*")
parser.add_argument("--list", default="config/protected-paths.txt")
args = parser.parse_args()

with open(args.list, encoding="utf-8") as handle:
    protected = [
        line.strip().strip("/").casefold()
        for line in handle
        if line.strip() and not line.lstrip().startswith("#")
    ]

failed = []
for raw in args.paths:
    path = str(PurePosixPath(raw.replace("\\", "/"))).strip("/").casefold()
    if path == ".." or path.startswith("../") or "/../" in f"/{path}/":
        failed.append((raw, "path traversal"))
        continue
    for root in protected:
        if path == root or path.startswith(root + "/"):
            failed.append((raw, root))
            break

if failed:
    for path, reason in failed:
        print(f"PROTECTED: {path} ({reason})")
    raise SystemExit(1)
print(f"Checked {len(args.paths)} path(s); no protected targets found.")
