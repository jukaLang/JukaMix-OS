#!/bin/sh
# JukaMix OS - JukaHub auto-installer.
#
# Downloads the JukaHub player (v1 "alpha" release) from the JukaHub GitHub
# release channel, verifies it against the published SHA-256 digest, and
# installs it as the JukaHub app under <root>/JukaHub/. JukaHub is an
# integrated hub app; its optional --replace-apps step moves the Apps/ entries
# it supersedes into a recoverable backup directory (nothing is deleted).
#
# Runs on-device (or on a host with curl/wget + 7zz/unzip/python3 for tests).
# Hooked into boot (System/starts/°post_starts.sh) and usable from the
# Control Center so JukaHub installs automatically once.
#
# Usage:
#   jukamix-jukahub.sh status [--root DIR]        show install state
#   jukamix-jukahub.sh install [--force] [--replace-apps] [--no-verify] [--background] [--root DIR]
#   jukamix-jukahub.sh update  (same as install)
#   jukamix-jukahub.sh remove  [--root DIR]        uninstall (moved to backups/)
#   jukamix-jukahub.sh restore-apps [--root DIR]   move replaced apps back to Apps/
#   jukamix-jukahub.sh skip | unskip [--root DIR]  toggle automatic (re)install
#
# Environment overrides (mainly for testing):
#   JUKAHUB_URL      release asset URL (default: alpha JukaHub.zip)
#   JUKAHUB_API      GitHub API URL used to fetch the asset digest
#   JUKAHUB_SHA256   pin the expected SHA-256 (skips the API call)
#   JUKAHUB_ARCHIVE  local .zip to install from (skips the download)
#   JUKAHUB_ROOT     install root (default: /mnt/SDCARD)

set -u

ROOT="${JUKAHUB_ROOT:-/mnt/SDCARD}"
URL="${JUKAHUB_URL:-https://github.com/jukaLang/JukaHub/releases/download/alpha/JukaHub.zip}"
API="${JUKAHUB_API:-https://api.github.com/repos/jukaLang/JukaHub/releases/tags/alpha}"
SHA="${JUKAHUB_SHA256:-}"
ARCHIVE="${JUKAHUB_ARCHIVE:-}"
TMPBASE="${JUKAMIX_TMPBASE:-/tmp}"

HUB="$ROOT/JukaHub"
BIN="$HUB/JukaHub"
STATE="$ROOT/System/var/jukamix/state"
SKIP="$STATE/jukahub-skip"
VF="$HUB/.jukahub-version"
BACKUP="$ROOT/System/var/jukamix/backups/jukahub-apps"
# Apps superseded by JukaHub; moved to $BACKUP (recoverable) by --replace-apps.
# Edit to taste - JukaHub's feature set keeps changing.
REPLACED="${JUKAHUB_REPLACED_APPS:-Activities BootLogo EmuCleaner Scraper ScreenRecorder ScreencapTK Terminal user_guide}"

usage() {
	sed -n '2,27p' "$0"
}

jkh_log() {
	echo "jukahub: $*" >&2
}

jkh_sha256() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" 2>/dev/null | awk '{print $1}'
	elif command -v busybox >/dev/null 2>&1; then
		busybox sha256sum "$1" 2>/dev/null | awk '{print $1}'
	elif command -v openssl >/dev/null 2>&1; then
		openssl dgst -sha256 "$1" 2>/dev/null | awk '{print $NF}'
	fi
}

jkh_fetch() {
	# $1 url -> stdout
	if command -v curl >/dev/null 2>&1; then
		curl -ksL --max-time 30 "$1" 2>/dev/null
	elif command -v wget >/dev/null 2>&1; then
		wget -q -O- "$1" 2>/dev/null
	fi
}

# Resolve the expected SHA-256 from GitHub's asset metadata (digest field).
jkh_api_sha() {
	_out=$(jkh_fetch "$API")
	[ -n "$_out" ] || return 1
	if command -v jq >/dev/null 2>&1; then
		printf '%s' "$_out" | jq -r '.assets[] | select(.name == "JukaHub.zip") | .digest // empty' 2>/dev/null
	else
		printf '%s' "$_out" | grep -o 'sha256:[0-9a-f]\{64\}' | head -n1
	fi
}

jkh_download() {
	# $1 url, $2 out file, $3 title
	if command -v download_file >/dev/null 2>&1; then
		download_file "$1" -f "$2" -t "${3:-Downloading JukaHub}"
	elif command -v curl >/dev/null 2>&1; then
		curl -kL --max-time 900 -o "$2" "$1"
	elif command -v wget >/dev/null 2>&1; then
		wget -q -O "$2" "$1"
	else
		return 1
	fi
	[ -f "$2" ]
}

