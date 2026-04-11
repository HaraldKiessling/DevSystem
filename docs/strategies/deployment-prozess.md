# Deployment-Prozess für DevSystem

Dieses Dokument beschreibt den vollständigen Deployment-Prozess für das DevSystem-Projekt auf einem Ubuntu VPS. Es umfasst alle notwendigen Schritte von der Vorbereitung des Servers bis zur Validierung der Installation und enthält Informationen zu Wartung, Updates und Fehlerbehebung.

## Inhaltsverzeichnis

1. [Voraussetzungen](#1-voraussetzungen)
2. [Installationsreihenfolge](#2-installationsreihenfolge)
3. [Deployment-Schritte](#3-deployment-schritte)
4. [Validierung](#4-validierung)
5. [Wartung und Updates](#5-wartung-und-updates)
6. [Fehlerbehebung](#6-fehlerbehebung)
7. [Dokumentation](#7-dokumentation)

## 1. Voraussetzungen

### 1.1 Benötigte Hardware und Ressourcen

Für die Bereitstellung des DevSystem-Projekts wird ein Ubuntu VPS mit folgenden Mindestanforderungen benötigt:

- **Betriebssystem:** Ubuntu 22.04 LTS oder neuer
- **CPU:** Mindestens 4 vCPUs (empfohlen: 8 vCPUs)
- **RAM:** Mindestens 8 GB (empfohlen: 16 GB)
- **Speicher:** Mindestens 50 GB SSD (empfohlen: 100 GB SSD)
- **Netzwerk:** Stabile Internetverbindung mit mindestens 100 Mbit/s

Für die Ausführung lokaler KI-Modelle mit Ollama werden folgende zusätzliche Ressourcen empfohlen:

- **RAM:** Zusätzliche 8-16 GB (je nach Modellgröße)
- **Speicher:** Zusätzliche 20-50 GB für die Modelle
- **GPU:** Optional, aber empfohlen für bessere Performance (NVIDIA mit CUDA-Unterstützung)

### 1.2 Erforderliche Zugangsdaten und Berechtigungen

Folgende Zugangsdaten und Berechtigungen werden für den Deployment-Prozess benötigt:

1. **SSH-Zugang zum Ubuntu VPS:**
   - SSH-Schlüsselpaar (öffentlich/privat)
   - Benutzername mit sudo-Rechten

2. **Tailscale-Konto:**
   - Registrierter Account bei Tailscale (https://tailscale.com)
   - Administratorrechte im Tailscale-Konto zur Konfiguration von ACLs

3. **OpenRouter-API-Schlüssel:**
   - Registrierter Account bei OpenRouter (https://openrouter.ai)
   - API-Schlüssel für den Zugriff auf Cloud-KI-Modelle

4. **Domain (optional):**
   - Wenn eine öffentliche Domain verwendet werden soll, werden die entsprechenden DNS-Zugangsdaten benötigt

### 1.3 Vorbereitung des Ubuntu VPS

Vor Beginn des eigentlichen Deployments sollte der Ubuntu VPS wie folgt vorbereitet werden:

1. **Aktualisierung des Systems:**
   ```bash
   sudo apt update
   sudo apt upgrade -y
   ```

2. **Installation grundlegender Pakete:**
   ```bash
   sudo apt install -y curl wget git build-essential apt-transport-https ca-certificates gnupg lsb-release unzip
   ```

3. **Einrichtung eines nicht-root Benutzers mit sudo-Rechten (falls noch nicht vorhanden):**
   ```bash
   sudo adduser devsystem
   sudo usermod -aG sudo devsystem
   ```

4. **Konfiguration der Firewall (UFW):**
   ```bash
   sudo ufw allow ssh
   sudo ufw enable
   ```

5. **Einrichtung der Zeitsynchronisation:**
   ```bash
   sudo apt install -y ntp
   sudo systemctl enable ntp
   sudo systemctl start ntp
   ```

6. **Einrichtung der Swap-Datei (falls benötigt):**
   ```bash
   sudo fallocate -l 8G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
   ```

7. **Optimierung der Systemeinstellungen:**
   ```bash
   # Erhöhung der maximalen Anzahl offener Dateien
   echo 'fs.file-max = 65535' | sudo tee -a /etc/sysctl.conf
   
   # Optimierung für Netzwerkverbindungen
   echo 'net.core.somaxconn = 65535' | sudo tee -a /etc/sysctl.conf
   echo 'net.ipv4.tcp_max_syn_backlog = 4096' | sudo tee -a /etc/sysctl.conf
   
   # Anwenden der Änderungen
   sudo sysctl -p
   ```

## 2. Installationsreihenfolge

Die Komponenten des DevSystem-Projekts müssen in einer bestimmten Reihenfolge installiert werden, um Abhängigkeiten und Konfigurationsanforderungen zu erfüllen. Die folgende Reihenfolge wird empfohlen:

1. **Tailscale:** Zuerst wird Tailscale installiert und konfiguriert, um die sichere Netzwerkverbindung herzustellen.
2. **Caddy:** Anschließend wird Caddy als Reverse Proxy installiert und konfiguriert.
3. **code-server:** Danach wird code-server als Web-IDE installiert.
4. **Ollama:** Dann wird Ollama für lokale KI-Modelle installiert.
5. **Roo Code Extension:** Zuletzt wird die Roo Code Extension für code-server installiert und mit OpenRouter konfiguriert.

Diese Reihenfolge stellt sicher, dass die Abhängigkeiten zwischen den Komponenten korrekt berücksichtigt werden und die Konfiguration reibungslos verläuft.

### 2.1 Abhängigkeiten zwischen den Komponenten

Die folgenden Abhängigkeiten bestehen zwischen den Komponenten:

- **Tailscale → Caddy:** Caddy benötigt Tailscale für die Zertifikate und die Netzwerkkonfiguration.
- **Caddy → code-server:** Caddy dient als Reverse Proxy für code-server und muss daher vor code-server konfiguriert werden.
- **code-server → Roo Code Extension:** Die Roo Code Extension wird in code-server installiert und benötigt daher eine funktionierende code-server-Installation.
- **Ollama → Roo Code Extension:** Die Roo Code Extension verwendet Ollama für lokale KI-Modelle und benötigt daher eine funktionierende Ollama-Installation.

### 2.2 Kritischer Pfad für die Installation

Der kritische Pfad für die Installation umfasst die folgenden Schritte:

1. Vorbereitung des Ubuntu VPS
2. Installation und Konfiguration von Tailscale
3. Installation und Konfiguration von Caddy
4. Installation und Konfiguration von code-server
5. Installation und Konfiguration von Ollama
6. Installation und Konfiguration der Roo Code Extension
7. Validierung der Installation

Jeder dieser Schritte muss erfolgreich abgeschlossen werden, bevor mit dem nächsten Schritt fortgefahren werden kann.

## 3. Deployment-Schritte

### 3.1 Installation und Konfiguration von Tailscale

Tailscale dient als primäre Netzwerksicherheitskomponente und ermöglicht einen sicheren, privaten Zugriff auf die Entwicklungsumgebung.

#### 3.1.1 Installation von Tailscale

```bash
# Aktualisieren der Paketlisten
sudo apt-get update

# Installation der erforderlichen Abhängigkeiten
sudo apt-get install -y curl apt-transport-https

# Hinzufügen des Tailscale-Repositorys
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.gpg | sudo apt-key add -
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.list | sudo tee /etc/apt/sources.list.d/tailscale.list

# Aktualisieren der Paketlisten mit dem neuen Repository
sudo apt-get update

# Installation von Tailscale
sudo apt-get install -y tailscale

# Starten des Tailscale-Dienstes
sudo systemctl start tailscale
```

#### 3.1.2 Authentifizierung und Autorisierung

```bash
# Initialisierung von Tailscale und Authentifizierung
sudo tailscale up --hostname="devsystem-vps"

# Optional: Spezifische Konfigurationsoptionen bei der Initialisierung
# sudo tailscale up --hostname="devsystem-vps" --advertise-routes=10.0.0.0/24
```

Nach Ausführung des `tailscale up`-Befehls wird ein Authentifizierungslink generiert. Dieser Link muss in einem Browser geöffnet werden, um den VPS mit dem Tailscale-Konto zu verknüpfen. Die Authentifizierung erfolgt über den Tailscale-Dienst und unterstützt verschiedene Identity Provider (Google, Microsoft, GitHub, etc.).

#### 3.1.3 Konfiguration für automatischen Start

```bash
# Aktivieren des Tailscale-Dienstes beim Systemstart
sudo systemctl enable tailscale

# Überprüfen des Dienststatus
sudo systemctl status tailscale
```

#### 3.1.4 Firewall-Konfiguration

Die Ubuntu-Firewall (UFW) sollte so konfiguriert werden, dass sie nur Verbindungen über Tailscale und lokale Verbindungen zulässt:

```bash
# Firewall zurücksetzen und standardmäßig eingehende Verbindungen blockieren
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Lokale Verbindungen erlauben
sudo ufw allow from 127.0.0.1

# SSH nur über Tailscale erlauben (optional: für Notfallzugriff auch direkt)
sudo ufw allow in on tailscale0

# Tailscale-Schnittstelle erlauben
sudo ufw allow in on tailscale0 to any port 22 proto tcp
sudo ufw allow in on tailscale0 to any port 80,443 proto tcp

# Tailscale UDP-Port für die Verbindung zum Koordinationsserver
sudo ufw allow 41641/udp

# Firewall aktivieren
sudo ufw enable
```

#### 3.1.5 Konfiguration der Access Control Lists (ACLs)

Die Zugriffskontrollen für Tailscale werden über ACLs konfiguriert. Diese werden in der Tailscale-Admin-Konsole als JSON-Datei definiert:

```json
{
  "acls": [
    {
      "action": "accept",
      "users": ["user@example.com"],
      "ports": ["*:*"]
    }
  ],
  "tagOwners": {
    "tag:server": ["user@example.com"],
  },
  "hosts": {
    "devsystem-vps": "100.x.y.z",
  }
}
```

Für das DevSystem-Projekt wird folgende ACL-Struktur empfohlen:

1. **Admin-Gruppe**: Vollzugriff auf alle Dienste und Ports des VPS
2. **Entwickler-Gruppe**: Zugriff auf spezifische Dienste (code-server, SSH)
3. **Monitoring-Gruppe**: Zugriff auf Monitoring-Ports und -Dienste

#### 3.1.6 DNS-Konfiguration

Tailscale bietet einen integrierten DNS-Dienst, der für die Namensauflösung im Tailnet verwendet werden kann:

```bash
# Aktivieren des Tailscale MagicDNS
sudo tailscale up --accept-dns

# Konfigurieren von benutzerdefinierten DNS-Einträgen
sudo tailscale set --hostname=devsystem-vps
```

Für das DevSystem werden folgende DNS-Einträge empfohlen:

1. **MagicDNS aktivieren**: Ermöglicht die Auflösung von Gerätenamen im Tailnet
2. **Benutzerdefinierte DNS-Einträge**: Für spezifische Dienste im DevSystem
   - `code.devsystem.internal` -> VPS-IP im Tailnet
   - `ollama.devsystem.internal` -> VPS-IP im Tailnet

### 3.2 Installation und Konfiguration von Caddy

Caddy wird als Reverse Proxy für die verschiedenen Dienste des DevSystem-Projekts eingesetzt und ist für die HTTPS-Terminierung und das Routing von Anfragen verantwortlich.

#### 3.2.1 Installation von Caddy

Die empfohlene Methode ist die Installation über das offizielle Paket-Repository:

```bash
# Abhängigkeiten installieren
sudo apt update
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl

# Caddy GPG-Schlüssel und Repository hinzufügen
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list

# Paketlisten aktualisieren und Caddy installieren
sudo apt update
sudo apt install caddy
```

Alternativ kann Caddy auch direkt von der offiziellen Website heruntergeladen werden:

```bash
# Caddy herunterladen
curl -o caddy.tar.gz -L "https://github.com/caddyserver/caddy/releases/latest/download/caddy_2.7.5_linux_amd64.tar.gz"

# Entpacken und installieren
sudo tar -xzf caddy.tar.gz -C /usr/local/bin caddy
sudo chmod +x /usr/local/bin/caddy

# Benutzer und Gruppe für Caddy erstellen
sudo groupadd --system caddy
sudo useradd --system \
    --gid caddy \
    --create-home \
    --home-dir /var/lib/caddy \
    --shell /usr/sbin/nologin \
    --comment "Caddy web server" \
    caddy
```

#### 3.2.2 Verzeichnisstruktur einrichten

Nach der Installation von Caddy wird folgende Verzeichnisstruktur empfohlen:

```bash
# Verzeichnisse erstellen
sudo mkdir -p /etc/caddy/sites
sudo mkdir -p /etc/caddy/snippets
sudo mkdir -p /etc/caddy/tls/tailscale
sudo mkdir -p /etc/caddy/tls/local
sudo mkdir -p /var/log/caddy
sudo mkdir -p /var/www/code-server-pwa

# Berechtigungen setzen
sudo chown -R caddy:caddy /etc/caddy
sudo chown -R caddy:caddy /var/log/caddy
sudo chown -R caddy:caddy /var/www/code-server-pwa
```

#### 3.2.3 Konfiguration für automatischen Start

Wenn Caddy über das Paket-Repository installiert wurde, wird automatisch ein systemd-Service eingerichtet. Andernfalls kann ein eigener systemd-Service erstellt werden:

```bash
# Systemd-Service-Datei erstellen
sudo cat > /etc/systemd/system/caddy.service << EOF
[Unit]
Description=Caddy Web Server
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
ExecStart=/usr/local/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/local/bin/caddy reload --config /etc/caddy/Caddyfile
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

# Systemd neu laden und Caddy-Service aktivieren
sudo systemctl daemon-reload
sudo systemctl enable caddy
sudo systemctl start caddy
```

#### 3.2.4 Grundlegende Caddyfile-Konfiguration

Die Hauptkonfigurationsdatei für Caddy ist die `Caddyfile`. Hier ist eine grundlegende Struktur für das DevSystem-Projekt:

```bash
# Caddyfile erstellen
sudo cat > /etc/caddy/Caddyfile << EOF
# Globale Optionen
{
    # Admin-API deaktivieren (Sicherheitsmaßnahme)
    admin off
    
    # Standardprotokoll auf HTTP/2 setzen
    servers {
        protocol {
            experimental_http3
            strict_sni_host
        }
    }
    
    # Log-Einstellungen
    log {
        output file /var/log/caddy/access.log
        format json
    }
}

# Gemeinsame Snippets importieren
import /etc/caddy/snippets/*.caddy

# Site-Konfigurationen importieren
import /etc/caddy/sites/*.caddy
EOF
```

#### 3.2.5 Konfiguration für code-server

Die Konfiguration für den code-server-Dienst wird in einer separaten Datei definiert:

```bash
# Konfigurationsdatei für code-server erstellen
sudo cat > /etc/caddy/sites/code-server.caddy << EOF
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
EOF
```

#### 3.2.6 Konfiguration für Ollama

Die Konfiguration für den Ollama-Dienst wird ebenfalls in einer separaten Datei definiert:

```bash
# Konfigurationsdatei für Ollama erstellen
sudo cat > /etc/caddy/sites/ollama.caddy << EOF
ollama.devsystem.internal {
    # Nur Zugriff über Tailscale erlauben
    @tailscale {
        remote_ip 100.64.0.0/10
    }
    
    # Reverse Proxy zu Ollama
    reverse_proxy @tailscale localhost:11434 {
        # Timeouts erhöhen für lange Inferenz-Anfragen
        transport http {
            keepalive 5m
            keepalive_idle_conns 5
        }
    }
    
    # Zugriff verweigern, wenn nicht über Tailscale
    respond !@tailscale 403 {
        body "Zugriff nur über Tailscale erlaubt"
    }
    
    # Sicherheits-Header
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-XSS-Protection "1; mode=block"
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "strict-origin-when-cross-origin"
        -Server
    }
    
    # Rate Limiting für API-Anfragen
    rate_limit {
        zone ollama_api {
            key {remote_ip}
            events 100
            window 1m
        }
    }
    
    # Logging
    log {
        output file /var/log/caddy/ollama.log {
            roll_size 50MB
            roll_keep 5
            roll_keep_for 168h
        }
        format json
    }
}
EOF
```

#### 3.2.7 Sicherheits-Header-Konfiguration

Die Sicherheits-Header werden in einem wiederverwendbaren Snippet definiert:

```bash
# Sicherheits-Header-Snippet erstellen
sudo cat > /etc/caddy/snippets/security-headers.caddy << EOF
header {
    # Strict-Transport-Security aktivieren
    Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    
    # XSS-Schutz aktivieren
    X-XSS-Protection "1; mode=block"
    
    # Clickjacking-Schutz
    X-Frame-Options "SAMEORIGIN"
    
    # MIME-Sniffing verhindern
    X-Content-Type-Options "nosniff"
    
    # Referrer-Policy einschränken
    Referrer-Policy "strict-origin-when-cross-origin"
    
    # Content-Security-Policy für erhöhte Sicherheit
    Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' wss:; frame-ancestors 'self';"
    
    # Entfernen von Server-Header
    -Server
}
EOF
```

#### 3.2.8 Integration mit Tailscale-Zertifikaten

Tailscale kann automatisch TLS-Zertifikate für Domains im Tailnet ausstellen:

```bash
# Aktivieren der Tailscale HTTPS-Zertifikate
sudo tailscale cert devsystem-vps.ts.net

# Zertifikate für Caddy verfügbar machen
sudo mkdir -p /etc/caddy/tls/tailscale
sudo cp /var/lib/tailscale/certs/devsystem-vps.ts.net.* /etc/caddy/tls/tailscale/
sudo chown -R caddy:caddy /etc/caddy/tls/tailscale
```

Ein Skript zur automatischen Erneuerung der Tailscale-Zertifikate:

```bash
# Skript zur Zertifikatserneuerung erstellen
sudo cat > /usr/local/bin/tailscale-cert-renew.sh << EOF
#!/bin/bash

# Zertifikate erneuern
sudo tailscale cert devsystem-vps.ts.net

# Zertifikate für Caddy kopieren
sudo cp /var/lib/tailscale/certs/devsystem-vps.ts.net.* /etc/caddy/tls/tailscale/
sudo chown -R caddy:caddy /etc/caddy/tls/tailscale

# Caddy neu laden
sudo systemctl reload caddy
EOF

# Skript ausführbar machen
sudo chmod +x /usr/local/bin/tailscale-cert-renew.sh

# Cron-Job für monatliche Erneuerung einrichten
echo "0 0 1 * * /usr/local/bin/tailscale-cert-renew.sh >> /var/log/tailscale-cert-renew.log 2>&1" | sudo tee -a /etc/crontab
```

#### 3.2.9 Überprüfung der Konfiguration und Neustart

Nach Abschluss der Konfiguration sollte die Syntax überprüft und Caddy neu gestartet werden:

```bash
# Konfiguration validieren
sudo caddy validate --config /etc/caddy/Caddyfile

# Caddy neu starten
sudo systemctl restart caddy

# Status überprüfen
sudo systemctl status caddy
```

### 3.3 Installation und Konfiguration von code-server

Code-server wird als Web-IDE für das DevSystem-Projekt eingesetzt und ermöglicht die Entwicklung direkt im Browser.

#### 3.3.1 Installation von code-server

Die empfohlene Methode ist die Installation über das offizielle Installationsskript:

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

#### 3.3.2 Verzeichnisstruktur einrichten

Nach der Installation von code-server wird folgende Verzeichnisstruktur empfohlen:

```bash
# Verzeichnisse erstellen
mkdir -p ~/.config/code-server/data/User
mkdir -p ~/workspaces/devsystem

# Git-Repository klonen (falls vorhanden)
git clone https://github.com/HaraldKiessling/DevSystem.git ~/workspaces/devsystem

# Berechtigungen setzen
chmod 750 ~/workspaces/devsystem
```

#### 3.3.3 Grundkonfiguration

Die Hauptkonfigurationsdatei für code-server befindet sich unter `~/.config/code-server/config.yaml`. Hier können grundlegende Einstellungen wie Authentifizierung und Netzwerkbindung konfiguriert werden:

```bash
# Konfigurationsdatei erstellen
cat > ~/.config/code-server/config.yaml << EOF
bind-addr: 127.0.0.1:8080
auth: none  # Authentifizierung wird durch Tailscale übernommen
cert: false # SSL-Terminierung erfolgt durch Caddy
EOF
```

#### 3.3.4 Workspace-Setup

Die Workspace-Konfiguration kann in einer `.code-workspace`-Datei definiert werden:

```bash
# Workspace-Konfigurationsdatei erstellen
cat > ~/workspaces/devsystem.code-workspace << EOF
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
EOF
```

#### 3.3.5 Benutzereinstellungen

Die Benutzereinstellungen für code-server werden in der Datei `~/.config/code-server/data/User/settings.json` gespeichert:

```bash
# Benutzereinstellungen erstellen
cat > ~/.config/code-server/data/User/settings.json << EOF
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
EOF
```

#### 3.3.6 Konfiguration für automatischen Start

Code-server wird standardmäßig als systemd-Service eingerichtet, wenn es über das Installationsskript installiert wird. Die Service-Datei befindet sich unter `/etc/systemd/system/code-server@.service`.

Für eine benutzerdefinierte Konfiguration kann die systemd-Service-Datei angepasst werden:

```bash
# Bearbeiten der Service-Datei
sudo cat > /etc/systemd/system/code-server@.service << EOF
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
EOF

# Systemd neu laden
sudo systemctl daemon-reload

# Dienst neu starten
sudo systemctl restart code-server@$USER
```

#### 3.3.7 PWA-Konfiguration

Code-server kann als Progressive Web App (PWA) konfiguriert werden, um eine App-ähnliche Erfahrung auf mobilen Geräten zu bieten:

```bash
# Web App Manifest-Datei erstellen
sudo cat > /var/www/code-server-pwa/manifest.json << EOF
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

# Service Worker erstellen
sudo cat > /var/www/code-server-pwa/service-worker.js << EOF
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

# Caddy-Konfiguration für PWA anpassen
sudo cat >> /etc/caddy/sites/code-server.caddy << EOF

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
    Link "</manifest.json>; rel=manifest"
}
EOF

# Caddy neu laden
sudo systemctl reload caddy
```

#### 3.3.8 Automatische Installation von Erweiterungen

Um die automatische Installation von Erweiterungen für alle Benutzer zu ermöglichen, kann ein Skript erstellt werden:

```bash
# Skript zur Installation von Erweiterungen erstellen
cat > /usr/local/bin/install-code-extensions.sh << EOF
#!/bin/bash

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
for ext in "\${EXTENSIONS[@]}"; do
  code-server --install-extension "\$ext"
done
EOF

# Skript ausführbar machen
chmod +x /usr/local/bin/install-code-extensions.sh

# Skript ausführen
/usr/local/bin/install-code-extensions.sh
```

#### 3.3.9 Backup-Konfiguration

Für die Sicherung der code-server-Konfiguration und Workspaces kann ein Backup-Skript erstellt werden:

```bash
# Backup-Skript erstellen
cat > /usr/local/bin/code-server-backup.sh << EOF
#!/bin/bash

# Backup-Verzeichnis
BACKUP_DIR="/var/backups/code-server"
TIMESTAMP=\$(date +%Y%m%d%H%M%S)

# Backup-Verzeichnis erstellen, falls es nicht existiert
mkdir -p \$BACKUP_DIR

# Konfigurationsdateien sichern
tar -czf \$BACKUP_DIR/code-server-config-\$TIMESTAMP.tar.gz \\
  /home/\$USER/.config/code-server/config.yaml \\
  /home/\$USER/.config/code-server/data/User/settings.json \\
  /home/\$USER/.config/code-server/data/User/keybindings.json

# Erweiterungen sichern
tar -czf \$BACKUP_DIR/code-server-extensions-\$TIMESTAMP.tar.gz \\
  /home/\$USER/.config/code-server/data/extensions

# Workspace-Dateien sichern (ohne .git-Verzeichnisse)
tar -czf \$BACKUP_DIR/code-server-workspaces-\$TIMESTAMP.tar.gz \\
  --exclude='*.git' \\
  /home/\$USER/workspaces

# Alte Backups bereinigen (älter als 30 Tage)
find \$BACKUP_DIR -name "code-server-*.tar.gz" -type f -mtime +30 -delete
EOF

# Skript ausführbar machen
chmod +x /usr/local/bin/code-server-backup.sh

# Cron-Job für tägliches Backup einrichten
echo "0 2 * * * $USER /usr/local/bin/code-server-backup.sh >> /var/log/code-server-backup.log 2>&1" | sudo tee -a /etc/crontab
```

#### 3.3.10 Überprüfung der Installation

Nach Abschluss der Installation und Konfiguration sollte code-server überprüft werden:

```bash
# Status des code-server-Dienstes überprüfen
sudo systemctl status code-server@$USER

# Logs anzeigen
journalctl -u code-server@$USER -f

# Verbindung testen
curl -I http://localhost:8080
```

### 3.4 Installation und Konfiguration von Ollama

Ollama wird für die Ausführung lokaler KI-Modelle eingesetzt und ermöglicht die Nutzung von KI-Funktionen ohne externe API-Abhängigkeiten.

#### 3.4.1 Installation von Ollama

Die Installation von Ollama erfolgt über das offizielle Installationsskript:

```bash
# Herunterladen und Ausführen des Installationsskripts
curl -fsSL https://ollama.com/install.sh | sh
```

Alternativ kann Ollama auch manuell installiert werden:

```bash
# Herunterladen der neuesten Version
curl -L https://github.com/ollama/ollama/releases/latest/download/ollama-linux-amd64 -o ollama

# Ausführbar machen und in den Pfad verschieben
chmod +x ollama
sudo mv ollama /usr/local/bin/
```

#### 3.4.2 Konfiguration als Systemdienst

Um Ollama als Systemdienst zu konfigurieren, erstellen wir eine systemd-Service-Datei:

```bash
# Systemd-Service-Datei erstellen
sudo cat > /etc/systemd/system/ollama.service << EOF
[Unit]
Description=Ollama Service
After=network.target

[Service]
ExecStart=/usr/local/bin/ollama serve
Restart=always
RestartSec=10
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="OLLAMA_MODELS=/var/lib/ollama/models"
User=$USER
Group=$USER

[Install]
WantedBy=multi-user.target
EOF

# Systemd neu laden
sudo systemctl daemon-reload

# Ollama-Dienst aktivieren und starten
sudo systemctl enable ollama
sudo systemctl start ollama
```

#### 3.4.3 Verzeichnisstruktur einrichten

Für die Ollama-Modelle und -Konfigurationen wird folgende Verzeichnisstruktur empfohlen:

```bash
# Verzeichnisse erstellen
sudo mkdir -p /var/lib/ollama/models
sudo mkdir -p /etc/ollama

# Berechtigungen setzen
sudo chown -R $USER:$USER /var/lib/ollama
sudo chown -R $USER:$USER /etc/ollama
```

#### 3.4.4 Herunterladen und Einrichten der Modelle

Für das DevSystem-Projekt werden folgende Modelle empfohlen:

```bash
# Llama 3 8B Modell herunterladen
ollama pull llama3

# DeepSeek Coder Modell herunterladen
ollama pull deepseek-coder

# Weitere nützliche Modelle (optional)
# ollama pull mistral
# ollama pull gemma
```

#### 3.4.5 Konfiguration der Modellparameter

Die Modellparameter können in einer Modelldefinitionsdatei angepasst werden:

```bash
# Modelldefinitionsdatei für Llama 3 erstellen
cat > ~/llama3.modelfile << EOF
FROM llama3

# Systemkontext für das Modell
SYSTEM """
Du bist ein hilfreicher KI-Assistent für Entwicklungsaufgaben.
Deine Aufgabe ist es, bei der Programmierung zu helfen, Code zu erklären und Lösungen für technische Probleme anzubieten.
"""

# Parameter für die Inferenz
PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER top_k 40
EOF

# Modell mit angepassten Parametern erstellen
ollama create llama3-custom -f ~/llama3.modelfile
```

#### 3.4.6 Konfiguration der Ressourcenbegrenzung

Um die Ressourcennutzung von Ollama zu begrenzen, kann die systemd-Service-Datei angepasst werden:

```bash
# Systemd-Service-Datei bearbeiten
sudo cat > /etc/systemd/system/ollama.service << EOF
[Unit]
Description=Ollama Service
After=network.target

[Service]
ExecStart=/usr/local/bin/ollama serve
Restart=always
RestartSec=10
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="OLLAMA_MODELS=/var/lib/ollama/models"
User=$USER
Group=$USER

# Ressourcenbegrenzungen
CPUQuota=80%
MemoryLimit=8G

[Install]
WantedBy=multi-user.target
EOF

# Systemd neu laden und Dienst neu starten
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

#### 3.4.7 Konfiguration der GPU-Unterstützung (optional)

Wenn eine NVIDIA-GPU verfügbar ist, kann Ollama für die GPU-Beschleunigung konfiguriert werden:

```bash
# NVIDIA-Treiber und CUDA installieren
sudo apt update
sudo apt install -y nvidia-driver-535 nvidia-cuda-toolkit

# NVIDIA Container Toolkit installieren (für Docker-basierte Ausführung)
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/libnvidia-container/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt update
sudo apt install -y nvidia-container-toolkit

# Umgebungsvariable für Ollama setzen
echo 'export CUDA_VISIBLE_DEVICES=0' >> ~/.bashrc
source ~/.bashrc

# Ollama-Dienst neu starten
sudo systemctl restart ollama
```

#### 3.4.8 Überprüfung der Installation

Nach Abschluss der Installation und Konfiguration sollte Ollama überprüft werden:

```bash
# Status des Ollama-Dienstes überprüfen
sudo systemctl status ollama

# Verfügbare Modelle anzeigen
ollama list

# Einfachen Test durchführen
ollama run llama3 "Erkläre kurz, was DevOps ist."
```

#### 3.4.9 Backup-Konfiguration

Für die Sicherung der Ollama-Modelle und -Konfigurationen kann ein Backup-Skript erstellt werden:

```bash
# Backup-Skript erstellen
cat > /usr/local/bin/ollama-backup.sh << EOF
#!/bin/bash

# Backup-Verzeichnis
BACKUP_DIR="/var/backups/ollama"
TIMESTAMP=\$(date +%Y%m%d%H%M%S)

# Backup-Verzeichnis erstellen, falls es nicht existiert
mkdir -p \$BACKUP_DIR

# Ollama-Dienst anhalten
sudo systemctl stop ollama

# Modelle und Konfigurationen sichern
sudo tar -czf \$BACKUP_DIR/ollama-models-\$TIMESTAMP.tar.gz /var/lib/ollama/models
sudo tar -czf \$BACKUP_DIR/ollama-config-\$TIMESTAMP.tar.gz /etc/ollama

# Ollama-Dienst wieder starten
sudo systemctl start ollama

# Alte Backups bereinigen (älter als 30 Tage)
find \$BACKUP_DIR -name "ollama-*.tar.gz" -type f -mtime +30 -delete
EOF

# Skript ausführbar machen
chmod +x /usr/local/bin/ollama-backup.sh

# Cron-Job für wöchentliches Backup einrichten
echo "0 3 * * 0 root /usr/local/bin/ollama-backup.sh >> /var/log/ollama-backup.log 2>&1" | sudo tee -a /etc/crontab
```

### 3.5 Installation und Konfiguration der Roo Code Extension mit OpenRouter

Die Roo Code Extension ist ein zentraler Bestandteil des DevSystem-Projekts und ermöglicht die KI-gestützte Entwicklung. Sie wird in code-server installiert und mit OpenRouter für Cloud-KI-Modelle sowie mit Ollama für lokale KI-Modelle konfiguriert.

#### 3.5.1 Beschaffung des OpenRouter API-Schlüssels

Für die Nutzung von OpenRouter wird ein API-Schlüssel benötigt:

1. Registrieren Sie sich bei OpenRouter (https://openrouter.ai)
2. Erstellen Sie einen API-Schlüssel im Dashboard
3. Notieren Sie sich den API-Schlüssel für die spätere Verwendung

#### 3.5.2 Installation der Roo Code Extension

Die Roo Code Extension wird in code-server installiert:

```bash
# Verzeichnis für Extensions erstellen (falls noch nicht vorhanden)
mkdir -p ~/.config/code-server/data/extensions

# Herunterladen der Roo Code Extension
wget -O /tmp/roo-code.vsix https://github.com/example/roo-code/releases/latest/download/roo-code.vsix

# Installation der Erweiterung
code-server --install-extension /tmp/roo-code.vsix
```

#### 3.5.3 Konfiguration der Roo Code Extension

Die Konfiguration der Roo Code Extension erfolgt in den Benutzereinstellungen von code-server:

```bash
# Konfigurationsdatei bearbeiten
cat >> ~/.config/code-server/data/User/settings.json << EOF
,
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
EOF
```

Ersetzen Sie `OPENROUTER_API_KEY` durch Ihren tatsächlichen OpenRouter API-Schlüssel.

#### 3.5.4 Sichere Speicherung des API-Schlüssels

Für eine sicherere Speicherung des API-Schlüssels kann eine Umgebungsvariable verwendet werden:

```bash
# Umgebungsvariable in der .bashrc-Datei setzen
echo 'export OPENROUTER_API_KEY="Ihr-API-Schlüssel"' >> ~/.bashrc
source ~/.bashrc

# Konfigurationsdatei anpassen, um die Umgebungsvariable zu verwenden
sed -i 's/"roo-code.openrouter.apiKey": "OPENROUTER_API_KEY"/"roo-code.openrouter.apiKey": "${env:OPENROUTER_API_KEY}"/g' ~/.config/code-server/data/User/settings.json
```

#### 3.5.5 Konfiguration der Modellauswahl

Die verfügbaren Modelle können in den Einstellungen konfiguriert werden:

```bash
# Konfigurationsdatei für die Modellauswahl bearbeiten
cat >> ~/.config/code-server/data/User/settings.json << EOF
,
  "roo-code.availableModels": [
    {
      "id": "anthropic/claude-3-opus",
      "name": "Claude 3 Opus",
      "provider": "openrouter"
    },
    {
      "id": "anthropic/claude-3-sonnet",
      "name": "Claude 3 Sonnet",
      "provider": "openrouter"
    },
    {
      "id": "llama3",
      "name": "Llama 3 (lokal)",
      "provider": "ollama"
    },
    {
      "id": "deepseek-coder",
      "name": "DeepSeek Coder (lokal)",
      "provider": "ollama"
    }
  ]
EOF
```

#### 3.5.6 Konfiguration der Berechtigungen

Die Berechtigungen für die Roo Code Extension können in den Einstellungen konfiguriert werden:

```bash
# Konfigurationsdatei für die Berechtigungen bearbeiten
cat >> ~/.config/code-server/data/User/settings.json << EOF
,
  "roo-code.permissions": {
    "allowFileSystemAccess": true,
    "allowNetworkAccess": true,
    "allowTerminalAccess": true,
    "allowSettingsAccess": true
  }
EOF
```

#### 3.5.7 Überprüfung der Installation

Nach Abschluss der Installation und Konfiguration sollte die Roo Code Extension überprüft werden:

```bash
# Code-server neu starten
sudo systemctl restart code-server@$USER

# Überprüfen, ob die Extension installiert ist
code-server --list-extensions | grep roo-code
```

#### 3.5.8 Backup der Konfiguration

Die Konfiguration der Roo Code Extension sollte in das bestehende Backup-Skript für code-server integriert werden:

```bash
# Backup-Skript bearbeiten
sed -i '/\/home\/\$USER\/.config\/code-server\/data\/User\/settings.json/s/$/\n  \/home\/\$USER\/.config\/code-server\/data\/User\/roo-code-settings.json/' /usr/local/bin/code-server-backup.sh
```

## 4. Validierung

Nach Abschluss der Installation und Konfiguration aller Komponenten sollte das gesamte System validiert werden, um sicherzustellen, dass es korrekt funktioniert.

### 4.1 Überprüfung der Netzwerkkonfiguration

#### 4.1.1 Tailscale-Verbindung testen

```bash
# Tailscale-Status überprüfen
tailscale status

# Verbindung zu anderen Geräten im Tailnet testen
ping devsystem-vps.ts.net
```

#### 4.1.2 Firewall-Regeln überprüfen

```bash
# Firewall-Status überprüfen
sudo ufw status verbose

# Offene Ports überprüfen
sudo ss -tulpn
```

### 4.2 Überprüfung der Dienste

#### 4.2.1 Dienststatus überprüfen

```bash
# Status aller relevanten Dienste überprüfen
sudo systemctl status tailscale
sudo systemctl status caddy
sudo systemctl status code-server@$USER
sudo systemctl status ollama
```

#### 4.2.2 Logs überprüfen

```bash
# Logs der Dienste überprüfen
sudo journalctl -u tailscale -n 50
sudo journalctl -u caddy -n 50
sudo journalctl -u code-server@$USER -n 50
sudo journalctl -u ollama -n 50
```

### 4.3 Funktionstest der Komponenten

#### 4.3.1 Zugriff auf code-server testen

1. Verbinden Sie sich mit dem Tailscale-Netzwerk
2. Öffnen Sie einen Browser und navigieren Sie zu `https://code.devsystem.internal`
3. Überprüfen Sie, ob die code-server-Oberfläche geladen wird

#### 4.3.2 Ollama-Integration testen

```bash
# Testen, ob Ollama läuft und Anfragen beantwortet
curl -X POST http://localhost:11434/api/generate -d '{
  "model": "llama3",
  "prompt": "Erkläre kurz, was DevOps ist."
}'
```

#### 4.3.3 Roo Code Extension testen

1. Öffnen Sie code-server im Browser
2. Öffnen Sie eine Datei
3. Testen Sie die Roo Code Extension, indem Sie eine Anfrage stellen
4. Überprüfen Sie, ob sowohl Cloud-Modelle (über OpenRouter) als auch lokale Modelle (über Ollama) funktionieren

### 4.4 Sicherheitsüberprüfung

#### 4.4.1 Zugriffskontrolle testen

```bash
# Testen, ob der Zugriff von außerhalb des Tailscale-Netzwerks blockiert wird
# (Von einem nicht mit Tailscale verbundenen Gerät ausführen)
curl -I https://code.devsystem.internal
```

#### 4.4.2 TLS-Konfiguration überprüfen

```bash
# TLS-Konfiguration überprüfen
curl -vI https://code.devsystem.internal
```

### 4.5 Performance-Test

```bash
# CPU- und Speichernutzung überwachen
htop

# Netzwerkverbindungen überwachen
sudo netstat -tulpn

# Festplattennutzung überprüfen
df -h
```

## 5. Wartung und Updates

Regelmäßige Wartung und Updates sind entscheidend, um die Sicherheit und Funktionalität des DevSystem-Projekts zu gewährleisten.

### 5.1 Regelmäßige Updates

#### 5.1.1 Betriebssystem-Updates

```bash
# Paketlisten aktualisieren
sudo apt update

# Sicherheitsupdates installieren
sudo apt upgrade -y

# Neustart, falls erforderlich
sudo needrestart -r a
```

Es wird empfohlen, diese Updates mindestens einmal pro Woche durchzuführen. Dies kann über einen Cron-Job automatisiert werden:

```bash
# Skript für automatische Updates erstellen
cat > /usr/local/bin/auto-update.sh << EOF
#!/bin/bash

# Log-Datei
LOG_FILE="/var/log/auto-update.log"

# Datum und Uhrzeit
echo "=== Update gestartet am \$(date) ===" >> \$LOG_FILE

# Paketlisten aktualisieren
apt update >> \$LOG_FILE 2>&1

# Sicherheitsupdates installieren
apt upgrade -y >> \$LOG_FILE 2>&1

# Aufräumen
apt autoremove -y >> \$LOG_FILE 2>&1
apt clean >> \$LOG_FILE 2>&1

echo "=== Update abgeschlossen am \$(date) ===" >> \$LOG_FILE
EOF

# Skript ausführbar machen
chmod +x /usr/local/bin/auto-update.sh

# Cron-Job für wöchentliche Updates einrichten (Sonntag um 4:00 Uhr)
echo "0 4 * * 0 root /usr/local/bin/auto-update.sh" | sudo tee -a /etc/crontab
```

#### 5.1.2 Tailscale-Updates

Tailscale aktualisiert sich in der Regel automatisch. Der Status kann wie folgt überprüft werden:

```bash
# Tailscale-Version anzeigen
tailscale version

# Manuelles Update (falls erforderlich)
sudo apt update
sudo apt install -y tailscale
```

#### 5.1.3 Caddy-Updates

```bash
# Caddy-Version anzeigen
caddy version

# Caddy aktualisieren
sudo apt update
sudo apt install -y caddy

# Caddy-Dienst neu starten
sudo systemctl restart caddy
```

#### 5.1.4 code-server-Updates

```bash
# code-server-Version anzeigen
code-server --version

# code-server aktualisieren
curl -fsSL https://code-server.dev/install.sh | sh

# code-server-Dienst neu starten
sudo systemctl restart code-server@$USER
```

#### 5.1.5 Ollama-Updates

```bash
# Ollama-Version anzeigen
ollama --version

# Ollama aktualisieren
curl -fsSL https://ollama.com/install.sh | sh

# Ollama-Dienst neu starten
sudo systemctl restart ollama
```

#### 5.1.6 Modell-Updates

```bash
# Verfügbare Modelle anzeigen
ollama list

# Modelle aktualisieren
ollama pull llama3
ollama pull deepseek-coder
```

### 5.2 Backup und Wiederherstellung

#### 5.2.1 Vollständiges System-Backup

Für ein vollständiges Backup des Systems kann ein Skript erstellt werden, das alle wichtigen Konfigurationen und Daten sichert:

```bash
# Backup-Skript erstellen
cat > /usr/local/bin/system-backup.sh << EOF
#!/bin/bash

# Backup-Verzeichnis
BACKUP_DIR="/var/backups/system"
TIMESTAMP=\$(date +%Y%m%d%H%M%S)
BACKUP_FILE="\$BACKUP_DIR/system-backup-\$TIMESTAMP.tar.gz"

# Backup-Verzeichnis erstellen, falls es nicht existiert
mkdir -p \$BACKUP_DIR

# Dienste anhalten
sudo systemctl stop code-server@$USER
sudo systemctl stop ollama
sudo systemctl stop caddy

# Wichtige Verzeichnisse und Dateien sichern
sudo tar -czf \$BACKUP_FILE \
  /etc/caddy \
  /etc/tailscale \
  /etc/systemd/system/code-server@.service \
  /etc/systemd/system/ollama.service \
  /etc/systemd/system/caddy.service \
  /home/$USER/.config/code-server \
  /var/lib/ollama \
  /etc/ollama \
  /var/www/code-server-pwa

# Dienste wieder starten
sudo systemctl start caddy
sudo systemctl start ollama
sudo systemctl start code-server@$USER

# Alte Backups bereinigen (älter als 30 Tage)
find \$BACKUP_DIR -name "system-backup-*.tar.gz" -type f -mtime +30 -delete

echo "Backup erstellt: \$BACKUP_FILE"
EOF

# Skript ausführbar machen
chmod +x /usr/local/bin/system-backup.sh

# Cron-Job für wöchentliches Backup einrichten (Samstag um 3:00 Uhr)
echo "0 3 * * 6 root /usr/local/bin/system-backup.sh >> /var/log/system-backup.log 2>&1" | sudo tee -a /etc/crontab
```

#### 5.2.2 Wiederherstellung aus einem Backup

```bash
# Wiederherstellungs-Skript erstellen
cat > /usr/local/bin/system-restore.sh << EOF
#!/bin/bash

# Backup-Datei als Parameter übergeben
BACKUP_FILE=\$1

if [ -z "\$BACKUP_FILE" ]; then
  echo "Bitte geben Sie die Backup-Datei an."
  exit 1
fi

if [ ! -f "\$BACKUP_FILE" ]; then
  echo "Die angegebene Backup-Datei existiert nicht."
  exit 1
fi

# Dienste anhalten
sudo systemctl stop code-server@$USER
sudo systemctl stop ollama
sudo systemctl stop caddy

# Backup wiederherstellen
sudo tar -xzf \$BACKUP_FILE -C /

# Berechtigungen wiederherstellen
sudo chown -R caddy:caddy /etc/caddy
sudo chown -R caddy:caddy /var/www/code-server-pwa
sudo chown -R $USER:$USER /home/$USER/.config/code-server
sudo chown -R $USER:$USER /var/lib/ollama
sudo chown -R $USER:$USER /etc/ollama

# Dienste wieder starten
sudo systemctl daemon-reload
sudo systemctl start caddy
sudo systemctl start ollama
sudo systemctl start code-server@$USER

echo "Wiederherstellung abgeschlossen."
EOF

# Skript ausführbar machen
chmod +x /usr/local/bin/system-restore.sh
```

### 5.3 Monitoring und Logging

#### 5.3.1 Zentrales Logging

Für ein zentrales Logging kann ein einfaches Skript erstellt werden, das die Logs aller relevanten Dienste zusammenfasst:

```bash
# Log-Zusammenfassungs-Skript erstellen
cat > /usr/local/bin/system-logs.sh << EOF
#!/bin/bash

# Anzahl der Zeilen pro Dienst
LINES=50

# Datum und Uhrzeit
echo "=== Logs vom \$(date) ==="
echo ""

echo "=== Tailscale Logs ==="
sudo journalctl -u tailscale -n \$LINES
echo ""

echo "=== Caddy Logs ==="
sudo journalctl -u caddy -n \$LINES
echo ""

echo "=== code-server Logs ==="
sudo journalctl -u code-server@$USER -n \$LINES
echo ""

echo "=== Ollama Logs ==="
sudo journalctl -u ollama -n \$LINES
echo ""

echo "=== System Logs ==="
sudo journalctl -p err -n \$LINES
echo ""
EOF

# Skript ausführbar machen
chmod +x /usr/local/bin/system-logs.sh
```

#### 5.3.2 Ressourcenüberwachung

Für die Überwachung der Systemressourcen kann ein einfaches Skript erstellt werden:

```bash
# Ressourcenüberwachungs-Skript erstellen
cat > /usr/local/bin/system-monitor.sh << EOF
#!/bin/bash

# Log-Datei
LOG_FILE="/var/log/system-monitor.log"

# Datum und Uhrzeit
echo "=== Systemüberwachung vom \$(date) ===" >> \$LOG_FILE

# CPU-Auslastung
echo "CPU-Auslastung:" >> \$LOG_FILE
top -bn1 | grep "Cpu(s)" >> \$LOG_FILE

# Speichernutzung
echo "Speichernutzung:" >> \$LOG_FILE
free -h >> \$LOG_FILE

# Festplattennutzung
echo "Festplattennutzung:" >> \$LOG_FILE
df -h >> \$LOG_FILE

# Prozesse mit hoher CPU- oder Speichernutzung
echo "Top-Prozesse:" >> \$LOG_FILE
ps aux --sort=-%cpu | head -n 10 >> \$LOG_FILE

# Dienststatus
echo "Dienststatus:" >> \$LOG_FILE
systemctl status tailscale | grep Active >> \$LOG_FILE
systemctl status caddy | grep Active >> \$LOG_FILE
systemctl status code-server@$USER | grep Active >> \$LOG_FILE
systemctl status ollama | grep Active >> \$LOG_FILE

echo "" >> \$LOG_FILE
EOF

# Skript ausführbar machen
chmod +x /usr/local/bin/system-monitor.sh

# Cron-Job für stündliche Überwachung einrichten
echo "0 * * * * root /usr/local/bin/system-monitor.sh" | sudo tee -a /etc/crontab
```

## 6. Fehlerbehebung

### 6.1 Häufige Probleme und Lösungen

#### 6.1.1 Tailscale-Verbindungsprobleme

**Problem**: Tailscale-Verbindung kann nicht hergestellt werden.

**Lösungen**:
```bash
# Tailscale-Status überprüfen
tailscale status

# Tailscale-Dienst neu starten
sudo systemctl restart tailscale

# Tailscale neu authentifizieren
sudo tailscale up

# Firewall-Regeln überprüfen
sudo ufw status
sudo ufw allow 41641/udp
```

#### 6.1.2 Caddy-Konfigurationsprobleme

**Problem**: Caddy startet nicht oder leitet Anfragen nicht korrekt weiter.

**Lösungen**:
```bash
# Caddy-Konfiguration validieren
sudo caddy validate --config /etc/caddy/Caddyfile

# Caddy-Logs überprüfen
sudo journalctl -u caddy -f

# Caddy-Dienst neu starten
sudo systemctl restart caddy

# Ports überprüfen
sudo ss -tulpn | grep caddy
```

#### 6.1.3 code-server-Verbindungsprobleme

**Problem**: code-server ist nicht über den Browser erreichbar.

**Lösungen**:
```bash
# code-server-Status überprüfen
sudo systemctl status code-server@$USER

# code-server-Logs überprüfen
sudo journalctl -u code-server@$USER -f

# Lokale Verbindung testen
curl -I http://localhost:8080

# code-server-Dienst neu starten
sudo systemctl restart code-server@$USER
```

#### 6.1.4 Ollama-Modellprobleme

**Problem**: Ollama-Modelle können nicht geladen oder verwendet werden.

**Lösungen**:
```bash
# Ollama-Status überprüfen
sudo systemctl status ollama

# Ollama-Logs überprüfen
sudo journalctl -u ollama -f

# Verfügbare Modelle anzeigen
ollama list

# Modell neu herunterladen
ollama pull llama3

# Speicherplatz überprüfen
df -h
```

#### 6.1.5 Roo Code Extension-Probleme

**Problem**: Roo Code Extension funktioniert nicht oder kann keine Verbindung zu den KI-Modellen herstellen.

**Lösungen**:
```bash
# Überprüfen, ob die Extension installiert ist
code-server --list-extensions | grep roo-code

# API-Schlüssel überprüfen
echo $OPENROUTER_API_KEY

# Ollama-API testen
curl -X POST http://localhost:11434/api/generate -d '{
  "model": "llama3",
  "prompt": "Hallo"
}'

# code-server neu starten
sudo systemctl restart code-server@$USER
```

### 6.2 Diagnosetools und -techniken

#### 6.2.1 Netzwerkdiagnose

```bash
# Netzwerkverbindungen überprüfen
sudo netstat -tulpn

# DNS-Auflösung testen
nslookup code.devsystem.internal

# Tailscale-Netzwerk testen
tailscale ping devsystem-vps.ts.net

# Traceroute durchführen
traceroute code.devsystem.internal
```

#### 6.2.2 Systemdiagnose

```bash
# Systemlogs überprüfen
sudo journalctl -p err

# Dienststatus überprüfen
sudo systemctl list-units --state=failed

# Ressourcennutzung überwachen
htop

# Festplattennutzung überprüfen
sudo du -sh /var/lib/ollama/models
```

#### 6.2.3 Anwendungsdiagnose

```bash
# Caddy-Konfiguration testen
caddy fmt --overwrite /etc/caddy/Caddyfile
caddy validate --config /etc/caddy/Caddyfile

# code-server-Verbindung testen
curl -I http://localhost:8080

# Ollama-API testen
curl -X POST http://localhost:11434/api/generate -d '{
  "model": "llama3",
  "prompt": "Test"
}'
```

### 6.3 Eskalationspfade

Bei Problemen, die nicht mit den oben genannten Methoden gelöst werden können, sollten folgende Eskalationspfade in Betracht gezogen werden:

1. **Dokumentation konsultieren**:
   - Tailscale-Dokumentation: https://tailscale.com/kb/
   - Caddy-Dokumentation: https://caddyserver.com/docs/
   - code-server-Dokumentation: https://coder.com/docs/code-server/latest
   - Ollama-Dokumentation: https://ollama.ai/docs

2. **Community-Foren**:
   - Tailscale-Forum: https://github.com/tailscale/tailscale/discussions
   - Caddy-Forum: https://caddy.community/
   - code-server-Forum: https://github.com/coder/code-server/discussions
   - Ollama-Forum: https://github.com/ollama/ollama/discussions

3. **Issue-Tracker**:
   - Tailscale: https://github.com/tailscale/tailscale/issues
   - Caddy: https://github.com/caddyserver/caddy/issues
   - code-server: https://github.com/coder/code-server/issues
   - Ollama: https://github.com/ollama/ollama/issues

4. **Professioneller Support**:
   - Tailscale bietet kostenpflichtigen Support für Business-Kunden an
   - OpenRouter bietet Support für API-Nutzer an

## 7. Dokumentation

### 7.1 Aktualisierung der Dokumentation

Die Dokumentation des DevSystem-Projekts sollte regelmäßig aktualisiert werden, um Änderungen an der Konfiguration, neue Funktionen oder Problembehebungen zu reflektieren.

#### 7.1.1 Dokumentationsstruktur

Die Dokumentation sollte folgende Bereiche umfassen:

1. **Architekturübersicht**: Beschreibung der Systemarchitektur und der Komponenten
2. **Installationsanleitung**: Detaillierte Schritte zur Installation und Konfiguration
3. **Benutzerhandbuch**: Anleitung zur Nutzung des Systems
4. **Administratorhandbuch**: Anleitung zur Verwaltung und Wartung des Systems
5. **Fehlerbehebung**: Häufige Probleme und Lösungen
6. **Änderungsprotokoll**: Dokumentation von Änderungen am System

#### 7.1.2 Dokumentationsprozess

Für die Aktualisierung der Dokumentation wird folgender Prozess empfohlen:

1. **Änderungen dokumentieren**: Bei jeder Änderung am System sollte die entsprechende Dokumentation aktualisiert werden
2. **Review**: Die aktualisierte Dokumentation sollte von einem anderen Teammitglied überprüft werden
3. **Versionierung**: Die Dokumentation sollte versioniert werden, um Änderungen nachverfolgen zu können
4. **Veröffentlichung**: Die aktualisierte Dokumentation sollte allen Teammitgliedern zur Verfügung gestellt werden

### 7.2 Änderungsmanagement

#### 7.2.1 Änderungsprozess

Für Änderungen am System wird folgender Prozess empfohlen:

1. **Änderungsantrag**: Beschreibung der geplanten Änderung und ihrer Auswirkungen
2. **Risikobewertung**: Bewertung der Risiken und Auswirkungen der Änderung
3. **Genehmigung**: Genehmigung der Änderung durch einen Verantwortlichen
4. **Implementierung**: Durchführung der Änderung
5. **Validierung**: Überprüfung, ob die Änderung erfolgreich war
6. **Dokumentation**: Aktualisierung der Dokumentation

#### 7.2.2 Änderungsprotokoll

Für jede Änderung am System sollte ein Eintrag im Änderungsprotokoll erstellt werden:

```markdown
# Änderungsprotokoll

## [1.0.0] - 2026-04-07
### Hinzugefügt
- Initiale Installation und Konfiguration des DevSystem-Projekts
- Tailscale für sichere Netzwerkverbindung
- Caddy als Reverse Proxy
- code-server als Web-IDE
- Ollama für lokale KI-Modelle
- Roo Code Extension mit OpenRouter-Integration

## [1.0.1] - 2026-04-14
### Geändert
- Aktualisierung von Ollama auf Version X.Y.Z
- Optimierung der Ressourcennutzung für Ollama

### Behoben
- Problem mit der WebSocket-Verbindung in Caddy
```

### 7.3 Versionskontrolle

#### 7.3.1 Git-Repository

Die Konfigurationsdateien und Skripte des DevSystem-Projekts sollten in einem Git-Repository verwaltet werden:

```bash
# Git-Repository initialisieren
cd /home/$USER/workspaces/devsystem
git init

# Konfigurationsdateien hinzufügen
cp /etc/caddy/Caddyfile ./config/caddy/
cp ~/.config/code-server/config.yaml ./config/code-server/
cp /etc/systemd/system/ollama.service ./config/systemd/

# .gitignore-Datei erstellen
cat > .gitignore << EOF
# Sensible Daten
*.key
*.pem
*.env

# Temporäre Dateien
*.tmp
*.log

# Große Dateien
models/
EOF

# Änderungen committen
git add .
git commit -m "Initiale Konfiguration"
```

#### 7.3.2 Backup des Git-Repositories

Das Git-Repository sollte regelmäßig gesichert werden:

```bash
# Repository klonen
git clone /home/$USER/workspaces/devsystem /var/backups/devsystem-repo

# Oder zu einem Remote-Repository pushen
git remote add origin https://github.com/username/devsystem.git
git push -u origin main
```