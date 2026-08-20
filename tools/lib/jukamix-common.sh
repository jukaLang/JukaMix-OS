#!/bin/sh
# JukaMix OS - shared diagnostics and compatibility library.
#
# POSIX sh (BusyBox ash / dash compatible). Intentionally free of bashisms.
# All device paths are overridable through environment variables so the
# tooling can be exercised from the command line and from host-side tests
# against a fixture tree (set JUKAMIX_ROOT to point somewhere else).
#
# This file contains NO telemetry, network access, or secret logging.

# Guard against accidental double-sourcing.
if [ -n "${JUKAMIX_COMMON_LOADED:-}" ]; then
	return 0 2>/dev/null || true
fi
JUKAMIX_COMMON_LOADED=1

# ---------------------------------------------------------------------------
# Path resolution (all overridable)
# ---------------------------------------------------------------------------
JUKAMIX_ROOT="${JUKAMIX_ROOT:-/mnt/SDCARD}"
JUKAMIX_SYSTEM="${JUKAMIX_SYSTEM:-$JUKAMIX_ROOT/System}"
JUKAMIX_BIN="${JUKAMIX_BIN:-$JUKAMIX_SYSTEM/bin}"
JUKAMIX_LIB="${JUKAMIX_LIB:-$JUKAMIX_SYSTEM/lib}"
JUKAMIX_SCRIPTS="${JUKAMIX_SCRIPTS:-$JUKAMIX_SYSTEM/usr/trimui/scripts}"
JUKAMIX_ETC="${JUKAMIX_ETC:-$JUKAMIX_SYSTEM/etc}"
JUKAMIX_RETROARCH="${JUKAMIX_RETROARCH:-$JUKAMIX_ROOT/RetroArch}"
JUKAMIX_RA_HOME="${JUKAMIX_RA_HOME:-$JUKAMIX_RETROARCH/.retroarch}"
JUKAMIX_BIOS="${JUKAMIX_BIOS:-$JUKAMIX_ROOT/BIOS}"
JUKAMIX_PORTMASTER="${JUKAMIX_PORTMASTER:-$JUKAMIX_ROOT/Apps/PortMaster/PortMaster}"
JUKAMIX_ROMS="${JUKAMIX_ROMS:-$JUKAMIX_ROOT/Roms}"
JUKAMIX_SAVES="${JUKAMIX_SAVES:-$JUKAMIX_ROOT/Saves}"
JUKAMIX_THEMES="${JUKAMIX_THEMES:-$JUKAMIX_ROOT/Themes}"
JUKAMIX_LOGDIR="${JUKAMIX_LOGDIR:-$JUKAMIX_SYSTEM/logs}"
JUKAMIX_SUPPORT="${JUKAMIX_SUPPORT:-$JUKAMIX_LOGDIR/jukamix}"
JUKAMIX_TMPBASE="${JUKAMIX_TMPBASE:-/tmp}"
JUKAMIX_PREFIX="jukamix-"

# Discovery of optional companion binaries.
JUKAMIX_SEVENZ="${JUKAMIX_SEVENZ:-$JUKAMIX_BIN/7zz}"
JUKAMIX_JQ="${JUKAMIX_JQ:-$JUKAMIX_BIN/jq}"
JUKAMIX_SYSTEMVAL="${JUKAMIX_SYSTEMVAL:-/usr/trimui/bin/systemval}"
JUKAMIX_INFOSCREEN="${JUKAMIX_INFOSCREEN:-$JUKAMIX_SCRIPTS/infoscreen.sh}"
JUKAMIX_SHELLECT="${JUKAMIX_SHELLECT:-$JUKAMIX_SCRIPTS/shellect.sh}"

# ---------------------------------------------------------------------------
# Quiet / verbosity
# ---------------------------------------------------------------------------
JUKAMIX_QUIET="${JUKAMIX_QUIET:-0}"
JUKAMIX_VERBOSE="${JUKAMIX_VERBOSE:-0}"

