#!/usr/bin/env python3
import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path

def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()

parser = argparse.ArgumentParser(description="Generate a JukaMix release manifest.")
parser.add_argument("version")
parser.add_argument("files", nargs="+")
parser.add_argument("-o", "--output", default="manifest.json")
args = parser.parse_args()

entries = []
for name in sorted(args.files):
    path = Path(name)
    if not path.is_file():
        raise SystemExit(f"Not a file: {path}")
    entries.append({"path": path.name, "size": path.stat().st_size, "sha256": digest(path)})

manifest = {
    "schema": 1,
    "version": args.version,
    "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
    "files": entries,
}
Path(args.output).write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
print(args.output)
