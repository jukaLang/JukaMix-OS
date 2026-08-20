#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

errors=0

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    errors=$((errors + 1))
}

printf '%s\n' "Checking JSON files..."
# Single python process validates every JSON file (was one python3 fork each).
python3 - <<'PY' || fail "Invalid JSON found"
import json
from pathlib import Path
bad = []
for path in sorted(Path(".").rglob("*.json")):
    if ".git" in path.parts or "dist" in path.parts:
        continue
    try:
        json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        bad.append(f"{path}: {exc}")
if bad:
    raise SystemExit("\n".join(bad))
PY

printf '%s\n' "Checking YAML files..."
python3 - <<'PY' || fail "Basic YAML checks failed"
from pathlib import Path
for path in list(Path(".github").rglob("*.yml")) + list(Path(".github").rglob("*.yaml")):
    text = path.read_text(encoding="utf-8")
    if "\t" in text:
        raise SystemExit(f"{path}: tabs are not allowed in YAML indentation")
print("YAML indentation check passed")
PY

printf '%s\n' "Checking shell scripts..."
shell_files="$(find . -type f \( -name '*.sh' -o -name '*.bash' \) \
    -not -path './.git/*' -not -path './dist/*' | sort)"
if command -v shellcheck >/dev/null 2>&1 && [ -n "$shell_files" ]; then
    # SC3043 is allowed because some inherited /bin/sh scripts use local.
    printf '%s\n' "$shell_files" | xargs shellcheck -e SC3043 || fail "ShellCheck failed"
else
    printf '%s\n' "WARNING: shellcheck unavailable; skipping static shell analysis"
fi

printf '%s\n' "Checking on-device shell scripts for POSIX violations..."
# The device shell is busybox ash (OpenWrt-based firmware), so bash-only
# constructs crash at runtime. Scan the dirs that ship in the image (the
# host-side scripts/tests dirs are excluded - they run on the build host).
python3 - <<'PY' || fail "POSIX compliance check failed"
import re
from pathlib import Path

patterns = [
    (r'\[\[\s', "[[ ]] test"),
    (r'\$\{[A-Za-z_][A-Za-z0-9_]*/', "${var/...} substitution"),
    (r'\$\{[A-Za-z_][A-Za-z0-9_]*:[0-9]', "${var:offset}"),
    (r'(?:^|[;&|\s])let\s', "let builtin"),
    (r'&>', "&> redirect"),
    (r'<<<', "herestring"),
    (r'(?:^[ \t]*|[;&|][ \t]*)source[ \t]+["/$]', "source command"),
]
compiled = [(re.compile(p), name) for p, name in patterns]
bad = []
for d in ("System", "Apps", "Emus", "Roms", "tools", "trimui"):
    for path in sorted(Path(d).rglob("*.sh")):
        for i, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            for rx, name in compiled:
                if rx.search(line):
                    bad.append(f"{name}: {path}:{i}: {stripped[:100]}")
                    break
# bin/ ships in the image as extensionless jm-* tools; scan every plain file
# (they are all POSIX sh wrappers around lib/jm_common.sh).
for path in sorted(Path("bin").rglob("*")):
    if not path.is_file() or path.suffix:
        continue
    for i, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        for rx, name in compiled:
            if rx.search(line):
                bad.append(f"{name}: {path}:{i}: {stripped[:100]}")
                break
if bad:
    raise SystemExit("\n".join(bad))
print("POSIX compliance check passed")
PY

printf '%s\n' "Checking shell line endings and shebangs..."
# Single python pass (was a grep+sed fork per file). The CRLF check validates
# what is COMMITTED: on hosts where core.autocrlf rewrites the working tree
# (i/lf + w/crlf), the file is skipped so the check only fails on files that
# are actually stored with CRLF in the index. A shebang is only required for
# directly executable scripts; non-executable .sh files are frequently sourced
# snippets or data files in the menu system.
python3 - <<'PY' || fail "Shell format checks failed"
import os
import subprocess
from pathlib import Path

