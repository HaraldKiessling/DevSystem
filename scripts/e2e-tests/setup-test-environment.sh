#!/bin/bash
#
# setup-test-environment.sh - Einrichtung der Testumgebung für code-server E2E-Tests
#
# Dieses Skript richtet eine isolierte Testumgebung für die E2E-Tests von code-server ein,
# konfiguriert code-server für Testzwecke, richtet Tailscale ein und implementiert
# Cleanup-Funktionen.
#
# Version: 1.0
# Autor: DevSystem Team
# Datum: 2026-04-12
#
# Verwendung: bash setup-test-environment.sh [--verbose] [--no-cleanup]
#

# Fehler bei der Ausführung beenden das Skript
set -e

# Konfigurationsoptionen
VERBOSE=false
NO_CLEANUP=false
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
TEST_ENV_DIR="/tmp/code-server-test-env"
TEST_RESULTS_DIR="/tmp/code-server-e2e-test-results"
TEST_ENV_LOG="$TEST_RESULTS_DIR/env-setup.log"

# code-server-Konfiguration
CODE_SERVER_PORT="8080"
CODE_SERVER_TEST_CONFIG="$TEST_ENV_DIR/code-server-test-config"
CODE_SERVER_TEST_DATA="$TEST_ENV_DIR/code-server-test-data"
CODE_SERVER_TEST_EXTENSIONS="$TEST_ENV_DIR/code-server-test-extensions"

# Tailscale-Konfiguration
TAILSCALE_TEST_CONFIG="$TEST_ENV_DIR/tailscale-test-config"
TAILSCALE_TEMP_AUTHKEY_FILE="$TEST_ENV_DIR/tailscale-authkey.txt"

# Farbdefinitionen für Terminal-Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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
        "SETUP") color=$BLUE ;;
        "STEP") color=$CYAN ;;
    esac
    
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [ENV-SETUP] [$level] $message${NC}" | tee -a "$TEST_ENV_LOG"
}

# Fehlerfunktion
fail() {
    log "ERROR" "$1"
    cleanup_test_environment
    exit 1
}

# ============================================================================
# HILFSFUNKTIONEN
# ============================================================================

# Initialisierung der Testumgebung
init_test_env() {
    mkdir -p "$TEST_RESULTS_DIR"
    > "$TEST_ENV_LOG"
    
    log "SETUP" "Initialisiere code-server Testumgebung..."
    
    if [ "$(id -u)" -ne 0 ] && [ -z "$SKIP_ROOT_CHECK" ]; then
        log "WARN" "Dieses Skript sollte idealerweise als Root ausgeführt werden. Einige Tests könnten fehlschlagen."
    fi
}

# Funktion zum Parsen der Kommandozeilenargumente
parse_args() {
    for arg in "$@"; do
        case $arg in
            --verbose)
                VERBOSE=true
                ;;
            --no-cleanup)
                NO_CLEANUP=true
                ;;
            --help)
                echo "Verwendung: bash setup-test-environment.sh [--verbose] [--no-cleanup]"
                echo ""
                echo "Optionen:"
                echo "  --verbose         Ausführliche Ausgabe aktivieren"
                echo "  --no-cleanup      Keine Bereinigung der Testumgebung nach Abschluss"
                echo "  --help            Diese Hilfe anzeigen"
                echo ""
                exit 0
                ;;
        esac
    done
    
    if [ "$VERBOSE" = true ]; then
        log "INFO" "Ausführliche Ausgabe aktiviert."
    fi
    
    if [ "$NO_CLEANUP" = true ]; then
        log "INFO" "Bereinigung der Testumgebung deaktiviert."
    fi
}

# ============================================================================
# FUNKTIONEN FÜR ISOLIERTE TESTUMGEBUNG
# ============================================================================

