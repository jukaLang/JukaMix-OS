#!/bin/bash
# batch_update_launchers.sh - Update all remaining launchers to device-aware CPU frequency
# Run from project root: bash scripts/batch_update_launchers.sh

set -e

# CPU frequency mapping per system type:
# LIGHT: 2->5 (tg5050) / 2->4 (tsp/brick) - 8-bit systems, simple emulation
# MEDIUM: 2->6 (tg5050) / 2->5 (tsp/brick) - 16-bit, moderate emulation
# HEAVY: 3->7 (tg5050) / 3->6 (tsp/brick) - CD-based, more demanding
# PERFORMANCE: 4->8 (tg5050) / 4->7 (tsp/brick) - demanding systems
# MAX: 5->9 (tg5050) / 5->8 (tsp/brick) - very demanding

declare -A SYS_WEIGHT=(
  # Light (8-bit, simple)
  ["ATARI2600"]="LIGHT"
  ["ATARI5200"]="LIGHT"
  ["ATARI7800"]="LIGHT"
  ["CHANNELF"]="LIGHT"
  ["COLECO"]="LIGHT"
  ["GW"]="LIGHT"
  ["INTELLIVISION"]="LIGHT"
  ["LYNX"]="LIGHT"
  ["MEGADUCK"]="LIGHT"
  ["NGP"]="LIGHT"
  ["POKEMINI"]="LIGHT"
  ["SG1000"]="LIGHT"
  ["SUPERVISION"]="LIGHT"
  ["VECTREX"]="LIGHT"
  ["WSC"]="LIGHT"
  ["ZXS"]="LIGHT"

  # Medium (16-bit, cartridge-based)
  ["C64"]="MEDIUM"
  ["FC"]="MEDIUM"
  ["FDS"]="MEDIUM"
  ["GB"]="MEDIUM"
  ["GBC"]="MEDIUM"
  ["GENESIS"]="MEDIUM"
  ["GG"]="MEDIUM"
  ["MD"]="MEDIUM"
  ["MS"]="MEDIUM"
  ["MSX"]="MEDIUM"
  ["MSX2"]="MEDIUM"
  ["NES"]="MEDIUM"
  ["NES"]="MEDIUM"
  ["PCE"]="MEDIUM"
  ["PCFX"]="MEDIUM"
  ["SFC"]="MEDIUM"
  ["SGB"]="MEDIUM"
  ["SUFAMI"]="MEDIUM"
  ["TIC"]="MEDIUM"

  # Heavy (CD-based, more demanding)
  ["AMIGA"]="HEAVY"
  ["AMIGACD"]="HEAVY"
  ["CPS1"]="HEAVY"
  ["CPS2"]="HEAVY"
  ["CPS3"]="HEAVY"
  ["DAPHNE"]="HEAVY"
  ["NEOCD"]="HEAVY"
  ["NEOGEO"]="HEAVY"
  ["PCECD"]="HEAVY"
  ["SEGACD"]="HEAVY"
  ["SEGA32X"]="HEAVY"
  ["SATURN"]="HEAVY"
  ["WS"]="HEAVY"

  # Performance (demanding 3D/emulation)
  ["DC"]="PERFORMANCE"
  ["FBNEO"]="PERFORMANCE"
  ["GBA"]="PERFORMANCE"
  ["MAME"]="PERFORMANCE"
  ["MAME2003PLUS"]="PERFORMANCE"
  ["MAME2010"]="PERFORMANCE"
  ["N64"]="PERFORMANCE"
  ["NDS"]="PERFORMANCE"
  ["PS"]="PERFORMANCE"
  ["PSP"]="PERFORMANCE"
  ["ATOMISWAVE"]="PERFORMANCE"
  ["NAOMI"]="PERFORMANCE"
)

get_freq() {
  local weight=$1
  local device=$2
  case "$weight" in
    LIGHT)
      case "$device" in
        tg5050) echo "2 5" ;;
        *)      echo "2 4" ;;
      esac ;;
    MEDIUM)
      case "$device" in
        tg5050) echo "2 6" ;;
        *)      echo "2 5" ;;
      esac ;;
    HEAVY)
      case "$device" in
        tg5050) echo "2 7" ;;
        *)      echo "2 6" ;;
      esac ;;
    PERFORMANCE)
      case "$device" in
        tg5050) echo "3 8" ;;
        *)      echo "3 7" ;;
      esac ;;
    *)
      case "$device" in
        tg5050) echo "2 6" ;;
        *)      echo "2 5" ;;
      esac ;;
  esac
}

count=0
for f in $(find Emus -name "*.sh" -type f ! -name "default.sh" ! -name "effect.sh" ! -name "load_launcher.sh" | sort); do
  # Skip if already updated
  if grep -q "JUKAMIX_DEVICE_OPTIMIZED" "$f" 2>/dev/null; then
    continue
  fi
  # Skip non-RetroArch launchers
  if ! grep -q "ra64.trimui\|retroarch" "$f" 2>/dev/null; then
    continue
  fi

  sys=$(echo "$f" | sed 's|Emus/\([^/]*\)/.*|\1|')
  weight="${SYS_WEIGHT[$sys]:-MEDIUM}"

  # Get the core name
  core=$(grep -o '[^/]*_libretro\.so' "$f" | head -1 | sed 's/_libretro\.so//')
  if [ -z "$core" ]; then
    continue
  fi

  # Generate new content
  newcontent="#!/bin/sh\n"
  # Add comment with core name
  newcontent+="# ${sys}: ${core}\n"
  newcontent+=". /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh\n"
  newcontent+="\n"
  newcontent+="if [ \"\$JUKAMIX_DEVICE_OPTIMIZED\" = \"tg5050\" ]; then\n"

  read tg_min tg_max <<< "$(get_freq "$weight" "tg5050")"
  read tsp_min tsp_max <<< "$(get_freq "$weight" "tsp")"

  newcontent+="    cpufreq.sh ondemand ${tg_min} ${tg_max}\n"
  newcontent+="else\n"
  newcontent+="    cpufreq.sh ondemand ${tsp_min} ${tsp_max}\n"
  newcontent+="fi\n"
  newcontent+="\n"
  newcontent+='cd "$RA_DIR/"'
  newcontent+="\n"
  newcontent+='\nHOME="$RA_DIR"/ "$RA_DIR"/ra64.trimui -v -L "$RA_DIR"/.retroarch/cores/'"${core}"'_libretro.so "$@"'
  newcontent+="\n"

  echo -n "$newcontent" > "$f"
  count=$((count + 1))
  echo "Updated: $f ($weight: tg5050=${tg_max}tsp=${tsp_max})"
done

echo ""
echo "Updated $count launcher scripts"