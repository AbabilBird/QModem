#!/bin/bash
# Test: Intel platform signal info fallback chain
# Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.5, 6.1, 6.2, 6.3, 6.4, 6.5
#
# This test validates the expected signal info parsing and fallback behavior
# for Intel XMM platform modems (L850-GL / L860-GL) by simulating AT command
# response parsing logic extracted from fibocom.sh.

PASS_COUNT=0
FAIL_COUNT=0

assert_eq() {
    local expected="$1"
    local actual="$2"
    local description="$3"

    if [ "$expected" = "$actual" ]; then
        echo "  PASS: $description"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  FAIL: $description"
        echo "    Expected: '$expected'"
        echo "    Actual:   '$actual'"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

assert_not_empty() {
    local actual="$1"
    local description="$2"

    if [ -n "$actual" ]; then
        echo "  PASS: $description"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  FAIL: $description (value is empty)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

assert_empty() {
    local actual="$1"
    local description="$2"

    if [ -z "$actual" ]; then
        echo "  PASS: $description"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  FAIL: $description (expected empty, got '$actual')"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# ============================================================
# Test Group 1: CSQ-to-RSSI conversion formula
# Formula: rssi = csq * 2 - 113
# Valid CSQ range: 0-31 (99 means unknown/undetectable)
# ============================================================
echo "=== Test Group 1: CSQ-to-RSSI Conversion ==="

# Simulate the conversion logic from fibocom.sh
csq_to_rssi() {
    local csq="$1"
    if [ -n "$csq" ] && [ "$csq" != "99" ]; then
        echo $((csq * 2 - 113))
    else
        echo ""
    fi
}

# CSQ=0 → RSSI=-113 dBm (minimum signal)
assert_eq "-113" "$(csq_to_rssi 0)" "CSQ 0 → RSSI -113 dBm"

# CSQ=15 → RSSI=-83 dBm (moderate signal)
assert_eq "-83" "$(csq_to_rssi 15)" "CSQ 15 → RSSI -83 dBm"

# CSQ=31 → RSSI=-51 dBm (maximum signal)
assert_eq "-51" "$(csq_to_rssi 31)" "CSQ 31 → RSSI -51 dBm"

# CSQ=10 → RSSI=-93 dBm
assert_eq "-93" "$(csq_to_rssi 10)" "CSQ 10 → RSSI -93 dBm"

# CSQ=20 → RSSI=-73 dBm
assert_eq "-73" "$(csq_to_rssi 20)" "CSQ 20 → RSSI -73 dBm"

# CSQ=99 → unknown (should return empty)
assert_empty "$(csq_to_rssi 99)" "CSQ 99 (unknown) → empty result"

# Empty CSQ → empty result
assert_empty "$(csq_to_rssi "")" "Empty CSQ → empty result"

echo ""

# ============================================================
# Test Group 2: AT+XCESQ? response parsing
# Response format: +XCESQ: <rsrp>,<rsrq>,<sinr>
# Parsing: strip "+XCESQ: " prefix, split by comma
# ============================================================
echo "=== Test Group 2: XCESQ Response Parsing ==="

# Simulate XCESQ parsing logic from fibocom.sh
parse_xcesq() {
    local response="$1"
    # Mimic: grep "+XCESQ:" | sed 's/+XCESQ: //g' | sed 's/\r//g'
    local cleaned=$(echo "$response" | grep "+XCESQ:" | sed 's/+XCESQ: //g' | sed 's/\r//g')
    if [ -n "$cleaned" ]; then
        local rsrp=$(echo "$cleaned" | awk -F',' '{print $1}')
        local rsrq=$(echo "$cleaned" | awk -F',' '{print $2}')
        local sinr=$(echo "$cleaned" | awk -F',' '{print $3}')
        echo "rsrp=$rsrp rsrq=$rsrq sinr=$sinr"
    else
        echo ""
    fi
}

# Normal response with typical LTE values
result=$(parse_xcesq "+XCESQ: -95,-11,8")
assert_eq "rsrp=-95 rsrq=-11 sinr=8" "$result" "XCESQ normal response: RSRP=-95, RSRQ=-11, SINR=8"

# Strong signal values
result=$(parse_xcesq "+XCESQ: -75,-5,20")
assert_eq "rsrp=-75 rsrq=-5 sinr=20" "$result" "XCESQ strong signal: RSRP=-75, RSRQ=-5, SINR=20"

# Weak signal values
result=$(parse_xcesq "+XCESQ: -120,-18,-3")
assert_eq "rsrp=-120 rsrq=-18 sinr=-3" "$result" "XCESQ weak signal: RSRP=-120, RSRQ=-18, SINR=-3"

# Error response (no +XCESQ: prefix) → empty
result=$(parse_xcesq "ERROR")
assert_empty "$result" "XCESQ error response → empty (triggers CSQ fallback)"

# Empty response → empty
result=$(parse_xcesq "")
assert_empty "$result" "XCESQ empty response → empty (triggers CSQ fallback)"

echo ""

# ============================================================
# Test Group 3: AT+XCCINFO? response parsing (band extraction)
# Response format: +XCCINFO: <field1>,<field2>,<field3>,<band>,...
# Band is the 4th comma-separated field
# ============================================================
echo "=== Test Group 3: XCCINFO Response Parsing (Band) ==="

# Simulate XCCINFO parsing logic from fibocom.sh
parse_xccinfo_band() {
    local response="$1"
    # Mimic: grep "+XCCINFO:" | sed 's/+XCCINFO: //g' | sed 's/\r//g'
    local cleaned=$(echo "$response" | grep "+XCCINFO:" | sed 's/+XCCINFO: //g' | sed 's/\r//g')
    if [ -n "$cleaned" ]; then
        local band=$(echo "$cleaned" | awk -F',' '{print $4}')
        echo "$band"
    else
        echo ""
    fi
}

# Band 3 (common LTE band)
result=$(parse_xccinfo_band "+XCCINFO: 1,234,5,3,100")
assert_eq "3" "$result" "XCCINFO band 3 extracted from 4th field"

# Band 7
result=$(parse_xccinfo_band "+XCCINFO: 0,456,2,7,200")
assert_eq "7" "$result" "XCCINFO band 7 extracted from 4th field"

# Band 20
result=$(parse_xccinfo_band "+XCCINFO: 2,789,1,20,50")
assert_eq "20" "$result" "XCCINFO band 20 extracted from 4th field"

# Band 1
result=$(parse_xccinfo_band "+XCCINFO: 0,100,3,1,300")
assert_eq "1" "$result" "XCCINFO band 1 extracted from 4th field"

# Band 41 (TDD)
result=$(parse_xccinfo_band "+XCCINFO: 1,500,0,41,150")
assert_eq "41" "$result" "XCCINFO band 41 (TDD) extracted from 4th field"

# Error response → empty
result=$(parse_xccinfo_band "ERROR")
assert_empty "$result" "XCCINFO error response → empty"

# Empty response → empty
result=$(parse_xccinfo_band "")
assert_empty "$result" "XCCINFO empty response → empty"

echo ""

# ============================================================
# Test Group 4: Signal info fallback chain logic
# Primary: AT+XCESQ? → parse RSRP, RSRQ, SINR
# Fallback: If XCESQ fails → AT+CSQ → calculate RSSI
# ============================================================
echo "=== Test Group 4: Signal Info Fallback Chain ==="

# Simulate the fallback decision logic from fibocom.sh network_info()
get_signal_info() {
    local xcesq_response="$1"
    local csq_response="$2"

    # Try XCESQ first
    local cleaned=$(echo "$xcesq_response" | grep "+XCESQ:" | sed 's/+XCESQ: //g' | sed 's/\r//g')
    if [ -n "$cleaned" ]; then
        local rsrp=$(echo "$cleaned" | awk -F',' '{print $1}')
        local rsrq=$(echo "$cleaned" | awk -F',' '{print $2}')
        local sinr=$(echo "$cleaned" | awk -F',' '{print $3}')
        echo "xcesq:rsrp=$rsrp,rsrq=$rsrq,sinr=$sinr"
    else
        # Fallback to CSQ
        local csq_cleaned=$(echo "$csq_response" | grep "+CSQ:" | sed 's/+CSQ: //g' | sed 's/\r//g')
        if [ -n "$csq_cleaned" ]; then
            local csq=$(echo "$csq_cleaned" | awk -F',' '{print $1}')
            if [ -n "$csq" ] && [ "$csq" != "99" ]; then
                local rssi=$((csq * 2 - 113))
                echo "csq:rssi=$rssi"
            else
                echo "none"
            fi
        else
            echo "none"
        fi
    fi
}

# XCESQ succeeds → use XCESQ values (no fallback needed)
result=$(get_signal_info "+XCESQ: -95,-11,8" "+CSQ: 15,99")
assert_eq "xcesq:rsrp=-95,rsrq=-11,sinr=8" "$result" "XCESQ success → uses XCESQ values"

# XCESQ fails, CSQ succeeds → fallback to CSQ
result=$(get_signal_info "ERROR" "+CSQ: 20,99")
assert_eq "csq:rssi=-73" "$result" "XCESQ error + CSQ success → fallback to CSQ RSSI"

# XCESQ empty, CSQ succeeds → fallback to CSQ
result=$(get_signal_info "" "+CSQ: 10,99")
assert_eq "csq:rssi=-93" "$result" "XCESQ empty + CSQ success → fallback to CSQ RSSI"

# Both fail → no signal info
result=$(get_signal_info "ERROR" "ERROR")
assert_eq "none" "$result" "Both XCESQ and CSQ fail → no signal info"

# XCESQ fails, CSQ=99 (unknown) → no signal info
result=$(get_signal_info "" "+CSQ: 99,99")
assert_eq "none" "$result" "XCESQ empty + CSQ=99 → no signal info"

echo ""

# ============================================================
# Test Group 5: CA info fallback chain
# Primary: AT+XLEC? → parse CA info
# Fallback: If XLEC fails → AT+GTCAINFO?
# If both fail → CA unavailable
# ============================================================
echo "=== Test Group 5: CA Info Fallback Chain ==="

# Simulate the CA fallback logic from fibocom.sh network_info()
get_ca_info() {
    local xlec_response="$1"
    local gtcainfo_response="$2"

    # Try XLEC first
    local response=$(echo "$xlec_response" | grep "+XLEC:" | sed 's/+XLEC: //g' | sed 's/\r//g')
    if [ -z "$response" ]; then
        # Fallback to GTCAINFO
        response=$(echo "$gtcainfo_response" | grep "+GTCAINFO:" | sed 's/+GTCAINFO: //g' | sed 's/\r//g')
    fi

    if [ -n "$response" ]; then
        echo "ca:$response"
    else
        echo "unavailable"
    fi
}

# XLEC succeeds → use XLEC data
result=$(get_ca_info "+XLEC: 3,7,20" "")
assert_eq "ca:3,7,20" "$result" "XLEC success → uses XLEC CA data"

# XLEC fails, GTCAINFO succeeds → fallback
result=$(get_ca_info "ERROR" "+GTCAINFO: 1,3")
assert_eq "ca:1,3" "$result" "XLEC error + GTCAINFO success → fallback to GTCAINFO"

# XLEC empty, GTCAINFO succeeds → fallback
result=$(get_ca_info "" "+GTCAINFO: 7,20")
assert_eq "ca:7,20" "$result" "XLEC empty + GTCAINFO success → fallback to GTCAINFO"

# Both fail → CA unavailable
result=$(get_ca_info "ERROR" "ERROR")
assert_eq "unavailable" "$result" "Both XLEC and GTCAINFO fail → CA unavailable"

# Both empty → CA unavailable
result=$(get_ca_info "" "")
assert_eq "unavailable" "$result" "Both XLEC and GTCAINFO empty → CA unavailable"

# XLEC succeeds with data, GTCAINFO ignored
result=$(get_ca_info "+XLEC: 1,3,7" "+GTCAINFO: 20,28")
assert_eq "ca:1,3,7" "$result" "XLEC success → GTCAINFO not consulted"

echo ""

# ============================================================
# Summary
# ============================================================
echo "========================================"
echo "Test Results: $PASS_COUNT passed, $FAIL_COUNT failed"
echo "========================================"

if [ $FAIL_COUNT -eq 0 ]; then
    echo "ALL TESTS PASSED"
    exit 0
else
    echo "SOME TESTS FAILED"
    exit 1
fi
