#!/bin/bash
#
# test-code-server-tailscale.sh - Tests für Code-Server und Tailscale Integration
#
# Dieses Skript testet die Integration zwischen Code-Server und Tailscale,
# überprüft die Tailscale-Verbindung und testet den Zugriff auf Code-Server
# über das Tailscale-Netzwerk.
#
# Implementierte Testfunktionen:
# - Prüfung des Tailscale-Status und der Konfiguration
# - Überprüfung der Tailscale-Netzwerkschnittstelle
# - Tests für die Zugänglichkeit von Code-Server über Tailscale
# - Authentifizierungstests über Tailscale
# - Kompatibilitätstests mit verschiedenen Tailscale-Konfigurationen
# - MagicDNS-Funktionalitätsüberprüfung
# - Robustheitstests für verschiedene Fehlerszenarien
#
# Version: 1.2
# Autor: DevSystem Team
# Datum: 2026-04-12
# Teil von: GitHub Issue #18 - Automatisierte E2E-Tests
#
# Verwendung: bash test-code-server-tailscale.sh [--verbose] [--auth-mode=AUTHMODE]
#             AUTHMODE Optionen: sso (Standard), key, disabled
#             --timeout=SECONDS Zeitlimit für bestimmte Tests setzen
#

# Fehler bei der Ausführung beenden das Skript
set -e

# Konfigurationsoptionen
VERBOSE=false
TEST_RESULTS_DIR="/tmp/code-server-e2e-test-results"
TAILSCALE_TEST_LOG="$TEST_RESULTS_DIR/tailscale-test.log"
AUTH_MODE="sso"  # sso (Standard), key, disabled
TEST_TIMEOUT=10  # Sekunden
TEST_ENV_DIR="/tmp/code-server-test-env"

# Timeout-Handler
TIMEOUT_CMD=""
if command -v timeout &> /dev/null; then
    TIMEOUT_CMD="timeout"
elif command -v gtimeout &> /dev/null; then
    TIMEOUT_CMD="gtimeout"
fi

# code-server-Konfiguration
CODE_SERVER_PORT="8080"
CADDY_PORT="9443"
TAILSCALE_IP=""
TAILSCALE_HOSTNAME=""
TAILSCALE_MAGICNAME=""

# Prüfe, ob Konfiguration aus der Testumgebung geladen werden kann
if [ -f "$TEST_ENV_DIR/code_server_port.txt" ]; then
    CODE_SERVER_PORT=$(cat "$TEST_ENV_DIR/code_server_port.txt")
fi

if [ -f "$TEST_ENV_DIR/tailscale_ip.txt" ]; then
    TAILSCALE_IP=$(cat "$TEST_ENV_DIR/tailscale_ip.txt")
fi

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
    
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [TAILSCALE] [$level] $message${NC}" | tee -a "$TAILSCALE_TEST_LOG"
}

# ============================================================================
# HILFSFUNKTIONEN
# ============================================================================

# Initialisierung der Testumgebung
init_test_env() {
    mkdir -p "$TEST_RESULTS_DIR"
    > "$TAILSCALE_TEST_LOG"
    
    log "INFO" "Initialisiere Tailscale-Testumgebung..."
}

# Funktion zum Parsen der Kommandozeilenargumente
parse_args() {
    for arg in "$@"; do
        case $arg in
            --verbose)
                VERBOSE=true
                ;;
            --auth-mode=*)
                AUTH_MODE="${arg#*=}"
                ;;
            --timeout=*)
                TEST_TIMEOUT="${arg#*=}"
                ;;
            --help)
                echo "Verwendung: bash test-code-server-tailscale.sh [--verbose] [--auth-mode=AUTHMODE] [--timeout=SECONDS]"
                echo ""
                echo "Optionen:"
                echo "  --verbose             Ausführliche Ausgabe aktivieren"
                echo "  --auth-mode=AUTHMODE  Authentifizierungsmodus für Tests (sso, key, disabled)"
                echo "  --timeout=SECONDS     Zeitlimit für Tests in Sekunden (Standard: 10)"
                echo "  --help                Diese Hilfe anzeigen"
                echo ""
                exit 0
                ;;
        esac
    done
    
    if [ "$VERBOSE" = true ]; then
        log "INFO" "Ausführliche Ausgabe aktiviert."
    fi
    
    log "INFO" "Authentifizierungsmodus: $AUTH_MODE"
    log "INFO" "Test-Timeout: $TEST_TIMEOUT Sekunden"
}

