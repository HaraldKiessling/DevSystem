#!/bin/bash
#
# Test-Script für Idempotency-Library
#
# Zweck:
#   Validiert alle Funktionen der Idempotency-Library
#
# Verwendung:
#   sudo bash scripts/qs/test-idempotency-lib.sh
#

set -eu

# Farben
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Test-Zähler
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================================
# TEST-FUNKTIONEN
# ============================================================================

test_result() {
    local test_name=$1
    local result=$2
    
    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}✅ PASS:${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL:${NC} $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# ============================================================================
# MAIN TESTS
# ============================================================================

main() {
    echo ""
    echo "============================================================================"
    echo "  Idempotency Library - Test Suite"
    echo "============================================================================"
    echo ""
    
    # Library laden
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${SCRIPT_DIR}/lib/idempotency.sh"
    
    echo -e "${BLUE}Test 1: Library Loaded${NC}"
    if declare -F marker_exists > /dev/null; then
        test_result "Library loaded successfully" "PASS"
    else
        test_result "Library failed to load" "FAIL"
        exit 1
    fi
    echo ""
    
    # Test 2: Marker-Funktionen
    echo -e "${BLUE}Test 2: Marker Functions${NC}"
    
    # Cleanup alte Test-Marker
    clear_marker "test-marker-1" 2>/dev/null || true
    
    # Set Marker
    if set_marker "test-marker-1" "Test Metadata"; then
        test_result "set_marker creates marker" "PASS"
    else
        test_result "set_marker failed" "FAIL"
    fi
    
    # Marker existiert
    if marker_exists "test-marker-1"; then
        test_result "marker_exists detects marker" "PASS"
    else
        test_result "marker_exists failed" "FAIL"
    fi
    
    # Marker-Datei enthält Metadaten
    if grep -q "Test Metadata" "/var/lib/qs-deployment/markers/test-marker-1.complete" 2>/dev/null; then
        test_result "marker contains metadata" "PASS"
    else
        test_result "marker metadata missing" "FAIL"
    fi
    
    # Clear Marker
    if clear_marker "test-marker-1"; then
        test_result "clear_marker removes marker" "PASS"
    else
        test_result "clear_marker failed" "FAIL"
    fi
    
    # Marker existiert nicht mehr
    if ! marker_exists "test-marker-1"; then
        test_result "marker_exists confirms removal" "PASS"
    else
        test_result "marker still exists after clear" "FAIL"
    fi
    echo ""
    
    # Test 3: State-Management
    echo -e "${BLUE}Test 3: State Management${NC}"
    
    # Save State
    if save_state "test-component" "test-key" "test-value"; then
        test_result "save_state stores value" "PASS"
    else
        test_result "save_state failed" "FAIL"
    fi
    
    # Get State
    local retrieved_value=$(get_state "test-component" "test-key")
    if [ "$retrieved_value" = "test-value" ]; then
        test_result "get_state retrieves correct value" "PASS"
    else
        test_result "get_state returned wrong value: '$retrieved_value'" "FAIL"
    fi
    
    # Update State
    save_state "test-component" "test-key" "updated-value"
    local updated_value=$(get_state "test-component" "test-key")
    if [ "$updated_value" = "updated-value" ]; then
        test_result "save_state updates existing value" "PASS"
    else
        test_result "save_state update failed" "FAIL"
    fi
    
    # Clear State
    if clear_state "test-component"; then
        test_result "clear_state removes component state" "PASS"
    else
        test_result "clear_state failed" "FAIL"
    fi
    echo ""
    
    # Test 4: run_idempotent
    echo -e "${BLUE}Test 4: Idempotent Execution${NC}"
    
    # Cleanup
    clear_marker "test-idempotent" 2>/dev/null || true
    
    # Erster Durchlauf (sollte ausführen)
    local test_file="/tmp/idempotency-test-$$"
    rm -f "$test_file"
    
    if run_idempotent "test-idempotent" "Test Command" touch "$test_file"; then
        test_result "run_idempotent executes command" "PASS"
    else
        test_result "run_idempotent execution failed" "FAIL"
    fi
    
    if [ -f "$test_file" ]; then
        test_result "run_idempotent command created file" "PASS"
    else
        test_result "run_idempotent command did not create file" "FAIL"
    fi
    
    # Zweiter Durchlauf (sollte überspringen)
    rm -f "$test_file"
    
    # Logik: Falls überspringen, wird touch nicht ausgeführt, Datei existiert nicht
    run_idempotent "test-idempotent" "Test Command" touch "$test_file" > /dev/null 2>&1
    
    if [ ! -f "$test_file" ]; then
        test_result "run_idempotent skips on second run" "PASS"
    else
        test_result "run_idempotent did not skip (file exists)" "FAIL"
    fi
    
    # Cleanup
    rm -f "$test_file"
    clear_marker "test-idempotent"
    echo ""
    
    # Test 5: Lock-Funktionen
    echo -e "${BLUE}Test 5: Lock Functions${NC}"
    
    # Cleanup alter Lock
    release_lock "test-lock" 2>/dev/null || true
    
    # Acquire Lock
    if acquire_lock "test-lock"; then
        test_result "acquire_lock creates lock" "PASS"
    else
        test_result "acquire_lock failed" "FAIL"
    fi
    
    # Lock existiert
    if [ -f "/var/lock/qs-deployment/test-lock.lock" ]; then
        test_result "lock file exists" "PASS"
    else
        test_result "lock file missing" "FAIL"
    fi
    
    # Zweiter acquire sollte fehlschlagen
    if ! acquire_lock "test-lock" 2>/dev/null; then
        test_result "acquire_lock prevents double-lock" "PASS"
    else
        test_result "acquire_lock allowed double-lock" "FAIL"
    fi
    
    # Release Lock
    if release_lock "test-lock"; then
        test_result "release_lock removes lock" "PASS"
    else
        test_result "release_lock failed" "FAIL"
    fi
    
    # Lock existiert nicht mehr
    if [ ! -f "/var/lock/qs-deployment/test-lock.lock" ]; then
        test_result "lock file removed" "PASS"
    else
        test_result "lock file still exists" "FAIL"
    fi
    echo ""
    
    # Test 6: Hilfsfunktionen
    echo -e "${BLUE}Test 6: Helper Functions${NC}"
    
    # file_checksum
    echo "test content" > "/tmp/checksum-test-$$"
    local checksum=$(file_checksum "/tmp/checksum-test-$$")
    if [ -n "$checksum" ] && [ "$checksum" != "none" ]; then
        test_result "file_checksum generates checksum" "PASS"
    else
        test_result "file_checksum failed" "FAIL"
    fi
    
    # backup_file
    local backup_path=$(backup_file "/tmp/checksum-test-$$")
    if [ -f "$backup_path" ]; then
        test_result "backup_file creates backup" "PASS"
    else
        test_result "backup_file failed" "FAIL"
    fi
    
    # Cleanup
    rm -f "/tmp/checksum-test-$$"
    echo ""
    
    # Test 7: FORCE_REDEPLOY
    echo -e "${BLUE}Test 7: FORCE_REDEPLOY Override${NC}"
    
    # Marker setzen
    set_marker "test-force" "Test"
    
    # Normal: sollte überspringen
    local test_file="/tmp/force-test-$$"
    rm -f "$test_file"
    run_idempotent "test-force" "Force Test" touch "$test_file" > /dev/null 2>&1
    
    if [ ! -f "$test_file" ]; then
        test_result "run_idempotent skips with existing marker" "PASS"
    else
        test_result "run_idempotent did not skip" "FAIL"
        rm -f "$test_file"
    fi
    
    # Mit FORCE_REDEPLOY: sollte ausführen
    export FORCE_REDEPLOY=true
    run_idempotent "test-force" "Force Test" touch "$test_file" > /dev/null 2>&1
    
    if [ -f "$test_file" ]; then
        test_result "FORCE_REDEPLOY overrides marker" "PASS"
    else
        test_result "FORCE_REDEPLOY did not override" "FAIL"
    fi
    
    # Cleanup
    rm -f "$test_file"
    unset FORCE_REDEPLOY
    clear_marker "test-force"
    echo ""
    
    # Zusammenfassung
    echo "============================================================================"
    echo "  Test Summary"
    echo "============================================================================"
    echo ""
    echo -e "Tests Passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Tests Failed: ${RED}${TESTS_FAILED}${NC}"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}❌ Some tests failed!${NC}"
        echo ""
        return 1
    fi
}

# Root-Check
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}❌ This script must be run as root${NC}"
    exit 1
fi

# Run Tests
main
