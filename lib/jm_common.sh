#!/bin/sh
# lib/jm_common.sh - Shared runtime library for JukaMix OS
#
# Strict POSIX. Must run under busybox ash on-device. No bashisms:
#   no [[ ]], no arrays, no ${var^^}, no <<<, no `function`, no `local -a`.
#
# Usage:
#   JM_ROOT="${JM_ROOT:-/mnt/SDCARD}"
#   . "$JM_ROOT/lib/jm_common.sh"
#   jm_init "my-app"
#
# Every public function is prefixed jm_. Everything else is _jm_ (private).

[ -n "${_JM_COMMON_LOADED:-}" ] && return 0
_JM_COMMON_LOADED=1

#-----------------------------------------------------------------------------
# Paths and defaults
#-----------------------------------------------------------------------------
JM_ROOT="${JM_ROOT:-/mnt/SDCARD}"
JM_SYSTEM="${JM_SYSTEM:-$JM_ROOT/System}"
JM_CONFIG_DIR="${JM_CONFIG_DIR:-$JM_ROOT/config}"
JM_LOG_DIR="${JM_LOG_DIR:-$JM_SYSTEM/logs}"
JM_RUN_DIR="${JM_RUN_DIR:-/tmp/jukamix}"
JM_TAG="${JM_TAG:-jukamix}"

# Log level: 0=debug 1=info 2=warn 3=error. Override with JM_LOG_LEVEL.
JM_LOG_LEVEL="${JM_LOG_LEVEL:-1}"
JM_LOG_MAX_BYTES="${JM_LOG_MAX_BYTES:-262144}"   # rotate at 256 KiB
JM_LOG_KEEP="${JM_LOG_KEEP:-3}"

# Network defaults tuned for handheld Wi-Fi.
JM_NET_RETRIES="${JM_NET_RETRIES:-4}"
JM_NET_CONNECT_TIMEOUT="${JM_NET_CONNECT_TIMEOUT:-15}"
JM_NET_MAX_TIME="${JM_NET_MAX_TIME:-0}"          # 0 = unlimited (large images)
JM_NET_BACKOFF_BASE="${JM_NET_BACKOFF_BASE:-2}"

_JM_TMPDIRS=""
_JM_LOCKS=""
_JM_LOGFILE=""
_JM_NAME="jm"

#-----------------------------------------------------------------------------
# Init / teardown
#-----------------------------------------------------------------------------

# jm_init <component-name>
# Sets up logging, temp handling, and an EXIT/INT/TERM trap that always cleans up.
jm_init() {
	_JM_NAME="${1:-jm}"
	mkdir -p "$JM_LOG_DIR" "$JM_RUN_DIR" 2>/dev/null || true
	_JM_LOGFILE="$JM_LOG_DIR/$_JM_NAME.log"
	_jm_rotate_log
	# shellcheck disable=SC2064  # expand now: we want the current function name
	trap '_jm_cleanup' EXIT
	trap '_jm_cleanup; exit 130' INT
	trap '_jm_cleanup; exit 143' TERM
	jm_debug "init component=$_JM_NAME device=$(jm_device) version=$(jm_version)"
}

_jm_cleanup() {
	_jm_rc=$?
	for _d in $_JM_TMPDIRS; do
		[ -d "$_d" ] && rm -rf "$_d"
	done
	for _l in $_JM_LOCKS; do
		[ -d "$_l" ] && rm -rf "$_l"
	done
	_JM_TMPDIRS=""
	_JM_LOCKS=""
	return $_jm_rc
}

# jm_mktemp_dir -> prints path, auto-removed on exit
jm_mktemp_dir() {
	_d=$(mktemp -d "$JM_RUN_DIR/${_JM_NAME}.XXXXXX" 2>/dev/null) || {
		_d="$JM_RUN_DIR/$_JM_NAME.$$.$(_jm_rand)"
		mkdir -p "$_d" || return 1
	}
	_JM_TMPDIRS="$_JM_TMPDIRS $_d"
	printf '%s\n' "$_d"
}

_jm_rand() {
	if [ -r /dev/urandom ]; then
		od -An -N2 -tu2 /dev/urandom 2>/dev/null | tr -d ' \n'
	else
		printf '%s' "$$"
	fi
}

