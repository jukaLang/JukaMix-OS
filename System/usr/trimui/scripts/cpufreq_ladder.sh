#!/bin/sh
# cpufreq_ladder.sh - Single source of truth for the Allwinner CPU
# frequency ladder used by every cpufreq helper on JukaMix OS.
#
# Source this from a launcher or helper, then call:
#
#   min_hz=$(cpufreq_id_to_hz 2)        # -> 816000
#   max_id=$(cpufreq_hz_to_id 2000000)  # -> 8
#   max_id=$(cpufreq_clamp "$max_id")   # -> 8 on A133, 10 on A523
#
# Ladder rationale (Allwinner A133 / A523 OPP table):
#   id  0 =   408000 kHz   base (deep idle, all SoCs)
#   id  1 =   600000 kHz   entry perf
#   id  2 =   816000 kHz   interactive floor (JukaMix default)
#   id  3 =  1008000 kHz
#   id  4 =  1200000 kHz
#   id  5 =  1416000 kHz
#   id  6 =  1608000 kHz   Brick recommended ceiling (A133)
#   id  7 =  1800000 kHz   Smart Pro recommended ceiling (A133)
#   id  8 =  2000000 kHz   Smart Pro S (A523) recommended ceiling, A133 max
#   id  9 =  2200000 kHz   A523 only - gated by cpufreq_max_id
#   id 10 =  2400000 kHz   A523 only - gated by cpufreq_max_id
#
# The shared ladder means cpufreq.sh, tsp_cpufreq.sh, tg5050_cpufreq.sh,
# cpufreq_default.sh and any launcher can all agree on id <-> Hz conversion
# without three near-identical case statements drifting apart.
#
# POSIX sh (BusyBox ash / dash). No bashisms.

# Guard against accidental double-sourcing.
[ -n "${JUKAMIX_CPUFREQ_LADDER_LOADED:-}" ] && return 0
JUKAMIX_CPUFREQ_LADDER_LOADED=1

# Map a ladder id (0-10) to its frequency in kHz. Echoes empty string on
# out-of-range input so callers can detect typos without aborting.
cpufreq_id_to_hz() {
	case $1 in
		0)  echo 408000  ;;
		1)  echo 600000  ;;
		2)  echo 816000  ;;
		3)  echo 1008000 ;;
		4)  echo 1200000 ;;
		5)  echo 1416000 ;;
		6)  echo 1608000 ;;
		7)  echo 1800000 ;;
		8)  echo 2000000 ;;
		9)  echo 2200000 ;;
		10) echo 2400000 ;;
		*)  echo ""      ;;
	esac
}

# Inverse map: kHz -> ladder id. Echoes empty on a frequency that is not on
# the OPP table (e.g. an unusual scaling_cur_freq from userspace tweaks).
cpufreq_hz_to_id() {
	case $1 in
		408000)  echo 0  ;;
		600000)  echo 1  ;;
		816000)  echo 2  ;;
		1008000) echo 3  ;;
		1200000) echo 4  ;;
		1416000) echo 5  ;;
		1608000) echo 6  ;;
		1800000) echo 7  ;;
		2000000) echo 8  ;;
		2200000) echo 9  ;;
		2400000) echo 10 ;;
		*)       echo "" ;;
	esac
}

# Resolve the highest ladder id the running kernel actually exposes. The
# OPP table is the authoritative source: cpuinfo_max_freq is read-only, so
# even if a previous tuning call lowered scaling_max_freq the ceiling
# remains correct. scaling_max_freq is the degraded fallback for kernels
# where cpuinfo_max_freq is missing. When neither is readable (early boot,
# off-device test environments) the device code is consulted last; tg5050
# (A523) gains ids 9/10, everything else tops out at id 8.
cpufreq_max_id() {
	_cfg=/sys/devices/system/cpu/cpu0/cpufreq
	_hw_max=$(cat "$_cfg/cpuinfo_max_freq" 2>/dev/null)
	_id=$(cpufreq_hz_to_id "$_hw_max")
	if [ -z "$_id" ]; then
		_hw_max=$(cat "$_cfg/scaling_max_freq" 2>/dev/null)
		_id=$(cpufreq_hz_to_id "$_hw_max")
	fi
	[ -n "$_id" ] && { echo "$_id"; unset _cfg _hw_max _id; return 0; }
	if [ -r /etc/trimui_device.txt ]; then
		_dev=$(tr -d '[:space:]' < /etc/trimui_device.txt)
		case "$_dev" in
			tg5050) echo 10 ;;
			*)      echo 8  ;;
		esac
		unset _dev
	else
		echo 8
	fi
	unset _cfg _hw_max _id
}

# Clamp an id to the [0, MAX_ID] range, where MAX_ID is the highest id
# supported by the running hardware. Negative or non-numeric inputs collapse
# to 0; inputs above MAX_ID collapse to MAX_ID. Use this any time you accept
# a user-supplied id so a typo (e.g. "9" on an A133, or the literal "--"
# from a separator-style call) cannot reject the whole call.
cpufreq_clamp() {
	_id=$1
	_max=$(cpufreq_max_id)
	# POSIX [ ... -lt ... ] aborts the whole script on a non-integer, so
	# guard the comparison explicitly. Anything that is not a non-negative
	# decimal integer falls back to 0.
	case "$_id" in
		''|*[!0-9]*) _id=0 ;;
	esac
	[ "$_id" -gt "$_max" ] && _id=$_max
	echo "$_id"
	unset _id _max
}