# Erstelle eine isolierte Testumgebung
create_isolated_env() {
    log "STEP" "Erstelle isolierte Testumgebung..."
    
    # Prüfe, ob Testumgebung bereits existiert
    if [ -d "$TEST_ENV_DIR" ]; then
        log "INFO" "Testumgebungsverzeichnis existiert bereits: $TEST_ENV_DIR"
        log "INFO" "Bereinige vorhandene Testumgebung..."
        rm -rf "$TEST_ENV_DIR"
    fi
    
    # Erstelle Verzeichnisstruktur für Testumgebung
    mkdir -p "$TEST_ENV_DIR"
    mkdir -p "$CODE_SERVER_TEST_CONFIG"
    mkdir -p "$CODE_SERVER_TEST_DATA"
    mkdir -p "$CODE_SERVER_TEST_EXTENSIONS"
    mkdir -p "$TAILSCALE_TEST_CONFIG"
    
    log "INFO" "Testumgebungsverzeichnis erstellt: $TEST_ENV_DIR"
}

# Prüfe ob benötigte Komponenten verfügbar sind
check_prerequisites() {
    log "STEP" "Prüfe Voraussetzungen für Testumgebung..."
    local missing_prereqs=false
    
    # Prüfe ob code-server installiert ist
    if ! command -v code-server &> /dev/null; then
        log "ERROR" "code-server ist nicht installiert oder nicht im PATH"
        missing_prereqs=true
    else
        log "INFO" "code-server gefunden: $(which code-server)"
    fi
    
    # Prüfe ob Tailscale installiert ist
    if ! command -v tailscale &> /dev/null; then
        log "ERROR" "Tailscale ist nicht installiert oder nicht im PATH"
        missing_prereqs=true
    else
        log "INFO" "Tailscale gefunden: $(which tailscale)"
    fi
    
    # Prüfe ob curl installiert ist
    if ! command -v curl &> /dev/null; then
        log "ERROR" "curl ist nicht installiert oder nicht im PATH"
        missing_prereqs=true
    else
        log "INFO" "curl gefunden: $(which curl)"
    fi
    
    # Prüfe ob jq installiert ist
    if ! command -v jq &> /dev/null; then
        log "WARN" "jq ist nicht installiert oder nicht im PATH. Einige Tailscale-Tests werden eingeschränkt sein."
    else
        log "INFO" "jq gefunden: $(which jq)"
    fi
    
    # Prüfe ob netstat verfügbar ist
    if ! command -v netstat &> /dev/null; then
        log "WARN" "netstat ist nicht installiert oder nicht im PATH. Portverfügbarkeitstests sind eingeschränkt."
    else
        log "INFO" "netstat gefunden: $(which netstat)"
    fi
    
    if [ "$missing_prereqs" = true ]; then
        log "ERROR" "Eine oder mehrere Voraussetzungen fehlen. Installation empfohlen mit:"
        log "ERROR" "bash $SCRIPT_DIR/setup-automated-tests.sh"
        fail "Voraussetzungen für Testumgebung nicht erfüllt"
    fi
    
    log "INFO" "Alle Voraussetzungen für Testumgebung erfüllt."
    return 0
}

# ============================================================================
# FUNKTIONEN FÜR CODE-SERVER KONFIGURATION
# ============================================================================

# Konfiguriere code-server für Tests
configure_code_server() {
    log "STEP" "Konfiguriere code-server für Testzwecke..."
    
    # Prüfe auf verfügbaren Port
    if command -v netstat &> /dev/null; then
        if netstat -tuln | grep -q ":$CODE_SERVER_PORT "; then
            log "WARN" "Port $CODE_SERVER_PORT ist bereits in Verwendung. Versuche alternativen Port."
            # Suche nach verfügbarem Port im Bereich 8081-8100
            for port in $(seq 8081 8100); do
                if ! netstat -tuln | grep -q ":$port "; then
                    CODE_SERVER_PORT="$port"
                    log "INFO" "Verwende alternativen Port: $CODE_SERVER_PORT"
                    break
                fi
            done
        fi
    fi
    
    # Erstelle Testkonfiguration für code-server
    log "INFO" "Erstelle Testkonfiguration für code-server..."
    
    local config_file="$CODE_SERVER_TEST_CONFIG/config.yaml"
    
    # Schreibe Konfigurationsdatei
    cat > "$config_file" <<EOF
bind-addr: 127.0.0.1:$CODE_SERVER_PORT
auth: none
cert: false
user-data-dir: $CODE_SERVER_TEST_DATA
extensions-dir: $CODE_SERVER_TEST_EXTENSIONS
log: debug
EOF
    
    log "INFO" "code-server-Testkonfiguration erstellt: $config_file"
    
    # Speichere den Port für andere Tests
    echo "$CODE_SERVER_PORT" > "$TEST_ENV_DIR/code_server_port.txt"
    
    # Erstelle ein einfaches Testprojekt
    local test_project="$CODE_SERVER_TEST_DATA/test-project"
    mkdir -p "$test_project"
    
    # Erstelle einfache Testdateien
    echo "# code-server Testprojekt" > "$test_project/README.md"
    echo "console.log('Hello World');" > "$test_project/test.js"
    echo "<html><body><h1>Test Page</h1></body></html>" > "$test_project/test.html"
    
    log "INFO" "Testprojekt erstellt: $test_project"
    
    # Teste code-server-Konfiguration (ohne zu starten)
    if [ "$VERBOSE" = true ]; then
        log "STEP" "Validiere code-server-Konfiguration..."
        if code-server --config "$config_file" --help &>/dev/null; then
            log "INFO" "code-server-Konfiguration ist gültig."
        else
            log "WARN" "code-server-Konfigurationsvalidierung fehlgeschlagen."
        fi
    fi
}

