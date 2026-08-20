#!/bin/sh
# JukaMix OS - device profiles.
#
# Stores hardware-specific defaults per detected device and lets the updater /
# package manager refuse packages that do not support the running hardware.
#
# Detection lives in jukamix-common.sh (jukamix_detect_device). This layer turns
# the detected code into a small, overridable settings profile and exposes a
# single policy function: jukamix_package_supported.
#
# POSIX sh (BusyBox ash / dash). Source this file; do not exec it.

if [ "${0##*/}" = "jukamix-profile.sh" ]; then
	cat >&2 <<'NOTE'
jukamix-profile.sh is a library. Source it from another script, e.g.:
  . "$JUKAMIX_LIB_DIR/jukamix-profile.sh"
NOTE
	exit 0
fi

jukamix_load_common() {
	[ -n "${JUKAMIX_COMMON_LOADED:-}" ] && return 0
	_d="${JUKAMIX_LIB_DIR:-}"
	if [ -z "$_d" ]; then
		case "$0" in
			*/*) _d="${0%/*}" ;;
			*)   _d="." ;;
		esac
	fi
	[ -f "$_d/jukamix-common.sh" ] && . "$_d/jukamix-common.sh" && return 0
	[ -f "$JUKAMIX_LIB/jukamix-common.sh" ] && . "$JUKAMIX_LIB/jukamix-common.sh" && return 0
	return 1
}
jukamix_load_common

JUKAMIX_PROFILE_DIR="${JUKAMIX_PROFILE_DIR:-${JUKAMIX_ROOT:-/mnt/SDCARD}/System/etc/device-profiles}"

# Emit key=value defaults for a device. Overridable by the user via the profile
# file on disk; this only provides the shipped starting point.
jukamix_profile_defaults() {
	_d="${1:-${JUKAMIX_DEVICE_FORCE:-$JUKAMIX_DEVICE}}"
	_d="${_d:-UNKNOWN}"
	case "$_d" in
		tsp)    printf 'perf_profile=balanced\ndisplay_rotation=0\nled=on\nsuspend_timeout=30\n' ;;
		tg5050) printf 'perf_profile=balanced\ndisplay_rotation=0\nled=on\nsuspend_timeout=30\n' ;;
		brick)  printf 'perf_profile=battery-saver\ndisplay_rotation=0\nled=off\nsuspend_timeout=60\n' ;;
		*)      printf 'perf_profile=balanced\ndisplay_rotation=0\nled=on\nsuspend_timeout=30\n' ;;
	esac
	unset _d
}

# Write the device profile to disk (only when missing, so user overrides win).
jukamix_profile_write() {
	_d="${1:-${JUKAMIX_DEVICE_FORCE:-$JUKAMIX_DEVICE}}"
	_pf="${2:-$JUKAMIX_PROFILE_DIR/jukamix-device-profile.txt}"
	[ -f "$_pf" ] && { jukamix_log INFO "device profile already present: $_pf (kept)"; return 0; }
	mkdir -p "${_pf%/*}" 2>/dev/null
	jukamix_profile_defaults "$_d" > "$_pf" 2>/dev/null
	jukamix_log INFO "device profile for $_d written to $_pf"
	unset _d _pf
}

# Policy: does the running device support a package declaring `devices`?
#   jukamix_package_supported <csv>   -> 0 supported, 1 rejected
# An empty/any/all/* declaration means universally supported.
jukamix_package_supported() {
	_csv="${1:-any}"
	[ -z "$_csv" ] && return 0
	_cur="${JUKAMIX_DEVICE_FORCE:-$JUKAMIX_DEVICE}"
	_csv=$(printf '%s' "$_csv" | tr 'A-Z' 'a-z' | tr ',;' '  ')
	_cur=$(printf '%s' "$_cur" | tr 'A-Z' 'a-z')
	case "$_csv" in
		any|all|\*) return 0 ;;
	esac
	for _d in $_csv; do
		[ "$_d" = "$_cur" ] && return 0
	done
	jukamix_log WARN "package device list '$_csv' does not include $_cur"
	return 1
}
