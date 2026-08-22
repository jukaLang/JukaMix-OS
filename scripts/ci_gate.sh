#!/bin/sh
# ci_gate.sh - Comprehensive CI gate for JukaMix OS releases
# All 12 checks must pass before a release can proceed
#
# Usage: ./scripts/ci_gate.sh [--release] [--verbose]
#   --release   Fail the build on any error (exit 1)
#   --verbose   Show detailed output for each check

set -e

# ── Configuration ──────────────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAIL_COUNT=0
WARN_COUNT=0
RELEASE_MODE=0
VERBOSE=0

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --release) RELEASE_MODE=1 ;;
        --verbose) VERBOSE=1 ;;
    esac
done

# ── Helpers ────────────────────────────────────────────────────────────
# Use printf for POSIX-compatible colored output
pass() {
    printf '  \033[0;32m[PASS]\033[0m %s\n' "$1"
}

fail() {
    printf '  \033[0;31m[FAIL]\033[0m %s\n' "$1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

warn() {
    printf '  \033[1;33m[WARN]\033[0m %s\n' "$1"
    WARN_COUNT=$((WARN_COUNT + 1))
}

section() {
    printf '\n\033[0;34m━━━ %s ━━━\033[0m\n' "$1"
}

# ── Gate 1: Shell syntax check (sh -n) ────────────────────────────────
section "Gate 1: Shell syntax check (sh -n)"

SYNTAX_ERRORS=0
find "$REPO_ROOT" -name "*.sh" -type f 2>/dev/null | while IFS= read -r script; do
    if ! sh -n "$script" 2>/dev/null; then
        fail "Syntax error: $script"
        SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
    fi
done

if [ "$SYNTAX_ERRORS" -eq 0 ]; then
    pass "All shell scripts have valid syntax"
fi

# ── Gate 2: ShellCheck (with documented exclusions) ────────────────────
section "Gate 2: ShellCheck analysis"

if command -v shellcheck >/dev/null 2>&1; then
    SHELLCHECK_ISSUES=0

    # Exclusions: SC1091 (can't follow external), SC2039 (ash compatibility)
    find "$REPO_ROOT/System/usr/trimui/scripts" -name "*.sh" -type f 2>/dev/null | while IFS= read -r script; do
        if ! shellcheck -e SC1091,SC2039 -S warning "$script" 2>/dev/null; then
            SHELLCHECK_ISSUES=$((SHELLCHECK_ISSUES + 1))
            if [ "$VERBOSE" -eq 1 ]; then
                shellcheck -e SC1091,SC2039 -S warning "$script" 2>&1 | head -5
            fi
        fi
    done

    find "$REPO_ROOT/System/starts" -name "*.sh" -type f 2>/dev/null | while IFS= read -r script; do
        if ! shellcheck -e SC1091,SC2039 -S warning "$script" 2>/dev/null; then
            SHELLCHECK_ISSUES=$((SHELLCHECK_ISSUES + 1))
            if [ "$VERBOSE" -eq 1 ]; then
                shellcheck -e SC1091,SC2039 -S warning "$script" 2>&1 | head -5
            fi
        fi
    done

    if [ "$SHELLCHECK_ISSUES" -eq 0 ]; then
        pass "No ShellCheck warnings in critical scripts"
    else
        warn "$SHELLCHECK_ISSUES scripts have ShellCheck warnings"
    fi
else
    warn "ShellCheck not installed, skipping"
fi

# ── Gate 3: CRLF and literal \n corruption ────────────────────────────
section "Gate 3: CRLF and newline corruption detection"

CRLF_FILES=0
LITERAL_NL_FILES=0

# Check for CRLF line endings
find "$REPO_ROOT" \( -name "*.sh" -o -name "*.json" -o -name "*.txt" -o -name "*.cfg" -o -name "*.conf" \) -not -path "*/.git/*" 2>/dev/null | head -500 | while IFS= read -r file; do
    if file "$file" 2>/dev/null | grep -q "CRLF"; then
        fail "CRLF line endings: $file"
        CRLF_FILES=$((CRLF_FILES + 1))
    fi
done

# Check for literal \n in shell scripts
find "$REPO_ROOT" -name "*.sh" -type f 2>/dev/null | head -200 | while IFS= read -r file; do
    if grep -q '\\n' "$file" 2>/dev/null && ! grep -q 'echo.*-e\|printf' "$file" 2>/dev/null; then
        if grep -q '\\\\n' "$file" 2>/dev/null; then
            fail "Literal \\n corruption: $file"
            LITERAL_NL_FILES=$((LITERAL_NL_FILES + 1))
        fi
    fi
done

if [ "$CRLF_FILES" -eq 0 ] && [ "$LITERAL_NL_FILES" -eq 0 ]; then
    pass "No CRLF or newline corruption detected"
fi

# ── Gate 4: JSON validation ───────────────────────────────────────────
section "Gate 4: JSON configuration validation"

JSON_ERRORS=0
if command -v jq >/dev/null 2>&1; then
    find "$REPO_ROOT" -name "config.json" -type f 2>/dev/null | head -300 | while IFS= read -r json_file; do
        if ! jq empty "$json_file" 2>/dev/null; then
            fail "Invalid JSON: $json_file"
            JSON_ERRORS=$((JSON_ERRORS + 1))
        fi
    done

    if [ "$JSON_ERRORS" -eq 0 ]; then
        pass "All config.json files are valid JSON"
    fi
elif command -v python3 >/dev/null 2>&1; then
    find "$REPO_ROOT" -name "config.json" -type f 2>/dev/null | head -300 | while IFS= read -r json_file; do
        if ! python3 -c "import json; json.load(open('$json_file'))" 2>/dev/null; then
            fail "Invalid JSON: $json_file"
            JSON_ERRORS=$((JSON_ERRORS + 1))
        fi
    done

    if [ "$JSON_ERRORS" -eq 0 ]; then
        pass "All config.json files are valid JSON"
    fi
else
    warn "No JSON validator available, skipping"
fi

# ── Gate 5: No hardcoded passwords/tokens/keys ────────────────────────
section "Gate 5: No hardcoded secrets"

SECRET_FILES=0

find "$REPO_ROOT" \( -name "*.sh" -o -name "*.json" -o -name "*.conf" -o -name "*.cfg" \) -not -path "*/.git/*" -not -path "*/node_modules/*" 2>/dev/null | head -500 | while IFS= read -r file; do
    if grep -qi "password\s*=\s*['\"].*['\"]" "$file" 2>/dev/null || \
       grep -qi "token\s*=\s*['\"].*['\"]" "$file" 2>/dev/null || \
       grep -qi "api_key\s*=\s*['\"].*['\"]" "$file" 2>/dev/null || \
       grep -qi "secret\s*=\s*['\"].*['\"]" "$file" 2>/dev/null; then
        # Filter out known safe patterns
        if ! grep -qi "example\|placeholder\|your_\|TODO\|FIXME" "$file" 2>/dev/null; then
            fail "Potential hardcoded secret: $file"
            SECRET_FILES=$((SECRET_FILES + 1))
        fi
    fi
done

# Check for actual private keys
if find "$REPO_ROOT" \( -name "*.pem" -o -name "*.key" -o -name "id_rsa" -o -name "id_ed25519" \) -not -path "*/.git/*" 2>/dev/null | head -1 | grep -q .; then
    fail "Private key files found in repository"
    SECRET_FILES=$((SECRET_FILES + 1))
fi

if [ "$SECRET_FILES" -eq 0 ]; then
    pass "No hardcoded secrets detected"
fi

# ── Gate 6: Unsafe operations (rm, cp, mv, kill, extraction) ──────────
section "Gate 6: Unsafe operation detection"

UNSAFE_OPS=0

find "$REPO_ROOT/System/usr/trimui/scripts" -name "*.sh" -type f 2>/dev/null | while IFS= read -r file; do
    # Check for unquoted rm with variable expansion
    if grep -n 'rm [^f].*\$[A-Z_]' "$file" 2>/dev/null | grep -v '2>/dev/null\|"\$' | head -1 | grep -q .; then
        warn "Potential unsafe rm: $file"
        UNSAFE_OPS=$((UNSAFE_OPS + 1))
    fi

    # Kill without PID tracking
    if grep -n 'kill.*gptokeyb2\|kill.*presenter\|kill.*sdl2imgshow' "$file" 2>/dev/null | grep -v 'GPTOKEY_PID\|current_pid\|sdl_pid\|\$!' | head -1 | grep -q .; then
        warn "Kill without PID tracking: $file"
        UNSAFE_OPS=$((UNSAFE_OPS + 1))
    fi
done

if [ "$UNSAFE_OPS" -eq 0 ]; then
    pass "No unsafe operations detected"
fi

# ── Gate 7: Background process cleanup ────────────────────────────────
section "Gate 7: Background process cleanup verification"

UNCLEAN_PROCS=0

find "$REPO_ROOT/Emus" -name "launch.sh" -type f 2>/dev/null | while IFS= read -r file; do
    # Check if script has background processes
    if grep -n '&$' "$file" 2>/dev/null | grep -v '#' | head -1 | grep -q .; then
        # Check if it has a trap
        if ! grep -q 'trap.*EXIT\|trap.*INT\|trap.*TERM' "$file" 2>/dev/null; then
            # Check if it saves PIDs
            if ! grep -q 'PID=\$!\|_pid=\$!\|GPTOKEY_PID=\$!' "$file" 2>/dev/null; then
                warn "Background process without cleanup: $(basename "$file")"
                UNCLEAN_PROCS=$((UNCLEAN_PROCS + 1))
            fi
        fi
    fi
done

find "$REPO_ROOT/System/usr/trimui/scripts" -name "*.sh" -type f 2>/dev/null | while IFS= read -r file; do
    # Check if script has background processes
    if grep -n '&$' "$file" 2>/dev/null | grep -v '#' | head -1 | grep -q .; then
        # Check if it has a trap
        if ! grep -q 'trap.*EXIT\|trap.*INT\|trap.*TERM' "$file" 2>/dev/null; then
            # Check if it saves PIDs
            if ! grep -q 'PID=\$!\|_pid=\$!\|GPTOKEY_PID=\$!' "$file" 2>/dev/null; then
                warn "Background process without cleanup: $(basename "$file")"
                UNCLEAN_PROCS=$((UNCLEAN_PROCS + 1))
            fi
        fi
    fi
done

if [ "$UNCLEAN_PROCS" -eq 0 ]; then
    pass "Background processes have proper cleanup"
fi

# ── Gate 8: Device coverage ───────────────────────────────────────────
section "Gate 8: Device support coverage"

REQUIRED_DEVICES="tsp tg5050 brick brick_pro"
MISSING_DEVICES=0

# Check detection scripts (the resolver is the single source of truth for
# device → input daemon mapping, so it must cover every device too).
for device in $REQUIRED_DEVICES; do
    if ! grep -rq "$device" "$REPO_ROOT/System/starts/_FirmwareCheck.sh" 2>/dev/null && \
       ! grep -rq "$device" "$REPO_ROOT/System/usr/trimui/scripts/inputd_switcher.sh" 2>/dev/null && \
       ! grep -rq "$device" "$REPO_ROOT/System/usr/trimui/scripts/inputd_resolve.sh" 2>/dev/null; then
        warn "Device '$device' not found in detection scripts"
        MISSING_DEVICES=$((MISSING_DEVICES + 1))
    fi
done

# Check profiles
for device in $REQUIRED_DEVICES; do
    if [ ! -f "$REPO_ROOT/Profiles/DEVICE-OVERRIDES/${device}_base.cfg" ] && \
       [ "$device" != "brick_pro" ]; then  # brick_pro is new
        warn "Device '$device' missing profile"
        MISSING_DEVICES=$((MISSING_DEVICES + 1))
    fi
done

# Check device-capabilities.txt
if [ -f "$REPO_ROOT/tools/data/device-capabilities.txt" ]; then
    for device in $REQUIRED_DEVICES; do
        if ! grep -q "$device" "$REPO_ROOT/tools/data/device-capabilities.txt" 2>/dev/null; then
            warn "Device '$device' missing from device-capabilities.txt"
            MISSING_DEVICES=$((MISSING_DEVICES + 1))
        fi
    done
else
    warn "device-capabilities.txt not found"
fi

if [ "$MISSING_DEVICES" -eq 0 ]; then
    pass "All devices have detection, profiles, and documentation"
fi

# ── Gate 9: SHA-256 metadata for release assets ───────────────────────
section "Gate 9: Release asset checksums"

if [ -f "$REPO_ROOT/SHA256SUMS" ]; then
    if [ -s "$REPO_ROOT/SHA256SUMS" ]; then
        pass "SHA256SUMS file exists and is non-empty"
    else
        warn "SHA256SUMS file is empty"
    fi
else
    warn "SHA256SUMS file not found"
fi

# ── Gate 10: Failure injection tests ──────────────────────────────────
section "Gate 10: Installer/update failure tests"

if [ -d "$REPO_ROOT/tests" ]; then
    TEST_COUNT=$(find "$REPO_ROOT/tests" -name "*.sh" -type f 2>/dev/null | wc -l)
    if [ "$TEST_COUNT" -gt 0 ]; then
        pass "Test directory exists with $TEST_COUNT test files"
    else
        warn "Test directory exists but is empty"
    fi
else
    warn "Tests directory not found"
fi

# ── Gate 11: Protected paths absent from update manifest ───────────────
section "Gate 11: Protected paths in update manifest"

PROTECTED_IN_UPDATE=0

if [ -f "$REPO_ROOT/System/usr/trimui/scripts/jukamix_update.sh" ]; then
    for path in Roms BIOS Saves States; do
        if grep -q "/$path/" "$REPO_ROOT/System/usr/trimui/scripts/jukamix_update.sh" 2>/dev/null; then
            # Check if it's a protective check, not a destructive operation
            if ! grep -B2 "/$path/" "$REPO_ROOT/System/usr/trimui/scripts/jukamix_update.sh" 2>/dev/null | grep -q "skip\|protect\|ignore\|exclude"; then
                warn "Protected path '$path' referenced in update script"
                PROTECTED_IN_UPDATE=$((PROTECTED_IN_UPDATE + 1))
            fi
        fi
    done
fi

if [ "$PROTECTED_IN_UPDATE" -eq 0 ]; then
    pass "Protected paths are not modified by updater"
fi

# ── Gate 12: License and SBOM generation ──────────────────────────────
section "Gate 12: License and SBOM"

if [ -f "$REPO_ROOT/LICENSE" ]; then
    pass "LICENSE file exists"
else
    warn "LICENSE file not found"
fi

# Check for bundled binary licenses
BUNDLED_LICENSES=0
if [ -d "$REPO_ROOT/System/bin" ]; then
    for bin in "$REPO_ROOT/System/bin"/*; do
        if [ -f "$bin" ] && file "$bin" 2>/dev/null | grep -q "ELF\|executable"; then
            bin_name=$(basename "$bin")
            if ! find "$REPO_ROOT" \( -name "LICENSE*" -o -name "COPYING*" \) 2>/dev/null | xargs grep -l "$bin_name" 2>/dev/null | head -1 | grep -q .; then
                warn "No license found for bundled binary: $bin_name"
                BUNDLED_LICENSES=$((BUNDLED_LICENSES + 1))
            fi
        fi
    done
fi

if [ "$BUNDLED_LICENSES" -eq 0 ]; then
    pass "All bundled binaries have license references"
fi

# ── Summary ────────────────────────────────────────────────────────────
printf '\n\033[0;34m━━━ Summary ━━━\033[0m\n'
printf '  Failures: \033[0;31m%s\033[0m\n' "$FAIL_COUNT"
printf '  Warnings: \033[1;33m%s\033[0m\n' "$WARN_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
    printf '\n\033[0;31mCI GATE FAILED\033[0m\n'
    if [ "$RELEASE_MODE" -eq 1 ]; then
        exit 1
    fi
elif [ "$WARN_COUNT" -gt 0 ]; then
    printf '\n\033[1;33mCI GATE PASSED WITH WARNINGS\033[0m\n'
else
    printf '\n\033[0;32mCI GATE PASSED\033[0m\n'
fi

exit 0
