#!/bin/bash
#
# QS-VPS: code-server Installationsskript für DevSystem Quality Server
#
# Zweck:
#   Installation von code-server auf dem QS-VPS
#   Angepasste Version mit QS-spezifischen Einstellungen
#   Mit integrierter Idempotenz-Library für wiederholbare Deployments
#
# Voraussetzungen:
#   - Ubuntu System
#   - Root-Rechte
#
# Parameter:
#   --user=NAME       Benutzer für code-server (Standard: codeserver-qs)
#   --port=PORT       Port für code-server (Standard: 8080)
#   --config-only     Nur Konfiguration, keine Installation
#   --force           Force-Redeploy (ignoriert bestehende Marker)
#
# Verwendung:
#   sudo bash install-code-server-qs.sh
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

# Farbdefinitionen für Terminal-Ausgabe
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# QS-spezifische Einstellungen
readonly QS_LOG_FILE="/var/log/qs-deployment.log"
readonly QS_MARKER="QS-VPS"
readonly COMPONENT_NAME="code-server"

# Logging-Funktion
log() {
    local level=$1
    local message=$2
    local color=$NC
    
    case $level in
        "INFO") color=$GREEN ;;
        "WARN") color=$YELLOW ;;
        "ERROR") color=$RED ;;
        "STEP") color=$BLUE ;;
    esac
    
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [${QS_MARKER}] [$level] $message${NC}" | tee -a "$QS_LOG_FILE"
}

# Fehlermeldung und Exit-Funktion
error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Root-Berechtigungen prüfen
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error_exit "Dieses Skript muss als Root ausgeführt werden. Bitte verwenden Sie 'sudo'."
    fi
}

# Kommandozeilenargumente parsen
parse_args() {
    CONFIG_ONLY=false
    export FORCE_REDEPLOY=false
    
    for arg in "$@"; do
        case $arg in
            --user=*)
                CODE_SERVER_USER="${arg#*=}"
                ;;
            --port=*)
                CODE_SERVER_PORT="${arg#*=}"
                ;;
            --config-only)
                CONFIG_ONLY=true
                ;;
            --force)
                export FORCE_REDEPLOY=true
                log "WARN" "Force-Redeploy aktiviert - bestehende Marker werden ignoriert"
                ;;
            --help)
                echo "Verwendung: sudo bash install-code-server-qs.sh [--user=NAME] [--port=PORT] [--config-only] [--force]"
                echo ""
                echo "Optionen:"
                echo "  --user=NAME       Benutzer für code-server (Standard: codeserver-qs)"
                echo "  --port=PORT       Port für code-server (Standard: 8080)"
                echo "  --config-only     Nur Konfiguration durchführen"
                echo "  --force           Force-Redeploy (ignoriert bestehende Marker)"
                echo ""
                exit 0
                ;;
        esac
    done
    
    # QS-spezifische Standardwerte
    CODE_SERVER_USER=${CODE_SERVER_USER:-"codeserver-qs"}
    CODE_SERVER_PORT=${CODE_SERVER_PORT:-"8080"}
}

# Systemvoraussetzungen prüfen
check_prerequisites() {
    log "STEP" "Prüfe Systemvoraussetzungen für QS-VPS..."
    
    if [ ! -f /etc/lsb-release ] || ! grep -q "Ubuntu" /etc/lsb-release; then
        error_exit "Dieses Skript ist für Ubuntu-Systeme ausgelegt."
    fi
    
    for cmd in apt-get curl systemctl; do
        if ! command -v $cmd &> /dev/null; then
            error_exit "Der Befehl '$cmd' wird benötigt, ist aber nicht installiert."
        fi
    done
    
    if ! command -v caddy &> /dev/null; then
        log "WARN" "Caddy scheint nicht installiert zu sein. Es wird als Reverse Proxy benötigt."
    fi
    
    log "INFO" "Systemvoraussetzungen erfüllt."
}

# Prüfen, ob code-server bereits installiert ist (mit State-Check)
check_code_server_installation() {
    if marker_exists "code-server-installed"; then
        local installed_version=$(get_state "$COMPONENT_NAME" "version")
        log "INFO" "code-server ist bereits installiert (Version: $installed_version)"
        return 0
    else
        return 1
    fi
}

# Dedizierten QS-Benutzer erstellen
create_user() {
    run_idempotent "code-server-user-created" "QS-Benutzer für code-server erstellen" bash -c "
        if ! id '$CODE_SERVER_USER' &>/dev/null; then
            useradd -m -s /bin/bash '$CODE_SERVER_USER'
            
            # QS-Marker im Home-Verzeichnis erstellen
            cat > '/home/$CODE_SERVER_USER/QS-ENVIRONMENT' << 'EOF_USER'
QS-VPS Quality Server User
Created: \$(date -Iseconds)
User: $CODE_SERVER_USER
EOF_USER
            chown '$CODE_SERVER_USER:$CODE_SERVER_USER' '/home/$CODE_SERVER_USER/QS-ENVIRONMENT'
        fi
    "
    
    save_state "$COMPONENT_NAME" "user" "$CODE_SERVER_USER"
    log "INFO" "Benutzer '$CODE_SERVER_USER' bereit."
}

