#!/bin/bash
#
# DevSystem - code-server Konfigurationsskript
# Autor: DevSystem Team
# Version: 1.0
# Datum: 2026-04-09
#
# Beschreibung:
# Dieses Skript konfiguriert code-server für das DevSystem-Projekt.
# Es führt folgende Aktionen aus:
# - Erstellung/Aktualisierung der config.yaml
# - Sichere Passwort-Generierung und -Speicherung
# - Installation wichtiger VS Code Extensions
# - Konfiguration der Workspace-Settings
# - Service-Neustart und Validierung
# - Detailliertes Logging und Fehlerbehandlung
# - Backup der alten Konfiguration
#
# Voraussetzungen:
# - code-server muss installiert sein (via install-code-server.sh)
# - Root-Zugriff erforderlich
#
# Verwendung:
#   sudo bash configure-code-server.sh [--user=NAME] [--password=PASS] [--no-extensions] [--help]
#

set -e  # Script beenden bei Fehler
set -u  # Script beenden bei undefinierter Variable

# ============================================================================
# KONFIGURATION UND KONSTANTEN
# ============================================================================

# Farbdefinitionen für Terminal-Ausgabe
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m' # No Color

# Verzeichnisse und Dateien
readonly BACKUP_DIR_DEFAULT="/var/backups/code-server"
readonly LOG_FILE="/var/log/devsystem-configure-code-server.log"

# Standardwerte für Konfigurationsparameter
CODE_SERVER_USER="codeserver"
CODE_SERVER_PORT="8080"
CODE_SERVER_PASSWORD=""
INSTALL_EXTENSIONS=true
BACKUP_DIR="${BACKUP_DIR_DEFAULT}"

# Extensions-Liste für DevSystem
readonly EXTENSIONS=(
    "saoudrizwan.claude-dev"           # Roo Cline - KI-Steuerung
    "eamodio.gitlens"                  # GitLens - Git-Integration
    "ms-azuretools.vscode-docker"      # Docker - Container-Management
    "ms-vscode-remote.remote-ssh"      # Remote - SSH
    "redhat.vscode-yaml"               # YAML - YAML-Support
    "mads-hartmann.bash-ide-vscode"    # Bash IDE - Bash-Scripting
)

# ============================================================================
# LOGGING-FUNKTIONEN
# ============================================================================

# Logging in Datei und Terminal
exec > >(tee -a "$LOG_FILE")
exec 2>&1

log_message() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓ SUCCESS:${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠ WARNING:${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗ ERROR:${NC} $1"
}

log_step() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] STEP:${NC} $1"
}

log_password() {
    echo -e "${MAGENTA}[$(date '+%Y-%m-%d %H:%M:%S')] 🔐 PASSWORD:${NC} $1"
}

# Fehlerbehandlung mit Exit
error_exit() {
    log_error "$1"
    log_error "Konfiguration fehlgeschlagen. Siehe Log: ${LOG_FILE}"
    exit 1
}

# ============================================================================
# HILFSFUNKTIONEN
# ============================================================================

# Hilfe-Text anzeigen
show_help() {
    cat << EOF
DevSystem - code-server Konfigurationsskript

Verwendung: sudo bash configure-code-server.sh [Optionen]

Optionen:
  --user=NAME           Benutzername für code-server (Standard: codeserver)
  --password=PASS       Eigenes Passwort setzen (statt generieren)
  --no-extensions       Keine Extensions installieren
  --backup-dir=DIR      Verzeichnis für Backups (Standard: ${BACKUP_DIR_DEFAULT})
  --help                Diese Hilfe anzeigen

Beispiele:
  sudo bash configure-code-server.sh
  sudo bash configure-code-server.sh --user=codeserver
  sudo bash configure-code-server.sh --password=MeinSicheresPasswort123
  sudo bash configure-code-server.sh --no-extensions

Voraussetzungen:
  - code-server muss installiert sein
  - Root-Rechte erforderlich

EOF
    exit 0
}

# Kommandozeilenargumente parsen
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --user=*)
                CODE_SERVER_USER="${1#*=}"
                shift
                ;;
            --password=*)
                CODE_SERVER_PASSWORD="${1#*=}"
                shift
                ;;
            --no-extensions)
                INSTALL_EXTENSIONS=false
                shift
                ;;
            --backup-dir=*)
                BACKUP_DIR="${1#*=}"
                shift
                ;;
            --help)
                show_help
                ;;
            *)
                error_exit "Unbekannter Parameter: $1. Verwende --help für Hilfe."
                ;;
        esac
    done
}

# ============================================================================
# VALIDIERUNGSFUNKTIONEN
# ============================================================================

