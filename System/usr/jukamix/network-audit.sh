#!/bin/sh
set -u

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SELF_DIR/lib/common.sh"
jm_init_dirs

report="$STATE_DIR/network-audit.txt"
{
    printf 'JukaMix network service audit\n'
    printf 'Generated: %s\n\n' "$(date 2>/dev/null || :)"
    if command -v ss >/dev/null 2>&1; then
        ss -lntup 2>/dev/null || ss -lnt 2>/dev/null || :
    elif command -v netstat >/dev/null 2>&1; then
        netstat -lntup 2>/dev/null || netstat -lnt 2>/dev/null || :
    else
        printf 'No socket-listing command available.\n'
    fi
    printf '\nWarnings:\n'
    ps 2>/dev/null | grep -E '[t]elnetd|[t]ftpd|[f]tpd|[d]ropbear|[s]shd' || :
    [ -r /etc/shadow ] && grep -E '^root::|^root:[^!*][^:]:' /etc/shadow 2>/dev/null &&
        printf 'WARNING: review the root password configuration.\n'
} | jm_atomic_write "$report"

cat "$report"
