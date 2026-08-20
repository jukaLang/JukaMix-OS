#!/bin/sh
# JukaMix OS - Cross-Device Emulator Optimizer
# Updates emulator launch scripts with device-appropriate CPU frequency settings
# Uses base profiles from Profiles/DEVICE-OVERRIDES/<device>_base.cfg
#
# Usage: emulator_optimizer.sh [--check|--apply|--revert|--status|--help]

set -u

SCRIPT_DIR="${0%/*}"
[ "$SCRIPT_DIR" = "$0" ] && SCRIPT_DIR="/mnt/SDCARD/System/usr/trimui/scripts"
EMUS_DIR="/mnt/SDCARD/Emus"
PROFILES_DIR="/mnt/SDCARD/Profiles"
BACKUP_DIR="/mnt/SDCARD/System/backups/emulator_configs"
LOG_FILE="/mnt/SDCARD/System/logs/jukamix/emulator_optimizer.log"

# Detect device
DEVICE_CODE="UNKNOWN"
if [ -r /etc/trimui_device.txt ]; then
    DEVICE_CODE=$(cat /etc/trimui_device.txt 2>/dev/null | tr -d '[:space:]' | head -n 1)
fi

# Load base profile for device
BASE_PROFILE="$PROFILES_DIR/DEVICE-OVERRIDES/${DEVICE_CODE}_base.cfg"
BASE_GOVERNOR="ondemand"
BASE_CORES="4"

if [ -f "$BASE_PROFILE" ]; then
    BASE_GOVERNOR=$(grep "^cpu_governor[[:space:]]*=" "$BASE_PROFILE" 2>/dev/null | head -n 1 | cut -d'=' -f2 | tr -d '[:space:]')
    BASE_CORES=$(grep "^active_cores[[:space:]]*=" "$BASE_PROFILE" 2>/dev/null | head -n 1 | cut -d'=' -f2 | tr -d '[:space:]')
fi
BASE_CORES="${BASE_CORES:-4}"

# get_optimal_freq below is device-aware: on tg5050 it uses the extra 9/10
# ladder steps exposed by cpufreq.sh (2200000/2400000 kHz); every other device
# keeps the historical 0-8 range.
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
mkdir -p "$BACKUP_DIR" 2>/dev/null

log_msg() {
    printf '[%s] [%s] %s\n' "$(date +%Y-%m-%dT%H:%M:%S)" "$1" "$2" >> "$LOG_FILE" 2>/dev/null
}

get_emu_system_name() {
    echo "$1" | sed -E 's|.*/Emus/([^/]+)/.*|\1|' | tr '[:lower:]' '[:upper:]'
}

has_cpufreq_line() {
    grep -q "cpufreq\.sh " "$1" 2>/dev/null
}

get_current_cpufreq_params() {
    grep "cpufreq\.sh " "$1" 2>/dev/null | head -n 1 | sed -E 's|.*cpufreq\.sh[[:space:]]+||'
}

get_optimal_freq() {
    case "$1" in
        SATURN|DC|NAOMI|ATOMISWAVE|PSP|PS)
            if [ "$DEVICE_CODE" = "tg5050" ]; then echo "performance 5 9 $BASE_CORES"; else echo "performance 5 8 $BASE_CORES"; fi
            ;;
        N64|N64DD|GBC|GBA|NGP|NGC|DS)
            if [ "$DEVICE_CODE" = "tg5050" ]; then echo "ondemand 4 9 $BASE_CORES"; else echo "ondemand 4 7 $BASE_CORES"; fi
            ;;
        SFC|MD|MS|SEGACD|SEGA32X|NEOGEO|NEOCD|PCE|PCECD|SG1000|FBNEO|MAME*)
            if [ "$DEVICE_CODE" = "tg5050" ]; then echo "ondemand 3 8 $BASE_CORES"; else echo "ondemand 3 7 $BASE_CORES"; fi
            ;;
        *)
            if [ "$DEVICE_CODE" = "tg5050" ]; then echo "ondemand 2 8 $BASE_CORES"; else echo "ondemand 2 6 $BASE_CORES"; fi
            ;;
    esac
}

