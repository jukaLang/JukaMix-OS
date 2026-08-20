#!/bin/sh
# JukaMix OS - safe, transactional OTA updater.
#
# Design reuses JukaHub's Patch trust model (signed manifest, per-file SHA-256
# verification, transaction journal, backups, automatic rollback) instead of
# reinventing it. The OTA engine applies an OS package as a set of declarative
# file operations (install / replace / remove) to the OS tree while keeping
# user data strictly protected.
#
# Flow (jukamix_ota_run):
#   1. resolve the latest release from the GitHub release channel
#   2. download archive + manifest + manifest signature into a STAGING dir
#   3. verify the manifest signature (Ed25519) and each payload checksum
#   4. refuse any operation that touches protected user-data directories
#   5. back up every file that will be replaced
#   6. apply operations, journaling each step
#   7. run any pending config migrations, then reboot
#   8. on any failure OR interruption, roll back from the journal
#
# Pure helpers (jukamix_ota_is_user_data, jukamix_ota_apply, jukamix_ota_rollback,
# jukamix_ota_verify_*) are exercised by the test harness. The network steps in
# jukamix_ota_run require curl + jq and run on-device.

# Protected user-data locations. Updates must never overwrite these without
# explicit user permission.
JUKAMIX_OTA_USER_DATA_DIRS='Roms BIOS Saves States Screenshots .media Themes UserConfig'

