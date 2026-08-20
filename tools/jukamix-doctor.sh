#!/bin/sh
# JukaMix OS - system doctor (read-only diagnostics).
#
# Performs a safe, read-only sweep over the JukaMix OS installation and
# writes a privacy-conscious support report. It never modifies files, never
# uploads anything, and never logs ROM names, BIOS contents, or secrets.
#
# Exit codes: 0 = healthy, 1 = issues found, 2 = usage/setup error.

set -u

TOOLS_DIR=${0%/*}
[ "$TOOLS_DIR" = "$0" ] && TOOLS_DIR=.
# shellcheck source=lib/jukamix-common.sh
. "$TOOLS_DIR/lib/jukamix-common.sh"

# Make device binaries available to the checks below.
PATH="$JUKAMIX_BIN:$PATH"
export LD_LIBRARY_PATH="$JUKAMIX_LIB:/usr/trimui/lib:${LD_LIBRARY_PATH:-}"

DRY_RUN=0
OUTPUT=""
NO_REPORT=0
SECTIONS=""
VERBOSE_OVERRIDE=0
QUIET_OVERRIDE=0
ARCHIVE=0
ARCHIVE_OUT=""

while [ $# -gt 0 ]; do
	case "$1" in
		-h|--help) sed -n '2,40p' "$0"; exit 0 ;;
		-q|--quiet) QUIET_OVERRIDE=1 ;;
		-v|--verbose) VERBOSE_OVERRIDE=1 ;;
		--dry-run) DRY_RUN=1 ;;
		--no-report) NO_REPORT=1 ;;
		--archive) ARCHIVE=1 ;;
		--archive-output) ARCHIVE_OUT="$2"; shift ;;
		--section) SECTIONS="$2"; shift ;;
		--output) OUTPUT="$2"; shift ;;
		*) jukamix_log ERROR "unknown argument: $1"; exit 2 ;;
	esac
	shift
done

[ "$QUIET_OVERRIDE" = "1" ] && JUKAMIX_QUIET=1
[ "$VERBOSE_OVERRIDE" = "1" ] && JUKAMIX_VERBOSE=1

jukamix_init_log "jukamix-doctor"
if [ "$NO_REPORT" = "0" ]; then
	jukamix_init_report "$OUTPUT"
fi

jukamix_begin

REPORT_ID=$(jukamix_report_id)

# Counters
ERRS=0
WARNS=0
OKS=0

report_line() { jukamix_report "$1"; }

# Emit a check result: status, section, message
emit() {
	_st="$1"; _sec="$2"; _msg="$3"
	case "$_st" in
		PASS) OKS=$((OKS+1)) ;;
		WARN) WARNS=$((WARNS+1)) ;;
		FAIL) ERRS=$((ERRS+1)) ;;
	esac
	if [ "$JUKAMIX_QUIET" != "1" ]; then
		printf '[%s] %s: %s\n' "$_st" "$_sec" "$_msg" >&2
	fi
	report_line "[$_st] $_sec: $_msg"
	unset _st _sec _msg
}

should_run() {
	_s="$1"
	if [ -z "$SECTIONS" ]; then
		return 0
	fi
	# SECTIONS is comma separated
	OLDIFS="$IFS"; IFS=","
	for _x in $SECTIONS; do
		if [ "$_x" = "$_s" ]; then
			IFS="$OLDIFS"; return 0
		fi
	done
	IFS="$OLDIFS"
	return 1
}

# ---------------------------------------------------------------------------
# Section: environment
# ---------------------------------------------------------------------------
sec_environment() {
	[ -d "$JUKAMIX_ROOT" ] || { emit FAIL env "root not found: $JUKAMIX_ROOT"; return; }
	emit PASS env "root directory present: $JUKAMIX_ROOT"
	[ -d "$JUKAMIX_SYSTEM" ] && emit PASS env "System directory present" || emit FAIL env "System directory missing"
	[ -d "$JUKAMIX_SCRIPTS" ] && emit PASS env "scripts directory present" || emit WARN env "scripts directory missing"
	# version
	if [ "$JUKAMIX_VERSION" != "UNKNOWN" ]; then
		emit PASS env "JukaMix OS version detected: $JUKAMIX_VERSION"
	else
		emit WARN env "version file not detected"
	fi
	# device
	if [ "$JUKAMIX_DEVICE" != "UNKNOWN" ]; then
		emit PASS env "device detected: $JUKAMIX_DEVICE ($JUKAMIX_DEVICE_NAME)"
	else
		emit WARN env "device not detected (running off-device?)"
	fi
	emit PASS env "architecture: $JUKAMIX_ARCH"
	[ "$JUKAMIX_FIRMWARE" != "UNKNOWN" ] && emit PASS env "firmware: $JUKAMIX_FIRMWARE" || emit WARN env "firmware not detected"
}

# ---------------------------------------------------------------------------
# Section: binaries
# ---------------------------------------------------------------------------
sec_binaries() {
	_missing=$(jukamix_require_cmds sh awk sed grep find df jq)
	if [ -n "$_missing" ]; then
		for _m in $_missing; do
			emit WARN bins "recommended command not found: $_m"
		done
	fi
	[ -x "$JUKAMIX_SEVENZ" ] && emit PASS bins "7zz present" || emit WARN bins "7zz not found at $JUKAMIX_SEVENZ"
	[ -x "$JUKAMIX_JQ" ] && emit PASS bins "jq present" || emit WARN bins "jq not found at $JUKAMIX_JQ"
	# ldconfig / ldd can help diagnose missing libs
	jukamix_have_cmd ldd && emit PASS bins "ldd available" || emit WARN bins "ldd not available"
}

# ---------------------------------------------------------------------------
# Section: retroarch
# ---------------------------------------------------------------------------
sec_retroarch() {
	[ -d "$JUKAMIX_RETROARCH" ] && emit PASS retroarch "RetroArch directory present" || { emit FAIL retroarch "RetroArch directory missing"; return; }
	[ -f "$JUKAMIX_RETROARCH/retroarch.cfg" ] && emit PASS retroarch "global retroarch.cfg present" || emit WARN retroarch "global retroarch.cfg missing"
	[ -d "$JUKAMIX_RA_HOME/cores" ] && emit PASS retroarch "cores directory present" || emit WARN retroarch "cores directory missing"
	[ -d "$JUKAMIX_RA_HOME/config" ] && emit PASS retroarch "core config overrides present" || emit WARN retroarch "core config overrides missing"
	# sanity: count cores
	if [ -d "$JUKAMIX_RA_HOME/cores" ]; then
		_n=$(ls "$JUKAMIX_RA_HOME/cores" 2>/dev/null | grep -c '\.so$' || true)
		emit PASS retroarch "installed cores: $_n"
	fi
	# overlay / shader presence (optional)
	[ -d "$JUKAMIX_RA_HOME/overlay" ] && emit PASS retroarch "overlays present" || emit WARN retroarch "overlays missing"
	[ -d "$JUKAMIX_RA_HOME/shaders" ] && emit PASS retroarch "shaders present" || emit WARN retroarch "shaders missing"
}

# ---------------------------------------------------------------------------
# Section: bios (presence only, never contents)
# ---------------------------------------------------------------------------
sec_bios() {
	if [ ! -d "$JUKAMIX_BIOS" ]; then
		emit WARN bios "BIOS directory missing"
		return
	fi
	_total=$(find "$JUKAMIX_BIOS" -type f 2>/dev/null | wc -l)
	if [ "$_total" -eq 0 ]; then
		emit WARN bios "BIOS directory is empty"
	else
		emit PASS bios "BIOS files present: $_total"
	fi
	# Manifest-based expected list (presence only).
	_mf="$TOOLS_DIR/data/bios-manifest.txt"
	if [ -f "$_mf" ]; then
		_exp=0; _have=0
		while IFS='|' read -r _sys _fn _rest; do
			[ -z "$_sys" ] && continue
			case "$_sys" in \#*) continue ;; esac
			_exp=$((_exp+1))
			if [ -f "$JUKAMIX_BIOS/$_fn" ]; then
				_have=$((_have+1))
			fi
		done <"$_mf"
		if [ "$_exp" -gt 0 ]; then
			if [ "$_have" -eq "$_exp" ]; then
				emit PASS bios "manifest match: $_have/$_exp expected files present"
			else
				emit WARN bios "manifest match: $_have/$_exp expected files present"
			fi
		fi
		unset _exp _have _sys _fn _rest
	fi
	unset _total _mf
}

# ---------------------------------------------------------------------------
# Section: portmaster
# ---------------------------------------------------------------------------
sec_portmaster() {
	if [ ! -d "$JUKAMIX_PORTMASTER" ]; then
		emit WARN portmaster "PortMaster directory not found (run jm-portmaster install)"
		return
	fi
	emit PASS portmaster "PortMaster directory present"
	# bundled PortMaster version
	_pmv=""
	[ -f "$JUKAMIX_PORTMASTER/version" ] && _pmv=$(tr -d '[:space:]' < "$JUKAMIX_PORTMASTER/version" 2>/dev/null)
	if [ -n "$_pmv" ]; then
		emit PASS portmaster "PortMaster version: $_pmv"
	else
		emit WARN portmaster "PortMaster version file missing"
	fi
	# core GUI binary
	if [ -x "$JUKAMIX_PORTMASTER/pugwash" ]; then
		emit PASS portmaster "PortMaster GUI binary present (pugwash)"
	else
		emit FAIL portmaster "PortMaster GUI binary missing (pugwash) - run jm-portmaster fix"
	fi
	# ports storage (Data/ports is where installed ports live)
	if [ -d "$JUKAMIX_ROOT/Data/ports" ]; then
		emit PASS portmaster "ports directory present: Data/ports"
	else
		emit WARN portmaster "ports directory missing: Data/ports (run jm-portmaster fix)"
	fi
	# PORTS-tab entry point
	if [ -f "$JUKAMIX_ROMS/PORTS/PortMaster.sh" ]; then
		emit PASS portmaster "PORTS-tab entry point present"
	else
		emit WARN portmaster "PORTS-tab entry point missing (run jm-portmaster fix)"
	fi
	# count runnable ports (directories with a .sh launcher); glob + test are
	# builtins, replacing a per-directory ls|head pipeline
	_n=0
	if [ -d "$JUKAMIX_PORTMASTER" ]; then
		for _d in "$JUKAMIX_PORTMASTER"/*/; do
			[ -d "$_d" ] || continue
			for _f in "$_d"*.sh; do
				[ -f "$_f" ] && { _n=$((_n+1)); break; }
			done
		done
	fi
	emit PASS portmaster "detected port launchers: $_n"
	# runtime detection
	if [ -d "$JUKAMIX_PORTMASTER/runtimes" ]; then
		_rt=$(ls "$JUKAMIX_PORTMASTER/runtimes" 2>/dev/null | wc -l)
		emit PASS portmaster "PortMaster runtimes present: $_rt"
	else
		emit WARN portmaster "no PortMaster runtimes directory"
	fi
	unset _pmv _n _d _sh _rt _f
}

