#!/bin/sh
# JukaMix OS - Device Compatibility Layer
#
# Centralizes every device-specific difference (model, firmware, architecture,
# screen, controls, GPU, audio, performance) in ONE place so ordinary launchers
# and tools never compare model names directly. They should ask for a CAPABILITY
# instead:
#
#     if [ "$(jukamix_capability horizontal_display)" = "SUPPORTED" ]; then ...
#
# Capability results use the project vocabulary:
#   SUPPORTED     - known good on this device
#   DEGRADED      - works with reduced quality/features
#   INCOMPATIBLE  - not usable on this device
#   UNTESTED      - no verification data yet (treat as "may not work")
#
# POSIX sh (BusyBox ash / dash). No bashisms. Source this file; do not exec it.

# Guard: if executed directly, just explain and exit.
if [ "${0##*/}" = "jukamix-device.sh" ]; then
	cat >&2 <<'NOTE'
jukamix-device.sh is a library. Source it from another script, e.g.:
  . "$JUKAMIX_LIB_DIR/jukamix-device.sh"
NOTE
	exit 0
fi

# ---- load the shared common library (idempotent) ----------------------------
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

# ---- compatibility database location ----------------------------------------
# Resolved once, overridable with JUKAMIX_DEVICE_DB.
if [ -z "${JUKAMIX_DEVICE_DB:-}" ]; then
	for _c in \
		"$JUKAMIX_TOOLS_DIR/data/compatibility-db.txt" \
		"$JUKAMIX_SYSTEM/jukamix/data/compatibility-db.txt" \
		"$JUKAMIX_LIB_DIR/../data/compatibility-db.txt" \
		"${0%/*}/../data/compatibility-db.txt"; do
		[ -f "$_c" ] && JUKAMIX_DEVICE_DB="$_c" && break
	done
	unset _c
fi

# ---------------------------------------------------------------------------
# Centralized device profile. This is the ONLY place that knows the hardware
# differences between models. Everything else reads from these variables.
# ---------------------------------------------------------------------------
jukamix_device_profile() {
	jukamix_detect_all 2>/dev/null

	# defaults for unknown devices (conservative)
	JUKAMIX_SCREEN_W="${JUKAMIX_SCREEN_W:-0}"
	JUKAMIX_SCREEN_H="${JUKAMIX_SCREEN_H:-0}"
	JUKAMIX_SCREEN_ORIENT="unknown"
	JUKAMIX_HAS_ANALOG=0
	JUKAMIX_HAS_RUMBLE=0
	JUKAMIX_HAS_TOUCH=0
	JUKAMIX_GPU_OPENGL=0
	JUKAMIX_GPU_VULKAN=0
	JUKAMIX_AUDIO_STEREO=0
	JUKAMIX_PERF_TIER="unknown"

	case "$JUKAMIX_DEVICE" in
		tsp)
			JUKAMIX_SCREEN_W=1280; JUKAMIX_SCREEN_H=720; JUKAMIX_SCREEN_ORIENT="horizontal"
			JUKAMIX_HAS_ANALOG=1; JUKAMIX_HAS_RUMBLE=1; JUKAMIX_HAS_TOUCH=0
			JUKAMIX_GPU_OPENGL=1; JUKAMIX_GPU_VULKAN=0
			JUKAMIX_AUDIO_STEREO=1; JUKAMIX_PERF_TIER="standard"
			;;
		tg5050)
			JUKAMIX_SCREEN_W=1280; JUKAMIX_SCREEN_H=720; JUKAMIX_SCREEN_ORIENT="horizontal"
			JUKAMIX_HAS_ANALOG=1; JUKAMIX_HAS_RUMBLE=1; JUKAMIX_HAS_TOUCH=0
			JUKAMIX_GPU_OPENGL=1; JUKAMIX_GPU_VULKAN=0
			JUKAMIX_AUDIO_STEREO=1; JUKAMIX_PERF_TIER="high"
			;;
		brick)
			JUKAMIX_SCREEN_W=1024; JUKAMIX_SCREEN_H=768; JUKAMIX_SCREEN_ORIENT="vertical"
			JUKAMIX_HAS_ANALOG=0; JUKAMIX_HAS_RUMBLE=0; JUKAMIX_HAS_TOUCH=1
			JUKAMIX_GPU_OPENGL=1; JUKAMIX_GPU_VULKAN=0
			JUKAMIX_AUDIO_STEREO=1; JUKAMIX_PERF_TIER="low"
			;;
	esac
	jukamix_detect_arch 2>/dev/null
	[ -z "$JUKAMIX_ARCH" ] || [ "$JUKAMIX_ARCH" = "UNKNOWN" ] && JUKAMIX_ARCH="aarch64"
}

