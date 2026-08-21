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

apply_remap() {
    # No config file = no remapping
    [ -f "$REMAP_CONFIG" ] || return 0

    local profile
    profile=$(cat "$REMAP_CONFIG" 2>/dev/null)
    [ -n "$profile" ] && [ "$profile" != "none" ] || return 0

    local profile_file="$KEYMAP_DIR/${profile}.ini"
    [ -f "$profile_file" ] || return 0

    echo "apply_remap: Using profile '$profile'"

    # Read the remap mappings from profile
    # Format: LOGICAL=PHYSICAL (e.g., A=B means press physical B to get logical A)
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

    # No actual remapping if all defaults are still set (all buttons unchanged)
    if [ -z "$remap_a" ] && [ -z "$remap_b" ] && [ -z "$remap_x" ] && [ -z "$remap_y" ]; then
        return 0
    fi

    # Helper: map physical button name to RetroArch joypad index
    ra_button_index() {
        case "$1" in
            A)      echo 0 ;;   # input_a
            B)      echo 1 ;;   # input_b
            X)      echo 2 ;;   # input_x
            Y)      echo 3 ;;   # input_y
            L1|L)   echo 4 ;;   # input_l (left shoulder)
            R1|R)   echo 5 ;;   # input_r (right shoulder)
            L2|LT)  echo 6 ;;   # input_l2 (left trigger)
            R2|RT)  echo 7 ;;   # input_r2 (right trigger)
            SELECT) echo 8 ;;   # input_select
            START)  echo 9 ;;   # input_start
            UP)     echo 11 ;;  # input_up
            DOWN)   echo 12 ;;  # input_down
            LEFT)   echo 13 ;;  # input_left
            RIGHT)  echo 14 ;;  # input_right
            *)      echo -1 ;;
        esac
    }

    # Helper: map logical button name to RetroArch input key name
    ra_input_name() {
        case "$1" in
            A)      echo "input_a" ;;
            B)      echo "input_b" ;;
            X)      echo "input_x" ;;
            Y)      echo "input_y" ;;
            L1|L)   echo "input_l" ;;
            R1|R)   echo "input_r" ;;
            L2|LT)  echo "input_l2" ;;
            R2|RT)  echo "input_r2" ;;
            START)  echo "input_start" ;;
            SELECT) echo "input_select" ;;
            UP)     echo "input_up" ;;
            DOWN)   echo "input_down" ;;
            LEFT)   echo "input_left" ;;
            RIGHT)  echo "input_right" ;;
            *)      echo "" ;;
        esac
    }

    # Build RetroArch remap lines
    local retromap=""
    for btn in A B X Y L1 R1 L2 RT START SELECT UP DOWN LEFT RIGHT; do
        eval "physical=\$remap_$(echo "$btn" | tr 'A-Z' 'a-z')"
        [ -z "$physical" ] && continue

        local ra_name
        ra_name=$(ra_input_name "$btn")
        [ -z "$ra_name" ] && continue

        local ra_index
        ra_index=$(ra_button_index "$physical")
        [ "$ra_index" -ge 0 ] 2>/dev/null || continue

        retromap="${retromap}${ra_name} = \"joypad ${ra_index}\"\n"
    done

    if [ -n "$retromap" ]; then
        mkdir -p /tmp/jukamix_remap
        printf '%b' "$retromap" > /tmp/jukamix_remap/remap.cfg
        export RETROARCH_REMAP_FILE="/tmp/jukamix_remap/remap.cfg"
        echo "apply_remap: RetroArch remap written to $RETROARCH_REMAP_FILE"
    fi

    # For non-RetroArch emulators (DraStic, PPSSPP, etc.) — SDL override
    local sdl_map=""
    for pair in "A:$remap_a" "B:$remap_b" "X:$remap_x" "Y:$remap_y" \
                "leftshoulder:$remap_l" "rightshoulder:$remap_r" \
                "lefttrigger:$remap_lt" "righttrigger:$remap_rt" \
                "start:$remap_start" "back:$remap_select" \
                "dpup:$remap_up" "dpdown:$remap_down" \
                "dpleft:$remap_left" "dpright:$remap_right"; do
        local sdl_name="${pair%%:*}"
        local phys="${pair#*:}"
        [ -z "$phys" ] && continue

        local btn_num
        btn_num=$(ra_button_index "$phys")
        [ "$btn_num" -ge 0 ] 2>/dev/null || continue

        sdl_map="${sdl_map}${sdl_name}:b${btn_num},"
    done

    if [ -n "$sdl_map" ]; then
        printf ',00000000000000000000000000000000,JukaMix Remapped,platform:Linux,%s\n' "$sdl_map" \
            > /tmp/gamecontrollerdb.txt
        export SDL_GAMECONTROLLERCONFIG_FILE="/tmp/gamecontrollerdb.txt"
        echo "apply_remap: SDL override written"
    fi
}

# Auto-apply when sourced
apply_remap
