#!/bin/bash
#
# DevSystem - code-server Konfigurationsskript
# Autor: DevSystem Team
# Datum: 2026-04-08
#
# Beschreibung: 
# Dieses Script führt die fortgeschrittene Konfiguration von code-server für DevSystem durch.
# Es führt folgende Aktionen aus:
# - Anpassung der VS Code-Einstellungen
# - Einrichtung von Git-Konfiguration
# - Installation zusätzlicher Extensions
# - Anpassung der System-Einstellungen
# - Sicherheitskonfiguration
#
# Voraussetzungen:
# - code-server ist bereits installiert
# - Root-Zugriff

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
CODE_SERVER_USER="coder"
CODE_SERVER_CONFIG_DIR="/etc/code-server"
CODE_SERVER_DATA_DIR="/var/lib/code-server"
CODE_SERVER_PORT="8080"
GIT_USER_NAME="DevSystem"
GIT_USER_EMAIL="devsystem@example.com"
ENABLE_DOCKER=true
INSTALL_EXTENSIONS=true
CONFIGURE_TERMINAL=true

# Kommandozeilenargumente parsen
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --user=*) CODE_SERVER_USER="${1#*=}"; shift ;;
        --config-dir=*) CODE_SERVER_CONFIG_DIR="${1#*=}"; shift ;;
        --data-dir=*) CODE_SERVER_DATA_DIR="${1#*=}"; shift ;;
        --port=*) CODE_SERVER_PORT="${1#*=}"; shift ;;
        --git-user=*) GIT_USER_NAME="${1#*=}"; shift ;;
        --git-email=*) GIT_USER_EMAIL="${1#*=}"; shift ;;
        --no-docker) ENABLE_DOCKER=false; shift ;;
        --no-extensions) INSTALL_EXTENSIONS=false; shift ;;
        --no-terminal-config) CONFIGURE_TERMINAL=false; shift ;;
        --help) 
            echo "Verwendung: $0 [Optionen]"
            echo "Optionen:"
            echo "  --user=USER             Benutzername für code-server (Standard: $CODE_SERVER_USER)"
            echo "  --config-dir=DIR        Konfigurationsverzeichnis (Standard: $CODE_SERVER_CONFIG_DIR)"
            echo "  --data-dir=DIR          Datenverzeichnis (Standard: $CODE_SERVER_DATA_DIR)"
            echo "  --port=PORT             Port für code-server (Standard: $CODE_SERVER_PORT)"
            echo "  --git-user=NAME         Git-Benutzername (Standard: $GIT_USER_NAME)"
            echo "  --git-email=EMAIL       Git-E-Mail-Adresse (Standard: $GIT_USER_EMAIL)"
            echo "  --no-docker             Docker-Integration deaktivieren"
            echo "  --no-extensions         Keine zusätzlichen Extensions installieren"
            echo "  --no-terminal-config    Terminal nicht konfigurieren"
            exit 0
            ;;
        *) log_error "Unbekannter Parameter: $1"; exit 1 ;;
    esac
done

# Willkommensnachricht
log_step "Starte fortgeschrittene code-server Konfiguration..."

# Prüfen, ob code-server installiert ist
if ! command -v code-server &> /dev/null; then
    log_error "code-server ist nicht installiert. Bitte zuerst code-server installieren."
    exit 1
fi

# Prüfen, ob der Benutzer existiert
if ! id -u "$CODE_SERVER_USER" &>/dev/null; then
    log_error "Der Benutzer '$CODE_SERVER_USER' existiert nicht. Bitte zuerst den Benutzer erstellen."
    exit 1
fi

# Prüfen, ob code-server läuft
if ! systemctl is-active --quiet code-server.service; then
    log_warning "code-server ist nicht aktiv. Starte den Service..."
    systemctl start code-server.service
    
    # Kurz warten und erneut prüfen
    sleep 3
    if ! systemctl is-active --quiet code-server.service; then
        log_error "code-server konnte nicht gestartet werden. Bitte überprüfen Sie die Logs mit 'journalctl -u code-server'."
        exit 1
    fi
fi

# Benutzereinstellungen für VS Code konfigurieren
log_step "Konfiguriere VS Code Benutzereinstellungen..."

USER_HOME=$(eval echo ~${CODE_SERVER_USER})
SETTINGS_DIR="${USER_HOME}/.local/share/code-server/User"
mkdir -p "$SETTINGS_DIR"