#-----------------------------------------------------------------------------
# Logging
#-----------------------------------------------------------------------------

_jm_rotate_log() {
	[ -n "$_JM_LOGFILE" ] || return 0
	[ -f "$_JM_LOGFILE" ] || return 0
	_sz=$(wc -c <"$_JM_LOGFILE" 2>/dev/null | tr -d ' ') || return 0
	[ "${_sz:-0}" -lt "$JM_LOG_MAX_BYTES" ] && return 0
	_i="$JM_LOG_KEEP"
	while [ "$_i" -gt 1 ]; do
		_prev=$((_i - 1))
		[ -f "$_JM_LOGFILE.$_prev" ] && mv -f "$_JM_LOGFILE.$_prev" "$_JM_LOGFILE.$_i"
		_i="$_prev"
	done
	mv -f "$_JM_LOGFILE" "$_JM_LOGFILE.1"
}

_jm_log() {
	_lvl="$1"
	_num="$2"
	shift 2
	[ "$_num" -lt "$JM_LOG_LEVEL" ] && return 0
	_ts=$(date '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || printf 'unknown')
	_line="$_ts [$_lvl] ($_JM_NAME) $*"
	# stderr keeps launchers/SSH informative; file keeps post-mortem evidence.
	printf '%s\n' "$_line" >&2
	[ -n "$_JM_LOGFILE" ] && printf '%s\n' "$_line" >>"$_JM_LOGFILE" 2>/dev/null
	return 0
}

jm_debug() { _jm_log DEBUG 0 "$@"; }
jm_info()  { _jm_log INFO  1 "$@"; }
jm_warn()  { _jm_log WARN  2 "$@"; }
jm_error() { _jm_log ERROR 3 "$@"; }

# jm_die <exit-code> <message...>
jm_die() {
	_rc="$1"
	shift
	jm_error "$@"
	exit "$_rc"
}

# jm_toast <message> - best-effort on-screen notification, never fatal.
jm_toast() {
	jm_info "toast: $*"
	if command -v infoPanel >/dev/null 2>&1; then
		infoPanel -t "JukaMix" -m "$*" >/dev/null 2>&1 &
	elif [ -x "$JM_SYSTEM/bin/infoPanel" ]; then
		"$JM_SYSTEM/bin/infoPanel" -t "JukaMix" -m "$*" >/dev/null 2>&1 &
	fi
	return 0
}

#-----------------------------------------------------------------------------
# Locking (mkdir-based: works without flock, survives kill -9)
#-----------------------------------------------------------------------------

# jm_lock <name> [timeout-seconds]
# Prevents two updaters / two scrapers stomping the same tree.
jm_lock() {
	_name="$1"
	_timeout="${2:-30}"
	_dir="$JM_RUN_DIR/lock.$_name"
	mkdir -p "$JM_RUN_DIR" 2>/dev/null || true
	_waited=0
	while ! mkdir "$_dir" 2>/dev/null; do
		if _jm_lock_is_stale "$_dir"; then
			jm_warn "removing stale lock $_name"
			rm -rf "$_dir"
			continue
		fi
		[ "$_waited" -ge "$_timeout" ] && {
			jm_error "could not acquire lock '$_name' after ${_timeout}s"
			return 1
		}
		sleep 1
		_waited=$((_waited + 1))
	done
	printf '%s\n' "$$" >"$_dir/pid"
	_JM_LOCKS="$_JM_LOCKS $_dir"
	jm_debug "acquired lock $_name"
	return 0
}

_jm_lock_is_stale() {
	_pidfile="$1/pid"
	[ -f "$_pidfile" ] || return 0            # no pid recorded -> assume stale
	_pid=$(cat "$_pidfile" 2>/dev/null)
	case "$_pid" in
	'' | *[!0-9]*) return 0 ;;
	esac
	[ -d "/proc/$_pid" ] && return 1
	return 0
}

jm_unlock() {
	_dir="$JM_RUN_DIR/lock.$1"
	rm -rf "$_dir"
	# Remove $_dir from the space-separated lock list without external tools.
	_new=""
	for _l in $_JM_LOCKS; do
		[ "$_l" = "$_dir" ] || _new="$_new $_l"
	done
	_JM_LOCKS="${_new# }"
	return 0
}

