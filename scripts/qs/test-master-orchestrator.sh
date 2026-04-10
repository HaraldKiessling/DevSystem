#!/usr/bin/env bash
#
# Test-Suite für QS Master-Orchestrator
# Testet alle Funktionen von setup-qs-master.sh
#
# Verwendung:
#   bash scripts/qs/test-master-orchestrator.sh [--host=IP] [--user=USER]
#
# Optionen:
#   --host=IP        Remote-Test gegen VPS (SSH)
#   --user=USER      SSH-User (default: root)
#   --skip-remote    Nur lokale Tests
#

set -euo pipefail

# ============================================================================
# KONFIGURATION
# ============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly MASTER_SCRIPT="${SCRIPT_DIR}/setup-qs-master.sh"
readonly TEST_LOG="/tmp/test-master-orchestrator-$$.log"

# Farben
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly RESET='\033[0m'

# Test-Zähler
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Remote-Test-Parameter
REMOTE_HOST=""
REMOTE_USER="root"
SKIP_REMOTE=false

# ============================================================================
# HELPER-FUNKTIONEN
# ============================================================================

log() {
    local level=$1
    shift
    local message="$*"
    local color=$RESET
    
    case $level in
        PASS) color=$GREEN; symbol="✅" ;;
        FAIL) color=$RED; symbol="❌" ;;
        WARN) color=$YELLOW; symbol="⚠️ " ;;
        INFO) color=$BLUE; symbol="ℹ️ " ;;
        TEST) color=$CYAN; symbol="🧪" ;;
        *) symbol="  " ;;
    esac
    
    echo -e "${color}[$(date '+%H:%M:%S')] ${symbol} ${message}${RESET}"
}

start_test() {
    local test_name=$1
    ((TESTS_RUN++))
    log "TEST" "Test ${TESTS_RUN}: $test_name"
}

pass_test() {
    ((TESTS_PASSED++))
    log "PASS" "Test bestanden"
    echo ""
}

fail_test() {
    local reason=$1
    ((TESTS_FAILED++))
    log "FAIL" "Test fehlgeschlagen: $reason"
    echo ""
}

# ============================================================================
# TEST 1: Script existiert und ist ausführbar
# ============================================================================

test_script_exists() {
    start_test "Script-Existenz und Rechte"
    
    if [ ! -f "$MASTER_SCRIPT" ]; then
        fail_test "Script nicht gefunden: $MASTER_SCRIPT"
        return 1
    fi
    
    if [ ! -x "$MASTER_SCRIPT" ]; then
        fail_test "Script ist nicht ausführbar"
        return 1
    fi
    
    pass_test
    return 0
}

# ============================================================================
# TEST 2: Help-Flag funktioniert
# ============================================================================

test_help_flag() {
    start_test "Help-Flag (--help)"
    
    if bash "$MASTER_SCRIPT" --help 2>&1 | grep -q "QS-VPS Master Orchestrator"; then
        pass_test
        return 0
    else
        fail_test "Help-Output fehlt oder ist unvollständig"
        return 1
    fi
}

# ============================================================================
# TEST 3: Dry-Run-Modus
# ============================================================================

test_dry_run() {
    start_test "Dry-Run-Modus (--dry-run)"
    
    # Dry-Run sollte ohne Root-Rechte möglich sein (validation wird übersprungen)
    if bash "$MASTER_SCRIPT" --dry-run --skip-checks 2>&1 | grep -q "DRY-RUN"; then
        pass_test
        return 0
    else
        fail_test "Dry-Run-Modus funktioniert nicht"
        return 1
    fi
}

# ============================================================================
# TEST 4: Lock-Mechanismus
# ============================================================================

