#!/bin/sh
# JukaMix OS - Safe Mode & Recovery library
#
# Provides crash detection, "reset to defaults", last-known-good restore, and
# repair-from-manifest. It is deliberately conservative:
#   * Every destructive action requires an explicit confirmation.
#   * ROMs, BIOS files, saves, and other user assets are NEVER touched.
#
# POSIX sh (BusyBox ash / dash). Source this file; do not exec it.

if [ "${0##*/}" = "jukamix-recovery.sh" ]; then
	cat >&2 <<'NOTE'
jukamix-recovery.sh is a library. Source it from another script, e.g.:
  . "$JUKAMIX_LIB_DIR/jukamix-recovery.sh"
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

JUKAMIX_STATE="${JUKAMIX_STATE:-$JUKAMIX_SUPPORT/state}"
JUKAMIX_CRASH_THRESHOLD="${JUKAMIX_CRASH_THRESHOLD:-3}"

# Lightweight pre-change snapshot of the JukaMix-managed config files.
# (Separate from jukamix-backup.sh, which archives user data sets.)
jukamix_backup_snapshot() {
	_tag="${1:-snapshot}"
	_bdir="$JUKAMIX_SUPPORT/backups"
	mkdir -p "$_bdir" 2>/dev/null
	_ts=$(date +%Y%m%d-%H%M%S)
	for _f in \
		"$JUKAMIX_ETC/jukamix.json" \
		"$JUKAMIX_SYSTEM/etc/jukamix.json" \
		"$JUKAMIX_RA_HOME/retroarch.cfg"; do
		[ -f "$_f" ] && cp -p "$_f" "$_bdir/${_f##*/}.$_tag.$_ts.bak" 2>/dev/null
	done
	jukamix_log INFO "snapshot '$_tag' saved to $_bdir"
	unset _tag _bdir _ts _f
}

# ---- small key=value state store -------------------------------------------
jukamix_state_get() {
	_k="$1"; _f="$JUKAMIX_STATE"
	[ -f "$_f" ] || { printf ''; return 1; }
	# Single awk pass (was grep|tail|sed); index() is literal, so keys with
	# regex metacharacters stay safe and values may contain '='.
	_v=$(awk -v k="$_k=" 'index($0,k)==1 { v=substr($0,length(k)+1) } END { print v }' "$_f" 2>/dev/null)
	printf '%s' "$_v"
	unset _k _f _v
}
jukamix_state_set() {
	_k="$1"; _v="$2"; _f="$JUKAMIX_STATE"
	mkdir -p "${_f%/*}" 2>/dev/null
	# Portable atomic rewrite (no grep -q + grep -v double scan, no sed -i).
	_tmp="$_f.tmp.$$"; _tac=""
	[ -f "$_f" ] && _tac=$(awk -v k="$_k=" 'index($0,k)!=1 { print }' "$_f" 2>/dev/null)
	{
		[ -n "$_tac" ] && printf '%s\n' "$_tac"
		printf '%s=%s\n' "$_k" "$_v"
	} > "$_tmp" 2>/dev/null && mv -f "$_tmp" "$_f" 2>/dev/null
	unset _k _v _f _tac _tmp
}

# ---- crash detection --------------------------------------------------------
# A "crash" is a boot that never reached a clean exit. We count boots and track
# the last boot that exited cleanly; the crash count is derived from the gap.
jukamix_boot_begin() {
	jukamix_state_set boot_count $(( $(jukamix_state_get boot_count 2>/dev/null || echo 0) + 1 ))
}
jukamix_boot_ok() {
	jukamix_state_set last_ok_boot "$(jukamix_state_get boot_count 2>/dev/null || echo 0)"
	jukamix_state_set crash_count 0
}
jukamix_crash_count() {
	_b=$(jukamix_state_get boot_count 2>/dev/null || echo 0)
	_o=$(jukamix_state_get last_ok_boot 2>/dev/null || echo 0)
	_c=$(( _b - _o )); [ "$_c" -lt 0 ] && _c=0
	printf '%s\n' "$_c"
	unset _b _o _c
}
jukamix_safe_mode_active() {
	_c=$(jukamix_crash_count)
	[ "$_c" -ge "$JUKAMIX_CRASH_THRESHOLD" ] 2>/dev/null && return 0
	return 1
}

