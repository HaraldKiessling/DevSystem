#!/bin/bash
#
# QS-VPS: code-server Konfigurationsskript für DevSystem Quality Server
#
# Zweck:
#   Konfiguration von code-server auf dem QS-VPS mit sicherem Passwort
#   Angepasste Version mit QS-spezifischen Einstellungen
#
# Voraussetzungen:
#   - code-server installiert (via install-code-server-qs.sh)
#   - Root-Rechte
#
# Parameter:
#   QS_CODE_SERVER_PASSWORD   Passwort für code-server (MUSS gesetzt werden)
#   --user=NAME               Benutzer (Standard: codeserver-qs)
#   --no-extensions           Keine Extensions installieren
#
# Verwendung:
#   # Platzhalter QS_CODE_SERVER_PASSWORD im Script ersetzen:
#   sed -i 's/QS_CODE_SERVER_PASSWORD/MeinSicheresPasswort/g' configure-code-server-qs.sh
#   # Dann ausführen:
#   sudo bash configure-code-server-qs.sh
#

set -euo pipefail

# ============================================================================
# IDEMPOTENZ-LIBRARY LADEN
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/idempotency.sh"

# ============================================================================
# KONFIGURATION UND KONSTANTEN
# ============================================================================

# !!! WICHTIG: Diese Variable MUSS vor der Ausführung gesetzt werden !!!
QS_CODE_SERVER_PASSWORD="QS_CODE_SERVER_PASSWORD"

# HINWEIS: Farbdefinitionen werden von lib/idempotency.sh bereitgestellt
# Die Library exportiert: RED, GREEN, YELLOW, BLUE, CYAN, MAGENTA, WHITE, BOLD, NC

# Verzeichnisse und Dateien
readonly BACKUP_DIR_DEFAULT="/var/backups/code-server-qs"
readonly QS_LOG_FILE="/var/log/qs-deployment.log"

# Standardwerte
CODE_SERVER_USER="codeserver-qs"
CODE_SERVER_PORT="8080"
INSTALL_EXTENSIONS=true
BACKUP_DIR="${BACKUP_DIR_DEFAULT}"

# QS-spezifische Extensions-Liste
readonly EXTENSIONS=(
    "saoudrizwan.claude-dev"           # Roo Cline - KI-Steuerung
    "eamodio.gitlens"                  # GitLens - Git-Integration
    "ms-azuretools.vscode-docker"      # Docker - Container-Management
    "redhat.vscode-yaml"               # YAML - YAML-Support
    "mads-hartmann.bash-ide-vscode"    # Bash IDE - Bash-Scripting
)

# ============================================================================
# LOGGING-FUNKTIONEN
# ============================================================================

# Logging in QS-Log-Datei (zusätzlich zur Idempotenz-Library)
exec > >(tee -a "$QS_LOG_FILE")
exec 2>&1

log_message() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] [QS-VPS] INFO:${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [QS-VPS] ✓ SUCCESS:${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [QS-VPS] ⚠ WARNING:${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [QS-VPS] ✗ ERROR:${NC} $1"
}

log_step() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] [QS-VPS] STEP:${NC} $1"
}

log_password() {
    echo -e "${MAGENTA}[$(date '+%Y-%m-%d %H:%M:%S')] [QS-VPS] 🔐 PASSWORD:${NC} $1"
}

error_exit() {
    log_error "$1"
    log_error "Konfiguration fehlgeschlagen. Siehe Log: ${QS_LOG_FILE}"
    exit 1
}

# ============================================================================
# HILFSFUNKTIONEN
# ============================================================================

show_help() {
    cat << EOF
QS-VPS - code-server Konfigurationsskript für Quality Server

Verwendung: sudo bash configure-code-server-qs.sh [Optionen]

WICHTIG: Vor der Ausführung MUSS die Variable QS_CODE_SERVER_PASSWORD gesetzt werden!
  sed -i 's/QS_CODE_SERVER_PASSWORD/MeinPasswort/g' configure-code-server-qs.sh

Optionen:
  --user=NAME           Benutzername (Standard: codeserver-qs)
  --no-extensions       Keine Extensions installieren
  --backup-dir=DIR      Verzeichnis für Backups (Standard: ${BACKUP_DIR_DEFAULT})
  --help                Diese Hilfe anzeigen

Beispiele:
  sudo bash configure-code-server-qs.sh
  sudo bash configure-code-server-qs.sh --no-extensions

Voraussetzungen:
  - code-server muss installiert sein
  - Root-Rechte erforderlich

EOF
    exit 0
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --user=*)
                CODE_SERVER_USER="${1#*=}"
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

