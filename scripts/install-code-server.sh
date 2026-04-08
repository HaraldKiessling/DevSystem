#!/bin/bash
#
# DevSystem - code-server Installationsskript
# Autor: DevSystem Team
# Datum: 2026-04-08
#
# Beschreibung: 
# Dieses Script installiert code-server (VS Code im Browser) für das DevSystem-Projekt.
# Es führt folgende Aktionen aus:
# - Installation der erforderlichen Abhängigkeiten
# - Installation von code-server über das offizielle Paket
# - Einrichtung eines systemd-Dienstes für automatischen Start
# - Grundlegende Konfiguration von code-server
#
# Voraussetzungen:
# - Ubuntu-System
# - Root-Zugriff
# - Caddy ist bereits installiert und konfiguriert

set -e # Script beenden, wenn ein Befehl fehlschlägt
set -u # Script beenden, wenn eine Variable nicht definiert ist

# Farbige Ausgabe für bessere Lesbarkeit
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funktion für Step-Nachrichten
log_step() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] [STEP] $1${NC}"
}

# Funktion für Infos
log_info() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1${NC}"
}

# Funktion für Warnungen
log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $1${NC}"
}

# Funktion für Fehler
log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1${NC}"
}

# Prüfen, ob das Script mit Root-Rechten ausgeführt wird
if [ "$(id -u)" != "0" ]; then
    log_error "Dieses Script muss mit Root-Rechten ausgeführt werden."
    exit 1
fi

# Standardwerte für Konfigurationsparameter
CODE_SERVER_VERSION="4.14.1"
CODE_SERVER_PORT="8080"
CODE_SERVER_USER="coder"
CODE_SERVER_PASSWORD=""
CODE_SERVER_BIND_ADDR="127.0.0.1"
CODE_SERVER_CONFIG_DIR="/etc/code-server"
CODE_SERVER_DATA_DIR="/var/lib/code-server"
CODE_SERVER_AUTH="password"
CREATE_USER=true

# Kommandozeilenargumente parsen
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --version=*) CODE_SERVER_VERSION="${1#*=}"; shift ;;
        --port=*) CODE_SERVER_PORT="${1#*=}"; shift ;;
        --user=*) CODE_SERVER_USER="${1#*=}"; shift ;;
        --password=*) CODE_SERVER_PASSWORD="${1#*=}"; shift ;;
        --bind-addr=*) CODE_SERVER_BIND_ADDR="${1#*=}"; shift ;;
        --config-dir=*) CODE_SERVER_CONFIG_DIR="${1#*=}"; shift ;;
        --data-dir=*) CODE_SERVER_DATA_DIR="${1#*=}"; shift ;;
        --auth=*) CODE_SERVER_AUTH="${1#*=}"; shift ;;
        --no-create-user) CREATE_USER=false; shift ;;
        --help) 
            echo "Verwendung: $0 [Optionen]"
            echo "Optionen:"
            echo "  --version=VERSION       Version von code-server (Standard: $CODE_SERVER_VERSION)"
            echo "  --port=PORT             Port für code-server (Standard: $CODE_SERVER_PORT)"
            echo "  --user=USER             Benutzername für code-server (Standard: $CODE_SERVER_USER)"
            echo "  --password=PASSWORD     Passwort für code-server (wenn --auth=password)"
            echo "  --bind-addr=ADDR        Bind-Adresse für code-server (Standard: $CODE_SERVER_BIND_ADDR)"
            echo "  --config-dir=DIR        Konfigurationsverzeichnis (Standard: $CODE_SERVER_CONFIG_DIR)"
            echo "  --data-dir=DIR          Datenverzeichnis (Standard: $CODE_SERVER_DATA_DIR)"
            echo "  --auth=TYPE             Authentifizierungstyp (password oder none) (Standard: $CODE_SERVER_AUTH)"
            echo "  --no-create-user        Keinen Benutzer erstellen"
            exit 0
            ;;
        *) log_error "Unbekannter Parameter: $1"; exit 1 ;;
    esac
done

# Willkommensnachricht
log_step "Starte code-server Installation für DevSystem..."

# Prüfe Systemvoraussetzungen
log_step "Prüfe Systemvoraussetzungen..."

