#!/bin/bash
#
# Caddy E2E-Testskript für DevSystem
# Dieses Skript führt umfassende Tests für die Caddy-Installation und -Konfiguration durch
#
# Version: 1.0
# Autor: DevSystem Team
# Datum: 2026-04-09
#
# Funktionen:
# - Service-Status-Tests (systemctl, Prozess-Status)
# - Konfigurationstests (Caddyfile-Validierung, Tailscale-IP)
# - Netzwerk-Tests (Port 443, HTTPS-Verbindung, WebSocket)
# - Sicherheitstests (Tailscale-Only-Zugriff, TLS, Security-Header)
# - Log-Validierung (journalctl, Caddy-Logs)
# - Integration mit code-server (Reverse Proxy)
#
# Verwendung: sudo bash test-caddy.sh [--verbose] [--test=TESTNAME]

# Fehler bei der Ausführung beenden das Skript
set -e

# Konfigurationsoptionen
VERBOSE=false
SPECIFIC_TEST=""
TEST_RESULTS_DIR="/tmp/caddy-test-results"
TEST_LOG_FILE="$TEST_RESULTS_DIR/test-results.log"
FINAL_LOG_FILE="/var/log/devsystem-test-caddy.log"

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

# Caddy-Konfiguration
CADDY_DIR="/etc/caddy"
CADDY_LOG_DIR="/var/log/caddy"
TAILSCALE_IP=""
TAILSCALE_DOMAIN=""
CODE_SERVER_PORT="8080"

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
    > "$TEST_LOG_FILE"  # Leere die Log-Datei
    
    log "INFO" "Initialisiere Testumgebung..."
    log "INFO" "Testergebnisse werden in $TEST_RESULTS_DIR gespeichert"
    
    # Prüfe, ob das Skript als Root läuft
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
            --test=*)
                SPECIFIC_TEST="${arg#*=}"
                ;;
            --help)
                echo "Verwendung: sudo bash test-caddy.sh [--verbose] [--test=TESTNAME]"
                echo ""
                echo "Optionen:"
                echo "  --verbose             Ausführliche Ausgabe aktivieren"
                echo "  --test=TESTNAME       Nur einen bestimmten Test ausführen"
                echo "                        Gültige Testnamen: service, config, network, security, logs, integration"
                echo "  --help                Diese Hilfe anzeigen"
                echo ""
                exit 0
                ;;
        esac
    done
    
    if [ -n "$SPECIFIC_TEST" ]; then
        log "INFO" "Führe nur den Test '$SPECIFIC_TEST' aus."
    fi
    
    if [ "$VERBOSE" = true ]; then
        log "INFO" "Ausführliche Ausgabe aktiviert."
    fi
}

# Funktion zum Ausführen eines Tests
run_test() {
    local test_name=$1
    local test_function=$2
    
    if [ -n "$SPECIFIC_TEST" ] && [ "$SPECIFIC_TEST" != "$test_name" ]; then
        return 0
    fi
    
    log "TEST" "Starte Test: $test_name"
    
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
    log "TEST" "====== Testergebnisse ======"
    log "INFO" "Durchgeführte Tests: $TOTAL_TESTS"
    log "INFO" "Erfolgreiche Tests: $PASSED_TESTS"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        log "INFO" "Fehlgeschlagene Tests: $FAILED_TESTS"
        log "INFO" "Alle Tests wurden erfolgreich abgeschlossen!"
    else
        log "ERROR" "Fehlgeschlagene Tests: $FAILED_TESTS"
        log "ERROR" "Einige Tests sind fehlgeschlagen. Überprüfen Sie die Logs für Details: $TEST_LOG_FILE"
    fi
    
    echo ""
}

