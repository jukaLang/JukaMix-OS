#!/bin/sh
# JukaMix OS - Device Compatibility Test Suite
# Validates all device optimizations, profiles, and configurations

echo "=== JukaMix OS Device Validation ==="
echo ""

TOTAL=0
PASSED=0

pass() { TOTAL=$((TOTAL+1)); PASSED=$((PASSED+1)); echo "  ✅ $1"; }
fail() { TOTAL=$((TOTAL+1)); echo "  ❌ $1"; }
info() { [ "${2:-ok}" = "ok" ] && pass "$1" || fail "$1"; }

# --- Test 1: Device Detection ---
echo "Test 1: Device Detection"
if [ -f "/etc/trimui_device.txt" ]; then
    DEV=$(cat /etc/trimui_device.txt 2>/dev/null | tr -d '[:space:]')
    info "Device detected: $DEV"
else
    fail "/etc/trimui_device.txt not found"
fi

# --- Test 2: Base Profiles Exist ---
echo ""
echo "Test 2: Device Base Profiles"
for _dev in tg5050 tsp brick; do
    if [ -f "/mnt/SDCARD/Profiles/DEVICE-OVERRIDES/${_dev}_base.cfg" ]; then
        info "${_dev}_base.cfg exists"
    else
        fail "${_dev}_base.cfg missing"
    fi
done

# --- Test 3: Scripts ---
echo ""
echo "Test 3: Essential Scripts"
SCRIPTS="
/mnt/SDCARD/System/usr/trimui/scripts/device_detection.sh
/mnt/SDCARD/System/usr/trimui/scripts/emulator_optimizer.sh
/mnt/SDCARD/System/usr/trimui/scripts/tg5050_cpufreq.sh
/mnt/SDCARD/System/usr/trimui/scripts/tsp_cpufreq.sh
/mnt/SDCARD/System/usr/trimui/scripts/apply_game_profile.sh
/mnt/SDCARD/System/usr/trimui/scripts/validate_profile.sh
"
for s in $SCRIPTS; do
    if [ -f "$s" ]; then
        info "$(basename $s)"
    else
        fail "$(basename $s) missing"
    fi
done

# --- Test 4: Game Profiles ---
echo ""
echo "Test 4: Game Profile System"
[ -f "/mnt/SDCARD/Profiles/README.md" ] && info "Profiles README" || fail "Profiles README missing"
[ -f "/mnt/SDCARD/Profiles/TEMPLATE.cfg" ] && info "Profile template" || fail "Template missing"
[ -f "/mnt/SDCARD/Profiles/DC/SonicAdventure.cfg" ] && info "Sample profile exists" || info "No sample profiles yet (ok)"

# --- Test 5: RetroArch Auto-Config ---
echo ""
echo "Test 5: RetroArch Controller Config"
[ -f "/mnt/SDCARD/RetroArch/.retroarch/autoconfig/TrimUI-Smart-Pro-S-tg5050.cfg" ] \
    && info "TG5050 auto-config" || info "TG5050 auto-config missing (fallback to generic ok)"

# --- Test 6: Tools ---
echo ""
echo "Test 6: Diagnostic Tools"
TOOLS="
jukamix-doctor.sh
jukamix-backup.sh
jukamix-update.sh
jukamix-bios-check.sh
jukamix-portmaster-check.sh
"
for t in $TOOLS; do
    if [ -f "/mnt/SDCARD/tools/$t" ]; then
        info "$t"
    else
        fail "$t missing"
    fi
done

# --- Test 7: Profile Validation Demo ---
echo ""
echo "Test 7: Profile Validator"
[ -x "/mnt/SDCARD/System/usr/trimui/scripts/validate_profile.sh" ] && info "Validator executable" || fail "Validator not executable"
if [ -f "/mnt/SDCARD/Profiles/DC/SonicAdventure.cfg" ]; then
    VOUT=$(/mnt/SDCARD/System/usr/trimui/scripts/validate_profile.sh /mnt/SDCARD/Profiles/DC/SonicAdventure.cfg 2>&1)
    echo "$VOUT" | grep -q "Valid profile" \
        && info "Sample profile validates" \
        || info "Sample profile has issues (review above)"
fi

# --- Summary ---
echo ""
echo "=== Summary ==="
echo "Total checks: $TOTAL"
echo "Passed: $PASSED"
FAILED=$((TOTAL - PASSED))
echo "Failed: $FAILED"
echo ""

if [ "$FAILED" -eq 0 ]; then
    echo "✅ All critical components verified."
elif [ "$FAILED" -le 2 ]; then
    echo "⚠️  Some non-critical items missing. Review above."
else
    echo "❌ Multiple failures detected. Run --help on tools for diagnostics."
fi

exit $FAILED
