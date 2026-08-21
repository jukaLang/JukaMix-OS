#!/bin/sh
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh
if [ "$JUKAMIX_DEVICE_OPTIMIZED" = "tg5050" ]; then
    cpufreq.sh ondemand 5 9
else
    cpufreq.sh ondemand 5 7
fi

# Require exactly one ROM argument
if [ $# -ne 1 ]; then
    echo "Usage: $0 <rom_path>"
    exit 1
fi

ROM_PATH="$1"

# Validate ROM extension
case "$ROM_PATH" in
    *.n64|*.v64|*.z64|*.ndd|*.zip|*.7z)
        ;;
    *)
        echo "Error: Unsupported ROM format: $ROM_PATH"
        exit 1
        ;;
esac

cd /mnt/SDCARD/Emus/N64
export XDG_CONFIG_HOME="$PWD"
export XDG_DATA_HOME="$PWD"

cd mupen64plus
EMU_DIR="$PWD"

export LD_LIBRARY_PATH="$PM_DIR:$EMU_DIR:$LD_LIBRARY_PATH"

[ -f "/mnt/SDCARD/trimui/app/cmd_to_run.sh" ] && fb_disable_transparency

# Handle archives
TEMP_ROM=""
cleanup() {
    [ -n "$TEMP_ROM" ] && rm -f "$TEMP_ROM" 2>/dev/null
}
trap cleanup EXIT INT TERM HUP

case "$ROM_PATH" in
    *.zip|*.7z)
        TEMP_ROM=$(mktemp /tmp/n64dd_XXXXXX.ndd)
        7zz e "$ROM_PATH" -so > "$TEMP_ROM"
        ROM_PATH="$TEMP_ROM"
        ;;
esac

# Launch gptokeyb2 and save its PID
HOTKEY=guide $PM_DIR/gptokeyb2 -c "./defkeys.gptk" &
GPTOKEY_PID=$!

# Launch emulator
HOME=$EMU_DIR ./mupen64plus "$ROM_PATH" 2>&1

# Cleanup gptokeyb2
[ -n "$GPTOKEY_PID" ] && kill -9 "$GPTOKEY_PID" 2>/dev/null
