#!/bin/sh
# JukaMix OS - jm-portmaster installer tests (host-safe, offline).
#
# Builds a minimal fake PortMaster zip, then exercises status / ensure / fix /
# install --from-zip / launcher regeneration against a scratch tree. No network
# access is required.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

export JUKAMIX_ROOT="$TMP"
PM_TOOL="$ROOT/bin/jm-portmaster"
PM_APPS="$TMP/Apps/PortMaster"
PM_DIR="$PM_APPS/PortMaster"
PM_DATA="$TMP/Data/ports"
PM_ROMS="$TMP/Roms/PORTS"

fail() { echo "test_portmaster: FAIL: $*" >&2; exit 1; }
ok()   { echo "test_portmaster: $*"; }

# --- build a fake but structurally valid PortMaster zip ---------------------
ZIP="$TMP/fake-trimui.portmaster.zip"
if command -v python3 >/dev/null 2>&1; then
    python3 - "$ZIP" <<'PY'
import sys, zipfile
zip_path = sys.argv[1]
base = "Apps/PortMaster/PortMaster/"
files = {
    base + "version": "2026.06.23-0015\n",
    base + "pugwash": "#!/bin/sh\necho fake pugwash\n",
    base + "trimui/update.txt": "#!/bin/bash\n# no-op for tests\n",
}
with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
    for name, data in files.items():
        zf.writestr(name, data)
PY
else
    fail "python3 required to build test zip"
fi

# --- 1. status on an empty tree ---------------------------------------------
OUT=$(JUKAMIX_ROOT="$TMP" sh "$PM_TOOL" status)
echo "$OUT" | grep -q '^installed=no$' || fail "status should report not installed"
echo "$OUT" | grep -q '^ports_dir=no$' || fail "status should report missing Data/ports"
echo "$OUT" | grep -q '^launcher=no$'  || fail "status should report missing launcher"
ok "status reports a clean (not installed) state"

# --- 2. install --from-zip (offline) ----------------------------------------
OUT=$(JUKAMIX_ROOT="$TMP" sh "$PM_TOOL" install --from-zip "$ZIP" 2>&1) || fail "install --from-zip failed: $OUT"
[ -x "$PM_DIR/pugwash" ] || fail "pugwash not installed/executable"
[ "$(cat "$PM_DIR/version")" = "2026.06.23-0015" ] || fail "version not installed"
[ -d "$PM_DATA" ] || fail "Data/ports not created"
[ -f "$PM_ROMS/PortMaster.sh" ] || fail "Roms/PORTS/PortMaster.sh not created"
[ -x "$PM_ROMS/PortMaster.sh" ] || fail "Roms/PORTS/PortMaster.sh not executable"
ok "install --from-zip installs, creates Data/ports and the PORTS entry point"

# --- 3. status now reports installed ----------------------------------------
OUT=$(JUKAMIX_ROOT="$TMP" sh "$PM_TOOL" status)
echo "$OUT" | grep -q '^installed=yes$' || fail "status should report installed"
echo "$OUT" | grep -q '^version=2026.06.23-0015$' || fail "status should report version"
echo "$OUT" | grep -q '^ports_dir=yes$' || fail "status should report ports dir"
echo "$OUT" | grep -q '^launcher=yes$'  || fail "status should report launcher"
ok "status reflects the installed state"

# --- 4. ensure is a no-op when healthy --------------------------------------
BEFORE=$(cat "$PM_DIR/version")
OUT=$(JUKAMIX_ROOT="$TMP" sh "$PM_TOOL" ensure 2>&1) || fail "ensure failed on healthy install: $OUT"
echo "$OUT" | grep -q 'healthy' || fail "ensure should report healthy: $OUT"
[ "$(cat "$PM_DIR/version")" = "$BEFORE" ] || fail "ensure must not replace a healthy install"
ok "ensure no-ops on a healthy install"

# --- 5. ensure installs when broken (launcher removed) -----------------------
rm -f "$PM_ROMS/PortMaster.sh"
JUKAMIX_ROOT="$TMP" sh "$PM_TOOL" ensure >/dev/null 2>&1 || fail "ensure should not fail"
[ -f "$PM_ROMS/PortMaster.sh" ] || fail "ensure did not restore launcher"
ok "ensure self-heals the PORTS entry point"

# --- 6. ensure installs from --from-zip when missing -------------------------
rm -rf "$PM_APPS"
JUKAMIX_ROOT="$TMP" sh "$PM_TOOL" ensure --from-zip "$ZIP" >/dev/null 2>&1 || fail "ensure --from-zip failed"
[ -x "$PM_DIR/pugwash" ] || fail "ensure --from-zip did not install"
ok "ensure --from-zip installs a missing PortMaster"

# --- 7. fix repairs exec bits and missing dirs -------------------------------
chmod -x "$PM_DIR/pugwash"
rm -rf "$PM_DATA"
JUKAMIX_ROOT="$TMP" sh "$PM_TOOL" fix >/dev/null 2>&1
[ -x "$PM_DIR/pugwash" ] || fail "fix did not restore exec bit on pugwash"
[ -d "$PM_DATA" ] || fail "fix did not recreate Data/ports"
ok "fix repairs exec bits and directories offline"

# --- 8. rejects a fake/placeholder bundle (version floor) --------------------
mkdir -p "$PM_DIR"
printf '0.0.0\n' > "$PM_DIR/version"
printf '#!/bin/sh\n' > "$PM_DIR/pugwash"
chmod +x "$PM_DIR/pugwash"
if JUKAMIX_ROOT="$TMP" sh "$PM_TOOL" status | grep -q '^installed=yes$'; then
    fail "placeholder version must not count as installed"
fi
ok "placeholder/old bundles are not treated as installed"

echo "test_portmaster: PASS"