#-----------------------------------------------------------------------------
# Atomic file operations (SD cards get yanked mid-write; never truncate in place)
#-----------------------------------------------------------------------------

# jm_atomic_write <dest>   (content on stdin)
jm_atomic_write() {
	_dest="$1"
	[ -n "$_dest" ] || return 1
	_dir=$(dirname "$_dest")
	mkdir -p "$_dir" || return 1
	_tmp="$_dir/.jm.$(basename "$_dest").$$"
	cat >"$_tmp" || { rm -f "$_tmp"; return 1; }
	if [ -e "$_dest" ]; then
		# Preserve the original mode so exec bits are never lost.
		_mode=$(_jm_mode_of "$_dest")
		[ -n "$_mode" ] && chmod "$_mode" "$_tmp" 2>/dev/null
	fi
	mv -f "$_tmp" "$_dest" || { rm -f "$_tmp"; return 1; }
	sync 2>/dev/null || true
	return 0
}

_jm_mode_of() {
	stat -c '%a' "$1" 2>/dev/null || return 1
}

# jm_backup <file> - copy to <file>.jmbak.<epoch>, prints backup path
jm_backup() {
	_f="$1"
	[ -e "$_f" ] || return 0
	_bak="$_f.jmbak.$(date +%s 2>/dev/null || printf '0')"
	cp -p "$_f" "$_bak" 2>/dev/null || cp "$_f" "$_bak" || return 1
	printf '%s\n' "$_bak"
}

#-----------------------------------------------------------------------------
# key=value config helpers (no sed -i; busybox sed lacks portable -i semantics)
#-----------------------------------------------------------------------------

# jm_cfg_get <file> <key> [default]
jm_cfg_get() {
	_file="$1"; _key="$2"; _def="${3:-}"
	[ -f "$_file" ] || { printf '%s\n' "$_def"; return 0; }
	_val=$(grep -E "^[[:space:]]*$_key[[:space:]]*=" "$_file" 2>/dev/null | tail -n 1 |
		cut -d= -f2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')
	[ -n "$_val" ] && printf '%s\n' "$_val" || printf '%s\n' "$_def"
}

# jm_cfg_set <file> <key> <value>  - idempotent, atomic, comment-preserving
jm_cfg_set() {
	_file="$1"; _key="$2"; _value="$3"
	mkdir -p "$(dirname "$_file")" || return 1
	[ -f "$_file" ] || : >"$_file"
	{
		grep -vE "^[[:space:]]*$_key[[:space:]]*=" "$_file" 2>/dev/null
		printf '%s=%s\n' "$_key" "$_value"
	} | jm_atomic_write "$_file"
}

#-----------------------------------------------------------------------------
# Device detection (cached; drives per-device emulator/perf tuning)
#-----------------------------------------------------------------------------

# jm_device -> tsp | tg5050 | brick | unknown
jm_device() {
	if [ -n "${JM_DEVICE_CACHE:-}" ]; then
		printf '%s\n' "$JM_DEVICE_CACHE"
		return 0
	fi
	_dev=unknown
	# 1) Explicit override wins (useful for CI and desktop testing).
	if [ -n "${JM_DEVICE_OVERRIDE:-}" ]; then
		_dev="$JM_DEVICE_OVERRIDE"
	# 2) TrimUI exposes a model string in the device tree.
	elif [ -r /proc/device-tree/model ]; then
		_model=$(tr -d '\0' </proc/device-tree/model 2>/dev/null | tr 'A-Z' 'a-z')
		case "$_model" in
		*a523* | *tg5050* | *5050*) _dev=tg5050 ;;
		*brick* | *tg3040*)         _dev=brick ;;
		*a133*)                     _dev=tsp ;;
		esac
	fi
	# 3) Fall back to resolution: Brick is the only 4:3 panel.
	if [ "$_dev" = unknown ] && [ -r /sys/class/graphics/fb0/virtual_size ]; then
		case "$(cat /sys/class/graphics/fb0/virtual_size 2>/dev/null)" in
		1024,*) _dev=brick ;;
		1280,*) _dev=tsp ;;
		esac
	fi
	JM_DEVICE_CACHE="$_dev"
	printf '%s\n' "$_dev"
}

