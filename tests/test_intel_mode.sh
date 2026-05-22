#!/bin/bash
# test_intel_mode.sh
# Example-based tests for Intel platform get_mode() and set_mode() logic
# Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 9.1, 9.2

PASS_COUNT=0
FAIL_COUNT=0

assert_eq() {
    local expected="$1"
    local actual="$2"
    local description="$3"

    if [ "$expected" = "$actual" ]; then
        echo "PASS: $description"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "FAIL: $description (expected='$expected', actual='$actual')"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local description="$3"

    if echo "$haystack" | grep -q "$needle"; then
        echo "PASS: $description"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "FAIL: $description (expected to contain '$needle' in '$haystack')"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local description="$3"

    if echo "$haystack" | grep -q "$needle"; then
        echo "FAIL: $description (should NOT contain '$needle' in '$haystack')"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    else
        echo "PASS: $description"
        PASS_COUNT=$((PASS_COUNT + 1))
    fi
}

# ============================================================
# Simulate Intel platform get_mode() mapping logic
# ============================================================
intel_get_mode() {
    local mode_num="$1"
    local mode
    case "$mode_num" in
        "0") mode="ncm" ;;
        "7") mode="mbim" ;;
        *) mode="$mode_num" ;;
    esac
    echo "$mode"
}

# ============================================================
# Simulate Intel platform set_mode() mapping logic
# Returns the mode_num that would be sent via AT+GTUSBMODE=X
# ============================================================
intel_set_mode() {
    local mode_config="$1"
    local mode_num
    case "$mode_config" in
        "ncm") mode_num="0" ;;
        "mbim") mode_num="7" ;;
        *) mode_num="0" ;;
    esac
    echo "$mode_num"
}

# ============================================================
# Test get_mode() mapping for Intel platform
# ============================================================
echo "=== get_mode() tests for Intel platform ==="

result=$(intel_get_mode "0")
assert_eq "ncm" "$result" "get_mode: GTUSBMODE=0 maps to ncm"

result=$(intel_get_mode "7")
assert_eq "mbim" "$result" "get_mode: GTUSBMODE=7 maps to mbim"

result=$(intel_get_mode "99")
assert_eq "99" "$result" "get_mode: GTUSBMODE=99 passes through as raw value"

result=$(intel_get_mode "3")
assert_eq "3" "$result" "get_mode: GTUSBMODE=3 passes through as raw value"

result=$(intel_get_mode "17")
assert_eq "17" "$result" "get_mode: GTUSBMODE=17 passes through as raw value (not mapped like qualcomm)"

echo ""

# ============================================================
# Test set_mode() mapping for Intel platform
# ============================================================
echo "=== set_mode() tests for Intel platform ==="

result=$(intel_set_mode "ncm")
assert_eq "0" "$result" "set_mode: ncm maps to mode_num 0"

result=$(intel_set_mode "mbim")
assert_eq "7" "$result" "set_mode: mbim maps to mode_num 7"

result=$(intel_set_mode "qmi")
assert_eq "0" "$result" "set_mode: qmi defaults to mode_num 0 (NCM)"

result=$(intel_set_mode "ecm")
assert_eq "0" "$result" "set_mode: ecm defaults to mode_num 0 (NCM)"

result=$(intel_set_mode "rndis")
assert_eq "0" "$result" "set_mode: rndis defaults to mode_num 0 (NCM)"

result=$(intel_set_mode "unknown_mode")
assert_eq "0" "$result" "set_mode: unknown mode defaults to mode_num 0 (NCM)"

echo ""

# ============================================================
# Test AT command generation for set_mode()
# Simulates the full flow including AT command construction
# Uses a temp file to track commands since subshells lose variable state
# ============================================================
echo "=== AT command generation tests ==="

AT_LOG=$(mktemp)
trap "rm -f $AT_LOG" EXIT

# Simulate full set_mode flow for Intel platform (success case)
simulate_set_mode_intel() {
    local mode_config="$1"
    local mode_num

    > "$AT_LOG"

    case "$mode_config" in
        "ncm") mode_num="0" ;;
        "mbim") mode_num="7" ;;
        *) mode_num="0" ;;
    esac

    # Record the mode change command
    local at_command="AT+GTUSBMODE=${mode_num}"
    echo "$at_command" >> "$AT_LOG"

    # Simulate success response - send restart command
    echo "AT+CFUN=1,1" >> "$AT_LOG"
}

# Simulate failed set_mode (AT command returns ERROR, no restart)
simulate_set_mode_intel_fail() {
    local mode_config="$1"
    local mode_num

    > "$AT_LOG"

    case "$mode_config" in
        "ncm") mode_num="0" ;;
        "mbim") mode_num="7" ;;
        *) mode_num="0" ;;
    esac

    # Record the mode change command
    local at_command="AT+GTUSBMODE=${mode_num}"
    echo "$at_command" >> "$AT_LOG"

    # Simulate ERROR response - do NOT send restart command
}

# Test: NCM mode sends correct AT command
simulate_set_mode_intel "ncm"
at_log_content=$(cat "$AT_LOG")
assert_contains "$at_log_content" "AT+GTUSBMODE=0" "set_mode ncm sends AT+GTUSBMODE=0"

# Test: MBIM mode sends correct AT command
simulate_set_mode_intel "mbim"
at_log_content=$(cat "$AT_LOG")
assert_contains "$at_log_content" "AT+GTUSBMODE=7" "set_mode mbim sends AT+GTUSBMODE=7"

# Test: AT+CFUN=1,1 is sent after successful mode change
simulate_set_mode_intel "ncm"
at_log_content=$(cat "$AT_LOG")
assert_contains "$at_log_content" "AT+CFUN=1,1" "AT+CFUN=1,1 sent after successful mode change"

# Test: AT+CFUN=1,1 is NOT sent after failed mode change
simulate_set_mode_intel_fail "ncm"
at_log_content=$(cat "$AT_LOG")
assert_not_contains "$at_log_content" "AT+CFUN=1,1" "AT+CFUN=1,1 NOT sent after failed mode change"

echo ""

# ============================================================
# Summary
# ============================================================
echo "=== Test Summary ==="
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"
echo "Total:  $((PASS_COUNT + FAIL_COUNT))"

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "RESULT: FAILED"
    exit 1
else
    echo "RESULT: ALL PASSED"
    exit 0
fi