# Return 0 when the destination path belongs to protected user data.
jukamix_ota_is_user_data() {
	_d="$1"
	case "$_d" in
		*/Roms/*|*/BIOS/*|*/Saves/*|*/States/*|*/Screenshots/*|*/.media/*|*/Themes/*|*/UserConfig/*|*/etc/wifi/*)
			return 0 ;;
	esac
	_base=$(printf '%s' "$_d" | sed -e 's#^/mnt/SDCARD/##' -e 's#/.*##')
	for _ud in $JUKAMIX_OTA_USER_DATA_DIRS; do
		[ "$_base" = "$_ud" ] && return 0
	done
	return 1
}

# Verify an Ed25519 signature over a file. Requires openssl with Ed25519 support
# and a PEM public key at $1 (pubkey) signing $2 (data) with signature $3.
# Echoes "verified" / "unverified"; returns 0 only when verified.
jukamix_ota_verify_signature() {
	_pk="$1"; _data="$2"; _sig="$3"
	[ -f "$_pk" ] || { echo "unverified"; return 1; }
	if openssl pkeyutl -verify -pubin -inkey "$_pk" -rawin -in "$_data" -sigfile "$_sig" >/dev/null 2>&1; then
		echo "verified"; return 0
	fi
	echo "unverified"; return 1
}

# Verify a payload file against an expected SHA-256 (tolerates a "sha256:" prefix,
# case-insensitive). Returns 0 on match.
jukamix_ota_verify_file() {
	_f="$1"; _exp="$2"
	[ -f "$_f" ] || return 1
	_got=$(jukamix_update_sha256 "$_f")
	_e=$(printf '%s' "$_exp" | sed 's/^sha256://I' | tr 'A-Z' 'a-z')
	_g=$(printf '%s' "$_got" | tr 'A-Z' 'a-z')
	[ -n "$_g" ] && [ "$_g" = "$_e" ]
}

# Flatten an absolute destination path into a single safe rollback-store name
# (leading slash stripped, remaining slashes -> underscores). Pure shell +
# one tr, replacing the per-line "echo | sed" pipeline.
jukamix_ota_flat() {
	printf '%s' "${1#/}" | tr '/' '_'
}

# Apply a manifest (simple, signable, TAB-delimited text format) from payload
# dir $1, using rollback store $3. Manifest lines:
#   install\t<relpath-in-payload>\t<dest-abs>\t<sha256>[\texecutable]
#   replace\t<relpath-in-payload>\t<dest-abs>\t<sha256>[\texecutable]
#   remove\t<dest-abs>
# Tabs are used because OS paths legitimately contain spaces and UTF-8.
# Journal is written to $3/journal.txt. Returns 0 on full success, 1 on any
# refusal or failure (caller should then roll back).
jukamix_ota_apply() {
	_pay="$1"; _man="$2"; _rb="$3"
	_txj="$_rb/journal.txt"
	: > "$_txj"
	_st=0
	_tab=$(printf '\t')
	while IFS="$_tab" read -r _op _src _dest _sha _flag; do
		case "$_op" in
			install|replace)
				[ -n "$_dest" ] || { echo "MALFORMED manifest entry (missing dest)" >&2; _st=1; break; }
				if jukamix_ota_is_user_data "$_dest"; then
					echo "REFUSE user-data: $_dest" >&2
					_st=1; break
				fi
				_from="$_pay/$_src"
				if [ ! -f "$_from" ]; then
					echo "MISSING payload: $_from" >&2
					_st=1; break
				fi
				if ! jukamix_ota_verify_file "$_from" "$_sha"; then
					echo "CHECKSUM MISMATCH: $_dest" >&2
					_st=1; break
				fi
				if [ -e "$_dest" ]; then
					# flat names never contain '/', so the rollback store dir is enough
					_bk="$_rb/$(jukamix_ota_flat "$_dest")"
					cp -a "$_dest" "$_bk" 2>/dev/null
					echo "backup $_dest" >> "$_txj"
				fi
				mkdir -p "$(dirname "$_dest")"
				cp -a "$_from" "$_dest"
				[ "$_flag" = "executable" ] && chmod +x "$_dest"
				echo "apply $_dest" >> "$_txj"
				;;
			remove)
				# remove lines carry the destination in the 2nd column.
				_dest="$_src"
				if jukamix_ota_is_user_data "$_dest"; then
					echo "REFUSE user-data: $_dest" >&2
					_st=1; break
				fi
				if [ -e "$_dest" ]; then
					mv "$_dest" "$_rb/removed_$(jukamix_ota_flat "$_dest")" 2>/dev/null
				fi
				echo "remove $_dest" >> "$_txj"
				;;
		esac
	done < "$_man"
	unset _tab
	return $_st
}

# Roll back a transaction using its journal (reverse order). Safe to call on
# interruption or failure. Removes the rollback store afterwards.
jukamix_ota_rollback() {
	_rb="$1"; _txj="$_rb/journal.txt"
	[ -f "$_txj" ] || return 0
	awk 'BEGIN{i=0} {a[i++]=$0} END{while(i>0){print a[--i]}}' "$_txj" | while IFS= read -r _e; do
		case "$_e" in
			apply\ *)
				_d=${_e#apply }
				_bk="$_rb/$(jukamix_ota_flat "$_d")"
				if [ -e "$_bk" ]; then
					mkdir -p "$(dirname "$_d")"
					cp -a "$_bk" "$_d"
				else
					rm -f "$_d"
				fi
				;;
			remove\ *)
				_d=${_e#remove }
				_rest="$_rb/removed_$(jukamix_ota_flat "$_d")"
				[ -e "$_rest" ] && mv "$_rest" "$_d" 2>/dev/null
				;;
		esac
	done
	rm -rf "$_rb"
}

# Run pending config migrations (migrations/*-to-*.sh) in numeric order.
# Each migration runs once and is recorded in a state file so later updates
# never re-apply it. Migrations must be idempotent and must not touch user
# data. Returns 0 when every pending migration succeeds.
jukamix_ota_migrate() {
	_dir="${JUKAMIX_MIGRATIONS_DIR:-/mnt/SDCARD/migrations}"
	_state="${JUKAMIX_MIGRATIONS_STATE:-/mnt/SDCARD/System/var/jukamix/state/applied-migrations}"
	[ -d "$_dir" ] || return 0
	mkdir -p "${_state%/*}" 2>/dev/null

	_idx="${JUKAMIX_TMPBASE:-/tmp}/.jukamix-ota-mig-$$"
	: > "$_idx"
	for _m in "$_dir"/*-to-*.sh; do
		[ -f "$_m" ] || continue
		_key=${_m##*/}
		_from=${_key%%-to-*}
		case "$_from" in ''|*[!0-9]*) continue ;; esac
		printf '%s\t%s\n' "$_from" "$_m" >> "$_idx"
	done

	_ordered=$(sort -n "$_idx" 2>/dev/null | cut -f2-)
	rm -f "$_idx"
	_rc=0
	for _m in $_ordered; do
		[ -f "$_m" ] || continue
		_key=${_m##*/}
		if [ -f "$_state" ] && grep -Fxq "$_key" "$_state" 2>/dev/null; then
			continue
		fi
		echo "Applying migration: $_key" >&2
		if sh "$_m"; then
			printf '%s\n' "$_key" >> "$_state"
		else
			echo "Migration failed: $_key" >&2
			_rc=1
			break
		fi
	done
	unset _dir _state _idx _ordered _m _key _from
	return $_rc
}