# Prüfe, ob das System auf Ubuntu basiert
if [ ! -f /etc/os-release ] || ! grep -q "Ubuntu" /etc/os-release; then
    log_warning "Dieses Skript wurde für Ubuntu entwickelt. Andere Systeme werden möglicherweise nicht vollständig unterstützt."
else
    log_info "Ubuntu-System erkannt."
fi

# Prüfen, ob code-server bereits installiert ist
if command -v code-server &> /dev/null; then
    INSTALLED_VERSION=$(code-server --version | head -n 1 | cut -d ' ' -f 3)
    log_warning "code-server ist bereits installiert (Version $INSTALLED_VERSION)."
    
    if [[ "$INSTALLED_VERSION" == "$CODE_SERVER_VERSION" ]]; then
        log_info "Die installierte Version entspricht der angeforderten Version."
        SKIP_INSTALL=true
    else
        log_info "Die installierte Version unterscheidet sich von der angeforderten Version. Fahre mit der Installation fort."
        SKIP_INSTALL=false
    fi
else
    SKIP_INSTALL=false
    log_info "code-server ist noch nicht installiert. Fahre mit der Installation fort."
fi

# Benutzer erstellen, falls notwendig
if [ "$CREATE_USER" = true ] && ! id -u "$CODE_SERVER_USER" &>/dev/null; then
    log_step "Erstelle Benutzer '$CODE_SERVER_USER' für code-server..."
    useradd -m -s /bin/bash "$CODE_SERVER_USER"
    log_info "Benutzer '$CODE_SERVER_USER' wurde erstellt."
fi

# Installiere Abhängigkeiten
log_step "Installiere Abhängigkeiten..."
apt-get update
apt-get install -y curl wget unzip git build-essential openssl

# Verzeichnisse erstellen
log_step "Erstelle Verzeichnisstruktur..."
mkdir -p "$CODE_SERVER_CONFIG_DIR"
mkdir -p "$CODE_SERVER_DATA_DIR"

# Führe die Installation nur durch, wenn sie nicht übersprungen werden soll
if [ "$SKIP_INSTALL" = false ]; then
    log_step "Installiere code-server Version $CODE_SERVER_VERSION..."
    
    # Downloading and installing code-server
    cd /tmp
    wget -q "https://github.com/coder/code-server/releases/download/v$CODE_SERVER_VERSION/code-server_${CODE_SERVER_VERSION}_amd64.deb"
    
    if [ $? -eq 0 ]; then
        log_info "Download von code-server Version $CODE_SERVER_VERSION erfolgreich."
        
        # Install the Debian package
        dpkg -i "code-server_${CODE_SERVER_VERSION}_amd64.deb"
        
        if [ $? -eq 0 ]; then
            log_info "Installation von code-server Version $CODE_SERVER_VERSION erfolgreich."
            
            # Lösche die Installationsdatei
            rm "code-server_${CODE_SERVER_VERSION}_amd64.deb"
        else
            log_error "Installation von code-server ist fehlgeschlagen."
            exit 1
        fi
    else
        log_error "Download von code-server ist fehlgeschlagen."
        exit 1
    fi
else
    log_info "Installation von code-server wird übersprungen, da bereits installiert."
fi

# Konfiguration erstellen
log_step "Erstelle code-server Konfiguration..."

# Generiere ein zufälliges Passwort, wenn keines angegeben wurde und Authentifizierung auf Passwort gesetzt ist
if [[ "$CODE_SERVER_AUTH" == "password" && -z "$CODE_SERVER_PASSWORD" ]]; then
    CODE_SERVER_PASSWORD=$(openssl rand -base64 12)
    log_info "Zufälliges Passwort generiert: $CODE_SERVER_PASSWORD"
    log_warning "Bitte notieren Sie dieses Passwort, da es später nicht mehr angezeigt wird!"
fi

# Erstelle Konfigurationsdatei
cat > "$CODE_SERVER_CONFIG_DIR/config.yaml" << EOF
bind-addr: ${CODE_SERVER_BIND_ADDR}:${CODE_SERVER_PORT}
auth: ${CODE_SERVER_AUTH}
password: ${CODE_SERVER_PASSWORD}
cert: false
user-data-dir: ${CODE_SERVER_DATA_DIR}/user-data
extensions-dir: ${CODE_SERVER_DATA_DIR}/extensions
disable-telemetry: true
disable-update-check: true
app-name: "DevSystem"
log: debug
EOF

