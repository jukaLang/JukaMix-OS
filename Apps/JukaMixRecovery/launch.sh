#!/bin/sh
ROOT=${JUKAMIX_ROOT:-/mnt/SDCARD}
"$ROOT/System/usr/jukamix/session-recover.sh"
"$ROOT/System/usr/jukamix/log-maintenance.sh"
exec "$ROOT/System/usr/jukamix/health-report.sh"
