#!/bin/sh

. /mnt/SDCARD/System/etc/ex_config

mkdir -p ~/.config/

# One-time root filesystem bootstrap (replaces the legacy CrossMix ex_update patches).
mkdir -p /etc/ssl/certs/
if [ ! -f /etc/ssl/certs/ca-certificates.crt ] && [ -f /mnt/SDCARD/System/etc/ca-certificates.crt ]; then
    cp -f /mnt/SDCARD/System/etc/ca-certificates.crt /etc/ssl/certs/
fi
if [ ! -e /bin/bash ]; then
    if [ -e /bin/busybox ]; then
        ln -sf /bin/busybox /bin/bash
    elif [ -e /mnt/SDCARD/System/bin/bash ]; then
        ln -sf /mnt/SDCARD/System/bin/bash /bin/bash
    fi
fi

if [ "$NETWORK_SSH" = "Y" ]; then
    mkdir -p /etc/dropbear

    # Currently broken
    nice -2 dropbear -R
fi

if [ "$NETWORK_SFTPGO" = "Y" ]; then
    mkdir -p /opt/sftpgo

    nice -2 /mnt/SDCARD/System/sftpgo/sftpgo serve -c /mnt/SDCARD/System/sftpgo/ --log-level error --log-file-path="" > /dev/null &
fi