# Funktion zur Ausführung eines Kommandos mit Timeout
run_with_timeout() {
    local cmd="$1"
    local timeout_seconds="$2"
    local description="$3"
    local result=0
    
    if [ -z "$TIMEOUT_CMD" ]; then
        log "WARN" "Timeout-Befehl nicht verfügbar, führe Befehl ohne Timeout aus: $description"
        eval "$cmd"
        result=$?
    else
        log "STEP" "Führe Befehl mit Timeout $timeout_seconds Sekunden aus: $description"
        $TIMEOUT_CMD $timeout_seconds bash -c "$cmd" 2>/dev/null
        result=$?
        if [ $result -eq 124 ]; then
            log "WARN" "Timeout nach $timeout_seconds Sekunden für: $description"
        fi
    fi
    
    return $result
}

# Funktion zum Ausführen eines Tests
run_test() {
    local test_name=$1
    local test_function=$2
    
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
    log "TEST" "====== Tailscale-Testergebnisse ======"
    log "INFO" "Durchgeführte Tests: $TOTAL_TESTS"
    log "INFO" "Erfolgreiche Tests: $PASSED_TESTS"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        log "INFO" "Fehlgeschlagene Tests: $FAILED_TESTS"
        log "INFO" "Alle Tailscale-Tests wurden erfolgreich abgeschlossen!"
    else
        log "ERROR" "Fehlgeschlagene Tests: $FAILED_TESTS"
        log "ERROR" "Einige Tailscale-Tests sind fehlgeschlagen. Überprüfen Sie die Logs für Details: $TAILSCALE_TEST_LOG"
    fi
    
    echo ""
}

# Ermittlung der Tailscale-Informationen
get_tailscale_info() {
    log "STEP" "Ermittle Tailscale-Informationen..."
    
    if ! command -v tailscale &> /dev/null; then
        log "ERROR" "Tailscale ist nicht installiert."
        return 1
    fi
    
    # Wenn wir bereits eine Tailscale-IP aus der Testumgebung haben, verwenden wir diese
    if [ -z "$TAILSCALE_IP" ]; then
        TAILSCALE_IP=$(tailscale ip -4 2>/dev/null | head -n1 || echo "")
    fi
    
    if [ -z "$TAILSCALE_IP" ]; then
        log "ERROR" "Konnte Tailscale-IP nicht ermitteln."
        return 1
    fi
    
    log "INFO" "Tailscale-IP: $TAILSCALE_IP"
    
    # Erweiterte Informationen abrufen
    local tailscale_status=$(tailscale status --json 2>/dev/null || echo "{}")
    
    # Hostname und MagicDNS-Namen ermitteln, wenn jq verfügbar ist
    if command -v jq &> /dev/null && [ -n "$tailscale_status" ] && [[ "$tailscale_status" != "{}" ]]; then
        TAILSCALE_HOSTNAME=$(echo "$tailscale_status" | jq -r '.Self.HostName' 2>/dev/null || echo "")
        local dns_suffix=$(echo "$tailscale_status" | jq -r '.MagicDNSSuffix' 2>/dev/null || echo "")
        
        if [ -n "$TAILSCALE_HOSTNAME" ] && [ -n "$dns_suffix" ] && [ "$TAILSCALE_HOSTNAME" != "null" ] && [ "$dns_suffix" != "null" ]; then
            TAILSCALE_MAGICNAME="${TAILSCALE_HOSTNAME}.${dns_suffix}"
            log "INFO" "Tailscale-Hostname: $TAILSCALE_HOSTNAME"
            log "INFO" "Tailscale-MagicDNS: $TAILSCALE_MAGICNAME"
        fi
    else
        # Fallback ohne jq
        TAILSCALE_HOSTNAME=$(hostname)
        log "INFO" "Hostname (nicht aus Tailscale): $TAILSCALE_HOSTNAME"
        log "WARN" "Konnte MagicDNS-Namen nicht ermitteln (jq nicht verfügbar oder kein gültiger Status)."
    fi
    
    if [ "$VERBOSE" = true ]; then
        log "INFO" "Tailscale-Status:"
        tailscale status
        
        if [ -n "$tailscale_status" ] && [[ "$tailscale_status" != "{}" ]]; then
            log "INFO" "Tailscale-Status Details:"
            if command -v jq &> /dev/null; then
                echo "$tailscale_status" | jq .
            else
                echo "$tailscale_status" | grep -v "\"" | head -n 15
            fi
        fi
    fi
    
    return 0
}

