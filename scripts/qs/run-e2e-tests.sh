#!/bin/bash
#
# QS-VPS: E2E-Test-Runner für DevSystem Quality Server
#
# Zweck:
#   Führt End-to-End-Tests gegen den QS-VPS aus
#   Validiert alle Komponenten und Log-Ausgaben
#   Nutzt SSH für Remote-Execution
#
# Voraussetzungen:
#   - SSH-Zugriff zum QS-VPS konfiguriert
#   - Tailscale VPN aktiv
#
# Parameter:
#   --host=IP         VPS IP/Hostname (Standard: aus Environment)
#   --user=NAME       SSH-User (Standard: root)
#   --ssh-key=PATH    SSH-Key Pfad (Standard: ~/.ssh/id_rsa)
#   --skip-deploy     Deployment überspringen, nur Tests
#
# Verwendung:
#   bash run-e2e-tests.sh --host=100.100.221.56 --user=root
#

set -euo pipefail

# ============================================================================
# IDEMPOTENZ-LIBRARY LADEN
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/idempotency.sh"

# ============================================================================
# KONFIGURATION
# ============================================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m'

readonly TEST_LOG_FILE="./e2e-test-results-$(date +%Y%m%d_%H%M%S).log"
readonly TEST_REPORT_FILE="./e2e-test-report-$(date +%Y%m%d_%H%M%S).md"

# Defaults
VPS_HOST="${VPS_HOST:-}"
SSH_USER="${SSH_USER:-root}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"
SKIP_DEPLOY=false

# Test-Zähler
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNING=0

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log_test() {
    local status=$1
    local test_name=$2
    local message=${3:-""}
    local color=$NC
    
    case $status in
        "PASS") 
            color=$GREEN
            ((TESTS_PASSED++))
            echo -e "${color}✓ PASS:${NC} $test_name" | tee -a "$TEST_LOG_FILE"
            ;;
        "FAIL") 
            color=$RED
            ((TESTS_FAILED++))
            echo -e "${color}✗ FAIL:${NC} $test_name" | tee -a "$TEST_LOG_FILE"
            ;;
        "WARN") 
            color=$YELLOW
            ((TESTS_WARNING++))
            echo -e "${color}⚠ WARN:${NC} $test_name" | tee -a "$TEST_LOG_FILE"
            ;;
    esac
    
    if [ -n "$message" ]; then
        echo "    → $message" | tee -a "$TEST_LOG_FILE"
    fi
}

log_section() {
    echo "" | tee -a "$TEST_LOG_FILE"
    echo "============================================================================" | tee -a "$TEST_LOG_FILE"
    echo -e "${CYAN}$1${NC}" | tee -a "$TEST_LOG_FILE"
    echo "============================================================================" | tee -a "$TEST_LOG_FILE"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --host=*)
                VPS_HOST="${1#*=}"
                shift
                ;;
            --user=*)
                SSH_USER="${1#*=}"
                shift
                ;;
            --ssh-key=*)
                SSH_KEY="${1#*=}"
                shift
                ;;
            --skip-deploy)
                SKIP_DEPLOY=true
                shift
                ;;
            --help)
                echo "Verwendung: bash run-e2e-tests.sh [--host=IP] [--user=USER] [--ssh-key=PATH] [--skip-deploy]"
                exit 0
                ;;
            *)
                echo "Unbekannter Parameter: $1"
                exit 1
                ;;
        esac
    done
    
    if [ -z "$VPS_HOST" ]; then
        echo -e "${RED}Fehler: --host=IP Parameter wird benötigt!${NC}"
        exit 1
    fi
}

# SSH-Wrapper
ssh_exec() {
    local command=$1
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER@$VPS_HOST" "$command" 2>&1
}

# ============================================================================
# E2E TEST FUNCTIONS
# ============================================================================

test_ssh_connection() {
    log_section "E2E-Test 1: SSH-Verbindung"
    
    if ssh_exec "echo 'SSH OK'" | grep -q "SSH OK"; then
        log_test "PASS" "SSH-Verbindung" "Erfolgreich zu $VPS_HOST verbunden"
    else
        log_test "FAIL" "SSH-Verbindung" "Konnte nicht zu $VPS_HOST verbinden"
        exit 1
    fi
}

