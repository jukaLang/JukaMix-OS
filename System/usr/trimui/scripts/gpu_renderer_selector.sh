#!/bin/sh
# gpu_renderer_selector.sh - JukaMix OS GPU renderer guidance.
#
# Reports the Mali GPU the running device actually has, then gives
# renderer recommendations tuned to that GPU. Each JukaMix-supported
# device has different GL driver maturity:
#
#   tg5050  Allwinner A523 + Mali-G57   OpenGL ES 3.2  -> prefer GLES2
#   tsp     Allwinner A133 + Mali-G31   OpenGL ES 3.1  -> prefer OpenGL
#   brick   Allwinner A133 + Mali-G31   OpenGL ES 3.1  -> prefer OpenGL
#
# The old version was hardcoded to the Smart Pro S, so its recommendations
# (GLES2-everywhere) silently hurt Smart Pro and Brick users: the Mali-G31
# driver is much more battle-tested on the full OpenGL path than on GLES2,
# and forcing GLES2 there introduces visual glitches and slower framerates.
#
# Usage: gpu_renderer_selector.sh [core_name]
#   core_name: optional; if omitted, prints guidance for every supported core.
#
# POSIX sh (BusyBox ash / dash). No bashisms.

CORE_NAME="$1"

# Resolve the running device without depending on /etc/trimui_device.txt's
# exact spelling (tsp / tg5040 are both Smart Pro in the firmware).
DEVICE_CODE="unknown"
if [ -r /etc/trimui_device.txt ]; then
    DEVICE_CODE=$(tr -d '[:space:]' < /etc/trimui_device.txt | head -n 1)
fi

GPU_VENDOR="Unknown"
GPU_MODEL="Unknown"
GLES_VERSION="Unknown"
RENDERER_HINT="OpenGL"
case "$DEVICE_CODE" in
    tg5050)
        GPU_VENDOR="ARM"
        GPU_MODEL="Mali-G57"
        GLES_VERSION="3.2"
        RENDERER_HINT="GLES2"
        ;;
    tsp|brick|tg5040)
        GPU_VENDOR="ARM"
        GPU_MODEL="Mali-G31"
        GLES_VERSION="3.1"
        RENDERER_HINT="OpenGL"
        ;;
esac

cat <<HEADER
=== JukaMix OS GPU Renderer Selection Helper ===
Device:    $DEVICE_CODE ($GPU_VENDOR $GPU_MODEL, OpenGL ES $GLES_VERSION)
Recommended renderer family: $RENDERER_HINT
HEADER

# Per-core guidance. Recommendations deliberately diverge by GPU:
# the G57 is happier on GLES2 (lower overhead, better shader compilation),
# the G31 is happier on full OpenGL (more mature driver, fewer edge cases).
# "UNTESTED" entries are cores that the maintainers have not yet exercised
# on each GPU and so default to the safer hint for that family.
show_core_renderers() {
    _core="$1"
    case "$_core" in
        flycast|dc|naomi|atomiswave)
            case "$DEVICE_CODE" in
                tg5050)
                    cat <<'NOTE'
Flycast / DC / NAOMI / AtomisWave:
  - GLES2: recommended for the Mali-G57 (lower driver overhead)
  - OpenGL: good compatibility fallback if a game glitches on GLES2
  - Vulkan: UNTESTED on this device - driver availability unverified
NOTE
                    ;;
                *)
                    cat <<'NOTE'
Flycast / DC / NAOMI / AtomisWave:
  - OpenGL: recommended for the Mali-G31 (most mature driver path)
  - GLES2: works but the G31 driver is less exercised here
  - Vulkan: not supported on the Mali-G31
NOTE
                    ;;
            esac
            echo ""
            ;;
        mupen64plus|parallel_n64)
            case "$DEVICE_CODE" in
                tg5050)
                    cat <<'NOTE'
N64 (mupen64plus / parallel_n64):
  - Glide64MK2 + GLES2: best speed/accuracy balance on the G57
  - Rice: higher accuracy, slower on this GPU
  - aspect=1 (16:9), resolution=1280
NOTE
                    ;;
                *)
                    cat <<'NOTE'
N64 (mupen64plus / parallel_n64):
  - Glide64MK2 + OpenGL: best balance on the G31 (driver maturity)
  - GLES2 plugins: usable but expect edge-case glitches
  - resolution=960 (avoid 1280: the G31 cannot sustain it in heavier games)
NOTE
                    ;;
            esac
            echo ""
            ;;
        ppsspp)
            case "$DEVICE_CODE" in
                tg5050)
                    cat <<'NOTE'
PPSSPP:
  - GLES2: best Mali-G57 utilization
  - OpenGL: stable fallback
  - Vulkan: UNTESTED on this device
NOTE
                    ;;
                *)
                    cat <<'NOTE'
PPSSPP:
  - OpenGL: stable on the G31; use this for reliability
  - GLES2: works but slower on the G31
  - Vulkan: not supported on the Mali-G31
NOTE
                    ;;
            esac
            echo ""
            ;;
        pcsx_rearmed|swanstation|duckstation)
            case "$DEVICE_CODE" in
                tg5050)
                    cat <<'NOTE'
PS1 (pcsx_rearmed / swanstation / duckstation):
  - GLES2: recommended for the Mali-G57
  - OpenGL: stable fallback if GLES2 has graphical glitches
NOTE
                    ;;
                *)
                    cat <<'NOTE'
PS1 (pcsx_rearmed / swanstation / duckstation):
  - OpenGL: recommended for the Mali-G31 (most stable path)
  - GLES2: usable for swanstation/duckstation; pcsx_rearmed is OpenGL-only
NOTE
                    ;;
            esac
            echo ""
            ;;
        *)
            cat <<UNKNOWN
Unknown core: $_core
Available cores: flycast, dc, naomi, atomiswave, mupen64plus, parallel_n64,
                 ppsspp, pcsx_rearmed, swanstation, duckstation
UNKNOWN
            return 1
            ;;
    esac
}

if [ -z "$CORE_NAME" ]; then
    echo ""
    echo "Per-core recommendations:"
    echo ""
    for _c in flycast mupen64plus ppsspp pcsx_rearmed; do
        show_core_renderers "$_c"
    done
    echo "General notes for this device:"
    case "$DEVICE_CODE" in
        tg5050)
            cat <<'NOTE'
  - Prefer GLES2 over OpenGL where both are available
  - Avoid Vulkan until drivers are verified on this device (UNTESTED)
  - 1280x720 internal resolution is the sweet spot for most cores
NOTE
            ;;
        *)
            cat <<'NOTE'
  - Prefer full OpenGL where both OpenGL and GLES2 are available
  - Vulkan is not supported on the Mali-G31 - do not enable it
  - Cap internal resolution at 960x720 (Brick) / 1024x720 (Smart Pro);
    higher settings exceed the G31's sustainable throughput
NOTE
            ;;
    esac
else
    show_core_renderers "$CORE_NAME"
fi

cat <<TAIL
To apply these settings, edit the core's .opt or .cfg in:
  /mnt/SDCARD/RetroArch/.retroarch/config/<core>/

Tip: jukamix-retroarch-profile.sh --core <core> to inspect the current cfg.
TAIL
