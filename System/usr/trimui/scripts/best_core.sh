#!/bin/sh
# System/usr/trimui/scripts/best_core.sh
# Auto-detect best RetroArch core for a given ROM

CORES_DIR="/mnt/SDCARD/RetroArch/.retroarch/cores"
INFO_DIR="$CORES_DIR"

# ── Get system from ROM extension ──────────────────────────────────────
get_system() {
    local rom="$1"
    local ext="${rom##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    
    case "$ext" in
        nes|fds|unf|unif)           echo "nes" ;;
        smc|sfc|fig|swc)            echo "snes" ;;
        gb|gbc|sgb)                 echo "gb" ;;
        gba|agb|bin)                echo "gba" ;;
        nds|nds\.rz)                echo "nds" ;;
        gen|md|bin|sms|gg|sg)       echo "genesis" ;;
        pce)                        echo "pce" ;;
        ngp|ngc)                    echo "ngp" ;;
        ws|wsc)                     echo "wswan" ;;
        lynx)                       echo "lynx" ;;
        col|col\.gz)                echo "colecovision" ;;
        integ)                      echo "intellivision" ;;
        2600)                       echo "atari2600" ;;
        a52|a78)                    echo "atari7800" ;;
        z64|n64|v64|j64)            echo "n64" ;;
        iso|bin|cue|cbn|exe|pbp)    echo "psx" ;;
        elf|prg)                    echo "c64" ;;
        *)                          echo "unknown" ;;
    esac
}

# ── Get best core for system ───────────────────────────────────────────
get_best_core() {
    local system="$1"
    local device="${2:-tsp}"
    
    case "$system" in
        nes)
            echo "nestopia_libretro.so"
            ;;
        snes)
            echo "snes9x_libretro.so"
            ;;
        gb|gbc)
            echo "gambatte_libretro.so"
            ;;
        gba)
            echo "mgba_libretro.so"
            ;;
        nds)
            echo "melonDS_libretro.so"
            ;;
        genesis|megadrive)
            echo "genesis_plus_gx_libretro.so"
            ;;
        n64)
            if [ "$device" = "tg5050" ]; then
                echo "mupen64plus_next_libretro.so"
            else
                echo "mupen64plus_libretro.so"
            fi
            ;;
        psx)
            echo "pcsx_rearmed_libretro.so"
            ;;
        pce)
            echo "mednafen_pce_fast_libretro.so"
            ;;
        ngp)
            echo "mednafen_ngp_libretro.so"
            ;;
        wswan)
            echo "mednafen_wswan_libretro.so"
            ;;
        lynx)
            echo "mednafen_lynx_libretro.so"
            ;;
        colecovision)
            echo "coleco_libretro.so"
            ;;
        intellivision)
            echo "freeintv_libretro.so"
            ;;
        atari2600)
            echo "stella_libretro.so"
            ;;
        atari7800)
            echo "prosystem_libretro.so"
            ;;
        c64)
            echo "vice_x64_libretro.so"
            ;;
        *)
            echo ""
            ;;
    esac
}

# ── Check if core exists ───────────────────────────────────────────────
core_exists() {
    local core="$1"
    [ -f "$CORES_DIR/$core" ]
}

# ── List cores for system ──────────────────────────────────────────────
list_cores() {
    local system="$1"
    
    echo "Available cores for $system:"
    echo ""
    
    for info_file in "$INFO_DIR"/*.info; do
        [ -f "$info_file" ] || continue
        
        local supported=$(grep -i "supported_extensions" "$info_file" | head -1)
        
        case "$system" in
            nes)
                echo "$supported" | grep -qi "nes\|fds" && echo "  $(basename "$info_file" .info)"
                ;;
            snes)
                echo "$supported" | grep -qi "smc\|sfc\|fig" && echo "  $(basename "$info_file" .info)"
                ;;
            gb)
                echo "$supported" | grep -qi "\.gb\|\.gbc" && echo "  $(basename "$info_file" .info)"
                ;;
            gba)
                echo "$supported" | grep -qi "gba\|agb" && echo "  $(basename "$info_file" .info)"
                ;;
            nds)
                echo "$supported" | grep -qi "nds" && echo "  $(basename "$info_file" .info)"
                ;;
            genesis)
                echo "$supported" | grep -qi "gen\|md\|bin" && echo "  $(basename "$info_file" .info)"
                ;;
            n64)
                echo "$supported" | grep -qi "n64\|z64\|v64" && echo "  $(basename "$info_file" .info)"
                ;;
            psx)
                echo "$supported" | grep -qi "iso\|bin\|cue\|pbp" && echo "  $(basename "$info_file" .info)"
                ;;
        esac
    done
}

# ── Main ──────────────────────────────────────────────────────────────
case "${1:-}" in
    detect|get)
        local system=$(get_system "$2")
        local device="${3:-tsp}"
        local core=$(get_best_core "$system" "$device")
        
        if [ -n "$core" ] && core_exists "$core"; then
            echo "$core"
        else
            echo ""
        fi
        ;;
    system)
        get_system "$2"
        ;;
    list)
        list_cores "$2"
        ;;
    *)
        echo "Usage: best_core.sh {detect|system|list} [rom_path] [device]" >&2
        echo "" >&2
        echo "Commands:" >&2
        echo "  detect <rom> [device]  - Get best core for ROM" >&2
        echo "  system <rom>           - Get system from ROM extension" >&2
        echo "  list <system>          - List available cores" >&2
        exit 1
        ;;
esac