# ---------------------------------------------------------------------------
# Safe command detection
# ---------------------------------------------------------------------------
jukamix_have_cmd() {
	command -v "$1" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Logging
#   jukamix_log LEVEL MESSAGE
#   LEVEL: DEBUG INFO WARN ERROR
# ---------------------------------------------------------------------------
jukamix_log() {
	_level="$1"
	_msg="$2"
	_ts=$(date +%Y-%m-%dT%H:%M:%S 2>/dev/null) || _ts=""
	if [ "${JUKAMIX_QUIET:-0}" != "1" ]; then
		case "$_level" in
			ERROR) printf '%s [%s] %s\n' "$_ts" "ERROR" "$_msg" >&2 ;;
			WARN)  printf '%s [%s] %s\n' "$_ts" "WARN " "$_msg" >&2 ;;
			*)     printf '%s [%s] %s\n' "$_ts" "$_level" "$_msg" >&2 ;;
		esac
	fi
	if [ -n "${JUKAMIX_LOG:-}" ]; then
		printf '%s [%s] %s\n' "$_ts" "$_level" "$_msg" >>"$JUKAMIX_LOG" 2>/dev/null
	fi
	unset _level _msg _ts
}

jukamix_debug() {
	if [ "${JUKAMIX_VERBOSE:-0}" = "1" ]; then
		jukamix_log DEBUG "$1"
	fi
}

# Initialize the log file (creates support dir, rotates).
jukamix_init_log() {
	_logname="$1"
	[ -z "$_logname" ] && _logname="jukamix"
	mkdir -p "$JUKAMIX_SUPPORT" 2>/dev/null
	# conservative permission on the support directory where supported
	if jukamix_have_cmd chmod; then
		chmod 700 "$JUKAMIX_SUPPORT" 2>/dev/null
	fi
	JUKAMIX_LOG="$JUKAMIX_SUPPORT/$_logname.$(date +%Y%m%d-%H%M%S).log"
	: >"$JUKAMIX_LOG" 2>/dev/null
	jukamix_logrotate "$JUKAMIX_SUPPORT" "jukamix" 10 5242880
	jukamix_debug "log initialized at $JUKAMIX_LOG"
	unset _logname
}

# Rotate logs: keep at most MAXCOUNT files, and cap total size at MAXBYTES.
# Lists the directory once, then evicts oldest-first until both limits hold.
# Replaces the previous O(n^2) "ls | tail, rm, repeat" loops with a single
# listing + reverse pass, so only one ls and one stat per file are needed.
jukamix_logrotate() {
	_dir="$1"; _pref="$2"; _max="${3:-10}"; _maxbytes="${4:-5242880}"
	[ -d "$_dir" ] || return 0
	# Single pass: list newest-first, count files+bytes, then evict oldest-first
	# until both limits are satisfied.
	_n=0; _tot=0
	_list=""
	for _f in "$_dir"/$_pref.*.log; do
		[ -f "$_f" ] || continue
		_n=$((_n + 1))
		_sz=$(jukamix_filesize "$_f")
		_tot=$((_tot + _sz))
		_list="$_f $_list"
	done
	# Evict oldest-first until within limits.
	for _f in $_list; do
		[ -f "$_f" ] || continue
		[ "$_n" -le "$_max" ] && [ "$_tot" -le "$_maxbytes" ] && break
		_sz=$(jukamix_filesize "$_f")
		_n=$((_n - 1)); _tot=$((_tot - _sz))
		rm -f "$_f" 2>/dev/null
	done
	unset _dir _pref _max _maxbytes _list _n _f _sz _tot
}

# Portable file size in bytes. stat -c%s is 1 fork on Linux/BusyBox; on
# hosts where it is unsupported (BSD) it fails and we fall back to wc -c.
jukamix_filesize() {
	_f="$1"
	stat -c%s "$_f" 2>/dev/null || wc -c <"$_f" 2>/dev/null
	unset _f
}