# Dependencies installieren
install_dependencies() {
    run_idempotent "code-server-dependencies" "code-server Dependencies installieren" bash -c '
        apt-get update -y
        apt-get install -y curl wget unzip git build-essential
    '
}

# code-server installieren
install_code_server() {
    log "STEP" "Installiere code-server auf QS-VPS..."
    
    # Dependencies
    install_dependencies
    
    # code-server installieren
    run_idempotent "code-server-package-install" "code-server-Paket installieren" bash -c '
        curl -fsSL https://code-server.dev/install.sh | sh
    '
    
    # Version speichern
    if command -v code-server &> /dev/null; then
        local version=$(code-server --version 2>&1 | head -n1 || echo "unknown")
        save_state "$COMPONENT_NAME" "version" "$version"
        save_state "$COMPONENT_NAME" "install_date" "$(date -Iseconds)"
        
        # Gesamt-Marker setzen
        set_marker "code-server-installed" "code-server installed: $version"
        
        log "INFO" "code-server erfolgreich auf QS-VPS installiert: $version"
    else
        error_exit "code-server Installation fehlgeschlagen!"
    fi
}

# Verzeichnisstruktur erstellen
create_directory_structure() {
    log "STEP" "Erstelle QS-spezifische code-server-Verzeichnisstruktur..."
    
    local user_home="/home/$CODE_SERVER_USER"
    
    run_idempotent "code-server-directories" "code-server-Verzeichnisstruktur erstellen" bash -c "
        mkdir -p '$user_home/.config/code-server'
        mkdir -p '$user_home/.config/code-server/data'
        mkdir -p '$user_home/.config/code-server/data/User'
        mkdir -p '$user_home/.config/code-server/data/extensions'
        mkdir -p '$user_home/.config/code-server/logs'
        mkdir -p '$user_home/workspaces'
        mkdir -p '$user_home/workspaces/DevSystem-QS'
        
        # QS-Marker in Workspace erstellen
        cat > '$user_home/workspaces/README-QS.md' << 'EOF_WS'
# QS-VPS Workspace
Dies ist der Quality Server Workspace für DevSystem-Tests.
Erstellt: \$(date -Iseconds)
EOF_WS
        
        chown -R '$CODE_SERVER_USER:$CODE_SERVER_USER' '$user_home/.config'
        chown -R '$CODE_SERVER_USER:$CODE_SERVER_USER' '$user_home/workspaces'
    "
    
    save_state "$COMPONENT_NAME" "directories_created" "true"
    log "INFO" "QS-Verzeichnisstruktur erfolgreich erstellt."
}

# Basis-Konfiguration erstellen mit QS-Kennzeichnung
create_base_config() {
    log "STEP" "Erstelle Basis-Konfiguration für QS code-server..."
    
    local user_home="/home/$CODE_SERVER_USER"
    local config_file="$user_home/.config/code-server/config.yaml"
    
    local config_content=$(cat << EOF
# QS-VPS code-server Basis-Konfiguration
# Quality Server Environment
# Diese Konfiguration wird später vom configure-code-server-qs.sh überschrieben
bind-addr: 127.0.0.1:$CODE_SERVER_PORT
auth: password
password: changeme-qs
cert: false
user-data-dir: $user_home/.config/code-server/data
EOF
)
    
    local current_checksum=""
    local new_checksum=""
    
    # Checksum berechnen
    if [ -f "$config_file" ]; then
        current_checksum=$(file_checksum "$config_file")
    fi
    new_checksum=$(echo "$config_content" | sha256sum | cut -d' ' -f1)
    
    # Nur aktualisieren wenn geändert
    if [ "$current_checksum" != "$new_checksum" ]; then
        backup_file "$config_file" "code-server-base-config"
        echo "$config_content" > "$config_file"
        
        chown "$CODE_SERVER_USER:$CODE_SERVER_USER" "$config_file"
        chmod 600 "$config_file"
        
        save_state "$COMPONENT_NAME" "base_config_checksum" "$new_checksum"
        save_state "$COMPONENT_NAME" "port" "$CODE_SERVER_PORT"
        set_marker "code-server-base-config" "Base config created"
        
        log "INFO" "Basis-Konfiguration erstellt/aktualisiert."
        log "WARN" "Das Standard-Passwort 'changeme-qs' sollte später geändert werden!"
    else
        log "INFO" "Basis-Konfiguration unverändert, überspringe."
    fi
}

