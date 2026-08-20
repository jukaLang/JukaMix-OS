#!/bin/sh
export LD_LIBRARY_PATH=/mnt/SDCARD/System/lib:/lib64:/usr/trimui/lib:/usr/lib
export PATH=$PATH:/mnt/SDCARD/System/bin

/mnt/SDCARD/System/usr/trimui/scripts/infoscreen2.sh -m "Optimizing boxart images..." -fi 0 -p top-left -fb -sp &

OUT=$(python3.11 "/mnt/SDCARD/System/usr/trimui/scripts/Boxart Optimizer.py" "/mnt/SDCARD/Imgs")
COUNT=$(printf '%s\n' "$OUT" | grep '^TOTAL_OPTIMIZED=' | cut -d= -f2)
SAVED=$(printf '%s\n' "$OUT" | grep '^TOTAL_SAVED_MB=' | cut -d= -f2)
COUNT=${COUNT:-0}
SAVED=${SAVED:-0}

Message="Optimize Boxart Images\n"
Message="$Message \n--------------------------------------\n"
Message="$Message Finished.\n"
Message="$Message \nImage(s) optimized: $COUNT\n"
Message="$Message Total space saved: ${SAVED} MB\n"
Message="$Message --------------------------------------"

/mnt/SDCARD/System/usr/trimui/scripts/infoscreen2.sh -m "$Message" -fi 0 -p top-left -k rin B "Exit"
