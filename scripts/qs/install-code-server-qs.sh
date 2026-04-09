#!/bin/bash
#
# QS-VPS: code-server Installationsskript für DevSystem Quality Server
#
# Zweck:
#   Installation von code-server auf dem QS-VPS
#   Angepasste Version mit QS-spezifischen Einstellungen
#
# Voraussetzungen:
#   - Ubuntu System
#   - Root-Rechte
#
# Parameter:
#   --user=NAME       Benutzer für code-server (Standard: codeserver-qs)
#   --port=PORT       Port für code-server (Standard: 8080)
#   --config-only     Nur Konfiguration, keine Installation
#
# Verwendung:
#   sudo bash install-code-server-qs.sh
#

set -euo pipefail

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
            --help)
                echo "Verwendung: sudo bash install-code-server-qs.sh [--user=NAME] [--port=PORT] [--config-only]"
                echo ""
                echo "Optionen:"
                echo "  --user=NAME       Benutzer für code-server (Standard: codeserver-qs)"
                echo "  --port=PORT       Port für code-server (Standard: 8080)"
                echo "  --config-only     Nur Konfiguration durchführen"
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

# Prüfen, ob code-server bereits installiert ist
check_code_server() {
    if command -v code-server &> /dev/null; then
        log "WARN" "code-server ist bereits installiert. Überspringe die Installation."
        return 0
    else
        return 1
    fi
}

# Dedizierten QS-Benutzer erstellen
create_user() {
    log "STEP" "Erstelle dedizierten QS-Benutzer für code-server..."
    
    if id "$CODE_SERVER_USER" &>/dev/null; then
        log "WARN" "Benutzer '$CODE_SERVER_USER' existiert bereits."
    else
        log "INFO" "Erstelle Benutzer '$CODE_SERVER_USER'..."
        useradd -m -s /bin/bash "$CODE_SERVER_USER" || error_exit "Fehler beim Erstellen des Benutzers."
        
        # QS-Marker im Home-Verzeichnis erstellen
        echo "QS-VPS Quality Server User" > "/home/$CODE_SERVER_USER/QS-ENVIRONMENT"
        echo "Created: $(date)" >> "/home/$CODE_SERVER_USER/QS-ENVIRONMENT"
        chown "$CODE_SERVER_USER:$CODE_SERVER_USER" "/home/$CODE_SERVER_USER/QS-ENVIRONMENT"
        
        log "INFO" "Benutzer '$CODE_SERVER_USER' erfolgreich erstellt."
    fi
}

# code-server installieren
install_code_server() {
    log "STEP" "Installiere code-server auf QS-VPS..."
    
    log "INFO" "Aktualisiere Paketlisten..."
    apt-get update -y || error_exit "Fehler beim Aktualisieren der Paketlisten."
    
    log "INFO" "Installiere erforderliche Abhängigkeiten..."
    apt-get install -y curl wget unzip git build-essential || error_exit "Fehler bei der Installation von Abhängigkeiten."
    
    log "INFO" "Lade und führe code-server Installationsskript aus..."
    curl -fsSL https://code-server.dev/install.sh | sh || error_exit "Fehler bei der Installation von code-server."
    
    log "INFO" "code-server erfolgreich auf QS-VPS installiert."
}

# Verzeichnisstruktur erstellen
create_directory_structure() {
    log "STEP" "Erstelle QS-spezifische code-server-Verzeichnisstruktur..."
    
    USER_HOME="/home/$CODE_SERVER_USER"
    
    mkdir -p "$USER_HOME/.config/code-server"
    mkdir -p "$USER_HOME/.config/code-server/data"
    mkdir -p "$USER_HOME/.config/code-server/data/User"
    mkdir -p "$USER_HOME/.config/code-server/data/extensions"
    mkdir -p "$USER_HOME/.config/code-server/logs"
    mkdir -p "$USER_HOME/workspaces"
    mkdir -p "$USER_HOME/workspaces/DevSystem-QS"
    
    # QS-Marker in Workspace erstellen
    echo "# QS-VPS Workspace" > "$USER_HOME/workspaces/README-QS.md"
    echo "Dies ist der Quality Server Workspace für DevSystem-Tests." >> "$USER_HOME/workspaces/README-QS.md"
    echo "Erstellt: $(date)" >> "$USER_HOME/workspaces/README-QS.md"
    
    chown -R "$CODE_SERVER_USER:$CODE_SERVER_USER" "$USER_HOME/.config"
    chown -R "$CODE_SERVER_USER:$CODE_SERVER_USER" "$USER_HOME/workspaces"
    
    log "INFO" "QS-Verzeichnisstruktur erfolgreich erstellt."
}

