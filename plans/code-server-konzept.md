# Code-Server-Konfigurationskonzept für DevSystem

Dieses Dokument beschreibt die Installation, Konfiguration und Integration von code-server als Web-IDE für das DevSystem-Projekt. Code-server wird als primäre Entwicklungsumgebung eingesetzt, um eine vollständig remote nutzbare, KI-gestützte Entwicklungsumgebung bereitzustellen.

## 1. Installation und Einrichtung von code-server auf dem Ubuntu VPS

### 1.1 Installationsschritte

Code-server kann auf verschiedene Arten auf einem Ubuntu-System installiert werden. Die empfohlene Methode ist die Installation über das offizielle Installationsskript:

```bash
# Aktualisieren der Paketlisten
sudo apt update
sudo apt upgrade -y

# Installation der erforderlichen Abhängigkeiten
sudo apt install -y curl wget unzip git build-essential

# Herunterladen und Ausführen des Installationsskripts
curl -fsSL https://code-server.dev/install.sh | sh

# Starten des code-server-Dienstes
sudo systemctl enable --now code-server@$USER
```

Alternativ kann code-server auch über npm installiert werden:

```bash
# Installation von Node.js und npm
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Installation von code-server über npm
npm install -g code-server

# Starten von code-server
code-server
```

### 1.2 Verzeichnisstruktur

Nach der Installation von code-server wird folgende Verzeichnisstruktur empfohlen:

```
/home/username/.config/code-server/
├── config.yaml                 # Hauptkonfigurationsdatei
├── data/                       # Datenverzeichnis
│   ├── User/                   # Benutzereinstellungen
│   │   ├── settings.json       # VS Code-Einstellungen
│   │   └── keybindings.json    # Tastaturkürzel
│   ├── extensions/             # Installierte Erweiterungen
│   └── Machine/                # Maschinenspezifische Einstellungen
├── logs/                       # Log-Dateien
└── workspaces/                 # Workspace-Verzeichnis
    ├── project1/               # Projektverzeichnis 1
    ├── project2/               # Projektverzeichnis 2
    └── ...

/var/lib/code-server/           # Systemweite Daten (bei Installation als Paket)
/var/log/code-server/           # Log-Verzeichnis (bei Installation als Paket)
```

### 1.3 Konfiguration für automatischen Start

Code-server wird standardmäßig als systemd-Service eingerichtet, wenn es über das Installationsskript installiert wird. Die Service-Datei befindet sich unter `/etc/systemd/system/code-server@.service`.

Um sicherzustellen, dass code-server beim Systemstart automatisch gestartet wird:

```bash
# Aktivieren des code-server-Dienstes für den aktuellen Benutzer
sudo systemctl enable code-server@$USER

# Starten des code-server-Dienstes
sudo systemctl start code-server@$USER

# Überprüfen des Dienststatus
sudo systemctl status code-server@$USER
```

Für eine benutzerdefinierte Konfiguration kann die systemd-Service-Datei angepasst werden:

```bash
# Bearbeiten der Service-Datei
sudo nano /etc/systemd/system/code-server@.service
```

Beispiel für eine angepasste Service-Datei:

```ini
[Unit]
Description=code-server for DevSystem
After=network.target

[Service]
Type=exec
User=%i
ExecStart=/usr/bin/code-server --bind-addr 127.0.0.1:8080 --user-data-dir /home/%i/.config/code-server/data --config /home/%i/.config/code-server/config.yaml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Nach Änderungen an der Service-Datei:

```bash
# Systemd neu laden
sudo systemctl daemon-reload

# Dienst neu starten
sudo systemctl restart code-server@$USER
```

## 2. Grundkonfiguration

### 2.1 Authentifizierung und Sicherheit

Die Hauptkonfigurationsdatei für code-server befindet sich unter `~/.config/code-server/config.yaml`. Hier können grundlegende Einstellungen wie Authentifizierung und Netzwerkbindung konfiguriert werden:

```yaml
# ~/.config/code-server/config.yaml
bind-addr: 127.0.0.1:8080
auth: password
password: SICHERES_PASSWORT_HIER
cert: false
```

Da der Zugriff auf code-server über Tailscale und Caddy abgesichert wird, empfehlen wir folgende Konfiguration:

```yaml
# ~/.config/code-server/config.yaml
bind-addr: 127.0.0.1:8080
auth: none  # Authentifizierung wird durch Tailscale übernommen
cert: false # SSL-Terminierung erfolgt durch Caddy
```

Alternativ kann die Authentifizierung auch über Umgebungsvariablen konfiguriert werden:

```bash
# Hinzufügen zu /etc/environment oder ~/.bashrc
export PASSWORD="SICHERES_PASSWORT_HIER"
```

### 2.2 Workspace-Setup

Für das DevSystem-Projekt empfehlen wir die Einrichtung eines dedizierten Workspace-Verzeichnisses:

```bash
# Erstellen des Workspace-Verzeichnisses
mkdir -p /home/$USER/workspaces/devsystem

