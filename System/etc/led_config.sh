#!/bin/sh
# System/etc/led_config.sh
# LED configuration script - runs at boot

# Check if LED animation is available
if [ ! -w "/sys/class/led_anim/effect_enable" ]; then
    # Try to fix permissions
    chmod a+w /sys/class/led_anim/* 2>/dev/null
fi

# Check if LED config file exists
CONFIG_FILE="/mnt/SDCARD/System/etc/led_config.json"

if [ -f "$CONFIG_FILE" ]; then
    # Read config and apply
    # Default: disable effects, set static color
    echo 0 > /sys/class/led_anim/effect_enable 2>/dev/null
else
    # Default LED state: effects disabled
    echo 0 > /sys/class/led_anim/effect_enable 2>/dev/null
fi