# Systemd-Service einrichten mit QS-Kennzeichnung
configure_systemd_service() {
    log "STEP" "Konfiguriere systemd-Service für QS code-server..."
    
    local user_home="/home/$CODE_SERVER_USER"
    local service_file="/etc/systemd/system/code-server-qs.service"
    
    local service_content=$(cat << EOF
[Unit]
Description=code-server Web IDE for DevSystem QS-VPS
Documentation=https://github.com/coder/code-server
After=network.target

[Service]
Type=exec
User=$CODE_SERVER_USER
Group=$CODE_SERVER_USER
WorkingDirectory=$user_home
ExecStart=/usr/bin/code-server --config $user_home/.config/code-server/config.yaml
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Sicherheitseinstellungen
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=$user_home/.config/code-server $user_home/workspaces

# Ressourcenlimits
LimitNOFILE=65536
LimitNPROC=4096

# QS-Environment Variable
Environment="QS_ENVIRONMENT=quality-server"

[Install]
WantedBy=multi-user.target
EOF
)
    
    local current_checksum=""
    local new_checksum=""
    
    # Checksum berechnen
    if [ -f "$service_file" ]; then
        current_checksum=$(file_checksum "$service_file")
    fi
    new_checksum=$(echo "$service_content" | sha256sum | cut -d' ' -f1)
    
    # Nur aktualisieren wenn geändert
    if [ "$current_checksum" != "$new_checksum" ]; then
        backup_file "$service_file" "code-server-systemd-service"
        echo "$service_content" > "$service_file"
        
        systemctl daemon-reload || error_exit "Fehler beim Neuladen von systemd."
        
        save_state "$COMPONENT_NAME" "systemd_service_checksum" "$new_checksum"
        set_marker "code-server-systemd-service" "Systemd service configured"
        
        log "INFO" "Systemd-Service-Datei erstellt/aktualisiert."
    else
        log "INFO" "Systemd-Service unverändert, überspringe."
    fi
}

# Service aktivieren
enable_service() {
    run_idempotent "code-server-service-enabled" "code-server-Service aktivieren" bash -c '
        systemctl enable code-server-qs
    '
    
    log "INFO" "code-server-Service für automatischen Start aktiviert."
}

# Service starten
start_service() {
    log "STEP" "Starte code-server-qs-Service..."
    
    if systemctl is-active --quiet code-server-qs; then
        log "INFO" "Service läuft bereits, starte neu..."
        systemctl restart code-server-qs || error_exit "Fehler beim Neustart des Dienstes."
    else
        if systemctl start code-server-qs; then
            log "INFO" "code-server-qs-Service erfolgreich gestartet."
        else
            log "ERROR" "Fehler beim Starten des Dienstes."
            log "INFO" "Überprüfen Sie die Logs mit: journalctl -u code-server-qs -n 50"
            return 1
        fi
    fi
    
    sleep 3
    
    if systemctl is-active --quiet code-server-qs; then
        log "INFO" "code-server-qs-Service läuft."
        set_marker "code-server-service-started" "Service started successfully"
        save_state "$COMPONENT_NAME" "service_status" "active"
    else
        log "WARN" "code-server-qs-Service scheint nicht zu laufen."
        save_state "$COMPONENT_NAME" "service_status" "inactive"
    fi
}

# Verifiziere die Installation
verify_installation() {
    log "STEP" "Verifiziere die QS code-server-Installation..."
    
    # Binary vorhanden?
    if ! command -v code-server &> /dev/null; then
        log "ERROR" "code-server wurde nicht gefunden. Installation fehlgeschlagen."
        return 1
    fi
    
    # Version prüfen
    log "INFO" "code-server-Version:"
    local version=$(code-server --version 2>&1 || echo "Konnte Version nicht abrufen.")
    echo "$version" | tee -a "$QS_LOG_FILE"
    
    # Service läuft?
    if ! systemctl is-active --quiet code-server-qs; then
        log "WARN" "code-server-qs-Service läuft nicht."
        systemctl status code-server-qs --no-pager || true
        return 1
    fi
    
    # Port-Check
    log "INFO" "Prüfe, ob code-server auf Port $CODE_SERVER_PORT lauscht..."
    if ss -tlnp 2>/dev/null | grep -q ":$CODE_SERVER_PORT"; then
        log "INFO" "code-server lauscht auf Port $CODE_SERVER_PORT."
        set_marker "code-server-verified" "Installation verified successfully"
    else
        log "WARN" "code-server scheint nicht auf Port $CODE_SERVER_PORT zu lauschen."
    fi
    
    log "INFO" "Verifizierung abgeschlossen."
    return 0
}

