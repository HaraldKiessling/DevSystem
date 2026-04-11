#!/bin/bash
#
# DevSystem Code-Server Log-Analyse E2E-Test
# Dieses Skript führt umfassende Tests für die Log-Analyse von Code-Server durch
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
TEST_LOG_FILE="${TEST_RESULTS_DIR}/logs-test-results.log"

# code-server-Konfiguration
CODE_SERVER_USER="codeserver"
CODE_SERVER_CONFIG_DIR="/home/$CODE_SERVER_USER/.config/code-server"
CODE_SERVER_DATA_DIR="/home/$CODE_SERVER_USER/.local/share/code-server"
CODE_SERVER_LOG_DIR="/home/$CODE_SERVER_USER/.local/share/code-server/logs"
LOGS_HISTORY_DAYS=7

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

# Fehlermuster für Analyse
ERROR_PATTERNS=(
    "Error:"
    "Failed"
    "exception"
    "ECONNREFUSED"
    "EACCES"
    "segmentation fault"
    "cannot access"
    "Permission denied"
    "Timeout"
    "is not running"
    "Refused to connect"
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
    
    log "INFO" "Initialisiere Log-Analyse-Tests..."
    
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
            --days=*)
                LOGS_HISTORY_DAYS="${arg#*=}"
                ;;
            --help)
                echo "Verwendung: sudo $0 [--verbose] [--days=N]"
                echo ""
                echo "Optionen:"
                echo "  --verbose             Ausführliche Ausgabe aktivieren"
                echo "  --days=N              Anzahl der Tage für Log-Historie (Standard: 7)"
                echo "  --help                Diese Hilfe anzeigen"
                echo ""
                exit 0
                ;;
        esac
    done
    
    if [ "$VERBOSE" = true ]; then
        log "INFO" "Ausführliche Ausgabe aktiviert."
    fi
    
    log "INFO" "Analysiere Logs der letzten $LOGS_HISTORY_DAYS Tage."
}

# Funktion zum Ausführen eines Tests
run_test() {
    local test_name=$1
    local test_function=$2
    
    log "TEST" "Starte Log-Analyse-Test: $test_name"
    
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
    log "TEST" "====== Log-Analyse Testergebnisse ======"
    log "INFO" "Durchgeführte Tests: $TOTAL_TESTS"
    log "INFO" "Erfolgreiche Tests: $PASSED_TESTS"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        log "INFO" "Fehlgeschlagene Tests: $FAILED_TESTS"
        log "INFO" "Alle Log-Analyse-Tests wurden erfolgreich abgeschlossen!"
    else
        log "ERROR" "Fehlgeschlagene Tests: $FAILED_TESTS"
        log "ERROR" "Einige Log-Analyse-Tests sind fehlgeschlagen. Überprüfen Sie die Logs für Details."
    fi
    
    echo ""
}

#######################################
# Test: Systemd-Logs
#######################################