#######################################
# 1. Test: Tailscale-Status
#######################################

test_tailscale_status() {
    log "TEST" "Überprüfe Tailscale-Status..."
    
    local test_failed=false
    
    if ! command -v tailscale &> /dev/null; then
        log "ERROR" "Tailscale ist nicht installiert."
        return 1
    else
        log "INFO" "Tailscale-Befehl ist verfügbar."
    fi
    
    local tailscale_version=$(tailscale version 2>&1 | head -n1)
    log "INFO" "Tailscale-Version: $tailscale_version"
    
    # Prüfe, ob Tailscale-Dienst läuft
    if ! pgrep -x "tailscaled" > /dev/null; then
        log "ERROR" "Tailscale-Daemon (tailscaled) läuft nicht."
        test_failed=true
    else
        log "INFO" "Tailscale-Daemon (tailscaled) läuft."
        local tailscaled_pid=$(pgrep -x "tailscaled" | head -n1)
        log "INFO" "Tailscale-PID: $tailscaled_pid"
    fi
    
    # Prüfe Tailscale-Status
    if ! tailscale status --json > /dev/null 2>&1; then
        log "ERROR" "Tailscale-Status konnte nicht abgerufen werden."
        test_failed=true
    else
        log "INFO" "Tailscale-Status konnte erfolgreich abgerufen werden."
        
        # Prüfe, ob Tailscale verbunden ist
        if tailscale status | grep -q "Stopped\|Disconnected"; then
            log "ERROR" "Tailscale ist nicht verbunden."
            test_failed=true
        else
            log "INFO" "Tailscale ist verbunden."
        fi
    fi
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# 2. Test: Tailscale-Netzwerk
#######################################

test_tailscale_network() {
    log "TEST" "Überprüfe Tailscale-Netzwerk..."
    
    local test_failed=false
    
    # Prüfe, ob Tailscale-Interface existiert
        local interface_cmd="ip -o link"
        if ! command -v ip &> /dev/null; then
            # Fallback für Systeme ohne ip-Befehl
            if command -v ifconfig &> /dev/null; then
                interface_cmd="ifconfig -a"
                log "INFO" "Verwende ifconfig statt ip-Befehl."
            else
                log "WARN" "Weder ip noch ifconfig verfügbar. Netzwerkschnittstellenprüfung eingeschränkt."
                interface_cmd="ls -la /sys/class/net/ 2>/dev/null || echo 'Keine Netzwerkinformationen verfügbar'"
            fi
        fi
        
        local tailscale_interface=""
        if command -v ip &> /dev/null; then
            # Moderne Systeme mit ip-Befehl
            tailscale_interface=$(ip -o link | grep -v "br-" | grep -v "docker" | grep -v "veth" | grep -E "tailscale|ts" | cut -d':' -f2 | tr -d ' ' || echo "")
        elif command -v ifconfig &> /dev/null; then
            # Ältere Systeme mit ifconfig
            tailscale_interface=$(ifconfig -a | grep -E "tailscale|ts" | cut -d':' -f1 | head -n1 || echo "")
        else
            # Absolute Fallback-Lösung
            tailscale_interface=$(ls -la /sys/class/net/ 2>/dev/null | grep -E "tailscale|ts" | awk '{print $9}' | head -n1 || echo "")
        fi
        
        if [ -z "$tailscale_interface" ]; then
            log "ERROR" "Tailscale-Netzwerkinterface wurde nicht gefunden."
            if [ "$VERBOSE" = true ]; then
                log "INFO" "Verfügbare Netzwerkinterfaces:"
                eval "$interface_cmd"
            fi
            test_failed=true
        else
            log "INFO" "Tailscale-Netzwerkinterface gefunden: $tailscale_interface"
            
            # Detaillierte Schnittstellen-Informationen
            if command -v ethtool &> /dev/null && [ "$VERBOSE" = true ]; then
                log "INFO" "Tailscale-Interface Details:"
                ethtool "$tailscale_interface" 2>/dev/null || true
            fi
        fi
    
    # Prüfe, ob Tailscale-Interface eine IP hat
    if [ -n "$tailscale_interface" ]; then
        local interface_ip=$(ip -o addr show dev $tailscale_interface | grep -v "scope link" | grep "scope global" | grep -oE 'inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut -d' ' -f2 || echo "")
        
        if [ -z "$interface_ip" ]; then
            log "ERROR" "Keine gültige IP-Adresse für Tailscale-Interface gefunden."
            test_failed=true
        else
            log "INFO" "Tailscale-Interface-IP: $interface_ip"
        fi
    fi
    
    # Prüfe ping zu einem anderen Tailscale-Host (wenn konfiguriert)
    if [ -n "$TAILSCALE_TEST_HOST" ]; then
        log "STEP" "Prüfe Konnektivität zu Tailscale-Test-Host: $TAILSCALE_TEST_HOST"
        
        if ping -c 3 -W 2 "$TAILSCALE_TEST_HOST" > /dev/null 2>&1; then
            log "INFO" "Ping zu Tailscale-Test-Host erfolgreich."
        else
            log "WARN" "Ping zu Tailscale-Test-Host fehlgeschlagen."
            # Setze nicht auf test_failed=true, da Ping blockiert sein könnte
        fi
    fi
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# 3. Test: Code-Server über Tailscale
#######################################

test_code_server_access() {
    log "TEST" "Überprüfe Code-Server-Zugriff über Tailscale..."
    
    local test_failed=false
    
    if [ -z "$TAILSCALE_IP" ]; then
        log "ERROR" "Tailscale-IP nicht verfügbar. Überspringe Code-Server-Zugriffstests."
        return 1
    fi
    
    log "STEP" "Prüfe direkten Zugriff auf Code-Server über Tailscale..."
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://$TAILSCALE_IP:$CODE_SERVER_PORT" 2>/dev/null || echo "000")
    
    if [ "$http_code" != "000" ]; then
        log "WARN" "Code-Server ist direkt über Tailscale erreichbar ohne Caddy: $http_code"
        log "WARN" "Dies könnte ein Sicherheitsrisiko darstellen, wenn Code-Server nicht auf localhost beschränkt ist."
    else
        log "INFO" "Code-Server ist korrekt konfiguriert und nicht direkt über Tailscale erreichbar."
    fi
    
    log "STEP" "Prüfe Code-Server über Caddy Reverse Proxy und Tailscale..."
    local https_code=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "https://$TAILSCALE_IP:$CADDY_PORT" 2>/dev/null || echo "000")
    
    if [ "$https_code" != "000" ]; then
        log "INFO" "Code-Server ist über Caddy und Tailscale erreichbar (HTTP-Code: $https_code)"
        
        if [ "$https_code" -eq 200 ] || [ "$https_code" -eq 302 ]; then
            log "INFO" "Erfolgreiche Verbindung zu Code-Server über Tailscale (HTTP-Code: $https_code)"
        else
            log "WARN" "Unerwarteter HTTP-Code bei Zugriff auf Code-Server: $https_code"
            test_failed=true
        fi
        
        # Hole Response-Headers für weitere Analyse
        curl -k -s -I --connect-timeout 5 "https://$TAILSCALE_IP:$CADDY_PORT" > "$TEST_RESULTS_DIR/tailscale_response_headers.txt" 2>/dev/null || true
        
        if [ "$VERBOSE" = true ] && [ -f "$TEST_RESULTS_DIR/tailscale_response_headers.txt" ]; then
            log "INFO" "Response-Headers:"
            cat "$TEST_RESULTS_DIR/tailscale_response_headers.txt" | tee -a "$TAILSCALE_TEST_LOG"
        fi
    else
        log "ERROR" "Code-Server ist über Caddy und Tailscale nicht erreichbar."
        test_failed=true
    fi
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# 4. Test: Tailscale-Zugriffskontrolle
#######################################

test_tailscale_access_control() {
    log "TEST" "Überprüfe Tailscale-Zugriffskontrolle..."
    
    local test_failed=false
    
    # Prüfe, ob Tailscale ACLs konfiguriert sind
    local acl_configured=false
    
    if command -v jq &> /dev/null; then
        # Mit jq können wir präziser nach ACLs suchen
        if tailscale status --json 2>/dev/null | jq -e '.UserProfiles != null' &>/dev/null; then
            log "INFO" "Tailscale ACLs sind konfiguriert (UserProfiles gefunden)."
            
            # Extrahiere Benutzerprofile für detailliertere Überprüfung
            local user_profiles=$(tailscale status --json 2>/dev/null | jq -r '.UserProfiles | keys[]' 2>/dev/null)
            if [ -n "$user_profiles" ]; then
                log "INFO" "Konfigurierte Benutzerprofile: $(echo "$user_profiles" | tr '\n' ',' | sed 's/,$//g')"
            fi
            
            acl_configured=true
        fi
    else
        # Fallback ohne jq
        if tailscale status 2>/dev/null | grep -q "ACLs"; then
            log "INFO" "Tailscale ACLs scheinen konfiguriert zu sein."
            acl_configured=true
        fi
    fi
    
    if [ "$acl_configured" = false ]; then
        log "WARN" "Konnte Tailscale ACL-Konfiguration nicht bestätigen."
    fi
    
    # Prüfe, ob Zugriff nur über bestimmte IPs möglich ist
    if [ -n "$TAILSCALE_IP" ]; then
        log "STEP" "Prüfe Zugriffssteuerung auf Firewall-Ebene..."
        
        # Test für HTTP-Request über Caddy mit Auth-Header
        local https_code=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "https://$TAILSCALE_IP:$CADDY_PORT" -H "X-Test-Auth: TailscaleTest" 2>/dev/null || echo "000")
        
        if [ "$https_code" != "000" ]; then
            log "INFO" "Zugriff mit Auth-Header: HTTP-Code $https_code"
            
            # Prüfe Antwort von Server basieren auf Auth-Mode
            if [ "$AUTH_MODE" = "sso" ] || [ "$AUTH_MODE" = "key" ]; then
                if [ "$https_code" -eq 200 ] || [ "$https_code" -eq 302 ]; then
                    log "INFO" "Zugriffssteuerung verhält sich wie erwartet für Modus '$AUTH_MODE'"
                else
                    log "WARN" "Unerwarteter HTTP-Code $https_code für Modus '$AUTH_MODE'"
                    test_failed=true
                fi
            elif [ "$AUTH_MODE" = "disabled" ]; then
                if [ "$https_code" -eq 401 ] || [ "$https_code" -eq 403 ] || [ "$https_code" -eq 302 ]; then
                    log "WARN" "Zugriffssteuerung ist aktiv, obwohl Modus 'disabled' ist"
                    test_failed=true
                else
                    log "INFO" "Zugriffssteuerung verhält sich wie erwartet für Modus 'disabled'"
                fi
            fi
        else
            log "WARN" "Konnte keine Verbindung für Zugriffssteuerungstest herstellen"
        fi
    fi
    
    # Zusätzlicher Test: Prüfe Tailscale-Node-Key (wenn verfügbar)
    if command -v tailscale &> /dev/null && command -v jq &> /dev/null; then
        log "STEP" "Prüfe Tailscale-Node-Schlüssel und Autorisierungsstatus..."
        
        local node_key=$(tailscale status --json 2>/dev/null | jq -r '.Self.ID' 2>/dev/null || echo "")
        
        if [ -n "$node_key" ] && [ "$node_key" != "null" ]; then
            log "INFO" "Tailscale-Node-Schlüssel gefunden: ${node_key:0:8}...${node_key: -8}"
            
            # Prüfe, ob dieser Knoten autorisiert ist
            local is_authorized=$(tailscale status --json 2>/dev/null | jq -r '.Self.Approved' 2>/dev/null || echo "")
            
            if [ "$is_authorized" = "true" ]; then
                log "INFO" "Tailscale-Knoten ist autorisiert"
            elif [ "$is_authorized" = "false" ]; then
                log "WARN" "Tailscale-Knoten ist NICHT autorisiert - ACLs erlauben möglicherweise keinen Zugriff"
                test_failed=true
            else
                log "WARN" "Konnte Autorisierungsstatus nicht ermitteln"
            fi
        else
            log "WARN" "Konnte Tailscale-Node-Schlüssel nicht ermitteln"
        fi
    fi
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# 5. Test: MagicDNS-Funktionalität
#######################################

test_magicdns_functionality() {
    log "TEST" "Überprüfe Tailscale MagicDNS-Funktionalität..."
    
    local test_failed=false
    
    # Nur ausführen, wenn MagicDNS-Name ermittelt wurde
    if [ -z "$TAILSCALE_MAGICNAME" ]; then
        log "WARN" "Kein MagicDNS-Name verfügbar. Überspringe MagicDNS-Tests."
        return 0
    fi
    
    log "STEP" "Prüfe DNS-Auflösung für MagicDNS-Namen: $TAILSCALE_MAGICNAME"
    
    # Prüfe DNS-Auflösung des MagicDNS-Namens
    local dns_result=""
    
    # Versuche mit dig
    if command -v dig &> /dev/null; then
        dns_result=$(dig +short "$TAILSCALE_MAGICNAME" 2>/dev/null || echo "")
    # Fallback auf nslookup
    elif command -v nslookup &> /dev/null; then
        dns_result=$(nslookup "$TAILSCALE_MAGICNAME" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "")
    # Fallback auf getent
    elif command -v getent &> /dev/null; then
        dns_result=$(getent hosts "$TAILSCALE_MAGICNAME" 2>/dev/null | awk '{print $1}' || echo "")
    # Absoluter Fallback mit ping (nicht ideal)
    else
        log "WARN" "Keine DNS-Tools verfügbar (dig/nslookup/getent). Verwende ping als Fallback."
        dns_result=$(ping -c 1 -W 2 "$TAILSCALE_MAGICNAME" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "")
    fi
    
    if [ -n "$dns_result" ]; then
        log "INFO" "MagicDNS-Auflösung erfolgreich: $TAILSCALE_MAGICNAME -> $dns_result"
        
        # Prüfe, ob die aufgelöste IP mit der Tailscale-IP übereinstimmt
        if [ "$dns_result" = "$TAILSCALE_IP" ]; then
            log "INFO" "Aufgelöste IP stimmt mit Tailscale-IP überein."
        else
            log "WARN" "Aufgelöste IP ($dns_result) stimmt nicht mit Tailscale-IP ($TAILSCALE_IP) überein."
            test_failed=true
        fi
        
        # Teste HTTP-Zugriff über MagicDNS
        log "STEP" "Prüfe HTTP(S)-Zugriff über MagicDNS-Namen..."
        
        local magic_https_code=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "https://$TAILSCALE_MAGICNAME:$CADDY_PORT" 2>/dev/null || echo "000")
        
        if [ "$magic_https_code" != "000" ]; then
            log "INFO" "HTTP-Zugriff über MagicDNS erfolgreich (HTTP-Code: $magic_https_code)"
        else
            log "WARN" "HTTP-Zugriff über MagicDNS fehlgeschlagen."
            test_failed=true
        fi
    else
        log "WARN" "MagicDNS-Auflösung fehlgeschlagen für: $TAILSCALE_MAGICNAME"
        test_failed=true
    fi
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# 6. Test: Robustheit und Fehlerfälle
#######################################

test_robustness() {
    log "TEST" "Überprüfe Robustheit der Tailscale-Integration..."
    
    local test_failed=false
    
    # 1. Teste Verbindungsabbruch-Szenario durch schnelles Timeout
    log "STEP" "Teste Verbindungsabbruch-Szenario..."
    
    local short_timeout=1
    local conn_abort_cmd="curl -k -s -o /dev/null -w '%{http_code}' --connect-timeout $short_timeout 'https://$TAILSCALE_IP:$CADDY_PORT/path/that/likely/does/not/exist'"
    
    run_with_timeout "$conn_abort_cmd" "$short_timeout" "Verbindungsabbruch-Test"
    
    # 2. Teste hohe Latenz durch absichtliche Verzögerung
    log "STEP" "Teste Verhalten bei hoher Latenz..."
    
    # Erzeuge künstliche Latenz durch Sleep vor der Anfrage
    local latency_cmd="sleep 2 && curl -k -s -o /dev/null -w '%{time_total}s - %{http_code}' --connect-timeout 5 'https://$TAILSCALE_IP:$CADDY_PORT'"
    
    local latency_result
    latency_result=$(run_with_timeout "$latency_cmd" "7" "Latenztest" 2>/dev/null || echo "Timeout")
    
    if [[ "$latency_result" != "Timeout" ]] && [[ "$latency_result" =~ [0-9]+\.[0-9]+s ]]; then
        log "INFO" "Latenztest abgeschlossen: $latency_result"
    else
        log "WARN" "Latenztest unterbrochen oder fehlgeschlagen."
    fi
    
    # 3. Teste Fehlerfall mit ungültigem Port
    log "STEP" "Teste Verbindung zu ungültigem Port..."
    
    local invalid_port=1
    if [ "$CADDY_PORT" -eq 1 ]; then
        invalid_port=2  # Fallback, falls CADDY_PORT tatsächlich 1 ist
    fi
    
    local invalid_port_cmd="curl -k -s -o /dev/null -w '%{http_code}' --connect-timeout 3 'https://$TAILSCALE_IP:$invalid_port'"
    
    run_with_timeout "$invalid_port_cmd" "3" "Ungültiger Port Test"
    
    log "INFO" "Robustheitstests abgeschlossen."
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# 7. Test: Authentifizierung
#######################################

test_authentication() {
    log "TEST" "Überprüfe Tailscale-Authentifizierung..."
    
    local test_failed=false
    
    log "STEP" "Prüfe Authentifizierungsmodus: $AUTH_MODE"
    
    # Test für verschiedene Auth-Modi
    case "$AUTH_MODE" in
        "sso")
            log "STEP" "Prüfe SSO-Authentifizierung mit Tailscale..."
            
            # Teste, ob Authentifizierungsheader durchgereicht werden
            local auth_header="X-Forwarded-User: testuser@example.com"
            local auth_test=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 5 \
                            -H "$auth_header" \
                            "https://$TAILSCALE_IP:$CADDY_PORT" 2>/dev/null || echo "000")
            
            if [ "$auth_test" != "000" ] && [ "$auth_test" != "401" ] && [ "$auth_test" != "403" ]; then
                log "INFO" "SSO-Authentifizierung scheint zu funktionieren (HTTP-Code: $auth_test)"
            else
                log "WARN" "SSO-Authentifizierung könnte fehlschlagen (HTTP-Code: $auth_test)"
                test_failed=true
            fi
            ;;
            
        "key")
            log "STEP" "Prüfe Schlüssel-basierte Authentifizierung mit Tailscale..."
            
            # Teste mit einem simulierten API-Key-Header
            local key_header="Authorization: Bearer TEST_TAILSCALE_KEY"
            local key_test=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 5 \
                           -H "$key_header" \
                           "https://$TAILSCALE_IP:$CADDY_PORT" 2>/dev/null || echo "000")
            
            if [ "$key_test" != "000" ]; then
                log "INFO" "Schlüssel-basierte Authentifizierung Test: HTTP-Code $key_test"
            else
                log "WARN" "Schlüssel-basierter Auth-Test fehlgeschlagen"
                test_failed=true
            fi
            ;;
            
        "disabled")
            log "STEP" "Prüfe deaktivierte Authentifizierung mit Tailscale..."
            
            # Teste ohne Authentifizierungsheader
            local no_auth_test=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 5 \
                               "https://$TAILSCALE_IP:$CADDY_PORT" 2>/dev/null || echo "000")
            
            if [ "$no_auth_test" != "000" ] && [ "$no_auth_test" != "401" ] && [ "$no_auth_test" != "403" ]; then
                log "INFO" "Zugriff ohne Authentifizierung erfolgreich (HTTP-Code: $no_auth_test)"
            else
                log "WARN" "Zugriff ohne Authentifizierung fehlgeschlagen (HTTP-Code: $no_auth_test)"
                # Bei deaktivierter Auth ist dies möglicherweise ein Fehler
                if [ "$no_auth_test" = "401" ] || [ "$no_auth_test" = "403" ]; then
                    log "WARN" "Authentifizierung scheint aktiviert zu sein, obwohl Modus 'disabled' ist."
                    test_failed=true
                fi
            fi
            ;;
            
        *)
            log "ERROR" "Unbekannter Authentifizierungsmodus: $AUTH_MODE"
            test_failed=true
            ;;
    esac
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# Hauptfunktion
#######################################

