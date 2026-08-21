#!/bin/sh
# Emus/JAVA/launch.sh - FreeJ2ME Java ME emulator launcher
# Supports: TrimUI Smart Pro, Smart Pro S, Brick, Brick Pro
#
# Features:
#   - Per-game resolution config with auto-save
#   - Device-aware CPU frequency
#   - Proper controller mapping via common_launcher.sh
#   - SDL display backend
#   - MIDI sound support via timidity

. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh

# ── Paths ──────────────────────────────────────────────────────────────
JAVA_BASE="/mnt/SDCARD/Emus/JAVA"
JAVA_HOME="$JAVA_BASE/zulu17"
FREEJ2ME_JAR="$JAVA_HOME/bin/freej2me-sdl.jar"
CONFIG_DIR="$JAVA_HOME/bin/config"
RMS_DIR="$JAVA_HOME/bin/rms"
TIMIDITY_CFG="$JAVA_BASE/timidity/timidity.cfg"
THD_CONF="$JAVA_BASE/thd.conf"

# ── Detect device ──────────────────────────────────────────────────────
detect_device() {
    if [ -f /sys/firmware/devicetree/base/model ]; then
        local model
        model=$(tr -d '\0' < /sys/firmware/devicetree/base/model 2>/dev/null)
        case "$model" in
            *SmartPro*|*smartpro*) echo "tsp" ;;
            *TG5050*|*tg5050*)     echo "tg5050" ;;
            *Brick*)               echo "brick" ;;
            *)                     echo "unknown" ;;
        esac
    else
        echo "unknown"
    fi
}

DEVICE=$(detect_device)

# ── CPU frequency by device ───────────────────────────────────────────
set_cpu_freq() {
    case "$DEVICE" in
        tg5050)
            cpufreq.sh ondemand 3 7 2>/dev/null || cpufreq.sh performance 7 2>/dev/null
            ;;
        brick_pro)
            cpufreq.sh ondemand 3 7 2>/dev/null || cpufreq.sh performance 6 2>/dev/null
            ;;
        *)
            cpufreq.sh ondemand 3 6 2>/dev/null || cpufreq.sh performance 6 2>/dev/null
            ;;
    esac
}

# ── Environment setup ─────────────────────────────────────────────────
export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$JAVA_HOME/lib:$JAVA_BASE/zulu17/lib:$LD_LIBRARY_PATH"
export CLASSPATH="$JAVA_HOME/lib:$CLASSPATH"
export TIMIDITY_CFG
export JAVA_TOOL_OPTIONS="-Xverify:none \
-Djava.util.prefs.systemRoot=$CONFIG_DIR \
-Djava.util.prefs.userRoot=$CONFIG_DIR \
-Djava.awt.headless=true \
-Dsun.jnu.encoding=UTF-8 \
-Dfile.encoding=UTF-8 \
-Djava.library.path=$JAVA_HOME/lib"

# ── Supported resolutions ─────────────────────────────────────────────
RESOLUTIONS="240x320 320x240 128x128 176x208 640x360 176x220 240x400 360x640"

# ── Parse arguments ───────────────────────────────────────────────────
rom_path=""
resolution_override=""
force_selector=0

for arg in "$@"; do
    case "$arg" in
        --resolution=*|-r=*)
            resolution_override="${arg#*=}"
            ;;
        --select|-s)
            force_selector=1
            ;;
        *)
            rom_path="$arg"
            ;;
    esac
done

if [ -z "$rom_path" ]; then
    echo "Usage: launch.sh [options] <game.jar>" >&2
    echo "  --resolution=WxH  Force specific resolution" >&2
    echo "  --select, -s      Force resolution selector" >&2
    exit 1
fi

# ── Validate ROM ──────────────────────────────────────────────────────
if [ ! -f "$rom_path" ]; then
    echo "ROM not found: $rom_path" >&2
    exit 1
fi

rom_name="$(basename "$rom_path" .jar)"

# ── Create directories ────────────────────────────────────────────────
mkdir -p "$CONFIG_DIR/.java/.systemPrefs" "$CONFIG_DIR/.java/.userPrefs"
mkdir -p "$RMS_DIR" "$CONFIG_DIR"

