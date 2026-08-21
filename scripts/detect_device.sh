#!/bin/sh
set -eu

# Allow an explicit override for tests/CI (mirrors JUKAMIX_DEVICE_FORCE in the
# tools libraries) so host-side validation can exercise each device's mapping
# without touching /etc/trimui_device.txt.
if [ -n "${JUKAMIX_DEVICE_FORCE:-}" ]; then
    code=$(printf '%s' "$JUKAMIX_DEVICE_FORCE" | tr -d '[:space:]')
    case "$code" in
        tsp|tg5040)       profile="trimui-smart-pro" ;;
        tg5050)           profile="trimui-smart-pro-s" ;;
        brick)            profile="trimui-brick" ;;
        brick_pro|brickpro) profile="trimui-brick-pro" ;;
        *)                profile="unknown" ;;
    esac
    printf 'device_code=%s\n' "$code"
    printf 'device_profile=%s\n' "$profile"
    printf 'machine=%s\n' "(forced)"
    [ "$profile" != "unknown" ] || exit 2
    exit 0
fi

# Prefer the authoritative device code written by TrimUI firmware; fall back to
# the device-tree model and finally to `uname` when running off-device.
code=""
machine=""

if [ -r /etc/trimui_device.txt ]; then
    code=$(tr -d '[:space:]' < /etc/trimui_device.txt)
fi

if [ -z "$code" ]; then
    for source in /sys/firmware/devicetree/base/model /proc/device-tree/model; do
        if [ -r "$source" ]; then
            machine=$(tr -d '\000' < "$source")
            break
        fi
    done
fi

if [ -z "$machine" ] && command -v uname >/dev/null 2>&1; then
    machine=$(uname -a)
fi

lower=$(printf '%s' "$code $machine" | tr '[:upper:]' '[:lower:]')
case "$lower" in
    *brick_pro*|*brickpro*)
        profile="trimui-brick-pro"
        ;;
    *brick*)
        profile="trimui-brick"
        ;;
    *"smart pro s"*|*"tg5050"*)
        profile="trimui-smart-pro-s"
        ;;
    *"smart pro"*|*"tsp"*|*"tg5040"*)
        profile="trimui-smart-pro"
        ;;
    *)
        profile="unknown"
        ;;
esac

[ -n "$code" ] || code="unknown"
printf 'device_code=%s\n' "$code"
printf 'device_profile=%s\n' "$profile"
printf 'machine=%s\n' "$machine"

[ "$profile" != "unknown" ] || exit 2
