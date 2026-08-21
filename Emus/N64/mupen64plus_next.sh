#!/bin/sh
# N64: Mupen64Plus-Next (Ludicrous mode) - maximum accuracy & performance
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh

# Ludicrous N64 mode - maximum performance with Mupen64Plus-Next
if [ "$JUKAMIX_DEVICE_OPTIMIZED" = "tg5050" ]; then
    cpufreq.sh ondemand 4 9
else
    cpufreq.sh ondemand 4 8
fi

cd "$RA_DIR/"

# Ludicrous settings: GLideN64 plugin, no shader smoothing, no auto-savestate
LUDICROUS_CFG="/tmp/retroarch_ludicrous.cfg"
cat > "$LUDICROUS_CFG" << 'CFGEOF'
# Ludicrous N64 Settings
video_shader_enable = "false"
video_smooth = "false"
video_filter = "0"
input_autodetect_enable = "false"
savestate_auto_load = "false"
savestate_auto_save = "false"
CFGEOF

HOME="$RA_DIR" "$RA_BIN" -v \
    -c "$LUDICROUS_CFG" \
    -L "$RA_DIR"/.retroarch/cores/mupen64plus_next_libretro.so \
    "$@"
