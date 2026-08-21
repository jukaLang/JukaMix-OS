#!/bin/sh
# Game Switcher - Quick access to recent games

SCRIPTS_DIR="/mnt/SDCARD/System/usr/trimui/scripts"

if [ -f "$SCRIPTS_DIR/game_switcher.sh" ]; then
    "$SCRIPTS_DIR/game_switcher.sh" show
else
    echo "Game Switcher not available" >&2
    exit 1
fi