# Git-Repository klonen
git clone https://github.com/HaraldKiessling/DevSystem.git /home/$USER/workspaces/devsystem

# Berechtigungen setzen
chmod 750 /home/$USER/workspaces/devsystem
```

Die Workspace-Konfiguration kann in einer `.code-workspace`-Datei definiert werden:

```json
// /home/$USER/workspaces/devsystem.code-workspace
{
  "folders": [
    {
      "path": "/home/$USER/workspaces/devsystem"
    }
  ],
  "settings": {
    "editor.formatOnSave": true,
    "editor.renderWhitespace": "boundary",
    "editor.rulers": [80, 120],
    "files.autoSave": "afterDelay",
    "files.autoSaveDelay": 1000,
    "terminal.integrated.defaultProfile.linux": "bash",
    "workbench.colorTheme": "Default Dark Modern",
    "workbench.startupEditor": "none"
  },
  "extensions": {
    "recommendations": [
      "ms-python.python",
      "dbaeumer.vscode-eslint",
      "esbenp.prettier-vscode",
      "github.copilot",
      "github.copilot-chat"
    ]
  }
}
```

### 2.3 Benutzereinstellungen

Die Benutzereinstellungen für code-server werden in der Datei `~/.config/code-server/data/User/settings.json` gespeichert. Hier ist eine empfohlene Grundkonfiguration für das DevSystem-Projekt:

```json
{
  "workbench.colorTheme": "Default Dark Modern",
  "workbench.iconTheme": "material-icon-theme",
  "editor.fontSize": 14,
  "editor.fontFamily": "'Fira Code', 'Droid Sans Mono', 'monospace'",
  "editor.fontLigatures": true,
  "editor.formatOnSave": true,
  "editor.minimap.enabled": true,
  "editor.tabSize": 2,
  "editor.wordWrap": "on",
  "files.autoSave": "afterDelay",
  "files.autoSaveDelay": 1000,
  "terminal.integrated.fontSize": 14,
  "terminal.integrated.defaultProfile.linux": "bash",
  "window.zoomLevel": 0,
  "telemetry.telemetryLevel": "off",
  "security.workspace.trust.enabled": false,
  "workbench.startupEditor": "none",
  "workbench.editor.enablePreview": false,
  "workbench.editor.enablePreviewFromQuickOpen": false,
  "workbench.editor.showTabs": true,
  "workbench.editor.tabSizing": "shrink",
  "workbench.editor.tabCloseButton": "right",
  "workbench.editor.openPositioning": "right",
  "workbench.editor.limit.enabled": true,
  "workbench.editor.limit.value": 10,
  "workbench.editor.limit.perEditorGroup": true
}
```

## 3. Integration mit Caddy und Tailscale

### 3.1 URL-Routing über Caddy

Die Integration von code-server mit Caddy erfolgt über die Konfiguration eines Reverse Proxys. Hier ist ein Beispiel für die Caddy-Konfiguration:

```
# /etc/caddy/sites/code-server.caddy
code.devsystem.internal {
    # Nur Zugriff über Tailscale erlauben
    @tailscale {
        remote_ip 100.64.0.0/10
    }
    
    # Reverse Proxy zu code-server
    reverse_proxy @tailscale localhost:8080 {
        # Header für WebSocket-Unterstützung
        header_up Connection {http.request.header.Connection}
        header_up Upgrade {http.request.header.Upgrade}
        
        # Timeouts erhöhen für lange Entwicklungssitzungen
        transport http {
            keepalive 30m
            keepalive_idle_conns 10
        }
    }
    
    # Zugriff verweigern, wenn nicht über Tailscale
    respond !@tailscale 403 {
        body "Zugriff nur über Tailscale erlaubt"
    }
    
    # Sicherheits-Header hinzufügen
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-XSS-Protection "1; mode=block"
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "strict-origin-when-cross-origin"
        Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' wss:; frame-ancestors 'self';"
        -Server
    }
    
    # Logging
    log {
        output file /var/log/caddy/code-server.log {
            roll_size 10MB
            roll_keep 5
            roll_keep_for 720h
        }
    }
}
```

### 3.2 Sicherung durch Tailscale-Netzwerk

Die Sicherung des Zugriffs auf code-server erfolgt über das Tailscale-Netzwerk. Nur Geräte, die Teil des Tailscale-Netzwerks sind, können auf code-server zugreifen. Die Konfiguration von Tailscale wurde bereits im Tailscale-Konzept beschrieben.

Für die Integration mit code-server sind folgende Aspekte wichtig:

1. **Zugriffskontrolle über ACLs**: Nur autorisierte Benutzer dürfen auf den code-server-Dienst zugreifen.

```json
{
  "acls": [
    {
      "action": "accept",
      "users": ["user@example.com"],
      "ports": ["code.devsystem.internal:443"]
    }
  ]
}
```

2. **DNS-Konfiguration**: Der Hostname `code.devsystem.internal` muss im Tailscale-DNS konfiguriert werden, um auf die IP-Adresse des VPS im Tailnet zu verweisen.

```bash
# Konfigurieren von benutzerdefinierten DNS-Einträgen
sudo tailscale set --hostname=devsystem-vps
```

### 3.3 Zertifikatshandling

Für die HTTPS-Verbindung zu code-server gibt es zwei Optionen:

#### Option 1: Tailscale-Zertifikate

Tailscale kann automatisch TLS-Zertifikate für Domains im Tailnet ausstellen:

```bash
# Aktivieren der Tailscale HTTPS-Zertifikate
sudo tailscale cert code.devsystem.internal
```

In der Caddy-Konfiguration:

```
code.devsystem.internal {
    tls /etc/tailscale/certs/code.devsystem.internal.crt /etc/tailscale/certs/code.devsystem.internal.key
    reverse_proxy localhost:8080
}
```

#### Option 2: Lokale selbstsignierte Zertifikate

Alternativ kann Caddy selbstsignierte Zertifikate für die interne Verwendung generieren:

```
code.devsystem.internal {
    # Caddy generiert automatisch selbstsignierte Zertifikate
    tls internal
    reverse_proxy localhost:8080
}
```

## 4. Erweiterungen und Plugins

### 4.1 Empfohlene Erweiterungen für DevOps-Arbeit

Für das DevSystem-Projekt empfehlen wir die Installation folgender Erweiterungen:

1. **Allgemeine Entwicklungswerkzeuge**:
   - GitLens — Git supercharged
   - Docker
   - Remote - SSH
   - Remote - Containers
   - EditorConfig for VS Code
   - Path Intellisense
   - Better Comments

2. **Programmiersprachen und Frameworks**:
   - Python
   - Jupyter
   - ESLint
   - Prettier - Code formatter
   - JavaScript and TypeScript Nightly
   - Go
   - Rust
   - C/C++

3. **DevOps-Tools**:
   - Kubernetes
   - HashiCorp Terraform
   - YAML
   - Ansible
   - Azure Tools
   - AWS Toolkit

4. **Kollaboration und Produktivität**:
   - Live Share
   - Todo Tree
   - Bookmarks
   - Project Manager
   - Code Spell Checker

### 4.2 Roo Code Extension für KI-Unterstützung

Die Roo Code Extension ist ein zentraler Bestandteil des DevSystem-Projekts und ermöglicht die KI-gestützte Entwicklung. Die Installation und Konfiguration erfolgt wie folgt:

1. **Installation der Erweiterung**:

```bash
# Herunterladen der Roo Code Extension
mkdir -p /home/$USER/.config/code-server/data/extensions
wget -O /tmp/roo-code.vsix https://github.com/example/roo-code/releases/latest/download/roo-code.vsix