# Root-Berechtigungen prüfen
check_root() {
    if [ "$(id -u)" != "0" ]; then
        error_exit "Dieses Skript muss mit Root-Rechten ausgeführt werden. Verwende 'sudo'."
    fi
}

# Prüfen, ob code-server installiert ist
check_code_server_installed() {
    log_step "Prüfe ob code-server installiert ist..."
    
    if ! command -v code-server &> /dev/null; then
        error_exit "code-server ist nicht installiert. Bitte führe zuerst 'install-code-server.sh' aus."
    fi
    
    local version=$(code-server --version 2>&1 | head -n1)
    log_success "code-server ist installiert: ${version}"
}

# Prüfen, ob Benutzer existiert
check_user_exists() {
    log_step "Prüfe ob Benutzer '${CODE_SERVER_USER}' existiert..."
    
    if ! id "${CODE_SERVER_USER}" &> /dev/null; then
        error_exit "Benutzer '${CODE_SERVER_USER}' existiert nicht. Bitte führe zuerst 'install-code-server.sh' aus."
    fi
    
    log_success "Benutzer '${CODE_SERVER_USER}' existiert."
}

# Prüfen, ob Service existiert
check_service_exists() {
    log_step "Prüfe ob code-server-Service existiert..."
    
    if ! systemctl list-unit-files | grep -q "code-server.service"; then
        error_exit "code-server-Service existiert nicht. Bitte führe zuerst 'install-code-server.sh' aus."
    fi
    
    log_success "code-server-Service existiert."
}

# ============================================================================
# BACKUP-FUNKTIONEN
# ============================================================================

# Backup der alten Konfiguration erstellen
backup_config() {
    log_step "Erstelle Backup der aktuellen Konfiguration..."
    
    local user_home="/home/${CODE_SERVER_USER}"
    local config_file="${user_home}/.config/code-server/config.yaml"
    local settings_file="${user_home}/.local/share/code-server/User/settings.json"
    
    # Backup-Verzeichnis erstellen
    mkdir -p "${BACKUP_DIR}"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="${BACKUP_DIR}/code-server_backup_${timestamp}"
    
    # Prüfen, ob Konfiguration existiert
    if [ -f "${config_file}" ] || [ -f "${settings_file}" ]; then
        mkdir -p "${backup_path}"
        
        # config.yaml sichern
        if [ -f "${config_file}" ]; then
            cp "${config_file}" "${backup_path}/" 2>/dev/null || true
            log_message "config.yaml gesichert."
        fi
        
        # settings.json sichern
        if [ -f "${settings_file}" ]; then
            mkdir -p "${backup_path}/User"
            cp "${settings_file}" "${backup_path}/User/" 2>/dev/null || true
            log_message "settings.json gesichert."
        fi
        
        # Extensions-Liste sichern
        if [ -d "${user_home}/.local/share/code-server/extensions" ]; then
            ls "${user_home}/.local/share/code-server/extensions" > "${backup_path}/extensions-list.txt" 2>/dev/null || true
        fi
        
        log_success "Backup erstellt: ${backup_path}"
        echo "${backup_path}" > "${BACKUP_DIR}/latest_backup.txt"
    else
        log_message "Keine vorherige Konfiguration gefunden. Kein Backup notwendig."
    fi
}

# ============================================================================
# PASSWORT-FUNKTIONEN
# ============================================================================

# Sicheres Passwort generieren
generate_password() {
    log_step "Generiere sicheres Passwort..."
    
    # Passwort mit openssl generieren (32 Zeichen Base64)
    local password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    
    if [ -z "$password" ]; then
        error_exit "Konnte kein Passwort generieren."
    fi
    
    log_success "Passwort erfolgreich generiert (32 Zeichen)."
    echo "$password"
}

# Passwort sicher speichern
save_password() {
    local password="$1"
    local user_home="/home/${CODE_SERVER_USER}"
    local password_file="${user_home}/.config/code-server/password.txt"
    
    log_step "Speichere Passwort sicher..."
    
    # Passwort in Datei speichern
    echo "$password" > "$password_file"
    
    # Berechtigungen setzen (nur User lesbar)
    chown "${CODE_SERVER_USER}:${CODE_SERVER_USER}" "$password_file"
    chmod 600 "$password_file"
    
    log_success "Passwort gespeichert in: ${password_file}"
    log_message "Berechtigungen: 600 (nur User lesbar)"
}

# ============================================================================
# KONFIGURATIONSFUNKTIONEN
# ============================================================================