# jm_device_caps -> "WIDTHxHEIGHT analog=<0|1> rumble=<0|1> touch=<0|1>"
jm_device_caps() {
	case "$(jm_device)" in
	brick)  printf '1024x768 analog=0 rumble=0 touch=1\n' ;;
	tg5050) printf '1280x720 analog=1 rumble=1 touch=0\n' ;;
	tsp)    printf '1280x720 analog=1 rumble=1 touch=0\n' ;;
	*)      printf '1280x720 analog=1 rumble=1 touch=0\n' ;;
	esac
}

# jm_has_analog / jm_has_rumble -> exit 0 if supported
jm_has_analog() { case "$(jm_device)" in brick) return 1 ;; *) return 0 ;; esac; }
jm_has_rumble() { case "$(jm_device)" in brick) return 1 ;; *) return 0 ;; esac; }

jm_version() {
	if [ -f "$JM_SYSTEM/version.txt" ]; then
		head -n 1 "$JM_SYSTEM/version.txt" 2>/dev/null | tr -d '\r\n'
	else
		printf 'dev'
	fi
}

#-----------------------------------------------------------------------------
# Disk space preflight (a half-extracted update is the worst failure mode)
#-----------------------------------------------------------------------------

# jm_free_kb [path] -> free kilobytes
jm_free_kb() {
	_p="${1:-$JM_ROOT}"
	df -k "$_p" 2>/dev/null | awk 'NR==2 {print $4; exit}'
}

# jm_require_space <needed-kb> [path]
jm_require_space() {
	_need="$1"; _p="${2:-$JM_ROOT}"
	_free=$(jm_free_kb "$_p")
	case "$_free" in '' | *[!0-9]*) jm_warn "cannot determine free space on $_p"; return 0 ;; esac
	if [ "$_free" -lt "$_need" ]; then
		jm_error "insufficient space on $_p: need ${_need}KB, have ${_free}KB"
		return 1
	fi
	jm_debug "space ok on $_p: ${_free}KB free, ${_need}KB needed"
	return 0
}

#-----------------------------------------------------------------------------
# Network: retry with exponential backoff, resume, mandatory verification
#-----------------------------------------------------------------------------

jm_online() {
	# Cheap reachability probe; avoids a 60s hang on every app start.
	if command -v curl >/dev/null 2>&1; then
		curl -fsS --connect-timeout 5 -o /dev/null "https://api.github.com/" 2>/dev/null && return 0
	fi
	ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1 && return 0
	return 1
}

_jm_fetch_once() {
	_url="$1"; _out="$2"
	if command -v curl >/dev/null 2>&1; then
		set -- -fL --connect-timeout "$JM_NET_CONNECT_TIMEOUT" \
			--retry 0 -C - -o "$_out" "$_url"
		[ "$JM_NET_MAX_TIME" -gt 0 ] && set -- --max-time "$JM_NET_MAX_TIME" "$@"
		curl "$@" 2>>"${_JM_LOGFILE:-/dev/null}"
	elif command -v wget >/dev/null 2>&1; then
		# busybox wget: -c resume, -T timeout, -q quiet
		wget -c -T "$JM_NET_CONNECT_TIMEOUT" -O "$_out" "$_url" 2>>"${_JM_LOGFILE:-/dev/null}"
	else
		jm_error "neither curl nor wget available"
		return 127
	fi
}

