#!/bin/bash
set -euo pipefail

# =============================================================================
# Sicheres Update-Skript für code-server
# =============================================================================
# Dieses Skript aktualisiert die code-server Konfiguration sicher mit:
# - Automatischem Backup der aktuellen Konfiguration
# - Minimaler Downtime (nur kurzer Restart)
# - Automatischem Rollback bei Fehlern
# - Umfassender Validierung nach dem Update
# =============================================================================

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variablen
BACKUP_DIR="/home/codeserver/backup-$(date +%Y%m%d-%H%M%S)"
CONFIG_DIR="/home/codeserver/.config/code-server"
SERVICE_NAME="code-server"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/code-server-update-$(date +%Y%m%d-%H%M%S).log"

# Logging-Funktion
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

print_status() {
    echo -e "${BLUE}==>${NC} $*" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}✓${NC} $*" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $*" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}✗${NC} $*" | tee -a "$LOG_FILE"
}

# =============================================================================
# Backup-Funktion
# =============================================================================
backup_config() {
    print_status "Erstelle Backup der aktuellen Konfiguration..."
    
    # Prüfe ob Config-Verzeichnis existiert
    if [[ ! -d "$CONFIG_DIR" ]]; then
        print_error "Konfigurationsverzeichnis nicht gefunden: $CONFIG_DIR"
        return 1
    fi
    
    # Erstelle Backup-Verzeichnis
    if ! mkdir -p "$BACKUP_DIR"; then
        print_error "Konnte Backup-Verzeichnis nicht erstellen: $BACKUP_DIR"
        return 1
    fi
    
    # Backup der Konfigurationsdateien
    local files_backed_up=0
    
    if [[ -f "$CONFIG_DIR/config.yaml" ]]; then
        if cp -p "$CONFIG_DIR/config.yaml" "$BACKUP_DIR/"; then
            print_success "config.yaml gesichert"
            ((files_backed_up++))
        else
            print_error "Fehler beim Sichern von config.yaml"
            return 1
        fi
    fi
    
    if [[ -f "$CONFIG_DIR/password.txt" ]]; then
        if cp -p "$CONFIG_DIR/password.txt" "$BACKUP_DIR/"; then
            print_success "password.txt gesichert"
            ((files_backed_up++))
        else
            print_error "Fehler beim Sichern von password.txt"
            return 1
        fi
    fi
    
    # Backup des gesamten Config-Verzeichnisses (für zusätzliche Dateien)
    if cp -rp "$CONFIG_DIR" "$BACKUP_DIR/config-full"; then
        print_success "Vollständiges Config-Verzeichnis gesichert"
    else
        print_warning "Warnung: Vollständiges Backup fehlgeschlagen"
    fi
    
    # Service-Status sichern
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "running" > "$BACKUP_DIR/service-status.txt"
        print_success "Service-Status gesichert: running"
    else
        echo "stopped" > "$BACKUP_DIR/service-status.txt"
        print_success "Service-Status gesichert: stopped"
    fi
    
    if [[ $files_backed_up -eq 0 ]]; then
        print_warning "Keine Konfigurationsdateien zum Sichern gefunden"
    else
        print_success "Backup erfolgreich erstellt in: $BACKUP_DIR"
    fi
    
    return 0
}

# =============================================================================
# Update-Funktion
# =============================================================================
update_config() {
    print_status "Aktualisiere code-server Konfiguration..."
    
    # Prüfe ob configure-Skript existiert
    local configure_script="$SCRIPT_DIR/configure-code-server.sh"
    if [[ ! -f "$configure_script" ]]; then
        print_error "Konfigurationsskript nicht gefunden: $configure_script"
        return 1
    fi
    
    if [[ ! -x "$configure_script" ]]; then
        print_error "Konfigurationsskript ist nicht ausführbar: $configure_script"
        return 1
    fi
    
    # Führe Konfigurationsskript aus
    print_status "Führe configure-code-server.sh aus..."
    if bash "$configure_script" >> "$LOG_FILE" 2>&1; then
        print_success "Konfiguration erfolgreich aktualisiert"
        return 0
    else
        print_error "Fehler beim Aktualisieren der Konfiguration"
        return 1
    fi
}