# Verzeichnisstruktur erstellen
create_directory_structure() {
    log_step "Erstelle/Prüfe Verzeichnisstruktur..."
    
    local user_home="/home/${CODE_SERVER_USER}"
    
    # Verzeichnisse erstellen
    mkdir -p "${user_home}/.config/code-server"
    mkdir -p "${user_home}/.local/share/code-server"
    mkdir -p "${user_home}/.local/share/code-server/User"
    mkdir -p "${user_home}/.local/share/code-server/extensions"
    
    # Berechtigungen setzen
    chown -R "${CODE_SERVER_USER}:${CODE_SERVER_USER}" "${user_home}/.config/code-server"
    chown -R "${CODE_SERVER_USER}:${CODE_SERVER_USER}" "${user_home}/.local/share/code-server"
    
    log_success "Verzeichnisstruktur erstellt/geprüft."
}

# config.yaml erstellen/aktualisieren
create_config_yaml() {
    local password="$1"
    local user_home="/home/${CODE_SERVER_USER}"
    local config_file="${user_home}/.config/code-server/config.yaml"
    
    log_step "Erstelle config.yaml..."
    
    cat > "${config_file}" << EOF
# code-server Konfiguration für DevSystem
# Generiert durch configure-code-server.sh am $(date '+%Y-%m-%d %H:%M:%S')

# Bind-Adresse: nur localhost, Caddy als Reverse Proxy
bind-addr: 127.0.0.1:${CODE_SERVER_PORT}

# Authentifizierung: Passwort
auth: password
password: ${password}

# TLS wird von Caddy übernommen
cert: false

# Datenverzeichnisse
user-data-dir: ${user_home}/.local/share/code-server
extensions-dir: ${user_home}/.local/share/code-server/extensions
EOF
    
    # Berechtigungen setzen (nur User lesbar)
    chown "${CODE_SERVER_USER}:${CODE_SERVER_USER}" "${config_file}"
    chmod 600 "${config_file}"
    
    log_success "config.yaml erstellt: ${config_file}"
    log_message "Berechtigungen: 600 (nur User lesbar)"
}

# Workspace-Settings erstellen
create_workspace_settings() {
    log_step "Erstelle Workspace-Settings..."
    
    local user_home="/home/${CODE_SERVER_USER}"
    local settings_file="${user_home}/.local/share/code-server/User/settings.json"
    
    cat > "${settings_file}" << 'EOF'
{
  "workbench.colorTheme": "Default Dark Modern",
  "workbench.iconTheme": "vs-minimal",
  "workbench.startupEditor": "none",
  "workbench.editor.enablePreview": false,
  "workbench.editor.showTabs": true,
  "workbench.editor.tabSizing": "shrink",
  "workbench.editor.tabCloseButton": "right",
  "workbench.editor.limit.enabled": true,
  "workbench.editor.limit.value": 10,
  
  "editor.fontSize": 14,
  "editor.fontFamily": "'Droid Sans Mono', 'monospace'",
  "editor.tabSize": 2,
  "editor.wordWrap": "on",
  "editor.formatOnSave": true,
  "editor.minimap.enabled": true,
  "editor.renderWhitespace": "boundary",
  "editor.rulers": [80, 120],
  
  "files.autoSave": "afterDelay",
  "files.autoSaveDelay": 1000,
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true,
  
  "terminal.integrated.fontSize": 14,
  "terminal.integrated.defaultProfile.linux": "bash",
  "terminal.integrated.scrollback": 10000,
  
  "git.enabled": true,
  "git.autofetch": true,
  "git.confirmSync": false,
  
  "extensions.autoUpdate": true,
  "extensions.autoCheckUpdates": true,
  
  "telemetry.telemetryLevel": "off",
  "security.workspace.trust.enabled": false,
  
  "window.zoomLevel": 0,
  "window.menuBarVisibility": "toggle"
}
EOF
    
    # Berechtigungen setzen
    chown "${CODE_SERVER_USER}:${CODE_SERVER_USER}" "${settings_file}"
    chmod 644 "${settings_file}"
    
    log_success "Workspace-Settings erstellt: ${settings_file}"
}

# ============================================================================
# EXTENSIONS-FUNKTIONEN
# ============================================================================

