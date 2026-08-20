#!/bin/sh
export LD_LIBRARY_PATH=/mnt/SDCARD/System/lib:/lib64:/usr/trimui/lib:/usr/lib
export PATH=$PATH:/mnt/SDCARD/System/bin

TOTAL=0
TESTED=0
Message=""

for dir in /mnt/SDCARD/Roms/*/; do
    dir=$(basename "$dir")
    case "$dir" in
        .*|_*) continue ;;
    esac
    /mnt/SDCARD/System/usr/trimui/scripts/infoscreen2.sh -m "$Message\n$dir archive test..." -fi 0 -p top-left -fb -sp &

    OUT=$(python3.11 "/mnt/SDCARD/System/usr/trimui/scripts/ROM Archive Tester.py" "/mnt/SDCARD/Roms/$dir")
    COUNT=$(printf '%s\n' "$OUT" | grep '^TOTAL_CORRUPT=' | cut -d= -f2)
    TST=$(printf '%s\n' "$OUT" | grep '^TESTED=' | cut -d= -f2)
    COUNT=${COUNT:-0}
    TST=${TST:-0}
    TOTAL=$((TOTAL + COUNT))
    TESTED=$((TESTED + TST))
    Message="$Message\n$dir corrupt zip(s): $COUNT"
    sleep 1
done

Message="$Message\n \n--------------------------------------\n"
Message="$Message Finished.\n"
Message="$Message \nArchive(s) tested: $TESTED\n"
Message="$Message Corrupt archive(s) found: $TOTAL\n"
Message="$Message \nCorrupt zips are in Data/archives-corrupt/<system>/ - nothing was deleted.\n"
Message="$Message --------------------------------------"

/mnt/SDCARD/System/usr/trimui/scripts/infoscreen2.sh -m "$Message" -fi 0 -p top-left -k rin B "Exit"
