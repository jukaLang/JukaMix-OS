#!/bin/sh
# retroarch_version.sh - Select RetroArch version based on device and config
#
# Source this in launchers to get the correct RetroArch binary path:
#   . /mnt/SDCARD/System/usr/trimui/scripts/retroarch_version.sh
#   # Now $RA_BIN contains the path to the selected RetroArch binary
#
# Configuration:
#   /mnt/SDCARD/System/usr/trimui/retroarch_version.conf
#   Contains the preferred version (e.g., "1.22.2" or "default")

RA_BASE="/mnt/SDCARD/RetroArch"
RA_VERSION_CONF="$RA_BASE/../System/usr/trimui/retroarch_version.conf"

# Get device code
DEVICE_CODE="unknown"
if [ -r /etc/trimui_device.txt ]; then
    DEVICE_CODE=$(tr -d '[:space:]' < /etc/trimui_device.txt 2>/dev/null | head -n 1)
fi

# Read configured version (if any)
CONFIGURED_VERSION=""
if [ -f "$RA_VERSION_CONF" ]; then
    CONFIGURED_VERSION=$(cat "$RA_VERSION_CONF" 2>/dev/null | tr -d '[:space:]')
fi

# Select RetroArch binary
select_ra_version() {
    # If a specific version is configured, try to use it
    if [ -n "$CONFIGURED_VERSION" ] && [ "$CONFIGURED_VERSION" != "default" ]; then
        local candidate="$RA_BASE/ra64.trimui-${CONFIGURED_VERSION}/ra64.trimui"
        if [ -x "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    fi

    # Device-specific defaults
    case "$DEVICE_CODE" in
        tg5050)
            # TG5050: Use latest available
            for ver in 1.22.2 1.20.0 1.18.0 1.17.0 1.15.0; do
                local candidate="$RA_BASE/ra64.trimui-${ver}/ra64.trimui"
                if [ -x "$candidate" ]; then
                    echo "$candidate"
                    return 0
                fi
            done
            ;;
        tsp|brick|brick_pro|brickpro)
            # TSP/Brick/Brick Pro: Use 1.22.2 if available, fallback to default
            for ver in 1.22.2 1.20.0 1.18.0; do
                local candidate="$RA_BASE/ra64.trimui-${ver}/ra64.trimui"
                if [ -x "$candidate" ]; then
                    echo "$candidate"
                    return 0
                fi
            done
            ;;
    esac

    # Fallback to default binary
    echo "$RA_BASE/ra64.trimui"
}

# Export the selected binary path
RA_BIN=$(select_ra_version)
export RA_BIN

# For backward compatibility, also set RA_DIR
RA_DIR="$RA_BASE"
export RA_DIR

# Debug output (uncomment for troubleshooting)
# echo "retroarch_version: device=$DEVICE_CODE config=$CONFIGURED_VERSION bin=$RA_BIN"