# Extensions installieren
install_extensions() {
    if [ "$INSTALL_EXTENSIONS" = false ]; then
        log_message "Extension-Installation übersprungen (--no-extensions)."
        return 0
    fi
    
    log_step "Installiere VS Code Extensions..."
    
    local user_home="/home/${CODE_SERVER_USER}"
    local installed_count=0
    local failed_count=0
    local failed_extensions=()
    
    for ext in "${EXTENSIONS[@]}"; do
        log_message "Installiere Extension: ${ext}"
        
        # Extension als User installieren
        if su - "${CODE_SERVER_USER}" -c "code-server --install-extension ${ext} --force" >> "$LOG_FILE" 2>&1; then
            log_success "  ✓ ${ext} installiert"
            ((installed_count++))
        else
            log_warning "  ✗ ${ext} konnte nicht installiert werden"
            failed_extensions+=("${ext}")
            ((failed_count++))
        fi
    done
    
    echo ""
    log_success "Extensions-Installation abgeschlossen:"
    log_message "  • Erfolgreich installiert: ${installed_count}"
    
    if [ $failed_count -gt 0 ]; then
        log_warning "  • Fehlgeschlagen: ${failed_count}"
        log_warning "  • Fehlgeschlagene Extensions:"
        for ext in "${failed_extensions[@]}"; do
            log_warning "    - ${ext}"
        done
    fi
}

# Installierte Extensions auflisten
list_installed_extensions() {
    log_step "Liste installierte Extensions auf..."
    
    local user_home="/home/${CODE_SERVER_USER}"
    
    if su - "${CODE_SERVER_USER}" -c "code-server --list-extensions" > /tmp/extensions-list.txt 2>&1; then
        local ext_count=$(wc -l < /tmp/extensions-list.txt)
        log_success "Installierte Extensions (${ext_count}):"
        
        while IFS= read -r ext; do
            echo "  • ${ext}"
        done < /tmp/extensions-list.txt
        
        rm -f /tmp/extensions-list.txt
    else
        log_warning "Konnte Extensions nicht auflisten."
    fi
}

# ============================================================================
# SERVICE-MANAGEMENT
# ============================================================================

# Service neu starten
restart_service() {
    log_step "Starte code-server-Service neu..."
    
    if systemctl restart code-server 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Service erfolgreich neu gestartet."
    else
        log_error "Fehler beim Neustart des Services."
        return 1
    fi
    
    # Kurz warten, damit Service hochfahren kann
    sleep 3
}

# Service-Status prüfen
check_service_status() {
    log_step "Prüfe Service-Status..."
    
    if systemctl is-active --quiet code-server; then
        log_success "code-server-Service läuft."
        
        # Detaillierte Status-Informationen
        log_message "Service-Details:"
        systemctl status code-server --no-pager -l | head -n 15 | tee -a "$LOG_FILE"
        
        return 0
    else
        log_error "code-server-Service läuft nicht!"
        log_error "Prüfe Logs mit: journalctl -u code-server -n 50"
        
        # Zeige letzte Log-Einträge
        log_message "Letzte Log-Einträge:"
        journalctl -u code-server -n 20 --no-pager | tee -a "$LOG_FILE"
        
        return 1
    fi
}

# Logs validieren
validate_logs() {
    log_step "Validiere Service-Logs..."
    
    # Warte kurz, damit Logs geschrieben werden
    sleep 2
    
    # Prüfe auf Fehler in den Logs
    local error_count=$(journalctl -u code-server -n 50 --no-pager | grep -i "error" | wc -l)
    
    if [ "$error_count" -gt 0 ]; then
        log_warning "Gefundene Fehler in Logs: ${error_count}"
        log_message "Letzte Fehler:"
        journalctl -u code-server -n 50 --no-pager | grep -i "error" | tail -n 5
    else
        log_success "Keine Fehler in den Logs gefunden."
    fi
    
    # Prüfe ob code-server auf Port lauscht
    if ss -tlnp | grep -q ":${CODE_SERVER_PORT}"; then
        log_success "code-server lauscht auf Port ${CODE_SERVER_PORT}."
    else
        log_warning "code-server scheint nicht auf Port ${CODE_SERVER_PORT} zu lauschen."
    fi
}

# ============================================================================
# ZUSAMMENFASSUNG UND AUSGABE
# ============================================================================

# Passwort sicher anzeigen
display_password() {
    local password="$1"
    
    echo ""
    echo "============================================================================"
    log_password "WICHTIG: Generiertes Passwort für code-server"
    echo "============================================================================"
    echo ""
    echo -e "${MAGENTA}Passwort: ${GREEN}${password}${NC}"
    echo ""
    log_warning "Bitte speichere dieses Passwort sicher!"
    log_message "Das Passwort wurde auch gespeichert in:"
    echo "  /home/${CODE_SERVER_USER}/.config/code-server/password.txt"
    echo ""
    echo "============================================================================"
    echo ""
}

