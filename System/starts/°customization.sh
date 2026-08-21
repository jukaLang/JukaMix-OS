#!/bin/sh

# ── Safeguards ────────────────────────────────────────────────────────
# Ensure required directories exist
mkdir -p /tmp 2>/dev/null
mkdir -p /mnt/SDCARD/trimui 2>/dev/null
mkdir -p /mnt/SDCARD/System/etc 2>/dev/null

# Set PATH and LD_LIBRARY_PATH
PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:$PATH"
export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"

# ── System configuration ──────────────────────────────────────────────
system_json="/mnt/UDISK/system.json"
Current_Theme=$(/usr/trimui/bin/systemval theme 2>/dev/null || echo "/mnt/SDCARD/Themes/JukaMix - OS/")
Current_bg="$Current_Theme/skin/bg.png"
if [ ! -f "$Current_bg" ]; then
    Current_bg="/mnt/SDCARD/trimui/res/skin/transparent.png"
fi

################ JukaMix OS Version Splashscreen ################

# Get version with fallback
version="unknown"
if [ -f /mnt/SDCARD/System/usr/trimui/jukamix-version.txt ]; then
    version=$(cat /mnt/SDCARD/System/usr/trimui/jukamix-version.txt 2>/dev/null || echo "unknown")
fi

# Only show splash if not already running (prevent duplicate messages)
if [ ! -f /tmp/boot_splash_shown ]; then
    touch /tmp/boot_splash_shown 2>/dev/null
    /mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh -i "$Current_bg" -m "JukaMix OS v$version" -t 2 2>/dev/null
fi

################ JukaMix OS internal storage Customization ################
# Get firmware version with fallback
FW_patched_version=""
if [ -f /usr/trimui/jukamix-version.txt ]; then
    FW_patched_version=$(cat /usr/trimui/jukamix-version.txt 2>/dev/null || echo "")
fi

