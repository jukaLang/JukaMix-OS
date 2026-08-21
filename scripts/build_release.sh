#!/bin/sh
set -eu

# Release builds are named after the build date+hour, e.g. JukaMix_0820202614
# (August 20, 2026, 14:00). Pass an explicit stamp to override (the CI
# workflow_dispatch version input does); an optional leading "v" is stripped.
version="${1:-$(date +%m%d%Y%H)}"
case "$version" in
    v[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]) version=${version#v} ;;
    [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]) ;;
    *) printf 'Invalid build stamp: %s (expected MMDDYYYYHH, e.g. 0820202614)\n' "$version" >&2; exit 2 ;;
esac

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
dist="$root/dist"
stage="$dist/JukaMix_${version}"
archive="$dist/JukaMix_${version}.zip"

# The firmware blobs are not tracked in git; materialise them (from local
# disk or a configured URL) before staging so the image can ship them.
sh "$root/scripts/fetch_firmware.sh" "$root"

# The RetroArch cores archive (~335MB) is too large to track in git;
# download from releases if not already present locally.
sh "$root/scripts/fetch_cores.sh" "$root"

rm -rf "$stage"
mkdir -p "$stage"

(
    cd "$root"
    find . -type f \
        ! -path './.git/*' \
        ! -path './dist/*' \
        ! -name '*.zip' \
        ! -name '*.log' \
        ! -name 'jukauser.json' \
        ! -name 'MANIFEST.json' \
        ! -name '.VolumeIcon.icns' \
        ! -name 'autorun.inf' \
        ! -name '.gitignore' \
        ! -name '.gitattributes' \
        ! -path './scripts/*' \
        ! -path './tests/*' \
        ! -path './schemas/*' \
        ! -path './packages/*' \
        -print
) | while IFS= read -r file; do
    relative=${file#./}
    mkdir -p "$stage/$(dirname "$relative")"
    cp -p "$root/$relative" "$stage/$relative"
done

# Stamp the release build stamp into the OS version file so on-device version
# detection matches the archive being built.
printf '%s\n' "$version" > "$stage/System/usr/trimui/jukamix-version.txt"

# Stamp the JukaHub patch index with the same version and matching release
# URLs. The tracked copy is a template; the shipped image must reference the
# release that actually contains it, otherwise JukaHub's Patch view 404s.
# (Shared with the CI workflow via scripts/stamp_jukahub.py.)
python3 "$root/scripts/stamp_jukahub.py" "$stage/Apps/JukaHub/patch/packages.json" "$version"

# Create the RetroArch default-config archive used by the on-device
# "Reset Retroarch Configuration" tool (System/bin/7zz extracts it). CI does
# the same; the archive is generated from tracked files, never committed.
# Use whatever 7z-capable tool the host has (libarchive, 7-Zip, p7zip).
if command -v bsdtar >/dev/null 2>&1; then
    ( cd "$stage" && bsdtar -acf RetroArch/default_config.7z RetroArch/retroarch.cfg RetroArch/.retroarch/config/* )
elif command -v 7zz >/dev/null 2>&1; then
    ( cd "$stage" && 7zz a RetroArch/default_config.7z RetroArch/retroarch.cfg RetroArch/.retroarch/config/* )
elif command -v 7zr >/dev/null 2>&1; then
    ( cd "$stage" && 7zr a RetroArch/default_config.7z RetroArch/retroarch.cfg RetroArch/.retroarch/config/* )
else
    echo "build_release: no 7z-capable tool (bsdtar/7zz/7zr) to create RetroArch/default_config.7z" >&2
    exit 1
fi

# Extract all RetroArch cores from the single compressed archive
# (RetroArch/.retroarch/cores/cores.7z — ~335MB in git, ~1.8GB extracted).
# CI does the same; the archive is deleted after extraction so it doesn't ship.
if [ -f "$stage/RetroArch/.retroarch/cores/cores.7z" ]; then
    if command -v bsdtar >/dev/null 2>&1; then
        ( cd "$stage/RetroArch/.retroarch/cores" && bsdtar -xf cores.7z && rm cores.7z )
    elif command -v 7zz >/dev/null 2>&1; then
        ( cd "$stage/RetroArch/.retroarch/cores" && 7zz x cores.7z && rm cores.7z )
    elif command -v 7zr >/dev/null 2>&1; then
        ( cd "$stage/RetroArch/.retroarch/cores" && 7zr x cores.7z && rm cores.7z )
    else
        echo "build_release: no 7z tool to extract RetroArch cores" >&2
        exit 1
    fi
fi

# Git clones made on Windows do not record the executable bit; restore it for
# every shebang script and ELF binary so the archive boots correctly.
# Note: the inner sh must exit 0 — GNU find propagates a non-zero -exec
# status, which would abort the build under set -e (the last [ ] test fails
# for any non-shebang file).
find "$stage" -type f -exec sh -c '
    for f do
        [ "$(head -c 2 "$f" 2>/dev/null)" = "#!" ] && { chmod +x "$f"; continue; }
        [ "$(head -c 4 "$f" 2>/dev/null)" = "$(printf "\177ELF")" ] && chmod +x "$f"
    done
    exit 0
' sh {} +

rm -f "$archive"
(
    cd "$dist"
    python3 -c 'import shutil; shutil.make_archive("JukaMix_'"$version"'", "zip", "JukaMix_'"$version"'")'
)

cd "$dist"
python3 "$root/scripts/safe_extract.py" "$archive" "$dist/.inspection" --inspect-only
python3 "$root/scripts/generate_manifest.py" "$version" "$(basename "$archive")" -o manifest.json
python3 "$root/scripts/verify_manifest.py" manifest.json --directory "$dist"

# Publish the transactional OTA manifest alongside the archive. The on-device
# updater looks for manifest.txt (and an optional manifest.txt.sig) next to the
# release asset; when present it applies the update incrementally instead of
# doing a full image replace.
sh "$root/tools/make-ota-manifest.sh" "$stage" "$dist/manifest.txt" "/mnt/SDCARD"

# Build the opkg package feed for the release. CI uploads dist/feed to the
# release; the on-device opkg.conf points at releases/latest/download.
mkdir -p "$dist/feed"
for pkg in "$root"/packages/*/; do
    [ -f "$pkg/control" ] || continue
    sh "$root/tools/jukamix-mkpackage.sh" "$pkg" "$dist/feed"
done
sh "$root/tools/jukamix-mkfeed.sh" "$dist/feed"

# Gate the release on device coverage: the combined archive must ship
# everything every supported device needs (tsp, tg5050, brick), and the OTA
# manifest must deliver it.
sh "$root/scripts/validate_devices.sh" "$stage" \
    --devices "tsp tg5050 brick" \
    --version "$version" \
    --manifest "$dist/manifest.txt"

printf 'Built %s\n' "$archive"
