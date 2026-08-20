#!/bin/sh
export LD_LIBRARY_PATH=/mnt/SDCARD/System/lib:/lib64:/usr/trimui/lib:/usr/lib
export PATH=$PATH:/mnt/SDCARD/System/bin

TOTAL=0
SAVED=0
Message=""

for dir in /mnt/SDCARD/Roms/*/; do
    dir=$(basename "$dir")
    case "$dir" in
        .*|_*) continue ;;
    esac
    /mnt/SDCARD/System/usr/trimui/scripts/infoscreen2.sh -m "$Message\n$dir duplicate search..." -fi 0 -p top-left -fb -sp &

    OUT=$(python3.11 "/mnt/SDCARD/System/usr/trimui/scripts/Duplicate Finder.py" "/mnt/SDCARD/Roms/$dir")
    COUNT=$(printf '%s\n' "$OUT" | grep '^TOTAL_DUPLICATES=' | cut -d= -f2)
    SAVED_MB=$(printf '%s\n' "$OUT" | grep '^TOTAL_SAVED_MB=' | cut -d= -f2)
    COUNT=${COUNT:-0}
    SAVED_MB=${SAVED_MB:-0}
    TOTAL=$((TOTAL + COUNT))
    SAVED=$((SAVED + SAVED_MB))
    Message="$Message\n$dir duplicates found: $COUNT"
    sleep 1
done

Message="$Message\n \n--------------------------------------\n"
Message="$Message Finished.\n"
Message="$Message \nTotal duplicate(s) moved: $TOTAL\n"
Message="$Message Total space saved: ${SAVED} MB\n"
Message="$Message \nDuplicates are in Data/duplicates/<system>/ - nothing was deleted.\n"
Message="$Message --------------------------------------"

/mnt/SDCARD/System/usr/trimui/scripts/infoscreen2.sh -m "$Message" -fi 0 -p top-left -k rin B "Exit"
