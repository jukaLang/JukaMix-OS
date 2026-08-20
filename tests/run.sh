#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sh "$ROOT/tools/validate-pack.sh"
sh "$ROOT/tests/test_common.sh"
sh "$ROOT/tests/test_session.sh"
sh "$ROOT/tests/test_install.sh"
sh "$ROOT/tests/test_portmaster.sh"
echo "All tests passed."
