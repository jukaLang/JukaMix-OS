#!/bin/sh
# JukaMix OS - PortMaster app launcher.
#
# Runs the bundled PortMaster GUI. Self-heals the install (exec bits, missing
# pugwash, Data/ports dir, Roms/PORTS entry point) so PortMaster keeps working
# however it was copied onto the SD card.

controlfolder="/mnt/SDCARD/Apps/PortMaster/PortMaster"

. /mnt/SDCARD/System/etc/ex_config

ESUDO=""
ESUDOKILL="-1" # for 351Elec and EmuELEC use "-1" (numeric one) or "-k"
export SDL_GAMECONTROLLERCONFIG_FILE="/$controlfolder/gamecontrollerdb.txt"
# export SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "/usr/lib/gamecontrollerdb.txt")

## TODO: Change to PortMaster/tty when Johnnyonflame merges the changes in,
CUR_TTY=/dev/tty0

cd "$controlfolder" 2>/dev/null || {
    echo "PortMaster directory missing: $controlfolder" >&2
    exit 1
}

# Quietly drop macOS AppleDouble junk (no glob-error noise when nothing matches).
find . -name '._*' -type f -delete 2>/dev/null

# Self-heal the install: make every bundled script/binary executable so the
# app works no matter how it was copied onto the SD card.
chmod -R +x . 2>/dev/null

# If the PortMaster GUI binary is missing, try a repair before giving up.
if [ ! -x ./pugwash ]; then
    echo "pugwash missing - attempting repair ..." >&2
    if [ -x /mnt/SDCARD/System/usr/jukamix/bin/jm-portmaster ]; then
        /mnt/SDCARD/System/usr/jukamix/bin/jm-portmaster fix >/dev/null 2>&1
    fi
    if [ ! -x ./pugwash ]; then
        echo "PortMaster is broken or incomplete. Reinstall it:" >&2
        echo "  jm-portmaster install   (online) or" >&2
        echo "  jm-portmaster install --from-zip <file.zip>   (offline)" >&2
        exit 1
    fi
fi

exec > >(tee "$controlfolder/log.txt") 2>&1

export TERM=linux
chmod 666 $CUR_TTY 2>/dev/null
printf "\033c" > $CUR_TTY

sdl2imgshow \
    -i "$EX_RESOURCE_PATH/background.png" \
    -f "$EX_RESOURCE_PATH/DejaVuSans.ttf" \
    -s 48 \
    -c "0,0,0" \
    -t "Starting PortMaster" &

sleep 0.5
pkill -f sdl2imgshow

# First-run migration (creates Data/ports etc.). It is a bash script; do not
# run it with sh. Failure is non-fatal - the GUI still starts.
if [ -f "$controlfolder/trimui/update.txt" ]; then
    command -v bash >/dev/null 2>&1 && bash "$controlfolder/trimui/update.txt" || sh "$controlfolder/trimui/update.txt"
fi

# Make sure the OS Ports section and its PortMaster entry point exist.
mkdir -p /mnt/SDCARD/Data/ports 2>/dev/null
if [ -x /mnt/SDCARD/System/usr/jukamix/bin/jm-portmaster ]; then
    /mnt/SDCARD/System/usr/jukamix/bin/jm-portmaster fix >/dev/null 2>&1
fi

## Autoinstallation Code
# This will automatically install zips found within the PortMaster/autoinstall directory using harbourmaster
AUTOINSTALL=$(find "$controlfolder/autoinstall" -type f \( -name "*.zip" -o -name "*.squashfs" \) 2>/dev/null)
if [ -n "$AUTOINSTALL" ]; then
  . "$controlfolder/PortMasterDialog.txt"

  GW=$(PortMasterIPCheck)
  PortMasterDialogInit "no-check"

  PortMasterDialog "messages_begin"

  PortMasterDialog "message" "Auto-installation"

  # Install the latest runtimes.zip
  if [ -f "$controlfolder/autoinstall/runtimes.zip" ]; then
    PortMasterDialog "message" "- Installing runtimes.zip, this could take a minute or two."
    $ESUDO unzip -o "$controlfolder/autoinstall/runtimes.zip" -d "$controlfolder/libs"
    $ESUDO rm -f "$controlfolder/autoinstall/runtimes.zip"
    PortMasterDialog "message" "- SUCCESS: runtimes.zip"
  fi

  for file_name in "$controlfolder/autoinstall"/*.squashfs
  do
    $ESUDO mv -f "$file_name" "$controlfolder/libs"
    PortMasterDialog "message" "- SUCCESS: $(basename $file_name)"
  done

  for file_name in "$controlfolder/autoinstall"/*.zip
  do
    if [ "$(basename $file_name)" = "PortMaster.zip" ]; then
      continue
    fi

    if [ "$(PortMasterDialogResult "install" "$file_name")" = "OKAY" ]; then
      $ESUDO rm -f "$file_name"
      PortMasterDialog "message" "- SUCCESS: $(basename $file_name)"
    else
      PortMasterDialog "message" "- FAILURE: $(basename $file_name)"
    fi
  done

  if [ -f "$controlfolder/autoinstall/PortMaster.zip" ]; then
    file_name="$controlfolder/autoinstall/PortMaster.zip"

    if [ "$(PortMasterDialogResult "install" "$file_name")" = "OKAY" ]; then
      $ESUDO rm -f "$file_name"
      PortMasterDialog "message" "- SUCCESS: $(basename $file_name)"
    else
      PortMasterDialog "message" "- FAILURE: $(basename $file_name)"
    fi
  fi

  touch "$controlfolder/.trimui-refresh"

  PortMasterDialog "messages_end"
  if [ -z "$GW" ]; then
    PortMasterDialogMessageBox "Finished running autoinstall.\n\nNo internet connection present so exiting."
    PortMasterDialogExit
    exit 0
  else
    PortMasterDialogMessageBox "Finished running autoinstall."
    PortMasterDialogExit
  fi
fi

export PYSDL2_DLL_PATH="/usr/trimui/lib"

echo "Starting PortMaster." > $CUR_TTY

rm -f "$controlfolder/.pugwash-reboot"

while true; do
  ./pugwash --debug

  if [ ! -f "$controlfolder/.pugwash-reboot" ]; then
    break;
  fi

  rm -f "$controlfolder/.pugwash-reboot"
done

if [ -f "$controlfolder/.trimui-refresh" ]; then
  rm -f "$controlfolder/.trimui-refresh"
  # HULK SMASH

  "$controlfolder"/trimui/image_smash.txt
fi

unset LD_LIBRARY_PATH
unset SDL_GAMECONTROLLERCONFIG
