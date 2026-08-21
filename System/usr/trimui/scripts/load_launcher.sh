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
GAME=$(basename "$1")

export Game_cfg="$ROM_DIR/.games_config/${GAME%.*}.cfg"
export Emu_cfg="$EMU_DIR/launchers.cfg"

# ── Look for a saved preset ───────────────────────────────────────────
Launcher_name=""
Preset_Type=""

if [ -f "$Game_cfg" ]; then
    Launcher_name=$(cat "$Game_cfg" 2>/dev/null)
    Preset_Type="Game"
elif [ -f "$Emu_cfg" ]; then
    Launcher_name=$(cat "$Emu_cfg" 2>/dev/null)
    Preset_Type="Emu"
fi

# Strip key= prefix if present
Launcher_name=${Launcher_name#*=}

# ── Find launcher command ─────────────────────────────────────────────
if [ -n "$Launcher_name" ] && command -v jq >/dev/null 2>&1; then
    Launcher_command=$(jq -r --arg name "$Launcher_name" \
        '.launchlist[] | select(.name == $name) | .launch' "$EMU_DIR/config.json" 2>/dev/null)
    echo -e "{ \"type\":\"info\", \"size\":2, \"duration\":2000, \"x\":660, \"y\":0,  \"message\":\"$Preset_Type preset: $Launcher_name\",  \"icon\":\"\" }" >/tmp/trimui_osd/osd_toast_msg 2>/dev/null

else
    # Look for the first valid launcher in launchlist
    if [ -f "$EMU_DIR/config.json" ] && command -v jq >/dev/null 2>&1 && jq -e ".launchlist" "$EMU_DIR/config.json" >/dev/null 2>&1; then
        # POSIX-compatible: use while read instead of process substitution
        jq -c '.launchlist[]' "$EMU_DIR/config.json" 2>/dev/null | while read -r launcher; do
            Launcher_name=$(echo "$launcher" | jq -r '.name' 2>/dev/null)
            Launcher_command=$(echo "$launcher" | jq -r '.launch' 2>/dev/null)
            if [ -n "$Launcher_command" ]; then
                break
            fi
        done
    fi
    
    # Fallback to launch.sh
    if [ -z "$Launcher_command" ]; then
        Launcher_name=Default
        Launcher_command="launch.sh"
    fi
fi

echo "load_launcher.sh : $Launcher_name dowork 0x" >> /tmp/log/messages 2>/dev/null

# Reset CPU preset
{
    rm -f "/tmp/trimui_osd/slider_cpu_preset/curpreset" 2>/dev/null
    echo "0/3" > "/tmp/trimui_osd/slider_cpu_preset/status" 2>/dev/null
} &

# Launch the emulator
"$EMU_DIR/$Launcher_command" "$@"

# Reset CPU preset after exit
{
    rm -f "/tmp/trimui_osd/slider_cpu_preset/curpreset" 2>/dev/null
    echo "0/3" > "/tmp/trimui_osd/slider_cpu_preset/status" 2>/dev/null
} &
