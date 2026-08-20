#!/bin/sh
# JukaMix OS - PortMaster preflight validator.
#
# Checks whether a given PortMaster port is runnable on this device: presence
# of launcher, compatibility-matrix status for the current device/version,
# required runtime availability, and (when an ELF launcher is present) shared
# library resolution via ldd.
#
# Read-only: it never modifies the port, runtime, or filesystem.
# Exit code: 0 = ok/pass, 1 = problems detected, 2 = usage error.

set -u

TOOLS_DIR=${0%/*}
[ "$TOOLS_DIR" = "$0" ] && TOOLS_DIR=.
# shellcheck source=lib/jukamix-common.sh
. "$TOOLS_DIR/lib/jukamix-common.sh"

PATH="$JUKAMIX_BIN:$PATH"
export LD_LIBRARY_PATH="$JUKAMIX_LIB:/usr/trimui/lib:${LD_LIBRARY_PATH:-}"

PORT_ARG=""
JSON=0
QUIET_OVERRIDE=0
VERBOSE_OVERRIDE=0

while [ $# -gt 0 ]; do
	case "$1" in
		-h|--help) sed -n '2,30p' "$0"; exit 0 ;;
		--port) PORT_ARG="$2"; shift ;;
		--json) JSON=1 ;;
		-q|--quiet) QUIET_OVERRIDE=1 ;;
		-v|--verbose) VERBOSE_OVERRIDE=1 ;;
		*) jukamix_log ERROR "unknown argument: $1"; exit 2 ;;
	esac
	shift
done

[ "$QUIET_OVERRIDE" = "1" ] && JUKAMIX_QUIET=1
[ "$VERBOSE_OVERRIDE" = "1" ] && JUKAMIX_VERBOSE=1

if [ -z "$PORT_ARG" ]; then
	jukamix_log ERROR "provide --port <name-or-path>"
	exit 2
fi

jukamix_init_log "jukamix-portmaster-check"
jukamix_begin

# Resolve the port directory.
PORT_DIR="$PORT_ARG"
if [ ! -d "$PORT_DIR" ]; then
	# Treat as a name under the PortMaster tree.
	if [ -d "$JUKAMIX_PORTMASTER/$PORT_ARG" ]; then
		PORT_DIR="$JUKAMIX_PORTMASTER/$PORT_ARG"
	else
		jukamix_log ERROR "port not found: $PORT_ARG"
		exit 1
	fi
fi

PROBLEMS=0
OKS=0

emit() {
	_st="$1"; _msg="$2"
	if [ "$_st" = "OK" ]; then OKS=$((OKS+1)); else PROBLEMS=$((PROBLEMS+1)); fi
	if [ "$JSON" = "1" ]; then
		printf '{"status":"%s","message":"%s"}\n' "$_st" "$_msg"
	else
		printf '[%s] %s\n' "$_st" "$_msg" >&2
	fi
	unset _st _msg
}

# 1. Launcher presence
LAUNCHER=""
for _sh in "$PORT_DIR"/*.sh; do
	[ -f "$_sh" ] && LAUNCHER="$_sh" && break
done
if [ -n "$LAUNCHER" ]; then
	emit OK "launcher present: ${LAUNCHER##*/}"
else
	emit FAIL "no .sh launcher found in $PORT_DIR"
fi

PORT_NAME=${PORT_DIR##*/}

# 2. Compatibility matrix
MF="$TOOLS_DIR/data/portmaster-compatibility.txt"
if [ -f "$MF" ]; then
	_match=""
	while IFS='|' read -r _p _dev _fw _jv _pv _rt _st _lim _date _ev; do
		case "$_p" in \#*|"") continue ;; esac
		if [ "$_p" = "$PORT_NAME" ] || [ "$_p" = "-" ]; then
			# device-specific or generic baseline
			if [ "$_dev" = "-" ] || [ "$_dev" = "$JUKAMIX_DEVICE" ]; then
				_match="$_st|$_lim|$_rt|$_jv"
				break
			fi
		fi
	done <"$MF"
	if [ -n "$_match" ]; then
		# Split the pipe-delimited match with parameter expansion (no cut forks).
		_rest=$_match
		_st=${_rest%%|*}; _rest=${_rest#*|}
		_lim=${_rest%%|*}; _rest=${_rest#*|}
		_rt=${_rest%%|*}; _rest=${_rest#*|}
		_jv=$_rest
		case "$_st" in
			PASS) emit OK "compatibility: PASS" ;;
			WARN) emit OK "compatibility: WARN ($_lim)" ;;
			FAIL) emit FAIL "compatibility: FAIL ($_lim)" ;;
			*) emit OK "compatibility: UNTESTED" ;;
		esac
		# version gate
		if [ -n "$_jv" ] && [ "$_jv" != "-" ] && [ "$JUKAMIX_VERSION" != "UNKNOWN" ]; then
			# crude numeric compare: only warn if manifest requires > current
			_req=$(echo "$_jv" | tr -d 'vV')
			_cur=$(echo "$JUKAMIX_VERSION" | tr -d 'vV')
			if [ "$(printf '%s\n%s\n' "$_req" "$_cur" | sort -t. -k1,1 -k2,2 -k3,3 -n | tail -n1)" != "$_cur" ]; then
				emit FAIL "requires JukaMix OS >= $_jv (have $JUKAMIX_VERSION)"
			fi
		fi
		# runtime check
		if [ -n "$_rt" ] && [ "$_rt" != "-" ]; then
			if [ -d "$JUKAMIX_PORTMASTER/runtimes/$_rt" ]; then
				emit OK "runtime present: $_rt"
			else
				emit FAIL "runtime missing: $_rt"
			fi
		fi
	else
		emit OK "no compatibility entry (treated as UNTESTED)"
	fi
else
	emit OK "compatibility manifest not found (skipping)"
fi

# 3. ldd on an ELF launcher if present
if [ -n "$LAUNCHER" ] && jukamix_have_cmd ldd; then
	# Only inspect if it's an ELF binary (skip shell wrappers)
	if head -c 4 "$LAUNCHER" 2>/dev/null | grep -q 'ELF'; then
		_miss=$(ldd "$LAUNCHER" 2>/dev/null | grep -i 'not found' | wc -l)
		if [ "$_miss" -gt 0 ]; then
			emit FAIL "launcher has $_miss unresolved shared libraries"
		else
			emit OK "launcher libraries resolve"
		fi
	fi
fi

# 4. Disk space sanity (need room for runtime extraction)
_FREE=$(jukamix_free_space_mb "$JUKAMIX_PORTMASTER")
if [ "$_FREE" != "0" ] && [ "$_FREE" != "" ]; then
	if [ "$_FREE" -lt 256 ]; then
		emit FAIL "low free space in PortMaster area: ${_FREE} MB"
	else
		emit OK "free space: ${_FREE} MB"
	fi
fi

if [ "$PROBLEMS" -gt 0 ]; then
	exit 1
fi
exit 0
