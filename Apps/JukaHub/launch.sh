#!/bin/sh
# JukaHub launcher (Bundle JukaHub + Patch).
#
# At release build time the JukaHub player binary and its jukaconfig.json are
# dropped into /mnt/SDCARD/JukaHub/. This launcher runs it; if it is missing it
# explains where to install it. JukaHub's built-in Patch (MISC > Patch) then
# handles updates for both the JukaHub app and JukaMix OS via the package index
# shipped at Apps/JukaHub/patch/packages.json.

export PATH="/mnt/SDCARD/System/bin:$PATH"
export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"

JUKAHUB_DIR="/mnt/SDCARD/JukaHub"
BIN="$JUKAHUB_DIR/JukaHub"

if [ -f "$JUKAHUB_DIR/launch.sh" ]; then
	# The bundled launcher sets up SDL/EGL libraries, SSL certificates and
	# LD_LIBRARY_PATH before starting the player; use it when present.
	cd "$JUKAHUB_DIR" || exit 1
	exec sh "$JUKAHUB_DIR/launch.sh"
elif [ -x "$BIN" ]; then
	cd "$JUKAHUB_DIR" || exit 1
	exec "$BIN"
else
	# Not installed yet - install it automatically (one-time ~160 MB
	# download, verified against the published SHA-256), then relaunch.
	if [ -f /mnt/SDCARD/tools/jukamix-jukahub.sh ]; then
		if command -v infoscreen.sh >/dev/null 2>&1; then
			infoscreen.sh -m "JukaHub is not installed.\n\nDownloading and installing now\n(~160 MB, one-time download)." -t 4
		fi
		if sh /mnt/SDCARD/tools/jukamix-jukahub.sh install --replace-apps; then
			exec sh "$0"
		fi
		echo "JukaHub install failed. Check your connection and try again." >&2
		exit 1
	fi
	if command -v infoscreen.sh >/dev/null 2>&1; then
		infoscreen.sh -m "JukaHub is not installed yet.\n\nDrop the JukaHub player and jukaconfig.json\ninto:\n  /mnt/SDCARD/JukaHub/\n\nor update JukaMix OS so it can be installed\nautomatically." -t 6
	fi
	echo "JukaHub not found at $JUKAHUB_DIR"
	exit 1
fi