# Tailscale-IP ermitteln
get_tailscale_info() {
    log "STEP" "Ermittle Tailscale-Informationen..."
    
    if ! command -v tailscale &> /dev/null; then
        log "WARN" "Tailscale ist nicht installiert. Einige Tests werden übersprungen."
        return 1
    fi
    
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null | head -n1)
    
    if [ -z "$TAILSCALE_IP" ]; then
        log "WARN" "Konnte Tailscale-IP nicht ermitteln."
        return 1
    fi
    
    log "INFO" "Tailscale-IP: $TAILSCALE_IP"
    
    # Domain ermitteln
    if command -v jq &> /dev/null; then
        TAILSCALE_DOMAIN=$(tailscale status --json 2>/dev/null | jq -r '.Self.DNSName' | sed 's/\.$//')
    fi
    
    if [ -z "$TAILSCALE_DOMAIN" ] || [ "$TAILSCALE_DOMAIN" = "null" ]; then
        TAILSCALE_DOMAIN=$(hostname -f 2>/dev/null || hostname)
    fi
    
    log "INFO" "Tailscale-Domain: $TAILSCALE_DOMAIN"
    
    return 0
}

#######################################
# 1. Test: Service-Status-Tests
#######################################

test_service() {
    log "TEST" "Überprüfe Caddy-Service-Status..."
    
    local test_failed=false
    
    # 1.1 Prüfe, ob der Caddy-Befehl verfügbar ist
    if ! command -v caddy &> /dev/null; then
        log "ERROR" "Caddy ist nicht installiert. Der Befehl 'caddy' wurde nicht gefunden."
        return 1
    else
        log "INFO" "Caddy-Befehl ist verfügbar."
    fi
    
    # 1.2 Prüfe die Version von Caddy
    local caddy_version=$(caddy version 2>&1 | head -n1)
    log "INFO" "Caddy-Version: $caddy_version"
    
    # 1.3 Prüfe, ob der Caddy-Dienst installiert ist
    if ! systemctl list-unit-files | grep -q "caddy.service"; then
        log "ERROR" "Caddy-Dienst ist nicht installiert."
        return 1
    else
        log "INFO" "Caddy-Dienst ist installiert."
    fi
    
    # 1.4 Prüfe, ob der Caddy-Dienst läuft
    if ! systemctl is-active --quiet caddy; then
        log "ERROR" "Caddy-Dienst läuft nicht."
        test_failed=true
        
        # Zeige Status-Details
        log "INFO" "Service-Status:"
        systemctl status caddy --no-pager -l | head -n 20 | tee -a "$TEST_LOG_FILE"
    else
        log "INFO" "Caddy-Dienst läuft."
    fi
    
    # 1.5 Prüfe, ob der Caddy-Dienst beim Systemstart aktiviert ist (enabled)
    if ! systemctl is-enabled --quiet caddy; then
        log "WARN" "Caddy-Dienst ist nicht für den Systemstart aktiviert."
    else
        log "INFO" "Caddy-Dienst ist für den Systemstart aktiviert (Auto-Start)."
    fi
    
    # 1.6 Prüfe, ob der Caddy-Prozess aktiv ist und reagiert
    if pgrep -x caddy > /dev/null; then
        log "INFO" "Caddy-Prozess ist aktiv."
        
        # Zeige Prozess-Details
        local caddy_pid=$(pgrep -x caddy | head -n1)
        log "INFO" "Caddy-PID: $caddy_pid"
        
        # Prüfe Prozess-Laufzeit
        local uptime=$(ps -p "$caddy_pid" -o etime= 2>/dev/null | tr -d ' ')
        log "INFO" "Caddy-Laufzeit: $uptime"
    else
        log "ERROR" "Caddy-Prozess ist nicht aktiv."
        test_failed=true
    fi
    
    # 1.7 Prüfe Systemd-Service-Details
    log "INFO" "Systemd-Service-Details:"
    systemctl show caddy --no-pager | grep -E "^(MainPID|ActiveState|SubState|LoadState|UnitFileState)=" | tee -a "$TEST_LOG_FILE"
    
    if [ "$test_failed" = true ]; then
        return 1
    fi
    
    return 0
}

#######################################
# 2. Test: Konfigurationstests
#######################################

