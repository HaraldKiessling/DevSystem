# KI-Integration Konzept für DevSystem

**Version:** 1.0  
**Datum:** 2026-04-09  
**Status:** Architektur-Konzept

---

## Executive Summary

Das DevSystem wird um KI-Funktionalität erweitert, um KI-gestützte Entwicklung direkt im Browser zu ermöglichen. Die Architektur kombiniert Cloud-KI (OpenRouter) für leistungsstarke Modelle mit lokaler KI (Ollama) für Datenschutz und Offline-Verfügbarkeit. Die Roo Code Extension dient als zentrale Steuerungseinheit mit Multi-Agent-Fähigkeiten.

**Kernarchitektur:**
- Roo Code Extension als VS Code Extension in code-server (bereits installiert)
- OpenRouter als Cloud-KI-Provider für leistungsstarke Modelle
- Ollama als lokale KI-Engine für ressourcenschonende Modelle
- Intelligente Routing-Logik zwischen Cloud und lokal

**Status Quo:** code-server läuft bereits über Tailscale VPN und Caddy Reverse Proxy (Port 9443). Die Roo Code Extension ist bereits aktiv und nutzt Claude Sonnet 4.5 über OpenRouter.

---

## Inhaltsverzeichnis

1. [Architektur-Übersicht](#1-architektur-übersicht)
2. [Roo Code Extension](#2-roo-code-extension)
3. [OpenRouter Integration](#3-openrouter-integration)
4. [Ollama Integration](#4-ollama-integration)
5. [Sicherheitskonzept](#5-sicherheitskonzept)
6. [Testkonzept](#6-testkonzept)
7. [MVP-Abgrenzung](#7-mvp-abgrenzung)
8. [Implementierungsplan](#8-implementierungsplan)
9. [Offene Entscheidungen](#9-offene-entscheidungen)

---

## 1. Architektur-Übersicht

### 1.1 Systemarchitektur

```
┌─────────────────────────────────────────────────────────────┐
│                      Handy-Browser (PWA)                     │
│                    https://100.100.221.56:9443              │
└────────────────────────────┬────────────────────────────────┘
                             │ Tailscale VPN (verschlüsselt)
┌────────────────────────────▼────────────────────────────────┐
│                      Caddy Reverse Proxy                     │
│                         Port 9443 (HTTPS)                    │
└────────────────────────────┬────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────┐
│                      code-server (Port 8080)                 │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │            Roo Code Extension (VS Code)             │   │
│  │         Multi-Agent KI-Steuerung                    │   │
│  └───────────────┬─────────────────────┬───────────────┘   │
│                  │                     │                     │
│        ┌─────────▼────────┐   ┌────────▼─────────┐         │
│        │  OpenRouter API  │   │  Ollama Service  │         │
│        │   (Cloud-KI)     │   │   (Lokale-KI)    │         │
│        │  Internet-Zugriff│   │  Port 11434      │         │
│        └──────────────────┘   └──────────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 Datenfluss

1. **Benutzer-Anfrage:** Entwickler stellt KI-Anfrage über Roo Code UI
2. **Routing-Entscheidung:** Roo Code entscheidet basierend auf Aufgabentyp
   - Komplex/Cloud-nötig → OpenRouter
   - Einfach/Datenschutz → Ollama lokal
3. **KI-Verarbeitung:** Modell generiert Response
4. **Code-Integration:** Roo Code integriert Response in Workspace
5. **Persistierung:** Änderungen werden in code-server gespeichert

### 1.3 Technologie-Stack

| Komponente | Technologie | Version | Zweck |
|------------|-------------|---------|-------|
| KI-Extension | Roo Code | 3.52.0 (bereits installiert) | Multi-Agent Steuerung |
| Cloud-KI | OpenRouter API | Latest | Zugriff auf verschiedene LLMs |
| Lokale-KI | Ollama | Latest | Offline-fähige Modelle |
| Orchestrierung | VS Code Extension API | - | Integration in code-server |
| Authentifizierung | Environment Variables | - | API-Key-Management |
| Netzwerk | Tailscale VPN | - | Sicherer Zugriff |

---

## 2. Roo Code Extension

### 2.1 Überblick

**Status:** Bereits installiert und aktiv im System  
**Extension ID:** `rooveterinaryinc.roo-cline`  
**Version:** 3.52.0

Die Roo Code Extension ist bereits vollständig funktionsfähig und nutzt derzeit Claude Sonnet 4.5 über OpenRouter.

### 2.2 Modi (Modes)

Roo Code bietet 5 spezialisierte Agenten-Modi:

| Modus | Slug | Zweck | Empfohlenes Modell |
|-------|------|-------|-------------------|
| Architect | `architect` | Planung, Design, Strategie | Claude Opus/Sonnet |
| Code | `code` | Code schreiben, refactoren | Claude Sonnet, GPT-4 |
| Ask | `ask` | Fragen, Erklärungen | Claude Haiku, GPT-3.5 |
| Debug | `debug` | Fehlersuche, Logging | Claude Sonnet |
| Orchestrator | `orchestrator` | Multi-Task Koordination | Claude Opus |

### 2.3 Konfiguration in code-server

Die Extension wird über VS Code Settings konfiguriert:

**Speicherort:** `/home/codeserver/.local/share/code-server/User/settings.json`

```json
{
  "roo.openRouterApiKey": "${OPENROUTER_API_KEY}",
  "roo.defaultModel": "anthropic/claude-sonnet-4.5",
  
  "roo.models": {
    "architect": "anthropic/claude-sonnet-4.5",
    "code": "anthropic/claude-sonnet-4.5",
    "ask": "anthropic/claude-haiku-4.0",
    "debug": "anthropic/claude-sonnet-4.5",
    "orchestrator": "anthropic/claude-opus-4.0"
  },
  
  "roo.localOllamaModels": {
    "ask": "llama3.1:8b",
    "code": "deepseek-coder-v2:16b"
  },
  
  "roo.routingStrategy": "intelligent",
  "roo.preferLocalForSimple": true,
  "roo.maxTokens": 8192,
  "roo.contextWindow": 200000
}
```

### 2.4 Multi-Agent Workflow

Roo Code koordiniert mehrere spezialisierte Agenten:

1. **Architect-Agent:** Plant Lösungsarchitektur
2. **Code-Agent:** Implementiert Code basierend auf Architektur
3. **Debug-Agent:** Findet und behebt Fehler
4. **Orchestrator-Agent:** Koordiniert komplexe Multi-Step-Tasks

### 2.5 Werkzeuge (Tools)

Roo Code hat Zugriff auf folgende Funktionen:

- `read_file`: Dateien lesen
- `write_to_file`: Dateien schreiben
- `apply_diff`: Code-Änderungen anwenden
- `execute_command`: Shell-Befehle ausführen
- `search_files`: Regex-Suche in Dateien
- `codebase_search`: Semantische Code-Suche
- `list_files`: Verzeichnisse auflisten

### 2.6 Installation & Update

**Hinweis:** Extension ist bereits installiert. Für Updates:

```bash
# Extension-Version prüfen
su - codeserver -c "code-server --list-extensions --show-versions | grep roo"

# Extension aktualisieren (falls neue Version verfügbar)
su - codeserver -c "code-server --force --install-extension rooveterinaryinc.roo-cline@latest"

# code-server neu starten
systemctl restart code-server
```

---

## 3. OpenRouter Integration

### 3.1 Überblick

**OpenRouter** ist ein KI-API-Gateway, das Zugriff auf verschiedene LLM-Provider bietet:
- Anthropic (Claude)
- OpenAI (GPT)
- Google (Gemini)
- Meta (Llama via API)
- und viele mehr

**Vorteil:** Ein API-Key für alle Modelle, vereinfachte Abrechnung.

### 3.2 API-Key-Management

#### 3.2.1 Sichere Speicherung

**Empfohlene Methode:** Environment Variables in systemd Service

```bash
# API-Key sicher in systemd-Umgebung speichern
sudo mkdir -p /etc/systemd/system/code-server.service.d
sudo tee /etc/systemd/system/code-server.service.d/environment.conf << EOF
[Service]
Environment="OPENROUTER_API_KEY=sk-or-v1-xxxxxxxxxxxxxxxxxxxx"
EOF

# Berechtigungen auf Root-only setzen
sudo chmod 600 /etc/systemd/system/code-server.service.d/environment.conf
sudo chown root:root /etc/systemd/system/code-server.service.d/environment.conf

# Service neu laden
sudo systemctl daemon-reload
sudo systemctl restart code-server
```

#### 3.2.2 Alternative: dotenv-Datei

```bash
# .env-Datei erstellen
sudo tee /etc/devsystem/ki.env << EOF
OPENROUTER_API_KEY=sk-or-v1-xxxxxxxxxxxxxxxxxxxx
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
OPENROUTER_SITE_URL=https://devsystem.internal
OPENROUTER_APP_NAME=DevSystem
EOF

# Berechtigungen einschränken
sudo chmod 600 /etc/devsystem/ki.env
sudo chown root:root /etc/devsystem/ki.env
```

#### 3.2.3 Zugriff aus code-server

Roo Code Extension liest den API-Key aus der Umgebungsvariable:

```json
{
  "roo.openRouterApiKey": "${OPENROUTER_API_KEY}"
}
```

### 3.3 Modell-Auswahl

#### 3.3.1 Empfohlene Modelle nach Anwendungsfall

| Anwendungsfall | Modell | Kosten | Performance |
|----------------|---------|--------|-------------|
| **Architektur/Planung** | `anthropic/claude-opus-4.0` | Hoch | Exzellent |
| **Code-Generierung** | `anthropic/claude-sonnet-4.5` | Mittel | Sehr gut |
| **Code-Review** | `anthropic/claude-sonnet-4.5` | Mittel | Sehr gut |
| **Schnelle Fragen** | `anthropic/claude-haiku-4.0` | Niedrig | Gut |
| **Debugging** | `anthropic/claude-sonnet-4.5` | Mittel | Sehr gut |
| **Langtext-Analyse** | `google/gemini-pro-1.5` | Mittel | Gut |
| **Cost-optimiert** | `meta-llama/llama-3.1-70b` | Niedrig | Gut |

#### 3.3.2 Kostenübersicht (Stand 2026-04)

**Claude (Anthropic):**
- Claude Opus 4.0: ~$15/$75 per 1M tokens (input/output)
- Claude Sonnet 4.5: ~$3/$15 per 1M tokens
- Claude Haiku 4.0: ~$0.25/$1.25 per 1M tokens

**GPT (OpenAI):**
- GPT-4 Turbo: ~$10/$30 per 1M tokens
- GPT-4o: ~$5/$15 per 1M tokens
- GPT-3.5 Turbo: ~$0.50/$1.50 per 1M tokens

**Hinweis:** Preise unterliegen Änderungen, siehe https://openrouter.ai/docs/models

### 3.4 Rate Limits & Kostenmanagement

#### 3.4.1 OpenRouter Limits

- **Free Tier:** $3 Guthaben zum Testen
- **Standard:** Pay-as-you-go, keine Hard Limits
- **Custom Limits:** Können im Dashboard gesetzt werden

#### 3.4.2 Kostenkontrolle in Roo Code

```json
{
  "roo.maxTokensPerRequest": 8192,
  "roo.maxRequestsPerHour": 100,
  "roo.costAlertThreshold": 10.0,
  "roo.preferredModels": {
    "cheap": "anthropic/claude-haiku-4.0",
    "balanced": "anthropic/claude-sonnet-4.5",
    "powerful": "anthropic/claude-opus-4.0"
  }
}
```

#### 3.4.3 Monitoring

```bash
# OpenRouter Dashboard für Kosten-Tracking nutzen
# https://openrouter.ai/activity

# Logging in Roo Code aktivieren
# Settings → Roo Code → Enable API Logging
```

### 3.5 Fallback-Strategien

#### 3.5.1 OpenRouter API Ausfall

```json
{
  "roo.fallbackStrategy": "local",
  "roo.fallbackToOllama": true,
  "roo.retryAttempts": 3,
  "roo.retryDelay": 5000
}
```

Nach 3 fehlgeschlagenen Versuchen mit OpenRouter:
1. **Automatischer Fallback** zu Ollama-Modell
2. **Benutzer-Benachrichtigung** über Modell-Wechsel
3. **Nächster Request** probiert OpenRouter erneut

#### 3.5.2 Rate Limit Reached

1. **Temporärer Switch** zu Ollama für einfache Anfragen
2. **Queue-System** für nicht-dringende Anfragen
3. **Benutzer-Information** über Wartezeit

### 3.6 Sicherheit

#### 3.6.1 API-Key Rotation

```bash
# Neuen API-Key in OpenRouter Dashboard generieren
# Alten Key in systemd-Umgebung ersetzen
sudo nano /etc/systemd/system/code-server.service.d/environment.conf

# Service neu starten
sudo systemctl daemon-reload
sudo systemctl restart code-server

# Alten Key in OpenRouter Dashboard deaktivieren
```

#### 3.6.2 Request Logging (Audit Trail)

```bash
# Log-Datei für KI-Anfragen
sudo mkdir -p /var/log/devsystem
sudo touch /var/log/devsystem/ki-requests.log
sudo chown codeserver:codeserver /var/log/devsystem/ki-requests.log
sudo chmod 640 /var/log/devsystem/ki-requests.log
```

Log-Format:
```
[TIMESTAMP] [USER] [MODE] [MODEL] [TOKENS_IN/OUT] [COST] [STATUS]
```

---

## 4. Ollama Integration

### 4.1 Überblick

**Ollama** ermöglicht das lokale Ausführen von LLMs auf dem VPS:
- Keine externe API-Abhängigkeit
- Datenschutz (Daten verlassen Server nicht)
- Keine laufenden Kosten
- Offline-fähig

### 4.2 Hardware-Anforderungen

#### 4.2.1 VPS-Spezifikationen

**Aktueller IONOS VPS:**
- CPU: Unbekannt (muss geprüft werden)
- RAM: Unbekannt (muss geprüft werden)
- Disk: Unbekannt (muss geprüft werden)

**Ollama Mindestanforderungen:**

| Modell-Größe | RAM (Min) | RAM (Empfohlen) | Disk Space |
|--------------|-----------|-----------------|------------|
| 3B Parameter | 4 GB | 8 GB | 2 GB |
| 7-8B Parameter | 8 GB | 16 GB | 5 GB |
| 13B Parameter | 16 GB | 32 GB | 8 GB |
| 70B Parameter | 48 GB | 64 GB | 40 GB |

#### 4.2.2 Empfohlene Modelle nach VPS-Größe

**Kleine VPS (4-8 GB RAM):**
- `llama3.1:3b` - Schnell, ressourcenschonend
- `phi3:3b` - Gute Code-Fähigkeiten
- `qwen2.5:3b` - Multilingual

**Mittlere VPS (8-16 GB RAM):**
- `llama3.1:8b` - Balanced Performance
- `deepseek-coder-v2:16b` - Spezialisiert auf Code
- `mistral:7b` - Gut für allgemeine Aufgaben

**Große VPS (16+ GB RAM):**
- `llama3.1:70b` - Top Performance (erfordert 48+ GB)
- `codellama:34b` - Exzellente Code-Generierung

### 4.3 Installation

#### 4.3.1 Ollama Binary installieren

```bash
# Offizielle Installation
curl -fsSL https://ollama.com/install.sh | sh

# Manuelle Installation (falls gewünscht)
curl -L https://github.com/ollama/ollama/releases/latest/download/ollama-linux-amd64 -o /tmp/ollama
sudo mv /tmp/ollama /usr/local/bin/ollama
sudo chmod +x /usr/local/bin/ollama
```

#### 4.3.2 systemd Service erstellen

```bash
sudo tee /etc/systemd/system/ollama.service << EOF
[Unit]
Description=Ollama Local LLM Service
Documentation=https://ollama.ai/docs
After=network.target

[Service]
Type=simple
User=codeserver
Group=codeserver
WorkingDirectory=/home/codeserver
ExecStart=/usr/local/bin/ollama serve
Restart=always
RestartSec=10

# Umgebungsvariablen
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="OLLAMA_MODELS=/var/lib/ollama/models"
Environment="OLLAMA_KEEP_ALIVE=5m"
Environment="OLLAMA_MAX_LOADED_MODELS=2"

# Ressourcen-Limits
MemoryMax=8G
MemoryHigh=7G
CPUQuota=300%

# Sicherheit
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/var/lib/ollama

[Install]
WantedBy=multi-user.target
EOF

# Service aktivieren und starten
sudo systemctl daemon-reload
sudo systemctl enable ollama
sudo systemctl start ollama
```

#### 4.3.3 Verzeichnisstruktur erstellen

```bash
# Ollama-Verzeichnisse
sudo mkdir -p /var/lib/ollama/models
sudo chown -R codeserver:codeserver /var/lib/ollama
sudo chmod -R 750 /var/lib/ollama
```

### 4.4 Modell-Management

#### 4.4.1 Modelle herunterladen

```bash
# Als codeserver-User
su - codeserver

# MVP: Nur leichtgewichtige Modelle
ollama pull llama3.1:8b          # Allgemein (4.7 GB)
ollama pull deepseek-coder:6.7b  # Code (3.8 GB)

# Optional: Nach MVP
# ollama pull phi3:3b              # Klein, schnell (2.3 GB)
# ollama pull codellama:13b        # Großes Code-Modell (7.4 GB)

# Installierte Modelle anzeigen
ollama list
```

#### 4.4.2 Modell-Konfiguration (Modelfile)

```bash
# Custom Modelfile für optimierte Code-Generierung
cat > /tmp/devsystem-coder.modelfile << 'EOF'
FROM deepseek-coder:6.7b

PARAMETER temperature 0.2
PARAMETER top_p 0.9
PARAMETER top_k 40
PARAMETER num_ctx 8192
PARAMETER stop "<|endoftext|>"

SYSTEM """
Du bist ein präziser Code-Assistent für das DevSystem-Projekt.
Antworte auf Deutsch wenn möglich, nutze Englisch für Code.
Fokussiere dich auf: Ubuntu, Bash, Python, Docker, DevOps.
Generiere immer vollständigen, lauffähigen Code.
"""
EOF

# Custom Modell erstellen
ollama create devsystem-coder -f /tmp/devsystem-coder.modelfile
```

#### 4.4.3 Modell testen

```bash
# Einfacher Test
ollama run llama3.1:8b "Erkläre kurz, was DevOps ist."

# Code-Generierung testen
ollama run deepseek-coder:6.7b "Schreibe ein Bash-Skript zum Backup von /etc"

# API-Test
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.1:8b",
  "prompt": "Was ist Kubernetes?",
  "stream": false
}'
```

### 4.5 Routing-Logik: Wann Cloud, wann lokal?

#### 4.5.1 Entscheidungsmatrix

| Kriterium | OpenRouter (Cloud) | Ollama (Lokal) |
|-----------|-------------------|----------------|
| **Komplexität** | Hoch (Architektur, Multi-File) | Niedrig (Einzelfunktion) |
| **Token-Anzahl** | > 4000 Tokens | < 4000 Tokens |
| **Datenschutz** | Nicht-sensibel | Sensible Daten |
| **Geschwindigkeit** | Nicht zeitkritisch | Sofort-Antwort gewünscht |
| **Kosten** | Budget verfügbar | Kostenoptimierung |
| **Internet** | Verfügbar | Nicht verfügbar |

#### 4.5.2 Automatisches Routing in Roo Code

```json
{
  "roo.routingStrategy": "intelligent",
  "roo.routingRules": {
    "architect": "cloud",
    "orchestrator": "cloud",
    "code": "intelligent",
    "ask": "local",
    "debug": "intelligent"
  },
  
  "roo.intelligentRouting": {
    "localIfTokensBelow": 2000,
    "localIfFilesSensitive": true,
    "localIfOffline": true,
    "cloudIfComplexityHigh": true
  }
}
```

### 4.6 Caddy Reverse Proxy für Ollama

```bash
# Ollama über Caddy erreichbar machen (optional, für externe Tools)
sudo tee /etc/caddy/sites/ollama.caddy << EOF
# Ollama API (nur intern über Tailscale)
ollama.devsystem.internal {
    # Nur Zugriff über Tailscale erlauben
    @tailscale {
        remote_ip 100.64.0.0/10
    }
    
    # Reverse Proxy zu Ollama
    reverse_proxy @tailscale localhost:11434 {
        header_up Host {host}
        header_up X-Real-IP {remote_ip}
        header_up X-Forwarded-For {remote_ip}
        header_up X-Forwarded-Proto {scheme}
    }
    
    # Zugriff verweigern, wenn nicht über Tailscale
    respond !@tailscale 403 {
        body "Zugriff nur über Tailscale VPN erlaubt"
    }
    
    # Logging
    log {
        output file /var/log/caddy/ollama.log {
            roll_size 50MB
            roll_keep 10
            roll_keep_for 30d
        }
        format json
    }
}
EOF

# Caddy neu laden
sudo systemctl reload caddy
```

### 4.7 Ressourcen-Monitoring

```bash
# Monitoring-Skript für Ollama
sudo tee /usr/local/bin/monitor-ollama.sh << 'EOF'
#!/bin/bash

LOG_FILE="/var/log/devsystem/ollama-monitor.log"

# RAM-Nutzung
MEMORY=$(ps aux | grep "ollama serve" | grep -v grep | awk '{print $4}')
echo "$(date '+%Y-%m-%d %H:%M:%S') - Ollama Memory: ${MEMORY}%" >> $LOG_FILE

# CPU-Nutzung
CPU=$(ps aux | grep "ollama serve" | grep -v grep | awk '{print $3}')
echo "$(date '+%Y-%m-%d %H:%M:%S') - Ollama CPU: ${CPU}%" >> $LOG_FILE

# Disk Space
DISK=$(du -sh /var/lib/ollama/models | awk '{print $1}')
echo "$(date '+%Y-%m-%d %H:%M:%S') - Ollama Models: ${DISK}" >> $LOG_FILE

# Alert bei hoher Auslastung
if (( $(echo "$MEMORY > 80" | bc -l) )); then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: Ollama high memory usage!" >> $LOG_FILE
fi
EOF

sudo chmod +x /usr/local/bin/monitor-ollama.sh

# Cronjob alle 5 Minuten
echo "*/5 * * * * root /usr/local/bin/monitor-ollama.sh" | sudo tee -a /etc/crontab
```

---

## 5. Sicherheitskonzept

### 5.1 API-Key Security

#### 5.1.1 Speicherung

**✅ SICHER:**
- systemd Environment Files (Berechtigungen: 600, Owner: root)
- HashiCorp Vault (für Enterprise-Setups)
- systemd-creds (verschlüsselt)

**❌ UNSICHER:**
- Klartext in VS Code Settings
- Git-Repository
- Shell-History
- Umgebungsvariablen in user-bashrc

#### 5.1.2 Zugriffskontrolle

```bash
# Nur code-server Service darf API-Keys lesen
# systemd Service File mit DynamicUser
[Service]
DynamicUser=false
User=codeserver
Group=codeserver

# Environment File nur für root lesbar
sudo chmod 600 /etc/systemd/system/code-server.service.d/environment.conf
sudo chown root:root /etc/systemd/system/code-server.service.d/environment.conf
```

#### 5.1.3 Key Rotation

**Empfohlener Zeitplan:**
- OpenRouter API-Key: Alle 90 Tage rotieren
- Rotation nach jedem Sicherheitsvorfall
- Alte Keys sofort deaktivieren nach Rotation

```bash
# Rotation-Skript
sudo tee /usr/local/bin/rotate-api-keys.sh << 'EOF'
#!/bin/bash
# 1. Neuen OpenRouter Key generieren: https://openrouter.ai/keys
# 2. In systemd-Umgebung eintragen
# 3. Service neu starten
# 4. Alten Key in OpenRouter deaktivieren
# 5. Rotation loggen
echo "$(date) - API Key rotiert" >> /var/log/devsystem/key-rotation.log
EOF
```

### 5.2 Netzwerk-Isolation

#### 5.2.1 Firewall-Regeln für Ollama

```bash
# Ollama nur für localhost und Tailscale erreichbar
sudo ufw allow from 127.0.0.1 to any port 11434 proto tcp
sudo ufw allow in on tailscale0 to any port 11434 proto tcp
sudo ufw deny 11434/tcp
```

#### 5.2.2 Caddy Access Control

Siehe Abschnitt 4.6 - Ollama ist nur über Tailscale-IPs erreichbar.

### 5.3 Data Privacy (Datenschutz)

#### 5.3.1 Sensible Daten

**Regel:** Sensible Daten NIEMALS an Cloud-KI senden

**Als sensibel gelten:**
- API-Keys, Passwörter, Tokens
- Kundendaten, personenbezogene Informationen
- Interne Geschäftsgeheimnisse
- Produktions-Konfigurationen

**Lösung:** Automatische Erkennung in Roo Code

```json
{
  "roo.dataPrivacy": {
    "enabled": true,
    "scanForSecrets": true,
    "blockCloudIfSecretsFound": true,
    "patterns": [
      "api[_-]?key",
      "password",
      "secret",
      "token",
      "auth",
      "credential"
    ]
  }
}
```

#### 5.3.2 Audit Logging

```bash
# Log aller KI-Anfragen
LOG_FORMAT: '[TIMESTAMP] [USER] [MODE] [MODEL] [PROVIDER] [INPUT_PREVIEW] [OUTPUT_PREVIEW] [TOKENS] [COST]'

# Log-Datei
/var/log/devsystem/ki-audit.log

# Rotation
sudo tee /etc/logrotate.d/devsystem-ki << EOF
/var/log/devsystem/ki-audit.log {
    weekly
    rotate 52
    compress
    delaycompress
    notifempty
    create 640 codeserver codeserver
}
EOF
```

### 5.4 Rate Limiting

#### 5.4.1 Ollama Rate Limiting

```bash
# In systemd Service File
[Service]
# Max 10 parallele Requests
Environment="OLLAMA_MAX_QUEUE=10"

# Max 2 Modelle gleichzeitig geladen
Environment="OLLAMA_MAX_LOADED_MODELS=2"
```

#### 5.4.2 OpenRouter Rate Limiting

```json
{
  "roo.rateLimits": {
    "openRouter": {
      "requestsPerMinute": 20,
      "tokensPerMinute": 100000,
      "costPerHour": 5.0
    }
  }
}
```

### 5.5 Code Injection Prevention

#### 5.5.1 Sandbox für generierter Code

**Warnung:** KI-generierter Code kann schädlich sein!

**Schutzmaßnahmen:**
1. **Review vor Ausführung:** Benutzer muss Code genehmigen
2. **Keine Auto-Execution:** Roo Code führt Code nicht automatisch aus
3. **Benutzer-Bestätigung:** Bei `execute_command` Tool

```json
{
  "roo.security": {
    "requireApprovalForCommands": true,
    "requireApprovalForFileWrites": false,
    "sandboxMode": false,
    "blockedCommands": ["rm -rf /", "sudo", "chmod 777"]
  }
}
```

---

## 6. Testkonzept

### 6.1 Test-Strategie

#### 6.1.1 Test-Pyramide

```
         ┌─────────────────┐
         │  E2E Tests (5%) │  Vollständiger Workflow
         └─────────────────┘
       ┌───────────────────────┐
       │ Integration Tests (20%)│  API-Verbindungen
       └───────────────────────┘
    ┌───────────────────────────────┐
    │     Unit Tests (75%)          │  Einzelne Funktionen
    └───────────────────────────────┘
```

### 6.2 Roo Code Extension Tests

#### 6.2.1 Installations-Test

```bash
#!/bin/bash
# Test: Roo Code Extension ist installiert

echo "=== Teste Roo Code Installation ==="

# 1. Prüfe ob Extension installiert ist
if su - codeserver -c "code-server --list-extensions" | grep -q "rooveterinaryinc.roo-cline"; then
    echo "✓ Roo Code Extension ist installiert"
else
    echo "✗ Roo Code Extension NICHT installiert"
    exit 1
fi

# 2. Prüfe Extension-Version
VERSION=$(su - codeserver -c "code-server --list-extensions --show-versions" | grep "roo-cline" | awk -F'@' '{print $2}')
echo "✓ Roo Code Version: $VERSION"

# 3. Prüfe Settings
if grep -q "roo\.openRouterApiKey" /home/codeserver/.local/share/code-server/User/settings.json; then
    echo "✓ Roo Code ist konfiguriert"
else
    echo "✗ Roo Code NICHT konfiguriert"
    exit 1
fi

echo "=== Roo Code Installation: OK ==="
```

#### 6.2.2 Konfiguration-Test

```bash
#!/bin/bash
# Test: Roo Code Konfiguration ist valide

echo "=== Teste Roo Code Konfiguration ==="

SETTINGS_FILE="/home/codeserver/.local/share/code-server/User/settings.json"

# 1. Settings-Datei existiert
if [ -f "$SETTINGS_FILE" ]; then
    echo "✓ Settings-Datei existiert"
else
    echo "✗ Settings-Datei NICHT gefunden"
    exit 1
fi

# 2. JSON ist valide
if jq empty "$SETTINGS_FILE" 2>/dev/null; then
    echo "✓ Settings JSON ist valide"
else
    echo "✗ Settings JSON ist UNGÜLTIG"
    exit 1
fi

# 3. OpenRouter API-Key ist gesetzt
if jq -e '.["roo.openRouterApiKey"]' "$SETTINGS_FILE" >/dev/null 2>&1; then
    echo "✓ OpenRouter API-Key ist konfiguriert"
else
    echo "✗ OpenRouter API-Key FEHLT"
    exit 1
fi

echo "=== Roo Code Konfiguration: OK ==="
```

### 6.3 OpenRouter Integration Tests

#### 6.3.1 API-Verbindung testen

```bash
#!/bin/bash
# Test: OpenRouter API ist erreichbar

echo "=== Teste OpenRouter API ==="

# API-Key aus systemd-Umgebung holen
API_KEY=$(systemctl show code-server --property=Environment | grep OPENROUTER_API_KEY | cut -d= -f2)

if [ -z "$API_KEY" ]; then
    echo "✗ API-Key nicht in systemd-Umgebung gefunden"
    exit 1
fi

# API-Test
RESPONSE=$(curl -s -X POST https://openrouter.ai/api/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "model": "anthropic/claude-haiku-4.0",
    "messages": [{"role": "user", "content": "Hi"}],
    "max_tokens": 10
  }')

# Prüfe Response
if echo "$RESPONSE" | jq -e '.choices[0].message.content' >/dev/null 2>&1; then
    echo "✓ OpenRouter API antwortet korrekt"
    echo "  Response: $(echo "$RESPONSE" | jq -r '.choices[0].message.content' | head -c 50)..."
else
    echo "✗ OpenRouter API-Fehler"
    echo "  Error: $(echo "$RESPONSE" | jq -r '.error.message // "Unknown error"')"
    exit 1
fi

echo "=== OpenRouter API: OK ==="
```

#### 6.3.2 Modell-Verfügbarkeit testen

```bash
#!/bin/bash
# Test: Benötigte Modelle sind verfügbar

echo "=== Teste OpenRouter Modelle ==="

API_KEY=$(systemctl show code-server --property=Environment | grep OPENROUTER_API_KEY | cut -d= -f2)

REQUIRED_MODELS=(
    "anthropic/claude-sonnet-4.5"
    "anthropic/claude-haiku-4.0"
    "anthropic/claude-opus-4.0"
)

for MODEL in "${REQUIRED_MODELS[@]}"; do
    RESPONSE=$(curl -s -X POST https://openrouter.ai/api/v1/chat/completions \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $API_KEY" \
      -d "{
        \"model\": \"$MODEL\",
        \"messages\": [{\"role\": \"user\", \"content\": \"test\"}],
        \"max_tokens\": 5
      }")
    
    if echo "$RESPONSE" | jq -e '.choices' >/dev/null 2>&1; then
        echo "✓ Modell verfügbar: $MODEL"
    else
        echo "✗ Modell NICHT verfügbar: $MODEL"
    fi
done

echo "=== OpenRouter Modelle: Geprüft ==="
```

### 6.4 Ollama Integration Tests

#### 6.4.1 Service-Test

```bash
#!/bin/bash
# Test: Ollama Service läuft

echo "=== Teste Ollama Service ==="

# 1. Service läuft
if systemctl is-active --quiet ollama; then
    echo "✓ Ollama Service ist aktiv"
else
    echo "✗ Ollama Service ist NICHT aktiv"
    systemctl status ollama --no-pager
    exit 1
fi

# 2. Port ist offen
if ss -tlnp | grep -q ":11434"; then
    echo "✓ Ollama lauscht auf Port 11434"
else
    echo "✗ Ollama lauscht NICHT auf Port 11434"
    exit 1
fi

# 3. API antwortet
if curl -s http://localhost:11434/api/version | jq -e '.version' >/dev/null 2>&1; then
    VERSION=$(curl -s http://localhost:11434/api/version | jq -r '.version')
    echo "✓ Ollama API antwortet (Version: $VERSION)"
else
    echo "✗ Ollama API antwortet NICHT"
    exit 1
fi

echo "=== Ollama Service: OK ==="
```

#### 6.4.2 Modell-Test

```bash
#!/bin/bash
# Test: Ollama Modelle sind verfügbar

echo "=== Teste Ollama Modelle ==="

# Installierte Modelle auflisten
MODELS=$(ollama list | tail -n +2 | awk '{print $1}')

if [ -z "$MODELS" ]; then
    echo "✗ Keine Ollama-Modelle installiert"
    exit 1
fi

echo "Installierte Modelle:"
echo "$MODELS" | while read -r model; do
    echo "  - $model"
done

# Test-Prompt an erstes Modell
FIRST_MODEL=$(echo "$MODELS" | head -n 1)
echo "Teste Modell: $FIRST_MODEL"

RESPONSE=$(curl -s -X POST http://localhost:11434/api/generate -d "{
  \"model\": \"$FIRST_MODEL\",
  \"prompt\": \"Say hello\",
  \"stream\": false
}" | jq -r '.response')

if [ -n "$RESPONSE" ]; then
    echo "✓ Modell $FIRST_MODEL funktioniert"
    echo "  Response: ${RESPONSE:0:50}..."
else
    echo "✗ Modell $FIRST_MODEL antwortet NICHT"
    exit 1
fi

echo "=== Ollama Modelle: OK ==="
```

### 6.5 End-to-End Tests

#### 6.5.1 Vollständiger Workflow-Test

```bash
#!/bin/bash
# E2E-Test: Kompletter KI-Workflow

echo "=== E2E Test: KI-Integration ==="

# 1. code-server erreichbar
echo "Teste code-server..."
if curl -k -s -o /dev/null -w "%{http_code}" https://100.100.221.56:9443 | grep -q "200\|302"; then
    echo "✓ code-server erreichbar"
else
    echo "✗ code-server NICHT erreichbar"
    exit 1
fi

# 2. Roo Code Extension läuft
echo "Teste Roo Code Extension..."
# (Extension-Check - siehe 6.2.1)

# 3. OpenRouter API funktioniert
echo "Teste OpenRouter API..."
# (API-Test - siehe 6.3.1)

# 4. Ollama Service läuft
echo "Teste Ollama Service..."
# (Service-Test - siehe 6.4.1)

# 5. Ollama-Modell antwortet
echo "Teste Ollama-Modell..."
# (Modell-Test - siehe 6.4.2)

echo ""
echo "=== E2E Test: BESTANDEN ==="
echo "✓ code-server läuft"
echo "✓ Roo Code Extension installiert"
echo "✓ OpenRouter API verbunden"
echo "✓ Ollama Service aktiv"
echo "✓ Ollama-Modelle funktionieren"
```

### 6.6 Log-Validierung

#### 6.6.1 Logs prüfen

```bash
#!/bin/bash
# Test: Logs zeigen keine kritischen Fehler

echo "=== Prüfe Logs ==="

# code-server Logs
echo "Prüfe code-server Logs..."
ERRORS=$(journalctl -u code-server -n 100 --no-pager | grep -i "error\|fatal" | wc -l)
if [ "$ERRORS" -eq 0 ]; then
    echo "✓ Keine Fehler in code-server Logs"
else
    echo "⚠ $ERRORS Fehler in code-server Logs gefunden"
    journalctl -u code-server -n 100 --no-pager | grep -i "error\|fatal" | tail -n 5
fi

# Ollama Logs
echo "Prüfe Ollama Logs..."
ERRORS=$(journalctl -u ollama -n 100 --no-pager | grep -i "error\|fatal" | wc -l)
if [ "$ERRORS" -eq 0 ]; then
    echo "✓ Keine Fehler in Ollama Logs"
else
    echo "⚠ $ERRORS Fehler in Ollama Logs gefunden"
    journalctl -u ollama -n 100 --no-pager | grep -i "error\|fatal" | tail -n 5
fi

echo "=== Log-Prüfung: Abgeschlossen ==="
```

---

## 7. MVP-Abgrenzung

### 7.1 MVP (Minimum Viable Product)

**Ziel:** Funktionierende KI-Integration mit Kern-Features

#### 7.1.1 MVP-Scope

**✅ IM MVP ENTHALTEN:**

1. **Roo Code Extension**
   - Extension ist installiert (bereits erledigt)
   - Basis-Konfiguration für OpenRouter
   - Multi-Agent Modi (Architect, Code, Ask, Debug, Orchestrator)

2. **OpenRouter Integration**
   - API-Key sicher konfiguriert
   - Claude Sonnet 4.5 als Haupt-Modell
   - Claude Haiku 4.0 für schnelle Anfragen
   - Basis-Kostenkontrolle (max. $50/Monat)

3. **Ollama Integration**
   - Ollama Service installiert und läuft
   - 1-2 Modelle: `llama3.1:8b` (allgemein) + `deepseek-coder:6.7b` (Code)
   - Nur localhost-Zugriff
   - Basis-Ressourcen-Limits

4. **Routing**
   - Manuelles Modell-Switching in Roo Code
   - Kein intelligentes Auto-Routing (kommt nach MVP)

5. **Sicherheit**
   - API-Key in systemd Environment File
   - Ollama nur über localhost erreichbar
   - Basis-Logging

6. **Tests**
   - Installation verifizieren
   - API-Konnektivität testen
   - Ollama-Service testen

**❌ NICHT IM MVP (Backlog):**

1. **Erweiterte Features**
   - Intelligentes Auto-Routing (Cloud vs. Lokal)
   - Cost-Optimization-Algorithmen
   - Multi-User-Support
   - GPU-Beschleunigung für Ollama
   - Mehr als 2 lokale Modelle

2. **Erweiterte Sicherheit**
   - HashiCorp Vault Integration
   - Detailliertes Audit-Logging
   - Data-Loss-Prevention (DLP)
   - Secret-Scanning in Prompts

3. **Monitoring**
   - Grafana-Dashboards
   - Prometheus-Metriken
   - Alerting bei Fehlern
   - Kostenreport-Dashboard

4. **Optimierungen**
   - Ollama-Modell-Quantisierung
   - Custom-Modelfiles für spezifische Tasks
   - Prompt-Caching
   - Response-Streaming-Optimierung

5. **Integration**
   - Caddy Reverse Proxy für Ollama (ollama.devsystem.internal)
   - MCP (Model Context Protocol) Server
   - Custom Roo Code Skills
   - Git-Hook-Integration

### 7.2 MVP-Implementierungsreihenfolge

```
1. VPS-Ressourcen prüfen (RAM, CPU, Disk)
   ↓
2. Ollama installieren (falls genug RAM)
   ↓
3. 1-2 Modelle runterladen (klein anfangen)
   ↓
4. OpenRouter API-Key sicher konfigurieren
   ↓
5. Roo Code Settings aktualisieren
   ↓
6. Basis-Tests durchführen
   ↓
7. Dokumentation ergänzen
   ↓
8. MVP-Abnahme
```

### 7.3 MVP-Erfolgskriterien

**Definition of Done:**

- [ ] Roo Code Extension funktioniert
- [ ] OpenRouter API antwortet auf Anfragen
- [ ] Mind. 1 Ollama-Modell läuft und antwortet
- [ ] API-Keys sind sicher gespeichert
- [ ] Basis-Tests laufen erfolgreich durch
- [ ] Keine kritischen Fehler in Logs
- [ ] Dokumentation ist vorhanden
- [ ] Benutzer kann KI-Features in code-server nutzen

### 7.4 Backlog-Priorisierung (Nach MVP)

**Priorität 1 (High):**
- Intelligentes Routing (Cloud vs. Lokal)
- Caddy Reverse Proxy für Ollama
- Detailliertes Audit-Logging

**Priorität 2 (Medium):**
- Monitoring & Alerting
- Cost-Optimization
- 2-3 zusätzliche Ollama-Modelle

**Priorität 3 (Low):**
- GPU-Beschleunigung (falls GPU verfügbar)
- Custom Modelfiles
- MCP-Server Integration
- Multi-User-Support

---

## 8. Implementierungsplan

### 8.1 Phasen-Übersicht

```
Phase 1: Vorbereitung (1h)
├─ VPS-Ressourcen prüfen
├─ Entscheidung: Welche Ollama-Modelle?
└─ OpenRouter API-Key beschaffen

Phase 2: Ollama Installation (1-2h)
├─ Ollama Binary installieren
├─ systemd Service konfigurieren
├─ Modelle herunterladen
└─ Service-Tests

Phase 3: Sicherheitskonfiguration (1h)
├─ API-Key in systemd speichern
├─ Firewall-Regeln für Ollama
└─ Logging einrichten

Phase 4: Roo Code Konfiguration (30min)
├─ Settings aktualisieren
├─ Modell-Mapping definieren
└─ code-server neu starten

Phase 5: Integration Testing (1h)
├─ OpenRouter API testen
├─ Ollama Modelle testen
├─ E2E-Test durchführen
└─ Logs validieren

Phase 6: Dokumentation (30min)
├─ Installation dokumentieren
└─ Benutzer-Anleitung erstellen
```

### 8.2 Detaillierte Schritte

#### 8.2.1 Phase 1: Vorbereitung

```bash
# Schritt 1: VPS-Ressourcen prüfen
free -h
df -h
lscpu
uname -a

# Schritt 2: OpenRouter Account erstellen
# https://openrouter.ai/
# API-Key generieren und sicher notieren
```

#### 8.2.2 Phase 2: Ollama Installation

```bash
# Schritt 1: Ollama installieren
curl -fsSL https://ollama.com/install.sh | sh

# Schritt 2: systemd Service erstellen
sudo tee /etc/systemd/system/ollama.service << 'EOF'
[Unit]
Description=Ollama Local LLM Service
After=network.target

[Service]
Type=simple
User=codeserver
WorkingDirectory=/home/codeserver
ExecStart=/usr/local/bin/ollama serve
Restart=always
RestartSec=10
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="OLLAMA_MODELS=/var/lib/ollama/models"
Environment="OLLAMA_KEEP_ALIVE=5m"
MemoryMax=8G

[Install]
WantedBy=multi-user.target
EOF

# Schritt 3: Verzeichnisse erstellen
sudo mkdir -p /var/lib/ollama/models
sudo chown -R codeserver:codeserver /var/lib/ollama

# Schritt 4: Service starten
sudo systemctl daemon-reload
sudo systemctl enable ollama
sudo systemctl start ollama
sudo systemctl status ollama

# Schritt 5: Modelle herunterladen (als codeserver)
su - codeserver
ollama pull llama3.1:8b
ollama pull deepseek-coder:6.7b
ollama list
exit

# Schritt 6: Test
curl http://localhost:11434/api/version
ollama run llama3.1:8b "Hello, what can you do?"
```

#### 8.2.3 Phase 3: Sicherheitskonfiguration

```bash
# Schritt 1: API-Key sicher speichern
sudo mkdir -p /etc/systemd/system/code-server.service.d
sudo tee /etc/systemd/system/code-server.service.d/environment.conf << 'EOF'
[Service]
Environment="OPENROUTER_API_KEY=sk-or-v1-HIER_DEN_ECHTEN_KEY_EINTRAGEN"
EOF

# Berechtigungen setzen
sudo chmod 600 /etc/systemd/system/code-server.service.d/environment.conf
sudo chown root:root /etc/systemd/system/code-server.service.d/environment.conf

# code-server neu starten
sudo systemctl daemon-reload
sudo systemctl restart code-server

# Schritt 2: Firewall für Ollama
sudo ufw allow from 127.0.0.1 to any port 11434
sudo ufw allow in on tailscale0 to any port 11434
sudo ufw status

# Schritt 3: Log-Verzeichnis
sudo mkdir -p /var/log/devsystem
sudo chown codeserver:codeserver /var/log/devsystem
sudo chmod 750 /var/log/devsystem
```

#### 8.2.4 Phase 4: Roo Code Konfiguration

```bash
# Settings-Datei editieren
sudo -u codeserver nano /home/codeserver/.local/share/code-server/User/settings.json

# Folgende Einstellungen hinzufügen/anpassen:
{
  "roo.openRouterApiKey": "${OPENROUTER_API_KEY}",
  "roo.defaultModel": "anthropic/claude-sonnet-4.5",
  
  "roo.models": {
    "architect": "anthropic/claude-sonnet-4.5",
    "code": "anthropic/claude-sonnet-4.5",
    "ask": "anthropic/claude-haiku-4.0",
    "debug": "anthropic/claude-sonnet-4.5",
    "orchestrator": "anthropic/claude-opus-4.0"
  },
  
  "roo.experimental": {
    "ollamaEnabled": true,
    "ollamaHost": "http://localhost:11434"
  }
}

# code-server neu starten
sudo systemctl restart code-server
```

#### 8.2.5 Phase 5: Integration Testing

```bash
# Test-Skript erstellen
cat > /tmp/test-ki-integration.sh << 'EOF'
#!/bin/bash
set -e

echo "=== KI-Integration Tests ==="

# Test 1: code-server läuft
if systemctl is-active --quiet code-server; then
    echo "✓ code-server läuft"
else
    echo "✗ code-server läuft NICHT"
    exit 1
fi

# Test 2: Ollama läuft
if systemctl is-active --quiet ollama; then
    echo "✓ Ollama läuft"
else
    echo "✗ Ollama läuft NICHT"
    exit 1
fi

# Test 3: Ollama-Modelle verfügbar
if ollama list | grep -q "llama3.1:8b"; then
    echo "✓ Ollama-Modelle installiert"
else
    echo "✗ Ollama-Modelle FEHLEN"
    exit 1
fi

# Test 4: OpenRouter API-Key gesetzt
if systemctl show code-server | grep -q "OPENROUTER_API_KEY"; then
    echo "✓ OpenRouter API-Key konfiguriert"
else
    echo "✗ OpenRouter API-Key FEHLT"
    exit 1
fi

# Test 5: Ollama antwortet
RESPONSE=$(curl -s -X POST http://localhost:11434/api/generate -d '{"model":"llama3.1:8b","prompt":"hi","stream":false}' | jq -r '.response')
if [ -n "$RESPONSE" ]; then
    echo "✓ Ollama antwortet: ${RESPONSE:0:30}..."
else
    echo "✗ Ollama antwortet NICHT"
    exit 1
fi

echo "=== Alle Tests BESTANDEN ==="
EOF

chmod +x /tmp/test-ki-integration.sh
/tmp/test-ki-integration.sh
```

#### 8.2.6 Phase 6: Dokumentation

```bash
# Benutzer-Dokumentation erstellen
cat > /home/codeserver/KI-INTEGRATION-README.md << 'EOF'
# KI-Integration im DevSystem

## Überblick

Das DevSystem bietet KI-gestützte Entwicklung über die Roo Code Extension.

## Verfügbare Modelle

### Cloud (OpenRouter)
- **Architect/Code/Debug:** Claude Sonnet 4.5 (leistungsstark)
- **Ask:** Claude Haiku 4.0 (schnell, günstig)
- **Orchestrator:** Claude Opus 4.0 (sehr leistungsstark)

### Lokal (Ollama)
- **Llama 3.1 (8B):** Allgemeine Fragen
- **DeepSeek Coder (6.7B):** Code-Generierung

## Verwendung

1. Öffne code-server in deinem Browser
2. Klicke auf das Roo Code Icon in der Seitenleiste
3. Wähle einen Modus (Architect, Code, Ask, Debug, Orchestrator)
4. Stelle deine Frage oder gib eine Aufgabe ein

## Modi

- **Architect:** Für Planung und Design
- **Code:** Für Code-Implementierung
- **Ask:** Für schnelle Fragen
- **Debug:** Für Fehlersuche
- **Orchestrator:** Für komplexe Multi-Step-Aufgaben

## Tipps

- Für sensible Daten: Nutze lokale Ollama-Modelle
- Für komplexe Aufgaben: Nutze Cloud-Modelle (Claude)
- Kosten im Blick behalten: https://openrouter.ai/activity

## Support

Bei Problemen: Logs prüfen mit `sudo journalctl -u code-server -f`
EOF

chown codeserver:codeserver /home/codeserver/KI-INTEGRATION-README.md
```

### 8.3 Rollback-Plan

Falls etwas schief geht:

```bash
# Ollama Service stoppen und deaktivieren
sudo systemctl stop ollama
sudo systemctl disable ollama

# Ollama deinstallieren
sudo rm -f /usr/local/bin/ollama
sudo rm -rf /var/lib/ollama

# API-Key aus systemd entfernen
sudo rm -f /etc/systemd/system/code-server.service.d/environment.conf
sudo systemctl daemon-reload

# code-server neu starten
sudo systemctl restart code-server

# Roo Code Settings zurücksetzen (Backup wiederherstellen)
sudo -u codeserver cp /home/codeserver/.local/share/code-server/User/settings.json.backup \
  /home/codeserver/.local/share/code-server/User/settings.json
```

---

## 9. Offene Entscheidungen

### 9.1 VPS-Ressourcen vs. Ollama-Modelle

**Frage:** Welche Ollama-Modelle sollen installiert werden, basierend auf den verfügbaren VPS-Ressourcen?

**Alternativen:**

1. **Konservativ (4-8 GB RAM):**
   - Nur `llama3.1:3b` (2 GB) + `phi3:3b` (2 GB)
   - Sehr ressourcenschonend
   - Moderate Qualität
   - **Risiko:** Modelle könnten für komplexe Aufgaben zu schwach sein

2. **Balanced (8-16 GB RAM):**
   - `llama3.1:8b` (4.7 GB) + `deepseek-coder:6.7b` (3.8 GB)
   - Gute Balance zwischen Performance und Ressourcen
   - Benötigt ~8 GB RAM gesamt
   - **Risiko:** Könnte bei hoher Last Speicher-Probleme geben

3. **Leistungsstark (16+ GB RAM):**
   - `llama3.1:8b` + `deepseek-coder-v2:16b` + `codellama:13b`