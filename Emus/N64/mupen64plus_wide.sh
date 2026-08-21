#!/bin/sh
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh
if [ "$JUKAMIX_DEVICE_OPTIMIZED" = "tg5050" ]; then
    cpufreq.sh ondemand 4 9
else
    cpufreq.sh ondemand 4 7
fi

cd "$RA_DIR/"

# Variable for the path to the Mupen64Plus directory
MUPEN_DIR="/mnt/SDCARD/RetroArch/.retroarch/config/Mupen64Plus GLES2"

# Extract the filename from the full path without the extension
ROM_PATH="$1"
ROM_NAME=$(basename "$ROM_PATH" | sed 's/\.[^.]*$//')

# Paths to the source config files
N64_CFG="$MUPEN_DIR/N64.cfg"
N64_OPT="$MUPEN_DIR/Mupen64Plus GLES2.opt"

# Use a private temp directory for per-ROM configs
TEMP_DIR="/tmp/mupen_wide_$$"
mkdir -p "$TEMP_DIR"
ROM_CFG="$TEMP_DIR/$ROM_NAME.cfg"
ROM_OPT="$TEMP_DIR/$ROM_NAME.opt"

# Cleanup trap: always remove temp files on exit
cleanup() {
    rm -f "$ROM_CFG" "$ROM_OPT" 2>/dev/null
    rmdir "$TEMP_DIR" 2>/dev/null
}
trap cleanup EXIT INT TERM HUP

# Verify source config files exist
if [ ! -f "$N64_CFG" ] || [ ! -f "$N64_OPT" ]; then
    echo "Error: Missing default config files in $MUPEN_DIR"
    exit 1
fi

# Copy the configuration files to temp directory
cp "$N64_CFG" "$ROM_CFG"
cp "$N64_OPT" "$ROM_OPT"

# Apply widescreen patches
/mnt/SDCARD/System/usr/trimui/scripts/patch_ra_cfg.sh "$MUPEN_DIR/widescreen.cfg" "$ROM_CFG"
/mnt/SDCARD/System/usr/trimui/scripts/patch_ra_cfg.sh "$MUPEN_DIR/widescreen.opt" "$ROM_OPT"

# Launch the game
HOME="$RA_DIR"/ "$RA_BIN" -v -L "$RA_DIR"/.retroarch/cores/mupen64plus_libretro.so "$@"