update_cpufreq_line() {
    _script="$1"
    _params="$2"
    
    # Create backup
    _bk_dir="${BACKUP_DIR}/$(dirname "$_script")"
    mkdir -p "$_bk_dir" 2>/dev/null
    cp "$_script" "${BACKUP_DIR}/${_script}.$(date +%Y%m%d-%H%M%S).bak" 2>/dev/null
    
    # Update cpufreq line
    sed -i "s/cpufreq\.sh .*/cpufreq.sh $_params/" "$_script"
}

do_check() {
    echo "=== Emulator Optimization Check (Device: $DEVICE_CODE) ==="
    echo "Base profile: $BASE_PROFILE"
    echo "  Governor: $BASE_GOVERNOR | Cores: $BASE_CORES"
    echo ""
    
    _count=0
    _needs=0
    _ok=0
    
    for _emu_dir in "$EMUS_DIR"/*/; do
        [ -d "$_emu_dir" ] || continue
        _system=$(get_emu_system_name "$_emu_dir")
        
        for _script in "$_emu_dir"*.sh; do
            [ -f "$_script" ] || continue
            if has_cpufreq_line "$_script"; then
                _cur=$(get_current_cpufreq_params "$_script")
                _opt=$(get_optimal_freq "$_system")
                if [ "$_cur" != "$_opt" ]; then
                    echo "NEEDS: $_script"
                    echo "  Current: cpufreq.sh $_cur"
                    echo "  Target:  cpufreq.sh $_opt"
                    _needs=$((_needs + 1))
                else
                    _ok=$((_ok + 1))
                fi
                _count=$((_count + 1))
            fi
        done
    done
    
    echo ""
    echo "Total: $_count | Needs update: $_needs | OK: $_ok"
}

do_apply() {
    echo "=== Applying Optimizations (Device: $DEVICE_CODE) ==="
    
    _backup="${BACKUP_DIR}/emus_$(date +%Y%m%d_%H%M%S)"
    cp -a "$EMUS_DIR" "$_backup" 2>/dev/null
    echo "Backup: $_backup"
    
    _applied=0
    _errors=0
    
    for _emu_dir in "$EMUS_DIR"/*/; do
        [ -d "$_emu_dir" ] || continue
        _system=$(get_emu_system_name "$_emu_dir")
        _opt=$(get_optimal_freq "$_system")
        
        for _script in "$_emu_dir"*.sh; do
            [ -f "$_script" ] || continue
            if has_cpufreq_line "$_script"; then
                update_cpufreq_line "$_script" "$_opt" && _applied=$((_applied + 1)) || _errors=$((_errors + 1))
            fi
        done
    done
    
    echo "Applied: $_applied | Errors: $_errors"
}

do_revert() {
    _latest=$(ls -1t "$BACKUP_DIR"/emus_* 2>/dev/null | head -n 1)
    [ -z "$_latest" ] && echo "No backup found." && return 1
    
    echo "Restoring from: $_latest"
    rm -rf "$EMUS_DIR"/*
    cp -a "$_latest/." "$EMUS_DIR/" 2>/dev/null
    echo "Done."
}

do_status() {
    echo "=== Emulator Optimizer Status ==="
    echo "Device: $DEVICE_CODE"
    echo "Base profile: $BASE_PROFILE"
    [ -f "$BASE_PROFILE" ] && echo "  Status: found" || echo "  Status: using defaults"
    echo ""
    
    _latest=$(ls -1t "$BACKUP_DIR"/emus_* 2>/dev/null | head -n 1)
    [ -n "$_latest" ] && echo "Latest backup: $_latest" || echo "No backups yet"
}

case "${1:-status}" in
    --check) do_check ;;
    --apply) do_apply ;;
    --revert) do_revert ;;
    --status) do_status ;;
    --help|-h)
        echo "Usage: $0 [--check|--apply|--revert|--status|--help]"
        echo ""
        echo "Options:"
        echo "  --check   Show what needs optimization"
        echo "  --apply   Apply device-appropriate settings (creates backup)"
        echo "  --revert  Restore last backup"
        echo "  --status  Show current status"
        echo "  --help    Show this help"
        ;;
    *) echo "Unknown: $1"; exit 1 ;;
esac

exit 0
