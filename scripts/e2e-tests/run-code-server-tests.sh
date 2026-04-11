#!/bin/bash
#
# DevSystem Code-Server E2E-Test-Hauptskript
# Dieses Skript führt alle spezialisierten E2E-Tests für Code-Server aus
#
# Version: 1.0
# Autor: DevSystem Team
# Datum: 2026-04-11
#

# Fehler bei der Ausführung beenden das Skript
set -e

# Konfigurationsoptionen
VERBOSE=false
SPECIFIC_TEST=""
TEST_RESULTS_DIR="/tmp/code-server-test-results"
TEST_LOG_FILE="$TEST_RESULTS_DIR/test-results.log"
FINAL_LOG_FILE="/var/log/devsystem-test-code-server.log"

# Pfad zum Skriptverzeichnis
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
                echo "Verwendung: sudo $0 [--verbose] [--test=TESTNAME]"
                echo ""
                echo "Optionen:"
                echo "  --verbose             Ausführliche Ausgabe aktivieren"
                echo "  --test=TESTNAME       Nur einen bestimmten Test ausführen"
                echo "                        Gültige Testnamen: service, config, network, extensions, workspace, tailscale, pwa, logs"
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

# Funktion zur Ausführung der originalen Tests aus test-code-server.sh
run_original_tests() {
    local original_script="/scripts/test-code-server.sh"
    
    if [ ! -f "$original_script" ]; then
        log "WARN" "Originales Testskript $original_script nicht gefunden."
        return 0
    fi
    
    local args=""
    [ "$VERBOSE" = true ] && args="--verbose"
    [ -n "$SPECIFIC_TEST" ] && args="$args --test=$SPECIFIC_TEST"
    
    log "TEST" "Führe Original-Testskript aus: $original_script $args"
    
    if bash "$original_script" $args; then
        log "INFO" "Original-Tests erfolgreich abgeschlossen."
        return 0
    else
        log "ERROR" "Original-Tests fehlgeschlagen."
        return 1
    fi
}

# Funktion zum Ausführen eines spezialisierten Testskripts
run_test_script() {
    local test_name=$1
    local test_script=$2
    
    if [ -n "$SPECIFIC_TEST" ] && [ "$SPECIFIC_TEST" != "$test_name" ]; then
        return 0
    fi
    
    log "TEST" "Starte Test: $test_name (Skript: $test_script)"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    local args=""
    [ "$VERBOSE" = true ] && args="--verbose"
    
    if [ -f "$test_script" ]; then
        if bash "$test_script" $args; then
            log "INFO" "Test '$test_name' erfolgreich abgeschlossen."
            PASSED_TESTS=$((PASSED_TESTS + 1))
            return 0
        else
            log "ERROR" "Test '$test_name' fehlgeschlagen."
            FAILED_TESTS=$((FAILED_TESTS + 1))
            return 1
        fi
    else
        log "ERROR" "Testskript nicht gefunden: $test_script"
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

# Umgebung für Tests vorbereiten
prepare_test_env() {
    log "STEP" "Bereite Testumgebung vor..."
    
    # Test-Umgebungsskript aufrufen, falls vorhanden
    local setup_script="$SCRIPT_DIR/setup-test-environment.sh"
    
    if [ -f "$setup_script" ] && [ -x "$setup_script" ]; then
        log "INFO" "Führe Setup-Skript aus: $setup_script"
        if "$setup_script"; then
            log "INFO" "Testumgebung erfolgreich vorbereitet."
        else
            log "WARN" "Testumgebung konnte nicht vollständig vorbereitet werden."
        fi
    else
        log "WARN" "Setup-Skript nicht gefunden oder nicht ausführbar: $setup_script"
    fi
}

#######################################
# Hauptfunktion
#######################################

main() {
    log "TEST" "==== Starte DevSystem Code-Server E2E-Tests ===="
    
    init_test_env
    parse_args "$@"
    prepare_test_env
    
    # Tailscale-Informationen ermitteln (kann von mehreren Tests verwendet werden)
    TAILSCALE_IP=""
    if command -v tailscale &> /dev/null; then
        TAILSCALE_IP=$(tailscale ip -4 2>/dev/null | head -n1)
        [ -n "$TAILSCALE_IP" ] && log "INFO" "Tailscale-IP: $TAILSCALE_IP"
    fi
    
    # Exportiere Variablen für Testskripte
    export TEST_RESULTS_DIR VERBOSE TAILSCALE_IP
    
    # Führe spezialisierte Testskripte aus
    run_test_script "tailscale" "$SCRIPT_DIR/test-code-server-tailscale.sh"
    run_test_script "pwa" "$SCRIPT_DIR/test-code-server-pwa.sh"
    run_test_script "logs" "$SCRIPT_DIR/test-code-server-logs.sh"
    
    # Abschluss-Tests und Zusammenfassung
    show_test_results
    
    if [ -f "$TEST_LOG_FILE" ]; then
        cp "$TEST_LOG_FILE" "$FINAL_LOG_FILE" 2>/dev/null || true
        log "INFO" "Finale Log-Datei: $FINAL_LOG_FILE"
    fi
    
    log "TEST" "==== DevSystem Code-Server E2E-Tests abgeschlossen ===="
    
    if [ $FAILED_TESTS -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"