test_lock_mechanism() {
    start_test "Lock-Mechanismus (parallele Ausführung verhindern)"
    
    # Benötigt Root-Rechte - nur wenn vorhanden
    if [ "$(id -u)" -ne 0 ]; then
        log "WARN" "Test übersprungen (benötigt Root-Rechte)"
        return 0
    fi
    
    # Ersten Prozess im Hintergrund starten
    bash "$MASTER_SCRIPT" --dry-run --skip-checks &
    local pid1=$!
    sleep 2
    
    # Zweiten Prozess starten (sollte wegen Lock fehlschlagen)
    if bash "$MASTER_SCRIPT" --dry-run --skip-checks 2>&1 | grep -q "läuft bereits"; then
        kill $pid1 2>/dev/null || true
        wait $pid1 2>/dev/null || true
        pass_test
        return 0
    else
        kill $pid1 2>/dev/null || true
        wait $pid1 2>/dev/null || true
        fail_test "Lock-Mechanismus verhindert nicht parallele Ausführung"
        return 1
    fi
}

# ============================================================================
# TEST 5: Component-Filter
# ============================================================================

test_component_filter() {
    start_test "Component-Filter (--component=NAME)"
    
    if bash "$MASTER_SCRIPT" --dry-run --skip-checks --component=install-caddy 2>&1 | grep -q "Component-Filter"; then
        pass_test
        return 0
    else
        fail_test "Component-Filter funktioniert nicht"
        return 1
    fi
}

# ============================================================================
# TEST 6: Force-Mode
# ============================================================================

test_force_mode() {
    start_test "Force-Mode (--force)"
    
    if bash "$MASTER_SCRIPT" --force --dry-run --skip-checks 2>&1 | grep -q "Force-Mode"; then
        pass_test
        return 0
    else
        fail_test "Force-Mode wird nicht erkannt"
        return 1
    fi
}

# ============================================================================
# TEST 7: Environment-Validation
# ============================================================================

test_environment_validation() {
    start_test "Environment-Validation"
    
    # Ohne Root kann validation fehlschlagen, aber sollte laufen
    local output=$(bash "$MASTER_SCRIPT" --dry-run 2>&1 || true)
    
    if echo "$output" | grep -q "Environment-Validation"; then
        pass_test
        return 0
    else
        fail_test "Environment-Validation wird nicht ausgeführt"
        return 1
    fi
}

# ============================================================================
# TEST 8: Skip-Checks-Flag
# ============================================================================

test_skip_checks() {
    start_test "Skip-Checks-Flag (--skip-checks)"
    
    if bash "$MASTER_SCRIPT" --skip-checks --dry-run 2>&1 | grep -q "Environment-Checks werden übersprungen"; then
        pass_test
        return 0
    else
        fail_test "Skip-Checks-Flag funktioniert nicht"
        return 1
    fi
}

# ============================================================================
# TEST 9: Rollback-Mode
# ============================================================================

test_rollback_mode() {
    start_test "Rollback-Mode (--rollback)"
    
    # Benötigt Root-Rechte
    if [ "$(id -u)" -ne 0 ]; then
        log "WARN" "Test übersprungen (benötigt Root-Rechte)"
        return 0
    fi
    
    if bash "$MASTER_SCRIPT" --rollback 2>&1 | grep -q "ROLLBACK"; then
        pass_test
        return 0
    else
        fail_test "Rollback-Mode funktioniert nicht"
        return 1
    fi
}

# ============================================================================
# TEST 10: Resume-Mode
# ============================================================================

test_resume_mode() {
    start_test "Resume-Mode (--resume)"
    
    if bash "$MASTER_SCRIPT" --resume --dry-run --skip-checks 2>&1 | grep -q "RESUME"; then
        pass_test
        return 0
    else
        fail_test "Resume-Mode funktioniert nicht"
        return 1
    fi
}

# ============================================================================
# TEST 11: Idempotenz-Library Integration
# ============================================================================

test_idempotency_library() {
    start_test "Idempotenz-Library Integration"
    
    # Script sollte Library laden
    if bash "$MASTER_SCRIPT" --dry-run --skip-checks 2>&1 | grep -q "Idempotency Library geladen"; then
        pass_test
        return 0
    else
        fail_test "Idempotenz-Library wird nicht geladen"
        return 1
    fi
}

# ============================================================================
# TEST 12: Component-Reihenfolge
# ============================================================================

