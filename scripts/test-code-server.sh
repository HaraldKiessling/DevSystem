#!/bin/bash
#
# code-server E2E-Testskript für DevSystem
# Dieses Skript führt umfassende Tests für die code-server-Installation und -Konfiguration durch
#
# Version: 1.0
# Autor: DevSystem Team
# Datum: 2026-04-09
#
# Funktionen:
# - Service-Status-Tests (systemctl, Prozess-Status, User-Kontext)
# - Konfigurationstests (config.yaml, Passwort, Berechtigungen)
# - Netzwerk-Tests (Port 8080, HTTP-Verbindung, WebSocket)
# - Extension-Tests (Installation, Aktivierung als User)
# - Workspace-Tests (Verzeichnisse, settings.json)
# - Integration mit Caddy (Reverse Proxy, HTTPS, WebSocket-Weiterleitung)
# - Log-Validierung (journalctl, code-server-Logs)
#
# Verwendung: sudo bash test-code-server.sh [--verbose] [--test=TESTNAME]

# Fehler bei der Ausführung beenden das Skript
set -e

# Konfigurationsoptionen
VERBOSE=false
SPECIFIC_TEST=""
TEST_RESULTS_DIR="/tmp/code-server-test-results"
TEST_LOG_FILE="$TEST_RESULTS_DIR/test-results.log"
FINAL_LOG_FILE="/var/log/devsystem-test-code-server.log"

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

# code-server-Konfiguration
CODE_SERVER_USER="codeserver"
CODE_SERVER_PORT="8080"
CODE_SERVER_CONFIG_DIR="/home/$CODE_SERVER_USER/.config/code-server"
CODE_SERVER_DATA_DIR="/home/$CODE_SERVER_USER/.local/share/code-server"
TAILSCALE_IP=""

# Erwartete Extensions
EXPECTED_EXTENSIONS=(
    "saoudrizwan.claude-dev"
    "eamodio.gitlens"
    "ms-azuretools.vscode-docker"
    "ms-vscode-remote.remote-ssh"
    "redhat.vscode-yaml"
    "mads-hartmann.bash-ide-vscode"
)

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
    
    log "INFO" "Initialisiere Testumgebung..."
    log "INFO" "Testergebnisse werden in $TEST_RESULTS_DIR gespeichert"
    
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
                echo "Verwendung: sudo bash test-code-server.sh [--verbose] [--test=TESTNAME]"
                echo ""
                echo "Optionen:"
                echo "  --verbose             Ausführliche Ausgabe aktivieren"
                echo "  --test=TESTNAME       Nur einen bestimmten Test ausführen"
                echo "                        Gültige Testnamen: service, config, network, extensions, workspace, integration, logs"
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
    
    return 0
}

#######################################
# 1. Test: Service-Status-Tests
#######################################