# A CRLF working-tree file is only an error when the COMMITTED blob is CRLF.
# On hosts where core.autocrlf rewrites the working tree (index LF, worktree
# CRLF) the file is fine to ship, so it is skipped. Reading the index blob
# directly (git ls-files -s + git cat-file --batch) avoids the very slow
# worktree stat scan of `git ls-files --eol`. Work in bytes so non-ASCII
# filenames match on any host.
index_blobs = {}
try:
    out = subprocess.check_output(["git", "ls-files", "-s", "-z"])
    for entry in out.split(b"\0"):
        if not entry:
            continue
        meta, name = entry.split(b"\t", 1)
        fields = meta.split()
        if len(fields) >= 2:
            index_blobs[name] = fields[1]
except (OSError, subprocess.CalledProcessError):
    index_blobs = None

bad = []
crlf_files = []
for pattern in ("*.sh", "*.bash"):
    for path in sorted(Path(".").rglob(pattern)):
        if ".git" in path.parts or "dist" in path.parts:
            continue
        data = path.read_bytes()
        if b"\r" in data:
            crlf_files.append(path)
            continue
        if path.stat().st_mode & 0o111 and not data.startswith(b"#!"):
            bad.append(f"Missing shebang: {path}")

if crlf_files and index_blobs is not None:
    proc = subprocess.Popen(
        ["git", "cat-file", "--batch"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
    )
    for path in crlf_files:
        sha = index_blobs.get(os.fsencode(path.as_posix()))
        if not sha:
            bad.append(f"CRLF line endings: {path}")
            continue
        assert proc.stdin and proc.stdout
        proc.stdin.write(sha + b"\n")
        proc.stdin.flush()
        header = proc.stdout.readline().split()
        if len(header) < 3 or header[1] != b"blob":
            bad.append(f"CRLF line endings: {path}")
            continue
        blob = proc.stdout.read(int(header[2]))
        proc.stdout.readline()  # trailing newline after the blob
        if b"\r" in blob:
            bad.append(f"CRLF line endings: {path}")
    proc.stdin.close()
    proc.wait()
elif crlf_files:
    # git unavailable: fall back to flagging every CRLF file
    bad.extend(f"CRLF line endings: {path}" for path in crlf_files)

if bad:
    raise SystemExit("\n".join(bad))
PY

printf '%s\n' "Checking for unsafe archive paths in tracked zip files..."
python3 - <<'PY' || fail "Unsafe zip archive path detected"
from pathlib import Path, PurePosixPath
import zipfile

for archive in Path(".").rglob("*.zip"):
    if ".git" in archive.parts or "dist" in archive.parts:
        continue
    with zipfile.ZipFile(archive) as zf:
        for name in zf.namelist():
            normalized = name.replace("\\", "/")
            path = PurePosixPath(normalized)
            if path.is_absolute() or ".." in path.parts:
                raise SystemExit(f"{archive}: unsafe member {name!r}")
print("Archive path check passed")
PY

printf '%s\n' "Checking accidental secret-like files..."
# Single tree walk (was four separate find/grep loops). A .pem is only a
# concern when it carries a PRIVATE KEY; public CA bundles (e.g. certifi's
# cacert.pem shipped with bundled Python libs) are harmless.
python3 - <<'PY' || fail "Possible secret file committed"
from pathlib import Path
hits = []
for path in Path(".").rglob("*"):
    if ".git" in path.parts or "dist" in path.parts or not path.is_file():
        continue
    name = path.name
    if name.endswith(".key") or name == "id_rsa" or name == ".env":
        hits.append(str(path))
        continue
    if name.endswith(".pem"):
        data = path.read_bytes()
        if b"-----BEGIN" in data and b"PRIVATE KEY" in data:
            hits.append(str(path))
if hits:
    raise SystemExit("\n".join(hits))
PY

if [ "$errors" -ne 0 ]; then
    printf '\nValidation failed with %s error(s).\n' "$errors" >&2
    exit 1
fi

printf '\n%s\n' "Validation completed successfully."
