#!/bin/sh
# Emus/JAVA/launch.sh - FreeJ2ME Java ME emulator launcher
# Uses common_launcher.sh for device detection

. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh

# Paths
JAVA_BASE="/mnt/SDCARD/Emus/JAVA"
JAVA_HOME="$JAVA_BASE/zulu17"
FREEJ2ME_JAR="$JAVA_HOME/bin/freej2me-sdl.jar"
CONFIG_DIR="$JAVA_HOME/bin/config"
RMS_DIR="$JAVA_HOME/bin/rms"
TIMIDITY_CFG="$JAVA_BASE/timidity/timidity.cfg"
THD_CONF="$JAVA_BASE/thd.conf"

# Use JUKAMIX_DEVICE_OPTIMIZED from common_launcher.sh
DEVICE="$JUKAMIX_DEVICE_OPTIMIZED"

# CPU frequency by device
case "$DEVICE" in
    tg5050)
        cpufreq.sh ondemand 3 7 2>/dev/null || cpufreq.sh performance 3 2>/dev/null
        ;;
    brick_pro)
        cpufreq.sh ondemand 3 7 2>/dev/null || cpufreq.sh performance 3 2>/dev/null
        ;;
    *)
        cpufreq.sh ondemand 3 6 2>/dev/null || cpufreq.sh performance 3 2>/dev/null
        ;;
esac

# Environment setup
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

# Supported resolutions
RESOLUTIONS="240x320 320x240 128x128 176x208 640x360 176x220 240x400 360x640"

# Parse arguments
rom_path=""
resolution_override=""
force_selector=0

for arg in "$@"; do
    case "$arg" in
        --resolution=*|-r=*) resolution_override="${arg#*=}" ;;
        --select|-s) force_selector=1 ;;
        *) rom_path="$arg" ;;
    esac
done

[ -z "$rom_path" ] && { echo "Usage: launch.sh [options] <game.jar>" >&2; exit 1; }
[ ! -f "$rom_path" ] && { echo "ROM not found: $rom_path" >&2; exit 1; }

rom_name="$(basename "$rom_path" .jar)"

# Create directories
mkdir -p "$CONFIG_DIR/.java/.systemPrefs" "$CONFIG_DIR/.java/.userPrefs"
mkdir -p "$RMS_DIR" "$CONFIG_DIR"

# Resolution functions
save_resolution() {
    local res="$1"
    local resx="${res%x*}"
    local resy="${res#*x}"
    echo "$res" > "$CONFIG_DIR/${rom_name}.resolution"
    for dir in "$CONFIG_DIR/${rom_name}"*; do
        [ -d "$dir" ] || continue
        local basename_dir="$(basename "$dir")"
        case "$basename_dir" in
            "${rom_name}${resx}${resy}"|"${rom_name}.resolution") continue ;;
            "${rom_name}"*) rm -rf "$dir" ;;
        esac
    done
}

load_resolution() {
    [ -n "$resolution_override" ] && { echo "$resolution_override"; return; }
    [ -f "$CONFIG_DIR/${rom_name}.resolution" ] && { cat "$CONFIG_DIR/${rom_name}.resolution"; return; }
    for res in $RESOLUTIONS; do
        local resx="${res%x*}"
        local resy="${res#*x}"
        [ -d "$CONFIG_DIR/${rom_name}${resx}${resy}" ] && { echo "$res"; return; }
    done
    echo ""
}

choose_resolution() {
    local selected
    selected=$(selector -t "Choose resolution for $rom_name:\n \
 (see https://tasemulators.github.io/freej2me-plus \
for resolution database)" -fs 160 -c $RESOLUTIONS)
    echo "${selected#*: }"
}

# Determine resolution
resolution=""
if [ "$force_selector" -eq 1 ]; then
    resolution="$(choose_resolution)"
elif [ -n "$resolution_override" ]; then
    resolution="$resolution_override"
else
    resolution="$(load_resolution)"
fi

[ -z "$resolution" ] && resolution="$(choose_resolution)"

echo "$resolution" | grep -qE '^[0-9]+x[0-9]+$' || { echo "Invalid resolution: $resolution" >&2; exit 1; }

resx="${resolution%x*}"
resy="${resolution#*x}"
save_resolution "$resolution"

# Rename RMS folder if needed
current_rms="$(find "$RMS_DIR" -type d -name "${rom_name}*" 2>/dev/null | grep -v "${rom_name}${resx}${resy}" | head -n1)"
[ -n "$current_rms" ] && [ -d "$current_rms" ] && mv "$current_rms" "$RMS_DIR/${rom_name}${resx}${resy}" 2>/dev/null

# Setup controller mapping
[ -f "$THD_CONF" ] && [ -e /dev/input/event3 ] && thd --triggers "$THD_CONF" /dev/input/event3 2>/dev/null &

# Launch
echo "FreeJ2ME: $rom_name @ ${resx}x${resy}" >&2
cd "$JAVA_HOME/bin" || exit 1
exec java -jar "$FREEJ2ME_JAR" "$rom_path" "$resx" "$resy" 100