# ---------------------------------------------------------------------------
# Device / firmware / architecture / version detection
# ---------------------------------------------------------------------------
JUKAMIX_DEVICE="${JUKAMIX_DEVICE:-UNKNOWN}"
JUKAMIX_DEVICE_NAME="${JUKAMIX_DEVICE_NAME:-UNKNOWN}"
JUKAMIX_FIRMWARE="${JUKAMIX_FIRMWARE:-UNKNOWN}"
JUKAMIX_ARCH="${JUKAMIX_ARCH:-UNKNOWN}"
JUKAMIX_VERSION="${JUKAMIX_VERSION:-UNKNOWN}"

jukamix_detect_arch() {
	_a=$(uname -m 2>/dev/null)
	[ -n "$_a" ] && JUKAMIX_ARCH="$_a"
	unset _a
}

jukamix_detect_device() {
	# Allow an explicit override (tests, pinned device, recovery).
	if [ -n "${JUKAMIX_DEVICE_FORCE:-}" ]; then
		JUKAMIX_DEVICE="$JUKAMIX_DEVICE_FORCE"
		case "$JUKAMIX_DEVICE" in
			tsp)    JUKAMIX_DEVICE_NAME="TrimUI Smart Pro" ;;
			tg5050) JUKAMIX_DEVICE_NAME="TrimUI Smart Pro S (TG5050)" ;;
			brick)  JUKAMIX_DEVICE_NAME="TrimUI Brick" ;;
			*)      JUKAMIX_DEVICE_NAME="$JUKAMIX_DEVICE" ;;
		esac
		unset _code
		return 0
	fi
	_code="UNKNOWN"
	if [ -r /etc/trimui_device.txt ]; then
		_code=$(cat /etc/trimui_device.txt 2>/dev/null | tr -d '[:space:]' | head -n 1)
	fi
	# Fallback to systemval if present and no code yet.
	if [ "$_code" = "UNKNOWN" ] && [ -x "$JUKAMIX_SYSTEMVAL" ]; then
		_c2=$("$JUKAMIX_SYSTEMVAL" device 2>/dev/null | tr -d '[:space:]' | head -n 1)
		[ -n "$_c2" ] && _code="$_c2"
	fi
	[ -z "$_code" ] && _code="UNKNOWN"
	JUKAMIX_DEVICE="$_code"
	case "$_code" in
		tsp)        JUKAMIX_DEVICE_NAME="TrimUI Smart Pro" ;;
		tg5050)     JUKAMIX_DEVICE_NAME="TrimUI Smart Pro S (TG5050)" ;;
		brick)      JUKAMIX_DEVICE_NAME="TrimUI Brick" ;;
		*)          JUKAMIX_DEVICE_NAME="$_code" ;;
	esac
	unset _code _c2
}

jukamix_detect_firmware() {
	_fw="UNKNOWN"
	for _cand in /etc/trimui_firmware.txt /usr/trimui/trimui_firmware.txt "$JUKAMIX_ETC/firmware.txt"; do
		if [ -r "$_cand" ]; then
			_fw=$(cat "$_cand" 2>/dev/null | tr -d '[:space:]' | head -n 1)
			[ -n "$_fw" ] && break
		fi
	done
	JUKAMIX_FIRMWARE="$_fw"
	unset _fw _cand
}

jukamix_detect_version() {
	_vf="$JUKAMIX_SYSTEM/usr/trimui/jukamix-version.txt"
	[ -f "$JUKAMIX_SYSTEM/usr/trimui/jukamix-version.txt" ] && _vf="$JUKAMIX_SYSTEM/usr/trimui/jukamix-version.txt"
	if [ -r "$_vf" ]; then
		JUKAMIX_VERSION=$(cat "$_vf" 2>/dev/null | tr -d '[:space:]' | head -n 1)
		[ -z "$JUKAMIX_VERSION" ] && JUKAMIX_VERSION="UNKNOWN"
	fi
	unset _vf
}

jukamix_detect_all() {
	jukamix_detect_arch
	jukamix_detect_device
	jukamix_detect_firmware
	jukamix_detect_version
}

# ---------------------------------------------------------------------------
# Privacy-safe report generation
# ---------------------------------------------------------------------------
JUKAMIX_REPORT="${JUKAMIX_REPORT:-}"

