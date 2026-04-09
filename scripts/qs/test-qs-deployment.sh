#!/bin/bash
#
# QS-VPS: Deployment-Test-Script für DevSystem Quality Server
#
# Zweck:
#   E2E-Tests für alle QS-VPS-Komponenten
#   - Tailscale
#   - Caddy
#   - code-server
#   - Qdrant
#   - Log-Validierung
#
# Voraussetzungen:
#   - Alle Komponenten müssen installiert und konfiguriert sein
#   - Root-Rechte
#
# Verwendung:
#   sudo bash test-qs-deployment.sh
#

set -euo pipefail

# ============================================================================
# KONFIGURATION UND KONSTANTEN
# ============================================================================

# Farbdefinitionen
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m'

# QS-spezifische Einstellungen
readonly QS_LOG_FILE="/var/log/qs-deployment.log"
readonly TEST_LOG_FILE="/var/log/qs-test-results.log"
readonly QS_MARKER="QS-VPS-TEST"

# Test-Zähler
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNING=0

# ============================================================================
# LOGGING-FUNKTIONEN
# ============================================================================

exec > >(tee -a "$TEST_LOG_FILE")
exec 2>&1

log_test() {
    local status=$1
    local test_name=$2
    local message=$3
    local color=$NC
    
    case $status in
        "PASS") 
            color=$GREEN
            ((TESTS_PASSED++))
            echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [${QS_MARKER}] ✓ PASS: ${test_name}${NC}"
            ;;
        "FAIL") 
            color=$RED
            ((TESTS_FAILED++))
            echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [${QS_MARKER}] ✗ FAIL: ${test_name}${NC}"
            ;;
        "WARN") 
            color=$YELLOW
            ((TESTS_WARNING++))
            echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [${QS_MARKER}] ⚠ WARN: ${test_name}${NC}"
            ;;
    esac
    
    if [ -n "$message" ]; then
        echo "    → $message"
    fi
}

log_section() {
    echo ""
    echo "============================================================================"
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
    echo "============================================================================"
}

# ============================================================================
# TEST-FUNKTIONEN
# ============================================================================

# Test 1: Root-Rechte
test_root_access() {
    log_section "Test 1: Root-Rechte"
    
    if [ "$(id -u)" = "0" ]; then
        log_test "PASS" "Root-Zugriff" "Script läuft mit Root-Rechten"
    else
        log_test "FAIL" "Root-Zugriff" "Script benötigt Root-Rechte (sudo)"
        exit 1
    fi
}

# Test 2: QS-Environment Marker
test_qs_markers() {
    log_section "Test 2: QS-Environment Marker"
    
    local markers_found=0
    
    # Caddy QS-Marker
    if [ -f "/etc/caddy/QS-ENVIRONMENT" ]; then
        log_test "PASS" "Caddy QS-Marker" "$(head -n1 /etc/caddy/QS-ENVIRONMENT)"
        ((markers_found++))
    else
        log_test "FAIL" "Caddy QS-Marker" "Nicht gefunden"
    fi
    
    # Qdrant QS-Marker
    if [ -f "/var/lib/qdrant-qs/QS-ENVIRONMENT" ]; then
        log_test "PASS" "Qdrant QS-Marker" "$(head -n1 /var/lib/qdrant-qs/QS-ENVIRONMENT)"
        ((markers_found++))
    else
        log_test "WARN" "Qdrant QS-Marker" "Nicht gefunden (optional)"
    fi
    
    # code-server QS-User
    if id "codeserver-qs" &>/dev/null; then
        log_test "PASS" "code-server QS-User" "Benutzer 'codeserver-qs' existiert"
        ((markers_found++))
    else
        log_test "FAIL" "code-server QS-User" "Benutzer nicht gefunden"
    fi
    
    if [ $markers_found -ge 2 ]; then
        log_test "PASS" "QS-Environment" "${markers_found} QS-Marker gefunden"
    else
        log_test "WARN" "QS-Environment" "Nur ${markers_found} QS-Marker gefunden"
    fi
}