# Installation der Erweiterung
code-server --install-extension /tmp/roo-code.vsix
```

2. **Konfiguration der Erweiterung**:

```json
// ~/.config/code-server/data/User/settings.json
{
  "roo-code.provider": "openrouter",
  "roo-code.openrouter.apiKey": "OPENROUTER_API_KEY",
  "roo-code.defaultModel": "anthropic/claude-3-opus",
  "roo-code.localModels": [
    {
      "name": "Llama 3",
      "provider": "ollama",
      "model": "llama3",
      "endpoint": "http://localhost:11434/api"
    },
    {
      "name": "DeepSeek",
      "provider": "ollama",
      "model": "deepseek-coder",
      "endpoint": "http://localhost:11434/api"
    }
  ],
  "roo-code.autoSuggest": true,
  "roo-code.contextLines": 100,
  "roo-code.maxTokens": 4000
}
```

### 4.3 Automatische Installation von Erweiterungen

Um die automatische Installation von Erweiterungen für alle Benutzer zu ermöglichen, kann ein Skript erstellt werden:

```bash
#!/bin/bash
# /usr/local/bin/install-code-extensions.sh

# Liste der zu installierenden Erweiterungen
EXTENSIONS=(
  "eamodio.gitlens"
  "ms-azuretools.vscode-docker"
  "ms-vscode-remote.remote-ssh"
  "ms-vscode-remote.remote-containers"
  "editorconfig.editorconfig"
  "christian-kohler.path-intellisense"
  "aaron-bond.better-comments"
  "ms-python.python"
  "ms-toolsai.jupyter"
  "dbaeumer.vscode-eslint"
  "esbenp.prettier-vscode"
  "ms-vscode.vscode-typescript-next"
  "golang.go"
  "rust-lang.rust-analyzer"
  "ms-vscode.cpptools"
  "ms-kubernetes-tools.vscode-kubernetes-tools"
  "hashicorp.terraform"
  "redhat.vscode-yaml"
  "redhat.ansible"
  "ms-vscode.azure-account"
  "amazonwebservices.aws-toolkit-vscode"
  "ms-vsliveshare.vsliveshare"
  "gruntfuggly.todo-tree"
  "alefragnani.bookmarks"
  "alefragnani.project-manager"
  "streetsidesoftware.code-spell-checker"
)