test_config() {
    log "TEST" "Überprüfe Caddy-Konfiguration..."
    
    local test_failed=false
    
    # 2.1 Prüfe, ob Caddyfile existiert
    if [ ! -f "$CADDY_DIR/Caddyfile" ]; then
        log "ERROR" "Caddyfile existiert nicht unter $CADDY_DIR/Caddyfile"
        return 1
    else
        log "INFO" "Caddyfile existiert: $CADDY_DIR/Caddyfile"
    fi
    
    # 2.2 Prüfe Caddyfile-Syntax (Validierung)
    log "STEP" "Validiere Caddyfile-Syntax..."
    if caddy validate --config "$CADDY_DIR/Caddyfile" > "$TEST_RESULTS_DIR/caddy_validate.log" 2>&1; then
        log "INFO" "Caddyfile-Syntax ist valide."
    else
        log "ERROR" "Caddyfile-Syntax ist ungültig!"
        if [ "$VERBOSE" = true ]; then
            log "INFO" "Validierungsfehler:"
            cat "$TEST_RESULTS_DIR/caddy_validate.log" | tee -a "$TEST_LOG_FILE"
        fi
        test_failed=true
    fi
    
    # 2.3 Prüfe, ob Tailscale-IP in der Konfiguration vorhanden ist
    if [ -n "$TAILSCALE_IP" ]; then
        log "STEP" "Prüfe Tailscale-IP-Konfiguration..."
        if grep -r "$TAILSCALE_IP" "$CADDY_DIR/" > /dev/null 2>&1; then
            log "INFO" "Tailscale-IP ($TAILSCALE_IP) ist in der Konfiguration vorhanden."
        else
            log "WARN" "Tailscale-IP ($TAILSCALE_IP) wurde nicht in der Konfiguration gefunden."
        fi
    fi
    
    # 2.4 Prüfe, ob code-server Reverse Proxy konfiguriert ist
    log "STEP" "Prüfe code-server Reverse Proxy Konfiguration..."
    if grep -r "reverse_proxy.*localhost:$CODE_SERVER_PORT" "$CADDY_DIR/" > /dev/null 2>&1; then
        log "INFO" "code-server Reverse Proxy ist konfiguriert (Port $CODE_SERVER_PORT)."
    else
        log "WARN" "code-server Reverse Proxy wurde nicht gefunden oder verwendet anderen Port."
    fi
    
    # 2.5 Prüfe Site-Konfigurationen
    if [ -d "$CADDY_DIR/sites" ]; then
        local site_count=$(find "$CADDY_DIR/sites" -name "*.caddy" | wc -l)
        log "INFO" "Gefundene Site-Konfigurationen: $site_count"
        
        if [ "$VERBOSE" = true ]; then
            log "INFO" "Site-Konfigurationsdateien:"
            find "$CADDY_DIR/sites" -name "*.caddy" | tee -a "$TEST_LOG_FILE"
        fi
    fi
    
    # 2.6 Prüfe Snippets
    if [ -d "$CADDY_DIR/snippets" ]; then
        local snippet_count=$(find "$CADDY_DIR/snippets" -name "*.caddy" | wc -l)
        log "INFO" "Gefundene Snippets: $snippet_count"
        
        # Prüfe auf Sicherheits-Header-Snippet
        if [ -f "$CADDY_DIR/snippets/security-headers.caddy" ]; then
            log "INFO" "Sicherheits-Header-Snippet gefunden."
        else
            log "WARN" "Sicherheits-Header-Snippet nicht gefunden."
        fi
    fi
    
    # 2.7 Prüfe TLS-Konfiguration
    if [ -d "$CADDY_DIR/tls" ]; then
        log "INFO" "TLS-Verzeichnis existiert."
        
        # Prüfe auf Tailscale-Zertifikate
        if [ -d "$CADDY_DIR/tls/tailscale" ]; then
            local cert_count=$(find "$CADDY_DIR/tls/tailscale" -name "*.crt" | wc -l)
            log "INFO" "Gefundene Tailscale-Zertifikate: $cert_count"
        fi
    fi
    
    # 2.8 Prüfe Log-Verzeichnis
    if [ ! -d "$CADDY_LOG_DIR" ]; then
        log "WARN" "Caddy-Log-Verzeichnis existiert nicht: $CADDY_LOG_DIR"
    else
        log "INFO" "Caddy-Log-Verzeichnis existiert: $CADDY_LOG_DIR"
    fi
    
    if [ "$test_failed" = true ]; then
        return 1
    fi
    
    return 0
}

