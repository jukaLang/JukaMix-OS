#!/bin/sh
# System/usr/trimui/scripts/load_launcher.sh
# Load and execute emulator launcher with preset support

export PATH="/mnt/SDCARD/System/usr/trimui/scripts/:/mnt/SDCARD/System/bin:${PATH:+:$PATH}"
export LD_LIBRARY_PATH="/usr/trimui/lib:${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# ── Safeguards ────────────────────────────────────────────────────────
mkdir -p /tmp/trimui_osd 2>/dev/null
mkdir -p /tmp/log 2>/dev/null

EMU_DIR="$(echo "$0" | sed -E 's|(.*Emus/[^/]+)/.*|\1|')"
ROM_DIR="$(echo "$1" | sed -E 's|(.*Roms/[^/]+)/.*|\1|')"
GAME="$(basename "$1")"

export Game_cfg="$ROM_DIR/.games_config/${GAME%.*}.cfg"
export Emu_cfg="$EMU_DIR/launchers.cfg"

# ── Look for a saved preset ───────────────────────────────────────────
Launcher_name=""
Preset_Type=""

if [ -f "$Game_cfg" ]; then
    Launcher_name="$(cat "$Game_cfg" 2>/dev/null)"
    Preset_Type="Game"
elif [ -f "$Emu_cfg" ]; then
    Launcher_name="$(cat "$Emu_cfg" 2>/dev/null)"
    Preset_Type="Emu"
fi

# Strip key= prefix if present
Launcher_name="${Launcher_name#*=}"

# ── Find launcher command ─────────────────────────────────────────────
Launcher_command=""

if [ -n "$Launcher_name" ] && command -v jq >/dev/null 2>&1; then
    # Look up the named launcher from config.json
    Launcher_command="$(jq -r --arg name "$Launcher_name" \
        '.launchlist[] | select(.name == $name) | .launch' "$EMU_DIR/config.json" 2>/dev/null)"
    if [ -n "$Launcher_command" ] && [ "$Launcher_command" != "null" ]; then
        printf '{ "type":"info", "size":2, "duration":2000, "x":660, "y":0, "message":"%s preset: %s", "icon":"" }\n' \
            "$Preset_Type" "$Launcher_name" >/tmp/trimui_osd/osd_toast_msg 2>/dev/null
    else
        Launcher_command=""
    fi
fi

# If no named preset found, use the top-level "launch" field from config.json
# This is the standard path — most emus set "launch": "default.sh" there.
if [ -z "$Launcher_command" ]; then
    if [ -f "$EMU_DIR/config.json" ] && command -v jq >/dev/null 2>&1; then
        Launcher_command="$(jq -r '.launch // empty' "$EMU_DIR/config.json" 2>/dev/null)"
    fi
fi

# Fallback: try launch.sh
if [ -z "$Launcher_command" ]; then
    Launcher_name="Default"
    Launcher_command="launch.sh"
fi

# Safety: verify the launcher script exists
if [ ! -f "$EMU_DIR/$Launcher_command" ]; then
    # Try to find any .sh in the emu directory
    fallback="$(find "$EMU_DIR" -maxdepth 1 -name '*.sh' -not -name 'default.sh' 2>/dev/null | head -1)"
    if [ -n "$fallback" ]; then
        Launcher_command="$(basename "$fallback")"
        Launcher_name="$(echo "$Launcher_command" | sed 's/\.sh$//')"
    fi
fi

echo "load_launcher.sh : $Launcher_name dowork 0x" >> /tmp/log/messages 2>/dev/null

# Reset CPU preset
(
    rm -f "/tmp/trimui_osd/slider_cpu_preset/curpreset" 2>/dev/null
    echo "0/3" > "/tmp/trimui_osd/slider_cpu_preset/status" 2>/dev/null
) &

# Launch the emulator — trap errors so we don't reboot on failure
if [ -f "$EMU_DIR/$Launcher_command" ]; then
    "$EMU_DIR/$Launcher_command" "$@"
    rc=$?
else
    echo "load_launcher.sh : ERROR launcher not found: $EMU_DIR/$Launcher_command" >> /tmp/log/messages 2>/dev/null
    rc=1
fi

# Reset CPU preset after exit
(
    rm -f "/tmp/trimui_osd/slider_cpu_preset/curpreset" 2>/dev/null
    echo "0/3" > "/tmp/trimui_osd/slider_cpu_preset/status" 2>/dev/null
) &

exit 0
