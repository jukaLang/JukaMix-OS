#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path

def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()

parser = argparse.ArgumentParser(description="Verify files in a JukaMix release manifest.")
parser.add_argument("manifest")
parser.add_argument("--directory", default=".")
args = parser.parse_args()

manifest_path = Path(args.manifest)
base = Path(args.directory)
data = json.loads(manifest_path.read_text(encoding="utf-8"))
failures = []

for entry in data.get("files", []):
    path = base / entry["path"]
    if not path.is_file():
        failures.append(f"missing: {entry['path']}")
        continue
    if path.stat().st_size != entry["size"]:
        failures.append(f"size mismatch: {entry['path']}")
        continue
    actual = digest(path)
    if actual != entry["sha256"]:
        failures.append(f"checksum mismatch: {entry['path']}")

if failures:
    print("\n".join(failures))
    raise SystemExit(1)
print(f"Verified {len(data.get('files', []))} file(s).")