check_root() {
    if [ "$(id -u)" != "0" ]; then
        error_exit "Dieses Skript muss mit Root-Rechten ausgeführt werden. Verwende 'sudo'."
    fi
}

check_password_placeholder() {
    log_step "Prüfe QS_CODE_SERVER_PASSWORD..."
    
    local config_file="/home/${CODE_SERVER_USER}/.config/code-server/config.yaml"
    
    # Wenn Placeholder nicht ersetzt wurde
    if [ "$QS_CODE_SERVER_PASSWORD" = "QS_CODE_SERVER_PASSWORD" ]; then
        # Prüfe ob bereits eine Config existiert (Idempotenz)
        if [ -f "$config_file" ]; then
            # Extrahiere vorhandenes Passwort aus Config
            local existing_password=$(grep '^password:' "$config_file" | awk '{print $2}' || echo "")
            if [ -n "$existing_password" ]; then
                log_warning "QS_CODE_SERVER_PASSWORD nicht gesetzt, aber Config existiert bereits."
                log_info "Verwende bestehendes Passwort aus Config (Idempotenz)."
                # Überschreibe Placeholder mit bestehendem Passwort
                QS_CODE_SERVER_PASSWORD="$existing_password"
                log_success "Bestehendes Passwort wird beibehalten."
                return 0
            fi
        fi
        
        # Keine Config vorhanden - Abbruch erforderlich
        error_exit "QS_CODE_SERVER_PASSWORD wurde nicht gesetzt! Bitte ersetze den Platzhalter vor der Ausführung."
    fi
    
    # Mindestlänge prüfen
    if [ ${#QS_CODE_SERVER_PASSWORD} -lt 8 ]; then
        error_exit "QS_CODE_SERVER_PASSWORD muss mindestens 8 Zeichen lang sein."
    fi
    
    log_success "QS_CODE_SERVER_PASSWORD ist gesetzt (${#QS_CODE_SERVER_PASSWORD} Zeichen)."
}

check_code_server_installed() {
    log_step "Prüfe ob code-server installiert ist..."
    
    if ! command -v code-server &> /dev/null; then
        error_exit "code-server ist nicht installiert. Bitte führe zuerst 'install-code-server-qs.sh' aus."
    fi
    
    local version=$(code-server --version 2>&1 | head -n1)
    log_success "code-server ist installiert: ${version}"
}

check_user_exists() {
    log_step "Prüfe ob Benutzer '${CODE_SERVER_USER}' existiert..."
    
    if ! id "${CODE_SERVER_USER}" &> /dev/null; then
        error_exit "Benutzer '${CODE_SERVER_USER}' existiert nicht. Bitte führe zuerst 'install-code-server-qs.sh' aus."
    fi
    
    log_success "Benutzer '${CODE_SERVER_USER}' existiert."
}

check_service_exists() {
    log_step "Prüfe ob code-server-qs-Service existiert..."

    # Robuster Check mit explizitem Exit-Code-Handling (pipefail-safe)
    if systemctl list-unit-files | grep -q "code-server-qs.service"; then
        log_success "code-server-qs-Service existiert."
    else
        error_exit "code-server-qs-Service existiert nicht. Bitte führe zuerst 'install-code-server-qs.sh' aus."
    fi
}

# ============================================================================
# BACKUP-FUNKTIONEN
# ============================================================================

backup_config() {
    log_step "Erstelle Backup der aktuellen QS-Konfiguration..."
    
    local user_home="/home/${CODE_SERVER_USER}"
    local config_file="${user_home}/.config/code-server/config.yaml"
    local settings_file="${user_home}/.local/share/code-server/User/settings.json"
    
    mkdir -p "${BACKUP_DIR}"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="${BACKUP_DIR}/code-server_qs_backup_${timestamp}"
    
    if [ -f "${config_file}" ] || [ -f "${settings_file}" ]; then
        mkdir -p "${backup_path}"
        
        if [ -f "${config_file}" ]; then
            cp "${config_file}" "${backup_path}/" 2>/dev/null || true
            log_message "config.yaml gesichert."
        fi
        
        if [ -f "${settings_file}" ]; then
            mkdir -p "${backup_path}/User"
            cp "${settings_file}" "${backup_path}/User/" 2>/dev/null || true
            log_message "settings.json gesichert."
        fi
        
        if [ -d "${user_home}/.local/share/code-server/extensions" ]; then
            ls "${user_home}/.local/share/code-server/extensions" > "${backup_path}/extensions-list.txt" 2>/dev/null || true
        fi
        
        log_success "Backup erstellt: ${backup_path}"
        echo "${backup_path}" > "${BACKUP_DIR}/latest_backup.txt"
    else
        log_message "Keine vorherige Konfiguration gefunden."
    fi
}

# ============================================================================
# PASSWORT-FUNKTIONEN
# ============================================================================

save_password() {
    local password="$1"
    local user_home="/home/${CODE_SERVER_USER}"
    local password_file="${user_home}/.config/code-server/password.txt"
    
    log_step "Speichere QS-Passwort sicher..."
    
    echo "$password" > "$password_file"
    
    chown "${CODE_SERVER_USER}:${CODE_SERVER_USER}" "$password_file"
    chmod 600 "$password_file"
    
    log_success "QS-Passwort gespeichert in: ${password_file}"
    log_message "Berechtigungen: 600 (nur User lesbar)"
}

# ============================================================================
# KONFIGURATIONSFUNKTIONEN
# ============================================================================

create_directory_structure() {
    log_step "Erstelle/Prüfe QS-Verzeichnisstruktur..."
    
    local user_home="/home/${CODE_SERVER_USER}"
    
    mkdir -p "${user_home}/.config/code-server"
    mkdir -p "${user_home}/.local/share/code-server"
    mkdir -p "${user_home}/.local/share/code-server/User"
    mkdir -p "${user_home}/.local/share/code-server/extensions"
    
    chown -R "${CODE_SERVER_USER}:${CODE_SERVER_USER}" "${user_home}/.config/code-server"
    chown -R "${CODE_SERVER_USER}:${CODE_SERVER_USER}" "${user_home}/.local/share/code-server"
    
    log_success "QS-Verzeichnisstruktur erstellt/geprüft."
}

create_config_yaml() {
    local password="$1"
    local user_home="/home/${CODE_SERVER_USER}"
    local config_file="${user_home}/.config/code-server/config.yaml"
    
    log_step "Erstelle QS config.yaml..."
    
    # Erstelle neue Config in temporärer Datei
    local temp_config="/tmp/code-server-config-qs-$$.yaml"
    cat > "${temp_config}" << EOF
# QS-VPS code-server Konfiguration - Quality Server
# Generiert durch configure-code-server-qs.sh am $(date '+%Y-%m-%d %H:%M:%S')

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
    
    # Prüfe ob Änderungen nötig sind (checksum-basiert)
    if [ -f "${config_file}" ]; then
        local old_checksum=$(idempotency::calculate_checksum "${config_file}")
        local new_checksum=$(idempotency::calculate_checksum "${temp_config}")
        
        if [ "$old_checksum" = "$new_checksum" ]; then
            log_success "QS config.yaml ist bereits aktuell (Checksum: ${old_checksum})."
            rm -f "${temp_config}"
            return 0
        else
            log_message "Config-Änderungen erkannt (alt: ${old_checksum}, neu: ${new_checksum})."
        fi
    fi
    
    # Config übernehmen
    mv "${temp_config}" "${config_file}"
    chown "${CODE_SERVER_USER}:${CODE_SERVER_USER}" "${config_file}"
    chmod 600 "${config_file}"
    
    # State speichern
    idempotency::save_state "code_server_qs_config" "checksum=$(idempotency::calculate_checksum "${config_file}")"
    
    log_success "QS config.yaml erstellt: ${config_file}"
    log_message "Berechtigungen: 600 (nur User lesbar)"
}

create_workspace_settings() {
    log_step "Erstelle QS Workspace-Settings..."
    
    local user_home="/home/${CODE_SERVER_USER}"
    local settings_file="${user_home}/.local/share/code-server/User/settings.json"
    
    # Erstelle Settings in temporärer Datei
    local temp_settings="/tmp/code-server-settings-qs-$$.json"
    cat > "${temp_settings}" << 'EOF'
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
  "window.menuBarVisibility": "toggle",
  
  "window.title": "${dirty}${activeEditorShort}${separator}${rootName} [QS-VPS]"
}
EOF
    
    # Prüfe ob Änderungen nötig sind (checksum-basiert)
    if [ -f "${settings_file}" ]; then
        local old_checksum=$(idempotency::calculate_checksum "${settings_file}")
        local new_checksum=$(idempotency::calculate_checksum "${temp_settings}")
        
        if [ "$old_checksum" = "$new_checksum" ]; then
            log_success "QS Workspace-Settings sind bereits aktuell (Checksum: ${old_checksum})."
            rm -f "${temp_settings}"
            return 0
        else
            log_message "Settings-Änderungen erkannt (alt: ${old_checksum}, neu: ${new_checksum})."
        fi
    fi
    
    # Settings übernehmen
    mv "${temp_settings}" "${settings_file}"
    chown "${CODE_SERVER_USER}:${CODE_SERVER_USER}" "${settings_file}"
    chmod 644 "${settings_file}"
    
    # State speichern
    idempotency::save_state "code_server_qs_settings" "checksum=$(idempotency::calculate_checksum "${settings_file}")"
    
    log_success "QS Workspace-Settings erstellt: ${settings_file}"
}

# ============================================================================
# EXTENSIONS-FUNKTIONEN
# ============================================================================

install_extensions() {
    if [ "$INSTALL_EXTENSIONS" = false ]; then
        log_message "Extension-Installation übersprungen (--no-extensions)."
        return 0
    fi
    
    # Prüfe ob Extensions bereits installiert wurden
    if idempotency::check_marker "code_server_qs_extensions_installed"; then
        log_success "Extensions wurden bereits installiert (Marker gefunden)."
        log_message "Nutze --force-redeploy zum erneuten Installieren."
        return 0
    fi
    
    log_step "Installiere VS Code Extensions für QS-VPS..."
    
    local installed_count=0
    local failed_count=0
    local failed_extensions=()
    
    for ext in "${EXTENSIONS[@]}"; do
        log_message "Installiere Extension: ${ext}"
        
        if su - "${CODE_SERVER_USER}" -c "code-server --install-extension ${ext} --force" >> "$QS_LOG_FILE" 2>&1; then
            log_success "  ✓ ${ext} installiert"
            ((installed_count++))
        else
            log_warning "  ✗ ${ext} konnte nicht installiert werden"
            failed_extensions+=("${ext}")
            ((failed_count++))
        fi
    done
    
    # Marker setzen (auch wenn einige fehlgeschlagen sind)
    idempotency::set_marker "code_server_qs_extensions_installed"
    
    # State speichern
    idempotency::save_state "code_server_qs_extensions" "installed=${installed_count} failed=${failed_count}"
    
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

list_installed_extensions() {
    log_step "Liste installierte Extensions auf..."
    
    if su - "${CODE_SERVER_USER}" -c "code-server --list-extensions" > /tmp/extensions-list-qs.txt 2>&1; then
        local ext_count=$(wc -l < /tmp/extensions-list-qs.txt)
        log_success "Installierte Extensions (${ext_count}):"
        
        while IFS= read -r ext; do
            echo "  • ${ext}"
        done < /tmp/extensions-list-qs.txt
        
        rm -f /tmp/extensions-list-qs.txt
    else
        log_warning "Konnte Extensions nicht auflisten."
    fi
}

# ============================================================================
# SERVICE-MANAGEMENT
# ============================================================================

restart_service() {
    log_step "Starte code-server-qs-Service neu..."
    
    if systemctl restart code-server-qs 2>&1 | tee -a "$QS_LOG_FILE"; then
        log_success "Service erfolgreich neu gestartet."
        
        # Marker setzen
        idempotency::set_marker "code_server_qs_service_restarted"
    else
        log_error "Fehler beim Neustart des Services."
        return 1
    fi
    
    sleep 3
}

check_service_status() {
    log_step "Prüfe QS-Service-Status..."
    
    if systemctl is-active --quiet code-server-qs; then
        log_success "code-server-qs-Service läuft."
        
        log_message "Service-Details:"
        systemctl status code-server-qs --no-pager -l | head -n 15 | tee -a "$QS_LOG_FILE"
        
        return 0
    else
        log_error "code-server-qs-Service läuft nicht!"
        log_error "Prüfe Logs mit: journalctl -u code-server-qs -n 50"
        
        log_message "Letzte Log-Einträge:"
        journalctl -u code-server-qs -n 20 --no-pager | tee -a "$QS_LOG_FILE"
        
        return 1
    fi
}

validate_logs() {
    log_step "Validiere QS-Service-Logs..."
    
    sleep 2
    
    local error_count=$(journalctl -u code-server-qs -n 50 --no-pager | grep -i "error" | wc -l)
    
    if [ "$error_count" -gt 0 ]; then
        log_warning "Gefundene Fehler in Logs: ${error_count}"
        log_message "Letzte Fehler:"
        journalctl -u code-server-qs -n 50 --no-pager | grep -i "error" | tail -n 5
    else
        log_success "Keine Fehler in den Logs gefunden."
    fi
    
    if ss -tlnp | grep -q ":${CODE_SERVER_PORT}"; then
        log_success "code-server lauscht auf Port ${CODE_SERVER_PORT}."
    else
        log_warning "code-server scheint nicht auf Port ${CODE_SERVER_PORT} zu lauschen."
    fi
}

# ============================================================================
# ZUSAMMENFASSUNG
# ============================================================================

show_summary() {
    local tailscale_ip=""
    
    if command -v tailscale &> /dev/null; then
        tailscale_ip=$(tailscale ip -4 2>/dev/null | head -n1 || echo "nicht verfügbar")
    else
        tailscale_ip="nicht verfügbar"
    fi
    
    echo ""
    echo "============================================================================"
    log_success "QS-VPS: code-server-Konfiguration erfolgreich abgeschlossen!"
    echo "============================================================================"
    echo ""
    log_message "Konfigurationsdetails:"
    echo "  • Environment:           QS-VPS (Quality Server)"
    echo "  • Benutzer:              ${CODE_SERVER_USER}"
    echo "  • Bind-Adresse:          127.0.0.1:${CODE_SERVER_PORT}"
    echo "  • Authentifizierung:     password (QS-spezifisch)"
    echo "  • TLS:                   false (Caddy übernimmt SSL)"
    echo "  • Extensions installiert: ${INSTALL_EXTENSIONS}"
    echo ""
    log_message "Zugriffs-URLs (über Caddy/Tailscale):"
    if [ "$tailscale_ip" != "nicht verfügbar" ]; then
        echo "  • https://${tailscale_ip}"
    fi
    echo "  • https://[QS-TAILSCALE-IP]"
    echo "  • https://[QS-TAILSCALE-DOMAIN]"
    echo ""
    log_message "Wichtige Dateien:"
    echo "  • Konfiguration:         /home/${CODE_SERVER_USER}/.config/code-server/config.yaml"
    echo "  • Passwort-Datei:        /home/${CODE_SERVER_USER}/.config/code-server/password.txt"
    echo "  • Workspace-Settings:    /home/${CODE_SERVER_USER}/.local/share/code-server/User/settings.json"
    echo "  • Extensions-Verzeichnis: /home/${CODE_SERVER_USER}/.local/share/code-server/extensions"
    echo "  • Deployment-Log:        ${QS_LOG_FILE}"
    echo ""
    log_message "Nützliche Befehle:"
    echo "  • Status prüfen:         sudo systemctl status code-server-qs"
    echo "  • Logs anzeigen:         sudo journalctl -u code-server-qs -f"
    echo "  • Service neustarten:    sudo systemctl restart code-server-qs"
    echo "  • Extensions auflisten:  su - ${CODE_SERVER_USER} -c 'code-server --list-extensions'"
    echo ""
    log_message "Nächste Schritte:"
    echo "  1. Stelle sicher, dass Caddy als Reverse Proxy konfiguriert ist"
    echo "  2. Greife über Tailscale auf code-server zu"
    echo "  3. Führe test-qs-deployment.sh aus für E2E-Tests"
    echo ""
    echo "============================================================================"
    echo ""
}

# ============================================================================
# HAUPTPROGRAMM
# ============================================================================

main() {
    echo ""
    echo "============================================================================"
    echo "  QS-VPS - code-server Konfigurationsskript für Quality Server"
    echo "  Version 1.0"
    echo "============================================================================"
    echo ""
    
    parse_arguments "$@"
    
    # Validierungen
    check_root
    check_password_placeholder
    check_code_server_installed
    check_user_exists
    check_service_exists
    
    # Backup erstellen
    backup_config
    
    # Passwort verwenden
    local password="$QS_CODE_SERVER_PASSWORD"
    save_password "$password"
    
    # Konfiguration erstellen
    create_directory_structure
    create_config_yaml "$password"
    create_workspace_settings
    
    # Extensions installieren
    install_extensions
    
    # Service neu starten
    if ! restart_service; then
        error_exit "Service-Neustart fehlgeschlagen."
    fi
    
    # Status prüfen
    if ! check_service_status; then
        error_exit "Service läuft nicht korrekt."
    fi
    
    # Logs validieren
    validate_logs
    
    # Installierte Extensions auflisten
    if [ "$INSTALL_EXTENSIONS" = true ]; then
        echo ""
        list_installed_extensions
    fi
    
    # Zusammenfassung anzeigen
    show_summary
    
    # Finale Marker und State
    idempotency::set_marker "code_server_qs_configured"
    idempotency::save_state "code_server_qs_deployment" "timestamp=$(date -Iseconds) user=${CODE_SERVER_USER} port=${CODE_SERVER_PORT}"
    
    # Status-Report
    idempotency::status_report "code-server-qs Konfiguration"
    
    log_success "QS-VPS: Konfiguration erfolgreich abgeschlossen!"
    exit 0
}

# Skript ausführen
main "$@"