test_systemd_logs() {
    log "TEST" "Überprüfe Systemd-Logs für code-server..."
    
    local test_failed=false
    local since_param="--since=\"$LOGS_HISTORY_DAYS days ago\""
    
    log "STEP" "Hole code-server Systemd-Logs..."
    if ! journalctl -u code-server $since_param > "$TEST_RESULTS_DIR/code_server_journal.log" 2>&1; then
        log "ERROR" "Konnte Systemd-Logs nicht abrufen."
        return 1
    fi
    
    local log_count=$(wc -l < "$TEST_RESULTS_DIR/code_server_journal.log")
    log "INFO" "Gefundene Log-Einträge: $log_count"
    
    if [ "$log_count" -eq 0 ]; then
        log "WARN" "Keine Log-Einträge für code-server gefunden."
        test_failed=true
    else
        log "INFO" "Log-Einträge für code-server gefunden."
        
        # Analyse der Startzeiten
        log "STEP" "Analysiere Startzeiten..."
        local start_count=$(grep -i "Starting\|started\|Server started" "$TEST_RESULTS_DIR/code_server_journal.log" | wc -l)
        log "INFO" "Anzahl der Starteinträge: $start_count"
        
        if [ "$start_count" -eq 0 ]; then
            log "WARN" "Keine Starteinträge gefunden."
        else
            grep -i "Starting\|started\|Server started" "$TEST_RESULTS_DIR/code_server_journal.log" | head -n 5 > "$TEST_RESULTS_DIR/code_server_starts.log"
            [ "$VERBOSE" = true ] && log "INFO" "Start-Einträge (erste 5):" && cat "$TEST_RESULTS_DIR/code_server_starts.log" | tee -a "$TEST_LOG_FILE"
        fi
        
        # Analyse der Fehlereinträge
        log "STEP" "Analysiere Fehlereinträge..."
        local error_count=0
        for pattern in "${ERROR_PATTERNS[@]}"; do
            local count=$(grep -i "$pattern" "$TEST_RESULTS_DIR/code_server_journal.log" | wc -l)
            error_count=$((error_count + count))
            
            if [ "$count" -gt 0 ] && [ "$VERBOSE" = true ]; then
                log "INFO" "Muster '$pattern' gefunden: $count Einträge"
                grep -i "$pattern" "$TEST_RESULTS_DIR/code_server_journal.log" | head -n 2 | tee -a "$TEST_LOG_FILE"
            fi
        done
        
        if [ "$error_count" -gt 0 ]; then
            log "WARN" "Fehlereinträge gefunden: $error_count"
            
            # Extrahiere die häufigsten Fehler
            log "STEP" "Analysiere häufigste Fehlermuster..."
            local patterns_regex=$(printf "|%s" "${ERROR_PATTERNS[@]}")
            patterns_regex="(${patterns_regex:1})"
            
            grep -i -E "$patterns_regex" "$TEST_RESULTS_DIR/code_server_journal.log" | head -n 20 > "$TEST_RESULTS_DIR/code_server_errors.log"
            
            [ "$VERBOSE" = true ] && log "INFO" "Top-Fehlereinträge:" && cat "$TEST_RESULTS_DIR/code_server_errors.log" | tee -a "$TEST_LOG_FILE"
        else
            log "INFO" "Keine Fehlereinträge gefunden."
        fi
        
        # Überprüfen auf kritische Fehler
        log "STEP" "Prüfe auf kritische Fehler..."
        local critical_patterns=("segmentation fault" "core dumped" "crashed" "not enough memory")
        local critical_count=0
        
        for pattern in "${critical_patterns[@]}"; do
            local count=$(grep -i "$pattern" "$TEST_RESULTS_DIR/code_server_journal.log" | wc -l)
            critical_count=$((critical_count + count))
            
            if [ "$count" -gt 0 ]; then
                log "ERROR" "Kritischer Fehler gefunden: '$pattern' ($count Einträge)"
                [ "$VERBOSE" = true ] && grep -i "$pattern" "$TEST_RESULTS_DIR/code_server_journal.log" | head -n 3 | tee -a "$TEST_LOG_FILE"
                test_failed=true
            fi
        done
        
        if [ "$critical_count" -eq 0 ]; then
            log "INFO" "Keine kritischen Fehler gefunden."
        fi
        
        # Allgemeine Log-Statistiken
        log "STEP" "Erstelle Log-Statistiken..."
        local restart_count=$(grep -i "Starting\|Stopping" "$TEST_RESULTS_DIR/code_server_journal.log" | wc -l)
        log "INFO" "Anzahl der Service-Neustarts: $((restart_count / 2))"
        
        # Die letzten Einträge extrahieren
        log "STEP" "Analysiere letzte Log-Einträge..."
        tail -n 20 "$TEST_RESULTS_DIR/code_server_journal.log" > "$TEST_RESULTS_DIR/code_server_last_entries.log"
        log "INFO" "Letzte 20 Log-Einträge extrahiert."
        
        # Überprüfen ob Service aktuell läuft
        if grep -q "code-server.service: Deactivated successfully" "$TEST_RESULTS_DIR/code_server_last_entries.log" && ! grep -q "code-server.service: Succeeded" "$TEST_RESULTS_DIR/code_server_last_entries.log"; then
            log "WARN" "Service wurde möglicherweise nicht sauber beendet."
        fi
    fi
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# Test: Code-Server interne Logs
#######################################

test_code_server_logs() {
    log "TEST" "Überprüfe Code-Server interne Log-Dateien..."
    
    local test_failed=false
    
    # Überprüfen ob der Log-Ordner existiert
    if [ ! -d "$CODE_SERVER_LOG_DIR" ]; then
        log "INFO" "Code-Server Log-Verzeichnis nicht gefunden: $CODE_SERVER_LOG_DIR"
        
        # Alternativen Pfad versuchen
        CODE_SERVER_LOG_DIR="$CODE_SERVER_DATA_DIR/../code-server/logs"
        log "INFO" "Versuche alternativen Log-Pfad: $CODE_SERVER_LOG_DIR"
        
        if [ ! -d "$CODE_SERVER_LOG_DIR" ]; then
            log "ERROR" "Konnte kein Code-Server Log-Verzeichnis finden."
            return 1
        fi
    fi
    
    log "INFO" "Code-Server Log-Verzeichnis gefunden: $CODE_SERVER_LOG_DIR"
    
    # Liste alle Log-Dateien auf
    log "STEP" "Sammle Code-Server Log-Dateien..."
    local log_files=()
    while IFS= read -r -d $'\0' file; do
        log_files+=("$file")
    done < <(find "$CODE_SERVER_LOG_DIR" -type f -name "*.log" -print0 2>/dev/null)
    
    local log_count=${#log_files[@]}
    log "INFO" "Gefundene Log-Dateien: $log_count"
    
    if [ "$log_count" -eq 0 ]; then
        log "WARN" "Keine Log-Dateien gefunden."
        test_failed=true
    else
        # Analysiere Log-Dateien nach Datum
        log "STEP" "Sortiere Log-Dateien nach Datum..."
        local newest_file=""
        local newest_date=0
        
        for file in "${log_files[@]}"; do
            local file_date=$(stat -c %Y "$file")
            if [ "$file_date" -gt "$newest_date" ]; then
                newest_date=$file_date
                newest_file=$file
            fi
        done
        
        log "INFO" "Neueste Log-Datei: $newest_file ($(date -d @$newest_date '+%Y-%m-%d %H:%M:%S'))"
        
        # Analysiere die neueste Log-Datei
        log "STEP" "Analysiere neueste Log-Datei..."
        cp "$newest_file" "$TEST_RESULTS_DIR/code_server_latest.log"
        
        # Extrahiere Fehler aus der neuesten Log-Datei
        log "STEP" "Extrahiere Fehler aus neuester Log-Datei..."
        local error_count=0
        for pattern in "${ERROR_PATTERNS[@]}"; do
            local count=$(grep -i "$pattern" "$TEST_RESULTS_DIR/code_server_latest.log" | wc -l)
            error_count=$((error_count + count))
            
            if [ "$count" -gt 0 ] && [ "$VERBOSE" = true ]; then
                log "INFO" "Muster '$pattern' gefunden: $count Einträge"
            fi
        done
        
        log "INFO" "Fehlereinträge in neuester Log-Datei: $error_count"
        
        if [ "$error_count" -gt 0 ]; then
            log "STEP" "Extrahiere Top-Fehler..."
            local patterns_regex=$(printf "|%s" "${ERROR_PATTERNS[@]}")
            patterns_regex="(${patterns_regex:1})"
            
            grep -i -E "$patterns_regex" "$TEST_RESULTS_DIR/code_server_latest.log" | head -n 10 > "$TEST_RESULTS_DIR/code_server_latest_errors.log"
            
            [ "$VERBOSE" = true ] && log "INFO" "Top-Fehlereinträge aus neuester Log-Datei:" && cat "$TEST_RESULTS_DIR/code_server_latest_errors.log" | tee -a "$TEST_LOG_FILE"
        fi
        
        # Analysiere Log-Rotation
        log "STEP" "Analysiere Log-Rotation..."
        if [ "$log_count" -gt 1 ]; then
            log "INFO" "Log-Rotation scheint aktiv zu sein ($log_count Dateien)."
            
            # Älteste Log-Datei ermitteln
            local oldest_file=""
            local oldest_date=$(date +%s)
            
            for file in "${log_files[@]}"; do
                local file_date=$(stat -c %Y "$file")
                if [ "$file_date" -lt "$oldest_date" ]; then
                    oldest_date=$file_date
                    oldest_file=$file
                fi
            done
            
            log "INFO" "Älteste Log-Datei: $oldest_file ($(date -d @$oldest_date '+%Y-%m-%d %H:%M:%S'))"
            
            # Log-Alter berechnen
            local now=$(date +%s)
            local age_days=$(( (now - oldest_date) / 86400 ))
            log "INFO" "Alter der ältesten Log-Datei: $age_days Tage"
        else
            log "WARN" "Log-Rotation scheint nicht aktiv zu sein (nur $log_count Datei)."
        fi
        
        # Analysiere Log-Größe
        log "STEP" "Analysiere Log-Größen..."
        local total_size=0
        local max_size=0
        local max_size_file=""
        
        for file in "${log_files[@]}"; do
            local size=$(stat -c %s "$file")
            total_size=$((total_size + size))
            
            if [ "$size" -gt "$max_size" ]; then
                max_size=$size
                max_size_file=$file
            fi
        done
        
        # Konvertiere Größen in lesbare Formate
        local total_size_human=$(numfmt --to=iec-i --suffix=B $total_size)
        local max_size_human=$(numfmt --to=iec-i --suffix=B $max_size)
        
        log "INFO" "Gesamtgröße aller Log-Dateien: $total_size_human"
        log "INFO" "Größte Log-Datei: $max_size_file ($max_size_human)"
        
        # Übermäßige Log-Größe könnte ein Problem darstellen
        if [ "$total_size" -gt 104857600 ]; then # 100 MB
            log "WARN" "Gesamtgröße der Logs ist größer als 100 MB, Was auf ein Rotationsproblem hindeuten könnte."
        fi
    fi
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# Test: OS-Logs für Code-Server
#######################################

test_os_logs() {
    log "TEST" "Überprüfe betriebssystemspezifische Logs für code-server..."
    
    local test_failed=false
    
    log "STEP" "Prüfe syslog nach code-server Einträgen..."
    if [ -f "/var/log/syslog" ]; then
        grep -i "code-server" /var/log/syslog | tail -n 100 > "$TEST_RESULTS_DIR/code_server_syslog.log" 2>/dev/null || true
        local entry_count=$(wc -l < "$TEST_RESULTS_DIR/code_server_syslog.log")
        
        if [ "$entry_count" -gt 0 ]; then
            log "INFO" "Gefundene syslog-Einträge: $entry_count"
            
            # Analysiere auf Fehler
            local error_count=0
            for pattern in "${ERROR_PATTERNS[@]}"; do
                local count=$(grep -i "$pattern" "$TEST_RESULTS_DIR/code_server_syslog.log" | wc -l)
                error_count=$((error_count + count))
            done
            
            if [ "$error_count" -gt 0 ]; then
                log "WARN" "Fehlereinträge in syslog gefunden: $error_count"
                
                # Extrahiere Fehler
                local patterns_regex=$(printf "|%s" "${ERROR_PATTERNS[@]}")
                patterns_regex="(${patterns_regex:1})"
                
                grep -i -E "$patterns_regex" "$TEST_RESULTS_DIR/code_server_syslog.log" | head -n 5 > "$TEST_RESULTS_DIR/code_server_syslog_errors.log"
                
                [ "$VERBOSE" = true ] && log "INFO" "Fehlereinträge in syslog:" && cat "$TEST_RESULTS_DIR/code_server_syslog_errors.log" | tee -a "$TEST_LOG_FILE"
            else
                log "INFO" "Keine Fehlereinträge in syslog gefunden."
            fi
        else
            log "INFO" "Keine Einträge in syslog gefunden."
        fi
    else
        log "INFO" "syslog nicht verfügbar."
    fi
    
    log "STEP" "Prüfe dmesg für relevantet Einträge..."
    dmesg | grep -i "code-server\|node\|codeserver" > "$TEST_RESULTS_DIR/code_server_dmesg.log" 2>/dev/null || true
    local dmesg_count=$(wc -l < "$TEST_RESULTS_DIR/code_server_dmesg.log")
    
    if [ "$dmesg_count" -gt 0 ]; then
        log "INFO" "Gefundene dmesg-Einträge: $dmesg_count"
        
        # Prüfe auf Out-of-Memory oder Segmentation Faults
        if grep -qi "out of memory\|segfault\|killed" "$TEST_RESULTS_DIR/code_server_dmesg.log"; then
            log "ERROR" "Kritische Fehler in dmesg gefunden!"
            grep -i "out of memory\|segfault\|killed" "$TEST_RESULTS_DIR/code_server_dmesg.log" | tee -a "$TEST_LOG_FILE"
            test_failed=true
        else
            [ "$VERBOSE" = true ] && log "INFO" "dmesg-Einträge:" && cat "$TEST_RESULTS_DIR/code_server_dmesg.log" | tee -a "$TEST_LOG_FILE"
        fi
    else
        log "INFO" "Keine relevanten dmesg-Einträge gefunden."
    fi
    
    log "STEP" "Prüfe auth.log für relevante Einträge..."
    if [ -f "/var/log/auth.log" ]; then
        grep -i "codeserver\|code-server" /var/log/auth.log | tail -n 50 > "$TEST_RESULTS_DIR/code_server_auth.log" 2>/dev/null || true
        local auth_count=$(wc -l < "$TEST_RESULTS_DIR/code_server_auth.log")
        
        if [ "$auth_count" -gt 0 ]; then
            log "INFO" "Gefundene auth.log-Einträge: $auth_count"
            
            # Prüfe auf Berechtigungsprobleme
            if grep -qi "permission denied\|failed\|error" "$TEST_RESULTS_DIR/code_server_auth.log"; then
                log "WARN" "Mögliche Berechtigungsprobleme in auth.log gefunden."
                [ "$VERBOSE" = true ] && grep -i "permission denied\|failed\|error" "$TEST_RESULTS_DIR/code_server_auth.log" | head -n 5 | tee -a "$TEST_LOG_FILE"
            fi
        else
            log "INFO" "Keine relevanten auth.log-Einträge gefunden."
        fi
    else
        log "INFO" "auth.log nicht verfügbar."
    fi
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# Test: Ressourcenverbrauch-Logs
#######################################

test_performance_logs() {
    log "TEST" "Analysiere Ressourcenverbrauch aus Logs..."
    
    local test_failed=false
    
    log "STEP" "Sammle aktuelle Ressourcennutzung..."
    ps -u "$CODE_SERVER_USER" -o pid,ppid,%cpu,%mem,cmd > "$TEST_RESULTS_DIR/code_server_processes.log" 2>/dev/null || true
    
    local process_count=$(grep -i "code-server\|node" "$TEST_RESULTS_DIR/code_server_processes.log" | wc -l)
    
    if [ "$process_count" -gt 0 ]; then
        log "INFO" "Gefundene Code-Server-Prozesse: $process_count"
        
        # Extrahiere CPU und Speichernutzung
        local cpu_usage=$(grep -i "code-server\|node" "$TEST_RESULTS_DIR/code_server_processes.log" | awk '{sum+=$3} END {print sum}')
        local mem_usage=$(grep -i "code-server\|node" "$TEST_RESULTS_DIR/code_server_processes.log" | awk '{sum+=$4} END {print sum}')
        
        log "INFO" "Aktuelle CPU-Nutzung: ${cpu_usage}%"
        log "INFO" "Aktuelle Speichernutzung: ${mem_usage}%"
        
        # Warne bei hoher Ressourcenbelastung
        if (( $(echo "$cpu_usage > 100" | bc -l) )); then
            log "WARN" "Hohe CPU-Nutzung erkannt (${cpu_usage}%)."
        fi
        
        if (( $(echo "$mem_usage > 30" | bc -l) )); then
            log "WARN" "Hohe Speichernutzung erkannt (${mem_usage}%)."
        fi
        
        [ "$VERBOSE" = true ] && log "INFO" "Prozessinformationen:" && cat "$TEST_RESULTS_DIR/code_server_processes.log" | grep -i "code-server\|node" | tee -a "$TEST_LOG_FILE"
    else
        log "WARN" "Keine aktiven Code-Server-Prozesse gefunden."
        test_failed=true
    fi
    
    log "STEP" "Analysiere historischen Ressourcenverbrauch..."
    if [ -f "/var/log/sysstat/sa$(date +%d)" ]; then
        log "INFO" "sysstat-Daten verfügbar."
        
        # Extrahiere Daten aus sar-Logs falls verfügbar
        if command -v sar &> /dev/null; then
            sar -u | tail -n 12 > "$TEST_RESULTS_DIR/system_cpu_usage.log" 2>/dev/null || true
            log "INFO" "CPU-Verlauf extrahiert."
            
            sar -r | tail -n 12 > "$TEST_RESULTS_DIR/system_memory_usage.log" 2>/dev/null || true
            log "INFO" "Speicher-Verlauf extrahiert."
        else
            log "INFO" "sar nicht installiert, überspringe Verlaufsanalyse."
        fi
    else
        log "INFO" "Keine sysstat-Daten verfügbar."
    fi
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# Hauptfunktion
#######################################

main() {
    log "TEST" "==== Starte Log-Analyse-Tests für Code-Server ===="
    
    init_test_env
    parse_args "$@"
    
    run_test "systemd_logs" test_systemd_logs
    run_test "code_server_logs" test_code_server_logs
    run_test "os_logs" test_os_logs
    run_test "performance_logs" test_performance_logs
    
    show_test_results
    
    log "TEST" "==== Log-Analyse-Tests abgeschlossen ===="
    
    if [ $FAILED_TESTS -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"