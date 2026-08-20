#!/bin/sh
set -u
SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SELF_DIR/../lib/common.sh"

append_default() {
    key=$1 value=$2
    grep -q "^${key}=" "$JM_CONFIG" 2>/dev/null || printf '%s=%s\n' "$key" "$value" >> "$JM_CONFIG"
}
append_default observe_only 1
append_default thermal_hysteresis_c 5
append_default snapshot_keep 5
append_default snapshot_min_free_mb 256
append_default recent_limit 50
append_default notification_limit 100
append_default lock_stale_seconds 21600
append_default health_log_keep 20
