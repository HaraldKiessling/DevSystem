#!/bin/bash
#
# code-server Installationsskript für DevSystem
# Dieses Skript automatisiert die Installation und Konfiguration von code-server
# als Web-IDE auf einem Ubuntu VPS für das DevSystem Projekt.
#
# Version: 1.0
# Autor: DevSystem Team
# Datum: $(date +%Y-%m-%d)
#
# Funktionen:
# - Installation von code-server auf dem Ubuntu VPS
# - Erstellung eines dedizierten Benutzers für code-server
# - Konfiguration für automatischen Start via systemd
# - Erstellung der grundlegenden Verzeichnisstruktur
# - Basis-Konfiguration (wird später vom Konfigurationsskript überschrieben)
# - Integration mit Caddy als Reverse Proxy
#
# Verwendung: sudo bash install-code-server.sh [--user=NAME] [--port=PORT] [--config-only]

# Fehler bei der Ausführung beenden das Skript
set -e

# Farbdefinitionen für Terminal-Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message${NC}"
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
                echo "Verwendung: sudo bash install-code-server.sh [--user=NAME] [--port=PORT] [--config-only]"
                echo ""
                echo "Optionen:"
                echo "  --user=NAME       Spezifiziert den Benutzernamen für code-server (Standard: codeserver)"
                echo "  --port=PORT       Spezifiziert den Port für code-server (Standard: 8080)"
                echo "  --config-only     Nur Konfiguration durchführen, keine Installation"
                echo ""
                exit 0
                ;;
        esac
    done
    
    # Standardwerte setzen, falls nicht angegeben
    CODE_SERVER_USER=${CODE_SERVER_USER:-"codeserver"}
    CODE_SERVER_PORT=${CODE_SERVER_PORT:-"8080"}
}