#######################################
# 3. Test: Netzwerk-Tests
#######################################

test_network() {
    log "TEST" "Überprüfe Caddy-Netzwerk-Konfiguration..."
    
    local test_failed=false
    
    # 3.1 Prüfe, ob Caddy auf Port 443 (HTTPS) lauscht
    log "STEP" "Prüfe ob Caddy auf Port 443 lauscht..."
    if ss -tlnp | grep -q ":443.*caddy" || netstat -tlnp 2>/dev/null | grep -q ":443.*caddy"; then
        log "INFO" "Caddy lauscht auf Port 443 (HTTPS)."
    else
        log "ERROR" "Caddy lauscht NICHT auf Port 443 (HTTPS)."
        test_failed=true
        
        # Zeige alle lauschenden Ports
        if [ "$VERBOSE" = true ]; then
            log "INFO" "Alle lauschenden Ports:"
            ss -tlnp | grep caddy | tee -a "$TEST_LOG_FILE" || netstat -tlnp 2>/dev/null | grep caddy | tee -a "$TEST_LOG_FILE"
        fi
    fi
    
    # 3.2 Prüfe Tailscale-IP-Erreichbarkeit
    if [ -n "$TAILSCALE_IP" ]; then
        log "STEP" "Prüfe Tailscale-IP-Erreichbarkeit..."
        if ping -c 1 -W 2 "$TAILSCALE_IP" > /dev/null 2>&1; then
            log "INFO" "Tailscale-IP ($TAILSCALE_IP) ist erreichbar."
        else
            log "WARN" "Tailscale-IP ($TAILSCALE_IP) ist nicht per Ping erreichbar (kann normal sein)."
        fi
    fi
    
    # 3.3 Prüfe HTTPS-Verbindung über Tailscale-IP
    if [ -n "$TAILSCALE_IP" ]; then
        log "STEP" "Prüfe HTTPS-Verbindung über Tailscale-IP..."
        
        # Teste mit curl (selbstsignierte Zertifikate akzeptieren)
        local http_code=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "https://$TAILSCALE_IP" 2>/dev/null || echo "000")
        
        if [ "$http_code" != "000" ]; then
            log "INFO" "HTTPS-Verbindung zu $TAILSCALE_IP funktioniert (HTTP-Code: $http_code)."
            
            # Speichere Response-Header für weitere Tests
            curl -k -s -I --connect-timeout 5 "https://$TAILSCALE_IP" > "$TEST_RESULTS_DIR/response_headers.txt" 2>/dev/null || true
        else
            log "ERROR" "HTTPS-Verbindung zu $TAILSCALE_IP fehlgeschlagen."
            test_failed=true
        fi
    fi
    
    # 3.4 Prüfe Redirect zu code-server
    if [ -n "$TAILSCALE_IP" ]; then
        log "STEP" "Prüfe Redirect zu code-server..."
        
        # Teste, ob die Anfrage an code-server weitergeleitet wird
        local response=$(curl -k -s --connect-timeout 5 "https://$TAILSCALE_IP" 2>/dev/null || echo "")
        
        if echo "$response" | grep -qi "code-server\|vscode\|visual studio code"; then
            log "INFO" "Redirect zu code-server funktioniert."
        else
            log "WARN" "Konnte code-server-Antwort nicht verifizieren (code-server läuft möglicherweise nicht)."
        fi
    fi
    
    # 3.5 Prüfe WebSocket-Unterstützung
    log "STEP" "Prüfe WebSocket-Konfiguration..."
    if grep -r "Upgrade\|websocket" "$CADDY_DIR/" > /dev/null 2>&1; then
        log "INFO" "WebSocket-Konfiguration gefunden."
    else
        log "WARN" "WebSocket-Konfiguration nicht explizit gefunden (Caddy unterstützt WebSockets standardmäßig)."
    fi
    
    # 3.6 Prüfe HTTP/2 und HTTP/3 Unterstützung
    if [ -n "$TAILSCALE_IP" ]; then
        log "STEP" "Prüfe HTTP/2-Unterstützung..."
        if curl -k -s -I --http2 --connect-timeout 5 "https://$TAILSCALE_IP" 2>/dev/null | grep -q "HTTP/2"; then
            log "INFO" "HTTP/2 wird unterstützt."
        else
            log "WARN" "HTTP/2-Unterstützung konnte nicht verifiziert werden."
        fi
    fi
    
    if [ "$test_failed" = true ]; then
        return 1
    fi
    
    return 0
}

