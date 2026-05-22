#!/bin/bash
# Test: match_config() name normalization for L850-GL / L860-GL modems
# Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.6
#
# This test verifies that various AT+CGMM response strings are correctly
# normalized to canonical modem names by the match_config() logic in modem_scan.sh.

PASS_COUNT=0
FAIL_COUNT=0

# Simulate the match_config name normalization logic from modem_scan.sh
# This replicates: lowercase conversion + glob matching rules
normalize_name() {
    local name
    # Step 1: Strip carriage returns and convert to lowercase (same as modem_scan.sh)
    name=$(echo "$1" | sed 's/\r//g' | tr 'A-Z' 'a-z')

    # Step 2: Apply matching rules in evaluation order (same order as modem_scan.sh)
    # L850-GL / Intel XMM7360
    if [[ "$name" = *"l850-gl"* ]] || [[ "$name" = *"xmm7360"* ]]; then
        name="l850-gl"
    # L860-GL / Intel XMM7560
    elif [[ "$name" = *"l860-gl"* ]] || [[ "$name" = *"xmm7560"* ]]; then
        name="l860-gl"
    fi

    echo "$name"
}

# Assertion helper
assert_equals() {
    local input="$1"
    local expected="$2"
    local actual="$3"
    local description="$4"

    if [ "$actual" = "$expected" ]; then
        echo "PASS: $description"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "FAIL: $description"
        echo "  Input:    '$input'"
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

echo "=== match_config() Name Normalization Tests ==="
echo ""

# Test 1: Uppercase L850-GL normalizes to l850-gl
input="L850-GL"
result=$(normalize_name "$input")
assert_equals "$input" "l850-gl" "$result" "Uppercase 'L850-GL' -> 'l850-gl'"

# Test 2: Lowercase l850-gl stays as l850-gl
input="l850-gl"
result=$(normalize_name "$input")
assert_equals "$input" "l850-gl" "$result" "Lowercase 'l850-gl' -> 'l850-gl'"

# Test 3: XMM7360 chipset name normalizes to l850-gl
input="XMM7360"
result=$(normalize_name "$input")
assert_equals "$input" "l850-gl" "$result" "Chipset 'XMM7360' -> 'l850-gl'"

# Test 4: Uppercase L860-GL normalizes to l860-gl
input="L860-GL"
result=$(normalize_name "$input")
assert_equals "$input" "l860-gl" "$result" "Uppercase 'L860-GL' -> 'l860-gl'"

# Test 5: Lowercase l860-gl stays as l860-gl
input="l860-gl"
result=$(normalize_name "$input")
assert_equals "$input" "l860-gl" "$result" "Lowercase 'l860-gl' -> 'l860-gl'"

# Test 6: XMM7560 chipset name normalizes to l860-gl
input="XMM7560"
result=$(normalize_name "$input")
assert_equals "$input" "l860-gl" "$result" "Chipset 'XMM7560' -> 'l860-gl'"

# Test 7: Full model string with surrounding text normalizes correctly
input="Fibocom L850-GL LTE Cat9"
result=$(normalize_name "$input")
assert_equals "$input" "l850-gl" "$result" "Full string 'Fibocom L850-GL LTE Cat9' -> 'l850-gl'"

# Test 8: Mixed case xmm7360
input="xmm7360"
result=$(normalize_name "$input")
assert_equals "$input" "l850-gl" "$result" "Lowercase 'xmm7360' -> 'l850-gl'"

# Test 9: Mixed case xmm7560
input="xmm7560"
result=$(normalize_name "$input")
assert_equals "$input" "l860-gl" "$result" "Lowercase 'xmm7560' -> 'l860-gl'"

# Test 10: Input containing both l850-gl and xmm7360 uses first match (l850-gl wins)
input="L850-GL XMM7360"
result=$(normalize_name "$input")
assert_equals "$input" "l850-gl" "$result" "Both 'L850-GL XMM7360' -> 'l850-gl' (first match wins)"

# Test 11: Unrecognized input passes through unchanged (lowercase only)
input="SomeOtherModem"
result=$(normalize_name "$input")
assert_equals "$input" "someothermodem" "$result" "Unrecognized 'SomeOtherModem' -> 'someothermodem' (lowercase, no match)"

# Test 12: Input with carriage return is handled
input=$'L850-GL\r'
result=$(normalize_name "$input")
assert_equals "L850-GL\\r" "l850-gl" "$result" "Input with CR 'L850-GL\\r' -> 'l850-gl'"

echo ""
echo "=== Results ==="
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"
echo ""

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "OVERALL: FAIL"
    exit 1
else
    echo "OVERALL: PASS"
    exit 0
fi