# Systemvoraussetzungen prüfen
check_prerequisites() {
    log "STEP" "Prüfe Systemvoraussetzungen..."
    
    # Prüfen, ob Ubuntu verwendet wird
    if [ ! -f /etc/lsb-release ] || ! grep -q "Ubuntu" /etc/lsb-release; then
        error_exit "Dieses Skript ist für Ubuntu-Systeme ausgelegt. Ihre Distribution wird nicht unterstützt."
    fi
    
    # Prüfen, ob die erforderlichen Befehle installiert sind
    for cmd in apt-get curl systemctl; do
        if ! command -v $cmd &> /dev/null; then
            error_exit "Der Befehl '$cmd' wird benötigt, ist aber nicht installiert."
        fi
    done
    
    # Prüfen, ob Caddy installiert ist (für Reverse Proxy)
    if ! command -v caddy &> /dev/null; then
        log "WARN" "Caddy scheint nicht installiert zu sein. Es wird als Reverse Proxy benötigt."
        log "WARN" "Bitte installieren Sie Caddy zuerst mit dem install-caddy.sh Skript."
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

# Dedizierten Benutzer für code-server erstellen
create_user() {
    log "STEP" "Erstelle dedizierten Benutzer für code-server..."
    
    # Prüfen, ob der Benutzer bereits existiert
    if id "$CODE_SERVER_USER" &>/dev/null; then
        log "WARN" "Benutzer '$CODE_SERVER_USER' existiert bereits. Überspringe Benutzererstellung."
    else
        log "INFO" "Erstelle Benutzer '$CODE_SERVER_USER'..."
        
        # Benutzer mit Home-Verzeichnis erstellen
        useradd -m -s /bin/bash "$CODE_SERVER_USER" || error_exit "Fehler beim Erstellen des Benutzers '$CODE_SERVER_USER'."
        
        log "INFO" "Benutzer '$CODE_SERVER_USER' erfolgreich erstellt."
    fi
}

# code-server installieren
install_code_server() {
    log "STEP" "Installiere code-server..."
    
    # Aktualisieren der Paketlisten
    log "INFO" "Aktualisiere Paketlisten..."
    apt-get update -y || error_exit "Fehler beim Aktualisieren der Paketlisten."
    
    # Installation der erforderlichen Abhängigkeiten
    log "INFO" "Installiere erforderliche Abhängigkeiten..."
    apt-get install -y curl wget unzip git build-essential || error_exit "Fehler bei der Installation von Abhängigkeiten."
    
    # Installation von code-server über das offizielle Installationsskript
    log "INFO" "Lade und führe code-server Installationsskript aus..."
    curl -fsSL https://code-server.dev/install.sh | sh || error_exit "Fehler bei der Installation von code-server."
    
    log "INFO" "code-server erfolgreich installiert."
}

# Verzeichnisstruktur erstellen
create_directory_structure() {
    log "STEP" "Erstelle code-server-Verzeichnisstruktur..."
    
    # Home-Verzeichnis des Benutzers
    USER_HOME="/home/$CODE_SERVER_USER"
    
    # Erstelle Hauptverzeichnisse
    mkdir -p "$USER_HOME/.config/code-server"
    mkdir -p "$USER_HOME/.config/code-server/data"
    mkdir -p "$USER_HOME/.config/code-server/data/User"
    mkdir -p "$USER_HOME/.config/code-server/data/extensions"
    mkdir -p "$USER_HOME/.config/code-server/logs"
    mkdir -p "$USER_HOME/workspaces"
    mkdir -p "$USER_HOME/workspaces/DevSystem"
    
    # Setze Berechtigungen
    chown -R "$CODE_SERVER_USER:$CODE_SERVER_USER" "$USER_HOME/.config"
    chown -R "$CODE_SERVER_USER:$CODE_SERVER_USER" "$USER_HOME/workspaces"
    
    log "INFO" "Verzeichnisstruktur erfolgreich erstellt."
}

# Basis-Konfiguration erstellen
create_base_config() {
    log "STEP" "Erstelle Basis-Konfiguration für code-server..."
    
    USER_HOME="/home/$CODE_SERVER_USER"
    CONFIG_FILE="$USER_HOME/.config/code-server/config.yaml"
    
    # Erstellen der Basis-Konfigurationsdatei
    cat > "$CONFIG_FILE" << EOF
# code-server Basis-Konfiguration für DevSystem
# Diese Konfiguration wird später vom configure-code-server.sh Skript überschrieben
bind-addr: 127.0.0.1:$CODE_SERVER_PORT
auth: password
password: changeme
cert: false
user-data-dir: $USER_HOME/.config/code-server/data
EOF
    
    # Berechtigungen setzen
    chown "$CODE_SERVER_USER:$CODE_SERVER_USER" "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    
    log "INFO" "Basis-Konfiguration erstellt."
    log "WARN" "Das Standard-Passwort 'changeme' sollte später geändert werden!"
}

# Systemd-Service einrichten
configure_systemd_service() {
    log "STEP" "Konfiguriere systemd-Service für code-server..."
    
    USER_HOME="/home/$CODE_SERVER_USER"
    SERVICE_FILE="/etc/systemd/system/code-server.service"
    
    # Systemd-Service-Datei erstellen
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=code-server Web IDE for DevSystem
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

[Install]
WantedBy=multi-user.target
EOF
    
    log "INFO" "Systemd-Service-Datei erstellt."
    
    # Systemd neu laden
    systemctl daemon-reload || error_exit "Fehler beim Neuladen von systemd."
    
    # Service aktivieren (Auto-Start)
    log "INFO" "Aktiviere code-server-Service für automatischen Start..."
    systemctl enable code-server || error_exit "Fehler beim Aktivieren des code-server-Dienstes."
    
    log "INFO" "Systemd-Service erfolgreich konfiguriert."
}

# Service starten
start_service() {
    log "STEP" "Starte code-server-Service..."
    
    # Service starten
    if systemctl start code-server; then
        log "INFO" "code-server-Service erfolgreich gestartet."
    else
        log "ERROR" "Fehler beim Starten des code-server-Dienstes."
        log "INFO" "Überprüfen Sie die Logs mit: journalctl -u code-server -n 50"
        return 1
    fi
    
    # Kurz warten, damit der Service hochfahren kann
    sleep 3
    
    # Service-Status prüfen
    if systemctl is-active --quiet code-server; then
        log "INFO" "code-server-Service läuft."
    else
        log "WARN" "code-server-Service scheint nicht zu laufen."
        log "INFO" "Status: $(systemctl is-active code-server)"
    fi
}

# Verifiziere die Installation
verify_installation() {
    log "STEP" "Verifiziere die code-server-Installation..."
    
    # Prüfen, ob code-server installiert ist
    if ! command -v code-server &> /dev/null; then
        log "ERROR" "code-server wurde nicht gefunden. Installation fehlgeschlagen."
        return 1
    fi
    
    # code-server-Version prüfen
    log "INFO" "code-server-Version:"
    code-server --version || log "WARN" "Konnte Version nicht abrufen."
    
    # Prüfen, ob der Service läuft
    if ! systemctl is-active --quiet code-server; then
        log "WARN" "code-server-Service läuft nicht."
        log "INFO" "Versuche Service-Status abzurufen..."
        systemctl status code-server --no-pager || true
        return 1
    fi
    
    # Prüfen, ob code-server auf dem konfigurierten Port lauscht
    log "INFO" "Prüfe, ob code-server auf Port $CODE_SERVER_PORT lauscht..."
    if ss -tlnp | grep -q ":$CODE_SERVER_PORT"; then
        log "INFO" "code-server lauscht auf Port $CODE_SERVER_PORT."
    else
        log "WARN" "code-server scheint nicht auf Port $CODE_SERVER_PORT zu lauschen."
        log "INFO" "Aktive Ports:"
        ss -tlnp | grep code-server || log "WARN" "Keine code-server Ports gefunden."
    fi
    
    log "INFO" "Verifizierung abgeschlossen."
    return 0
}

# Zusätzliche hilfreiche Informationen anzeigen
show_info() {
    echo ""
    log "STEP" "Installation abgeschlossen!"
    echo ""
    echo -e "${GREEN}code-server wurde erfolgreich installiert und konfiguriert.${NC}"
    echo ""
    echo "Konfigurationsdetails:"
    echo "  - Benutzer:                     $CODE_SERVER_USER"
    echo "  - Port:                         $CODE_SERVER_PORT (localhost only)"
    echo "  - Bind-Address:                 127.0.0.1:$CODE_SERVER_PORT"
    echo "  - Home-Verzeichnis:             /home/$CODE_SERVER_USER"
    echo "  - Konfigurationsdatei:          /home/$CODE_SERVER_USER/.config/code-server/config.yaml"
    echo "  - Workspace-Verzeichnis:        /home/$CODE_SERVER_USER/workspaces"
    echo ""
    echo "Nützliche Befehle:"
    echo "  - Status anzeigen:              sudo systemctl status code-server"
    echo "  - Service starten:              sudo systemctl start code-server"
    echo "  - Service stoppen:              sudo systemctl stop code-server"
    echo "  - Service neu starten:          sudo systemctl restart code-server"
    echo "  - Logs anzeigen:                sudo journalctl -u code-server -f"
    echo "  - Logs (letzte 50 Zeilen):      sudo journalctl -u code-server -n 50"
    echo ""
    echo "Nächste Schritte:"
    echo "  1. Führen Sie das Konfigurationsskript aus: sudo bash scripts/configure-code-server.sh"
    echo "  2. Konfigurieren Sie Caddy als Reverse Proxy (falls noch nicht geschehen)"
    echo "  3. Greifen Sie auf code-server über Tailscale zu: https://code.devsystem.internal"
    echo ""
    echo -e "${YELLOW}WICHTIG: Das Standard-Passwort 'changeme' muss geändert werden!${NC}"
    echo -e "${YELLOW}Bearbeiten Sie: /home/$CODE_SERVER_USER/.config/code-server/config.yaml${NC}"
    echo ""
    echo "Weitere Informationen finden Sie in der offiziellen Dokumentation:"
    echo "  https://coder.com/docs/code-server"
    echo ""
}

# Hauptfunktion
main() {
    log "STEP" "Starte code-server-Installation für DevSystem..."
    
    # Prüfungen
    check_root
    parse_args "$@"
    check_prerequisites
    
    # Installation, wenn code-server noch nicht installiert ist
    if [ "$CONFIG_ONLY" != "true" ]; then
        if ! check_code_server; then
            # Benutzer erstellen
            create_user
            
            # code-server installieren
            install_code_server
        else
            log "INFO" "code-server ist bereits installiert. Überspringe Installation."
        fi
    else
        log "INFO" "Überspringe Installation, nur Konfiguration wird durchgeführt."
        
        # Benutzer muss existieren für Konfiguration
        if ! id "$CODE_SERVER_USER" &>/dev/null; then
            create_user
        fi
    fi
    
    # Konfigurationen
    create_directory_structure
    create_base_config
    configure_systemd_service
    
    # Service starten
    start_service
    
    # Verifizieren und abschließen
    if verify_installation; then
        show_info
        log "INFO" "code-server-Installation und -Konfiguration erfolgreich abgeschlossen."
    else
        log "ERROR" "Verifizierung fehlgeschlagen. Bitte überprüfen Sie die Logs."
        log "INFO" "Logs anzeigen mit: sudo journalctl -u code-server -n 50"
        exit 1
    fi
}

# Skript ausführen
main "$@"