#######################################
# 4. Test: Sicherheitstests
#######################################

test_security() {
    log "TEST" "Überprüfe Caddy-Sicherheitskonfiguration..."
    
    local test_failed=false
    
    # 4.1 Prüfe Tailscale-Only-Zugriff (Konfiguration)
    log "STEP" "Prüfe Tailscale-Only-Zugriff-Konfiguration..."
    if grep -r "remote_ip.*100\.64\.0\.0/10\|@tailscale" "$CADDY_DIR/" > /dev/null 2>&1; then
        log "INFO" "Tailscale-Only-Zugriff ist konfiguriert (100.64.0.0/10)."
    else
        log "WARN" "Tailscale-Only-Zugriff-Konfiguration nicht gefunden."
    fi
    
    # 4.2 Prüfe TLS/SSL-Konfiguration
    log "STEP" "Prüfe TLS/SSL-Konfiguration..."
    if [ -n "$TAILSCALE_IP" ]; then
        # Teste TLS-Verbindung mit OpenSSL
        local tls_info=$(echo | openssl s_client -connect "$TAILSCALE_IP:443" -servername "$TAILSCALE_IP" 2>/dev/null | grep -E "Protocol|Cipher")
        
        if [ -n "$tls_info" ]; then
            log "INFO" "TLS/SSL-Zertifikat ist aktiv."
            
            if [ "$VERBOSE" = true ]; then
                log "INFO" "TLS-Details:"
                echo "$tls_info" | tee -a "$TEST_LOG_FILE"
            fi
            
            # Prüfe TLS-Version
            if echo "$tls_info" | grep -q "TLSv1.2\|TLSv1.3"; then
                log "INFO" "Sichere TLS-Version wird verwendet (1.2 oder 1.3)."
            else
                log "WARN" "TLS-Version konnte nicht verifiziert werden."
            fi
        else
            log "WARN" "TLS-Informationen konnten nicht abgerufen werden."
        fi
    fi
    
    # 4.3 Prüfe Sicherheits-Header
    log "STEP" "Prüfe Sicherheits-Header..."
    if [ -f "$TEST_RESULTS_DIR/response_headers.txt" ]; then
        local headers_file="$TEST_RESULTS_DIR/response_headers.txt"
        
        # Prüfe HSTS
        if grep -qi "Strict-Transport-Security" "$headers_file"; then
            log "INFO" "HSTS-Header ist gesetzt."
        else
            log "WARN" "HSTS-Header nicht gefunden."
        fi
        
        # Prüfe X-Frame-Options
        if grep -qi "X-Frame-Options" "$headers_file"; then
            log "INFO" "X-Frame-Options-Header ist gesetzt."
        else
            log "WARN" "X-Frame-Options-Header nicht gefunden."
        fi
        
        # Prüfe X-Content-Type-Options
        if grep -qi "X-Content-Type-Options" "$headers_file"; then
            log "INFO" "X-Content-Type-Options-Header ist gesetzt."
        else
            log "WARN" "X-Content-Type-Options-Header nicht gefunden."
        fi
        
        # Prüfe Content-Security-Policy
        if grep -qi "Content-Security-Policy" "$headers_file"; then
            log "INFO" "Content-Security-Policy-Header ist gesetzt."
        else
            log "WARN" "Content-Security-Policy-Header nicht gefunden."
        fi
        
        if [ "$VERBOSE" = true ]; then
            log "INFO" "Alle Response-Header:"
            cat "$headers_file" | tee -a "$TEST_LOG_FILE"
        fi
    else
        log "WARN" "Response-Header konnten nicht analysiert werden (keine Verbindung möglich)."
    fi
    
    # 4.4 Prüfe Admin-API-Status (sollte deaktiviert sein)
    log "STEP" "Prüfe Admin-API-Status..."
    if grep -r "admin off" "$CADDY_DIR/Caddyfile" > /dev/null 2>&1; then
        log "INFO" "Admin-API ist deaktiviert (Sicherheit)."
    else
        log "WARN" "Admin-API-Status konnte nicht verifiziert werden."
    fi
    
    # 4.5 Prüfe Firewall-Regeln (UFW)
    if command -v ufw &> /dev/null; then
        log "STEP" "Prüfe Firewall-Regeln..."
        if ufw status | grep -q "Status: active"; then
            log "INFO" "UFW-Firewall ist aktiv."
            
            # Prüfe, ob Port 443 freigegeben ist
            if ufw status | grep -q "443"; then
                log "INFO" "Port 443 ist in der Firewall freigegeben."
            else
                log "WARN" "Port 443 ist nicht explizit in der Firewall freigegeben."
            fi
        else
            log "WARN" "UFW-Firewall ist nicht aktiv."
        fi
    fi
    
    if [ "$test_failed" = true ]; then
        return 1
    fi
    
    return 0
}