# jm_fetch <url> <dest> [expected-sha256]
# Retries with backoff, resumes partial downloads, verifies before publishing.
# The download lands in dest.part and is only moved into place once verified.
jm_fetch() {
	_url="$1"; _dest="$2"; _sha="${3:-}"
	mkdir -p "$(dirname "$_dest")" || return 1
	_part="$_dest.part"
	_try=1
	while [ "$_try" -le "$JM_NET_RETRIES" ]; do
		jm_info "fetch attempt $_try/$JM_NET_RETRIES: $_url"
		if _jm_fetch_once "$_url" "$_part"; then
			if [ -n "$_sha" ]; then
				if jm_verify_sha256 "$_part" "$_sha"; then
					mv -f "$_part" "$_dest" && sync 2>/dev/null
					jm_info "fetch verified -> $_dest"
					return 0
				fi
				# Checksum failure means the partial file is poison: start clean.
				jm_warn "checksum mismatch, discarding partial download"
				rm -f "$_part"
			else
				mv -f "$_part" "$_dest" && sync 2>/dev/null
				jm_warn "fetch completed WITHOUT checksum verification -> $_dest"
				return 0
			fi
		fi
		_sleep=$((JM_NET_BACKOFF_BASE ** _try))
		[ "$_sleep" -gt 30 ] && _sleep=30
		jm_warn "fetch failed; retrying in ${_sleep}s"
		sleep "$_sleep"
		_try=$((_try + 1))
	done
	rm -f "$_part"
	jm_error "fetch failed after $JM_NET_RETRIES attempts: $_url"
	return 1
}

# jm_verify_sha256 <file> <expected-hex>
jm_verify_sha256() {
	_f="$1"; _want=$(printf '%s' "$2" | tr 'A-Z' 'a-z')
	[ -f "$_f" ] || { jm_error "verify: missing file $_f"; return 1; }
	_got=$(jm_sha256 "$_f") || return 1
	if [ "$_got" != "$_want" ]; then
		jm_error "verify: $_f sha256 mismatch (want $_want got $_got)"
		return 1
	fi
	jm_debug "verify: $_f ok"
	return 0
}

jm_sha256() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" 2>/dev/null | awk '{print tolower($1); exit}'
	elif command -v shasum >/dev/null 2>&1; then
		shasum -a 256 "$1" 2>/dev/null | awk '{print tolower($1); exit}'
	elif command -v openssl >/dev/null 2>&1; then
		openssl dgst -sha256 "$1" 2>/dev/null | awk '{print tolower($NF); exit}'
	else
		jm_error "no sha256 implementation available"
		return 127
	fi
}

#-----------------------------------------------------------------------------
# Exec-bit repair (SD cards formatted FAT/exFAT lose the +x bit entirely)
#-----------------------------------------------------------------------------

# jm_fix_exec_bits <dir> - marks shell scripts and ELF binaries executable
jm_fix_exec_bits() {
	_dir="$1"
	[ -d "$_dir" ] || return 0
	# Single find pass: mark shell scripts and ELF binaries executable.
	find "$_dir" -type f ! -perm -u+x 2>/dev/null | while IFS= read -r _f; do
		case "$_f" in
			*.sh|*.bin|*/launch.sh) chmod +x "$_f" 2>/dev/null; continue ;;
		esac
		_magic=$(head -c 4 "$_f" 2>/dev/null | tr -d '\0')
		case "$_magic" in
			'#!'* | *ELF*) chmod +x "$_f" 2>/dev/null ;;
		esac
	done
	jm_debug "exec bits normalized under $_dir"
	return 0
}

#-----------------------------------------------------------------------------
# Misc utilities
#-----------------------------------------------------------------------------

# jm_retry <attempts> <command...>
jm_retry() {
	_attempts="$1"; shift
	_i=1
	while [ "$_i" -le "$_attempts" ]; do
		if "$@"; then return 0; fi
		jm_warn "command failed (attempt $_i/$_attempts): $*"
		_i=$((_i + 1))
		sleep 1
	done
	return 1
}

# jm_need <binary...> - fail fast with a clear message instead of cryptic errors
jm_need() {
	_missing=""
	for _b in "$@"; do
		command -v "$_b" >/dev/null 2>&1 || _missing="$_missing $_b"
	done
	[ -z "$_missing" ] && return 0
	jm_error "missing required tool(s):$_missing"
	return 1
}

# jm_is_protected_path <relative-path>
# The updater must never touch user data. Single authoritative definition.
jm_is_protected_path() {
	case "$1" in
	Roms/* | BIOS/* | Saves/* | States/* | Pictures/* | Themes/* | \
		Backgrounds/* | Icons/* | Profiles/* | Data/ports/* | \
		Best/* | *.sav | *.srm | *.state*)
		return 0
		;;
	esac
	return 1
}