jkh_extract() {
	# $1 zip, $2 dest dir
	mkdir -p "$2"
	_7zz=$(command -v 7zz 2>/dev/null)
	[ -n "$_7zz" ] || [ -x /mnt/SDCARD/System/bin/7zz ] && _7zz=/mnt/SDCARD/System/bin/7zz
	if [ -n "$_7zz" ] && [ -x "$_7zz" ]; then
		"$_7zz" x -aoa "$1" "-o$2" >/dev/null 2>&1
	elif command -v unzip >/dev/null 2>&1; then
		unzip -oq "$1" -d "$2"
	elif command -v python3 >/dev/null 2>&1; then
		python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$1" "$2"
	else
		return 1
	fi
}

# Move Apps/ entries superseded by JukaHub into the backup dir (recoverable).
jkh_replace_apps() {
	[ -d "$ROOT/Apps" ] || { echo "no Apps dir; nothing to replace"; return 0; }
	_ts=$(date +%Y%m%d-%H%M%S 2>/dev/null || echo now)
	_dest="$BACKUP/$_ts"
	mkdir -p "$_dest"
	_n=0
	for _a in $REPLACED; do
		if [ -e "$ROOT/Apps/$_a" ]; then
			mv "$ROOT/Apps/$_a" "$_dest/" 2>/dev/null && _n=$((_n + 1))
		fi
	done
	printf '%s\n' $REPLACED > "$_dest/.moved-apps" 2>/dev/null
	echo "moved $_n replaced app(s) into backup: $_dest"
	unset _ts _dest _n _a
}

cmd="${1:-help}"
shift 2>/dev/null || true

FORCE=0
REPLACE=0
NOVERIFY=0
BACKGROUND=0

while [ "$#" -gt 0 ]; do
	case "$1" in
		--root)
			ROOT="$2"
			HUB="$ROOT/JukaHub"; BIN="$HUB/JukaHub"
			STATE="$ROOT/System/var/jukamix/state"; SKIP="$STATE/jukahub-skip"
			VF="$HUB/.jukahub-version"; BACKUP="$ROOT/System/var/jukamix/backups/jukahub-apps"
			shift 2 ;;
		--force)       FORCE=1; shift ;;
		--replace-apps) REPLACE=1; shift ;;
		--no-verify)   NOVERIFY=1; shift ;;
		--background)  BACKGROUND=1; shift ;;
		-h|--help)     usage; exit 0 ;;
		*) echo "unknown option: $1" >&2; usage; exit 2 ;;
	esac
done