if [ "$version" != "$FW_patched_version" ]; then

    if [ -f "/usr/trimui/jukamix-version.txt" ]; then
        JukaMix_Update=1
    else
        JukaMix_Update=0
    fi

    Current_FW_Revision=$(grep 'DISTRIB_DESCRIPTION' /etc/openwrt_release | cut -d '.' -f 3)

    # Set boot flag to prevent inputd_switcher from killing MainUI
    touch /tmp/boot_in_progress
    /mnt/SDCARD/System/usr/trimui/scripts/inputd_switcher.sh
    rm -f /tmp/boot_in_progress

    # Removing duplicated app
    rm -rf /usr/trimui/apps/zformatter_fat32/

    # making some place in root fs
    rm -rf /usr/trimui/res/sound/bgm2.mp3
    swapoff -a
    rm -rf /swapfile
    mv /bin/busybox.bak /mnt/SDCARD/System/bin 2>/dev/null
    cp "/mnt/SDCARD/trimui/res/skin/bg.png" "/usr/trimui/res/skin/"

    # USB Storage app update
    rm "/usr/trimui/apps/usb_storage/"*.png
    cp "/mnt/SDCARD/System/resources/usb_storage/"* "/usr/trimui/apps/usb_storage/"

    # Disable Stock Music app
    mv /usr/trimui/apps/musicplayer/config.json /usr/trimui/apps/musicplayer/config_disabled.json

    # Disable Stock Reader app
    mv /usr/trimui/apps/bookreader/config.json /usr/trimui/apps/bookreader/config_disabled.json

    # add language files
    if [ ! -e "/usr/trimui/res/skin/pl.lang" ]; then
        cp "/mnt/SDCARD/trimui/res/lang/"*.lang "/usr/trimui/res/lang/"
        cp "/mnt/SDCARD/trimui/res/lang/"*.short "/usr/trimui/res/lang/"
        cp "/mnt/SDCARD/trimui/res/lang/"*.png "/usr/trimui/res/skin/"
    fi

    # custom shutdown script for "Resume at Boot"
    cp "/mnt/SDCARD/System/usr/trimui/bin/kill_apps.sh" "/usr/trimui/bin/kill_apps.sh"
    chmod a+x "/usr/trimui/bin/kill_apps.sh"

    # custom sshd initd script & disabled by default
    cp "/mnt/SDCARD/trimui/etc/init.d/sshd" /etc/init.d/sshd
    chmod a+x /etc/init.d/sshd
    /etc/init.d/sshd disable

    # fix retroarch path for PortMaster
    cp "/mnt/SDCARD/System/usr/trimui/bin/retroarch" "/usr/bin/retroarch"
    chmod a+x "/usr/bin/retroarch"

    # custom shutdown script, will be called by MainUI
    # cp "/mnt/SDCARD/System/bin/shutdown" "/usr/bin/poweroff"
    # chmod a+x "/usr/bin/poweroff"

    # modifying default theme to impact all other themes (Better game image background)
    # mv "/usr/trimui/res/skin/ic-game-580.png" "/usr/trimui/res/skin/ic-game-580_old.png"
    cp "/mnt/SDCARD/trimui/res/skin/ic-game-580.png" "/usr/trimui/res/skin/ic-game-580.png"

    # Fnkey app modifications
    JukaMixSourceDir="/mnt/SDCARD/System/usr/trimui/res/apps/fn_editor"
    FWappDir="/usr/trimui/apps/fn_editor"
    FWsceneDir="/usr/trimui/scene"

    # Ensure directories exist
    mkdir -p "$FWappDir" 2>/dev/null
    mkdir -p "$FWsceneDir" 2>/dev/null

    if [ -d "$JukaMixSourceDir" ]; then
        for src in "$JukaMixSourceDir"/*; do
            [ -f "$src" ] || continue  # Skip if not a file
            
            filename=$(basename "$src")
            app_dest="$FWappDir/$filename"
            scene_dest="$FWsceneDir/$filename"

            # Always copy to the apps directory
            if cp "$src" "$app_dest" 2>/dev/null; then
                chmod a+x "$app_dest" 2>/dev/null
            fi

            # Conditional copy to the scene directory
            if [ "$JukaMix_Update" = "1" ]; then
                if [ -f "$scene_dest" ]; then
                    if cp "$src" "$scene_dest" 2>/dev/null; then
                        chmod a+x "$scene_dest" 2>/dev/null
                    fi
                fi
            fi
        done
    fi

    # On fresh install, always set the default FN function to CPU performance
    if [ "$JukaMix_Update" != "1" ]; then
        src="$JukaMixSourceDir/com.trimui.cpuperformance.sh"
        dest="$FWsceneDir/com.trimui.cpuperformance.sh"
        if cp "$src" "$dest"; then
            echo "com.trimui.cpuperformance.sh copied to $FWsceneDir"
            chmod a+x "$dest"
        fi
    fi

    # Upgrade the stock OSD (with safeguard)
    if [ -d "/mnt/SDCARD/System/usr/trimui/res/osd" ]; then
        cp -a /mnt/SDCARD/System/usr/trimui/res/osd/. /usr/trimui/osd/ 2>/dev/null
        find /usr/trimui/osd/ -type f -name "*" -exec chmod a+x {} \; 2>/dev/null
    fi

    # Customize SSH sessions (with safeguard)
    if [ -f /etc/profile ] && ! grep -q "SSH_CONNECTION" /etc/profile 2>/dev/null; then
        printf '\n\n[ -n "$SSH_CONNECTION" ] || [ -n "$SSH_CLIENT" ] && . /mnt/SDCARD/System/usr/trimui/scripts/ssh_profile.sh\n' >>/etc/profile 2>/dev/null
    fi

    # fix potential bad asound configuration
    # sed -i -e 's/period_size 2048/period_size 1024/' -e 's/period_size 4096/period_size 1024/' -e '/buffer_size 16384/d' "/etc/asound.conf"

    # Apply default JukaMix OS theme, sound volume, and grid view
    if [ "$JukaMix_Update" = "0" ]; then
        if [ ! -f /mnt/UDISK/system.json ]; then
            cp /mnt/SDCARD/System/usr/trimui/scripts/MainUI_default_system.json /mnt/UDISK/system.json
        else
            /usr/trimui/bin/systemval theme "/mnt/SDCARD/Themes/JukaMix - OS/"
            /usr/trimui/bin/systemval menustylel1 1
            /usr/trimui/bin/systemval bgmvol 10
        fi
    fi

    if [ "$Current_Theme" = "../res/" ]; then
        /usr/trimui/bin/systemval theme "/mnt/SDCARD/Themes/JukaMix - OS/"
    fi

    # hide netplay tab in MainUI
    /usr/trimui/bin/systemval netplaytab 0

    # Fix app icons (with safeguard)
    if [ -x "/mnt/SDCARD/Apps/SystemTools/Menu/ADVANCED SETTINGS##APP ICONS (value)/Default.sh" ]; then
        "/mnt/SDCARD/Apps/SystemTools/Menu/ADVANCED SETTINGS##APP ICONS (value)/Default.sh" 2>/dev/null
    fi

    # modifying performance mode for Moonlight
    if ! grep -qF "performance" "/usr/trimui/apps/moonlight/launch.sh"; then
        sed -i 's|^\./moonlightui|echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor\necho 1608000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq\n\./moonlightui|' /usr/trimui/apps/moonlight/launch.sh
    fi

    # Restore FW settings
    if [ -f "/mnt/SDCARD/trimui/firmwares/Last_Automatic_Backup.txt" ]; then
        Last_Automatic_Backup=$(cat /mnt/SDCARD/trimui/firmwares/Last_Automatic_Backup.txt)
        if [ -f "/mnt/SDCARD/System/backups/firmware_settings/$current_device/$Last_Automatic_Backup" ]; then
            echo "Restoring firmware settings from $Last_Automatic_Backup"
            "/mnt/SDCARD/Apps/SystemTools/Menu/TOOLS/FW Settings Save-Load.sh" --restore "/mnt/SDCARD/System/backups/firmware_settings/$current_device/$Last_Automatic_Backup" joystick
            "/mnt/SDCARD/Apps/SystemTools/Menu/TOOLS/FW Settings Save-Load.sh" --restore "/mnt/SDCARD/System/backups/firmware_settings/$current_device/$Last_Automatic_Backup" wifi
        else
            echo "No automatic backup found for $Last_Automatic_Backup"
        fi
    fi

    # we set the customization flag
    rm "/usr/trimui/fw_mod_done"
    echo $version >/usr/trimui/jukamix-version.txt
    sync

    ################ JukaMix OS SD card Customization ################

    # Sorting Themes Alphabetically (with safeguard)
    if [ -x "/mnt/SDCARD/Apps/SystemTools/Menu/THEME/Sort Themes Alphabetically.sh" ]; then
        "/mnt/SDCARD/Apps/SystemTools/Menu/THEME/Sort Themes Alphabetically.sh" -s 2>/dev/null
    fi

    # Game tab by default (with safeguard)
    if [ "$JukaMix_Update" = "0" ]; then
        if [ -x "/mnt/SDCARD/Apps/SystemTools/Menu/USER INTERFACE##START TAB (value)/Tab Game.sh" ]; then
            "/mnt/SDCARD/Apps/SystemTools/Menu/USER INTERFACE##START TAB (value)/Tab Game.sh" -s 2>/dev/null
        fi
    fi

    # Displaying only Emulators with roms (with safeguard)
    if [ -x "/mnt/SDCARD/Apps/EmuCleaner/launch.sh" ]; then
        /mnt/SDCARD/Apps/EmuCleaner/launch.sh -s 2>/dev/null
    fi

    ################ Flash boot logo ################
    if [ "$JukaMix_Update" = "0" ]; then

        # Get device with fallback
        Current_device="tsp"  # Default
        if [ -f /etc/trimui_device.txt ]; then
            read -r Current_device < /etc/trimui_device.txt 2>/dev/null || Current_device="tsp"
        fi

        case "$Current_device" in
            tsp|tg5050)
                src_dir="/mnt/SDCARD/Apps/BootLogo/Images_1280x720"
                ;;
            *)
                src_dir="/mnt/SDCARD/Apps/BootLogo/Images_1024x768"
                ;;
        esac

        # Flash boot logo with safeguard
        if [ -x "/mnt/SDCARD/Emus/_BootLogo/launch.sh" ] && [ -f "$src_dir/- JukaMix-OS.bmp" ]; then
            "/mnt/SDCARD/Emus/_BootLogo/launch.sh" "$src_dir/- JukaMix-OS.bmp" 2>/dev/null
        fi
    fi
fi

######################### JukaMix OS at each boot #########################

# override empty password on firmware >= v1.1.1
echo "root:tina" | chpasswd 2>/dev/null

# Apply current led configuration (only if LED hardware exists)
if [ -d /sys/class/led_anim ] && [ -x "/mnt/SDCARD/System/etc/led_config.sh" ]; then
    /mnt/SDCARD/System/etc/led_config.sh &
fi

# Start deep sleep monitor (with delay to avoid boot conflicts)
if [ -x "/mnt/SDCARD/System/usr/trimui/scripts/deep_sleep.sh" ]; then
    # Check if deep sleep is enabled in config
    deep_sleep_enabled=1
    if [ -f "/mnt/SDCARD/System/etc/jukamix.json" ]; then
        if grep -q '"DEEP_SLEEP".*:.*"disabled"' "/mnt/SDCARD/System/etc/jukamix.json" 2>/dev/null; then
            deep_sleep_enabled=0
        fi
    fi
    if [ "$deep_sleep_enabled" -eq 1 ]; then
        sleep 5  # Delay to avoid boot conflicts
        /mnt/SDCARD/System/usr/trimui/scripts/deep_sleep.sh start &
    fi
fi

# Start battery monitor (with delay to avoid boot conflicts)
if [ -x "/mnt/SDCARD/System/usr/trimui/scripts/battery_monitor.sh" ]; then
    sleep 10  # Delay to avoid boot conflicts
    /mnt/SDCARD/System/usr/trimui/scripts/battery_monitor.sh record &
fi

# Check for autoresume (only if recent session exists)
if [ -x "/mnt/SDCARD/System/usr/trimui/scripts/autoresume.sh" ]; then
    # Only run if there's a recent session file
    if [ -f "/mnt/SDCARD/trimui/autosave/last_session.txt" ]; then
        session_time=$(grep "^timestamp=" "/mnt/SDCARD/trimui/autosave/last_session.txt" 2>/dev/null | cut -d= -f2)
        current_time=$(date +%s)
        if [ -n "$session_time" ]; then
            age=$((current_time - session_time))
            if [ "$age" -lt 300 ]; then  # Only if session is less than 5 minutes old
                /mnt/SDCARD/System/usr/trimui/scripts/autoresume.sh --background &
            fi
        fi
    fi
fi

hostname "TSP"