# ============================================================================
# FUNKTIONEN FÜR TAILSCALE SETUP
# ============================================================================

# Konfiguriere Tailscale für Tests
configure_tailscale() {
    log "STEP" "Konfiguriere Tailscale für Testzwecke..."
    
    # Prüfe Tailscale-Status
    log "INFO" "Prüfe Tailscale-Status..."
    
    local tailscale_status=""
    local tailscale_ip=""
    
    # Versuche Tailscale-Status abzurufen
    if command -v jq &> /dev/null; then
        # Mit jq (bevorzugt für präzisere Extraktion)
        if tailscale_status=$(tailscale status --json 2>/dev/null); then
            tailscale_ip=$(echo "$tailscale_status" | jq -r '.Self.TailscaleIPs[0]' 2>/dev/null)
            local tailnet_name=$(echo "$tailscale_status" | jq -r '.MagicDNSSuffix' 2>/dev/null)
            
            if [ -n "$tailscale_ip" ] && [ "$tailscale_ip" != "null" ]; then
                log "INFO" "Tailscale ist verbunden mit IP: $tailscale_ip"
                log "INFO" "Tailnet: $tailnet_name"
            else
                log "WARN" "Tailscale-Status konnte nicht korrekt extrahiert werden."
                tailscale_ip=""
            fi
        else
            log "WARN" "Konnte Tailscale-Status nicht abrufen."
        fi
    else
        # Ohne jq (Fallback, weniger zuverlässig)
        if tailscale_status=$(tailscale status 2>/dev/null | grep -i "tailscale ip"); then
            tailscale_ip=$(echo "$tailscale_status" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+')
            if [ -n "$tailscale_ip" ]; then
                log "INFO" "Tailscale ist verbunden mit IP: $tailscale_ip"
            fi
        else
            log "WARN" "Konnte Tailscale-Status nicht abrufen."
        fi
    fi
    
    # Speichere Tailscale-IP für Tests, wenn verfügbar
    if [ -n "$tailscale_ip" ]; then
        echo "$tailscale_ip" > "$TEST_ENV_DIR/tailscale_ip.txt"
    else
        log "WARN" "Tailscale scheint nicht verbunden zu sein oder IP konnte nicht ermittelt werden."
        log "WARN" "Einige Tailscale-bezogene Tests werden fehlschlagen."
        
        # Prüfe ob Authkey-Vorlage existiert
        local authkey_template="$PARENT_DIR/tailscale-authkey.txt.template"
        if [ -f "$authkey_template" ]; then
            log "INFO" "Tailscale-Authkey-Vorlage gefunden: $authkey_template"
            log "INFO" "Kopiere als Vorlage für Tests..."
            cp "$authkey_template" "$TAILSCALE_TEMP_AUTHKEY_FILE"
            log "INFO" "Für vollständige Tests ersetzen Sie den Inhalt in: $TAILSCALE_TEMP_AUTHKEY_FILE"
        else
            log "INFO" "Erstelle leere Authkey-Datei für Tests: $TAILSCALE_TEMP_AUTHKEY_FILE"
            echo "# Ersetzen Sie diese Zeile mit Ihrem Tailscale-Authkey für automatisierte Tests" > "$TAILSCALE_TEMP_AUTHKEY_FILE"
        fi
    fi
    
    # Erstelle Tailscale-Test-Konfiguration
    local tailscale_test_config="$TAILSCALE_TEST_CONFIG/tailscaled.conf"
    cat > "$tailscale_test_config" <<EOF
# Tailscale-Testkonfiguration
# Diese Konfiguration wird für Tests verwendet, nicht für die Produktion.
# Generiert von setup-test-environment.sh

# Verwende temporäres Verzeichnis für Testdaten
STATE_DIR=$TAILSCALE_TEST_CONFIG
EOF
    
    log "INFO" "Tailscale-Testkonfiguration erstellt: $tailscale_test_config"
}

# ============================================================================
# CLEANUP-FUNKTIONEN
# ============================================================================

# Bereinigung der Testumgebung
cleanup_test_environment() {
    # Wenn --no-cleanup gesetzt ist, führe keine Bereinigung durch
    if [ "$NO_CLEANUP" = true ]; then
        log "INFO" "Bereinigung übersprungen (--no-cleanup wurde angegeben)"
        return 0
    fi
    
    log "STEP" "Bereinige Testumgebung..."
    
    # Bereinige nur, wenn das Verzeichnis existiert
    if [ ! -d "$TEST_ENV_DIR" ]; then
        log "INFO" "Nichts zu bereinigen. Testumgebungsverzeichnis existiert nicht."
        return 0
    fi
    
    # Beende eventuell laufende Testprozesse
    for pid_file in "$TEST_ENV_DIR"/*.pid; do
        if [ -f "$pid_file" ]; then
            local proc_pid=$(cat "$pid_file")
            local proc_name=$(basename "$pid_file" .pid)
            if kill -0 "$proc_pid" 2>/dev/null; then
                log "INFO" "Beende Testprozess $proc_name (PID: $proc_pid)..."
                kill "$proc_pid" 2>/dev/null || true
            fi
            rm -f "$pid_file"
        fi
    done
    
    # Entferne Testumgebungsverzeichnis
    log "INFO" "Entferne Testumgebungsverzeichnis: $TEST_ENV_DIR"
    rm -rf "$TEST_ENV_DIR"
    
    log "INFO" "Testumgebung bereinigt."
    return 0
}

# Registriere Trap für sauberes Beenden
setup_trap() {
    # Trap für Cleanup bei Skriptabbruch
    trap cleanup_test_environment EXIT
    log "INFO" "Trap für sauberes Beenden registriert."
}

# ============================================================================
# HAUPTFUNKTION
# ============================================================================

# Hauptfunktion
main() {
    log "SETUP" "==== Starte Einrichtung der code-server Testumgebung ===="
    
    init_test_env
    parse_args "$@"
    
    # Überspringe Trap-Setup, wenn --no-cleanup gesetzt ist
    if [ "$NO_CLEANUP" = false ]; then
        setup_trap
    fi
    
    # Prüfe Voraussetzungen
    check_prerequisites || fail "Voraussetzungsprüfung fehlgeschlagen"
    
    # Erstelle isolierte Testumgebung
    create_isolated_env || fail "Erstellen der isolierten Testumgebung fehlgeschlagen"
    
    # Konfiguriere code-server und Tailscale
    configure_code_server || log "WARN" "Konfiguration von code-server fehlgeschlagen, fahre trotzdem fort..."
    configure_tailscale || log "WARN" "Konfiguration von Tailscale fehlgeschlagen, fahre trotzdem fort..."
    
    log "SETUP" "==== Einrichtung der code-server Testumgebung abgeschlossen ===="
    log "INFO" "Testumgebung erfolgreich eingerichtet: $TEST_ENV_DIR"
    log "INFO" "code-server-Konfiguration: $CODE_SERVER_TEST_CONFIG/config.yaml"
    
    return 0
}

# Starte die Hauptfunktion mit allen übergebenen Argumenten
main "$@"