# =============================================================================
# Service-Restart-Funktion
# =============================================================================
restart_service() {
    print_status "Starte code-server Service neu..."
    
    # Prüfe ob Service existiert
    if ! systemctl list-unit-files | grep -q "^${SERVICE_NAME}.service"; then
        print_error "Service nicht gefunden: $SERVICE_NAME"
        return 1
    fi
    
    # Restart mit Timeout
    if timeout 30 systemctl restart "$SERVICE_NAME"; then
        print_success "Service erfolgreich neu gestartet"
        sleep 3  # Kurze Wartezeit für Service-Stabilisierung
        return 0
    else
        print_error "Fehler beim Neustarten des Services"
        return 1
    fi
}

# =============================================================================
# Validierungs-Funktion
# =============================================================================
validate_service() {
    print_status "Validiere code-server Service..."
    
    local validation_failed=0
    
    # 1. Service-Status prüfen
    print_status "Prüfe Service-Status..."
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Service ist aktiv"
    else
        print_error "Service ist nicht aktiv"
        systemctl status "$SERVICE_NAME" --no-pager >> "$LOG_FILE" 2>&1 || true
        ((validation_failed++))
    fi
    
    # 2. Service-Enabled-Status prüfen
    if systemctl is-enabled --quiet "$SERVICE_NAME"; then
        print_success "Service ist enabled"
    else
        print_warning "Service ist nicht enabled (wird nicht automatisch gestartet)"
    fi
    
    # 3. Port 8080 prüfen
    print_status "Prüfe Port 8080..."
    sleep 2  # Kurze Wartezeit für Port-Binding
    
    if ss -tlnp | grep -q ":8080"; then
        print_success "Port 8080 ist gebunden"
    else
        print_error "Port 8080 ist nicht gebunden"
        ss -tlnp | grep ":8080" >> "$LOG_FILE" 2>&1 || true
        ((validation_failed++))
    fi
    
    # 4. HTTP-Erreichbarkeit prüfen
    print_status "Prüfe HTTP-Erreichbarkeit..."
    if timeout 10 curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 | grep -q "200\|302\|401"; then
        print_success "code-server antwortet auf HTTP-Anfragen"
    else
        print_warning "code-server antwortet nicht wie erwartet (möglicherweise Auth-Redirect)"
    fi
    
    # 5. Logs auf Fehler prüfen
    print_status "Prüfe Logs auf Fehler..."
    local error_count=$(journalctl -u "$SERVICE_NAME" -n 50 --no-pager | grep -i "error\|fatal\|failed" | wc -l)
    
    if [[ $error_count -eq 0 ]]; then
        print_success "Keine Fehler in den letzten 50 Log-Einträgen"
    else
        print_warning "Gefunden: $error_count Fehler-Einträge in den Logs"
        journalctl -u "$SERVICE_NAME" -n 20 --no-pager >> "$LOG_FILE" 2>&1 || true
    fi
    
    # 6. Konfigurationsdatei prüfen
    print_status "Prüfe Konfigurationsdatei..."
    if [[ -f "$CONFIG_DIR/config.yaml" ]]; then
        print_success "config.yaml existiert"
        
        # Prüfe wichtige Konfigurationsparameter
        if grep -q "bind-addr:" "$CONFIG_DIR/config.yaml"; then
            print_success "bind-addr ist konfiguriert"
        else
            print_warning "bind-addr nicht in config.yaml gefunden"
        fi
    else
        print_error "config.yaml nicht gefunden"
        ((validation_failed++))
    fi
    
    # Zusammenfassung
    echo ""
    if [[ $validation_failed -eq 0 ]]; then
        print_success "Alle Validierungen erfolgreich"
        return 0
    else
        print_error "Validierung fehlgeschlagen: $validation_failed kritische Fehler"
        return 1
    fi
}

