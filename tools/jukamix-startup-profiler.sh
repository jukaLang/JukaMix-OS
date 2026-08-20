#!/bin/sh
# JukaMix OS - startup / command profiler (non-destructive).
#
# Measures execution time of a provided command and records the result in a
# profiler log under the support directory. It can also report previously
# recorded samples. This never modifies system state or user data.
#
# Exit code: 0 = ok, 1 = measured command failed, 2 = usage error.

set -u

TOOLS_DIR=${0%/*}
[ "$TOOLS_DIR" = "$0" ] && TOOLS_DIR=.
# shellcheck source=lib/jukamix-common.sh
. "$TOOLS_DIR/lib/jukamix-common.sh"

PATH="$JUKAMIX_BIN:$PATH"
export LD_LIBRARY_PATH="$JUKAMIX_LIB:/usr/trimui/lib:${LD_LIBRARY_PATH:-}"

RUN=""
REPORT=0
LABEL=""
QUIET_OVERRIDE=0
VERBOSE_OVERRIDE=0

while [ $# -gt 0 ]; do
	case "$1" in
		-h|--help) sed -n '2,30p' "$0"; exit 0 ;;
		--run) RUN="$2"; shift ;;
		--label) LABEL="$2"; shift ;;
		--report) REPORT=1 ;;
		-q|--quiet) QUIET_OVERRIDE=1 ;;
		-v|--verbose) VERBOSE_OVERRIDE=1 ;;
		*) jukamix_log ERROR "unknown argument: $1"; exit 2 ;;
	esac
	shift
done

[ "$QUIET_OVERRIDE" = "1" ] && JUKAMIX_QUIET=1
[ "$VERBOSE_OVERRIDE" = "1" ] && JUKAMIX_VERBOSE=1

jukamix_init_log "jukamix-startup-profiler"
jukamix_begin

PROFILER_LOG="$JUKAMIX_SUPPORT/startup-profile.log"
mkdir -p "$JUKAMIX_SUPPORT" 2>/dev/null

if [ "$REPORT" = "1" ]; then
	if [ -f "$PROFILER_LOG" ]; then
		cat "$PROFILER_LOG" >&2
	else
		jukamix_log INFO "no profiler samples recorded yet"
	fi
	exit 0
fi

if [ -z "$RUN" ]; then
	jukamix_log ERROR "provide --run <command> (optionally --label <name>)"
	exit 2
fi

[ -z "$LABEL" ] && LABEL="$RUN"
jukamix_log INFO "profiling: $LABEL"

_start=$(date +%s%N 2>/dev/null)
case $_start in ''|*[!0-9]*) _start=$(date +%s);; esac
$RUN
_RC=$?
_stop=$(date +%s%N 2>/dev/null)
case $_stop in ''|*[!0-9]*) _stop=$(date +%s);; esac

# Normalize to milliseconds. On GNU hosts %s%N yields seconds(10)+nanoseconds(9)
# digits; stripping the final 6 digits converts ns -> ms. On shells without
# %N (BusyBox prints a literal 'N'), the case above already fell back to plain
# seconds, so we multiply by 1000.
if [ ${#_start} -gt 12 ]; then
	_ms=$(( (${_stop%??????} - ${_start%??????}) ))
else
	_ms=$(( (_stop - _start) * 1000 ))
fi

_TS=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
printf '%s | %s | rc=%s | %s ms\n' "$_TS" "$LABEL" "$_RC" "$_ms" >>"$PROFILER_LOG" 2>/dev/null
jukamix_log INFO "elapsed: ${_ms} ms (exit $_RC)"

if [ "$_RC" -ne 0 ]; then
	exit 1
fi
exit 0