# ---- JSON key setter (jq when present, sed fallback) ------------------------
jukamix_json_set() {
	_f="$1"; _k="$2"; _v="$3"
	[ -f "$_f" ] || return 1
	if jukamix_have_cmd jq; then
		_t="$JUKAMIX_TMPBASE/.$JUKAMIX_PREFIXjson.$$"
		jq --arg k "$_k" --arg v "$_v" '.[$k]=$v' "$_f" > "$_t" 2>/dev/null && mv -f "$_t" "$_f" && return 0
	fi
	# fallback: replace "key": "anything"
	sed -i "s/\(\"$_k\"[[:space:]]*:[[:space:]]*\"\)[^\"]*\(\"\)/\1$_v\2/" "$_f" 2>/dev/null
	unset _f _k _v _t
}

# ---- reset to defaults ------------------------------------------------------
# Resets JukaMix-managed configuration (theme, RetroArch, Control Center mode).
# Never touches ROMs / BIOS / Saves / user assets.
jukamix_reset_defaults() {
	[ "$(jukamix_confirm 'Reset JukaMix to default theme, controls layout and RetroArch config? This keeps your ROMs, BIOS and saves.')" = "yes" ] || { jukamix_log INFO "reset-defaults cancelled"; return 0; }

	# 1. snapshot current config set first
	jukamix_backup_snapshot "pre-reset" 2>/dev/null

	# 2. theme -> Default (both known keys)
	for _cf in "$JUKAMIX_ETC/jukamix.json" "$JUKAMIX_SYSTEM/etc/jukamix.json"; do
		[ -f "$_cf" ] || continue
		jukamix_backup_file "$_cf" 2>/dev/null
		jukamix_json_set "$_cf" "THEMES" "Default"
		jukamix_json_set "$_cf" "THEME PACK" "Default"
	done

	# 3. RetroArch: back up and remove user configuration so stock defaults load
	if [ -f "$JUKAMIX_RA_HOME/retroarch.cfg" ]; then
		jukamix_backup_file "$JUKAMIX_RA_HOME/retroarch.cfg" 2>/dev/null
		rm -f "$JUKAMIX_RA_HOME/retroarch.cfg" 2>/dev/null
	fi
	if [ -d "$JUKAMIX_RA_HOME/config" ]; then
		_bk="$JUKAMIX_SUPPORT/backups/retroarch-config.$(date +%Y%m%d-%H%M%S).bak"
		mkdir -p "${_bk%/*}" 2>/dev/null
		cp -r "$JUKAMIX_RA_HOME/config" "$_bk" 2>/dev/null
		rm -rf "$JUKAMIX_RA_HOME/config" 2>/dev/null
	fi

	# 4. Control Center mode back to simple
	jukamix_state_set cc_mode simple

	jukamix_log INFO "reset to defaults complete"
	jukamix_notify "JukaMix reset to defaults. ROMs, BIOS and saves were kept."
	unset _cf _bk
}

# ---- last-known-good restore ------------------------------------------------
jukamix_last_known_good_list() {
	_d="$JUKAMIX_SUPPORT/backups"
	[ -d "$_d" ] || return 0
	ls -1t "$_d"/*.7z "$_d"/*.zip 2>/dev/null
	unset _d
}
jukamix_restore_last_known_good() {
	_latest=$(jukamix_last_known_good_list 2>/dev/null | head -n1)
	[ -n "$_latest" ] || { jukamix_log WARN "no backup archive found"; return 1; }
	if [ "$(jukamix_confirm "Restore configuration from $(basename "$_latest")? Existing config will be backed up first.")" = "yes" ]; then
		if jukamix_have_cmd 7zz && [ -x "$JUKAMIX_SEVENZ" ]; then
			jukamix_backup_snapshot "pre-restore" 2>/dev/null
			"$JUKAMIX_SEVENZ" x -y -o"$JUKAMIX_ROOT" "$_latest" >/dev/null 2>&1
			jukamix_log INFO "restored from $_latest"
			jukamix_notify "Configuration restored from backup."
		else
			jukamix_log WARN "7zz not available; cannot extract $_latest"
			return 1
		fi
	fi
	unset _latest
}

# ---- repair JukaMix-owned files from a verified manifest --------------------
jukamix_repair_owned() {
	_src="${1:-}"
	[ "$(jukamix_confirm 'Repair JukaMix-owned system files from a verified manifest? User data is never modified.')" = "yes" ] || return 0
	if [ -z "$_src" ]; then
		jukamix_log WARN "repair needs a verified source tree (update package); none provided"
		jukamix_notify "Provide the verified update package to repair files."
		return 1
	fi
	"$JUKAMIX_TOOLS_DIR/jukamix-manifest.sh" --repair --source "$_src" 2>&1
	unset _src
}
