#!/bin/sh
# JukaMix OS - Game Profile Applier
# Applies community-maintained per-game optimization profiles

set -u

SCRIPT_DIR="${0%/*}"
[ "$SCRIPT_DIR" = "$0" ] && SCRIPT_DIR="/mnt/SDCARD/System/usr/trimui/scripts"
# Env override (JUKAMIX_PROFILES_DIR) keeps the applier host-testable; the
# device always uses the on-card path.
PROFILES_DIR="${JUKAMIX_PROFILES_DIR:-/mnt/SDCARD/Profiles}"

# Source common library if available
if [ -f "$SCRIPT_DIR/jukamix-common.sh" ]; then
    . "$SCRIPT_DIR/jukamix-common.sh"
fi
# Source the shared CPU frequency ladder so this script uses the same
# id<->Hz mapping as cpufreq.sh, tsp_cpufreq.sh, tg5050_cpufreq.sh. The
# ladder owns the device-specific MAX_FREQ_ID lookup (sysfs + device
# code fallback) in one place; the local freq_to_id() and per-device
# case statement below used to duplicate it.
. "$SCRIPT_DIR/cpufreq_ladder.sh" 2>/dev/null || \
    . /mnt/SDCARD/System/usr/trimui/scripts/cpufreq_ladder.sh

GAME=""
SYSTEM=""
DRY_RUN=0
LIST_MODE=0
RESET_MODE=0
QUIET=0
STRICT=0

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --game <name>       Game name (e.g., "Sonic Adventure")
  --system <code>     System code (e.g., DC, N64, PSP, PS1)
  --dry-run           Show what would be applied without applying
  --list              List all available profiles
  --reset             Reset game to base profile defaults
  --quiet             Suppress output; exit 0 when no profile exists (launch-time use)
  --strict            Refuse profiles verified for a different device
  -h, --help          Show this help

Examples:
  $0 --list
  $0 --game "Sonic Adventure" --system DC
  $0 --game "Sonic Adventure" --system DC --dry-run
  $0 --game "Sonic Adventure" --system DC --reset
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --game) GAME="$2"; shift 2 ;;
        --system) SYSTEM="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        --list) LIST_MODE=1; shift ;;
        --reset) RESET_MODE=1; shift ;;
        --quiet) QUIET=1; shift ;;
        --strict) STRICT=1; shift ;;
        *) echo "Unknown option: $1"; usage; exit 2 ;;
    esac
done

# List mode
if [ "$LIST_MODE" = "1" ]; then
    echo "=== Available Game Profiles ==="
    echo ""
    find "$PROFILES_DIR" -name "*.cfg" -type f | grep -v "TEMPLATE\|_base" | while read -r profile; do
        _game=$(basename "$profile" .cfg)
        _system=$(basename "$(dirname "$profile")")
        _dev=$(grep -iE '^[[:space:]]*#[[:space:]]*Device:' "$profile" 2>/dev/null | head -n 1 | sed -E 's/^[^:]*:[[:space:]]*//' | tr -d '[:space:]')
        echo "  $_system/$_game (device: ${_dev:-any})"
    done
    echo ""
    echo "Base profiles:"
    find "$PROFILES_DIR/DEVICE-OVERRIDES" -name "*_base.cfg" -type f 2>/dev/null | while read -r profile; do
        _device=$(basename "$profile" _base.cfg)
        echo "  DEVICE-OVERRIDES/$_device"
    done
    exit 0
fi

# Validate required arguments
if [ -z "$GAME" ] || [ -z "$SYSTEM" ]; then
    echo "Error: --game and --system are required"
    usage
    exit 2
fi

# Detect current device
DEVICE_CODE="UNKNOWN"
if [ -r /etc/trimui_device.txt ]; then
    DEVICE_CODE=$(cat /etc/trimui_device.txt 2>/dev/null | tr -d '[:space:]' | head -n 1)
fi

# Unified cpufreq.sh handles every device and clamps to the running kernel's
# ceiling, so the same script and MAX_FREQ_ID lookup work on tsp / tg5050 /
# brick / unknown. MAX_FREQ_ID is sourced from cpufreq_ladder.sh (sysfs
# cpuinfo_max_freq first, device code as the fallback for off-device runs).
CPUFREQ_SCRIPT="cpufreq.sh"
MAX_FREQ_ID=$(cpufreq_max_id)

[ "$QUIET" = "1" ] || {
    echo "=== JukaMix OS Game Profile Applier ==="
    echo "Device: $DEVICE_CODE"
    echo "Game: $GAME"
    echo "System: $SYSTEM"
    echo ""
}

# Find profile file
PROFILE_FILE="$PROFILES_DIR/$SYSTEM/${GAME}.cfg"
BASE_PROFILE="$PROFILES_DIR/DEVICE-OVERRIDES/${DEVICE_CODE}_base.cfg"

