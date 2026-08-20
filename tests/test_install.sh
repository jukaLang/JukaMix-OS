#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

JUKAMIX_ROOT="$TMP" sh "$ROOT/install.sh"
[ -x "$TMP/System/usr/jukamix/bin/jm-doctor" ]
[ -x "$TMP/System/usr/jukamix/bin/jm-portmaster" ]
[ -f "$TMP/System/var/jukamix/install-manifest-v5.txt" ]
[ -f "$TMP/Roms/PORTS/PortMaster.sh" ]  # install prepares the PortMaster entry point
[ -d "$TMP/Data/ports" ]
JUKAMIX_ROOT="$TMP" sh "$ROOT/uninstall.sh"
[ ! -f "$TMP/System/usr/jukamix/bin/jm-doctor" ]
[ -f "$TMP/System/etc/jukamix/jukamix.conf" ]
echo "test_install: PASS"