# ---------------------------------------------------------------------------
# Capability checks. Launchers call these instead of comparing model names.
# ---------------------------------------------------------------------------
jukamix_capability() {
	_feat="$1"
	jukamix_device_profile >/dev/null 2>&1
	_res="UNTESTED"
	case "$_feat" in
		horizontal_display)
			if [ "$JUKAMIX_SCREEN_ORIENT" = "horizontal" ] && [ "$JUKAMIX_SCREEN_W" = "1280" ]; then
				_res="SUPPORTED"
			elif [ "$JUKAMIX_SCREEN_ORIENT" = "vertical" ]; then
				_res="INCOMPATIBLE"
			else
				_res="DEGRADED"
			fi ;;
		vertical_display)
			if [ "$JUKAMIX_SCREEN_ORIENT" = "vertical" ]; then _res="SUPPORTED"; else _res="INCOMPATIBLE"; fi ;;
		analog_sticks)
			[ "$JUKAMIX_HAS_ANALOG" = "1" ] && _res="SUPPORTED" || _res="UNTESTED" ;;
		rumble)
			[ "$JUKAMIX_HAS_RUMBLE" = "1" ] && _res="SUPPORTED" || _res="UNTESTED" ;;
		touchscreen)
			[ "$JUKAMIX_HAS_TOUCH" = "1" ] && _res="SUPPORTED" || _res="UNTESTED" ;;
		opengl)
			[ "$JUKAMIX_GPU_OPENGL" = "1" ] && _res="SUPPORTED" || _res="UNTESTED" ;;
		vulkan)
			[ "$JUKAMIX_GPU_VULKAN" = "1" ] && _res="SUPPORTED" || _res="UNTESTED" ;;
		stereo_audio)
			[ "$JUKAMIX_AUDIO_STEREO" = "1" ] && _res="SUPPORTED" || _res="UNTESTED" ;;
		high_perf)
			[ "$JUKAMIX_PERF_TIER" = "high" ] && _res="SUPPORTED" || _res="DEGRADED" ;;
		aarch64)
			[ "$JUKAMIX_ARCH" = "aarch64" ] && _res="SUPPORTED" || _res="UNTESTED" ;;
		*)
			# Unknown feature: fall back to the compatibility database.
			_db_res=$(jukamix_compat_status "$_feat" 2>/dev/null)
			[ -n "$_db_res" ] && _res="$_db_res" ;;
	esac
	printf '%s\n' "$_res"
	unset _feat _res _db_res
}

# ---------------------------------------------------------------------------
# Compatibility database query.
# Schema (pipe-delimited, '#' comments, first non-comment line: # version=N):
#   device|firmware|jukamix_version|component|tested_version|status|limitations|runtime_bios|last_verified
# A field of "*" is a wildcard. The best (most specific) match wins.
# ---------------------------------------------------------------------------
jukamix_compat_query() {
	_dev="$1"; _fw="$2"; _ver="$3"; _comp="$4"
	_db="${JUKAMIX_DEVICE_DB:-}"
	[ -f "$_db" ] || { printf ''; return 1; }
	_best=""; _bestscore=-1
	while IFS='|' read -r d f v c tv st lim rb lv; do
		# strip carriage returns (CRLF safety)
		lv=${lv%"${lv##*[![:space:]]}"}
		case "$d" in \#*) continue ;; esac
		[ -z "$d" ] && continue
		[ "$c" != "$_comp" ] && continue
		_score=0
		if [ "$d" = "$_dev" ]; then _score=$((_score+4)); elif [ "$d" = "*" ]; then _score=$((_score+0)); else continue; fi
		if [ "$f" = "$_fw" ]; then _score=$((_score+2)); elif [ "$f" = "*" ]; then _score=$((_score+0)); else continue; fi
		if [ "$v" = "$_ver" ]; then _score=$((_score+1)); elif [ "$v" = "*" ]; then _score=$((_score+0)); else continue; fi
		if [ "$_score" -gt "$_bestscore" ]; then _bestscore=$_score; _best="$st"; fi
	done < "$_db"
	[ -n "$_best" ] && printf '%s\n' "$_best"
	unset _dev _fw _ver _comp _db _best _bestscore _score d f v c tv st lim rb lv
}

jukamix_compat_status() {
	jukamix_detect_all 2>/dev/null
	jukamix_compat_query "$JUKAMIX_DEVICE" "$JUKAMIX_FIRMWARE" "$JUKAMIX_VERSION" "$1"
}

# Human-readable profile dump for the Device Info screen.
jukamix_device_summary() {
	jukamix_device_profile >/dev/null 2>&1
	jukamix_detect_all 2>/dev/null
	cat <<SUMMARY
Device:        $JUKAMIX_DEVICE_NAME ($JUKAMIX_DEVICE)
Firmware:      $JUKAMIX_FIRMWARE
JukaMix:       $JUKAMIX_VERSION
Architecture:  $JUKAMIX_ARCH
Screen:        ${JUKAMIX_SCREEN_W}x${JUKAMIX_SCREEN_H} ($JUKAMIX_SCREEN_ORIENT)
Controls:      analog=$(jukamix_capability analog_sticks) rumble=$(jukamix_capability rumble) touch=$(jukamix_capability touchscreen)
Graphics:      opengl=$(jukamix_capability opengl) vulkan=$(jukamix_capability vulkan)
Audio:         stereo=$(jukamix_capability stereo_audio)
Performance:   $(jukamix_capability high_perf)
SUMMARY
}