# Installation der Erweiterungen
for ext in "${EXTENSIONS[@]}"; do
  code-server --install-extension "$ext"
done

# Installation der Roo Code Extension
wget -O /tmp/roo-code.vsix https://github.com/example/roo-code/releases/latest/download/roo-code.vsix
code-server --install-extension /tmp/roo-code.vsix
```

Dieses Skript kann beim ersten Start von code-server oder als Teil des Installationsprozesses ausgeführt werden.

## 5. Mobile Nutzung

### 5.1 Optimierung für Smartphone/Tablet

Für die optimale Nutzung von code-server auf mobilen Geräten empfehlen wir folgende Anpassungen:

1. **Anpassung der Benutzeroberfläche**:

```json
// ~/.config/code-server/data/User/settings.json
{
  "window.zoomLevel": 1,
  "editor.fontSize": 16,
  "terminal.integrated.fontSize": 16,
  "editor.minimap.enabled": false,
  "workbench.editor.showTabs": true,
  "workbench.editor.tabSizing": "fit",
  "workbench.sideBar.location": "right",
  "breadcrumbs.enabled": true,
  "editor.lineNumbers": "on",
  "editor.folding": true,
  "editor.showFoldingControls": "always"
}
```

2. **Touch-freundliche Einstellungen**:

```json
{
  "editor.mouseWheelZoom": true,
  "editor.multiCursorModifier": "ctrlCmd",
  "editor.scrollBeyondLastLine": false,
  "editor.smoothScrolling": true,
  "workbench.list.smoothScrolling": true,
  "terminal.integrated.smoothScrolling": true
}
```

### 5.2 PWA-Konfiguration

Code-server kann als Progressive Web App (PWA) konfiguriert werden, um eine App-ähnliche Erfahrung auf mobilen Geräten zu bieten. Dazu muss Caddy so konfiguriert werden, dass es die erforderlichen PWA-Dateien bereitstellt:

1. **Erstellen der Web App Manifest-Datei**:

```bash
# Erstellen des Verzeichnisses für PWA-Dateien
mkdir -p /var/www/code-server-pwa

