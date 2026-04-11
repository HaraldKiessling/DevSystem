#!/bin/bash
#
# DevSystem Code-Server Automatisierte Tests Setup
# Dieses Skript richtet automatisierte regelmäßige Tests für Code-Server ein
#
# Version: 1.0
# Autor: DevSystem Team
# Datum: 2026-04-11
#

# Fehler bei der Ausführung beenden das Skript
set -e

# Konfigurationsoptionen
VERBOSE=false
TEST_INTERVAL="daily" # daily, weekly, monthly, custom
CUSTOM_CRON_SCHEDULE="0 3 * * *" # Standard: Täglich um 3 Uhr morgens
EMAIL_NOTIFICATIONS=false
NOTIFICATION_EMAIL=""
TEST_RESULTS_DIR="/var/log/code-server-tests"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_TEST_SCRIPT="$SCRIPTS_DIR/run-code-server-tests.sh"

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
    
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message${NC}"
}

# ============================================================================
# INITIALISIERUNG
# ============================================================================

# Funktion zum Parsen der Kommandozeilenargumente
parse_args() {
    for arg in "$@"; do
        case $arg in
            --verbose)
                VERBOSE=true
                ;;
            --interval=*)
                TEST_INTERVAL="${arg#*=}"
                ;;
            --cron=*)
                CUSTOM_CRON_SCHEDULE="${arg#*=}"
                ;;
            --email-notifications)
                EMAIL_NOTIFICATIONS=true
                ;;
            --email=*)
                NOTIFICATION_EMAIL="${arg#*=}"
                EMAIL_NOTIFICATIONS=true
                ;;
            --help)
                echo "Verwendung: sudo $0 [--verbose] [--interval=INTERVAL] [--cron='CRON_SCHEDULE'] [--email-notifications] [--email=EMAIL]"
                echo ""
                echo "Optionen:"
                echo "  --verbose               Ausführliche Ausgabe aktivieren"
                echo "  --interval=INTERVAL     Testintervall: daily, weekly, monthly, custom (Standard: daily)"
                echo "  --cron='CRON_SCHEDULE'  Benutzerdefinierter Cron-Zeitplan (Standard: '0 3 * * *')"
                echo "  --email-notifications   E-Mail-Benachrichtigungen aktivieren"
                echo "  --email=EMAIL           E-Mail-Adresse für Benachrichtigungen"
                echo "  --help                  Diese Hilfe anzeigen"
                echo ""
                echo "Beispiele:"
                echo "  $0 --interval=weekly"
                echo "  $0 --cron='0 4 * * 0' --email=admin@example.com"
                echo ""
                exit 0
                ;;
        esac
    done
    
    if [ "$VERBOSE" = true ]; then
        log "INFO" "Ausführliche Ausgabe aktiviert."
    fi
    
    if [ "$EMAIL_NOTIFICATIONS" = true ] && [ -z "$NOTIFICATION_EMAIL" ]; then
        log "WARN" "E-Mail-Benachrichtigungen aktiviert, aber keine E-Mail-Adresse angegeben. Bitte geben Sie eine E-Mail-Adresse mit --email=EMAIL an."
        exit 1
    fi
}

# Root-Berechtigungen prüfen
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log "ERROR" "Dieses Skript muss als Root ausgeführt werden. Bitte verwenden Sie 'sudo'."
        exit 1
    fi
}

# Systemanforderungen prüfen
check_requirements() {
    log "STEP" "Prüfe Systemanforderungen..."
    
    # Prüfe ob cron installiert ist
    if ! command -v crontab &> /dev/null; then
        log "ERROR" "cron ist nicht installiert. Bitte installieren Sie es mit 'apt-get install cron' oder einem ähnlichen Befehl."
        exit 1
    else
        log "INFO" "cron ist installiert."
    fi
    
    # Prüfe ob mail verfügbar ist (für Benachrichtigungen)
    if [ "$EMAIL_NOTIFICATIONS" = true ]; then
        if ! command -v mail &> /dev/null; then
            log "WARN" "mail-Befehl ist nicht installiert. E-Mail-Benachrichtigungen werden nicht funktionieren."
            log "INFO" "Installiere mail-Befehl mit 'apt-get install mailutils' oder einem ähnlichen Befehl."
            apt-get update && apt-get install -y mailutils
        else
            log "INFO" "mail-Befehl ist installiert."
        fi
    fi
    
    # Prüfe ob systemd vorhanden ist (für Timer)
    if ! command -v systemctl &> /dev/null; then
        log "WARN" "systemd ist nicht verfügbar. Systemd-Timer werden nicht eingerichtet."
    else
        log "INFO" "systemd ist verfügbar. Systemd-Timer können verwendet werden."
    fi
    
    # Prüfe Haupttestskript
    if [ ! -f "$MAIN_TEST_SCRIPT" ]; then
        log "ERROR" "Das Haupttestskript existiert nicht: $MAIN_TEST_SCRIPT"
        exit 1
    else
        log "INFO" "Haupttestskript gefunden: $MAIN_TEST_SCRIPT"
        
        # Prüfe ob ausführbar
        if [ ! -x "$MAIN_TEST_SCRIPT" ]; then
            log "STEP" "Mache Haupttestskript ausführbar..."
            chmod +x "$MAIN_TEST_SCRIPT"
        fi
    fi
}