jukamix_init_report() {
	_rp="$1"
	[ -z "$_rp" ] && _rp="$JUKAMIX_SUPPORT/jukamix-report.$(date +%Y%m%d-%H%M%S).txt"
	mkdir -p "${_rp%/*}" 2>/dev/null
	JUKAMIX_REPORT="$_rp"
	: >"$JUKAMIX_REPORT" 2>/dev/null
	unset _rp
}

jukamix_report() {
	[ -n "${JUKAMIX_REPORT:-}" ] && printf '%s\n' "$1" >>"$JUKAMIX_REPORT" 2>/dev/null
}

# Redact a content path to a privacy-safe token (hash, no filename).
jukamix_redact() {
	_p="$1"
	if jukamix_have_cmd sha256sum; then
		printf '%s' "$_p" | sha256sum 2>/dev/null | cut -c1-16
	elif jukamix_have_cmd md5sum; then
		printf '%s' "$_p" | md5sum 2>/dev/null | cut -c1-16
	else
		printf 'id-%s' "$(printf '%s' "$_p" | wc -c)"
	fi
}

# Redact secret VALUES from a stream (passwords, PSKs, tokens, API keys).
# Reads stdin, writes stdout. Leaves all other content intact.
jukamix_redact_values() {
	sed -e 's/\([Pp][Ss][Kk]\)[=:]"[^"]*"/\1=REDACTED"/g' \
	    -e 's/\([Pp][Ss][Kk]\)[=:][^[:space:]]*/\1=REDACTED/g' \
	    -e 's/\([Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]\)[=:]"[^"]*"/\1=REDACTED"/g' \
	    -e 's/\([Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]\)[=:][^[:space:]]*/\1=REDACTED/g' \
	    -e 's/\([Aa][Pp][Ii][Kk][Ee][Yy]\)[=:][^[:space:]]*/\1=REDACTED/g' \
	    -e 's/\([Tt][Oo][Kk][Ee][Nn]\)[=:][^[:space:]]*/\1=REDACTED/g' \
	    -e 's/\([Ss][Ee][Cc][Rr][Ee][Tt]\)[=:][^[:space:]]*/\1=REDACTED/g'
}

# Short, unique-ish identifier for a support report (8 hex chars or fallback).
jukamix_report_id() {
	_id=""
	if [ -r /dev/urandom ]; then
		_id=$(od -An -tx1 -N4 /dev/urandom 2>/dev/null | tr -d ' \n')
	fi
	# Portable fallback (no %N/md5sum dependency): cksum of pid+timestamp.
	[ -z "$_id" ] && _id=$(printf '%s' "$$$(date +%s)" | cksum | cut -c1-8)
	[ -z "$_id" ] && _id="report"
	printf '%s\n' "$_id"
	unset _id
}

# ---------------------------------------------------------------------------
# Notification / prompt (use device UI when available, else terminal)
# ---------------------------------------------------------------------------
jukamix_notify() {
	_msg="$1"
	if [ -x "$JUKAMIX_INFOSCREEN" ]; then
		"$JUKAMIX_INFOSCREEN" -m "$_msg" -t 3 2>/dev/null
	elif [ -x "$JUKAMIX_SHELLECT" ]; then
		printf '%s\n' "$_msg" | "$JUKAMIX_SHELLECT" -t "JukaMix OS" -b "Press A" >/dev/null 2>&1
	else
		printf '%s\n' "$_msg" >&2
	fi
	unset _msg
}

# Yes/No prompt. Echoes "yes" or "no" on stdout.
jukamix_confirm() {
	_prompt="$1"
	# Testability / non-interactive override.
	if [ "${JUKAMIX_FORCE_CONFIRM:-}" = "yes" ]; then
		printf 'yes'
		unset _prompt
		return 0
	fi
	if [ -x "$JUKAMIX_SHELLECT" ]; then
		printf 'No\nYes\n' | "$JUKAMIX_SHELLECT" -t "$_prompt" -b "Press A to validate" 2>/dev/null
	else
		printf '%s (y/N): ' "$_prompt" >&2
		read -r _ans 2>/dev/null || _ans="n"
		case "$_ans" in
			y|Y|yes|YES) printf 'yes' ;;
			*) printf 'no' ;;
		esac
		unset _ans
	fi
	unset _prompt
}