# Test 3: Tailscale
test_tailscale() {
    log_section "Test 3: Tailscale VPN"
    
    # Tailscale installiert?
    if ! command -v tailscale &> /dev/null; then
        log_test "FAIL" "Tailscale Installation" "Tailscale nicht gefunden"
        return
    fi
    log_test "PASS" "Tailscale Installation" "$(tailscale version | head -n1)"
    
    # Tailscale verbunden?
    if tailscale status &> /dev/null; then
        log_test "PASS" "Tailscale Status" "Verbunden"
    else
        log_test "FAIL" "Tailscale Status" "Nicht verbunden"
        return
    fi
    
    # Tailscale IP
    local ts_ip=$(tailscale ip -4 2>/dev/null | head -n1)
    if [ -n "$ts_ip" ]; then
        log_test "PASS" "Tailscale IP" "$ts_ip"
    else
        log_test "FAIL" "Tailscale IP" "Konnte IP nicht ermitteln"
    fi
    
    # Tailscale Domain
    local ts_domain=$(tailscale status --json 2>/dev/null | grep -o '"DNSName":"[^"]*"' | cut -d'"' -f4 | sed 's/\.$//' || echo "")
    if [ -n "$ts_domain" ]; then
        log_test "PASS" "Tailscale Domain" "$ts_domain"
    else
        log_test "WARN" "Tailscale Domain" "Konnte Domain nicht ermitteln"
    fi
}

# Test 4: Caddy
test_caddy() {
    log_section "Test 4: Caddy Reverse Proxy"
    
    # Caddy installiert?
    if ! command -v caddy &> /dev/null; then
        log_test "FAIL" "Caddy Installation" "Caddy nicht gefunden"
        return
    fi
    log_test "PASS" "Caddy Installation" "$(caddy version | head -n1)"
    
    # Caddy Service aktiv?
    if systemctl is-active --quiet caddy; then
        log_test "PASS" "Caddy Service" "Service läuft"
    else
        log_test "FAIL" "Caddy Service" "Service läuft nicht"
        return
    fi
    
    # Caddyfile validieren
    if caddy validate --config /etc/caddy/Caddyfile &> /dev/null; then
        log_test "PASS" "Caddy Konfiguration" "Caddyfile ist gültig"
    else
        log_test "FAIL" "Caddy Konfiguration" "Caddyfile hat Fehler"
    fi
    
    # QS-Konfigurationen vorhanden?
    if [ -f "/etc/caddy/sites/code-server-qs.caddy" ]; then
        log_test "PASS" "Caddy QS-Config" "code-server-qs.caddy gefunden"
    else
        log_test "WARN" "Caddy QS-Config" "QS-spezifische Config nicht gefunden"
    fi
    
    # Logs prüfen
    local caddy_errors=$(journalctl -u caddy -n 50 --no-pager | grep -i "error" | wc -l)
    if [ "$caddy_errors" -eq 0 ]; then
        log_test "PASS" "Caddy Logs" "Keine Fehler in den letzten 50 Einträgen"
    else
        log_test "WARN" "Caddy Logs" "$caddy_errors Fehler gefunden"
    fi
}

# Test 5: code-server
test_code_server() {
    log_section "Test 5: code-server Web IDE"
    
    # code-server installiert?
    if ! command -v code-server &> /dev/null; then
        log_test "FAIL" "code-server Installation" "code-server nicht gefunden"
        return
    fi
    log_test "PASS" "code-server Installation" "$(code-server --version | head -n1)"
    
    # QS-Service aktiv?
    if systemctl is-active --quiet code-server-qs; then
        log_test "PASS" "code-server-qs Service" "Service läuft"
    else
        log_test "FAIL" "code-server-qs Service" "Service läuft nicht"
        return
    fi
    
    # Port 8080 gebunden?
    if ss -tlnp | grep -q ":8080"; then
        log_test "PASS" "code-server Port" "Lauscht auf Port 8080"
    else
        log_test "FAIL" "code-server Port" "Lauscht nicht auf Port 8080"
    fi
    
    # Lokaler HTTP-Test
    local http_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://127.0.0.1:8080 2>/dev/null || echo "000")
    if [ "$http_status" = "200" ] || [ "$http_status" = "302" ]; then
        log_test "PASS" "code-server HTTP" "Antwortet mit Status $http_status"
    else
        log_test "WARN" "code-server HTTP" "Unerwarteter Status: $http_status"
    fi
    
    # Logs prüfen
    local cs_errors=$(journalctl -u code-server-qs -n 50 --no-pager | grep -i "error" | wc -l)
    if [ "$cs_errors" -eq 0 ]; then
        log_test "PASS" "code-server Logs" "Keine Fehler in den letzten 50 Einträgen"
    else
        log_test "WARN" "code-server Logs" "$cs_errors Fehler gefunden"
    fi
}

