#!/bin/bash
#
# DevSystem Code-Server Tailscale-Integration E2E-Test
# Dieses Skript führt spezialisierte Tests für die Tailscale-Integration mit Code-Server durch
#
# Version: 1.0
# Autor: DevSystem Team
# Datum: 2026-04-11
#

# Fehler bei der Ausführung beenden das Skript
set -e

# Konfigurationsoptionen
VERBOSE=${VERBOSE:-false}
TEST_RESULTS_DIR=${TEST_RESULTS_DIR:-"/tmp/code-server-test-results"}
TEST_LOG_FILE="${TEST_RESULTS_DIR}/tailscale-test-results.log"

# code-server-Konfiguration
CODE_SERVER_PORT="8080"
CADDY_PORT="9443"
TAILSCALE_PORT="8088"

# Farbdefinitionen für Terminal-Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Testzähler
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# ============================================================================
# LOGGING-FUNKTIONEN
# ============================================================================

# Log-Funktion
log() {
    local level=$1
    local message=$2
    local color=$NC
    
    case $level in
        "INFO") color=$GREEN ;;
        "WARN") color=$YELLOW ;;
        "ERROR") color=$RED ;;
        "TEST") color=$BLUE ;;
        "STEP") color=$CYAN ;;
    esac
    
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message${NC}" | tee -a "$TEST_LOG_FILE"
}

# ============================================================================
# INITIALISIERUNG
# ============================================================================

# Initialisierung der Testumgebung
init_test_env() {
    mkdir -p "$TEST_RESULTS_DIR"
    > "$TEST_LOG_FILE"
    
    log "INFO" "Initialisiere Tailscale-Integration-Tests..."
    
    if [ "$(id -u)" -ne 0 ]; then
        log "ERROR" "Dieses Skript muss als Root ausgeführt werden. Bitte verwenden Sie 'sudo'."
        exit 1
    fi
}

# Funktion zum Parsen der Kommandozeilenargumente
parse_args() {
    for arg in "$@"; do
        case $arg in
            --verbose)
                VERBOSE=true
                ;;
            --help)
                echo "Verwendung: sudo $0 [--verbose]"
                echo ""
                echo "Optionen:"
                echo "  --verbose             Ausführliche Ausgabe aktivieren"
                echo "  --help                Diese Hilfe anzeigen"
                echo ""
                exit 0
                ;;
        esac
    done
    
    if [ "$VERBOSE" = true ]; then
        log "INFO" "Ausführliche Ausgabe aktiviert."
    fi
}

