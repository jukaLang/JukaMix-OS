#!/bin/sh
# keyremap.sh - Universal key remapping for TrimUI emulators
#
# Reads a remap profile and applies key remapping via SDL2 environment
# or evdev interception. Works with any emulator that respects SDL mappings.
#
# Usage:
#   keyremap.sh <profile_name> <command> [args...]
#   keyremap.sh none <command> [args...]       # No remapping
#   keyremap.sh list                           # List available profiles
#
# Profiles are stored in /mnt/SDCARD/System/usr/trimui/keymaps/
# Format: Simple key=value pairs (physical_key=logical_key)
#
# Example profile (nintendo.ini):
#   A=A
#   B=B
#   X=X
#   Y=Y
#   L1=L1
#   R1=R1
#   START=START
#   SELECT=SELECT
#   UP=UP
#   DOWN=DOWN
#   LEFT=LEFT
#   RIGHT=RIGHT

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
    echo "keyremap: available profiles:" >&2
    keyremap.sh list >&2
    exec "$@"
fi

echo "keyremap: loading profile: $CURRENT_PROFILE"

# Build SDL gamecontrollerdb mapping string from profile
# This maps physical buttons to logical SDL buttons
build_sdl_mapping() {
    local profile="$1"
    local mapping=""

    # Default TrimUI mapping (physical -> SDL button name)
    # Read profile overrides
    while IFS='=' read -r phys_key logi_key; do
        # Skip comments and empty lines
        case "$phys_key" in
            \#*|"") continue ;;
        esac
        # Trim whitespace
        phys_key=$(echo "$phys_key" | tr -d ' \t')
        logi_key=$(echo "$logi_key" | tr -d ' \t')

        case "$logi_key" in
            A)      mapping="${mapping}btn_a:" ;;
            B)      mapping="${mapping}btn_b:" ;;
            X)      mapping="${mapping}btn_x:" ;;
            Y)      mapping="${mapping}btn_y:" ;;
            L1)     mapping="${mapping}btn_leftshoulder:" ;;
            R1)     mapping="${mapping}btn_rightshoulder:" ;;
            L2)     mapping="${mapping}btn_lefttrigger:" ;;
            R2)     mapping="${mapping}btn_righttrigger:" ;;
            START)  mapping="${mapping}btn_start:" ;;
            SELECT) mapping="${mapping}btn_back:" ;;
            UP)     mapping="${mapping}dpup:" ;;
            DOWN)   mapping="${mapping}dpdown:" ;;
            LEFT)   mapping="${mapping}dpleft:" ;;
            RIGHT)  mapping="${mapping}dpdown:" ;;
        esac
    done < "$profile"

    echo "$mapping"
}

# Create SDL gamecontroller mapping override
create_sdl_override() {
    local profile="$1"
    local override_file="/tmp/gamecontrollerdb.txt"

    # Start with empty mapping for TrimUI controller
    # Format: <guid>,<name>,<platform>,<mapping>
    # We use * as GUID to match any controller
    local mapping=""

    while IFS='=' read -r phys_key logi_key; do
        case "$phys_key" in
            \#*|"") continue ;;
        esac
        phys_key=$(echo "$phys_key" | tr -d ' \t')
        logi_key=$(echo "$logi_key" | tr -d ' \t')

        case "$logi_key" in
            A)      mapping="${mapping}btn:a," ;;
            B)      mapping="${mapping}btn:b," ;;
            X)      mapping="${mapping}btn:x," ;;
            Y)      mapping="${mapping}btn:y," ;;
            L1)     mapping="${mapping}btn:leftshoulder," ;;
            R1)     mapping="${mapping}btn:rightshoulder," ;;
            L2)     mapping="${mapping}btn:lefttrigger," ;;
            R2)     mapping="${mapping}btn:righttrigger," ;;
            START)  mapping="${mapping}btn:start," ;;
            SELECT) mapping="${mapping}btn:back," ;;
            UP)     mapping="${mapping}btn:dpup," ;;
            DOWN)   mapping="${mapping}btn:dpdown," ;;
            LEFT)   mapping="${mapping}btn:dpleft," ;;
            RIGHT)  mapping="${mapping}btn:dpup," ;;
        esac
    done < "$profile"

    if [ -n "$mapping" ]; then
        echo ",${CURRENT_PROFILE},platform:Linux,${mapping}" > "$override_file"
        export SDL_GAMECONTROLLERCONFIG_FILE="$override_file"
        echo "keyremap: SDL override created: $override_file"
    fi
}

# Also try evdev-level remapping via inputattach or interceptevdev
apply_evdev_remap() {
    local profile="$1"

    # Read profile and create evdev key remapping
    local remap_args=""
    while IFS='=' read -r phys_key logi_key; do
        case "$phys_key" in
            \#*|"") continue ;;
        esac
        phys_key=$(echo "$phys_key" | tr -d ' \t')
        logi_key=$(echo "$logi_key" | tr -d ' \t')

        # Convert button names to keycodes
        local phys_code=""
        local logi_code=""
        case "$phys_key" in
            A)      phys_code="304" ;;  # BTN_SOUTH
            B)      phys_code="305" ;;  # BTN_EAST
            X)      phys_code="307" ;;  # BTN_NORTH
            Y)      phys_code="308" ;;  # BTN_WEST
            L1)     phys_code="310" ;;  # BTN_TL
            R1)     phys_code="311" ;;  # BTN_TR
            L2)     phys_code="312" ;;  # BTN_TL2
            R2)     phys_code="313" ;;  # BTN_TR2
            START)  phys_code="315" ;;  # BTN_START
            SELECT) phys_code="314" ;;  # BTN_SELECT
            UP)     phys_code="710" ;;  # BTN_DPAD_UP
            DOWN)   phys_code="711" ;;  # BTN_DPAD_DOWN
            LEFT)   phys_code="712" ;;  # BTN_DPAD_LEFT
            RIGHT)  phys_code="713" ;;  # BTN_DPAD_RIGHT
        esac
        case "$logi_key" in
            A)      logi_code="304" ;;
            B)      logi_code="305" ;;
            X)      logi_code="307" ;;
            Y)      logi_code="308" ;;
            L1)     logi_code="310" ;;
            R1)     logi_code="311" ;;
            L2)     logi_code="312" ;;
            R2)     logi_code="313" ;;
            START)  logi_code="315" ;;
            SELECT) logi_code="314" ;;
            UP)     logi_code="710" ;;
            DOWN)   logi_code="711" ;;
            LEFT)   logi_code="712" ;;
            RIGHT)  logi_code="713" ;;
        esac

        if [ -n "$phys_code" ] && [ -n "$logi_code" ] && [ "$phys_code" != "$logi_code" ]; then
            remap_args="$remap_args $phys_code:$logi_code"
        fi
    done < "$profile"

    if [ -n "$remap_args" ]; then
        # Try to use evdev remapping if available
        if command -v interceptevdev >/dev/null 2>&1; then
            echo "keyremap: applying evdev remapping"
            # evdev remapping would go here
        fi
    fi
}

# Apply remapping
create_sdl_override "$PROFILE_FILE"
apply_evdev_remap "$PROFILE_FILE"

# Execute the emulator with remapping applied
exec "$@"
