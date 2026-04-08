#!/bin/bash
#
# Tailscale E2E-Testskript für DevSystem
# Dieses Skript führt umfassende Tests für die Tailscale-Installation und -Konfiguration durch
#
# Version: 1.0
# Autor: DevSystem Team
# Datum: $(date +%Y-%m-%d)
#
# Funktionen:
# - Überprüfung der erfolgreichen Installation von Tailscale
# - Test der Verbindung zum Tailscale-Netzwerk
# - Überprüfung der ACL-Konfiguration
# - Test der DNS-Konfiguration
# - Überprüfung der Logging- und Monitoring-Konfiguration
# - Validierung der Backup-Konfiguration
#
# Verwendung: sudo bash test-tailscale.sh [--verbose] [--test=TESTNAME]

# Fehler bei der Ausführung beenden das Skript
set -e

# Konfigurationsoptionen
VERBOSE=false
SPECIFIC_TEST=""
TEST_RESULTS_DIR="/tmp/tailscale-test-results"
TEST_LOG_FILE="$TEST_RESULTS_DIR/test-results.log"
PING_TARGET="example.com"  # Ersetzen Sie dies durch einen tatsächlichen Hostnamen im Tailnet

# Farbdefinitionen für Terminal-Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Testzähler
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

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
    esac
    
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message${NC}" | tee -a "$TEST_LOG_FILE"
}

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
                echo "Verwendung: sudo bash test-tailscale.sh [--verbose] [--test=TESTNAME]"
                echo ""
                echo "Optionen:"
                echo "  --verbose             Ausführliche Ausgabe aktivieren"
                echo "  --test=TESTNAME       Nur einen bestimmten Test ausführen"
                echo "                        Gültige Testnamen: installation, connection, acl, dns, logging, backup"
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

#######################################
# 1. Test: Überprüfung der erfolgreichen Installation von Tailscale
#######################################

test_installation() {
    log "TEST" "Überprüfe die Installation von Tailscale..."
    
    # 1.1 Prüfe, ob der Tailscale-Befehl verfügbar ist
    if ! command -v tailscale &> /dev/null; then
        log "ERROR" "Tailscale ist nicht installiert. Der Befehl 'tailscale' wurde nicht gefunden."
        return 1
    else
        log "INFO" "Tailscale-Befehl ist verfügbar."
    fi
    
    # 1.2 Prüfe, ob der Tailscale-Dienst installiert ist
    if ! systemctl list-unit-files | grep -q tailscaled; then
        log "ERROR" "Tailscale-Dienst ist nicht installiert."
        return 1
    else
        log "INFO" "Tailscale-Dienst ist installiert."
    fi
    
    # 1.3 Prüfe, ob der Tailscale-Dienst läuft
    if ! systemctl is-active --quiet tailscaled; then
        log "ERROR" "Tailscale-Dienst läuft nicht."
        return 1
    else
        log "INFO" "Tailscale-Dienst läuft."
    fi
    
    # 1.4 Prüfe, ob der Tailscale-Dienst beim Systemstart aktiviert ist
    if ! systemctl is-enabled --quiet tailscaled; then
        log "WARN" "Tailscale-Dienst ist nicht für den Systemstart aktiviert."
    else
        log "INFO" "Tailscale-Dienst ist für den Systemstart aktiviert."
    fi
    
    # 1.5 Prüfe die Version von Tailscale
    local tailscale_version=$(tailscale version 2>/dev/null || echo "Unbekannt")
    log "INFO" "Tailscale-Version: $tailscale_version"
    
    # 1.6 Prüfe die Konfigurationsdateien
    if [ ! -d "/etc/tailscale" ]; then
        log "WARN" "Tailscale-Konfigurationsverzeichnis existiert nicht."
    else
        log "INFO" "Tailscale-Konfigurationsverzeichnis existiert."
    fi
    
    # 1.7 Prüfe die Statuskonfiguration
    if [ ! -f "/var/lib/tailscale/tailscaled.state" ]; then
        log "WARN" "Tailscale-Statusdatei existiert nicht."
    else
        log "INFO" "Tailscale-Statusdatei existiert."
    fi
    
    return 0
}

#######################################
# 2. Test: Test der Verbindung zum Tailscale-Netzwerk
#######################################