# ---------------------------------------------------------------------------
# Section: storage
# ---------------------------------------------------------------------------
sec_storage() {
	_fs=$(jukamix_free_space_mb "$JUKAMIX_ROOT")
	if [ "$_fs" = "0" ] || [ -z "$_fs" ]; then
		emit WARN storage "could not determine free space for $JUKAMIX_ROOT"
	else
		emit PASS storage "free space on $JUKAMIX_ROOT: ${_fs} MB"
		if [ "$_fs" -lt 512 ]; then
			emit WARN storage "free space is low (<512 MB)"
		fi
	fi
	# read-only check (best effort)
	if touch "$JUKAMIX_ROOT/.jukamix_writetest" 2>/dev/null; then
		rm -f "$JUKAMIX_ROOT/.jukamix_writetest" 2>/dev/null
		emit PASS storage "filesystem writable"
	else
		emit WARN storage "filesystem appears read-only at $JUKAMIX_ROOT"
	fi
	unset _fs
}

# ---------------------------------------------------------------------------
# Section: themes
# ---------------------------------------------------------------------------
sec_themes() {
	[ -d "$JUKAMIX_THEMES" ] || { emit WARN themes "Themes directory missing"; return; }
	_n=$(find "$JUKAMIX_THEMES" -maxdepth 1 -type d 2>/dev/null | wc -l)
	emit PASS themes "themes found: $((_n-1))"
}