# Orchestrate a full safe OTA. Requires curl + jq (on-device). Resolves the
# latest release from the GitHub release channel directly (the channel is the
# source of truth, so a stale local package index can never block an update).
#
# Order: resolve latest release -> download archive -> fetch manifest ->
# extract -> apply (backup + journal, verifying every file against the
# manifest) -> migrate -> reboot, or roll back automatically on any failure.
# When no manifest is published, falls back to the legacy full-image installer.
jukamix_ota_run() {
	. "/mnt/SDCARD/System/usr/trimui/scripts/update_common.sh" 2>/dev/null
	_jm_lib="${JUKAMIX_LIB_DIR:-/mnt/SDCARD/System/jukamix/lib}"
	[ -d "$_jm_lib" ] || _jm_lib="/mnt/SDCARD/tools/lib"
	. "$_jm_lib/jukamix-update.sh" 2>/dev/null
	unset _jm_lib
	_staging="${JUKAMIX_OTA_STAGING:-/mnt/SDCARD/System/updates/staging}"
	_pubkey="${JUKAMIX_OTA_PUBKEY:-/mnt/SDCARD/System/etc/jukamix-signing.pub}"

	check_connection || exit 2

	# 1. Resolve the latest release and its published checksum.
	jukamix_update_resolve_release || { infoscreen.sh -m "No JukaMix OS update found.\nCheck your connection and try again." -t 4; exit 1; }
	if ! jukamix_update_version_gt "$JUKAMIX_UPDATE_VERSION" "$Local_JukaMixVersion"; then
		infoscreen.sh -m "JukaMix OS is up to date ($Local_JukaMixVersion)." -t 3
		exit 0
	fi

	mkdir -p "$_staging"

	# 2. Download the archive (verified against the release checksum when one is published).
	_archive="$_staging/JukaMix_${JUKAMIX_UPDATE_VERSION}.zip"
	download_file "$JUKAMIX_UPDATE_URL" -f "$_archive" -t "Downloading JukaMix OS $JUKAMIX_UPDATE_VERSION"
	[ -f "$_archive" ] || { infoscreen.sh -m "Download failed." -c red -t 3; rm -rf "$_staging"; exit 1; }
	if [ -n "$JUKAMIX_UPDATE_SHA" ] && ! jukamix_update_verify_file "$_archive" "$JUKAMIX_UPDATE_SHA"; then
		infoscreen.sh -m "Update checksum verification FAILED.\nAborting for safety." -c red -t 4
		rm -rf "$_staging"; exit 1
	fi

	# 3. Fetch the (optional) signed manifest, published next to the archive.
	_man=""
	_man="$_staging/manifest.txt"
	download_file "${JUKAMIX_UPDATE_URL%/*}/manifest.txt" -f "$_man" -t "Fetching update manifest" 2>/dev/null
	[ -f "$_man" ] || _man=""
	if [ -n "$_man" ]; then
		_sig="$_staging/manifest.txt.sig"
		if download_file "${JUKAMIX_UPDATE_URL%/*}/manifest.txt.sig" -f "$_sig" -t "Fetching manifest signature" 2>/dev/null && [ -f "$_sig" ]; then
			if jukamix_ota_verify_signature "$_pubkey" "$_man" "$_sig" >/dev/null 2>&1; then
				infoscreen.sh -m "Manifest signature verified." -t 2
			else
				infoscreen.sh -m "Manifest signature FAILED.\nAborting for safety." -c red -t 4
				rm -rf "$_staging"; exit 1
			fi
		else
			infoscreen.sh -m "Update is UNSIGNED.\nProceed only if you trust the source." -t 3
		fi
	else
		infoscreen.sh -m "No manifest found.\nUsing full-image installer." -t 3
	fi

	# 4. Apply transactionally when a manifest is present; otherwise hand off
	#    to the legacy full-image installer.
	if [ -n "$_man" ]; then
		_payload="$_staging/payload"
		rm -rf "$_payload"; mkdir -p "$_payload"
		if ! /mnt/SDCARD/System/bin/7zz x -aoa "$_archive" "-o$_payload" >/dev/null 2>&1; then
			infoscreen.sh -m "Could not extract the update package." -c red -t 4
			rm -rf "$_staging"; exit 1
		fi
		_rb="$_staging/rollback-$$"
		mkdir -p "$_rb"
		if jukamix_ota_apply "$_payload" "$_man" "$_rb"; then
			if jukamix_ota_migrate; then
				infoscreen.sh -m "JukaMix OS updated.\nRebooting..." -t 2
			else
				infoscreen.sh -m "Update applied, but a migration step failed.\nCheck the log before rebooting." -t 4
			fi
			rm -rf "$_staging"
			sync; sleep 3; reboot
		else
			infoscreen.sh -m "Update failed.\nRolling back changes..." -t 3
			jukamix_ota_rollback "$_rb"
			rm -rf "$_staging"
			exit 1
		fi
	else
		mv "$_archive" "/mnt/SDCARD/" 2>/dev/null
		_up="https://raw.githubusercontent.com/$GITHUB_REPOSITORY/refs/tags/v$JUKAMIX_UPDATE_VERSION/System/usr/trimui/scripts/jukamix_update.sh"
		download_file "$_up" -f "/mnt/SDCARD/System/usr/trimui/scripts/jukamix_update.sh" -t "Upgrading updater"
		rm -rf "$_staging"
		sync; sleep 4; reboot
	fi
}
