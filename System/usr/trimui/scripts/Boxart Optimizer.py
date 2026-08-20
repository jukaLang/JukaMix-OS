#!/usr/bin/env python3
# Boxart image optimizer for JukaMix OS.
#
# Uses the bundled Pillow to shrink images whose longest side exceeds a cap
# (default 512 px) and re-saves them optimized. A file is only overwritten
# when the result is actually smaller, so a second run is a no-op.
#
# Usage: python3.11 "Boxart Optimizer.py" <images dir> [max_dim]
# Prints a TOTAL_OPTIMIZED=<n> and TOTAL_SAVED_MB=<mb> line for the UI.

import os
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Pillow is not available in this build.")
    sys.exit(1)


def usage():
    print('Usage: python3.11 "Boxart Optimizer.py" <images dir> [max_dim]')
    sys.exit(1)


if len(sys.argv) not in (2, 3):
    usage()

imgs_root = Path(sys.argv[1]).resolve()
if not imgs_root.is_dir():
    print(f"Directory not found: {imgs_root}")
    sys.exit(1)

try:
    max_dim = int(sys.argv[2]) if len(sys.argv) > 2 else 512
except ValueError:
    usage()
if max_dim < 64:
    max_dim = 512

optimized = 0
saved = 0
for img_path in sorted(imgs_root.rglob("*")):
    if not img_path.is_file():
        continue
    ext = img_path.suffix.lower()
    if ext not in (".png", ".jpg", ".jpeg"):
        continue
    try:
        with Image.open(img_path) as im:
            im.load()
            w, h = im.size
            longest = max(w, h)
            if longest <= max_dim:
                continue
            ratio = max_dim / float(longest)
            new_size = (int(w * ratio + 0.5), int(h * ratio + 0.5))
            resized = im.resize(new_size, Image.LANCZOS)
            tmp = img_path.with_name(img_path.name + ".jmopt")
            if ext == ".png":
                resized.save(tmp, format="PNG", optimize=True)
            else:
                resized.convert("RGB").save(tmp, format="JPEG", quality=85, optimize=True)
            resized.close()
            old_size = img_path.stat().st_size
            new_size_bytes = tmp.stat().st_size
            if new_size_bytes < old_size:
                os.replace(tmp, img_path)
                saved += old_size - new_size_bytes
                optimized += 1
                print(f"  {img_path.relative_to(imgs_root)}: {w}x{h} -> {new_size[0]}x{new_size[1]} "
                      f"({old_size // 1024} KB -> {new_size_bytes // 1024} KB)")
            else:
                tmp.unlink()
                print(f"  keep  {img_path.relative_to(imgs_root)} (already optimal)")
    except Exception as exc:
        print(f"  skip  {img_path.name}: {exc}")

print(f"TOTAL_OPTIMIZED={optimized}")
print(f"TOTAL_SAVED_MB={saved // (1024 * 1024)}")
