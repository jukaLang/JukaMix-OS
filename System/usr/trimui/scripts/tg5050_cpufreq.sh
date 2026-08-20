#!/bin/sh
# tg5050_cpufreq.sh - Thin compatibility shim for the Allwinner A523 (Smart Pro S).
#
# Historically this file carried its own copy of the id<->Hz ladder, its own
# validation, and its own sysfs writes. cpufreq.sh now owns all of that in a
# single place; the A523 ladder's extra ids (9 = 2200000 kHz, 10 = 2400000 kHz)
# are exposed automatically when the running kernel's OPP table advertises
# them, so this wrapper simply forwards its arguments. Existing callers keep
# working unchanged; new code should call cpufreq.sh directly.
#
# POSIX sh (BusyBox ash / dash). No bashisms.

_HERE=$(cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || _HERE=/mnt/SDCARD/System/usr/trimui/scripts
exec sh "$_HERE/cpufreq.sh" "$@"
