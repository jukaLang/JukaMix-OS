#!/bin/sh
echo $0 $*
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$progdir
progdir=$(pwd)

JukaMix_Style=$(/mnt/SDCARD/System/bin/jq -r '.["JUKAMIX STYLE"]' "/mnt/SDCARD/System/etc/jukamix.json")

if [ -d "$progdir/theme_$JukaMix_Style" ]; then
	cd "$progdir/theme_$JukaMix_Style"
else
	cd "$progdir"
fi

"$progdir/user_guide"
