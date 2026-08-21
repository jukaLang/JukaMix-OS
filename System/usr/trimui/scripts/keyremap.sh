#!/bin/sh
# keyremap.sh - Universal key remapping for TrimUI emulators
#
# Usage:
#   keyremap.sh <profile_name> <command> [args...]
#   keyremap.sh none <command> [args...]       # No remapping
#   keyremap.sh list                           # List available profiles
#
# Profiles are stored in /mnt/SDCARD/System/usr/trimui/keymaps/
# Format: LOGICAL=PHYSICAL (e.g., A=B means press physical B to get logical A)

KEYMAP_DIR="/mnt/SDCARD/System/usr/trimui/keymaps"
CURRENT_PROFILE="${1:-none}"
shift 2>/dev/null

# List profiles
if [ "$CURRENT_PROFILE" = "list" ]; then
    echo "Available key remap profiles:"
    echo "  none          - Default mapping (no changes)"
    echo ""
    if [ -d "$KEYMAP_DIR" ]; then
        for f in "$KEYMAP_DIR"/*.ini; do
            [ -f "$f" ] || continue
            name=$(basename "$f" .ini)
            desc=$(grep "^#desc=" "$f" 2>/dev/null | head -1 | cut -d= -f2-)
            if [ -n "$desc" ]; then
                printf "  %-14s %s\n" "$name" "$desc"
            else
                echo "  $name"
            fi
        done
    fi
    exit 0
fi

# No remapping requested
if [ "$CURRENT_PROFILE" = "none" ] || [ -z "$CURRENT_PROFILE" ]; then
    exec "$@"
fi

# Load profile
PROFILE_FILE="$KEYMAP_DIR/${CURRENT_PROFILE}.ini"
if [ ! -f "$PROFILE_FILE" ]; then
    echo "keyremap: profile not found: $PROFILE_FILE" >&2
    keyremap.sh list >&2 2>/dev/null
    exec "$@"
fi

echo "keyremap: loading profile: $CURRENT_PROFILE"

# Map button name to RetroArch joypad index (and SDL button number)
button_index() {
    case "$1" in
        A)      echo 0 ;;
        B)      echo 1 ;;
        X)      echo 2 ;;
        Y)      echo 3 ;;
        L1|L)   echo 4 ;;
        R1|R)   echo 5 ;;
        L2|LT)  echo 6 ;;
        R2|RT)  echo 7 ;;
        SELECT) echo 8 ;;
        START)  echo 9 ;;
        UP)     echo 11 ;;
        DOWN)   echo 12 ;;
        LEFT)   echo 13 ;;
        RIGHT)  echo 14 ;;
        *)      echo -1 ;;
    esac
}

# Create SDL gamecontrollerdb override for standalone emulators
create_sdl_override() {
    local profile="$1"
    local override_file="/tmp/gamecontrollerdb.txt"
    local mapping=""

    while IFS='=' read -r logical physical; do
        case "$logical" in \#*|"") continue ;; esac
        logical=$(echo "$logical" | tr -d ' \t')
        physical=$(echo "$physical" | tr -d ' \t')

        # Map logical button to SDL name
        local sdl_name=""
        case "$logical" in
            A)      sdl_name="a" ;;
            B)      sdl_name="b" ;;
            X)      sdl_name="x" ;;
            Y)      sdl_name="y" ;;
            L1)     sdl_name="leftshoulder" ;;
            R1)     sdl_name="rightshoulder" ;;
            L2)     sdl_name="lefttrigger" ;;
            R2)     sdl_name="righttrigger" ;;
            START)  sdl_name="start" ;;
            SELECT) sdl_name="back" ;;
            UP)     sdl_name="dpup" ;;
            DOWN)   sdl_name="dpdown" ;;
            LEFT)   sdl_name="dpleft" ;;
            RIGHT)  sdl_name="dpright" ;;
        esac
        [ -z "$sdl_name" ] && continue

        local btn_num
        btn_num=$(button_index "$physical")
        [ "$btn_num" -ge 0 ] 2>/dev/null || continue

        mapping="${mapping}${sdl_name}:b${btn_num},"
    done < "$profile"

    if [ -n "$mapping" ]; then
        printf ',00000000000000000000000000000000,JukaMix Remapped,platform:Linux,%s\n' "$mapping" \
            > "$override_file"
        export SDL_GAMECONTROLLERCONFIG_FILE="$override_file"
        echo "keyremap: SDL override created: $override_file"
    fi
}

# Apply remapping
create_sdl_override "$PROFILE_FILE"

# Execute the emulator with remapping applied
exec "$@"