# ── Resolution functions ──────────────────────────────────────────────
save_resolution() {
    local res="$1"
    local resx="${res%x*}"
    local resy="${res#*x}"
    echo "$res" > "$CONFIG_DIR/${rom_name}.resolution"
    # Clean up old config folders for this game
    for dir in "$CONFIG_DIR/${rom_name}"*; do
        [ -d "$dir" ] || continue
        local basename_dir
        basename_dir="$(basename "$dir")"
        # Keep the active resolution folder, remove stale ones
        case "$basename_dir" in
            "${rom_name}${resx}${resy}"|"${rom_name}.resolution") continue ;;
            "${rom_name}"*) rm -rf "$dir" ;;
        esac
    done
}

load_resolution() {
    # 1. Check command-line override
    if [ -n "$resolution_override" ]; then
        echo "$resolution_override"
        return
    fi
    # 2. Check saved per-game resolution
    if [ -f "$CONFIG_DIR/${rom_name}.resolution" ]; then
        cat "$CONFIG_DIR/${rom_name}.resolution"
        return
    fi
    # 3. Check existing config folder
    for res in $RESOLUTIONS; do
        local resx="${res%x*}"
        local resy="${res#*x}"
        if [ -d "$CONFIG_DIR/${rom_name}${resx}${resy}" ]; then
            echo "$res"
            return
        fi
    done
    # 4. Default: let user choose
    echo ""
}

choose_resolution() {
    local selected
    selected=$(selector -t "Choose resolution for $rom_name:\n \
 (see https://tasemulators.github.io/freej2me-plus \
for resolution database)" -fs 160 -c $RESOLUTIONS)
    echo "${selected#*: }"
}

# ── Determine resolution ──────────────────────────────────────────────
resolution=""

if [ "$force_selector" -eq 1 ]; then
    resolution="$(choose_resolution)"
elif [ -n "$resolution_override" ]; then
    resolution="$resolution_override"
else
    resolution="$(load_resolution)"
fi

# If still empty, ask the user
if [ -z "$resolution" ]; then
    resolution="$(choose_resolution)"
fi

# Validate resolution format
if ! echo "$resolution" | grep -qE '^[0-9]+x[0-9]+$'; then
    echo "Invalid resolution: $resolution" >&2
    exit 1
fi

resx="${resolution%x*}"
resy="${resolution#*x}"

# Save for next time
save_resolution "$resolution"

# ── Rename RMS folder if needed ───────────────────────────────────────
rename_rms() {
    local current_rms new_rms
    current_rms="$(find "$RMS_DIR" -type d -name "${rom_name}*" 2>/dev/null | grep -v "${rom_name}${resx}${resy}" | head -n1)"
    if [ -n "$current_rms" ] && [ -d "$current_rms" ]; then
        new_rms="$RMS_DIR/${rom_name}${resx}${resy}"
        if [ ! -d "$new_rms" ]; then
            echo "Moving RMS: $(basename "$current_rms") -> $(basename "$new_rms")" >&2
            mv "$current_rms" "$new_rms"
        fi
    fi
}
rename_rms

# ── Setup controller mapping ──────────────────────────────────────────
# FreeJ2ME uses its own keymap, but we set up thd for L2/R2/mode
if [ -f "$THD_CONF" ] && [ -e /dev/input/event3 ]; then
    thd --triggers "$THD_CONF" /dev/input/event3 2>/dev/null &
    THD_PID=$!
fi

# Update freej2me keymap for TrimUI controller
cat > "$JAVA_HOME/bin/keymap.cfg" << 'KEYMAP'
{
    "left": "DPAD_LEFT",
    "right": "DPAD_RIGHT",
    "up": "DPAD_UP",
    "down": "DPAD_DOWN",
    "ok": "A",
    "cancel": "B",
    "soft1": "X",
    "soft2": "Y",
    "send": "START",
    "clear": "SELECT",
    "*": "L1",
    "#": "R1",
    "0": "DPAD_LEFT",
    "1": "DPAD_UP",
    "2": "DPAD_UP",
    "3": "DPAD_UP",
    "4": "DPAD_LEFT",
    "5": "DPAD_CENTER",
    "6": "DPAD_RIGHT",
    "7": "DPAD_LEFT",
    "8": "DPAD_DOWN",
    "9": "DPAD_RIGHT"
}
KEYMAP

# ── Launch ────────────────────────────────────────────────────────────
set_cpu_freq

echo "FreeJ2ME: $rom_name @ ${resx}x${resy}" >&2

cd "$JAVA_HOME/bin" || exit 1
exec java -jar "$FREEJ2ME_JAR" "$rom_path" "$resx" "$resy" 100

# Cleanup thd on exit
[ -n "$THD_PID" ] && kill "$THD_PID" 2>/dev/null
