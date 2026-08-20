#!/bin/sh
export PATH="/mnt/SDCARD/System/usr/trimui/scripts/:/mnt/SDCARD/System/bin:/mnt/SDCARD/bin:$PM_DIR:${PATH:+:$PATH}"
export LD_LIBRARY_PATH="/usr/trimui/lib:/mnt/SDCARD/System/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# =============================================================================
# Device Detection & TG5050 Optimization
# =============================================================================
# Auto-detect device type and apply performance optimizations accordingly
DEVICE_CODE="UNKNOWN"
if [ -r /etc/trimui_device.txt ]; then
    DEVICE_CODE=$(cat /etc/trimui_device.txt 2>/dev/null | tr -d '[:space:]' | head -n 1)
fi

# Source device detection if available
if [ -f "/mnt/SDCARD/System/usr/trimui/scripts/device_detection.sh" ]; then
    . "/mnt/SDCARD/System/usr/trimui/scripts/device_detection.sh"
fi

# Per-device default CPU ceiling (shared mapping, see cpufreq_default.sh):
# tg5050 (A523) id 8, tsp (A133) id 7, Brick/unknown id 6. Emulator launchers
# call `cpufreq.sh ondemand 2 "${JUKAMIX_CPUFREQ_MAX:-6}"` so the same line tunes
# every device to its own ceiling; the baseline below also covers apps that
# source this file without calling cpufreq themselves.
. /mnt/SDCARD/System/usr/trimui/scripts/cpufreq_default.sh
# Use the shared JUKAMIX_CPUFREQ_MAX rather than per-device hardcoded ids, so
# the Brick (which the previous case statement silently skipped) and any
# future device get the right baseline from one source of truth. cpufreq.sh
# clamps the id to the kernel's ceiling, so an A523-tuned line tunes
# gracefully on A133 hardware.
_jm_baseline_tuned=0
for _jm_cpufreq in \
    /mnt/SDCARD/System/usr/trimui/scripts/cpufreq.sh \
    /mnt/SDCARD/System/usr/trimui/scripts/tg5050_cpufreq.sh \
    /mnt/SDCARD/System/usr/trimui/scripts/tsp_cpufreq.sh; do
    if [ -f "$_jm_cpufreq" ]; then
        sh "$_jm_cpufreq" ondemand 2 "${JUKAMIX_CPUFREQ_MAX:-6}" 4 >/dev/null 2>&1
        _jm_baseline_tuned=1
        break
    fi
done
export JUKAMIX_DEVICE_OPTIMIZED="$DEVICE_CODE"
unset DEVICE_CODE _jm_cpufreq _jm_baseline_tuned

# ANSI colors
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
RESET="\033[0m"

# Pretty print section header
print_blue() {
    printf "${BLUE}%s${RESET}\n" "$1"
}

# Pretty print key=value
print_var() {
    printf "${GREEN}%-20s${RESET}: %s\n" "$1" "$2"
}

print_blue "$0 $*"
PM_DIR="/mnt/SDCARD/Apps/PortMaster/PortMaster"

# Input variables
ROM_REAL_PATH=$(realpath "$1")
EMU_DIR="$(echo "$0" | sed -E 's|(.*Emus/[^/]+)/.*|\1|')"
if [ "${1#"/tmp/folderspoof/"}" != "$1" ]; then
    ROM_DIR=$(dirname "$1")
else
    ROM_DIR=$(echo "$1" | sed -E 's|(.*Roms/[^/]+)/.*|\1|')
fi

ROM_FILENAME=$(basename "$1")
ROM_FILENAME_NOEXT=${ROM_FILENAME%.*}

printf "\n"
print_blue "=== ROM Information ==="
print_var "ROM_REAL_PATH" "$ROM_REAL_PATH"
print_var "ROM_DIR" "$ROM_DIR"
print_var "ROM_FILENAME" "$ROM_FILENAME"
print_var "ROM_FILENAME_NOEXT" "$ROM_FILENAME_NOEXT"
print_var "EMU_DIR" "$EMU_DIR"
print_blue "======================="

/mnt/SDCARD/System/usr/trimui/scripts/button_state.sh A
if [ $? -eq 10 ]; then
    if ! pgrep -f "activities gui"; then
        /mnt/SDCARD/System/bin/activities gui "$1"
        exit 0
    fi
fi

/mnt/SDCARD/System/usr/trimui/scripts/button_state.sh Y
if [ $? -eq 10 ]; then
    . /mnt/SDCARD/System/usr/trimui/scripts/romscripts/.romscript_launcher.sh
    exit
fi

dir=/mnt/SDCARD/System/usr/trimui/scripts
. $dir/save_launcher.sh

if [ -z "$2" ]; then
    /mnt/SDCARD/System/bin/activities time "$1" $$ &
fi

if grep -q ra64.trimui "$0"; then
    RA_DIR="/mnt/SDCARD/RetroArch"
    export PATH=$PATH:"$RA_DIR"
    . $dir/FolderOverrideFinder.sh
    ra_audio_switcher.sh
    touch /var/trimui_inputd/ra_hotkey
fi

# Per-game performance profiles (Profiles/<SYSTEM>/<GAME>.cfg) apply in the
# background after a short delay, so a game profile wins over the launcher's
# own default tuning (which runs right after this file is sourced). The
# applier clamps values to this device's CPU ladder, warns on mismatched
# device tags, and is a silent no-op when no profile exists — so games
# without a profile pay a single stat() check and nothing else.
if [ -n "$ROM_FILENAME_NOEXT" ] && [ -n "$ROM_DIR" ]; then
    _jm_sys=$(basename "$ROM_DIR")
    if [ -n "$_jm_sys" ] && [ -f "/mnt/SDCARD/Profiles/$_jm_sys/$ROM_FILENAME_NOEXT.cfg" ]; then
        (
            sleep 3
            exec /mnt/SDCARD/System/usr/trimui/scripts/apply_game_profile.sh \
                --game "$ROM_FILENAME_NOEXT" --system "$_jm_sys" --quiet
        ) >/dev/null 2>&1 &
    fi
    unset _jm_sys
fi

cd "$EMU_DIR"