# ---------------------------------------------------------------------------
# Locking with flock fallback (mkdir-based advisory lock)
# ---------------------------------------------------------------------------
jukamIX_LOCKDIR=""

jukamix_lock() {
	_name="$1"
	_ldir="$JUKAMIX_TMPBASE/.$JUKAMIX_PREFIX$_name.lock"
	if jukamix_have_cmd flock; then
		# flock works on a file descriptor; open a lock file.
		exec 9>"$_ldir" 2>/dev/null
		if flock -n 9 2>/dev/null; then
			jukamix_debug "acquired flock for $_name"
			unset _name _ldir
			return 0
		fi
		jukamix_debug "flock unavailable/busy for $_name"
		unset _name _ldir
		return 1
	fi
	# Fallback: mkdir is atomic on POSIX filesystems.
	if mkdir "$_ldir" 2>/dev/null; then
		trap 'rm -rf "$_ldir" 2>/dev/null' EXIT INT TERM
		jukamix_debug "acquired mkdir lock for $_name"
		unset _name _ldir
		return 0
	fi
	jukamix_debug "mkdir lock busy for $_name"
	unset _name _ldir
	return 1
}

jukamix_unlock() {
	_name="$1"
	_ldir="$JUKAMIX_TMPBASE/.$JUKAMIX_PREFIX$_name.lock"
	if jukamix_have_cmd flock; then
		exec 9>&- 2>/dev/null
	else
		rm -rf "$_ldir" 2>/dev/null
	fi
	unset _name _ldir
}

# ---------------------------------------------------------------------------
# Temporary directory + cleanup traps
# ---------------------------------------------------------------------------
jukamix_mktempdir() {
	_base="${1:-$JUKAMIX_TMPBASE}"
	# POSIX-safe uniqueness: PID + per-process sequence counter + epoch seconds
	# ($RANDOM is a bashism and is empty under BusyBox ash/dash).
	JUKAMIX_TMPSEQ=${JUKAMIX_TMPSEQ:-0}
	JUKAMIX_TMPSEQ=$((JUKAMIX_TMPSEQ + 1))
	_d="$JUKAMIX_TMPBASE/.$JUKAMIX_PREFIX.$$.$JUKAMIX_TMPSEQ.$(date +%s)"
	# predictable-but-unique, not world-writable: rely on /tmp perms.
	mkdir -p "$_d" 2>/dev/null || return 1
	printf '%s\n' "$_d"
	unset _base _d
}

# Register a cleanup trap that restores display/audio/input/performance state
# by invoking the project's known restore helpers when present.
jukamix_trap_cleanup() {
	# Preserve prior EXIT trap if any.
	_prev=$(trap -p EXIT 2>/dev/null | sed "s/^trap -- '//; s/' EXIT\$//")
	_cleanup() {
		# Remove our temp dirs.
		if [ -n "${JUKAMIX_TMPDIR:-}" ] && [ -d "$JUKAMIX_TMPDIR" ]; then
			rm -rf "$JUKAMIX_TMPDIR" 2>/dev/null
		fi
		# Restore performance governor if we changed it.
		if [ -n "${JUKAMIX_RESTORE_GOV:-}" ]; then
			echo "$JUKAMIX_RESTORE_GOV" >/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null
		fi
		# Restore display/audio/input via project helpers when available.
		if [ -x "$JUKAMIX_SCRIPTS/lcd_on.sh" ]; then
			"$JUKAMIX_SCRIPTS/lcd_on.sh" 2>/dev/null
		fi
		if [ -x "$JUKAMIX_SCRIPTS/cpufreq-restore.sh" ]; then
			"$JUKAMIX_SCRIPTS/cpufreq-restore.sh" 2>/dev/null
		fi
		if [ -n "$_prev" ]; then
			eval "$_prev"
		fi
	}
	trap _cleanup EXIT INT TERM HUP
	unset _prev
}

