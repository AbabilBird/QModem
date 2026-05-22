#!/bin/bash
# Smoke tests for L850-GL and L860-GL JSON registry entries
# Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 3.1, 3.2

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MODEM_SUPPORT="$REPO_ROOT/application/qmodem/files/usr/share/qmodem/modem_support.json"
MODEM_PORT_RULE="$REPO_ROOT/application/qmodem/files/usr/share/qmodem/modem_port_rule.json"

PASS=0
FAIL=0

assert_eq() {
    local description="$1"
    local expected="$2"
    local actual="$3"

    if [ "$expected" = "$actual" ]; then
        echo "  PASS: $description"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $description (expected='$expected', actual='$actual')"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local description="$1"
    local haystack="$2"
    local needle="$3"

    if echo "$haystack" | grep -q "$needle"; then
        echo "  PASS: $description"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $description (expected to contain '$needle' in '$haystack')"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_exists() {
    local description="$1"
    local value="$2"

    if [ "$value" = "null" ] || [ -z "$value" ]; then
        echo "  PASS: $description"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $description (expected null/empty, got '$value')"
        FAIL=$((FAIL + 1))
    fi
}

# Check jq is available
if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required but not installed"
    exit 1
fi

# Check JSON files exist
if [ ! -f "$MODEM_SUPPORT" ]; then
    echo "ERROR: modem_support.json not found at $MODEM_SUPPORT"
    exit 1
fi

if [ ! -f "$MODEM_PORT_RULE" ]; then
    echo "ERROR: modem_port_rule.json not found at $MODEM_PORT_RULE"
    exit 1
fi

echo "=== modem_support.json: L850-GL entry ==="

# L850-GL exists under .modem_support.usb
l850_entry=$(jq -r '.modem_support.usb["l850-gl"]' "$MODEM_SUPPORT")
assert_eq "l850-gl entry exists" "true" "$([ "$l850_entry" != "null" ] && echo true || echo false)"

# L850-GL fields
assert_eq "l850-gl manufacturer=fibocom" "fibocom" "$(jq -r '.modem_support.usb["l850-gl"].manufacturer' "$MODEM_SUPPORT")"
assert_eq "l850-gl platform=intel" "intel" "$(jq -r '.modem_support.usb["l850-gl"].platform' "$MODEM_SUPPORT")"
assert_eq "l850-gl data_interface=usb" "usb" "$(jq -r '.modem_support.usb["l850-gl"].data_interface' "$MODEM_SUPPORT")"
assert_eq "l850-gl pdp_index=1" "1" "$(jq -r '.modem_support.usb["l850-gl"].pdp_index' "$MODEM_SUPPORT")"
assert_eq "l850-gl manufacturer_id=8087" "8087" "$(jq -r '.modem_support.usb["l850-gl"].manufacturer_id' "$MODEM_SUPPORT")"

# L850-GL modes
l850_modes=$(jq -r '.modem_support.usb["l850-gl"].modes[]' "$MODEM_SUPPORT")
assert_contains "l850-gl modes contains ncm" "$l850_modes" "ncm"
assert_contains "l850-gl modes contains mbim" "$l850_modes" "mbim"

# L850-GL bands
assert_eq "l850-gl lte_band" "1/2/3/4/5/7/8/12/13/17/18/19/20/26/28/29/30/66/41" "$(jq -r '.modem_support.usb["l850-gl"].lte_band' "$MODEM_SUPPORT")"
assert_eq "l850-gl wcdma_band" "1/2/4/5/8" "$(jq -r '.modem_support.usb["l850-gl"].wcdma_band' "$MODEM_SUPPORT")"
assert_eq "l850-gl nsa_band=0" "0" "$(jq -r '.modem_support.usb["l850-gl"].nsa_band' "$MODEM_SUPPORT")"
assert_eq "l850-gl sa_band=0" "0" "$(jq -r '.modem_support.usb["l850-gl"].sa_band' "$MODEM_SUPPORT")"

