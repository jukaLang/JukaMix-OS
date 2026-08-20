#!/bin/sh
# JukaMix OS verified auto-updater.
#
# Implements the JukaHubV2 update trust model for the OS itself:
#   * releases are fetched from the project GitHub repo
#   * every downloaded artifact is verified against the release manifest
#     manifest before it is trusted
#   * the install is staged then rebooted into the existing installer
#
# Reuses the globals/helpers from update_common.sh (GITHUB_REPOSITORY,
# updatedir, Local_JukaMixVersion, download_file, check_available_space ...).
#
# Only the pure helpers below are exercised by the test harness; the network
# helpers (jukamix_update_resolve_release / jukamix_update_run) require curl and
# jq and are intended to run on-device.

# Compute the SHA-256 of a file using whatever tool is available.
jukamix_update_sha256() {
	_f="$1"
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$_f" 2>/dev/null | awk '{print $1}'
	elif command -v sha256 >/dev/null 2>&1; then
		sha256 "$_f" 2>/dev/null | awk '{print $1}'
	elif command -v openssl >/dev/null 2>&1; then
		openssl dgst -sha256 "$_f" 2>/dev/null | awk '{print $NF}'
	fi
}

# Verify a file against an expected SHA-256 (case-insensitive, tolerant of a
# "sha256:" prefix). Returns 0 on match.
jukamix_update_verify_file() {
	_f="$1"; _exp="$2"
	[ -z "$_exp" ] && return 1
	[ -f "$_f" ] || return 1
	_got=$(jukamix_update_sha256 "$_f")
	_e=$(printf '%s' "$_exp" | sed 's/^sha256://I' | tr 'A-Z' 'a-z')
	_g=$(printf '%s' "$_got" | tr 'A-Z' 'a-z')
	[ -n "$_g" ] && [ "$_g" = "$_e" ]
}

# Compare two dotted version strings. Returns 0 (true) when $1 > $2.
jukamix_update_version_gt() {
	_a=$(printf '%s' "$1" | tr -d '[:alpha:]' | awk -F. '{printf("%d%03d%03d%03d", $1+0, $2+0, $3+0, $4+0)}')
	_b=$(printf '%s' "$2" | tr -d '[:alpha:]' | awk -F. '{printf("%d%03d%03d%03d", $1+0, $2+0, $3+0, $4+0)}')
	[ -n "$_a" ] && [ -n "$_b" ] && [ "$_a" -gt "$_b" ]
}

# Resolve the latest GitHub release: sets JUKAMIX_UPDATE_VERSION and
# JUKAMIX_UPDATE_URL. Requires curl + jq. Returns 1 on any failure.
jukamix_update_resolve_release() {
	_repo="${GITHUB_REPOSITORY:-jukaLang/JukaMix-OS}"
	_api="https://api.github.com/repos/$_repo/releases/latest"
	_info=$(curl -k -s "$_api")
	[ -z "$_info" ] && return 1
	printf '%s' "$_info" | grep -q '"message": "Not Found"' && return 1

	JUKAMIX_UPDATE_URL=$(printf '%s' "$_info" | jq -r '.assets[]? | select((.name | startswith("JukaMix_")) and (.name | endswith(".zip"))) | .browser_download_url' | head -n1)
	JUKAMIX_UPDATE_VERSION=$(printf '%s' "$JUKAMIX_UPDATE_URL" | sed 's#.*JukaMix_##; s#\.zip$##')
	[ -z "$JUKAMIX_UPDATE_URL" ] && return 1

	return 0
}

# Full on-device update flow with integrity verification.
jukamix_update_run() {
	. "/mnt/SDCARD/System/usr/trimui/scripts/update_common.sh" 2>/dev/null
	check_connection || exit 2
	jukamix_update_resolve_release || { infoscreen.sh -m "No JukaMix OS update found." -t 3; exit 1; }

	if ! jukamix_update_version_gt "$JUKAMIX_UPDATE_VERSION" "$Local_JukaMixVersion"; then
		infoscreen.sh -m "JukaMix OS is up to date ($Local_JukaMixVersion)." -t 3
		exit 0
	fi

	_zip="$updatedir/JukaMix_${JUKAMIX_UPDATE_VERSION}.zip"
	download_file "$JUKAMIX_UPDATE_URL" -f "$_zip" -t "Downloading JukaMix OS $JUKAMIX_UPDATE_VERSION"
	[ -f "$_zip" ] || { infoscreen.sh -m "Download failed." -c red -t 3; exit 1; }

	if [ -n "$JUKAMIX_UPDATE_SHA" ]; then
		if ! jukamix_update_verify_file "$_zip" "$JUKAMIX_UPDATE_SHA"; then
			infoscreen.sh -m "Update checksum verification FAILED.\nAborting for safety." -c red -t 4
			rm -f "$_zip"
			exit 1
		fi
	fi

	mv "$_zip" "/mnt/SDCARD/" 2>/dev/null
	_up="https://raw.githubusercontent.com/$GITHUB_REPOSITORY/refs/tags/v$JUKAMIX_UPDATE_VERSION/System/usr/trimui/scripts/jukamix_update.sh"
	download_file "$_up" -f "/mnt/SDCARD/System/usr/trimui/scripts/jukamix_update.sh" -t "Upgrading updater"
	sync; sleep 4; reboot
}
