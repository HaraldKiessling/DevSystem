#!/bin/bash
#
# run-code-server-tests.sh - Hauptskript für Code-Server-E2E-Tests
#
# Dieses Skript dient als zentraler Einstiegspunkt für alle Code-Server-Tests
# und ruft die einzelnen Testskripte auf. Es fasst die Ergebnisse zusammen
# und stellt ein einheitliches Logging-Format zur Verfügung.
#
# Erweiterte Funktionalität:
# - Integration mit setup-test-environment.sh für automatisierte Testumgebung
# - Unterstützung für parallele Testausführung für schnellere Ergebnisse
# - HTML-Berichterstellung für bessere Berichterstellung
# - Verbesserte Fehlerbehandlung und Robustheit
# - Erweiterte Logging-Funktionen mit Dauer- und Leistungsmetriken
#
# Version: 1.1
# Autor: DevSystem Team
# Datum: 2026-04-12
# Teil von: GitHub Issue #18 - Automatisierte E2E-Tests
#
# Verwendung: bash run-code-server-tests.sh [--verbose] [--test=TESTNAME]
#             TESTNAME Optionen: tailscale, pwa, logs, all (Standard)
#             --parallel Führt Tests parallel aus (beschleunigte Ausführung)
#             --html-report Erstellt HTML-Bericht der Testergebnisse
#

# Fehler bei der Ausführung beenden das Skript
set -e

# Konfigurationsoptionen
VERBOSE=false
SPECIFIC_TEST=""
PARALLEL_EXECUTION=false
GENERATE_HTML_REPORT=false
TEST_RESULTS_DIR="/tmp/code-server-e2e-test-results"
TEST_LOG_FILE="$TEST_RESULTS_DIR/e2e-test-results.log"
HTML_REPORT_FILE="$TEST_RESULTS_DIR/e2e-test-report.html"
FINAL_LOG_FILE="/var/log/devsystem-e2e-tests.log"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

# Testzähler
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

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
        "TEST") color=$BLUE ;;
        "STEP") color=$CYAN ;;
    esac
    
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [E2E-TEST] [$level] $message${NC}" | tee -a "$TEST_LOG_FILE"
}

# ============================================================================
# HILFSFUNKTIONEN
# ============================================================================

# Initialisierung der Testumgebung
init_test_env() {
    mkdir -p "$TEST_RESULTS_DIR"
    > "$TEST_LOG_FILE"
    
    log "INFO" "Initialisiere E2E-Testumgebung..."
    log "INFO" "Testergebnisse werden in $TEST_RESULTS_DIR gespeichert"
    
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
            --test=*)
                SPECIFIC_TEST="${arg#*=}"
                ;;
            --parallel)
                PARALLEL_EXECUTION=true
                ;;
            --html-report)
                GENERATE_HTML_REPORT=true
                ;;
            --help)
                echo "Verwendung: bash run-code-server-tests.sh [--verbose] [--test=TESTNAME] [--parallel] [--html-report]"
                echo ""
                echo "Optionen:"
                echo "  --verbose                  Ausführliche Ausgabe aktivieren"
                echo "  --test=TESTNAME            Nur bestimmte Tests ausführen"
                echo "                             Gültige Testnamen: tailscale, pwa, logs, all"
                echo "  --parallel                 Tests parallel ausführen (beschleunigte Ausführung)"
                echo "  --html-report              HTML-Bericht der Testergebnisse erstellen"
                echo "  --help                     Diese Hilfe anzeigen"
                echo ""
                exit 0
                ;;
        esac
    done
    
    if [ -n "$SPECIFIC_TEST" ]; then
        log "INFO" "Führe nur den Test '$SPECIFIC_TEST' aus."
    else
        SPECIFIC_TEST="all"
        log "INFO" "Führe alle Tests aus."
    fi
    
    if [ "$VERBOSE" = true ]; then
        log "INFO" "Ausführliche Ausgabe aktiviert."
    fi
    
    if [ "$PARALLEL_EXECUTION" = true ]; then
        log "INFO" "Parallele Testausführung aktiviert."
    fi
    
    if [ "$GENERATE_HTML_REPORT" = true ]; then
        log "INFO" "HTML-Bericht wird erstellt."
    fi
}