# ---------------------------------------------------------------------------
# Atomic file replacement with timestamped backup
# ---------------------------------------------------------------------------
jukamix_backup_file() {
	_src="$1"
	[ -f "$_src" ] || { jukamix_log WARN "backup skipped, not a file: $_src"; return 0; }
	_bdir="$JUKAMIX_SUPPORT/backups"
	[ -n "${2:-}" ] && _bdir="$2"
	mkdir -p "$_bdir" 2>/dev/null
	_bk="$_bdir/${_src##*/}.$(date +%Y%m%d-%H%M%S).bak"
	cp -p "$_src" "$_bk" 2>/dev/null && jukamix_log INFO "backed up $_src -> $_bk"
	unset _src _bdir _bk
}

jukamix_atomic_replace() {
	_src="$1"; _dst="$2"
	[ -f "$_src" ] || { jukamix_log ERROR "atomic replace source missing: $_src"; return 1; }
	if [ -f "$_dst" ]; then
		jukamix_backup_file "$_dst"
	fi
	_tmp="$_dst.tmp.$$"
	cp -p "$_src" "$_tmp" 2>/dev/null || { jukamix_log ERROR "atomic replace copy failed: $_dst"; return 1; }
	mv -f "$_tmp" "$_dst" 2>/dev/null || { jukamix_log ERROR "atomic replace mv failed: $_dst"; rm -f "$_tmp" 2>/dev/null; return 1; }
	jukamix_log INFO "replaced $_dst (backup retained)"
	unset _src _dst _tmp
}

# ---------------------------------------------------------------------------
# Free space (MB) for a given path's filesystem
# ---------------------------------------------------------------------------
jukamix_free_space_mb() {
	_p="$1"
	[ -z "$_p" ] && _p="$JUKAMIX_ROOT"
	_mp=$(jukamix_mountpoint "$_p")
	if jukamix_have_cmd df; then
		df -m "$_mp" 2>/dev/null | awk 'NR==2{print $4; exit}'
	else
		echo "0"
	fi
	unset _p _mp
}

jukamix_mountpoint() {
	_p="$1"
	if jukamix_have_cmd df; then
		df "$_p" 2>/dev/null | awk 'NR==2{print $6; exit}'
	else
		echo "$_p"
	fi
	unset _p
}

# ---------------------------------------------------------------------------
# Safe command execution with exit-code capture
# ---------------------------------------------------------------------------
jukamix_safe_run() {
	# Runs "$@"; echoes exit code to stdout, does not suppress output.
	"$@"
	_rc=$?
	printf '%s\n' "$_rc"
	unset _rc
}

# ---------------------------------------------------------------------------
# Feature detection helpers
# ---------------------------------------------------------------------------
jukamix_check_exec() {
	# $1 path; prints PASS/WARN/FAIL
	_p="$1"
	if [ -e "$_p" ] && [ -x "$_p" ]; then
		printf 'PASS'
	elif [ -e "$_p" ]; then
		printf 'WARN'
	else
		printf 'FAIL'
	fi
	unset _p
}

jukamix_require_cmds() {
	# prints missing commands, one per line; empty if all present
	for _c in "$@"; do
		jukamix_have_cmd "$_c" || printf '%s\n' "$_c"
	done
	unset _c
}

# ---------------------------------------------------------------------------
# Usage helper
# ---------------------------------------------------------------------------
jukamix_usage_common() {
	cat <<USAGE
Common options:
  -h, --help          Show this help and exit.
  -q, --quiet         Reduce on-screen output (logs still written).
  -v, --verbose       Verbose (debug) logging.
  --dry-run           Report actions without modifying the system.
  --output PATH       Write the support/report file to PATH.
USAGE
}

# Mark a tool as started (writes a tiny run marker, no PII).
jukamix_begin() {
	jukamix_detect_all
	jukamix_debug "JukaMix OS diagnostics begin: device=$JUKAMIX_DEVICE ($JUKAMIX_DEVICE_NAME) arch=$JUKAMIX_ARCH fw=$JUKAMIX_FIRMWARE ver=$JUKAMIX_VERSION"
}
