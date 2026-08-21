#!/bin/sh
# apply_remap.sh - Shared key remapping helper for all emulators
#
# Source this file in any emulator launcher to apply the active key remap profile:
#   . /mnt/SDCARD/System/usr/trimui/scripts/apply_remap.sh
#
# Reads /mnt/SDCARD/System/usr/trimui/keyremap.conf for the active profile name
# and creates SDL controller config override in /tmp/gamecontrollerdb.txt

REMAP_CONFIG="/mnt/SDCARD/System/usr/trimui/keyremap.conf"
KEYMAP_DIR="/mnt/SDCARD/System/usr/trimui/keymaps"

# Source this in emulator launchers to apply the active key remap profile
# Usage: . /mnt/SDCARD/System/usr/trimui/scripts/apply_remap.sh

apply_remap() {
    # No config file = no remapping
    [ -f "$REMAP_CONFIG" ] || return 0

    local profile
    profile=$(cat "$REMAP_CONFIG" 2>/dev/null)
    [ -n "$profile" ] && [ "$profile" != "none" ] || return 0

    local profile_file="$KEYMAP_DIR/${profile}.ini"
    [ -f "$profile_file" ] || return 0

    echo "apply_remap: Using profile '$profile'"

    # Read the remap mappings into arrays
    # Format in .ini: LOGICAL=PHYSICAL (e.g., A=B means press physical B to get logical A)
    local remap_a="" remap_b="" remap_x="" remap_y=""
    local remap_l="" remap_r="" remap_lt="" remap_rt=""
    local remap_start="" remap_select=""
    local remap_up="" remap_down="" remap_left="" remap_right=""

    while IFS='=' read -r logical physical; do
        # Skip comments and empty lines
        case "$logical" in \#*|""|*\ *) continue ;; esac
        logical=$(echo "$logical" | tr -d ' \t\r')
        physical=$(echo "$physical" | tr -d ' \t\r')

        case "$logical" in
            A)      remap_a="$physical" ;;
            B)      remap_b="$physical" ;;
            X)      remap_x="$physical" ;;
            Y)      remap_y="$physical" ;;
            L1|L)   remap_l="$physical" ;;
            R1|R)   remap_r="$physical" ;;
            L2|LT)  remap_lt="$physical" ;;
            R2|RT)  remap_rt="$physical" ;;
            START)  remap_start="$physical" ;;
            SELECT) remap_select="$physical" ;;
            UP)     remap_up="$physical" ;;
            DOWN)   remap_down="$physical" ;;
            LEFT)   remap_left="$physical" ;;
            RIGHT)  remap_right="$physical" ;;
        esac
    done < "$profile_file"

    # Apply remapping to RetroArch via config override
    # This creates a temporary retroarch.cfg with remapped input binds
    local retromap=""

    # Helper: map logical button to RetroArch input name
    ra_input_name() {
        case "$1" in
            A) echo "input_a" ;;
            B) echo "input_b" ;;
            X) echo "input_x" ;;
            Y) echo "input_y" ;;
            L1|L) echo "input_l" ;;
            R1|R) echo "input_r" ;;
            L2|LT) echo "input_l2" ;;
            R2|RT) echo "input_r2" ;;
            START) echo "input_start" ;;
            SELECT) echo "input_select" ;;
            UP) echo "input_up" ;;
            DOWN) echo "input_down" ;;
            LEFT) echo "input_left" ;;
            RIGHT) echo "input_right" ;;
            *) echo "" ;;
        esac
    }

    # Build RetroArch remap commands
    for btn in A B X Y L1 R1 L2 RT START SELECT UP DOWN LEFT RIGHT; do
        eval "physical=\$remap_$(echo $btn | tr 'A-Z' 'a-z')"
        [ -z "$physical" ] && continue

        local ra_name=$(ra_input_name "$btn")
        [ -z "$ra_name" ] && continue

        # Map physical button to RetroArch joypad index
        local ra_index=-1
        case "$physical" in
            A)      ra_index=0 ;;
            B)      ra_index=1 ;;
            X)      ra_index=2 ;;
            Y)      ra_index=3 ;;
            L1|L)   ra_index=4 ;;
            R1|R)   ra_index=5 ;;
            L2|LT)  ra_index=6 ;;
            R2|RT)  ra_index=7 ;;
            START)  ra_index=9 ;;
            SELECT) ra_index=8 ;;
            UP)     ra_index=11 ;;
            DOWN)   ra_index=12 ;;
            LEFT)   ra_index=13 ;;
            RIGHT)  ra_index=14 ;;
        esac

        if [ "$ra_index" -ge 0 ]; then
            retromap+="${ra_name} = \"joypad ${ra_index}\"\n"
        fi
    done

    if [ -n "$retromap" ]; then
        # Write RetroArch remap config
        mkdir -p /tmp/jukamix_remap
        echo -e "$retromap" > /tmp/jukamix_remap/remap.cfg
        export RETROARCH_REMAP_FILE="/tmp/jukamix_remap/remap.cfg"
        echo "apply_remap: RetroArch remap written to $RETROARCH_REMAP_FILE"
    fi

    # For non-RetroArch emulators (DraStic, PPSSPP, etc.) - use SDL override
    if [ -n "$remap_a" ] || [ -n "$remap_b" ]; then
        # Build SDL gamecontrollerdb mapping
        local guid="00000000000000000000000000000000"
        local name="JukaMix Remapped"
        local platform="Linux"

        # Build button mapping string
        local sdl_map=""
        for pair in "A:$remap_a" "B:$remap_b" "X:$remap_x" "Y:$remap_y" \
                   "leftshoulder:$remap_l" "rightshoulder:$remap_r" \
                   "lefttrigger:$remap_lt" "righttrigger:$remap_rt" \
                   "start:$remap_start" "back:$remap_select" \
                   "dpup:$remap_up" "dpdown:$remap_down" \
                   "dpleft:$remap_left" "dpup:$remap_right"; do
            local sdl_name="${pair%%:*}"
            local phys="${pair#*:}"
            [ -z "$phys" ] && continue

            # Map physical to SDL button number
            local btn_num=-1
            case "$phys" in
                A)      btn_num=0 ;;
                B)      btn_num=1 ;;
                X)      btn_num=2 ;;
                Y)      btn_num=3 ;;
                L1|L)   btn_num=4 ;;
                R1|R)   btn_num=5 ;;
                L2|LT)  btn_num=6 ;;
                R2|RT)  btn_num=7 ;;
                START)  btn_num=9 ;;
                SELECT) btn_num=8 ;;
                UP)     btn_num=11 ;;
                DOWN)   btn_num=12 ;;
                LEFT)   btn_num=13 ;;
                RIGHT)  btn_num=14 ;;
            esac

            if [ "$btn_num" -ge 0 ]; then
                sdl_map+="${sdl_name}:b${btn_num},"
            fi
        done

        if [ -n "$sdl_map" ]; then
            echo "${guid},${name},${platform},${sdl_map}" > /tmp/gamecontrollerdb.txt
            export SDL_GAMECONTROLLERCONFIG_FILE="/tmp/gamecontrollerdb.txt"
            echo "apply_remap: SDL override written"
        fi
    fi
}

# Auto-apply when sourced
apply_remap
