#!/bin/ash
# cpufreq.sh - JukaMix OS unified CPU frequency helper.
#
# Usage:
#   cpufreq.sh [governor] [min_id] [max_id] [active_cores]
#   cpufreq.sh                                    # show current state + examples
#
# The base ladder (ids 0-8) is identical on every supported device (TSP /
# Smart Pro / Brick run Allwinner A133 Plus; the Smart Pro S / tg5050 runs
# Allwinner A523). The A523 adds ids 9 (2200000 kHz) and 10 (2400000 kHz);
# the shared cpufreq_ladder.sh exposes them only when the running kernel
# actually advertises them. Launchers written for the A523 therefore apply
# the closest valid setting on the A133 instead of failing.
#
# This script sources cpufreq_ladder.sh so the id<->Hz mapping lives in
# exactly one place (tsp_cpufreq.sh and tg5050_cpufreq.sh both delegate
# here).

# Resolve the script's own directory so the ladder library is found whether
# the helper is on PATH or invoked via absolute path.
_HERE=$(cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || _HERE=/mnt/SDCARD/System/usr/trimui/scripts
. "$_HERE/cpufreq_ladder.sh" 2>/dev/null || . /mnt/SDCARD/System/usr/trimui/scripts/cpufreq_ladder.sh
unset _HERE

governor="$1"
min_id="$2"
max_id="$3"
active_cores="$4"

MAX_ID=$(cpufreq_max_id)

# Display current CPU settings and usage examples.
show_info() {
	read current_governor </sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
	read current_min_freq </sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
	read current_max_freq </sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq

	_min_id=$(cpufreq_hz_to_id "$current_min_freq")
	_max_id=$(cpufreq_hz_to_id "$current_max_freq")

	# Use the kernel's authoritative CPU list rather than a hardcoded glob
	# so the same code works on the A133 (4 cores), the A523 (4 cores) and
	# any future SoC with a different topology. `cpu[0-9]*` is brittle: it
	# silently misses cpu10+ and accidentally matches files like cpuidle.
	_num_cores=$(ls -d /sys/devices/system/cpu/cpu[0-9]* 2>/dev/null \
		| awk -F/ '{print $(NF-1)}' | awk '$1 ~ /^cpu[0-9]+$/{print}' | wc -l)
	_active=0
	for _f in /sys/devices/system/cpu/cpu[0-9]*/online; do
		[ -r "$_f" ] || continue
		[ "$(cat "$_f" 2>/dev/null)" = "1" ] && _active=$((_active + 1))
	done

	cat <<-EOF
		========================================================================
		Usage examples:
		---------------
		  cpufreq.sh performance 3 7    # governor=performance, max=1800000 kHz
		  cpufreq.sh ondemand 1 5       # governor=ondemand, range 600000-1416000 kHz
		  cpufreq.sh ondemand 1 5 2     # as above, only 2 cores enabled
		  cpufreq.sh powersave 0 2      # governor=powersave, range 408000-816000 kHz
		========================================================================
		Current CPU settings:
		---------------------
		  Governor:     $current_governor
		  Min Frequency: $(printf '%s' "${_min_id:-?}" | sed 's/^$/?/' ) = ${current_min_freq} kHz
		  Max Frequency: $(printf '%s' "${_max_id:-?}" | sed 's/^$/?/' ) = ${current_max_freq} kHz
		  Active Cores:  $_active / $_num_cores
		  Hardware Max:  id $MAX_ID ($(cpufreq_id_to_hz "$MAX_ID") kHz)
		========================================================================
	EOF
	unset _min_id _max_id _num_cores _active _f
}

# Without arguments, display current CPU settings and examples.
if [ -z "$governor" ]; then
	show_info
	exit 0
fi

# Validate governor. A case match keeps the check declarative and avoids
# the long if-elif chain that previously had to grow with every new governor.
case "$governor" in
	interactive|ondemand|performance|powersave|conservative|schedutil) ;;
	*)
		echo "cpufreq.sh: Invalid governor '$governor'." >&2
		exit 1
		;;
esac

# Validate min_id / max_id ranges. MAX_ID is the kernel-reported ceiling;
# values above it are clamped (not rejected) so an A523-tuned launcher still
# runs correctly on A133 hardware.
case "$min_id" in
	''|*[!0-9]*)
		echo "cpufreq.sh: Invalid min frequency ID '$min_id'." >&2
		exit 1
		;;
esac
case "$max_id" in
	''|*[!0-9]*)
		echo "cpufreq.sh: Invalid max frequency ID '$max_id'." >&2
		exit 1
		;;
esac

# Clamp instead of rejecting so an A523 (tg5050, ids 0-10) launcher can
# run unchanged on the A133 (TSP/Brick, ids 0-8); the closest valid id is
# what we tune to. Without this the same launch line would 1+ devices out.
min_id=$(cpufreq_clamp "$min_id")
max_id=$(cpufreq_clamp "$max_id")
[ "$min_id" -gt "$max_id" ] && min_id=$max_id

# Validate core count if provided. Use the kernel-discovered total rather
# than a hardcoded "4" so future 8-core SoCs don't reject valid requests.
if [ -n "$active_cores" ]; then
	case "$active_cores" in
		''|*[!0-9]*)
			echo "cpufreq.sh: Invalid active core count '$active_cores'." >&2
			exit 1
			;;
	esac
	_total=0
	for _f in /sys/devices/system/cpu/cpu[0-9]*; do
		# Skip non-CPU entries (cpuidle, cpufreq, etc.) so the count
		# reflects actual cores, not the whole /sys/devices/system/cpu
		# directory.
		case "$(basename "$_f")" in cpu[0-9]*) _total=$((_total + 1)) ;; esac
	done
	if [ "$active_cores" -lt 1 ] || [ "$active_cores" -gt "$_total" ]; then
		echo "cpufreq.sh: Invalid active core count '$active_cores' (1-$_total)." >&2
		exit 1
	fi
	unset _total _f
fi

min_freq=$(cpufreq_id_to_hz "$min_id")
max_freq=$(cpufreq_id_to_hz "$max_id")

echo "Setting CPU frequency to $governor, $min_freq - $max_freq kHz (max id $MAX_ID)."

# Apply governor first - on some kernels switching governor resets min/max.
echo "$governor" >/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# Order min/max so the requested range always fits: if the kernel still
# has the old (lower) max in place, setting min > max would be rejected.
if [ "$min_freq" -gt "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq)" ]; then
	echo "$max_freq" >/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
	echo "$min_freq" >/sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
else
	echo "$min_freq" >/sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
	echo "$max_freq" >/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
fi

# Optionally set the number of active CPU cores. Iterate the kernel's own
# cpuN directory list (not a hardcoded cpu[0-3]) so the script scales to
# any core count. The first core (cpu0) is left online; only cpu1+ can be
# brought down to match the request.
if [ -n "$active_cores" ]; then
	_i=0
	for _cpu in /sys/devices/system/cpu/cpu[0-9]*; do
		case "$(basename "$_cpu")" in cpu[0-9]*) ;; *) continue ;; esac
		_cpu_id=$(basename "$_cpu" | sed 's/^cpu//')
		if [ "$_i" -lt "$active_cores" ]; then
			echo 1 >"$_cpu/online" 2>/dev/null
		elif [ "$_cpu_id" != "0" ]; then
			echo 0 >"$_cpu/online" 2>/dev/null
		fi
		_i=$((_i + 1))
	done
	echo "Activated $active_cores CPU core(s)."
	unset _i _cpu _cpu_id
fi