# settings.json erstellen/aktualisieren
cat > "$SETTINGS_DIR/settings.json" << EOF
{
    "files.autoSave": "afterDelay",
    "files.autoSaveDelay": 1000,
    "editor.fontSize": 14,
    "editor.fontFamily": "'JetBrains Mono', Menlo, Monaco, 'Courier New', monospace",
    "editor.fontLigatures": true,
    "editor.bracketPairColorization.enabled": true,
    "editor.guides.bracketPairs": true,
    "editor.formatOnSave": true,
    "editor.minimap.enabled": true,
    "editor.renderWhitespace": "boundary",
    "editor.rulers": [80, 120],
    "editor.tabSize": 4,
    "editor.codeActionsOnSave": {
        "source.organizeImports": true
    },
    "workbench.colorTheme": "Default Dark+",
    "workbench.startupEditor": "none",
    "terminal.integrated.fontSize": 14,
    "terminal.integrated.profiles.linux": {
        "bash": {
            "path": "/bin/bash",
            "icon": "terminal-bash"
        }
    },
    "terminal.integrated.defaultProfile.linux": "bash",
    "explorer.confirmDelete": false,
    "telemetry.telemetryLevel": "off",
    "security.workspace.trust.enabled": false,
    "git.autofetch": true,
    "git.confirmSync": false
}
EOF

# keybindings.json erstellen
cat > "$SETTINGS_DIR/keybindings.json" << EOF
[
    {
        "key": "ctrl+shift+b",
        "command": "workbench.action.tasks.build"
    },
    {
        "key": "ctrl+shift+t",
        "command": "workbench.action.terminal.toggleTerminal"
    }
]
EOF

# Berechtigungen anpassen
chown -R "$CODE_SERVER_USER":"$CODE_SERVER_USER" "$SETTINGS_DIR"
log_info "VS Code Benutzereinstellungen wurden konfiguriert."

# Git-Konfiguration für den Benutzer
log_step "Konfiguriere Git für den Benutzer $CODE_SERVER_USER..."

sudo -u "$CODE_SERVER_USER" bash -c "git config --global user.name \"${GIT_USER_NAME}\""
sudo -u "$CODE_SERVER_USER" bash -c "git config --global user.email \"${GIT_USER_EMAIL}\""
sudo -u "$CODE_SERVER_USER" bash -c "git config --global init.defaultBranch main"
sudo -u "$CODE_SERVER_USER" bash -c "git config --global core.editor nano"
sudo -u "$CODE_SERVER_USER" bash -c "git config --global push.default simple"
sudo -u "$CODE_SERVER_USER" bash -c "git config --global pull.rebase false"

log_info "Git-Konfiguration wurde eingerichtet."

# Installation von erweiterten VS Code Extensions
if [ "$INSTALL_EXTENSIONS" = true ]; then
    log_step "Installiere erweiterte VS Code Extensions..."
    
    EXTENDED_EXTENSIONS=(
        "streetsidesoftware.code-spell-checker"
        "eamodio.gitlens"
        "esbenp.prettier-vscode"
        "ms-vscode.makefile-tools"
        "coenraads.bracket-pair-colorizer-2"
        "yzhang.markdown-all-in-one"
        "hashicorp.terraform"
        "christian-kohler.path-intellisense"
        "pkief.material-icon-theme"
        "ms-kubernetes-tools.vscode-kubernetes-tools"
    )
    
    for ext in "${EXTENDED_EXTENSIONS[@]}"; do
        log_info "Installiere Extension $ext..."
        sudo -u "$CODE_SERVER_USER" code-server --install-extension "$ext" || log_warning "Installation von $ext fehlgeschlagen."
    done
    
    log_info "Erweiterte VS Code Extensions wurden installiert."
fi

# Docker-Integration (falls aktiviert)
if [ "$ENABLE_DOCKER" = true ]; then
    log_step "Konfiguriere Docker-Integration..."
    
    # Prüfen, ob Docker installiert ist
    if ! command -v docker &> /dev/null; then
        log_warning "Docker ist nicht installiert. Die Docker-Integration wird übersprungen."
    else
        # Füge Benutzer zur Docker-Gruppe hinzu
        if getent group docker > /dev/null; then
            usermod -aG docker "$CODE_SERVER_USER"
            log_info "Benutzer $CODE_SERVER_USER wurde zur Docker-Gruppe hinzugefügt."
        else
            log_warning "Docker-Gruppe existiert nicht. Die Docker-Gruppe-Integration wird übersprungen."
        fi
        
        # Docker-Verzeichnis im Home-Verzeichnis erstellen
        mkdir -p "${USER_HOME}/docker-projects"
        chown "$CODE_SERVER_USER":"$CODE_SERVER_USER" "${USER_HOME}/docker-projects"
        
        log_info "Docker-Integration wurde konfiguriert."
    fi