# Testverzeichnisse vorbereiten
prepare_directories() {
    log "STEP" "Bereite Testverzeichnisse vor..."
    
    # Erstelle Verzeichnis für Testergebnisse
    mkdir -p "$TEST_RESULTS_DIR"
    log "INFO" "Testergebnisse-Verzeichnis erstellt: $TEST_RESULTS_DIR"
    
    # Erstelle Unterverzeichnisse für verschiedene Testtypen
    mkdir -p "$TEST_RESULTS_DIR/daily"
    mkdir -p "$TEST_RESULTS_DIR/weekly"
    mkdir -p "$TEST_RESULTS_DIR/monthly"
    
    # Setze Berechtigungen
    chmod 755 "$TEST_RESULTS_DIR"
    chmod 755 "$TEST_RESULTS_DIR/daily"
    chmod 755 "$TEST_RESULTS_DIR/weekly"
    chmod 755 "$TEST_RESULTS_DIR/monthly"
    
    log "INFO" "Testverzeichnisse vorbereitet."
}

# Cron-Job für Tests einrichten
setup_cron_job() {
    log "STEP" "Richte Cron-Job für automatisierte Tests ein..."
    
    local cron_schedule=""
    local log_file=""
    
    # Bestimme Cron-Zeitplan basierend auf dem gewählten Intervall
    case $TEST_INTERVAL in
        daily)
            cron_schedule="0 3 * * *" # Täglich um 3 Uhr morgens
            log_file="$TEST_RESULTS_DIR/daily/\$(date +\\%Y-\\%m-\\%d).log"
            ;;
        weekly)
            cron_schedule="0 4 * * 0" # Sonntag um 4 Uhr morgens
            log_file="$TEST_RESULTS_DIR/weekly/\$(date +\\%Y-\\%m-\\%d).log"
            ;;
        monthly)
            cron_schedule="0 5 1 * *" # 1. Tag des Monats um 5 Uhr morgens
            log_file="$TEST_RESULTS_DIR/monthly/\$(date +\\%Y-\\%m).log"
            ;;
        custom)
            cron_schedule="$CUSTOM_CRON_SCHEDULE"
            log_file="$TEST_RESULTS_DIR/custom/\$(date +\\%Y-\\%m-\\%d-\\%H\\%M).log"
            mkdir -p "$TEST_RESULTS_DIR/custom"
            chmod 755 "$TEST_RESULTS_DIR/custom"
            ;;
        *)
            log "ERROR" "Ungültiges Intervall: $TEST_INTERVAL"
            exit 1
            ;;
    esac
    
    log "INFO" "Verwende Cron-Zeitplan: $cron_schedule"
    
    # Erstelle temporäre Crontab-Datei
    local temp_cron=$(mktemp)
    
    # Exportiere bestehende crontab
    crontab -l > "$temp_cron" 2>/dev/null || echo "" > "$temp_cron"
    
    # Entferne alte Einträge dieses Skripts
    sed -i '/code-server.*test/d' "$temp_cron"
    
    # Generiere Crontab-Eintrag
    local cron_entry="$cron_schedule"
    
    if [ "$EMAIL_NOTIFICATIONS" = true ]; then
        # Mit E-Mail-Benachrichtigungen
        cron_entry="$cron_entry $MAIN_TEST_SCRIPT > $log_file 2>&1 && if [ \$? -ne 0 ]; then echo \"Code-Server Tests fehlgeschlagen! Siehe $log_file für Details.\" | mail -s \"Code-Server Test-Fehler\" $NOTIFICATION_EMAIL; fi"
    else
        # Ohne E-Mail-Benachrichtigungen
        cron_entry="$cron_entry $MAIN_TEST_SCRIPT > $log_file 2>&1"
    fi
    
    echo "# Code-Server automatisierte Tests ($TEST_INTERVAL)" >> "$temp_cron"
    echo "$cron_entry" >> "$temp_cron"
    
    # Installiere neue crontab
    crontab "$temp_cron"
    
    # Lösche temporäre Datei
    rm "$temp_cron"
    
    log "INFO" "Cron-Job für automatisierte Tests eingerichtet."
}