# Installation-Status-Report generieren
generate_status_report() {
    log "STEP" "Generiere Installations-Status-Report..."
    
    local report_file="/var/lib/qs-deployment/reports/code-server-install-report.txt"
    mkdir -p "$(dirname "$report_file")"
    
    cat > "$report_file" << EOF
=============================================================================
QS-VPS code-server Installation Status Report
=============================================================================
Datum: $(date -Iseconds)
Component: $COMPONENT_NAME

Installation Details:
- Version: $(get_state "$COMPONENT_NAME" "version")
- Install-Datum: $(get_state "$COMPONENT_NAME" "install_date")
- Benutzer: $(get_state "$COMPONENT_NAME" "user")
- Port: $(get_state "$COMPONENT_NAME" "port")
- Directories: $(get_state "$COMPONENT_NAME" "directories_created")
- Service Status: $(get_state "$COMPONENT_NAME" "service_status")

Config Checksums:
- Base Config: $(get_state "$COMPONENT_NAME" "base_config_checksum")
- Systemd Service: $(get_state "$COMPONENT_NAME" "systemd_service_checksum")

Aktive Marker:
$(list_markers | grep "^code-server" || echo "Keine")

Systemd Service Status:
$(systemctl status code-server-qs --no-pager -l 2>&1 || echo "Service-Status konnte nicht abgerufen werden")

Port-Status:
$(ss -tlnp 2>/dev/null | grep ":$CODE_SERVER_PORT" || echo "Port $CODE_SERVER_PORT nicht aktiv")

=============================================================================
EOF
    
    log "INFO" "Status-Report erstellt: $report_file"
}

# Informationen anzeigen
show_info() {
    echo ""
    log "STEP" "QS-VPS: code-server-Installation abgeschlossen!"
    echo ""
    echo -e "${GREEN}code-server wurde erfolgreich auf dem QS-VPS installiert.${NC}"
    echo ""
    echo "QS-Konfigurationsdetails:"
    echo "  - Environment:                  QS-VPS (Quality Server)"
    echo "  - Benutzer:                     $CODE_SERVER_USER"
    echo "  - Port:                         $CODE_SERVER_PORT (localhost only)"
    echo "  - Bind-Address:                 127.0.0.1:$CODE_SERVER_PORT"
    echo "  - Home-Verzeichnis:             /home/$CODE_SERVER_USER"
    echo "  - Konfigurationsdatei:          /home/$CODE_SERVER_USER/.config/code-server/config.yaml"
    echo "  - Workspace-Verzeichnis:        /home/$CODE_SERVER_USER/workspaces"
    echo "  - Service-Name:                 code-server-qs"
    echo "  - Status-Report:                /var/lib/qs-deployment/reports/code-server-install-report.txt"
    echo ""
    echo "Idempotenz-Status:"
    echo "  - Marker-Directory:             $MARKER_DIR"
    echo "  - State-Directory:              $STATE_DIR"
    echo "  - Aktive Marker:                $(list_markers | grep "^code-server" | wc -l)"
    echo ""
    echo "Nützliche Befehle:"
    echo "  - Status anzeigen:              sudo systemctl status code-server-qs"
    echo "  - Service starten:              sudo systemctl start code-server-qs"
    echo "  - Service stoppen:              sudo systemctl stop code-server-qs"
    echo "  - Service neu starten:          sudo systemctl restart code-server-qs"
    echo "  - Logs anzeigen:                sudo journalctl -u code-server-qs -f"
    echo ""
    echo "Nächste Schritte:"
    echo "  1. Führe configure-code-server-qs.sh aus (mit QS_CODE_SERVER_PASSWORD)"
    echo "  2. Konfiguriere Caddy als Reverse Proxy"
    echo "  3. Teste den Zugriff über Tailscale"
    echo ""
    echo -e "${YELLOW}WICHTIG: Das Standard-Passwort 'changeme-qs' muss geändert werden!${NC}"
    echo ""
}

# Hauptfunktion
main() {
    log "STEP" "Starte QS-VPS code-server-Installation (mit Idempotenz)..."
    
    check_root
    parse_args "$@"
    check_prerequisites
    
    if [ "$CONFIG_ONLY" != "true" ]; then
        if ! check_code_server_installation; then
            create_user
            install_code_server
        else
            log "INFO" "code-server ist bereits installiert, überspringe Installation."
        fi
    else
        log "INFO" "Überspringe Installation, nur Konfiguration wird durchgeführt."
        create_user
    fi
    
    create_directory_structure
    create_base_config
    configure_systemd_service
    enable_service
    start_service
    
    if verify_installation; then
        generate_status_report
        show_info
        
        # Finaler Marker
        set_marker "code-server-install-complete" "Full installation completed"
        
        log "INFO" "QS-VPS: code-server-Installation erfolgreich abgeschlossen."
    else
        log "ERROR" "Verifizierung fehlgeschlagen. Bitte überprüfen Sie die Logs."
        exit 1
    fi
}

# Skript ausführen
main "$@"