test_service() {
    log "TEST" "Überprüfe code-server-Service-Status..."
    
    local test_failed=false
    
    if ! command -v code-server &> /dev/null; then
        log "ERROR" "code-server ist nicht installiert."
        return 1
    else
        log "INFO" "code-server-Befehl ist verfügbar."
    fi
    
    local code_server_version=$(code-server --version 2>&1 | head -n1)
    log "INFO" "code-server-Version: $code_server_version"
    
    if ! systemctl list-unit-files | grep -q "code-server.service"; then
        log "ERROR" "code-server-Dienst ist nicht installiert."
        return 1
    else
        log "INFO" "code-server-Dienst ist installiert."
    fi
    
    if ! systemctl is-active --quiet code-server; then
        log "ERROR" "code-server-Dienst läuft nicht."
        test_failed=true
        log "INFO" "Service-Status:"
        systemctl status code-server --no-pager -l | head -n 20 | tee -a "$TEST_LOG_FILE"
    else
        log "INFO" "code-server-Dienst läuft."
    fi
    
    if ! systemctl is-enabled --quiet code-server; then
        log "WARN" "code-server-Dienst ist nicht für den Systemstart aktiviert."
    else
        log "INFO" "code-server-Dienst ist für den Systemstart aktiviert (Auto-Start)."
    fi
    
    if pgrep -x "node" > /dev/null && pgrep -f "code-server" > /dev/null; then
        log "INFO" "code-server-Prozess ist aktiv."
        local code_server_pid=$(pgrep -f "code-server" | head -n1)
        log "INFO" "code-server-PID: $code_server_pid"
        local uptime=$(ps -p "$code_server_pid" -o etime= 2>/dev/null | tr -d ' ')
        log "INFO" "code-server-Laufzeit: $uptime"
    else
        log "ERROR" "code-server-Prozess ist nicht aktiv."
        test_failed=true
    fi
    
    if ! id "$CODE_SERVER_USER" &>/dev/null; then
        log "ERROR" "User '$CODE_SERVER_USER' existiert nicht."
        return 1
    else
        log "INFO" "User '$CODE_SERVER_USER' existiert."
        if pgrep -u "$CODE_SERVER_USER" -f "code-server" > /dev/null; then
            log "INFO" "code-server läuft unter User '$CODE_SERVER_USER'."
        else
            log "ERROR" "code-server läuft nicht unter User '$CODE_SERVER_USER'."
            test_failed=true
        fi
    fi
    
    log "INFO" "Systemd-Service-Details:"
    systemctl show code-server --no-pager | grep -E "^(MainPID|ActiveState|SubState|LoadState|UnitFileState)=" | tee -a "$TEST_LOG_FILE"
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# 2. Test: Konfigurationstests
#######################################

test_config() {
    log "TEST" "Überprüfe code-server-Konfiguration..."
    
    local test_failed=false
    local config_file="$CODE_SERVER_CONFIG_DIR/config.yaml"
    
    if [ ! -f "$config_file" ]; then
        log "ERROR" "config.yaml existiert nicht unter $config_file"
        return 1
    else
        log "INFO" "config.yaml existiert: $config_file"
    fi
    
    log "STEP" "Validiere config.yaml-Syntax..."
    if command -v yamllint &> /dev/null; then
        if yamllint "$config_file" > "$TEST_RESULTS_DIR/yamllint.log" 2>&1; then
            log "INFO" "config.yaml-Syntax ist valide."
        else
            log "WARN" "yamllint hat Warnungen gefunden (kann normal sein)."
            [ "$VERBOSE" = true ] && cat "$TEST_RESULTS_DIR/yamllint.log" | tee -a "$TEST_LOG_FILE"
        fi
    else
        log "WARN" "yamllint nicht installiert. Überspringe YAML-Validierung."
    fi
    
    log "STEP" "Prüfe bind-addr-Konfiguration..."
    if grep -q "bind-addr: 127.0.0.1:$CODE_SERVER_PORT" "$config_file"; then
        log "INFO" "bind-addr ist korrekt konfiguriert: 127.0.0.1:$CODE_SERVER_PORT"
    else
        log "ERROR" "bind-addr ist nicht korrekt konfiguriert."
        test_failed=true
        [ "$VERBOSE" = true ] && grep "bind-addr" "$config_file" | tee -a "$TEST_LOG_FILE"
    fi
    
    log "STEP" "Prüfe Authentifizierungs-Konfiguration..."
    if grep -q "auth: password" "$config_file"; then
        log "INFO" "Authentifizierung ist auf 'password' gesetzt."
    else
        log "ERROR" "Authentifizierung ist nicht auf 'password' gesetzt."
        test_failed=true
    fi
    
    log "STEP" "Prüfe TLS-Konfiguration..."
    if grep -q "cert: false" "$config_file"; then
        log "INFO" "TLS ist deaktiviert (cert: false) - Caddy übernimmt SSL."
    else
        log "WARN" "TLS-Konfiguration ist nicht wie erwartet (cert: false)."
    fi
    
    log "STEP" "Prüfe Passwort-Konfiguration..."
    local password_file="$CODE_SERVER_CONFIG_DIR/password.txt"
    
    if [ -f "$password_file" ]; then
        log "INFO" "Passwort-Datei existiert: $password_file"
        if [ -r "$password_file" ]; then
            log "INFO" "Passwort-Datei ist lesbar."
            if [ -s "$password_file" ]; then
                log "INFO" "Passwort-Datei enthält Daten."
            else
                log "ERROR" "Passwort-Datei ist leer."
                test_failed=true
            fi
        else
            log "ERROR" "Passwort-Datei ist nicht lesbar."
            test_failed=true
        fi
    else
        log "WARN" "Passwort-Datei existiert nicht (Passwort könnte in config.yaml sein)."
        if grep -q "password:" "$config_file"; then
            log "INFO" "Passwort ist in config.yaml konfiguriert."
        else
            log "ERROR" "Kein Passwort gefunden."
            test_failed=true
        fi
    fi
    
    log "STEP" "Prüfe Dateiberechtigungen..."
    local config_perms=$(stat -c "%a" "$config_file" 2>/dev/null || stat -f "%Lp" "$config_file" 2>/dev/null)
    if [ "$config_perms" = "600" ]; then
        log "INFO" "config.yaml hat korrekte Berechtigungen: 600"
    else
        log "WARN" "config.yaml hat Berechtigungen: $config_perms (erwartet: 600)"
    fi
    
    if [ -f "$password_file" ]; then
        local password_perms=$(stat -c "%a" "$password_file" 2>/dev/null || stat -f "%Lp" "$password_file" 2>/dev/null)
        if [ "$password_perms" = "600" ]; then
            log "INFO" "password.txt hat korrekte Berechtigungen: 600"
        else
            log "WARN" "password.txt hat Berechtigungen: $password_perms (erwartet: 600)"
        fi
    fi
    
    log "STEP" "Prüfe Dateieigentümer..."
    local config_owner=$(stat -c "%U" "$config_file" 2>/dev/null || stat -f "%Su" "$config_file" 2>/dev/null)
    if [ "$config_owner" = "$CODE_SERVER_USER" ]; then
        log "INFO" "config.yaml gehört User '$CODE_SERVER_USER'."
    else
        log "WARN" "config.yaml gehört User '$config_owner' (erwartet: $CODE_SERVER_USER)"
    fi
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# 3. Test: Netzwerk-Tests
#######################################

test_network() {
    log "TEST" "Überprüfe code-server-Netzwerk-Konfiguration..."
    
    local test_failed=false
    
    log "STEP" "Prüfe ob code-server auf Port $CODE_SERVER_PORT lauscht..."
    if ss -tlnp | grep -q ":$CODE_SERVER_PORT" || netstat -tlnp 2>/dev/null | grep -q ":$CODE_SERVER_PORT"; then
        log "INFO" "code-server lauscht auf Port $CODE_SERVER_PORT."
    else
        log "ERROR" "code-server lauscht NICHT auf Port $CODE_SERVER_PORT."
        test_failed=true
        if [ "$VERBOSE" = true ]; then
            log "INFO" "Alle lauschenden Ports:"
            ss -tlnp | grep node | tee -a "$TEST_LOG_FILE" || netstat -tlnp 2>/dev/null | grep node | tee -a "$TEST_LOG_FILE"
        fi
    fi
    
    log "STEP" "Prüfe ob Port nur auf localhost gebunden ist..."
    if ss -tlnp | grep ":$CODE_SERVER_PORT" | grep -q "127.0.0.1"; then
        log "INFO" "Port $CODE_SERVER_PORT ist nur auf localhost (127.0.0.1) gebunden."
    else
        log "WARN" "Port $CODE_SERVER_PORT ist möglicherweise nicht nur auf localhost gebunden."
        [ "$VERBOSE" = true ] && ss -tlnp | grep ":$CODE_SERVER_PORT" | tee -a "$TEST_LOG_FILE"
    fi
    
    log "STEP" "Prüfe HTTP-Verbindung zu localhost:$CODE_SERVER_PORT..."
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://127.0.0.1:$CODE_SERVER_PORT" 2>/dev/null || echo "000")
    
    if [ "$http_code" != "000" ]; then
        log "INFO" "HTTP-Verbindung zu localhost:$CODE_SERVER_PORT funktioniert (HTTP-Code: $http_code)."
        curl -s -I --connect-timeout 5 "http://127.0.0.1:$CODE_SERVER_PORT" > "$TEST_RESULTS_DIR/response_headers.txt" 2>/dev/null || true
    else
        log "ERROR" "HTTP-Verbindung zu localhost:$CODE_SERVER_PORT fehlgeschlagen."
        test_failed=true
    fi
    
    log "STEP" "Prüfe ob Login-Seite erreichbar ist..."
    local response=$(curl -s --connect-timeout 5 "http://127.0.0.1:$CODE_SERVER_PORT/login" 2>/dev/null || echo "")
    
    if echo "$response" | grep -qi "code-server\|password\|login"; then
        log "INFO" "Login-Seite ist erreichbar."
    else
        log "WARN" "Login-Seite konnte nicht verifiziert werden."
    fi
    
    log "STEP" "Prüfe WebSocket-Unterstützung..."
    if [ -f "$TEST_RESULTS_DIR/response_headers.txt" ]; then
        if grep -qi "upgrade" "$TEST_RESULTS_DIR/response_headers.txt"; then
            log "INFO" "WebSocket-Header werden unterstützt."
        else
            log "WARN" "WebSocket-Header nicht in Response gefunden (kann normal sein)."
        fi
    fi
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# 4. Test: Extension-Tests
#######################################

test_extensions() {
    log "TEST" "Überprüfe code-server-Extensions..."
    
    local test_failed=false
    local extensions_dir="$CODE_SERVER_DATA_DIR/extensions"
    
    if [ ! -d "$extensions_dir" ]; then
        log "ERROR" "Extensions-Verzeichnis existiert nicht: $extensions_dir"
        return 1
    else
        log "INFO" "Extensions-Verzeichnis existiert: $extensions_dir"
    fi
    
    log "STEP" "Liste installierte Extensions auf (als User '$CODE_SERVER_USER')..."
    
    if su - "$CODE_SERVER_USER" -c "code-server --list-extensions" > "$TEST_RESULTS_DIR/installed_extensions.txt" 2>&1; then
        local ext_count=$(wc -l < "$TEST_RESULTS_DIR/installed_extensions.txt")
        log "INFO" "Installierte Extensions: $ext_count"
        [ "$VERBOSE" = true ] && cat "$TEST_RESULTS_DIR/installed_extensions.txt" | tee -a "$TEST_LOG_FILE"
    else
        log "ERROR" "Konnte Extensions nicht auflisten."
        test_failed=true
    fi
    
    log "STEP" "Prüfe erwartete Extensions..."
    local missing_extensions=()
    local found_extensions=0
    
    for ext in "${EXPECTED_EXTENSIONS[@]}"; do
        if grep -q "$ext" "$TEST_RESULTS_DIR/installed_extensions.txt" 2>/dev/null; then
            log "INFO" "  ✓ Extension installiert: $ext"
            ((found_extensions++))
        else
            log "WARN" "  ✗ Extension fehlt: $ext"
            missing_extensions+=("$ext")
        fi
    done
    
    log "INFO" "Gefundene Extensions: $found_extensions/${#EXPECTED_EXTENSIONS[@]}"
    
    if [ ${#missing_extensions[@]} -gt 0 ]; then
        log "WARN" "Fehlende Extensions: ${#missing_extensions[@]}"
        if [ "$VERBOSE" = true ]; then
            for ext in "${missing_extensions[@]}"; do
                log "WARN" "  - $ext"
            done
        fi
    fi
    
    log "STEP" "Prüfe ob Extensions aktiviert sind..."
    local active_extensions=$(find "$extensions_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    log "INFO" "Aktive Extension-Verzeichnisse: $active_extensions"
    
    if [ "$active_extensions" -eq 0 ]; then
        log "WARN" "Keine aktiven Extensions gefunden."
    else
        log "INFO" "Extensions sind aktiviert."
    fi
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# 5. Test: Workspace-Tests
#######################################

test_workspace() {
    log "TEST" "Überprüfe code-server-Workspace-Konfiguration..."
    
    local test_failed=false
    
    if [ ! -d "$CODE_SERVER_DATA_DIR" ]; then
        log "ERROR" "User-Data-Verzeichnis existiert nicht: $CODE_SERVER_DATA_DIR"
        return 1
    else
        log "INFO" "User-Data-Verzeichnis existiert: $CODE_SERVER_DATA_DIR"
    fi
    
    local extensions_dir="$CODE_SERVER_DATA_DIR/extensions"
    if [ ! -d "$extensions_dir" ]; then
        log "ERROR" "Extensions-Verzeichnis existiert nicht: $extensions_dir"
        test_failed=true
    else
        log "INFO" "Extensions-Verzeichnis existiert: $extensions_dir"
    fi
    
    local settings_file="$CODE_SERVER_DATA_DIR/User/settings.json"
    log "STEP" "Prüfe settings.json..."
    
    if [ ! -f "$settings_file" ]; then
        log "WARN" "settings.json existiert nicht: $settings_file"
    else
        log "INFO" "settings.json existiert: $settings_file"
        
        if command -v jq &> /dev/null; then
            if jq empty "$settings_file" 2>/dev/null; then
                log "INFO" "settings.json hat valide JSON-Syntax."
            else
                log "ERROR" "settings.json hat ungültige JSON-Syntax."
                test_failed=true
            fi
        else
            log "WARN" "jq nicht installiert. Überspringe JSON-Validierung."
        fi
    fi
    
    log "STEP" "Prüfe Workspace-Einstellungen..."
    if [ -f "$settings_file" ] && command -v jq &> /dev/null; then
        if jq -e '.["files.autoSave"]' "$settings_file" > /dev/null 2>&1; then
            local autosave=$(jq -r '.["files.autoSave"]' "$settings_file")
            log "INFO" "Auto-Save ist konfiguriert: $autosave"
        else
            log "WARN" "Auto-Save ist nicht konfiguriert."
        fi
        
        if jq -e '.["editor.formatOnSave"]' "$settings_file" > /dev/null 2>&1; then
            local formatonsave=$(jq -r '.["editor.formatOnSave"]' "$settings_file")
            log "INFO" "Format on Save ist konfiguriert: $formatonsave"
        else
            log "WARN" "Format on Save ist nicht konfiguriert."
        fi
    fi
    
    log "STEP" "Prüfe Verzeichnisberechtigungen..."
    local data_owner=$(stat -c "%U" "$CODE_SERVER_DATA_DIR" 2>/dev/null || stat -f "%Su" "$CODE_SERVER_DATA_DIR" 2>/dev/null)
    if [ "$data_owner" = "$CODE_SERVER_USER" ]; then
        log "INFO" "User-Data-Verzeichnis gehört User '$CODE_SERVER_USER'."
    else
        log "WARN" "User-Data-Verzeichnis gehört User '$data_owner' (erwartet: $CODE_SERVER_USER)"
    fi
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# 6. Test: Integration mit Caddy
#######################################

test_integration() {
    log "TEST" "Überprüfe Integration mit Caddy..."
    
    local test_failed=false
    
    log "STEP" "Prüfe ob Caddy läuft..."
    if ! command -v caddy &> /dev/null; then
        log "WARN" "Caddy ist nicht installiert. Überspringe Caddy-Integration-Tests."
        return 0
    fi
    
    if ! systemctl is-active --quiet caddy; then
        log "WARN" "Caddy-Service läuft nicht. Überspringe Caddy-Integration-Tests."
        return 0
    else
        log "INFO" "Caddy-Service läuft."
    fi
    
    log "STEP" "Prüfe Reverse Proxy zu code-server..."
    if grep -r "reverse_proxy.*localhost:$CODE_SERVER_PORT" /etc/caddy/ > /dev/null 2>&1; then
        log "INFO" "Caddy Reverse Proxy zu code-server ist konfiguriert."
    else
        log "WARN" "Caddy Reverse Proxy zu code-server wurde nicht in der Konfiguration gefunden."
    fi
    
    if [ -n "$TAILSCALE_IP" ]; then
        log "STEP" "Prüfe HTTPS-Zugriff über Caddy (https://$TAILSCALE_IP:9443)..."
        local https_code=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "https://$TAILSCALE_IP:9443" 2>/dev/null || echo "000")
        
        if [ "$https_code" != "000" ]; then
            log "INFO" "HTTPS-Zugriff über Caddy funktioniert (HTTP-Code: $https_code)."
            curl -k -s -I --connect-timeout 5 "https://$TAILSCALE_IP:9443" > "$TEST_RESULTS_DIR/caddy_response_headers.txt" 2>/dev/null || true
        else
            log "WARN" "HTTPS-Zugriff über Caddy fehlgeschlagen."
        fi
    else
        log "WARN" "Tailscale-IP nicht verfügbar. Überspringe HTTPS-Test."
    fi
    
    log "STEP" "Prüfe WebSocket-Weiterleitung..."
    if grep -r "header_up.*Upgrade\|header_up.*Connection" /etc/caddy/ > /dev/null 2>&1; then
        log "INFO" "WebSocket-Header sind in Caddy konfiguriert."
    else
        log "WARN" "WebSocket-Header-Konfiguration nicht gefunden (Caddy unterstützt WebSockets standardmäßig)."
    fi
    
    log "STEP" "Prüfe Authentifizierung über Caddy..."
    if [ -n "$TAILSCALE_IP" ]; then
        local response=$(curl -k -s --connect-timeout 5 "https://$TAILSCALE_IP:9443" 2>/dev/null || echo "")
        if echo "$response" | grep -qi "password\|login"; then
            log "INFO" "Authentifizierung ist aktiv (Login-Seite wird angezeigt)."
        else
            log "WARN" "Konnte Authentifizierung nicht verifizieren."
        fi
    fi
    
    log "STEP" "Prüfe Caddy-Logs..."
    if [ -d "/var/log/caddy" ]; then
        [ -f "/var/log/caddy/access.log" ] && log "INFO" "Caddy Access-Log existiert." || log "WARN" "Caddy Access-Log nicht gefunden."
        [ -f "/var/log/caddy/code-server.log" ] && log "INFO" "Caddy code-server-spezifisches Log existiert." || log "WARN" "Caddy code-server-spezifisches Log nicht gefunden."
    else
        log "WARN" "Caddy-Log-Verzeichnis nicht gefunden."
    fi
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# 7. Test: Log-Validierung (KRITISCH!)
#######################################

test_logs() {
    log "TEST" "Überprüfe code-server-Logs und -Logging-Konfiguration..."
    
    local test_failed=false
    
    log "STEP" "Prüfe code-server-Log-Dateien..."
    local log_dir="$CODE_SERVER_DATA_DIR/../code-server/logs"
    if [ -d "$log_dir" ]; then
        log "INFO" "code-server-Log-Verzeichnis existiert: $log_dir"
        local log_count=$(find "$log_dir" -name "*.log" 2>/dev/null | wc -l)
        log "INFO" "Gefundene Log-Dateien: $log_count"
        [ "$VERBOSE" = true ] && [ "$log_count" -gt 0 ] && find "$log_dir" -name "*.log" 2>/dev/null | tee -a "$TEST_LOG_FILE"
    else
        log "WARN" "code-server-Log-Verzeichnis existiert nicht: $log_dir"
    fi
    
    log "STEP" "Prüfe journalctl-Logs für code-server..."
    if ! journalctl -u code-server -n 1 &> /dev/null; then
        log "ERROR" "Keine code-server-Logs in journalctl gefunden."
        test_failed=true
    else
        local log_count=$(journalctl -u code-server --no-pager | wc -l)
        log "INFO" "Gefundene journalctl-Log-Einträge für code-server: $log_count"
        journalctl -u code-server -n 50 --no-pager > "$TEST_RESULTS_DIR/code_server_journalctl.log" 2>&1
        
        log "STEP" "Prüfe Logs auf erfolgreichen Start..."
        if journalctl -u code-server --no-pager | grep -qi "HTTP server listening\|started\|listening"; then
            log "INFO" "Logs zeigen erfolgreichen Start."
        else
            log "WARN" "Konnte keinen erfolgreichen Start in den Logs finden."
        fi
        
        log "STEP" "Prüfe Logs auf kritische Fehler..."
        local error_count=$(journalctl -u code-server --no-pager | grep -ci "error\|fatal\|panic" || echo "0")
        
        if [ "$error_count" -eq 0 ]; then
            log "INFO" "Keine kritischen Fehler in den Logs gefunden."
        else
            log "WARN" "Gefundene Fehler in den Logs: $error_count"
            [ "$VERBOSE" = true ] && journalctl -u code-server --no-pager | grep -i "error\|fatal\|panic" | tail -n 10 | tee -a "$TEST_LOG_FILE"
        fi
        
        local warn_count=$(journalctl -u code-server --no-pager | grep -ci "warn" || echo "0")
        if [ "$warn_count" -eq 0 ]; then
            log "INFO" "Keine Warnungen in den Logs gefunden."
        else
            log "INFO" "Gefundene Warnungen in den Logs: $warn_count"
        fi
        
        [ "$VERBOSE" = true ] && log "INFO" "Letzte 20 Log-Einträge:" && journalctl -u code-server -n 20 --no-pager | tee -a "$TEST_LOG_FILE"
    fi
    
    log "STEP" "Prüfe code-server-interne Logs..."
    local internal_log_dir="$CODE_SERVER_DATA_DIR/../code-server/logs"
    
    if [ -d "$internal_log_dir" ]; then
        local latest_log=$(find "$internal_log_dir" -name "*.log" -type f 2>/dev/null | sort -r | head -n1)
        
        if [ -n "$latest_log" ]; then
            log "INFO" "Neueste interne Log-Datei: $latest_log"
            if grep -qi "error" "$latest_log" 2>/dev/null; then
                log "WARN" "Fehler in interner Log-Datei gefunden."
                [ "$VERBOSE" = true ] && grep -i "error" "$latest_log" | tail -n 5 | tee -a "$TEST_LOG_FILE"
            else
                log "INFO" "Keine Fehler in interner Log-Datei gefunden."
            fi
        else
            log "WARN" "Keine internen Log-Dateien gefunden."
        fi
    fi
    
    log "STEP" "Prüfe Log-Größe und -Rotation..."
    if [ -d "$internal_log_dir" ]; then
        local total_log_size=$(du -sh "$internal_log_dir" 2>/dev/null | cut -f1)
        log "INFO" "Gesamte Log-Größe: $total_log_size"
        local log_file_count=$(find "$internal_log_dir" -name "*.log" 2>/dev/null | wc -l)
        log "INFO" "Anzahl Log-Dateien: $log_file_count"
    fi
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# Hauptfunktion
#######################################

main() {
    log "TEST" "==== Starte code-server E2E-Tests ===="
    
    init_test_env
    parse_args "$@"
    
    get_tailscale_info || log "WARN" "Tailscale-Informationen konnten nicht vollständig ermittelt werden."
    
    run_test "service" test_service
    run_test "config" test_config
    run_test "network" test_network
    run_test "extensions" test_extensions
    run_test "workspace" test_workspace
    run_test "integration" test_integration
    run_test "logs" test_logs
    
    show_test_results
    
    if [ -f "$TEST_LOG_FILE" ]; then
        cp "$TEST_LOG_FILE" "$FINAL_LOG_FILE" 2>/dev/null || true
        log "INFO" "Finale Log-Datei: $FINAL_LOG_FILE"
    fi
    
    log "TEST" "==== code-server E2E-Tests abgeschlossen ===="
    
    if [ $FAILED_TESTS -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