#######################################
# 5. Test: Log-Validierung (KRITISCH!)
#######################################

test_logs() {
    log "TEST" "Überprüfe Caddy-Logs und -Logging-Konfiguration..."
    
    local test_failed=false
    
    # 5.1 Prüfe, ob Caddy-Logs existieren und lesbar sind
    log "STEP" "Prüfe Caddy-Log-Dateien..."
    
    # Prüfe Access-Log
    if [ -f "$CADDY_LOG_DIR/access.log" ]; then
        log "INFO" "Access-Log existiert: $CADDY_LOG_DIR/access.log"
        
        # Prüfe, ob Log-Datei lesbar ist
        if [ -r "$CADDY_LOG_DIR/access.log" ]; then
            log "INFO" "Access-Log ist lesbar."
            
            # Prüfe Log-Größe
            local log_size=$(stat -f%z "$CADDY_LOG_DIR/access.log" 2>/dev/null || stat -c%s "$CADDY_LOG_DIR/access.log" 2>/dev/null)
            log "INFO" "Access-Log-Größe: $log_size Bytes"
        else
            log "WARN" "Access-Log ist nicht lesbar."
        fi
    else
        log "WARN" "Access-Log existiert nicht: $CADDY_LOG_DIR/access.log"
    fi
    
    # Prüfe code-server-Log
    if [ -f "$CADDY_LOG_DIR/code-server.log" ]; then
        log "INFO" "code-server-Log existiert: $CADDY_LOG_DIR/code-server.log"
    else
        log "WARN" "code-server-Log existiert nicht: $CADDY_LOG_DIR/code-server.log"
    fi
    
    # 5.2 Prüfe journalctl-Logs für Caddy
    log "STEP" "Prüfe journalctl-Logs für Caddy..."
    if ! journalctl -u caddy -n 1 &> /dev/null; then
        log "ERROR" "Keine Caddy-Logs in journalctl gefunden."
        test_failed=true
    else
        local log_count=$(journalctl -u caddy --no-pager | wc -l)
        log "INFO" "Gefundene journalctl-Log-Einträge für Caddy: $log_count"
        
        # Speichere die letzten Log-Einträge
        journalctl -u caddy -n 50 --no-pager > "$TEST_RESULTS_DIR/caddy_journalctl.log" 2>&1
        
        # 5.3 Prüfe Logs auf erfolgreichen Start
        log "STEP" "Prüfe Logs auf erfolgreichen Start..."
        if journalctl -u caddy --no-pager | grep -qi "started\|serving\|listening"; then
            log "INFO" "Logs zeigen erfolgreichen Start."
        else
            log "WARN" "Konnte keinen erfolgreichen Start in den Logs finden."
        fi
        
        # 5.4 Prüfe Logs auf kritische Fehler
        log "STEP" "Prüfe Logs auf kritische Fehler..."
        local error_count=$(journalctl -u caddy --no-pager | grep -ci "error\|fatal\|panic" || echo "0")
        
        if [ "$error_count" -eq 0 ]; then
            log "INFO" "Keine kritischen Fehler in den Logs gefunden."
        else
            log "WARN" "Gefundene Fehler in den Logs: $error_count"
            
            if [ "$VERBOSE" = true ]; then
                log "INFO" "Fehler-Einträge:"
                journalctl -u caddy --no-pager | grep -i "error\|fatal\|panic" | tail -n 10 | tee -a "$TEST_LOG_FILE"
            fi
        fi
        
        # 5.5 Prüfe auf Warnungen
        local warn_count=$(journalctl -u caddy --no-pager | grep -ci "warn" || echo "0")
        
        if [ "$warn_count" -eq 0 ]; then
            log "INFO" "Keine Warnungen in den Logs gefunden."
        else
            log "INFO" "Gefundene Warnungen in den Logs: $warn_count"
        fi
        
        # 5.6 Zeige letzte Log-Einträge
        if [ "$VERBOSE" = true ]; then
            log "INFO" "Letzte 20 Log-Einträge:"
            journalctl -u caddy -n 20 --no-pager | tee -a "$TEST_LOG_FILE"
        fi
    fi
    
    # 5.7 Prüfe Access-Logs funktionieren
    log "STEP" "Prüfe ob Access-Logs funktionieren..."
    if [ -f "$CADDY_LOG_DIR/access.log" ]; then
        # Prüfe, ob Log-Datei in den letzten 24 Stunden modifiziert wurde
        if [ -n "$(find "$CADDY_LOG_DIR/access.log" -mtime -1 2>/dev/null)" ]; then
            log "INFO" "Access-Log wurde kürzlich aktualisiert."
        else
            log "WARN" "Access-Log wurde seit mehr als 24 Stunden nicht aktualisiert."
        fi
    fi
    
    # 5.8 Prüfe Log-Rotation-Konfiguration
    log "STEP" "Prüfe Log-Rotation-Konfiguration..."
    if grep -r "roll_size\|roll_keep" "$CADDY_DIR/" > /dev/null 2>&1; then
        log "INFO" "Log-Rotation ist konfiguriert."
    else
        log "WARN" "Log-Rotation-Konfiguration nicht gefunden."
    fi
    
    if [ "$test_failed" = true ]; then
        return 1
    fi
    
    return 0
}