# Systemd-Timer als Alternative einrichten
setup_systemd_timer() {
    log "STEP" "Richte Systemd-Timer für automatisierte Tests ein..."
    
    if ! command -v systemctl &> /dev/null; then
        log "WARN" "systemd ist nicht verfügbar. Überspringe Timer-Einrichtung."
        return
    fi
    
    # Bestimme Timer-Konfiguration basierend auf dem gewählten Intervall
    local timer_schedule=""
    local timer_description=""
    
    case $TEST_INTERVAL in
        daily)
            timer_schedule="OnCalendar=*-*-* 03:00:00"
            timer_description="Täglich um 3 Uhr morgens"
            ;;
        weekly)
            timer_schedule="OnCalendar=Sun *-*-* 04:00:00"
            timer_description="Sonntag um 4 Uhr morgens"
            ;;
        monthly)
            timer_schedule="OnCalendar=*-*-01 05:00:00"
            timer_description="1. Tag des Monats um 5 Uhr morgens"
            ;;
        custom)
            # Für benutzerdefinierte Zeitpläne verwende Crontab und keine Timer
            log "INFO" "Bei benutzerdefinierten Zeitplänen wird kein Timer eingerichtet."
            return
            ;;
    esac
    
    # Erstelle Service-Datei
    local service_file="/etc/systemd/system/code-server-test.service"
    cat > "$service_file" << EOF
[Unit]
Description=Code-Server automatisierter Test
After=network.target

[Service]
Type=oneshot
ExecStart=$MAIN_TEST_SCRIPT
StandardOutput=append:$TEST_RESULTS_DIR/$TEST_INTERVAL/latest.log
StandardError=append:$TEST_RESULTS_DIR/$TEST_INTERVAL/latest.log

[Install]
WantedBy=multi-user.target
EOF
    
    log "INFO" "Service-Datei erstellt: $service_file"
    
    # Erstelle Timer-Datei
    local timer_file="/etc/systemd/system/code-server-test.timer"
    cat > "$timer_file" << EOF
[Unit]
Description=Code-Server automatisierter Test ($timer_description)
Requires=code-server-test.service

[Timer]
Unit=code-server-test.service
$timer_schedule
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    log "INFO" "Timer-Datei erstellt: $timer_file"
    
    # Systemd neu laden und Timer aktivieren
    systemctl daemon-reload
    systemctl enable code-server-test.timer
    systemctl start code-server-test.timer
    
    local timer_status=$(systemctl is-active code-server-test.timer)
    
    if [ "$timer_status" = "active" ]; then
        log "INFO" "Systemd-Timer für automatisierte Tests eingerichtet und aktiviert."
    else
        log "WARN" "Systemd-Timer konnte nicht aktiviert werden."
    fi
}

# Log-Rotation für Testergebnisse einrichten
setup_log_rotation() {
    log "STEP" "Richte Log-Rotation für Testergebnisse ein..."
    
    local logrotate_file="/etc/logrotate.d/code-server-tests"
    
    cat > "$logrotate_file" << EOF
$TEST_RESULTS_DIR/daily/*.log {
    rotate 30
    daily
    compress
    missingok
    notifempty
    create 644 root root
}

$TEST_RESULTS_DIR/weekly/*.log {
    rotate 12
    weekly
    compress
    missingok
    notifempty
    create 644 root root
}

$TEST_RESULTS_DIR/monthly/*.log {
    rotate 12
    monthly
    compress
    missingok
    notifempty
    create 644 root root
}

$TEST_RESULTS_DIR/custom/*.log {
    rotate 30
    daily
    compress
    missingok
    notifempty
    create 644 root root
}
EOF
    
    log "INFO" "Log-Rotation für Testergebnisse eingerichtet: $logrotate_file"
}

# Hauptfunktion
main() {
    log "SETUP" "==== Starte Einrichtung von automatisierten Tests für Code-Server ===="
    
    check_root
    parse_args "$@"
    check_requirements
    prepare_directories
    
    # Richte Cron-Job ein
    setup_cron_job
    
    # Richte Systemd-Timer ein (wenn systemd verfügbar ist)
    if command -v systemctl &> /dev/null; then
        setup_systemd_timer
    fi
    
    # Richte Log-Rotation ein
    setup_log_rotation
    
    log "SETUP" "==== Einrichtung von automatisierten Tests für Code-Server abgeschlossen ===="
    
    log "INFO" "Tests werden gemäß dem '$TEST_INTERVAL'-Zeitplan ausgeführt."
    log "INFO" "Testergebnisse werden in '$TEST_RESULTS_DIR' gespeichert."
    
    if [ "$EMAIL_NOTIFICATIONS" = true ]; then
        log "INFO" "E-Mail-Benachrichtigungen werden an '$NOTIFICATION_EMAIL' gesendet."
    fi
    
    # Biete an, sofort einen ersten Test auszuführen
    echo ""
    read -p "Möchten Sie direkt einen ersten Test ausführen? (j/n) " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Jj]$ ]]; then
        log "INFO" "Führe ersten Test aus..."
        "$MAIN_TEST_SCRIPT" || true
        log "INFO" "Erster Test abgeschlossen."
    fi
    
    echo ""
    log "INFO" "Hinweis: Die Tests können jederzeit manuell mit '$MAIN_TEST_SCRIPT' ausgeführt werden."
    
    exit 0
}

main "$@"