# Erstellen der manifest.json
cat > /var/www/code-server-pwa/manifest.json << EOF
{
  "name": "DevSystem IDE",
  "short_name": "DevSystem",
  "description": "Web-IDE für das DevSystem-Projekt",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#1e1e1e",
  "theme_color": "#007acc",
  "icons": [
    {
      "src": "/icons/icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "/icons/icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
EOF
```

2. **Erstellen des Service Workers**:

```bash
cat > /var/www/code-server-pwa/service-worker.js << EOF
self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  return self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  event.respondWith(fetch(event.request));
});
EOF
```

3. **Anpassen der Caddy-Konfiguration**:

```
code.devsystem.internal {
    # ... bestehende Konfiguration ...
    
    # PWA-Dateien bereitstellen
    handle /manifest.json {
        root * /var/www/code-server-pwa
        file_server
    }
    
    handle /service-worker.js {
        root * /var/www/code-server-pwa
        file_server
    }
    
    handle /icons/* {
        root * /var/www/code-server-pwa
        file_server
    }
    
    # Header für PWA
    header {
        # ... bestehende Header ...
        Link "</manifest.json>; rel=manifest"
    }
}
```

### 5.3 Touch-Bedienung

Für eine verbesserte Touch-Bedienung können zusätzliche Anpassungen vorgenommen werden:

1. **Anpassung der Tastaturkürzel**:

```json
// ~/.config/code-server/data/User/keybindings.json
[
  {
    "key": "ctrl+shift+p",
    "command": "workbench.action.showCommands"
  },
  {
    "key": "ctrl+p",
    "command": "workbench.action.quickOpen"
  },
  {
    "key": "ctrl+shift+e",
    "command": "workbench.view.explorer"
  },
  {
    "key": "ctrl+shift+f",
    "command": "workbench.view.search"
  },
  {
    "key": "ctrl+shift+g",
    "command": "workbench.view.scm"
  },
  {
    "key": "ctrl+shift+d",
    "command": "workbench.view.debug"
  },
  {
    "key": "ctrl+shift+x",
    "command": "workbench.view.extensions"
  }
]
```

2. **Anpassung der Benutzeroberfläche für Touch-Geräte**:

```json
// ~/.config/code-server/data/User/settings.json
{
  "editor.lineHeight": 1.8,
  "editor.cursorBlinking": "smooth",
  "editor.cursorSmoothCaretAnimation": "on",
  "editor.cursorWidth": 2,
  "editor.renderWhitespace": "none",
  "editor.renderControlCharacters": false,
  "editor.renderIndentGuides": false,
  "editor.guides.indentation": false,
  "editor.overviewRulerBorder": false,
  "editor.hideCursorInOverviewRuler": true,
  "editor.scrollbar.vertical": "visible",
  "editor.scrollbar.horizontal": "visible",
  "editor.scrollbar.verticalScrollbarSize": 14,
  "editor.scrollbar.horizontalScrollbarSize": 14
}
```

## 6. Backup und Wiederherstellung

### 6.1 Sicherung von Einstellungen und Workspaces

Für die Sicherung der code-server-Konfiguration und Workspaces empfehlen wir folgende Strategie:

1. **Sicherung der Konfigurationsdateien**:

```bash
#!/bin/bash
# /usr/local/bin/code-server-backup.sh

# Backup-Verzeichnis
BACKUP_DIR="/var/backups/code-server"
TIMESTAMP=$(date +%Y%m%d%H%M%S)

# Backup-Verzeichnis erstellen, falls es nicht existiert
mkdir -p $BACKUP_DIR

# Konfigurationsdateien sichern
tar -czf $BACKUP_DIR/code-server-config-$TIMESTAMP.tar.gz \
  /home/$USER/.config/code-server/config.yaml \
  /home/$USER/.config/code-server/data/User/settings.json \
  /home/$USER/.config/code-server/data/User/keybindings.json

# Erweiterungen sichern
tar -czf $BACKUP_DIR/code-server-extensions-$TIMESTAMP.tar.gz \
  /home/$USER/.config/code-server/data/extensions

# Workspace-Dateien sichern (ohne .git-Verzeichnisse)
tar -czf $BACKUP_DIR/code-server-workspaces-$TIMESTAMP.tar.gz \
  --exclude='*.git' \
  /home/$USER/workspaces

# Alte Backups bereinigen (älter als 30 Tage)
find $BACKUP_DIR -name "code-server-*.tar.gz" -type f -mtime +30 -delete
```

2. **Automatisierung der Backups**:

```bash
# Tägliches Backup um 2:00 Uhr
echo "0 2 * * * /usr/local/bin/code-server-backup.sh >> /var/log/code-server-backup.log 2>&1" | sudo tee -a /etc/crontab
```

### 6.2 Automatisierte Backups

Für automatisierte Backups empfehlen wir die Verwendung von restic oder rclone, um die Backups auf externe Speicherorte zu übertragen:

```bash
#!/bin/bash
# /usr/local/bin/code-server-remote-backup.sh

# Backup-Verzeichnis
BACKUP_DIR="/var/backups/code-server"
TIMESTAMP=$(date +%Y%m%d%H%M%S)

# Lokales Backup erstellen
/usr/local/bin/code-server-backup.sh

# Backup auf externen Speicher übertragen (z.B. S3)
rclone copy $BACKUP_DIR remote:code-server-backups

# Oder mit restic
restic -r sftp:user@backup-server:/backups backup $BACKUP_DIR
```

### 6.3 Disaster Recovery

Im Falle eines Systemausfalls kann code-server wie folgt wiederhergestellt werden:

1. **Wiederherstellung der Konfiguration**:

```bash
#!/bin/bash
# /usr/local/bin/code-server-restore.sh

# Backup-Datei als Parameter übergeben
CONFIG_BACKUP=$1
EXTENSIONS_BACKUP=$2
WORKSPACES_BACKUP=$3

if [ -z "$CONFIG_BACKUP" ] || [ -z "$EXTENSIONS_BACKUP" ] || [ -z "$WORKSPACES_BACKUP" ]; then
  echo "Bitte geben Sie die Backup-Dateien an."
  echo "Verwendung: $0 config-backup.tar.gz extensions-backup.tar.gz workspaces-backup.tar.gz"
  exit 1
fi

# code-server-Dienst anhalten
sudo systemctl stop code-server@$USER

# Konfiguration wiederherstellen
tar -xzf $CONFIG_BACKUP -C /

# Erweiterungen wiederherstellen
tar -xzf $EXTENSIONS_BACKUP -C /

# Workspaces wiederherstellen
tar -xzf $WORKSPACES_BACKUP -C /

# Berechtigungen wiederherstellen
chown -R $USER:$USER /home/$USER/.config/code-server
chown -R $USER:$USER /home/$USER/workspaces

# code-server-Dienst wieder starten
sudo systemctl start code-server@$USER
```

2. **Vollständige Neuinstallation**:

```bash
#!/bin/bash
# /usr/local/bin/code-server-reinstall.sh

# code-server neu installieren
curl -fsSL https://code-server.dev/install.sh | sh

# Konfiguration wiederherstellen
/usr/local/bin/code-server-restore.sh /var/backups/code-server/code-server-config-latest.tar.gz /var/backups/code-server/code-server-extensions-latest.tar.gz /var/backups/code-server/code-server-workspaces-latest.tar.gz

# Dienst aktivieren und starten
sudo systemctl enable --now code-server@$USER
```

## 7. Performance-Optimierung

### 7.1 Ressourcennutzung

Für eine optimale Ressourcennutzung empfehlen wir folgende Maßnahmen:

1. **Begrenzung der CPU- und Speichernutzung**:

```bash
# Bearbeiten der systemd-Service-Datei
sudo nano /etc/systemd/system/code-server@.service
```

Hinzufügen der folgenden Zeilen im `[Service]`-Abschnitt:

```ini
[Service]
# ... bestehende Konfiguration ...
CPUQuota=200%
MemoryLimit=4G
```

2. **Optimierung der Node.js-Einstellungen**:

```bash
# Hinzufügen zu /etc/environment oder ~/.bashrc
export NODE_OPTIONS="--max-old-space-size=4096"
```

### 7.2 Caching-Strategien

Für eine verbesserte Performance durch Caching empfehlen wir folgende Maßnahmen:

1. **Aktivierung des VS Code-Caches**:

```json
// ~/.config/code-server/data/User/settings.json
{
  "files.useExperimentalFileWatcher": true,
  "search.followSymlinks": false,
  "search.useIgnoreFiles": true,
  "search.useG