# Funktion zum Ausführen eines Testskripts
run_test_script() {
    local test_name=$1
    local test_script=$2
    local test_result_file="$TEST_RESULTS_DIR/${test_name}_result.txt"
    
    if [ "$SPECIFIC_TEST" != "all" ] && [ "$SPECIFIC_TEST" != "$test_name" ]; then
        log "INFO" "Überspringe Test '$test_name' (nicht angefordert)."
        return 0
    fi
    
    log "TEST" "Starte Test: $test_name"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    local args=""
    [ "$VERBOSE" = true ] && args="$args --verbose"
    
    local start_time=$(date +%s)
    
    # Führe Test aus und erfasse Ergebnis
    if $test_script $args; then
        local status=$?
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log "INFO" "Test '$test_name' erfolgreich abgeschlossen (Dauer: ${duration}s)."
        echo "success:$test_name:$duration" > "$test_result_file"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        local status=$?
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log "ERROR" "Test '$test_name' fehlgeschlagen mit Exit-Code $status (Dauer: ${duration}s)."
        echo "failure:$test_name:$duration:$status" > "$test_result_file"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Funktion zum parallelen Ausführen mehrerer Tests
run_tests_parallel() {
    local test_scripts=("$@")
    local pids=()
    local names=()
    
    log "STEP" "Starte parallele Testausführung..."
    
    # Starte alle Tests parallel
    for ((i=0; i<${#test_scripts[@]}; i+=2)); do
        local test_name="${test_scripts[i]}"
        local test_script="${test_scripts[i+1]}"
        
        if [ "$SPECIFIC_TEST" != "all" ] && [ "$SPECIFIC_TEST" != "$test_name" ]; then
            log "INFO" "Überspringe Test '$test_name' (nicht angefordert)."
            continue
        fi
        
        log "TEST" "Starte Test im Hintergrund: $test_name"
        
        # Starte den Test im Hintergrund
        local args=""
        [ "$VERBOSE" = true ] && args="$args --verbose"
        
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        
        # Führe Test in Subshell im Hintergrund aus
        (
            local test_result_file="$TEST_RESULTS_DIR/${test_name}_result.txt"
            local start_time=$(date +%s)
            
            if $test_script $args; then
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                echo "success:$test_name:$duration" > "$test_result_file"
                exit 0
            else
                local status=$?
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                echo "failure:$test_name:$duration:$status" > "$test_result_file"
                exit $status
            fi
        ) &
        
        pids+=($!)
        names+=("$test_name")
    done
    
    # Warte auf Abschluss aller Tests
    log "STEP" "Warte auf Abschluss paralleler Tests..."
    
    for ((i=0; i<${#pids[@]}; i++)); do
        local pid="${pids[i]}"
        local name="${names[i]}"
        local test_result_file="$TEST_RESULTS_DIR/${name}_result.txt"
        
        if wait $pid; then
            if [ -f "$test_result_file" ] && grep -q "^success:" "$test_result_file"; then
                local duration=$(grep "^success:" "$test_result_file" | cut -d':' -f3)
                log "INFO" "Test '$name' erfolgreich abgeschlossen (Dauer: ${duration}s)."
                PASSED_TESTS=$((PASSED_TESTS + 1))
            else
                log "ERROR" "Test '$name' fehlgeschlagen (kein gültiges Ergebnis)."
                FAILED_TESTS=$((FAILED_TESTS + 1))
            fi
        else
            if [ -f "$test_result_file" ] && grep -q "^failure:" "$test_result_file"; then
                local duration=$(grep "^failure:" "$test_result_file" | cut -d':' -f3)
                local status=$(grep "^failure:" "$test_result_file" | cut -d':' -f4)
                log "ERROR" "Test '$name' fehlgeschlagen mit Exit-Code $status (Dauer: ${duration}s)."
            else
                log "ERROR" "Test '$name' fehlgeschlagen (kein gültiges Ergebnis)."
            fi
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    done
    
    log "STEP" "Parallele Testausführung abgeschlossen."
}

# Funktion zum Erstellen eines HTML-Berichts der Testergebnisse
generate_html_report() {
    log "STEP" "Erstelle HTML-Bericht der Testergebnisse..."
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local total_duration=0
    local result_files=("$TEST_RESULTS_DIR"/*_result.txt)
    local test_details=""
    
    # Sammle Testergebnisse
    for result_file in "${result_files[@]}"; do
        if [ -f "$result_file" ]; then
            local test_name=$(basename "$result_file" _result.txt)
            
            if grep -q "^success:" "$result_file"; then
                local duration=$(grep "^success:" "$result_file" | cut -d':' -f3)
                total_duration=$((total_duration + duration))
                local status_color="green"
                local status_text="Erfolgreich"
                
                test_details+="
                <tr>
                  <td>$test_name</td>
                  <td><span style=\"color:$status_color\">$status_text</span></td>
                  <td>${duration}s</td>
                  <td>-</td>
                </tr>"
            elif grep -q "^failure:" "$result_file"; then
                local content=$(cat "$result_file")
                local duration=$(echo "$content" | cut -d':' -f3)
                local exit_code=$(echo "$content" | cut -d':' -f4)
                total_duration=$((total_duration + duration))
                local status_color="red"
                local status_text="Fehlgeschlagen"
                
                test_details+="
                <tr>
                  <td>$test_name</td>
                  <td><span style=\"color:$status_color\">$status_text</span></td>
                  <td>${duration}s</td>
                  <td>$exit_code</td>
                </tr>"
            fi
        fi
    done
    
    # Generiere HTML-Bericht
    cat > "$HTML_REPORT_FILE" <<HTML_REPORT
<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Code-Server E2E Test-Bericht</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    h1 { color: #333; }
    table { border-collapse: collapse; width: 100%; margin-top: 20px; }
    th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
    th { background-color: #f2f2f2; }
    .summary { margin: 20px 0; padding: 15px; background-color: #f8f8f8; border-radius: 5px; }
    .passed { color: green; }
    .failed { color: red; }
    .timestamp { color: #666; font-size: 0.9em; }
  </style>
</head>
<body>
  <h1>Code-Server E2E Test-Bericht</h1>
  <p class="timestamp">Erstellt am: $timestamp</p>
  
  <div class="summary">
    <h2>Zusammenfassung</h2>
    <p>Gesamtanzahl Tests: $TOTAL_TESTS</p>
    <p class="passed">Erfolgreiche Tests: $PASSED_TESTS</p>
    <p class="failed">Fehlgeschlagene Tests: $FAILED_TESTS</p>
    <p>Gesamtdauer: ${total_duration}s</p>
  </div>
  
  <h2>Testergebnisse im Detail</h2>
  <table>
    <thead>
      <tr>
        <th>Test</th>
        <th>Status</th>
        <th>Dauer</th>
        <th>Exit-Code</th>
      </tr>
    </thead>
    <tbody>
      $test_details
    </tbody>
  </table>
</body>
</html>
HTML_REPORT
    
    log "INFO" "HTML-Bericht erstellt: $HTML_REPORT_FILE"
}

# Funktion zum Anzeigen der Testergebnisse
show_test_results() {
    echo ""
    log "TEST" "====== E2E-Testergebnisse ======"
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

# Funktion zur Prüfung der Testskripte
check_test_scripts() {
    log "STEP" "Prüfe Verfügbarkeit der Testskripte..."
    local missing_scripts=false
    
    local required_scripts=(
        "$SCRIPT_DIR/test-code-server-tailscale.sh"
        "$SCRIPT_DIR/test-code-server-pwa.sh"
        "$SCRIPT_DIR/test-code-server-logs.sh"
    )
    
    # Prüfe auch das Setup-Skript
    local setup_script="$SCRIPT_DIR/setup-test-environment.sh"
    if [ ! -f "$setup_script" ]; then
        log "ERROR" "Setup-Skript nicht gefunden: $setup_script"
        missing_scripts=true
    elif [ ! -x "$setup_script" ]; then
        log "WARN" "Setup-Skript nicht ausführbar: $setup_script"
        log "STEP" "Setze ausführbare Berechtigung für: $setup_script"
        chmod +x "$setup_script" || log "ERROR" "Konnte Berechtigungen nicht setzen für: $setup_script"
    else
        log "INFO" "Setup-Skript gefunden: $setup_script"
    fi
    
    for script in "${required_scripts[@]}"; do
        if [ ! -f "$script" ]; then
            log "ERROR" "Testskript nicht gefunden: $script"
            missing_scripts=true
        elif [ ! -x "$script" ]; then
            log "WARN" "Testskript nicht ausführbar: $script"
            log "STEP" "Setze ausführbare Berechtigung für: $script"
            chmod +x "$script" || log "ERROR" "Konnte Berechtigungen nicht setzen für: $script"
        else
            log "INFO" "Testskript gefunden: $script"
        fi
    done
    
    if [ "$missing_scripts" = true ]; then
        log "ERROR" "Einige Testskripte fehlen. Überprüfen Sie die Installation."
        return 1
    fi
    
    log "INFO" "Alle Testskripte sind vorhanden und ausführbar."
    return 0
}

# Funktion zur Vorbereitung der Testumgebung
prepare_test_environment() {
    log "STEP" "Bereite Testumgebung vor..."
    local setup_script="$SCRIPT_DIR/setup-test-environment.sh"
    local setup_args=""
    
    # Bereite Argumente für Setup-Skript vor
    [ "$VERBOSE" = true ] && setup_args="$setup_args --verbose"
    
    # Führe Setup-Skript aus
    log "INFO" "Führe Setup-Skript aus: $setup_script $setup_args"
    if ! $setup_script $setup_args; then
        log "ERROR" "Einrichtung der Testumgebung fehlgeschlagen."
        return 1
    fi
    
    # Lese Umgebungskonfiguration ein
    local env_dir="/tmp/code-server-test-env"
    
    # Lese Code-Server-Port ein, wenn verfügbar
    if [ -f "$env_dir/code_server_port.txt" ]; then
        CODE_SERVER_PORT=$(cat "$env_dir/code_server_port.txt")
        log "INFO" "Verwende Code-Server-Port aus Testumgebung: $CODE_SERVER_PORT"
        # Exportiere die Variable, damit sie für Subprozesse verfügbar ist
        export CODE_SERVER_PORT
    fi
    
    # Lese Tailscale-IP ein, wenn verfügbar
    if [ -f "$env_dir/tailscale_ip.txt" ]; then
        TAILSCALE_IP=$(cat "$env_dir/tailscale_ip.txt")
        log "INFO" "Verwende Tailscale-IP aus Testumgebung: $TAILSCALE_IP"
        # Exportiere die Variable, damit sie für Subprozesse verfügbar ist
        export TAILSCALE_IP
    fi
    
    log "INFO" "Testumgebung erfolgreich vorbereitet."
    return 0
}

#######################################
# Hauptfunktion
#######################################

main() {
    log "TEST" "==== Starte Code-Server E2E-Tests ===="
    
    init_test_env
    parse_args "$@"
    
    # Prüfe, ob Testskripte vorhanden sind
    check_test_scripts || {
        log "ERROR" "Testskripte-Prüfung fehlgeschlagen. Beende Tests."
        exit 1
    }
    
    # Bereite Testumgebung vor
    prepare_test_environment || {
        log "ERROR" "Vorbereitung der Testumgebung fehlgeschlagen. Weitere Tests könnten eingeschränkt sein."
        # Wir brechen nicht komplett ab, um robuster zu sein
    }
    
    # Erstelle Array mit Tests und den entsprechenden Skriptpfaden
    local tests=(
        "tailscale" "$SCRIPT_DIR/test-code-server-tailscale.sh"
        "pwa" "$SCRIPT_DIR/test-code-server-pwa.sh"
        "logs" "$SCRIPT_DIR/test-code-server-logs.sh"
    )
    
    local failed=0
    
    # Führe Tests entweder parallel oder sequentiell aus
    if [ "$PARALLEL_EXECUTION" = true ]; then
        run_tests_parallel "${tests[@]}" || failed=1
    else
        for ((i=0; i<${#tests[@]}; i+=2)); do
            run_test_script "${tests[i]}" "${tests[i+1]}" || failed=1
        done
    fi
    
    show_test_results
    
    # Erstelle HTML-Bericht, wenn angefordert
    if [ "$GENERATE_HTML_REPORT" = true ]; then
        generate_html_report
    fi
    
    # Speichere das finale Log
    if [ -f "$TEST_LOG_FILE" ]; then
        if [ -w "$(dirname "$FINAL_LOG_FILE")" ]; then
            cp "$TEST_LOG_FILE" "$FINAL_LOG_FILE" 2>/dev/null && log "INFO" "Finale Log-Datei: $FINAL_LOG_FILE"
        else
            log "WARN" "Konnte finale Log-Datei nicht schreiben: $FINAL_LOG_FILE"
            log "INFO" "Temporäre Log-Datei: $TEST_LOG_FILE"
        fi
        
        # Komprimiere alte Logs, falls nötig
        local final_log_dir=$(dirname "$FINAL_LOG_FILE")
        if [ -d "$final_log_dir" ]; then
            local old_logs=$(find "$final_log_dir" -name "devsystem-e2e-tests-*.log" -type f 2>/dev/null)
            if [ -n "$old_logs" ] && command -v gzip &>/dev/null; then
                log "INFO" "Komprimiere alte Log-Dateien..."
                echo "$old_logs" | xargs -r gzip -f 2>/dev/null || true
            fi
        fi
        
        # Erstelle datierte Kopie des Logs
        local date_suffix=$(date '+%Y%m%d-%H%M%S')
        local dated_log_file="${FINAL_LOG_FILE%.log}-$date_suffix.log"
        cp "$TEST_LOG_FILE" "$dated_log_file" 2>/dev/null && log "INFO" "Datierte Log-Kopie: $dated_log_file"
    fi
    
    log "TEST" "==== Code-Server E2E-Tests abgeschlossen ===="
    
    if [ $FAILED_TESTS -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"