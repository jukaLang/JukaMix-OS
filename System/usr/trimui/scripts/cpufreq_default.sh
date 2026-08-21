#!/bin/sh
# cpufreq_default.sh — resolve the per-device default CPU ceiling into
# JUKAMIX_CPUFREQ_MAX, exported for launchers that call `cpufreq.sh ondemand 2
# "${JUKAMIX_CPUFREQ_MAX:-6}"`. Source this from any launcher that tunes CPU
# without going through common_launcher.sh (e.g. standalone-engine launchers
# such as GZDoom and the ffmpeg media core), so the mapping lives in one place.
#
# Values match the [recommended_defaults] in Profiles/DEVICE-OVERRIDES/*_base.cfg
# (ladder ids: 6 = 1600000 kHz, 7 = 1800000 kHz, 8 = 2000000 kHz):
#   tg5050 (A523)  id 8 = 2000000 kHz
#   tsp    (A133)  id 7 = 1800000 kHz
#   brick  (A133)  id 6 = 1600000 kHz — also the fallback for unknown/off-device,
#                   keeping every other launcher's pre-optimization behaviour.
JUKAMIX_CPUFREQ_MAX=6
if [ -r /etc/trimui_device.txt ]; then
    _jm_dev=$(tr -d '[:space:]' < /etc/trimui_device.txt)
    case "$_jm_dev" in
        tg5050)          JUKAMIX_CPUFREQ_MAX=8 ;;
        tsp)             JUKAMIX_CPUFREQ_MAX=7 ;;
        brick_pro|brickpro) JUKAMIX_CPUFREQ_MAX=7 ;;  # Same A133 as TSP
    esac
    unset _jm_dev
fi
export JUKAMIX_CPUFREQ_MAX
