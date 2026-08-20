#!/bin/sh
# scripts/fetch_firmware.sh - Fetch TrimUI firmware blobs on demand.
#
# The on-device Firmware Update Wizard needs the firmware archive parts under
# trimui/firmwares/, but they are multi-tens-of-MB binaries that must not live
# in git history. This script materialises them before a release is built:
#
#   - Files already present locally are kept (no re-download).
#   - Files listed in trimui/firmwares/firmware_sources.txt with a URL are
#     downloaded with curl when missing.
#   - Files with no URL configured are reported, and the run fails.
#
# Usage:
#   scripts/fetch_firmware.sh [os-root]          # default: repo root
#   JUKAMIX_SKIP_FIRMWARE=1 scripts/fetch_firmware.sh   # dev builds, skip
#
# Exit codes: 0 all required blobs present, 1 missing/unfetchable, 2 usage.

set -u

[ -n "${JUKAMIX_SKIP_FIRMWARE:-}" ] && { echo "fetch_firmware: skipped (JUKAMIX_SKIP_FIRMWARE=1)"; exit 0; }

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
# An optional os-root argument overrides the default; only error when an
# argument was given but is not a directory (no-arg runs use the repo root).
if [ -n "${1:-}" ]; then
    if [ -d "$1" ]; then
        root=$(CDPATH= cd -- "$1" && pwd)
    else
        echo "fetch_firmware: not a directory: $1" >&2
        exit 2
    fi
fi

fw_dir="$root/trimui/firmwares"
sources="$fw_dir/firmware_sources.txt"

if [ ! -f "$sources" ]; then
    echo "fetch_firmware: $sources not found" >&2
    exit 2
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "fetch_firmware: curl not found" >&2
    exit 1
fi

missing=0
while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
        ''|\#*) continue ;;
    esac
    name=${line%%$'\t'*}
    url=${line#*$'\t'}
    dest="$fw_dir/$name"
    if [ -s "$dest" ]; then
        echo "fetch_firmware: present  $name"
        continue
    fi
    if [ -z "$url" ] || [ "$url" = "$name" ]; then
        echo "fetch_firmware: MISSING  $name (no download URL configured in trimui/firmwares/firmware_sources.txt)" >&2
        missing=1
        continue
    fi
    echo "fetch_firmware: fetching $name"
    if ! curl -fL --retry 3 -o "$dest.tmp" "$url"; then
        echo "fetch_firmware: failed to download $url" >&2
        rm -f "$dest.tmp"
        missing=1
        continue
    fi
    mv "$dest.tmp" "$dest"
done < "$sources"

if [ "$missing" -eq 1 ]; then
    echo "fetch_firmware: one or more firmware blobs are missing. Download them manually into $fw_dir or set a URL in $sources." >&2
    exit 1
fi

echo "fetch_firmware: all firmware blobs present"