case "$cmd" in
	status)
		if [ -x "$BIN" ]; then
			echo "JukaHub: installed at $HUB"
			[ -f "$VF" ] && echo "version: $(cat "$VF")"
		else
			echo "JukaHub: not installed ($BIN missing)"
		fi
		[ -f "$SKIP" ] && echo "auto-install: disabled (remove $SKIP to re-enable)"
		if [ -d "$BACKUP" ]; then
			echo "replaced-apps backup: $BACKUP"
		fi
		;;

	install|update)
		if [ -x "$BIN" ] && [ "$FORCE" -eq 0 ]; then
			echo "JukaHub already installed. Use --force to reinstall."
			exit 0
		fi

		if [ "$NOVERIFY" -eq 0 ] && [ -z "$SHA" ]; then
			SHA=$(jkh_api_sha)
			[ -n "$SHA" ] || { jkh_log "could not fetch expected SHA-256 from GitHub API"; exit 1; }
		fi
		_exp=$(printf '%s' "$SHA" | sed 's/^sha256://I' | tr 'A-Z' 'a-z')

		if command -v check_available_space >/dev/null 2>&1; then
			check_available_space 500 >/dev/null 2>&1 || jkh_log "warning: less than 500 MB free on $ROOT"
		else
			_avail=$(df -Pk "$ROOT" 2>/dev/null | awk 'NR==2 {print $4}')
			[ -n "$_avail" ] && [ "$_avail" -lt 524288 ] && jkh_log "warning: less than 512 MB free on $ROOT"
		fi

		_tmp="$TMPBASE/jukahub-install-$$"
		rm -rf "$_tmp"; mkdir -p "$_tmp"
		_zip="$_tmp/JukaHub.zip"

		if [ -n "$ARCHIVE" ]; then
			[ -f "$ARCHIVE" ] || { jkh_log "archive not found: $ARCHIVE"; rm -rf "$_tmp"; exit 1; }
			cp "$ARCHIVE" "$_zip"
		else
			jkh_download "$URL" "$_zip" "Downloading JukaHub (~160 MB)" \
				|| { jkh_log "download failed: $URL"; rm -rf "$_tmp"; exit 1; }
		fi
		[ -s "$_zip" ] || { jkh_log "downloaded archive is empty"; rm -rf "$_tmp"; exit 1; }

		if [ "$NOVERIFY" -eq 0 ] && [ -n "$_exp" ]; then
			_got=$(jkh_sha256 "$_zip")
			if [ -z "$_got" ] || [ "$_got" != "$_exp" ]; then
				jkh_log "CHECKSUM MISMATCH: got $_got, expected $_exp"
				rm -rf "$_tmp"; exit 1
			fi
		fi

		_ext="$_tmp/x"
		jkh_extract "$_zip" "$_ext" || { jkh_log "extract failed (need 7zz/unzip/python3)"; rm -rf "$_tmp"; exit 1; }
		[ -e "$_ext/JukaHub" ] || { jkh_log "JukaHub binary missing from archive"; rm -rf "$_tmp"; exit 1; }

		# Swap into place atomically (keep the old copy until the new one is in).
		_old="$ROOT/.jukahub-old-$$"
		rm -rf "$_old"
		[ -d "$HUB" ] && mv "$HUB" "$_old" 2>/dev/null
		if ! mv "$_ext" "$HUB" 2>/dev/null; then
			# FAT rename of a big dir can fail; fall back to copy.
			cp -a "$_ext/." "$HUB" 2>/dev/null || { jkh_log "could not install JukaHub into $HUB"; rm -rf "$_old" "$_tmp"; exit 1; }
		fi
		rm -rf "$_old"

		# FAT/exFAT + Windows archives drop exec bits; restore them.
		chmod +x "$HUB/JukaHub" 2>/dev/null
		for _x in "$HUB"/*.sh "$HUB"/ffmpeg "$HUB"/ffprobe "$HUB"/mpv "$HUB"/yt-dlp "$HUB"/mediamtx; do
			[ -f "$_x" ] && chmod +x "$_x" 2>/dev/null
		done
		unset _x

		printf 'alpha %s %s\n' "$(printf '%s' "$_exp" | cut -c1-12)" "$(date +%Y-%m-%d 2>/dev/null)" > "$VF"

		if [ "$REPLACE" -eq 1 ]; then
			jkh_replace_apps
		fi

		rm -rf "$_tmp"
		rm -f "$SKIP"

		if [ "$BACKGROUND" -eq 0 ] && command -v infoscreen.sh >/dev/null 2>&1; then
			infoscreen.sh -m "JukaHub installed.\\nOpen it from the Apps menu." -t 4
		fi
		echo "JukaHub installed to $HUB"
		;;

	remove)
		if [ -d "$HUB" ]; then
			_ts=$(date +%Y%m%d-%H%M%S 2>/dev/null || echo now)
			_rmdir="$ROOT/System/var/jukamix/backups/jukahub-removed-$_ts"
			mkdir -p "${_rmdir%/*}"
			mv "$HUB" "$_rmdir" 2>/dev/null || rm -rf "$HUB"
			echo "JukaHub removed (kept in $ROOT/System/var/jukamix/backups/)."
		else
			echo "JukaHub is not installed."
		fi
		mkdir -p "$STATE"
		touch "$SKIP"
		echo "Automatic (re)install disabled; remove $SKIP to re-enable."
		;;

	restore-apps)
		[ -d "$BACKUP" ] || { echo "no replaced-apps backup found" >&2; exit 1; }
		_latest=$(ls -1dt "$BACKUP"/* 2>/dev/null | head -n1)
		[ -n "$_latest" ] || { echo "no replaced-apps backup found" >&2; exit 1; }
		mkdir -p "$ROOT/Apps"
		_n=0
		for _a in "$_latest"/*; do
			[ -e "$_a" ] || continue
			[ "${_a##*/}" = ".moved-apps" ] && continue
			mv "$_a" "$ROOT/Apps/" 2>/dev/null && _n=$((_n + 1))
		done
		echo "restored $_n app(s) to $ROOT/Apps"
		unset _latest _n _a
		;;

	skip)
		mkdir -p "$STATE"
		touch "$SKIP"
		echo "JukaHub auto-install disabled."
		;;

	unskip)
		rm -f "$SKIP"
		echo "JukaHub auto-install re-enabled."
		;;

	-h|--help|help) usage; exit 0 ;;
	*)
		echo "unknown command: $cmd" >&2
		usage
		exit 2
		;;
esac
