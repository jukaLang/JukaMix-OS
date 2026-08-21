#!/bin/sh
# Device detection script for JukaMix OS
# Detects the current device and applies device-specific optimizations

# Read the current device. Trim surrounding whitespace/CR so a stray CRLF
# (e.g. from a hand-edited file) can never break the tg5050 comparison below.
CURRENT_DEVICE=$(tr -d '[:space:]' < /etc/trimui_device.txt 2>/dev/null | head -n 1)

# Export device-specific variables
export DEVICE_CODE="$CURRENT_DEVICE"

case "$CURRENT_DEVICE" in
    tsp)
        export DEVICE_NAME="TrimUI Smart Pro"
        export DEVICE_SOC="Allwinner A133 Plus"
        export DEVICE_PERFORMANCE_TIER="standard"
        ;;
    tg5050)
        export DEVICE_NAME="TrimUI Smart Pro S"
        export DEVICE_SOC="Allwinner A523"
        export DEVICE_PERFORMANCE_TIER="high"
        ;;
    brick)
        export DEVICE_NAME="TrimUI Brick"
        export DEVICE_SOC="Allwinner A133 Plus"
        export DEVICE_PERFORMANCE_TIER="low"
        ;;
    brick_pro|brickpro)
        export DEVICE_NAME="TrimUI Brick Pro"
        export DEVICE_SOC="Allwinner A133 Plus"
        export DEVICE_PERFORMANCE_TIER="standard"
        ;;
    *)
        export DEVICE_NAME="Unknown"
        export DEVICE_SOC="Unknown"
        export DEVICE_PERFORMANCE_TIER="standard"
        ;;
esac

# Function to check if running on TG5050
is_tg5050() {
    [ "$CURRENT_DEVICE" = "tg5050" ]
}

# Function to check if running on Brick Pro
is_brick_pro() {
    [ "$CURRENT_DEVICE" = "brick_pro" ] || [ "$CURRENT_DEVICE" = "brickpro" ]
}

# Function to check if running on high-performance device
is_high_performance() {
    [ "$DEVICE_PERFORMANCE_TIER" = "high" ]
}

# Function to check if running on standard-performance device
is_standard_performance() {
    [ "$DEVICE_PERFORMANCE_TIER" = "standard" ]
}

# Function to check if running on low-performance device
is_low_performance() {
    [ "$DEVICE_PERFORMANCE_TIER" = "low" ]
}