# Basis-Konfiguration erstellen mit QS-Kennzeichnung
create_base_config() {
    log "STEP" "Erstelle Basis-Konfiguration für QS code-server..."
    
    USER_HOME="/home/$CODE_SERVER_USER"
    CONFIG_FILE="$USER_HOME/.config/code-server/config.yaml"
    
    cat > "$CONFIG_FILE" << EOF
# QS-VPS code-server Basis-Konfiguration
# Quality Server Environment
# Diese Konfiguration wird später vom configure-code-server-qs.sh überschrieben
bind-addr: 127.0.0.1:$CODE_SERVER_PORT
auth: password
password: changeme-qs
cert: false
user-data-dir: $USER_HOME/.config/code-server/data
EOF
    
    chown "$CODE_SERVER_USER:$CODE_SERVER_USER" "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    
    log "INFO" "Basis-Konfiguration erstellt."
    log "WARN" "Das Standard-Passwort 'changeme-qs' sollte später geändert werden!"
}

# Systemd-Service einrichten mit QS-Kennzeichnung
configure_systemd_service() {
    log "STEP" "Konfiguriere systemd-Service für QS code-server..."
    
    USER_HOME="/home/$CODE_SERVER_USER"
    SERVICE_FILE="/etc/systemd/system/code-server-qs.service"
    
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=code-server Web IDE for DevSystem QS-VPS
Documentation=https://github.com/coder/code-server
After=network.target

[Service]
Type=exec
User=$CODE_SERVER_USER
Group=$CODE_SERVER_USER
WorkingDirectory=$USER_HOME
ExecStart=/usr/bin/code-server --config $USER_HOME/.config/code-server/config.yaml
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Sicherheitseinstellungen
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=$USER_HOME/.config/code-server $USER_HOME/workspaces

# Ressourcenlimits
LimitNOFILE=65536
LimitNPROC=4096

# QS-Environment Variable
Environment="QS_ENVIRONMENT=quality-server"

[Install]
WantedBy=multi-user.target
EOF
    
    log "INFO" "Systemd-Service-Datei erstellt."
    
    systemctl daemon-reload || error_exit "Fehler beim Neuladen von systemd."
    
    log "INFO" "Aktiviere code-server-qs-Service für automatischen Start..."
    systemctl enable code-server-qs || error_exit "Fehler beim Aktivieren des Dienstes."
    
    log "INFO" "Systemd-Service erfolgreich konfiguriert."
}

# Service starten
start_service() {
    log "STEP" "Starte code-server-qs-Service..."
    
    if systemctl start code-server-qs; then
        log "INFO" "code-server-qs-Service erfolgreich gestartet."
    else
        log "ERROR" "Fehler beim Starten des Dienstes."
        log "INFO" "Überprüfen Sie die Logs mit: journalctl -u code-server-qs -n 50"
        return 1
    fi
    
    sleep 3
    
    if systemctl is-active --quiet code-server-qs; then
        log "INFO" "code-server-qs-Service läuft."
    else
        log "WARN" "code-server-qs-Service scheint nicht zu laufen."
    fi
}

# Verifiziere die Installation
verify_installation() {
    log "STEP" "Verifiziere die QS code-server-Installation..."
    
    if ! command -v code-server &> /dev/null; then
        log "ERROR" "code-server wurde nicht gefunden. Installation fehlgeschlagen."
        return 1
    fi
    
    log "INFO" "code-server-Version:"
    code-server --version || log "WARN" "Konnte Version nicht abrufen."
    
    if ! systemctl is-active --quiet code-server-qs; then
        log "WARN" "code-server-qs-Service läuft nicht."
        systemctl status code-server-qs --no-pager || true
        return 1
    fi
    
    log "INFO" "Prüfe, ob code-server auf Port $CODE_SERVER_PORT lauscht..."
    if ss -tlnp | grep -q ":$CODE_SERVER_PORT"; then
        log "INFO" "code-server lauscht auf Port $CODE_SERVER_PORT."
    else
        log "WARN" "code-server scheint nicht auf Port $CODE_SERVER_PORT zu lauschen."
    fi
    
    log "INFO" "Verifizierung abgeschlossen."
    return 0
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
    log "STEP" "Starte QS-VPS code-server-Installation..."
    
    check_root
    parse_args "$@"
    check_prerequisites
    
    if [ "$CONFIG_ONLY" != "true" ]; then
        if ! check_code_server; then
            create_user
            install_code_server
        else
            log "INFO" "code-server ist bereits installiert. Überspringe Installation."
        fi
    else
        log "INFO" "Überspringe Installation, nur Konfiguration wird durchgeführt."
        if ! id "$CODE_SERVER_USER" &>/dev/null; then
            create_user
        fi
    fi
    
    create_directory_structure
    create_base_config
    configure_systemd_service
    start_service
    
    if verify_installation; then
        show_info
        log "INFO" "QS-VPS: code-server-Installation erfolgreich abgeschlossen."
    else
        log "ERROR" "Verifizierung fehlgeschlagen. Bitte überprüfen Sie die Logs."
        exit 1
    fi
}

# Skript ausführen
main "$@"