test_component_order() {
    start_test "Component-Reihenfolge (Dependencies)"
    
    # Prüfe ob Components in korrekter Reihenfolge definiert sind
    local output=$(bash "$MASTER_SCRIPT" --help 2>&1)
    
    # Caddy sollte vor code-server kommen
    local caddy_line=$(echo "$output" | grep -n "install-caddy" | cut -d: -f1)
    local codeserver_line=$(echo "$output" | grep -n "install-code-server" | cut -d: -f1)
    
    if [ "$caddy_line" -lt "$codeserver_line" ]; then
        pass_test
        return 0
    else
        fail_test "Component-Reihenfolge falsch"
        return 1
    fi
}

# ============================================================================
# TEST 13: Report-Generierung (Simulation)
# ============================================================================

test_report_generation() {
    start_test "Report-Generierung (Dry-Run)"
    
    # Benötigt Root-Rechte für Verzeichnisse
    if [ "$(id -u)" -ne 0 ]; then
        log "WARN" "Test übersprungen (benötigt Root-Rechte)"
        return 0
    fi
    
    # Dry-Run durchlaufen lassen
    bash "$MASTER_SCRIPT" --dry-run --skip-checks > /tmp/test-master-report.log 2>&1 || true
    
    # Prüfe ob Report-Funktionen aufgerufen werden
    if grep -q "DEPLOYMENT SUMMARY" /tmp/test-master-report.log; then
        rm -f /tmp/test-master-report.log
        pass_test
        return 0
    else
        rm -f /tmp/test-master-report.log
        fail_test "Report wird nicht generiert"
        return 1
    fi
}

# ============================================================================
# REMOTE-TEST: Vollständiges Deployment auf VPS
# ============================================================================

test_remote_full_deployment() {
    start_test "Remote: Vollständiges Deployment auf VPS"
    
    if [ -z "$REMOTE_HOST" ]; then
        log "WARN" "Test übersprungen (kein Remote-Host angegeben)"
        return 0
    fi
    
    log "INFO" "Deploye auf Remote-Host: $REMOTE_USER@$REMOTE_HOST"
    
    # Script auf VPS kopieren
    if ! scp -o ConnectTimeout=10 "$MASTER_SCRIPT" "$REMOTE_USER@$REMOTE_HOST:/tmp/" &>/dev/null; then
        fail_test "SSH-Verbindung fehlgeschlagen"
        return 1
    fi
    
    # Deployment ausführen
    local remote_output=$(ssh -o ConnectTimeout=10 "$REMOTE_USER@$REMOTE_HOST" \
        "bash /tmp/setup-qs-master.sh --dry-run --skip-checks" 2>&1)
    
    if echo "$remote_output" | grep -q "SUCCESS"; then
        pass_test
        return 0
    else
        fail_test "Remote-Deployment fehlgeschlagen"
        return 1
    fi
}

# ============================================================================
# REMOTE-TEST: Idempotenz auf VPS
# ============================================================================

test_remote_idempotency() {
    start_test "Remote: Idempotenz (2x ausführen)"
    
    if [ -z "$REMOTE_HOST" ]; then
        log "WARN" "Test übersprungen (kein Remote-Host angegeben)"
        return 0
    fi
    
    log "INFO" "Teste Idempotenz auf: $REMOTE_USER@$REMOTE_HOST"
    
    # Erstes Deployment (mit --force um sicherzustellen dass deployed wird)
    ssh -o ConnectTimeout=10 "$REMOTE_USER@$REMOTE_HOST" \
        "bash /tmp/setup-qs-master.sh --force --skip-checks" &>/dev/null || true
    
    # Zweites Deployment (sollte alles skippen)
    local second_run=$(ssh -o ConnectTimeout=10 "$REMOTE_USER@$REMOTE_HOST" \
        "bash /tmp/setup-qs-master.sh --skip-checks" 2>&1)
    
    if echo "$second_run" | grep -q "bereits deployed"; then
        pass_test
        return 0
    else
        fail_test "Idempotenz funktioniert nicht auf Remote-System"
        return 1
    fi
}

# ============================================================================
# REMOTE-TEST: Lock-Mechanismus auf VPS
# ============================================================================

