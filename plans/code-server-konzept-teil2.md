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
  "search.useGlobalIgnoreFiles": true,
  "search.useParentIgnoreFiles": true,
  "files.watcherExclude": {
    "**/.git/objects/**": true,
    "**/.git/subtree-cache/**": true,
    "**/node_modules/**": true,
    "**/.hg/store/**": true
  }
}
```

2. **Optimierung der Dateisystemüberwachung**:

```bash
# Erhöhen der Anzahl der Inotify-Watches
echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### 7.3 Speicheroptimierung

Für eine optimale Speichernutzung empfehlen wir folgende Maßnahmen:

1. **Regelmäßige Bereinigung des Caches**:

```bash
#!/bin/bash
# /usr/local/bin/code-server-clean.sh

# Bereinigen des VS Code-Caches
rm -rf /home/$USER/.config/code-server/data/CachedData/*
rm -rf /home/$USER/.config/code-server/data/Cache/*
rm -rf /home/$USER/.config/code-server/data/logs/*
```

2. **Automatisierung der Bereinigung**:

```bash
# Wöchentliche Bereinigung am Sonntag um 3:00 Uhr
echo "0 3 * * 0 /usr/local/bin/code-server-clean.sh >> /var/log/code-server-clean.log 2>&1" | sudo tee -a /etc/crontab
```

## 8. Zusammenfassung und nächste Schritte

Dieses Konzept beschreibt die Installation, Konfiguration und Integration von code-server als Web-IDE für das DevSystem-Projekt. Die wichtigsten Aspekte sind:

1. **Installation und Einrichtung**: Schritte zur Installation und Konfiguration von code-server auf dem Ubuntu VPS
2. **Grundkonfiguration**: Authentifizierung, Workspace-Setup und Benutzereinstellungen
3. **Integration mit Caddy und Tailscale**: URL-Routing, Sicherung durch Tailscale-Netzwerk und Zertifikatshandling
4. **Erweiterungen und Plugins**: Empfohlene Erweiterungen, Roo Code Extension und automatische Installation
5. **Mobile Nutzung**: Optimierung für Smartphone/Tablet, PWA-Konfiguration und Touch-Bedienung
6. **Backup und Wiederherstellung**: Sicherung von Einstellungen und Workspaces, automatisierte Backups und Disaster Recovery
7. **Performance-Optimierung**: Ressourcennutzung, Caching-Strategien und Speicheroptimierung

### Nächste Schritte

1. **Implementierung**: Umsetzung der in diesem Konzept beschriebenen Konfiguration auf dem Ubuntu VPS
2. **Testing**: Durchführung von Tests zur Überprüfung der Funktionalität und Sicherheit
3. **Integration mit Ollama**: Einrichtung und Konfiguration von Ollama für lokale KI-Modelle
4. **Dokumentation**: Erstellung einer Benutzeranleitung für die Verwendung von code-server im DevSystem-Projekt
5. **Schulung**: Schulung der Teammitglieder in der Verwendung von code-server und der Fehlerbehebung

## 9. Anhang

### 9.1 Nützliche code-server-Befehle

```bash
# code-server-Version anzeigen
code-server --version

# code-server mit bestimmter Konfigurationsdatei starten
code-server --config /path/to/config.yaml

# code-server mit bestimmtem Datenverzeichnis starten
code-server --user-data-dir /path/to/data

# code-server mit bestimmtem Port starten
code-server --bind-addr 127.0.0.1:8888

# Erweiterung installieren
code-server --install-extension ms-python.python

# Liste der installierten Erweiterungen anzeigen
code-server --list-extensions

# Erweiterung deinstallieren
code-server --uninstall-extension ms-python.python
```

### 9.2 Referenzen

- [Offizielle code-server-Dokumentation](https://coder.com/docs/code-server/latest)
- [VS Code-Dokumentation](https://code.visualstudio.com/docs)
- [Caddy-Dokumentation](https://caddyserver.com/docs/)
- [Tailscale-Dokumentation](https://tailscale.com/kb/)
- [Roo Code Extension-Dokumentation](https://github.com/example/roo-code)
- [Ollama-Dokumentation](https://ollama.ai/docs)