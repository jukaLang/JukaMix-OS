#!/bin/sh
# tsp_cpufreq.sh - Thin compatibility shim for the Allwinner A133 (Smart Pro).
#
# Historically this file carried its own copy of the id<->Hz ladder, its own
# validation, and its own sysfs writes. cpufreq.sh now owns all of that in a
# single place and clamps user-supplied ids to the running kernel's ceiling,
# so this wrapper simply forwards its arguments. Existing callers keep
# working unchanged; new code should call cpufreq.sh directly.
#
# POSIX sh (BusyBox ash / dash). No bashisms.

_HERE=$(cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || _HERE=/mnt/SDCARD/System/usr/trimui/scripts
exec sh "$_HERE/cpufreq.sh" "$@"