test_connection() {
    log "TEST" "Überprüfe die Verbindung zum Tailscale-Netzwerk..."
    
    # 2.1 Prüfe den Verbindungsstatus
    local status_output=$(tailscale status 2>/dev/null)
    
    if ! echo "$status_output" | grep -q "Connected"; then
        log "ERROR" "Tailscale ist nicht mit dem Netzwerk verbunden."
        return 1
    else
        log "INFO" "Tailscale ist mit dem Netzwerk verbunden."
    fi
    
    # 2.2 Prüfe die Tailscale-IP-Adresse
    local ip=$(tailscale ip -4 2>/dev/null || echo "")
    
    if [ -z "$ip" ]; then
        log "ERROR" "Konnte keine Tailscale-IP-Adresse abrufen."
        return 1
    else
        log "INFO" "Tailscale-IP-Adresse: $ip"
        
        # Prüfe, ob die IP im erwarteten Bereich liegt (100.64.0.0/10)
        if ! [[ $ip =~ ^100\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            log "WARN" "Tailscale-IP-Adresse liegt nicht im erwarteten Bereich (100.64.0.0/10)."
        fi
    fi
    
    # 2.3 Prüfe Netzwerkverbindung mit netcheck
    log "INFO" "Führe Netzwerkprüfung durch..."
    
    if ! tailscale netcheck > "$TEST_RESULTS_DIR/netcheck_output.txt" 2>&1; then
        log "WARN" "Netzwerkprüfung hat Probleme festgestellt."
        
        if [ "$VERBOSE" = true ]; then
            log "INFO" "Netcheck-Ausgabe:"
            cat "$TEST_RESULTS_DIR/netcheck_output.txt" | tee -a "$TEST_LOG_FILE"
        fi
    else
        log "INFO" "Netzwerkprüfung erfolgreich."
        
        # Prüfe, ob DERP-Server erreichbar sind
        if ! grep -q "DERP" "$TEST_RESULTS_DIR/netcheck_output.txt"; then
            log "WARN" "DERP-Server scheinen nicht erreichbar zu sein."
        else
            log "INFO" "DERP-Server sind erreichbar."
        fi
    fi
    
    # 2.4 Prüfe Verbindung zu anderen Geräten im Tailnet (optional, falls PING_TARGET konfiguriert ist)
    if [ -n "$PING_TARGET" ] && [ "$PING_TARGET" != "example.com" ]; then
        log "INFO" "Teste Ping zu $PING_TARGET..."
        
        if ! tailscale ping -c 3 "$PING_TARGET" > "$TEST_RESULTS_DIR/ping_output.txt" 2>&1; then
            log "WARN" "Ping zu $PING_TARGET fehlgeschlagen."
            
            if [ "$VERBOSE" = true ]; then
                log "INFO" "Ping-Ausgabe:"
                cat "$TEST_RESULTS_DIR/ping_output.txt" | tee -a "$TEST_LOG_FILE"
            fi
        else
            local ping_latency=$(grep -o "[0-9.]* ms" "$TEST_RESULTS_DIR/ping_output.txt" | head -n1)
            log "INFO" "Ping zu $PING_TARGET erfolgreich. Latenz: $ping_latency"
        fi
    else
        log "WARN" "Kein PING_TARGET konfiguriert oder Standardwert wird verwendet. Überspringe Ping-Test."
    fi
    
    return 0
}

#######################################
# 3. Test: Überprüfung der ACL-Konfiguration
#######################################

test_acl() {
    log "TEST" "Überprüfe die ACL-Konfiguration..."
    
    # 3.1 Prüfe, ob ACL-Konfigurationsdateien existieren
    if [ ! -d "/etc/tailscale/acls" ]; then
        log "WARN" "ACL-Konfigurationsverzeichnis existiert nicht."
    else
        log "INFO" "ACL-Konfigurationsverzeichnis existiert."
        
        # Prüfe, ob mindestens eine ACL-Datei existiert
        if ! find /etc/tailscale/acls -name "*.json" | grep -q .; then
            log "WARN" "Keine ACL-Konfigurationsdateien gefunden."
        else
            local acl_files=$(find /etc/tailscale/acls -name "*.json" | wc -l)
            log "INFO" "Gefundene ACL-Konfigurationsdateien: $acl_files"
            
            # Prüfe, ob die Standardkonfigurationsdatei existiert
            if [ -f "/etc/tailscale/acls/default_acl.json" ]; then
                log "INFO" "Standard-ACL-Konfigurationsdatei existiert."
                
                # Validiere die JSON-Syntax
                if ! jq empty /etc/tailscale/acls/default_acl.json 2>/dev/null; then
                    log "ERROR" "ACL-Konfigurationsdatei enthält ungültiges JSON."
                else
                    log "INFO" "ACL-Konfigurationsdatei enthält gültiges JSON."
                    
                    # Prüfe, ob die ACL-Datei mindestens eine Regel enthält
                    if ! jq -e '.acls' /etc/tailscale/acls/default_acl.json > /dev/null 2>&1; then
                        log "WARN" "ACL-Konfigurationsdatei enthält keine ACL-Regeln."
                    else
                        local acl_count=$(jq '.acls | length' /etc/tailscale/acls/default_acl.json)
                        log "INFO" "ACL-Regeln in der Konfigurationsdatei: $acl_count"
                    fi
                fi
            else
                log "WARN" "Standard-ACL-Konfigurationsdatei existiert nicht."
            fi
        fi
    fi
    
    # 3.2 Prüfe Firewall-Konfiguration für Tailscale
    log "INFO" "Überprüfe Firewall-Konfiguration für Tailscale..."
    
    if ! command -v ufw &> /dev/null; then
        log "WARN" "UFW ist nicht installiert. Kann Firewall-Konfiguration nicht überprüfen."
    else
        # Prüfe, ob UFW aktiviert ist
        if ! ufw status | grep -q "Status: active"; then
            log "WARN" "UFW ist nicht aktiviert."
        else
            log "INFO" "UFW ist aktiviert."
            
            # Prüfe, ob Tailscale-Regeln existieren
            if ! ufw status | grep -q "tailscale0"; then
                log "WARN" "Keine Tailscale-spezifischen Firewall-Regeln gefunden."
            else
                log "INFO" "Tailscale-spezifische Firewall-Regeln gefunden."
            fi
            
            # Prüfe, ob der Tailscale-Port freigegeben ist
            if ! ufw status | grep -q "41641/udp"; then
                log "WARN" "Tailscale UDP-Port (41641) ist nicht in der Firewall freigegeben."
            else
                log "INFO" "Tailscale UDP-Port (41641) ist in der Firewall freigegeben."
            fi
        fi
    fi
    
    # 3.3 Simuliere ACL-Tests (Hinweis: Echte ACL-Tests würden Zugriffstests mit verschiedenen Benutzerrollen erfordern)
    log "INFO" "Hinweis: Vollständige ACL-Tests erfordern Zugriffsprüfungen mit verschiedenen Benutzerrollen."
    log "INFO" "Diese würden in einer Produktionsumgebung manuell oder mit speziellen Testbenutzern durchgeführt."
    
    return 0
}

#######################################
# 4. Test: Test der DNS-Konfiguration
#######################################

test_dns() {
    log "TEST" "Überprüfe die DNS-Konfiguration..."
    
    # 4.1 Prüfe, ob MagicDNS aktiviert ist
    if ! tailscale status --json | grep -q '"MagicDNS":true'; then
        log "WARN" "MagicDNS ist nicht aktiviert."
    else
        log "INFO" "MagicDNS ist aktiviert."
    fi
    
    # 4.2 Prüfe lokale DNS-Konfigurationsdatei
    if [ ! -f "/etc/tailscale/local_dns.conf" ]; then
        log "WARN" "Lokale DNS-Konfigurationsdatei existiert nicht."
    else
        log "INFO" "Lokale DNS-Konfigurationsdatei existiert."
        
        # Prüfe den Inhalt der DNS-Konfigurationsdatei
        local dns_entries=$(grep -v "^#" /etc/tailscale/local_dns.conf | grep -v "^$" | wc -l)
        log "INFO" "DNS-Einträge in der lokalen Konfigurationsdatei: $dns_entries"
    fi
    
    # 4.3 Prüfe DNS-Auflösung mit dem Tailscale-DNS-Server
    log "INFO" "Teste DNS-Auflösung mit Tailscale DNS..."
    
    # Prüfe Auflösung des eigenen Hostnamens
    local hostname=$(hostname)
    if ! dig @100.100.100.100 "$hostname" +short | grep -q "^100\."; then
        log "WARN" "Konnte eigenen Hostname ($hostname) nicht über Tailscale DNS auflösen."
    else
        local resolved_ip=$(dig @100.100.100.100 "$hostname" +short)
        log "INFO" "Hostname $hostname wurde zu $resolved_ip aufgelöst."
    fi
    
    # 4.4 Prüfe Auflösung von benutzerdefinierten Namen
    # Hinweis: Dies erfordert konfigurierte Hostnamen im Tailnet
    local custom_domains=(
        "code.devsystem.internal"
        "api.devsystem.internal"
    )
    
    for domain in "${custom_domains[@]}"; do
        log "INFO" "Teste Auflösung von $domain..."
        
        if ! dig @100.100.100.100 "$domain" +short &> /dev/null; then
            log "WARN" "Konnte $domain nicht über Tailscale DNS auflösen."
        else
            local resolved_ip=$(dig @100.100.100.100 "$domain" +short)
            if [ -z "$resolved_ip" ]; then
                log "WARN" "Domain $domain wurde zu keiner IP aufgelöst."
            else
                log "INFO" "Domain $domain wurde zu $resolved_ip aufgelöst."
            fi
        fi
    done
    
    # 4.5 Teste die Split-DNS-Funktionalität (optional)
    log "INFO" "Teste Split-DNS-Funktionalität..."
    
    # Prüfe Auflösung einer externen Domain
    if ! dig @100.100.100.100 "example.com" +short &> /dev/null; then
        log "WARN" "Konnte externe Domain (example.com) nicht über Tailscale DNS auflösen."
    else
        log "INFO" "Externe Domain (example.com) wurde erfolgreich aufgelöst."
    fi
    
    return 0
}

#######################################
# 5. Test: Überprüfung der Logging- und Monitoring-Konfiguration
#######################################

test_logging() {
    log "TEST" "Überprüfe die Logging- und Monitoring-Konfiguration..."
    
    # 5.1 Prüfe Monitoring-Verzeichnis
    if [ ! -d "/opt/tailscale-monitoring" ]; then
        log "WARN" "Tailscale-Monitoring-Verzeichnis existiert nicht."
    else
        log "INFO" "Tailscale-Monitoring-Verzeichnis existiert."
        
        # 5.2 Prüfe Monitoring-Skript
        if [ ! -f "/opt/tailscale-monitoring/tailscale-monitor.sh" ]; then
            log "WARN" "Tailscale-Monitoring-Skript existiert nicht."
        else
            log "INFO" "Tailscale-Monitoring-Skript existiert."
            
            # Prüfe Ausführbarkeit
            if [ ! -x "/opt/tailscale-monitoring/tailscale-monitor.sh" ]; then
                log "WARN" "Tailscale-Monitoring-Skript ist nicht ausführbar."
            else
                log "INFO" "Tailscale-Monitoring-Skript ist ausführbar."
            fi
        fi
    fi
    
    # 5.3 Prüfe Cron-Konfiguration für Monitoring
    if [ ! -f "/etc/cron.d/tailscale-monitor" ]; then
        log "WARN" "Tailscale-Monitoring-Cron-Konfiguration existiert nicht."
    else
        log "INFO" "Tailscale-Monitoring-Cron-Konfiguration existiert."
        
        # Prüfe, ob der Cron-Job korrekt konfiguriert ist
        if ! grep -q "tailscale-monitor.sh" /etc/cron.d/tailscale-monitor; then
            log "WARN" "Tailscale-Monitoring-Cron-Job scheint nicht korrekt konfiguriert zu sein."
        else
            log "INFO" "Tailscale-Monitoring-Cron-Job ist konfiguriert."
        fi
    fi
    
    # 5.4 Prüfe Log-Rotation
    if [ ! -f "/etc/logrotate.d/tailscale-monitor" ]; then
        log "WARN" "Tailscale-Log-Rotation-Konfiguration existiert nicht."
    else
        log "INFO" "Tailscale-Log-Rotation-Konfiguration existiert."
    fi
    
    # 5.5 Prüfe Tailscale-Logs
    log "INFO" "Überprüfe Tailscale-Logs..."
    
    # Prüfe, ob es Log-Einträge für Tailscale gibt
    if ! journalctl -u tailscaled -n 10 &> /dev/null; then
        log "WARN" "Keine Tailscale-Logs gefunden."
    else
        local log_count=$(journalctl -u tailscaled -n 10 | grep -v "^--" | wc -l)
        log "INFO" "Gefundene Tailscale-Log-Einträge: $log_count"
        
        # Speichere die letzten Log-Einträge zur Analyse
        journalctl -u tailscaled -n 10 > "$TEST_RESULTS_DIR/tailscale_logs.txt"
        
        if [ "$VERBOSE" = true ]; then
            log "INFO" "Letzte Tailscale-Logs:"
            cat "$TEST_RESULTS_DIR/tailscale_logs.txt" | tee -a "$TEST_LOG_FILE"
        fi
    fi
    
    # 5.6 Prüfe Promtail-Konfiguration (falls vorhanden)
    if [ ! -d "/etc/promtail" ]; then
        log "INFO" "Promtail-Verzeichnis nicht gefunden (optional)."
    else
        log "INFO" "Promtail-Verzeichnis gefunden."
        
        if [ ! -f "/etc/promtail/tailscale.yaml" ]; then
            log "WARN" "Promtail-Konfiguration für Tailscale nicht gefunden."
        else
            log "INFO" "Promtail-Konfiguration für Tailscale gefunden."
        fi
    fi
    
    return 0
}

#######################################
# 6. Test: Validierung der Backup-Konfiguration
#######################################

test_backup() {
    log "TEST" "Überprüfe die Backup-Konfiguration..."
    
    # 6.1 Prüfe Backup-Verzeichnis
    if [ ! -d "/var/backups/tailscale" ]; then
        log "WARN" "Tailscale-Backup-Verzeichnis existiert nicht."
    else
        log "INFO" "Tailscale-Backup-Verzeichnis existiert."
        
        # Prüfe, ob Backup-Dateien existieren
        local backup_files=$(find /var/backups/tailscale -name "tailscale-config-*.tar.gz" | wc -l)
        log "INFO" "Gefundene Backup-Dateien: $backup_files"
    fi
    
    # 6.2 Prüfe Backup-Skript
    if [ ! -f "/usr/local/bin/tailscale-backup.sh" ]; then
        log "WARN" "Tailscale-Backup-Skript existiert nicht."
    else
        log "INFO" "Tailscale-Backup-Skript existiert."
        
        # Prüfe Ausführbarkeit
        if [ ! -x "/usr/local/bin/tailscale-backup.sh" ]; then
            log "WARN" "Tailscale-Backup-Skript ist nicht ausführbar."
        else
            log "INFO" "Tailscale-Backup-Skript ist ausführbar."
        fi
    fi
    
    # 6.3 Prüfe Wiederherstellungsskript
    if [ ! -f "/usr/local/bin/tailscale-restore.sh" ]; then
        log "WARN" "Tailscale-Wiederherstellungsskript existiert nicht."
    else
        log "INFO" "Tailscale-Wiederherstellungsskript existiert."
        
        # Prüfe Ausführbarkeit
        if [ ! -x "/usr/local/bin/tailscale-restore.sh" ]; then
            log "WARN" "Tailscale-Wiederherstellungsskript ist nicht ausführbar."
        else
            log "INFO" "Tailscale-Wiederherstellungsskript ist ausführbar."
        fi
    fi
    
    # 6.4 Prüfe Cron-Konfiguration für Backup
    if [ ! -f "/etc/cron.d/tailscale-backup" ]; then
        log "WARN" "Tailscale-Backup-Cron-Konfiguration existiert nicht."
    else
        log "INFO" "Tailscale-Backup-Cron-Konfiguration existiert."
        
        # Prüfe, ob der Cron-Job korrekt konfiguriert ist
        if ! grep -q "tailscale-backup.sh" /etc/cron.d/tailscale-backup; then
            log "WARN" "Tailscale-Backup-Cron-Job scheint nicht korrekt konfiguriert zu sein."
        else
            log "INFO" "Tailscale-Backup-Cron-Job ist konfiguriert."
        fi
    fi
    
    # 6.5 Optional: Teste die Backup-Funktion
    log "INFO" "Hinweis: Ein vollständiger Test der Backup-Funktion würde die Erstellung eines Backups und dessen Wiederherstellung umfassen."
    log "INFO" "Dies wird hier nicht automatisch durchgeführt, um das Produktionssystem nicht zu gefährden."
    
    return 0
}

#######################################
# Hauptfunktion
#######################################

main() {
    log "TEST" "==== Starte Tailscale E2E-Tests ===="
    
    # Initialisierung
    init_test_env
    parse_args "$@"
    
    # Führe Tests durch
    run_test "installation" test_installation
    run_test "connection" test_connection
    run_test "acl" test_acl
    run_test "dns" test_dns
    run_test "logging" test_logging
    run_test "backup" test_backup
    
    # Zeige Testergebnisse
    show_test_results
    
    log "TEST" "==== Tailscale E2E-Tests abgeschlossen ===="
    
    # Exit-Code basierend auf Testergebnissen
    if [ $FAILED_TESTS -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Skript ausführen
main "$@"