# ---------------------------------------------------------------------------
# Section: installed packages (JukaHub index)
# ---------------------------------------------------------------------------
sec_packages() {
	_idx="$JUKAMIX_ROOT/Apps/JukaHub/patch/packages.json"
	[ -f "$_idx" ] || { emit WARN packages "JukaHub index not found at $_idx"; return; }
	if jukamix_have_cmd jq; then
		_list=$(jq -r '.packages[]? | "  \(.id) \(.version) - \(.name)"' "$_idx" 2>/dev/null)
		if [ -n "$JUKAMIX_REPORT" ]; then
			jukamix_report "Packages:"
			printf '%s\n' "$_list" >> "$JUKAMIX_REPORT" 2>/dev/null
		fi
		_n=$(printf '%s\n' "$_list" | sed '/^$/d' | wc -l)
		emit PASS packages "installed packages: $_n"
	else
		emit WARN packages "jq unavailable; cannot parse index"
	fi
	unset _idx _list _n
}

# ---------------------------------------------------------------------------
# Section: emulators
# ---------------------------------------------------------------------------
sec_emulators() {
	_e="$JUKAMIX_ROOT/Emus"
	[ -d "$_e" ] || { emit WARN emulators "Emus directory not found at $_e"; return; }
	_n=$(ls -1 "$_e" 2>/dev/null | wc -l)
	emit PASS emulators "emulator folders: $_n"
	unset _e _n
}