# A profile may declare the device it was verified on ("# Device: tg5050").
# Enforce it: a mismatched profile still applies, clamped to this device's
# ladder, but warns loudly; --strict refuses it outright. Profiles without a
# Device tag (or tagged "all"/"any") apply on every device.
_profile_dev=$(grep -iE '^[[:space:]]*#[[:space:]]*Device:' "$PROFILE_FILE" 2>/dev/null | head -n 1 | sed -E 's/^[^:]*:[[:space:]]*//' | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
if [ -n "$_profile_dev" ] && [ "$_profile_dev" != "all" ] && [ "$_profile_dev" != "any" ] && [ "$_profile_dev" != "$DEVICE_CODE" ]; then
    if [ "$STRICT" = "1" ]; then
        [ "$QUIET" = "1" ] || echo "Error: profile verified for '$_profile_dev', refusing on '$DEVICE_CODE' (--strict)."
        exit 1
    fi
    [ "$QUIET" = "1" ] || echo "Warning: profile verified for '$_profile_dev', running on '$DEVICE_CODE' — values will clamp to this device's limits."
fi
unset _profile_dev

if [ ! -f "$PROFILE_FILE" ] && [ "$RESET_MODE" != "1" ]; then
    [ "$QUIET" = "1" ] && exit 0
    echo "No profile found for '$GAME' on $SYSTEM"
    echo "Available profiles for $SYSTEM:"
    ls -1 "$PROFILES_DIR/$SYSTEM/"*.cfg 2>/dev/null | sed 's|.*/||' | sed 's|\.cfg$||' || echo "  (none)"
    exit 1
fi

# Load base profile
if [ -f "$BASE_PROFILE" ]; then
    [ "$QUIET" = "1" ] || echo "Loading base profile: $BASE_PROFILE"
    # Parse base profile values (simple key=value extraction). Base profiles
    # use "key = value" spacing, so trim whitespace from both sides before
    # matching (the case patterns are whitespace-free).
    while IFS='=' read -r key value; do
        key=$(printf '%s' "$key" | tr -d '[:space:]')
        value=$(printf '%s' "$value" | tr -d '[:space:]' | tr -d '"')
        case "$key" in
            cpu_governor)          BASE_cpu_governor="$value" ;;
            cpu_min_freq)          BASE_cpu_min_freq="$value" ;;
            cpu_max_freq)          BASE_cpu_max_freq="$value" ;;
            active_cores)          BASE_active_cores="$value" ;;
            internal_resolution)   BASE_internal_resolution="$value" ;;
            texture_upscaling)     BASE_texture_upscaling="$value" ;;
            anisotropic_filtering) BASE_anisotropic_filtering="$value" ;;
            threaded_rendering)    BASE_threaded_rendering="$value" ;;
        esac
    done < "$BASE_PROFILE"
else
    [ "$QUIET" = "1" ] || echo "Warning: No base profile found for $DEVICE_CODE, using defaults"
fi

# Ensure every value has a safe default even when a base profile exists but is
# missing some keys (set -u is active, so never leave these unset).
BASE_cpu_governor="${BASE_cpu_governor:-ondemand}"
BASE_cpu_min_freq="${BASE_cpu_min_freq:-816000}"
BASE_cpu_max_freq="${BASE_cpu_max_freq:-2000000}"
BASE_active_cores="${BASE_active_cores:-4}"
BASE_internal_resolution="${BASE_internal_resolution:-1x}"
BASE_texture_upscaling="${BASE_texture_upscaling:-disabled}"
BASE_anisotropic_filtering="${BASE_anisotropic_filtering:-0}"
BASE_threaded_rendering="${BASE_threaded_rendering:-false}"

# Local freq_to_id() removed: cpufreq_ladder.sh (sourced above) provides
# cpufreq_hz_to_id which returns the same id for the same kHz. Keeping a
# third copy of the ladder in sync was the original drift hazard.

# Reset mode - just use base profile (device [recommended_defaults])
if [ "$RESET_MODE" = "1" ]; then
    echo "Resetting to base profile defaults..."
    echo "  CPU Governor: $BASE_cpu_governor"
    echo "  CPU Frequency: $BASE_cpu_min_freq - $BASE_cpu_max_freq kHz"
    echo "  Active Cores: $BASE_active_cores"
    echo "  Internal Resolution: $BASE_internal_resolution"
    
    if [ "$DRY_RUN" != "1" ]; then
        # Apply base settings, converting the profile's kHz values to the
        # device frequency IDs (fall back to safe defaults if out of ladder).
        _MIN_ID=$(cpufreq_hz_to_id "$BASE_cpu_min_freq")
        _MAX_ID=$(cpufreq_hz_to_id "$BASE_cpu_max_freq")
        [ -z "$_MIN_ID" ] && _MIN_ID=2
        [ -z "$_MAX_ID" ] && _MAX_ID=$MAX_FREQ_ID
        # Never exceed the device's ladder, and keep min <= max.
        _MIN_ID=$(cpufreq_clamp "$_MIN_ID")
        _MAX_ID=$(cpufreq_clamp "$_MAX_ID")
        [ "$_MIN_ID" -gt "$_MAX_ID" ] && _MIN_ID=$_MAX_ID
        sh "$SCRIPT_DIR/$CPUFREQ_SCRIPT" "$BASE_cpu_governor" "$_MIN_ID" "$_MAX_ID" "$BASE_active_cores" >/dev/null 2>&1
        echo "Applied base profile settings (ids $_MIN_ID-$_MAX_ID, $BASE_active_cores cores)."
    fi
    exit 0