test_idempotency_framework() {
    log_section "E2E-Test 2: Idempotenz-Framework"
    
    # Prüfe ob Library existiert
    if ssh_exec "[ -f /root/work/DevSystem/scripts/qs/lib/idempotency.sh ] && echo 'EXISTS'" | grep -q "EXISTS"; then
        log_test "PASS" "Idempotenz-Library" "Library existiert auf VPS"
    else
        log_test "FAIL" "Idempotenz-Library" "Library nicht gefunden"
        return
    fi
    
    # Prüfe Marker-Directory
    if ssh_exec "[ -d /var/lib/qs-deployment/markers ] && echo 'EXISTS'" | grep -q "EXISTS"; then
        local marker_count=$(ssh_exec "ls /var/lib/qs-deployment/markers/*.complete 2>/dev/null | wc -l" || echo "0")
        log_test "PASS" "Marker-Directory" "$marker_count Marker gefunden"
    else
        log_test "WARN" "Marker-Directory" "Noch keine Marker vorhanden"
    fi
}

test_caddy_service() {
    log_section "E2E-Test 3: Caddy Service"
    
    # Service läuft?
    if ssh_exec "systemctl is-active caddy" | grep -q "active"; then
        log_test "PASS" "Caddy Service" "Service ist aktiv"
    else
        log_test "FAIL" "Caddy Service" "Service läuft nicht"
        ssh_exec "systemctl status caddy --no-pager -l" | head -20 | tee -a "$TEST_LOG_FILE"
        return
    fi
    
    # Port 9443 lauscht?
    if ssh_exec "ss -tlnp | grep :9443" &>/dev/null; then
        log_test "PASS" "Caddy Port 9443" "Caddy lauscht auf Port 9443"
    else
        log_test "FAIL" "Caddy Port 9443" "Port nicht aktiv"
    fi
    
    # Config valid?
    if ssh_exec "caddy validate --config /etc/caddy/Caddyfile" &>/dev/null; then
        log_test "PASS" "Caddy Config" "Caddyfile ist gültig"
    else
        log_test "FAIL" "Caddy Config" "Caddyfile enthält Fehler"
    fi
}

test_code_server_service() {
    log_section "E2E-Test 4: code-server Service"
    
    # Service läuft?
    if ssh_exec "systemctl is-active code-server-qs" | grep -q "active"; then
        log_test "PASS" "code-server Service" "Service ist aktiv"
    else
        log_test "WARN" "code-server Service" "Service läuft nicht"
        return
    fi
    
    # Port 8080 lauscht?
    if ssh_exec "ss -tlnp | grep :8080" &>/dev/null; then
        log_test "PASS" "code-server Port 8080" "code-server lauscht auf Port 8080"
    else
        log_test "WARN" "code-server Port 8080" "Port nicht aktiv"
    fi
}

test_qdrant_service() {
    log_section "E2E-Test 5: Qdrant Service"
    
    # Service läuft?
    if ssh_exec "systemctl is-active qdrant-qs" | grep -q "active"; then
        log_test "PASS" "Qdrant Service" "Service ist aktiv"
    else
        log_test "WARN" "Qdrant Service" "Service läuft nicht (optional)"
        return
    fi
    
    # API erreichbar?
    if ssh_exec "curl -s http://localhost:6333/health" | grep -q "status"; then
        log_test "PASS" "Qdrant API" "API antwortet auf Health-Check"
    else
        log_test "WARN" "Qdrant API" "API antwortet nicht"
    fi
}

test_log_validation() {
    log_section "E2E-Test 6: Log-Validierung"
    
    # QS-Deployment-Log existiert?
    if ssh_exec "[ -f /var/log/qs-deployment.log ] && echo 'EXISTS'" | grep -q "EXISTS"; then
        local log_size=$(ssh_exec "wc -l /var/log/qs-deployment.log" | awk '{print $1}')
        log_test "PASS" "QS-Deployment-Log" "$log_size Zeilen"
    else
        log_test "WARN" "QS-Deployment-Log" "Log nicht gefunden"
    fi
    
    # Systemd Journals prüfen
    local journal_errors=$(ssh_exec "journalctl --since '1 hour ago' -p err --no-pager | wc -l")
    if [ "$journal_errors" -lt 10 ]; then
        log_test "PASS" "System-Errors" "Nur $journal_errors Fehler in der letzten Stunde"
    else
        log_test "WARN" "System-Errors" "$journal_errors Fehler gefunden"
    fi
}