fi

# Terminal-Konfiguration
if [ "$CONFIGURE_TERMINAL" = true ]; then
    log_step "Konfiguriere Terminal für den Benutzer $CODE_SERVER_USER..."
    
    # .bashrc anpassen
    BASHRC_FILE="${USER_HOME}/.bashrc"
    
    # Backup erstellen, falls die Datei existiert
    if [ -f "$BASHRC_FILE" ]; then
        cp "$BASHRC_FILE" "${BASHRC_FILE}.bak"
    fi
    
    # Ergänze die .bashrc
    cat >> "$BASHRC_FILE" << EOF

# DevSystem Konfiguration
export EDITOR=nano
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# Aliase
alias ll='ls -la'
alias l='ls -l'
alias c='clear'
alias h='history'
alias update='sudo apt update && sudo apt upgrade -y'
alias ..='cd ..'
alias ...='cd ../..'

# Git-Aliase
alias gs='git status'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias ga='git add'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'

# Bessere Eingabeaufforderung
export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\\$ '

# Pfad erweitern
export PATH=\$PATH:\$HOME/.local/bin

# Verlauf-Größe erhöhen
export HISTSIZE=10000
export HISTFILESIZE=10000
EOF
    
    # .inputrc für bessere Tastatureingabe erstellen
    cat > "${USER_HOME}/.inputrc" << EOF
# Eingabeverhalten verbessern
set completion-ignore-case On
set show-all-if-ambiguous On
set show-all-if-unmodified On
set mark-symlinked-directories On
set colored-stats On
set visible-stats On
set echo-control-characters Off
set input-meta On
set output-meta On
set convert-meta Off
EOF
    
    # Berechtigungen anpassen
    chown "$CODE_SERVER_USER":"$CODE_SERVER_USER" "$BASHRC_FILE"
    chown "$CODE_SERVER_USER":"$CODE_SERVER_USER" "${USER_HOME}/.inputrc"
    
    log_info "Terminal-Konfiguration wurde eingerichtet."
fi

# Erstelle ein Beispielprojekt
log_step "Erstelle Beispielprojekt..."

PROJECT_DIR="${USER_HOME}/projects/devsystem-demo"
mkdir -p "$PROJECT_DIR"

cat > "${PROJECT_DIR}/README.md" << EOF
# DevSystem Demo Projekt

Dieses Projekt dient als Beispiel für die DevSystem-Infrastruktur.

## Funktionen

- Beispiel für die code-server Integration
- Tailscale-gesicherte Verbindung
- Automatische Bereitstellung über Caddy

## Entwicklung

Für die Entwicklung nutze die integrierten Terminal-Funktionen von VS Code.
EOF

# Berechtigungen anpassen
chown -R "$CODE_SERVER_USER":"$CODE_SERVER_USER" "${USER_HOME}/projects"

log_info "Beispielprojekt wurde erstellt."

# Systemeinstellungen anpassen
log_step "Passe Systemeinstellungen an..."

# Aktiviere Code-Server Service
systemctl restart code-server.service

# Prüfe, ob der Dienst läuft
if systemctl is-active --quiet code-server.service; then
    log_info "code-server Dienst wurde neu gestartet und läuft."
else
    log_error "code-server Dienst konnte nicht gestartet werden. Bitte überprüfen Sie die Logs mit 'journalctl -u code-server'."
    exit 1
fi

# Zusammenfassung
log_step "Konfiguration von code-server abgeschlossen"
log_info "Benutzer: $CODE_SERVER_USER"
log_info "Port: $CODE_SERVER_PORT"
log_info "Konfigurationsverzeichnis: $CODE_SERVER_CONFIG_DIR"
log_info "Datenverzeichnis: $CODE_SERVER_DATA_DIR"

log_info "Zugriff über: http://localhost:$CODE_SERVER_PORT"
log_info "Zugriff über Caddy: https://code.devsystem.internal:9443"

log_info "Git-Benutzer: $GIT_USER_NAME"
log_info "Git-E-Mail: $GIT_USER_EMAIL"

log_info "code-server systemd service: code-server.service"
log_info "Logs anzeigen mit: journalctl -u code-server"

if [ "$ENABLE_DOCKER" = true ]; then
    log_info "Docker-Integration: Aktiviert"
else
    log_info "Docker-Integration: Deaktiviert"
fi

log_info "Konfiguration erfolgreich abgeschlossen!"
exit 0