fi

# Load game-specific profile
[ "$QUIET" = "1" ] || echo "Loading game profile: $PROFILE_FILE"
[ "$QUIET" = "1" ] || echo ""

# Parse profile sections
CPU_GOVERNOR="$BASE_cpu_governor"
CPU_MIN_FREQ="$BASE_cpu_min_freq"
CPU_MAX_FREQ="$BASE_cpu_max_freq"
ACTIVE_CORES="$BASE_active_cores"
INTERNAL_RES="$BASE_internal_resolution"
TEXTURE_UPSCALE="$BASE_texture_upscaling"
ANISO_FILTER="$BASE_anisotropic_filtering"
THREADED_RENDER="$BASE_threaded_rendering"

while IFS= read -r line; do
    # Skip comments and empty lines
    case "$line" in
        \#*|"") continue ;;
    esac
    
    # Parse key = value
    key=$(echo "$line" | cut -d'=' -f1 | tr -d '[:space:]')
    value=$(echo "$line" | cut -d'=' -f2- | tr -d '[:space:]' | tr -d '"')
    
    case "$key" in
        cpu_governor) CPU_GOVERNOR="$value" ;;
        cpu_min_freq) CPU_MIN_FREQ="$value" ;;
        cpu_max_freq) CPU_MAX_FREQ="$value" ;;
        active_cores) ACTIVE_CORES="$value" ;;
        internal_resolution) INTERNAL_RES="$value" ;;
        texture_upscaling) TEXTURE_UPSCALE="$value" ;;
        anisotropic_filtering) ANISO_FILTER="$value" ;;
        threaded_rendering) THREADED_RENDER="$value" ;;
    esac
done < "$PROFILE_FILE"

# Display what will be applied
[ "$QUIET" = "1" ] || {
    echo "Settings to apply:"
    echo "  CPU Governor: $CPU_GOVERNOR"
    echo "  CPU Frequency: $CPU_MIN_FREQ - $CPU_MAX_FREQ kHz"
    echo "  Active Cores: $ACTIVE_CORES"
    echo "  Internal Resolution: $INTERNAL_RES (advisory — not auto-applied)"
    echo "  Texture Upscaling: $TEXTURE_UPSCALE (advisory)"
    echo "  Anisotropic Filtering: $ANISO_FILTER (advisory)"
    echo "  Threaded Rendering: $THREADED_RENDER (advisory)"
    echo ""
}

# Extract notes from profile
NOTES=$(grep -A100 '^\[notes\]' "$PROFILE_FILE" 2>/dev/null | grep '^"' | tr -d '"' | head -n 3)
if [ -n "$NOTES" ]; then
    echo "Profile notes:"
    echo "$NOTES" | sed 's/^/  /'
    echo ""
fi

# Apply settings
if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY RUN] Settings not applied."
    exit 0
fi

[ "$QUIET" = "1" ] || echo "Applying profile..."

# Map the profile's kHz range to device frequency IDs. Fall back to the
# internal-resolution heuristic only when a profile leaves the max unset.
_MIN_ID=$(cpufreq_hz_to_id "$CPU_MIN_FREQ")
_MAX_ID=$(cpufreq_hz_to_id "$CPU_MAX_FREQ")
[ -z "$_MIN_ID" ] && _MIN_ID=2
if [ -z "$_MAX_ID" ]; then
    case "$INTERNAL_RES" in
        1x) _MAX_ID=6 ;;   # 1608000
        2x) _MAX_ID=8 ;;   # 2000000
        3x) _MAX_ID=9 ;;   # 2200000
        4x) _MAX_ID=10 ;;  # 2400000
        *) _MAX_ID=8 ;;
    esac
fi

# Clamp to the device ladder and keep the range sane.
_MIN_ID=$(cpufreq_clamp "$_MIN_ID")
_MAX_ID=$(cpufreq_clamp "$_MAX_ID")
[ "$_MIN_ID" -gt "$_MAX_ID" ] && _MIN_ID=$_MAX_ID

# Apply CPU settings
sh "$SCRIPT_DIR/$CPUFREQ_SCRIPT" "$CPU_GOVERNOR" "$_MIN_ID" "$_MAX_ID" "$ACTIVE_CORES" >/dev/null 2>&1

[ "$QUIET" = "1" ] || {
    echo "Profile applied successfully!"
    echo ""
    echo "CPU settings are active for this session; the next launch restores the device defaults."
}

exit 0
