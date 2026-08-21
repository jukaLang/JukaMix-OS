#!/bin/sh

SAVE_FILE="/tmp/cpufreq_saved.conf"

[ -f "$SAVE_FILE" ] || {
    echo "No saved configuration found at $SAVE_FILE"
    exit 1
}

. "$SAVE_FILE"

echo "Restoring CPU settings:"
echo "  Governor: $GOVERNOR"
echo "  Min Frequency: $MIN_FREQ"
echo "  Max Frequency: $MAX_FREQ"
echo "  Active CPUs: $ACTIVE_CPUS"

# Restores active CPU
cpu_index=0
for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
    if [ "$cpu_index" -lt "$ACTIVE_CPUS" ]; then
        if [ -f "$cpu/online" ] && [ -w "$cpu/online" ]; then
            echo 1 > "$cpu/online" 2>/dev/null
        fi
    else
        if [ -f "$cpu/online" ] && [ -w "$cpu/online" ]; then
            echo 0 > "$cpu/online" 2>/dev/null
        fi
    fi
    cpu_index=$((cpu_index + 1))
done

# Apply CPU settings (with safeguards)
if [ -w /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    echo "$GOVERNOR" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null
fi

if [ -w /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq ] && [ -w /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq ]; then
    if [ "$MIN_FREQ" -gt "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null)" ]; then
        echo "$MAX_FREQ" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null
        echo "$MIN_FREQ" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq 2>/dev/null
    else
        echo "$MIN_FREQ" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq 2>/dev/null
        echo "$MAX_FREQ" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null
    fi
fi