main() {
    log "TEST" "==== Starte Code-Server Tailscale-Tests ===="
    
    init_test_env
    parse_args "$@"
    
    # Versuche, Tailscale-Informationen zu ermitteln
    get_tailscale_info || {
        log "WARN" "Konnte Tailscale-Informationen nicht vollständig ermitteln. Einige Tests werden eingeschränkt sein."
        # Wir brechen nicht sofort ab, um robuster zu sein und zumindest teilweise Tests durchführen zu können
    }
    
    # Führe Tests in logischer Reihenfolge aus
    run_test "tailscale-status" test_tailscale_status
    run_test "tailscale-network" test_tailscale_network
    run_test "code-server-access" test_code_server_access
    run_test "access-control" test_tailscale_access_control
    
    # Erweiterte Tests
    if [ -n "$TAILSCALE_MAGICNAME" ]; then
        run_test "magicdns-functionality" test_magicdns_functionality
    else
        log "WARN" "Überspringe MagicDNS-Tests (kein MagicDNS-Name verfügbar)"
    fi
    
    run_test "authentication" test_authentication
    run_test "robustness" test_robustness
    
    # Zeige Ergebnisse
    show_test_results
    
    # Exportiere Testergebnisse für andere Skripte
    echo "$TOTAL_TESTS:$PASSED_TESTS:$FAILED_TESTS" > "$TEST_RESULTS_DIR/tailscale-test-summary.txt"
    
    log "TEST" "==== Code-Server Tailscale-Tests abgeschlossen ===="
    
    if [ $FAILED_TESTS -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"