# ---------------------------------------------------------------------------
# Section: temperature (best effort)
# ---------------------------------------------------------------------------
sec_temperature() {
	_found=0
	for _z in /sys/class/thermal/thermal_zone*/temp; do
		[ -r "$_z" ] || continue
		_v=$(cat "$_z" 2>/dev/null)
		case "$_v" in ''|*[!0-9]*) continue ;; esac
		emit PASS thermal "$(basename "$_z"): $(( _v / 1000 )) C"
		_found=1
	done
	[ "$_found" = "0" ] && emit WARN thermal "no readable thermal sensors"
	unset _z _v _found
}

# ---------------------------------------------------------------------------
# Section: recent errors (from support logs, redacted)
# ---------------------------------------------------------------------------
sec_errors() {
	_d="$JUKAMIX_SUPPORT"
	[ -d "$_d" ] || { emit WARN errors "no support log directory at $_d"; return; }
	_found=0
	for _lf in "$_d"/*.log; do
		[ -f "$_lf" ] || continue
		_found=1
		emit PASS errors "log present: $(basename "$_lf")"
		report_line "--- $(basename "$_lf") (tail, redacted) ---"
		tail -n 15 "$_lf" 2>/dev/null | jukamix_redact_values >> "$JUKAMIX_REPORT" 2>/dev/null
	done
	[ "$_found" = "0" ] && emit WARN errors "no logs found in $_d"
	unset _d _lf _found
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
report_line "=============================================="
report_line " JukaMix OS Doctor Report"
report_line " REPORT_ID: $REPORT_ID"
report_line " Generated: $(date 2>/dev/null)"
report_line " Device: $JUKAMIX_DEVICE ($JUKAMIX_DEVICE_NAME)"
report_line " Arch: $JUKAMIX_ARCH | FW: $JUKAMIX_FIRMWARE | Ver: $JUKAMIX_VERSION"
report_line " Root: $JUKAMIX_ROOT"
report_line "=============================================="
report_line ""

should_run env && sec_environment
report_line ""
should_run bins && sec_binaries
report_line ""
should_run retroarch && sec_retroarch
report_line ""
should_run bios && sec_bios
report_line ""
should_run portmaster && sec_portmaster
report_line ""
should_run storage && sec_storage
report_line ""
should_run themes && sec_themes
report_line ""
should_run packages && sec_packages
report_line ""
should_run emulators && sec_emulators
report_line ""
should_run temperature && sec_temperature
report_line ""
should_run errors && sec_errors
report_line ""
report_line "=============================================="
report_line " Summary: $OKS OK, $WARNS warnings, $ERRS errors"
report_line " REPORT_ID: $REPORT_ID"
report_line "=============================================="

if [ "$NO_REPORT" = "0" ] && [ -n "${JUKAMIX_REPORT:-}" ]; then
	jukamix_log INFO "report written to $JUKAMIX_REPORT"
fi

# Package the report into a single archive suitable for a GitHub issue.
if [ "$ARCHIVE" = "1" ] && [ -n "${JUKAMIX_REPORT:-}" ] && [ -f "$JUKAMIX_REPORT" ]; then
	_out="${ARCHIVE_OUT:-$JUKAMIX_SUPPORT/jukamix-diag-${REPORT_ID}.txt.gz}"
	mkdir -p "${_out%/*}" 2>/dev/null
	if jukamix_have_cmd gzip; then
		gzip -c "$JUKAMIX_REPORT" > "$_out" 2>/dev/null && jukamix_log INFO "diagnostics archive: $_out"
	else
		cp "$JUKAMIX_REPORT" "${_out%.gz}" 2>/dev/null && _out="${_out%.gz}" && jukamix_log INFO "diagnostics report: $_out"
	fi
	printf '%s\n' "$_out"
fi

if [ "$ERRS" -gt 0 ]; then
	exit 1
elif [ "$WARNS" -gt 0 ]; then
	exit 1
fi
exit 0
