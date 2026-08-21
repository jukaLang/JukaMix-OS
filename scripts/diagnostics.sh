#!/bin/sh
set -eu

output=${1:-"jukamix-diagnostics.txt"}
tmp="${output}.tmp"
umask 077

redact() {
    sed -E \
        -e 's/([A-Za-z0-9_]*(token|key|secret|password|cookie)[A-Za-z0-9_]*[=:])[[:space:]]*[^[:space:],"]+/\1[REDACTED]/Ig' \
        -e 's/(gsk_|AIza|sk-)[A-Za-z0-9_-]+/[REDACTED]/g'
}

{
    printf 'JukaMix diagnostics\n'
    printf 'Generated (UTC): '
    date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true
    printf '\n== Device ==\n'
    sh "$(dirname "$0")/detect_device.sh" 2>&1 || true
    printf '\n== Kernel ==\n'
    uname -a 2>&1 || true
    printf '\n== Storage ==\n'
    df -h 2>&1 || true
    printf '\n== Memory ==\n'
    free -h 2>&1 || cat /proc/meminfo 2>&1 || true
    printf '\n== Mounts ==\n'
    mount 2>&1 || true
    printf '\n== JukaMix version files ==\n'
    # `crossmix` is kept intentionally so diagnostics still detect pre-rebrand
    # installs during migration.
    find /mnt/SDCARD/System -maxdepth 5 -type f \
        \( -iname '*jukamix*version*' -o -iname '*crossmix*version*' \) \
        -print -exec cat {} \; 2>/dev/null || true
} | redact > "$tmp"

mv "$tmp" "$output"
printf 'Diagnostics written to %s\n' "$output"
