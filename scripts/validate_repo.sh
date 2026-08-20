#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"

failed=0

printf '%s\n' "Checking shell syntax..."
find scripts -type f -name '*.sh' -print | while IFS= read -r file; do
    sh -n "$file"
done

printf '%s\n' "Checking Python syntax..."
find scripts -type f -name '*.py' -print | while IFS= read -r file; do
    python3 -m py_compile "$file"
done

printf '%s\n' "Checking JSON..."
find config schemas .github -type f -name '*.json' -print 2>/dev/null | while IFS= read -r file; do
    python3 -m json.tool "$file" >/dev/null
done

printf '%s\n' "Checking merge markers..."
# Only the unambiguous conflict markers are checked: '=======' is a common
# decorative line in README/LICENSE files, so matching it creates false alarms.
if grep -R -n -I -E '^(<<<<<<<|>>>>>>>)' \
    --exclude-dir=.git --exclude='*.zip' .; then
    printf '%s\n' "Merge markers found."
    failed=1
fi

printf '%s\n' "Checking accidental secrets..."
# -I skips binary files (ELF/so/wad/rom blobs in the image would otherwise
# produce false positives).
if grep -R -n -I -E \
    '(gsk_[A-Za-z0-9_-]{20,}|AIza[A-Za-z0-9_-]{20,}|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY)' \
    --exclude-dir=.git --exclude='validate_repo.sh' .; then
    printf '%s\n' "Potential secret found."
    failed=1
fi

printf '%s\n' "Checking executable scripts..."
find scripts -type f \( -name '*.sh' -o -name '*.py' \) ! -perm -u+x -print | while IFS= read -r file; do
    printf 'warning: not executable: %s\n' "$file"
done

[ "$failed" -eq 0 ] || exit 1
printf '%s\n' "Repository validation passed."