#######################################
# 6. Test: Integration mit code-server
#######################################

test_integration() {
    log "TEST" "Überprüfe Integration mit code-server..."
    
    local test_failed=false
    
    # 6.1 Prüfe, ob code-server auf dem konfigurierten Port läuft
    log "STEP" "Prüfe ob code-server auf Port $CODE_SERVER_PORT läuft..."
    if nc -z localhost "$CODE_SERVER_PORT" 2>/dev/null || timeout 2 bash -c "echo > /dev/tcp/localhost/$CODE_SERVER_PORT" 2>/dev/null; then
        log "INFO" "code-server ist auf Port $CODE_SERVER_PORT erreichbar."
    else
        log "WARN" "code-server ist nicht auf Port $CODE_SERVER_PORT erreichbar."
        log "WARN" "Integration kann nicht vollständig getestet werden."
    fi
    
    # 6.2 Prüfe, ob code-server über Caddy erreichbar ist
    if [ -n "$TAILSCALE_IP" ]; then
        log "STEP" "Prüfe ob code-server über Caddy erreichbar ist..."
        
        local response=$(curl -k -s --connect-timeout 5 "https://$TAILSCALE_IP" 2>/dev/null || echo "")
        
        if [ -n "$response" ]; then
            log "INFO" "code-server ist über Caddy erreichbar."
            
            # Prüfe, ob die Antwort von code-server kommt
            if echo "$response" | grep -qi "code-server\|vscode\|visual studio code"; then
                log "INFO" "Response kommt von code-server."
            else
                log "WARN" "Response-Inhalt konnte nicht als code-server identifiziert werden."
            fi
        else
            log "WARN" "Keine Response von code-server über Caddy erhalten."
        fi
    fi
    
    # 6.3 Prüfe HTTP-Anfragen werden korrekt weitergeleitet
    if [ -n "$TAILSCALE_IP" ]; then
        log "STEP" "Prüfe HTTP-Weiterleitung..."
        
        # Teste verschiedene Pfade
        local paths=("/" "/healthz" "/login")
        
        for path in "${paths[@]}"; do
            local http_code=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "https://$TAILSCALE_IP$path" 2>/dev/null || echo "000")
            
            if [ "$http_code" != "000" ]; then
                log "INFO" "Pfad $path ist erreichbar (HTTP-Code: $http_code)."
            else
                log "WARN" "Pfad $path ist nicht erreichbar."
            fi
        done
    fi
    
    # 6.4 Prüfe Response-Header sind korrekt
    if [ -f "$TEST_RESULTS_DIR/response_headers.txt" ]; then
        log "STEP" "Prüfe Response-Header..."
        
        # Prüfe, ob wichtige Header vorhanden sind
        if grep -qi "X-Forwarded-For\|X-Real-IP" "$TEST_RESULTS_DIR/response_headers.txt"; then
            log "INFO" "Proxy-Header sind gesetzt."
        else
            log "WARN" "Proxy-Header nicht gefunden (kann normal sein)."
        fi
    fi
    
    # 6.5 Prüfe WebSocket-Unterstützung für code-server
    log "STEP" "Prüfe WebSocket-Unterstützung..."
    if grep -r "header_up.*Upgrade\|header_up.*Connection" "$CADDY_DIR/" > /dev/null 2>&1; then
        log "INFO" "WebSocket-Header sind konfiguriert."
    else
        log "WARN" "WebSocket-Header-Konfiguration nicht gefunden."
    fi
    
    # 6.6 Prüfe Timeout-Konfiguration für lange Sessions
    log "STEP" "Prüfe Timeout-Konfiguration..."
    if grep -r "read_timeout\|write_timeout\|keepalive" "$CADDY_DIR/" > /dev/null 2>&1; then
        log "INFO" "Timeout-Konfiguration gefunden."
    else
        log "WARN" "Timeout-Konfiguration nicht gefunden."
    fi
    
    if [ "$test_failed" = true ]; then
        return 1
    fi
    
    return 0
}

#######################################
# Hauptfunktion
#######################################

main() {
    log "TEST" "==== Starte Caddy E2E-Tests ===="
    
    # Initialisierung
    init_test_env
    parse_args "$@"
    
    # Tailscale-Informationen ermitteln
    get_tailscale_info || log "WARN" "Tailscale-Informationen konnten nicht vollständig ermittelt werden."
    
    # Führe Tests durch
    run_test "service" test_service
    run_test "config" test_config
    run_test "network" test_network
    run_test "security" test_security
    run_test "logs" test_logs
    run_test "integration" test_integration
    
    # Zeige Testergebnisse
    show_test_results
    
    # Kopiere Log-Datei zum finalen Speicherort
    if [ -f "$TEST_LOG_FILE" ]; then
        cp "$TEST_LOG_FILE" "$FINAL_LOG_FILE" 2>/dev/null || true
        log "INFO" "Finale Log-Datei: $FINAL_LOG_FILE"
    fi
    
    log "TEST" "==== Caddy E2E-Tests abgeschlossen ===="
    
    # Exit-Code basierend auf Testergebnissen
    if [ $FAILED_TESTS -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Skript ausführen
main "$@"