# Test 6: Qdrant
test_qdrant() {
    log_section "Test 6: Qdrant Vektordatenbank"
    
    # Qdrant Binary vorhanden?
    if [ -f "/opt/qdrant-qs/qdrant" ]; then
        log_test "PASS" "Qdrant Binary" "Binary gefunden"
    else
        log_test "FAIL" "Qdrant Binary" "Binary nicht gefunden"
        return
    fi
    
    # QS-Service aktiv?
    if systemctl is-active --quiet qdrant-qs; then
        log_test "PASS" "qdrant-qs Service" "Service läuft"
    else
        log_test "FAIL" "qdrant-qs Service" "Service läuft nicht"
        return
    fi
    
    # Port 6333 gebunden?
    if ss -tlnp | grep -q ":6333"; then
        log_test "PASS" "Qdrant HTTP Port" "Lauscht auf Port 6333"
    else
        log_test "FAIL" "Qdrant HTTP Port" "Lauscht nicht auf Port 6333"
    fi
    
    # Port 6334 gebunden?
    if ss -tlnp | grep -q ":6334"; then
        log_test "PASS" "Qdrant gRPC Port" "Lauscht auf Port 6334"
    else
        log_test "WARN" "Qdrant gRPC Port" "Lauscht nicht auf Port 6334"
    fi
    
    # HTTP API Root-Test
    local qdrant_response=$(curl -s http://127.0.0.1:6333/ 2>/dev/null || echo "error")
    if [[ "$qdrant_response" == *"qdrant"* ]]; then
        log_test "PASS" "Qdrant HTTP API" "API antwortet: $qdrant_response"
    else
        log_test "FAIL" "Qdrant HTTP API" "API antwortet nicht"
    fi
    
    # Health-Check
    local health_status=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:6333/health 2>/dev/null || echo "000")
    if [ "$health_status" = "200" ]; then
        log_test "PASS" "Qdrant Health" "Health-Check erfolgreich (200)"
    else
        log_test "WARN" "Qdrant Health" "Health-Check Status: $health_status"
    fi
    
    # Collections-API
    local collections_response=$(curl -s http://127.0.0.1:6333/collections 2>/dev/null || echo "error")
    if [[ "$collections_response" == *"result"* ]]; then
        log_test "PASS" "Qdrant Collections API" "Collections-API funktioniert"
    else
        log_test "WARN" "Qdrant Collections API" "Collections-API antwortet nicht erwartungsgemäß"
    fi
    
    # Logs prüfen
    local qdrant_errors=$(journalctl -u qdrant-qs -n 50 --no-pager | grep -i "error" | wc -l)
    if [ "$qdrant_errors" -eq 0 ]; then
        log_test "PASS" "Qdrant Logs" "Keine Fehler in den letzten 50 Einträgen"
    else
        log_test "WARN" "Qdrant Logs" "$qdrant_errors Fehler gefunden"
    fi
}

# Test 7: Netzwerk und Firewall
test_network() {
    log_section "Test 7: Netzwerk und Firewall"
    
    # Localhost-Binding prüfen
    local localhost_services=$(ss -tlnp | grep "127.0.0.1" | wc -l)
    if [ "$localhost_services" -gt 0 ]; then
        log_test "PASS" "Localhost Services" "$localhost_services Services auf localhost"
    else
        log_test "WARN" "Localhost Services" "Keine Services auf localhost gefunden"
    fi
    
    # Keine öffentlichen Bindings (Sicherheit)
    local public_bindings=$(ss -tlnp | grep -v "127.0.0.1" | grep -v "100\." | grep -E ":(8080|6333|6334)" | wc -l)
    if [ "$public_bindings" -eq 0 ]; then
        log_test "PASS" "Sicherheit" "Keine öffentlichen Port-Bindings gefunden"
    else
        log_test "WARN" "Sicherheit" "$public_bindings öffentliche Bindings gefunden"
    fi
    
    # UFW Status (optional)
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            log_test "PASS" "UFW Firewall" "Firewall ist aktiv"
        else
            log_test "WARN" "UFW Firewall" "Firewall ist nicht aktiv"
        fi
    else
        log_test "WARN" "UFW Firewall" "UFW nicht installiert"
    fi
}

# Test 8: Dateisystem und Speicher
test_filesystem() {
    log_section "Test 8: Dateisystem und Speicher"
    
    # Freier Speicher
    local free_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$free_space" -gt 5 ]; then
        log_test "PASS" "Freier Speicher" "${free_space}GB verfügbar"
    else
        log_test "WARN" "Freier Speicher" "Nur ${free_space}GB verfügbar"
    fi
    
    # QS-Verzeichnisse vorhanden
    local qs_dirs=("/etc/caddy" "/var/lib/qdrant-qs" "/opt/qdrant-qs" "/home/codeserver-qs")
    local dirs_found=0
    
    for dir in "${qs_dirs[@]}"; do
        if [ -d "$dir" ]; then
            ((dirs_found++))
        fi
    done
    
    if [ $dirs_found -eq ${#qs_dirs[@]} ]; then
        log_test "PASS" "QS-Verzeichnisse" "Alle $dirs_found Verzeichnisse vorhanden"
    else
        log_test "WARN" "QS-Verzeichnisse" "$dirs_found von ${#qs_dirs[@]} Verzeichnissen vorhanden"
    fi
    
    # Log-Dateien
    if [ -f "$QS_LOG_FILE" ]; then
        local log_size=$(du -h "$QS_LOG_FILE" | cut -f1)
        log_test "PASS" "QS-Deployment-Log" "Vorhanden (${log_size})"
    else
        log_test "WARN" "QS-Deployment-Log" "Nicht gefunden"
    fi
}

# Test 9: Systemd Services
test_systemd_services() {
    log_section "Test 9: Systemd Services"
    
    local services=("caddy" "code-server-qs" "qdrant-qs" "tailscaled")
    local services_running=0
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_test "PASS" "Service: $service" "Läuft und aktiviert"
            ((services_running++))
        else
            if systemctl list-unit-files | grep -q "^${service}.service"; then
                log_test "FAIL" "Service: $service" "Existiert, läuft aber nicht"
            else
                log_test "WARN" "Service: $service" "Service nicht gefunden (optional)"
            fi
        fi
    done
    
    if [ $services_running -ge 3 ]; then
        log_test "PASS" "Services Gesamt" "$services_running von ${#services[@]} Services laufen"
    else
        log_test "WARN" "Services Gesamt" "Nur $services_running von ${#services[@]} Services laufen"
    fi
}

# Test 10: Log-Validierung
test_log_validation() {
    log_section "Test 10: Log-Validierung"
    
    # Gesamtzahl an Systemfehlern
    local total_errors=$(journalctl -p err -n 100 --no-pager | wc -l)
    if [ "$total_errors" -lt 10 ]; then
        log_test "PASS" "System-Fehler" "$total_errors Fehler in den letzten 100 Einträgen"
    else
        log_test "WARN" "System-Fehler" "$total_errors Fehler gefunden"
    fi
    
    # Caddy-Logs
    if journalctl -u caddy -n 50 --no-pager | grep -iq "listening on"; then
        log_test "PASS" "Caddy Log-Validierung" "Caddy lauscht auf Ports"
    else
        log_test "WARN" "Caddy Log-Validierung" "Keine 'listening on' Meldung gefunden"
    fi
    
    # code-server-Logs
    if journalctl -u code-server-qs -n 50 --no-pager | grep -iq "HTTP server listening"; then
        log_test "PASS" "code-server Log-Validierung" "code-server lauscht"
    else
        log_test "WARN" "code-server Log-Validierung" "Keine 'listening' Meldung gefunden"
    fi
    
    # Qdrant-Logs
    if journalctl -u qdrant-qs -n 50 --no-pager | grep -iq "listening on"; then
        log_test "PASS" "Qdrant Log-Validierung" "Qdrant lauscht auf Ports"
    else
        log_test "WARN" "Qdrant Log-Validierung" "Keine 'listening' Meldung gefunden"
    fi
}

# ============================================================================
# ZUSAMMENFASSUNG
# ============================================================================

show_summary() {
    echo ""
    echo "============================================================================"
    echo -e "${MAGENTA}QS-VPS E2E-Test Zusammenfassung${NC}"
    echo "============================================================================"
    echo ""
    
    local total_tests=$((TESTS_PASSED + TESTS_FAILED + TESTS_WARNING))
    
    echo -e "${GREEN}✓ Tests bestanden:   ${TESTS_PASSED}${NC}"
    echo -e "${RED}✗ Tests fehlgeschlagen: ${TESTS_FAILED}${NC}"
    echo -e "${YELLOW}⚠ Tests mit Warnung: ${TESTS_WARNING}${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "  Gesamt:            $total_tests"
    echo ""
    
    # Erfolgsrate berechnen
    local success_rate=0
    if [ $total_tests -gt 0 ]; then
        success_rate=$((TESTS_PASSED * 100 / total_tests))
    fi
    
    echo "  Erfolgsrate:       ${success_rate}%"
    echo ""
    
    # Gesamtbewertung
    if [ $TESTS_FAILED -eq 0 ] && [ $TESTS_WARNING -eq 0 ]; then
        echo -e "${GREEN}🎉 Alle Tests erfolgreich! QS-VPS ist vollständig einsatzbereit.${NC}"
        echo ""
        return 0
    elif [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${YELLOW}⚠ Alle kritischen Tests bestanden, aber ${TESTS_WARNING} Warnungen.${NC}"
        echo -e "${YELLOW}QS-VPS ist einsatzbereit, aber einige optionale Komponenten fehlen.${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}❌ ${TESTS_FAILED} kritische Test(s) fehlgeschlagen!${NC}"
        echo -e "${RED}QS-VPS benötigt Korrekturen vor dem Einsatz.${NC}"
        echo ""
        return 1
    fi
}

show_test_log_location() {
    echo "============================================================================"
    echo "Test-Logs gespeichert in:"
    echo "  • ${TEST_LOG_FILE}"
    echo "  • ${QS_LOG_FILE}"
    echo ""
    echo "Detaillierte Service-Logs:"
    echo "  • Caddy:       journalctl -u caddy -f"
    echo "  • code-server: journalctl -u code-server-qs -f"
    echo "  • Qdrant:      journalctl -u qdrant-qs -f"
    echo "  • Tailscale:   journalctl -u tailscaled -f"
    echo "============================================================================"
    echo ""
}

# ============================================================================
# HAUPTPROGRAMM
# ============================================================================

main() {
    echo ""
    echo "============================================================================"
    echo "  QS-VPS E2E Deployment-Tests"
    echo "  DevSystem Quality Server Validation"
    echo "============================================================================"
    echo ""
    echo "Start: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # Tests ausführen
    test_root_access
    test_qs_markers
    test_tailscale
    test_caddy
    test_code_server
    test_qdrant
    test_network
    test_filesystem
    test_systemd_services
    test_log_validation
    
    # Zusammenfassung
    show_summary
    local exit_code=$?
    
    # Test-Log-Location zeigen
    show_test_log_location
    
    echo "Ende: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    exit $exit_code
}

# Script ausführen
main "$@"