echo ""
echo "=== modem_support.json: L860-GL entry ==="

# L860-GL exists under .modem_support.usb
l860_entry=$(jq -r '.modem_support.usb["l860-gl"]' "$MODEM_SUPPORT")
assert_eq "l860-gl entry exists" "true" "$([ "$l860_entry" != "null" ] && echo true || echo false)"

# L860-GL fields
assert_eq "l860-gl manufacturer=fibocom" "fibocom" "$(jq -r '.modem_support.usb["l860-gl"].manufacturer' "$MODEM_SUPPORT")"
assert_eq "l860-gl platform=intel" "intel" "$(jq -r '.modem_support.usb["l860-gl"].platform' "$MODEM_SUPPORT")"
assert_eq "l860-gl data_interface=usb" "usb" "$(jq -r '.modem_support.usb["l860-gl"].data_interface' "$MODEM_SUPPORT")"
assert_eq "l860-gl pdp_index=1" "1" "$(jq -r '.modem_support.usb["l860-gl"].pdp_index' "$MODEM_SUPPORT")"
assert_eq "l860-gl manufacturer_id=2cb7" "2cb7" "$(jq -r '.modem_support.usb["l860-gl"].manufacturer_id' "$MODEM_SUPPORT")"

# L860-GL modes
l860_modes=$(jq -r '.modem_support.usb["l860-gl"].modes[]' "$MODEM_SUPPORT")
assert_contains "l860-gl modes contains ncm" "$l860_modes" "ncm"
assert_contains "l860-gl modes contains mbim" "$l860_modes" "mbim"

# L860-GL should NOT have band fields (Requirement 1.8)
assert_not_exists "l860-gl has no lte_band" "$(jq -r '.modem_support.usb["l860-gl"].lte_band' "$MODEM_SUPPORT")"
assert_not_exists "l860-gl has no wcdma_band" "$(jq -r '.modem_support.usb["l860-gl"].wcdma_band' "$MODEM_SUPPORT")"
assert_not_exists "l860-gl has no nsa_band" "$(jq -r '.modem_support.usb["l860-gl"].nsa_band' "$MODEM_SUPPORT")"
assert_not_exists "l860-gl has no sa_band" "$(jq -r '.modem_support.usb["l860-gl"].sa_band' "$MODEM_SUPPORT")"

echo ""
echo "=== modem_port_rule.json: USB port rules ==="

# 8087:095a entry
assert_eq "8087:095a entry exists" "true" "$(jq -r '.modem_port_rule.usb["8087:095a"] != null' "$MODEM_PORT_RULE")"
assert_eq "8087:095a name=l850-gl" "l850-gl" "$(jq -r '.modem_port_rule.usb["8087:095a"].name' "$MODEM_PORT_RULE")"
assert_eq "8087:095a mode=ncm" "ncm" "$(jq -r '.modem_port_rule.usb["8087:095a"].mode' "$MODEM_PORT_RULE")"
assert_eq "8087:095a option_driver=1" "1" "$(jq -r '.modem_port_rule.usb["8087:095a"].option_driver' "$MODEM_PORT_RULE")"

# 2cb7:0007 entry
assert_eq "2cb7:0007 entry exists" "true" "$(jq -r '.modem_port_rule.usb["2cb7:0007"] != null' "$MODEM_PORT_RULE")"
assert_eq "2cb7:0007 name=l850-gl" "l850-gl" "$(jq -r '.modem_port_rule.usb["2cb7:0007"].name' "$MODEM_PORT_RULE")"
assert_eq "2cb7:0007 mode=mbim" "mbim" "$(jq -r '.modem_port_rule.usb["2cb7:0007"].mode' "$MODEM_PORT_RULE")"
assert_eq "2cb7:0007 option_driver=1" "1" "$(jq -r '.modem_port_rule.usb["2cb7:0007"].option_driver' "$MODEM_PORT_RULE")"

echo ""
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "Total:  $((PASS + FAIL))"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi

echo ""
echo "All smoke tests passed!"
exit 0