# =============================================================================
# Rollback-Funktion
# =============================================================================
rollback() {
    print_error "Führe Rollback durch..."
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        print_error "Backup-Verzeichnis nicht gefunden: $BACKUP_DIR"
        print_error "Manuelles Eingreifen erforderlich!"
        return 1
    fi
    
    local rollback_failed=0
    
    # Restore Konfigurationsdateien
    print_status "Stelle Konfigurationsdateien wieder her..."
    
    if [[ -f "$BACKUP_DIR/config.yaml" ]]; then
        if cp -p "$BACKUP_DIR/config.yaml" "$CONFIG_DIR/"; then
            print_success "config.yaml wiederhergestellt"
        else
            print_error "Fehler beim Wiederherstellen von config.yaml"
            ((rollback_failed++))
        fi
    fi
    
    if [[ -f "$BACKUP_DIR/password.txt" ]]; then
        if cp -p "$BACKUP_DIR/password.txt" "$CONFIG_DIR/"; then
            print_success "password.txt wiederhergestellt"
        else
            print_error "Fehler beim Wiederherstellen von password.txt"
            ((rollback_failed++))
        fi
    fi
    
    # Restore vollständiges Config-Verzeichnis falls vorhanden
    if [[ -d "$BACKUP_DIR/config-full" ]]; then
        print_status "Stelle vollständiges Config-Verzeichnis wieder her..."
        if cp -rp "$BACKUP_DIR/config-full/"* "$CONFIG_DIR/"; then
            print_success "Vollständiges Config-Verzeichnis wiederhergestellt"
        else
            print_warning "Warnung: Vollständiges Restore fehlgeschlagen"
        fi
    fi
    
    # Service neu starten
    print_status "Starte Service mit alter Konfiguration neu..."
    if systemctl restart "$SERVICE_NAME"; then
        print_success "Service erfolgreich neu gestartet"
        sleep 3
        
        # Validiere nach Rollback
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            print_success "Service läuft nach Rollback"
        else
            print_error "Service läuft nicht nach Rollback"
            ((rollback_failed++))
        fi
    else
        print_error "Fehler beim Neustarten des Services"
        ((rollback_failed++))
    fi
    
    # Zusammenfassung
    echo ""
    if [[ $rollback_failed -eq 0 ]]; then
        print_success "Rollback erfolgreich abgeschlossen"
        print_status "Backup befindet sich in: $BACKUP_DIR"
        return 0
    else
        print_error "Rollback fehlgeschlagen: $rollback_failed Fehler"
        print_error "Manuelles Eingreifen erforderlich!"
        print_status "Backup befindet sich in: $BACKUP_DIR"
        return 1
    fi
}

# =============================================================================
# Hauptfunktion
# =============================================================================
main() {
    echo ""
    echo "============================================================================="
    echo "  Sicheres code-server Update"
    echo "============================================================================="
    echo ""
    log "Update-Prozess gestartet"
    log "Log-Datei: $LOG_FILE"
    echo ""
    
    # Root-Rechte prüfen
    if [[ $EUID -ne 0 ]]; then
        print_error "Dieses Skript muss als root ausgeführt werden"
        exit 1
    fi
    
    # Prüfe ob Service existiert
    if ! systemctl list-unit-files | grep -q "^${SERVICE_NAME}.service"; then
        print_error "Service nicht gefunden: $SERVICE_NAME"
        print_error "Ist code-server installiert?"
        exit 1
    fi
    
    # Zeige aktuellen Status
    print_status "Aktueller Service-Status:"
    systemctl status "$SERVICE_NAME" --no-pager | head -n 5 || true
    echo ""
    
    # Schritt 1: Backup erstellen
    if ! backup_config; then
        print_error "Backup fehlgeschlagen - Update wird abgebrochen"
        exit 1
    fi
    echo ""
    
    # Schritt 2: Konfiguration aktualisieren
    if ! update_config; then
        print_error "Konfiguration fehlgeschlagen - starte Rollback"
        rollback
        exit 1
    fi
    echo ""
    
    # Schritt 3: Service neu starten
    if ! restart_service; then
        print_error "Service-Restart fehlgeschlagen - starte Rollback"
        rollback
        exit 1
    fi
    echo ""
    
    # Schritt 4: Validierung
    if ! validate_service; then
        print_error "Validierung fehlgeschlagen - starte Rollback"
        rollback
        exit 1
    fi
    echo ""
    
    # Erfolg
    echo "============================================================================="
    print_success "code-server Update erfolgreich abgeschlossen!"
    echo "============================================================================="
    echo ""
    print_status "Zusammenfassung:"
    echo "  • Backup erstellt in: $BACKUP_DIR"
    echo "  • Konfiguration aktualisiert"
    echo "  • Service neu gestartet"
    echo "  • Validierung erfolgreich"
    echo "  • Log-Datei: $LOG_FILE"
    echo ""
    print_status "Service-Status:"
    systemctl status "$SERVICE_NAME" --no-pager | head -n 10 || true
    echo ""
    
    log "Update-Prozess erfolgreich abgeschlossen"
    exit 0
}

# =============================================================================
# Skript-Ausführung
# =============================================================================

# Trap für Fehlerbehandlung
trap 'print_error "Unerwarteter Fehler in Zeile $LINENO"; exit 1' ERR

# Hauptfunktion ausführen
main "$@"