test_marker_status() {
    log_section "E2E-Test 7: Idempotenz-Marker-Status"
    
    local markers=$(ssh_exec "find /var/lib/qs-deployment/markers -name '*.complete' 2>/dev/null | wc -l" || echo "0")
    
    if [ "$markers" -gt 5 ]; then
        log_test "PASS" "Deployment-Marker" "$markers Marker gesetzt"
        
        echo "" | tee -a "$TEST_LOG_FILE"
        echo "Aktive Marker:" | tee -a "$TEST_LOG_FILE"
        ssh_exec "ls /var/lib/qs-deployment/markers/*.complete 2>/dev/null | xargs -n1 basename | sed 's/.complete//'" | head -10 | tee -a "$TEST_LOG_FILE"
    else
        log_test "WARN" "Deployment-Marker" "Nur $markers Marker gefunden"
    fi
}

generate_test_report() {
    log_section "Generiere Test-Report"
    
    cat > "$TEST_REPORT_FILE" << EOF
# QS-VPS E2E-Test-Report

**Datum:** $(date -Iseconds)
**VPS Host:** $VPS_HOST
**SSH User:** $SSH_USER

## Test-Zusammenfassung

- ✅ **Bestanden:** $TESTS_PASSED
- ❌ **Fehlgeschlagen:** $TESTS_FAILED
- ⚠️ **Warnungen:** $TESTS_WARNING
- **Gesamt:** $((TESTS_PASSED + TESTS_FAILED + TESTS_WARNING))

## Test-Ergebnis

EOF

    if [ $TESTS_FAILED -eq 0 ]; then
        echo "✅ **ALLE TESTS BESTANDEN!**" >> "$TEST_REPORT_FILE"
        echo "" >> "$TEST_REPORT_FILE"
        echo "Das QS-VPS-Deployment ist funktionsfähig." >> "$TEST_REPORT_FILE"
    else
        echo "❌ **TESTS FEHLGESCHLAGEN!**" >> "$TEST_REPORT_FILE"
        echo "" >> "$TEST_REPORT_FILE"
        echo "Es gab $TESTS_FAILED fehlgeschlagene Tests. Bitte Log prüfen: $TEST_LOG_FILE" >> "$TEST_REPORT_FILE"
    fi
    
    echo "" >> "$TEST_REPORT_FILE"
    echo "## Detaillierte Logs" >> "$TEST_REPORT_FILE"
    echo "" >> "$TEST_REPORT_FILE"
    echo "Vollständige Logs: \`$TEST_LOG_FILE\`" >> "$TEST_REPORT_FILE"
    
    echo -e "${GREEN}Test-Report erstellt: $TEST_REPORT_FILE${NC}"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo ""
    echo "============================================================================"
    echo -e "${MAGENTA}QS-VPS E2E-Test-Runner${NC}"
    echo "============================================================================"
    echo ""
    
    parse_args "$@"
    
    echo "Konfiguration:" | tee -a "$TEST_LOG_FILE"
    echo "  - VPS Host: $VPS_HOST" | tee -a "$TEST_LOG_FILE"
    echo "  - SSH User: $SSH_USER" | tee -a "$TEST_LOG_FILE"
    echo "  - SSH Key:  $SSH_KEY" | tee -a "$TEST_LOG_FILE"
    echo "  - Log File: $TEST_LOG_FILE" | tee -a "$TEST_LOG_FILE"
    echo "" | tee -a "$TEST_LOG_FILE"
    
    # Tests ausführen
    test_ssh_connection
    test_idempotency_framework
    test_caddy_service
    test_code_server_service
    test_qdrant_service
    test_log_validation
    test_marker_status
    
    # Report generieren
    generate_test_report
    
    # Zusammenfassung
    echo "" | tee -a "$TEST_LOG_FILE"
    log_section "Test-Zusammenfassung"
    echo -e "${GREEN}Tests bestanden:      $TESTS_PASSED${NC}" | tee -a "$TEST_LOG_FILE"
    echo -e "${RED}Tests fehlgeschlagen: $TESTS_FAILED${NC}" | tee -a "$TEST_LOG_FILE"
    echo -e "${YELLOW}Warnungen:            $TESTS_WARNING${NC}" | tee -a "$TEST_LOG_FILE"
    echo "" | tee -a "$TEST_LOG_FILE"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✅ ALLE E2E-TESTS BESTANDEN!${NC}" | tee -a "$TEST_LOG_FILE"
        exit 0
    else
        echo -e "${RED}❌ EINIGE E2E-TESTS FEHLGESCHLAGEN!${NC}" | tee -a "$TEST_LOG_FILE"
        exit 1
    fi
}

main "$@"