test_remote_lock() {
    start_test "Remote: Lock-Mechanismus"
    
    if [ -z "$REMOTE_HOST" ]; then
        log "WARN" "Test übersprungen (kein Remote-Host angegeben)"
        return 0
    fi
    
    log "INFO" "Teste Lock auf: $REMOTE_USER@$REMOTE_HOST"
    
    # Erstes Deployment im Hintergrund starten
    ssh -o ConnectTimeout=10 "$REMOTE_USER@$REMOTE_HOST" \
        "bash /tmp/setup-qs-master.sh --dry-run --skip-checks" &>/dev/null &
    local ssh_pid=$!
    
    sleep 3
    
    # Zweites Deployment (sollte wegen Lock fehlschlagen)
    local second_attempt=$(ssh -o ConnectTimeout=10 "$REMOTE_USER@$REMOTE_HOST" \
        "bash /tmp/setup-qs-master.sh --dry-run --skip-checks" 2>&1 || true)
    
    kill $ssh_pid 2>/dev/null || true
    wait $ssh_pid 2>/dev/null || true
    
    if echo "$second_attempt" | grep -q "läuft bereits"; then
        pass_test
        return 0
    else
        fail_test "Lock funktioniert nicht auf Remote-System"
        return 1
    fi
}

# ============================================================================
# ARGUMENT-PARSING
# ============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --host=*)
                REMOTE_HOST="${1#*=}"
                shift
                ;;
            --user=*)
                REMOTE_USER="${1#*=}"
                shift
                ;;
            --skip-remote)
                SKIP_REMOTE=true
                shift
                ;;
            --help)
                cat << EOF
Test-Suite für QS Master-Orchestrator

Verwendung:
  bash $0 [OPTIONEN]

Optionen:
  --host=IP          Remote-Tests gegen VPS (SSH)
  --user=USER        SSH-User (default: root)
  --skip-remote      Nur lokale Tests
  --help             Diese Hilfe

Beispiele:
  # Nur lokale Tests
  bash $0

  # Mit Remote-Tests
  bash $0 --host=100.100.221.56 --user=root

EOF
                exit 0
                ;;
            *)
                echo "Unbekannte Option: $1"
                echo "Verwende --help für Hilfe"
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    # Banner
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║   Test-Suite: QS Master-Orchestrator                        ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    
    echo ""
    log "INFO" "Test-Start: $(date)"
    log "INFO" "Master-Script: $MASTER_SCRIPT"
    echo ""
    
    parse_arguments "$@"
    
    # ========================================================================
    # LOKALE TESTS
    # ========================================================================
    
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "INFO" "LOKALE TESTS"
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    test_script_exists
    test_help_flag
    test_dry_run
    test_lock_mechanism
    test_component_filter
    test_force_mode
    test_environment_validation
    test_skip_checks
    test_rollback_mode
    test_resume_mode
    test_idempotency_library
    test_component_order
    test_report_generation
    
    # ========================================================================
    # REMOTE TESTS (optional)
    # ========================================================================
    
    if [ "$SKIP_REMOTE" = false ] && [ -n "$REMOTE_HOST" ]; then
        echo ""
        log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log "INFO" "REMOTE TESTS (VPS: $REMOTE_HOST)"
        log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        test_remote_full_deployment
        test_remote_idempotency
        test_remote_lock
    fi
    
    # ========================================================================
    # ZUSAMMENFASSUNG
    # ========================================================================
    
    echo ""
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "INFO" "TEST-ZUSAMMENFASSUNG"
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    log "INFO" "Gesamt:      $TESTS_RUN Tests"
    log "PASS" "Bestanden:   $TESTS_PASSED"
    log "FAIL" "Fehlgeschlagen: $TESTS_FAILED"
    
    local success_rate=0
    if [ $TESTS_RUN -gt 0 ]; then
        success_rate=$((TESTS_PASSED * 100 / TESTS_RUN))
    fi
    
    echo ""
    log "INFO" "Erfolgsrate: ${success_rate}%"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log "PASS" "🎉 Alle Tests bestanden!"
        exit 0
    else
        log "FAIL" "Einige Tests fehlgeschlagen"
        exit 1
    fi
}

main "$@"