# Setze Berechtigungen
chown -R "$CODE_SERVER_USER":"$CODE_SERVER_USER" "$CODE_SERVER_CONFIG_DIR"
chown -R "$CODE_SERVER_USER":"$CODE_SERVER_USER" "$CODE_SERVER_DATA_DIR"
chmod 600 "$CODE_SERVER_CONFIG_DIR/config.yaml"

# Erstelle systemd-Servicedatei
log_step "Konfiguriere systemd-Dienst für code-server..."

cat > /etc/systemd/system/code-server.service << EOF
[Unit]
Description=code-server VS Code in browser
After=network.target

[Service]
User=${CODE_SERVER_USER}
Group=${CODE_SERVER_USER}
WorkingDirectory=/home/${CODE_SERVER_USER}
EnvironmentFile=-/etc/code-server/environment
ExecStart=/usr/bin/code-server --config ${CODE_SERVER_CONFIG_DIR}/config.yaml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Erstelle environment-Datei für zusätzliche Umgebungsvariablen
cat > "$CODE_SERVER_CONFIG_DIR/environment" << EOF
# Umgebungsvariablen für code-server
SHELL=/bin/bash
NODE_PATH=
PATH=/usr/local/bin:/usr/bin:/bin
EOF

# Systemd neu laden und Dienst aktivieren
systemctl daemon-reload
systemctl enable code-server.service

# Dienst starten
log_step "Starte code-server Dienst..."
systemctl restart code-server.service

# Prüfe, ob der Dienst erfolgreich gestartet wurde
if systemctl is-active --quiet code-server.service; then
    log_info "code-server Dienst ist aktiv."
else
    log_error "code-server Dienst konnte nicht gestartet werden. Prüfe die Logs mit 'journalctl -u code-server'."
    exit 1
fi

# Überprüfen, ob code-server auf dem konfigurierten Port lauscht
sleep 5
if ss -tuln | grep -q ":$CODE_SERVER_PORT "; then
    log_info "code-server läuft und lauscht auf Port $CODE_SERVER_PORT."
else
    log_warning "code-server lauscht nicht auf Port $CODE_SERVER_PORT. Bitte überprüfe die Konfiguration."
fi

# Installation von nützlichen VS Code Extensions
log_step "Installiere nützliche VS Code Extensions..."

CODE_SERVER_EXTENSIONS=(
    "ms-python.python" 
    "ms-azuretools.vscode-docker" 
    "redhat.vscode-yaml" 
    "dbaeumer.vscode-eslint"
)

for ext in "${CODE_SERVER_EXTENSIONS[@]}"; do
    log_info "Installiere Extension $ext..."
    sudo -u $CODE_SERVER_USER code-server --install-extension $ext
done

# Zusammenfassung
log_step "Installation von code-server abgeschlossen"
log_info "code-server Version: $CODE_SERVER_VERSION"
log_info "Benutzer: $CODE_SERVER_USER"
log_info "Bind-Adresse: $CODE_SERVER_BIND_ADDR:$CODE_SERVER_PORT"
log_info "Authentifizierungsmethode: $CODE_SERVER_AUTH"
log_info "Konfigurationsverzeichnis: $CODE_SERVER_CONFIG_DIR"
log_info "Datenverzeichnis: $CODE_SERVER_DATA_DIR"

log_info "Zugriff über: http://$CODE_SERVER_BIND_ADDR:$CODE_SERVER_PORT"
log_info "Zugriff über Caddy: https://code.devsystem.internal:9443"

log_info "code-server systemd service: code-server.service"
log_info "Logs anzeigen mit: journalctl -u code-server"

if [[ "$CODE_SERVER_AUTH" == "password" && -n "$CODE_SERVER_PASSWORD" ]]; then
    log_info "Authentifizierungsdaten:"
    log_info "  Passwort: $CODE_SERVER_PASSWORD"
fi

log_info "Installation erfolgreich abgeschlossen!"
exit 0