# Abschlussinformationen anzeigen
show_summary() {
    local password="$1"
    local tailscale_ip=""
    
    # Versuche Tailscale-IP zu ermitteln
    if command -v tailscale &> /dev/null; then
        tailscale_ip=$(tailscale ip -4 2>/dev/null | head -n1 || echo "nicht verfügbar")
    else
        tailscale_ip="nicht verfügbar (Tailscale nicht installiert)"
    fi
    
    echo ""
    echo "============================================================================"
    log_success "code-server-Konfiguration erfolgreich abgeschlossen!"
    echo "============================================================================"
    echo ""
    log_message "Konfigurationsdetails:"
    echo "  • Benutzer:              ${CODE_SERVER_USER}"
    echo "  • Bind-Adresse:          127.0.0.1:${CODE_SERVER_PORT}"
    echo "  • Authentifizierung:     password"
    echo "  • TLS:                   false (Caddy übernimmt SSL)"
    echo "  • Extensions installiert: ${INSTALL_EXTENSIONS}"
    echo ""
    log_message "Zugriffs-URLs (über Caddy/Tailscale):"
    if [ "$tailscale_ip" != "nicht verfügbar (Tailscale nicht installiert)" ]; then
        echo "  • https://${tailscale_ip}:9443"
    fi
    echo "  • https://[TAILSCALE-IP]"
    echo "  • https://[TAILSCALE-DOMAIN]"
    echo ""
    log_message "Wichtige Dateien:"
    echo "  • Konfiguration:         /home/${CODE_SERVER_USER}/.config/code-server/config.yaml"
    echo "  • Passwort-Datei:        /home/${CODE_SERVER_USER}/.config/code-server/password.txt"
    echo "  • Workspace-Settings:    /home/${CODE_SERVER_USER}/.local/share/code-server/User/settings.json"
    echo "  • Extensions-Verzeichnis: /home/${CODE_SERVER_USER}/.local/share/code-server/extensions"
    echo "  • Konfig-Log:            ${LOG_FILE}"
    echo ""
    log_message "Nützliche Befehle:"
    echo "  • Status prüfen:         sudo systemctl status code-server"
    echo "  • Logs anzeigen:         sudo journalctl -u code-server -f"
    echo "  • Service neustarten:    sudo systemctl restart code-server"
    echo "  • Extensions auflisten:  su - ${CODE_SERVER_USER} -c 'code-server --list-extensions'"
    echo ""
    log_message "Nächste Schritte:"
    echo "  1. Stelle sicher, dass Caddy als Reverse Proxy konfiguriert ist"
    echo "  2. Greife über Tailscale auf code-server zu"
    echo "  3. Melde dich mit dem generierten Passwort an"
    echo "  4. Installiere weitere Extensions nach Bedarf"
    echo ""
    echo "============================================================================"
    echo ""
}

# ============================================================================
# HAUPTPROGRAMM
# ============================================================================

main() {
    # Banner
    echo ""
    echo "============================================================================"
    echo "  DevSystem - code-server Konfigurationsskript"
    echo "  Version 1.0"
    echo "============================================================================"
    echo ""
    
    # Argumente parsen
    parse_arguments "$@"
    
    # Validierungen
    check_root
    check_code_server_installed
    check_user_exists
    check_service_exists
    
    # Backup erstellen
    backup_config
    
    # Passwort generieren oder verwenden
    local password=""
    if [ -z "$CODE_SERVER_PASSWORD" ]; then
        password=$(generate_password)
    else
        password="$CODE_SERVER_PASSWORD"
        log_message "Verwende benutzerdefiniertes Passwort."
    fi
    
    # Passwort speichern
    save_password "$password"
    
    # Konfiguration erstellen
    create_directory_structure
    create_config_yaml "$password"
    create_workspace_settings
    
    # Extensions installieren
    install_extensions
    
    # Service neu starten
    if ! restart_service; then
        error_exit "Service-Neustart fehlgeschlagen. Prüfe die Logs."
    fi
    
    # Status prüfen
    if ! check_service_status; then
        error_exit "Service läuft nicht korrekt. Prüfe die Logs."
    fi
    
    # Logs validieren
    validate_logs
    
    # Installierte Extensions auflisten
    if [ "$INSTALL_EXTENSIONS" = true ]; then
        echo ""
        list_installed_extensions
    fi
    
    # Passwort anzeigen (nur wenn generiert)
    if [ -z "$CODE_SERVER_PASSWORD" ]; then
        display_password "$password"
    fi
    
    # Zusammenfassung anzeigen
    show_summary "$password"
    
    log_success "Konfiguration erfolgreich abgeschlossen!"
    exit 0
}

# Skript ausführen
main "$@"