# Funktion zum Ausführen eines Tests
run_test() {
    local test_name=$1
    local test_function=$2
    
    log "TEST" "Starte Tailscale-Test: $test_name"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if $test_function; then
        log "INFO" "Test '$test_name' erfolgreich abgeschlossen."
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        log "ERROR" "Test '$test_name' fehlgeschlagen."
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Funktion zum Anzeigen der Testergebnisse
show_test_results() {
    echo ""
    log "TEST" "====== Tailscale-Integration Testergebnisse ======"
    log "INFO" "Durchgeführte Tests: $TOTAL_TESTS"
    log "INFO" "Erfolgreiche Tests: $PASSED_TESTS"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        log "INFO" "Fehlgeschlagene Tests: $FAILED_TESTS"
        log "INFO" "Alle Tailscale-Tests wurden erfolgreich abgeschlossen!"
    else
        log "ERROR" "Fehlgeschlagene Tests: $FAILED_TESTS"
        log "ERROR" "Einige Tailscale-Tests sind fehlgeschlagen. Überprüfen Sie die Logs für Details."
    fi
    
    echo ""
}

# Tailscale-IP ermitteln
get_tailscale_info() {
    log "STEP" "Ermittle Tailscale-Informationen..."
    
    if ! command -v tailscale &> /dev/null; then
        log "ERROR" "Tailscale ist nicht installiert. Tests können nicht durchgeführt werden."
        return 1
    fi
    
    TAILSCALE_IP=${TAILSCALE_IP:-$(tailscale ip -4 2>/dev/null | head -n1)}
    
    if [ -z "$TAILSCALE_IP" ]; then
        log "ERROR" "Konnte Tailscale-IP nicht ermitteln."
        return 1
    fi
    
    log "INFO" "Tailscale-IP: $TAILSCALE_IP"
    
    # Hole Hostname
    TAILSCALE_HOSTNAME=$(tailscale status --json | jq -r '.Self.DNSName' 2>/dev/null || echo "")
    [ -n "$TAILSCALE_HOSTNAME" ] && log "INFO" "Tailscale-Hostname: $TAILSCALE_HOSTNAME"
    
    return 0
}

#######################################
# Test: Tailscale-Installation und Status
#######################################

test_tailscale_installation() {
    log "TEST" "Überprüfe Tailscale-Installation und Status..."
    
    local test_failed=false
    
    if ! command -v tailscale &> /dev/null; then
        log "ERROR" "Tailscale ist nicht installiert."
        return 1
    else
        log "INFO" "Tailscale-Befehl ist verfügbar."
    fi
    
    local tailscale_version=$(tailscale version 2>&1 | head -n1)
    log "INFO" "Tailscale-Version: $tailscale_version"
    
    if ! systemctl list-unit-files | grep -q "tailscaled.service"; then
        log "ERROR" "tailscaled-Dienst ist nicht installiert."
        test_failed=true
    else
        log "INFO" "tailscaled-Dienst ist installiert."
    fi
    
    if ! systemctl is-active --quiet tailscaled; then
        log "ERROR" "tailscaled-Dienst läuft nicht."
        test_failed=true
        log "INFO" "Service-Status:"
        systemctl status tailscaled --no-pager -l | head -n 20 | tee -a "$TEST_LOG_FILE"
    else
        log "INFO" "tailscaled-Dienst läuft."
    fi
    
    if ! systemctl is-enabled --quiet tailscaled; then
        log "WARN" "tailscaled-Dienst ist nicht für den Systemstart aktiviert."
    else
        log "INFO" "tailscaled-Dienst ist für den Systemstart aktiviert (Auto-Start)."
    fi
    
    tailscale status > "$TEST_RESULTS_DIR/tailscale_status.txt" 2>&1 || true
    
    if grep -q "Tailscale" "$TEST_RESULTS_DIR/tailscale_status.txt"; then
        log "INFO" "Tailscale-Status konnte abgerufen werden."
        [ "$VERBOSE" = true ] && cat "$TEST_RESULTS_DIR/tailscale_status.txt" | tee -a "$TEST_LOG_FILE"
    else
        log "ERROR" "Tailscale-Status konnte nicht abgerufen werden."
        test_failed=true
    fi
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# Test: Tailscale-Verbindung zu Code-Server
#######################################

test_tailscale_connection() {
    log "TEST" "Überprüfe Tailscale-Verbindung zu Code-Server..."
    
    local test_failed=false
    
    if [ -z "$TAILSCALE_IP" ]; then
        log "ERROR" "Tailscale-IP ist nicht verfügbar."
        return 1
    fi
    
    log "STEP" "Prüfe Konnektivität zum Caddy-Reverse-Proxy über Tailscale..."
    local https_code=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "https://$TAILSCALE_IP:$CADDY_PORT" 2>/dev/null || echo "000")
    
    if [ "$https_code" != "000" ]; then
        log "INFO" "HTTPS-Verbindung zu $TAILSCALE_IP:$CADDY_PORT ist möglich (HTTP-Code: $https_code)."
        curl -k -s -I --connect-timeout 5 "https://$TAILSCALE_IP:$CADDY_PORT" > "$TEST_RESULTS_DIR/tailscale_caddy_headers.txt" 2>/dev/null || true
        
        if [ "$VERBOSE" = true ] && [ -f "$TEST_RESULTS_DIR/tailscale_caddy_headers.txt" ]; then
            log "INFO" "HTTPS-Header vom Caddy-Server über Tailscale:"
            cat "$TEST_RESULTS_DIR/tailscale_caddy_headers.txt" | tee -a "$TEST_LOG_FILE"
        fi
    else
        log "ERROR" "HTTPS-Verbindung zu $TAILSCALE_IP:$CADDY_PORT ist nicht möglich."
        test_failed=true
    fi
    
    log "STEP" "Prüfe Code-Server-Login über Tailscale..."
    local response=$(curl -k -s --connect-timeout 5 "https://$TAILSCALE_IP:$CADDY_PORT/login" 2>/dev/null || echo "")
    
    if echo "$response" | grep -qi "code-server\|password\|login"; then
        log "INFO" "Code-Server-Login ist über Tailscale erreichbar."
    else
        log "WARN" "Code-Server-Login-Seite konnte über Tailscale nicht verifiziert werden."
        test_failed=true
    fi
    
    log "STEP" "Prüfe WebSocket-Unterstützung über Tailscale..."
    if [ -f "$TEST_RESULTS_DIR/tailscale_caddy_headers.txt" ]; then
        if grep -qi "upgrade" "$TEST_RESULTS_DIR/tailscale_caddy_headers.txt"; then
            log "INFO" "WebSocket-Header werden über Tailscale unterstützt."
        else
            log "WARN" "WebSocket-Header nicht in Response gefunden (kann bei Login-Seite normal sein)."
        fi
    fi
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# Test: Tailscale-ACLs und Zugriffskontrolle
#######################################

test_tailscale_acl() {
    log "TEST" "Überprüfe Tailscale-ACLs und Zugriffskontrolle..."
    
    local test_failed=false
    
    log "STEP" "Prüfe ob Tailscale mit ACLs konfiguriert ist..."
    
    local tailscale_status=$(tailscale status --json 2>/dev/null || echo "{}")
    
    if command -v jq &> /dev/null && [ -n "$tailscale_status" ]; then
        echo "$tailscale_status" > "$TEST_RESULTS_DIR/tailscale_status.json"
        
        local acl_enabled=$(echo "$tailscale_status" | jq -r '.Self.ControlURL' 2>/dev/null)
        if [ -n "$acl_enabled" ] && [ "$acl_enabled" != "null" ]; then
            log "INFO" "Tailscale mit Control-Server konfiguriert: $acl_enabled"
        else
            log "WARN" "Tailscale möglicherweise ohne zentrale ACLs konfiguriert."
        fi
        
        local tags=$(echo "$tailscale_status" | jq -r '.Self.Tags[]?' 2>/dev/null)
        if [ -n "$tags" ] && [ "$tags" != "null" ]; then
            log "INFO" "Tailscale-Tags konfiguriert:"
            echo "$tags" | while read -r tag; do
                log "INFO" "  - $tag"
            done
        else
            log "INFO" "Keine Tailscale-Tags konfiguriert."
        fi
    else
        log "WARN" "Konnte Tailscale-Status nicht als JSON parsen oder jq nicht verfügbar."
    fi
    
    log "STEP" "Prüfe Zugriffskontrolle für Code-Server..."
    
    # Prüfe ob Caddy mit Tailscale-Authentifizierung konfiguriert ist
    if [ -d "/etc/caddy" ]; then
        if grep -r "tailscale" /etc/caddy/ > /dev/null 2>&1; then
            log "INFO" "Caddy mit Tailscale-Integration konfiguriert."
        else
            log "WARN" "Keine explizite Tailscale-Integration in Caddy gefunden."
        fi
    fi
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# Test: Tailscale-Performance und Verbindungsqualität
#######################################

test_tailscale_performance() {
    log "TEST" "Überprüfe Tailscale-Performance und Verbindungsqualität..."
    
    local test_failed=false
    
    if [ -z "$TAILSCALE_IP" ]; then
        log "ERROR" "Tailscale-IP ist nicht verfügbar."
        return 1
    fi
    
    log "STEP" "Führe Ping-Test über Tailscale durch..."
    if ping -c 3 "$TAILSCALE_IP" > "$TEST_RESULTS_DIR/tailscale_ping.txt" 2>&1; then
        local avg_ping=$(grep "avg" "$TEST_RESULTS_DIR/tailscale_ping.txt" | awk -F'/' '{print $5}')
        log "INFO" "Ping zu Tailscale-IP erfolgreich. Durchschnitt: ${avg_ping}ms"
    else
        log "ERROR" "Ping zu Tailscale-IP fehlgeschlagen."
        test_failed=true
    fi
    
    log "STEP" "Führe HTTP-Latenz-Test durch..."
    local start_time=$(date +%s.%N)
    if curl -k -s -o /dev/null "https://$TAILSCALE_IP:$CADDY_PORT" 2>/dev/null; then
        local end_time=$(date +%s.%N)
        local latency=$(echo "$end_time - $start_time" | bc)
        log "INFO" "HTTP-Latenz über Tailscale: ${latency}s"
        
        # Prüfe ob Latenz akzeptabel ist (unter 1 Sekunde)
        if (( $(echo "$latency < 1.0" | bc -l) )); then
            log "INFO" "Tailscale-Latenz ist akzeptabel."
        else
            log "WARN" "Tailscale-Latenz ist höher als erwartet (${latency}s > 1.0s)."
        fi
    else
        log "ERROR" "HTTP-Latenz-Test fehlgeschlagen."
        test_failed=true
    fi
    
    # Prüfe Tailscale-Verbindungsdetails
    if command -v tailscale &> /dev/null; then
        tailscale status --peers=true > "$TEST_RESULTS_DIR/tailscale_peers.txt" 2>&1 || true
        
        if [ "$VERBOSE" = true ]; then
            log "INFO" "Tailscale-Peers:"
            cat "$TEST_RESULTS_DIR/tailscale_peers.txt" | tee -a "$TEST_LOG_FILE"
        fi
        
        # Prüfe ob Direct oder DERP-Verbindung
        if grep -q "direct" "$TEST_RESULTS_DIR/tailscale_peers.txt"; then
            log "INFO" "Direkte Tailscale-Verbindungen verfügbar."
        elif grep -q "derp" "$TEST_RESULTS_DIR/tailscale_peers.txt"; then
            log "INFO" "DERP-vermittelte Tailscale-Verbindungen verfügbar."
        else
            log "WARN" "Verbindungsdetails nicht eindeutig erkennbar."
        fi
    fi
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# Hauptfunktion
#######################################

main() {
    log "TEST" "==== Starte Tailscale-Integration Tests für Code-Server ===="
    
    init_test_env
    parse_args "$@"
    
    if ! get_tailscale_info; then
        log "ERROR" "Tailscale-Informationen konnten nicht ermittelt werden. Tests werden abgebrochen."
        exit 1
    fi
    
    run_test "tailscale_installation" test_tailscale_installation
    run_test "tailscale_connection" test_tailscale_connection
    run_test "tailscale_acl" test_tailscale_acl
    run_test "tailscale_performance" test_tailscale_performance
    
    show_test_results
    
    log "TEST" "==== Tailscale-Integration Tests abgeschlossen ===="
    
    if [ $FAILED_TESTS -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"