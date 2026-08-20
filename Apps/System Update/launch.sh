#!/bin/sh
# System Update - safe, transactional OTA updater (JukaHub/Patch-aligned).
#
# Stages the update, verifies signed manifest + SHA-256 checksums, backs up
# modified files, applies them journaled, and automatically rolls back on
# failure. Reuses update_common.sh globals/helpers and tools/lib/jukamix-ota.sh.

export PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:$PATH"
export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"

. "/mnt/SDCARD/System/usr/trimui/scripts/update_common.sh" 2>/dev/null
JUKAMIX_LIB_DIR="/mnt/SDCARD/System/jukamix/lib"
[ -d "$JUKAMIX_LIB_DIR" ] || JUKAMIX_LIB_DIR="/mnt/SDCARD/tools/lib"
. "$JUKAMIX_LIB_DIR/jukamix-update.sh" 2>/dev/null
. "$JUKAMIX_LIB_DIR/jukamix-ota.sh" 2>/dev/null

jukamix_ota_run
