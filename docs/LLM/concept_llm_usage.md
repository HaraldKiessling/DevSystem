# LLM-Integration: Konzept & Konfiguration für DevSystem

**Version:** 1.0  
**Datum:** 2026-05-31  
**Status:** Konzept  
**Gültig für:** Zoo Code (VS Code Extension) & OpenClaw

---

## 1. Übersicht

Das DevSystem stellt eine mehrstufige LLM-Infrastruktur bereit, die je nach Anforderung zwischen lokalen und Cloud-basierten Modellen wählt. Die Orchestrierung erfolgt über **Zoo Code** (ehemals Roo Code) als VS Code Extension in code-server sowie über **OpenClaw** für terminalbasierte KI-Interaktion.

### 1.1 Verfügbare Provider

| Provider                      | Typ           | Zugriff                        | Kosten      | Latenz  |
| ----------------------------- | ------------- | ------------------------------ | ----------- | ------- |
| **Lokales Ollama** (VPS)      | Local         | `http://localhost:11434`       | Keine       | Niedrig |
| **Cloud Ollama** (ollama.com) | Cloud         | `https://ollama.com/api/tags`  | Pay-per-use | Mittel  |
| **OpenRouter**                | Cloud-Gateway | `https://openrouter.ai/api/v1` | Pay-per-use | Mittel  |

### 1.2 Architektur-Übersicht

```
┌───────────────────────────────────────────────��──────────────┐
│                    Zoo Code Extension (VS Code)               │
│  ┌──────────────┐  ┌──────────────────┐  ┌───────────────┐  │
│  │ Ollama Local │  │ Hybrid (Ollama +  │  │ Ollama Cloud  │  │
│  │   🦙 Mode    │  │   OpenRouter) 🔀  │  │   General ☁️   │  │
│  └──────┬───────┘  └────────┬─────────┘  └───────┬───────┘  │
│         │                   │                    │           │
│         ▼                   ▼                    ▼           │
│  localhost:11434    localhost:11434        api.openrouter.ai │
│  (qwen2.5-coder)    + api.openrouter.ai   ollama.com/api     │
│                     (Claude Sonnet 4.6)   (deepseek-v4)      │
└──────────────────────────────────────────────────────────────┘
```

---

## 2. Zoo Code – Custom Modes

Zoo Code nutzt drei spezialisierte Modi für unterschiedliche Einsatzszenarien. Die Konfiguration erfolgt in [`custom_modes.yaml`](../../.local/share/code-server/User/globalStorage/zoocodeorganization.zoo-code/settings/custom_modes.yaml).

### 2.1 🦙 Ollama Local

**Zweck:** Ausschließlich lokale Modelle – datenschutzfreundlich, keine Cloud-Abhängigkeit.

| Eigenschaft          | Wert                              |
| -------------------- | --------------------------------- |
| **Code-Modell**      | `qwen2.5-coder:7b`                |
| **Allgemein-Modell** | `qwen2.5:3b`                      |
| **Embeddings**       | `nomic-embed-text`                |
| **Ollama-URL**       | `http://localhost:11434`          |
| **Gruppen**          | read, edit, browser, command, mcp |

**Einsatzszenarien:**

- Vertrauliche Code-Reviews
- Einfache Syntax-Korrekturen
- Lokale Entwicklung ohne Internet
- Datenschutzsensitive Aufgaben

### 2.2 🔀 Hybrid (Ollama + OpenRouter)

**Zweck:** Intelligente Kombination aus lokalen und Cloud-Modellen – optimiert nach Kosten, Geschwindigkeit und Qualität.

| Eigenschaft           | Wert                                         |
| --------------------- | -------------------------------------------- |
| **Lokal (einfach)**   | `qwen2.5-coder:7b` / `qwen2.5:3b`            |
| **Cloud (komplex)**   | `anthropic/claude-sonnet-4.6` via OpenRouter |
| **Routing-Strategie** | Automatisch nach Aufgabentyp                 |
| **Gruppen**           | read, edit, browser, command, mcp            |

**Routing-Logik:**

| Aufgabe                               | Modell                        |
| ------------------------------------- | ----------------------------- |
| Einfache Code-Snippets, Syntax        | → Lokal (`qwen2.5-coder:7b`)  |
| Kurze Erklärungen, Fragen             | → Lokal (`qwen2.5:3b`)        |
| Bash/YAML/Python Boilerplate          | → Lokal (`qwen2.5-coder:7b`)  |
| Datenschutzsensitive Aufgaben         | → Lokal (Ollama)              |
| Komplexe Architektur-Entscheidungen   | → Cloud (`claude-sonnet-4.6`) |
| Große Codebase-Analysen (>500 Zeilen) | → Cloud (`claude-sonnet-4.6`) |
| Multi-Step Reasoning & Planung        | → Cloud (`claude-sonnet-4.6`) |
| Debugging komplexer Fehler            | → Cloud (`claude-sonnet-4.6`) |
| Dokumentation & technisches Schreiben | → Cloud (`claude-sonnet-4.6`) |

### 2.3 ☁️ Ollama Cloud General

**Zweck:** Cloud-basierte Modelle über ollama.com API – leistungsstark ohne lokale Ressourcen.

| Eigenschaft           | Wert                          |
| --------------------- | ----------------------------- |
| **Primäres Modell**   | `deepseek-v4-pro`             |
| **API-Endpunkt**      | `https://ollama.com/api/tags` |
| **Authentifizierung** | API-Key (`OLLAMA_API_KEY`)    |

---

## 3. OpenClaw – Terminal-basierte KI

OpenClaw ist ein CLI-Tool für KI-gestützte Entwicklung direkt im Terminal. Es nutzt dieselbe Infrastruktur wie Zoo Code, jedoch ohne VS Code-Abhängigkeit.

### 3.1 Konfiguration

Die OpenClaw-Konfiguration erfolgt über Umgebungsvariablen oder eine `.env`-Datei im Projektverzeichnis.

```bash
# ~/.openclaw/config.env
# Lokales Ollama
OLLAMA_HOST=http://localhost:11434
OLLAMA_MODEL=qwen2.5-coder:7b

# OpenRouter (optional)
OPENROUTER_API_KEY=sk-or-v1-...
OPENROUTER_MODEL=anthropic/claude-sonnet-4.6

# Cloud Ollama (optional)
OLLAMA_API_KEY=...
OLLAMA_CLOUD_MODEL=deepseek-v4-pro
```

### 3.2 Verwendung

```bash
# Mit lokalem Ollama
openclaw --provider ollama "Erkläre diese Funktion"

# Mit OpenRouter
openclaw --provider openrouter --model anthropic/claude-sonnet-4.6 "Refactore diese Datei"

# Mit Cloud Ollama
openclaw --provider ollama-cloud "Analysiere den Code"
```

---

## 4. Installation & Einrichtung

### 4.1 Zoo Code Custom Modes installieren

Die Custom Modes werden als YAML-Datei im Zoo-Code-GlobalStorage abgelegt.

**Pfad:** `~/.local/share/code-server/User/globalStorage/zoocodeorganization.zoo-code/settings/custom_modes.yaml`

```yaml
customModes:
  - slug: ollama-local
    name: "🦙 Ollama Local"
    iconName: codicon-server
    roleDefinition: >
      Du bist Zoo, ein KI-Assistent der ausschließlich lokale Ollama-Modelle nutzt.
      Für Code-Aufgaben verwendest du qwen2.5-coder:7b, für allgemeine Aufgaben qwen2.5:3b.
      Du arbeitest datenschutzfreundlich ohne Cloud-Abhängigkeit.
      Alle Anfragen werden lokal auf dem DevSystem-VPS verarbeitet.
    customInstructions: >
      Nutze ausschließlich lokale Ollama-Modelle:
      - Code-Generierung, Debugging, Refactoring: qwen2.5-coder:7b
      - Allgemeine Fragen, Erklärungen, Deutsch: qwen2.5:3b
      - Embeddings/RAG: nomic-embed-text

      Ollama läuft auf: http://localhost:11434
      Verfügbare Modelle: qwen2.5-coder:7b, qwen2.5:3b, nomic-embed-text

      Hinweise:
      - Antworten können langsamer sein als Cloud-Modelle
      - Kein Internet-Zugriff für Modell-Inferenz
      - Ideal für vertrauliche Code-Reviews und lokale Entwicklung
    groups:
      - read
      - edit
      - browser
      - command
      - mcp
    source: global

  - slug: hybrid-ollama-openrouter
    name: "🔀 Hybrid (Ollama + OpenRouter)"
    iconName: codicon-git-merge
    roleDefinition: >
      Du bist Zoo, ein KI-Assistent im Hybrid-Modus der sowohl lokale Ollama-Modelle
      als auch OpenRouter Cloud-Modelle intelligent kombiniert.
      Einfache, schnelle Aufgaben werden lokal mit Ollama erledigt.
      Komplexe Reasoning-Aufgaben, große Kontexte und schwierige Probleme
      werden über OpenRouter mit Claude Sonnet 4.6 gelöst.
      Du optimierst automatisch zwischen Kosten, Geschwindigkeit und Qualität.
    customInstructions: >
      Hybrid-Strategie - wähle das Modell nach Aufgabentyp:

      LOKAL (Ollama - kostenlos, schnell):
      - Einfache Code-Snippets und Syntax-Korrekturen → qwen2.5-coder:7b
      - Kurze Erklärungen und Fragen → qwen2.5:3b
      - Bash/YAML/Python Boilerplate → qwen2.5-coder:7b
      - Datenschutzsensitive Aufgaben → Ollama bevorzugen

      CLOUD (OpenRouter - leistungsstark):
      - Komplexe Architektur-Entscheidungen → Claude Sonnet 4.6
      - Große Codebase-Analysen (>500 Zeilen) → Claude Sonnet 4.6
      - Multi-Step Reasoning und Planung → Claude Sonnet 4.6
      - Debugging komplexer Fehler → Claude Sonnet 4.6
      - Dokumentation und technisches Schreiben → Claude Sonnet 4.6

      Ollama URL: http://localhost:11434
      OpenRouter: Bereits konfiguriert (Claude Sonnet 4.6)

      Teile dem User mit welches Modell du für die aktuelle Aufgabe verwendest.
    groups:
      - read
      - edit
      - browser
      - command
      - mcp
    source: global
```

**Installation auf dem VPS:**

```bash
# 1. In das GlobalStorage-Verzeichnis wechseln
cd ~/.local/share/code-server/User/globalStorage/zoocodeorganization.zoo-code/settings/

# 2. Bestehende custom_modes.yaml sichern (falls vorhanden)
cp custom_modes.yaml custom_modes.yaml.backup

# 3. Neue custom_modes.yaml erstellen (Inhalt von oben)
nano custom_modes.yaml

# 4. code-server neu starten
systemctl restart code-server
```

### 4.2 OpenRouter API-Key konfigurieren

Der OpenRouter-API-Key wird **ausschließlich** im sicheren Secret-Store der VS-Code-Extension (`vscode.SecretStorage`) gespeichert – niemals in Klartext-Dateien.

**Schritte:**

1. code-server im Browser öffnen: `https://devsystem-qs-vps.tailcfea8a.ts.net:9443`
2. Zoo-Code-Icon in der Activity Bar öffnen
3. Modus "🔀 Hybrid (Ollama + OpenRouter)" wählen
4. In den Zoo-Extension-Settings den OpenRouter-Provider auswählen
5. API-Key von [https://openrouter.ai/keys](https://openrouter.ai/keys) eingeben
6. Key wird automatisch im Secret-Store gesichert

**Validierung:**

- [ ] Hybrid-Modus ausgewählt
- [ ] OpenRouter als Provider gesetzt
- [ ] API-Key eingegeben
- [ ] Test-Request abgesetzt
- [ ] OpenRouter Dashboard zeigt Request

> **Hinweis:** Ohne OpenRouter-Key funktioniert der Hybrid-Modus nur mit lokalen Ollama-Modellen. Der "🦙 Ollama Local"-Modus benötigt keinen Key.

### 4.3 Cloud Ollama API-Key konfigurieren

Der Cloud-Ollama-API-Key wird als Umgebungsvariable gesetzt:

```bash
# In /etc/environment oder systemd service file
OLLAMA_API_KEY=dein-api-key
```

---

## 5. Anforderungsmatrix

### 5.1 Verfügbarkeit

| Anforderung           | Umsetzung                                                        |
| --------------------- | ---------------------------------------------------------------- |
| **Offline-Fähigkeit** | Lokales Ollama auf VPS – kein Internet erforderlich              |
| **Redundanz**         | Zwei VPS-Instanzen mit eigener Ollama-Installation               |
| **Fallback**          | Hybrid-Modus: automatischer Fallback auf lokal bei Cloud-Ausfall |
| **Monitoring**        | `systemctl status ollama`, OpenRouter Dashboard                  |

### 5.2 Kostenoptimierung

| Strategie                  | Beschreibung                                           |
| -------------------------- | ------------------------------------------------------ |
| **Lokal zuerst**           | Einfache Aufgaben werden kostenlos lokal verarbeitet   |
| **Cloud nur bei Bedarf**   | Komplexe Aufgaben gehen an OpenRouter/Cloud Ollama     |
| **Modellwahl nach Kosten** | Claude Haiku ($0.25/$1.25) für einfache Cloud-Aufgaben |
| **Token-Budget**           | Begrenzung der maximalen Tokens pro Request            |

**Kostenvergleich (pro 1M Tokens):**

| Modell            | Input    | Output   | Einsatz         |
| ----------------- | -------- | -------- | --------------- |
| Lokales Ollama    | $0       | $0       | Standard        |
| Claude Sonnet 4.6 | ~$3      | ~$15     | Komplex         |
| Claude Haiku 4.0  | ~$0.25   | ~$1.25   | Einfach (Cloud) |
| DeepSeek V4 Pro   | variabel | variabel | Cloud-General   |

### 5.3 Leistungsfähigkeit

| Metrik                | Lokal (qwen2.5-coder:7b) | Cloud (Claude Sonnet 4.6) |
| --------------------- | ------------------------ | ------------------------- |
| **Latenz**            | < 1s (kein Netzwerk)     | 2-5s                      |
| **Kontextfenster**    | 32K Tokens               | 200K Tokens               |
| **Code-Qualität**     | Gut für einfache Tasks   | Exzellent                 |
| **Deutsch-Kompetenz** | Mittel                   | Sehr gut                  |
| **RAM-Bedarf**        | ~8 GB                    | 0 (Cloud)                 |

---

## 6. Betrieb & Wartung

### 6.1 Ollama Service Management

```bash
# Status prüfen
systemctl status ollama

# Neustart
systemctl restart ollama

# Logs einsehen
journalctl -u ollama -f

# Installierte Modelle anzeigen
ollama list

# Neues Modell laden
ollama pull qwen2.5-coder:7b

# Modell entfernen
ollama rm qwen2.5-coder:7b
```

### 6.2 API-Key Rotation

- **OpenRouter:** Alle 90 Tage rotieren über [https://openrouter.ai/keys](https://openrouter.ai/keys)
- **Cloud Ollama:** Nach Sicherheitsvorfällen sofort erneuern
- **Nach Rotation:** Zoo Code Extension neu starten

### 6.3 Troubleshooting

| Problem                      | Ursache                  | Lösung                                      |
| ---------------------------- | ------------------------ | ------------------------------------------- |
| Hybrid-Modus nutzt nur lokal | OpenRouter-Key fehlt     | Key im Secret-Store hinterlegen (siehe 4.2) |
| Ollama antwortet nicht       | Service gestoppt         | `systemctl restart ollama`                  |
| 401/403 von OpenRouter       | Key abgelaufen           | Key rotieren                                |
| Timeout bei Cloud-Requests   | Netzwerk/Proxy           | Tailscale-Konnektivität prüfen              |
| Hohe RAM-Nutzung             | Zu viele Modelle geladen | `OLLAMA_MAX_LOADED_MODELS=2` setzen         |

---

## 7. Sicherheit

- **API-Keys** werden niemals in Klartext-Dateien oder Git-Repositories gespeichert
- **OpenRouter-Key** liegt im `vscode.SecretStorage` (nicht dateibasiert replizierbar)
- **Cloud-Ollama-Key** wird als Umgebungsvariable gesetzt
- **Lokales Ollama** nur über localhost erreichbar (Firewall: Port 11434 nicht öffentlich)
- **Sensible Daten** werden nur an lokale Modelle gesendet

---

## 8. Referenzen

- [KI-Integration Konzept](../concepts/ki-integration-konzept.md) – Detaillierte Architektur
- [OpenRouter Setup-Hinweis](../operations/SETUP-HINWEIS-OPENROUTER.md) – API-Key-Konfiguration
- [Ollama QS Setup](../operations/OLLAMA-QS-SETUP.md) – Ollama-Installation
- [Ollama Prod Setup](../operations/OLLAMA-PROD-SETUP.md) – Produktionssetup
- [Code-Server Konzept](../concepts/code-server-konzept.md) – IDE-Integration
- [GitHub Secrets Setup](../operations/github-secrets-setup.md) – Secrets-Konfiguration
- [GitHub Secrets Completion Report](../operations/GITHUB-SECRETS-SETUP-COMPLETION-REPORT.md) – Status

---

## 9. Deployment über GitHub Actions

Die LLM-Konfiguration wird automatisiert über GitHub Actions auf die VPS-Instanzen ausgerollt. Dies ermöglicht Deployments vom Smartphone, Desktop oder jedem anderen Gerät – ohne direkten SSH-Zugriff.

### 9.1 Deployment-Architektur

```
┌──────────────────────────────────────────────────────────────┐
│                     GitHub Repository                         │
│  ┌────────────────────┐  ┌──────────────────────────────┐   │
│  │ GitHub Secrets     │  │ Workflow-Dateien             │   │
│  │ (API Keys, SSH)    │  │ .github/workflows/*.yml      │   │
│  └────────┬───────────┘  └──────────┬───────────────────┘   │
│           │                         │                        │
└───────────│──────────���──────────────│────────────────────────┘
            │                         │
            ▼                         ▼
┌───────────────────────────────────────────────────────────────┐
│                    GitHub Actions Runner                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ Tailscale    │  │ SSH via      │  │ Secrets →        │   │
│  │ OAuth/AuthKey│  │ Tailscale IP │  │ Umgebungsvar.    │   │
│  └──────┬───────┘  └──────┬───────┘  └────────┬─────────┘   │
│         │                 │                    │              │
└─────────│─────────────────│────────────────────│──────────────┘
          │                 │                    │
          ▼                 ▼                    ▼
┌───────────────────────────────────────────────────────────────┐
│              VPS (QS oder Produktion)                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ Ollama       │  │ code-server  │  │ /etc/environment │   │
│  │ Service      │  │ + Zoo Code   │  │ (API Keys)       │   │
│  └──────────────┘  └──────────────┘  └──────────────────┘   │
└───────────────────────────────────────────────────────────────┘
```

### 9.2 Bestehende Deploy-Workflows

| Workflow                 | Datei                                                                                        | Zweck                                                   |
| ------------------------ | -------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| **Deploy QS-VPS**        | [`.github/workflows/deploy-qs-vps.yml`](../../.github/workflows/deploy-qs-vps.yml)           | Vollständiges QS-VPS Deployment inkl. aller Komponenten |
| **Deploy Ollama (QS)**   | [`.github/workflows/deploy-ollama-qs.yml`](../../.github/workflows/deploy-ollama-qs.yml)     | Ollama-Installation + phi3.5:3.8b auf QS-VPS            |
| **Deploy Ollama (Prod)** | [`.github/workflows/deploy-ollama-prod.yml`](../../.github/workflows/deploy-ollama-prod.yml) | Ollama-Installation + nomic-embed-text auf Prod-VPS     |

### 9.3 Deployment-Ablauf (QS-VPS)

Der Workflow [`deploy-qs-vps.yml`](../../.github/workflows/deploy-qs-vps.yml) führt folgende Schritte aus:

```yaml
Steps:
  1. Checkout Repository        # Code von GitHub laden
  2. Setup Tailscale (OAuth)    # Ins Tailscale-Netzwerk einwählen
  3. Setup SSH Key              # SSH-Private-Key aus Secrets laden
  4. Test SSH Connection        # Verbindung zum VPS prüfen
  5. Sync Repository to VPS     # Kompletten Code via rsync übertragen
  6. Run Master-Orchestrator    # setup-qs-master.sh ausführen
  7. Validate Services          # Caddy, Qdrant Status prüfen
  8. Run Health Checks          # API-Endpunkte testen
  9. Cleanup                    # SSH-Key entfernen
```

**Trigger:**

- **Manuell:** `workflow_dispatch` mit Auswahl von Modus (normal/force/dry-run/rollback) und Komponente
- **Automatisch:** Push auf `main`-Branch bei Änderungen in `scripts/qs/**` oder dem Workflow selbst

### 9.4 Zoo Code IaC: Provider & Modes (Infrastructure as Code)

Die gesamte Zoo-Code-Konfiguration – **API-Provider** (OpenRouter, Ollama) und **Custom Modes** (spezialisierte KI-Personas) – wird als Infrastructure as Code (IaC) im Repository versioniert und per GitHub Actions automatisch auf den VPS ausgerollt. Kein manuelles Einrichten im UI nötig.

#### 9.4.1 Was sind Zoo Code Provider?

Provider definieren, **welche KI-APIs** Zoo Code nutzen darf. Jeder Provider hat einen API-Endpunkt, einen API-Key und eine Liste verfügbarer Modelle.

| Provider           | Konfigurationsdatei       | API-Key-Quelle                                                  |
| ------------------ | ------------------------- | --------------------------------------------------------------- |
| **OpenRouter**     | `settings.json` (VS Code) | `OPENROUTER_API_KEY` → GitHub Secret → `/etc/devsystem/llm.env` |
| **Ollama (lokal)** | `settings.json` (VS Code) | Kein Key nötig (localhost)                                      |
| **Ollama (Cloud)** | `settings.json` (VS Code) | `OLLAMA_API_KEY` → GitHub Secret → `/etc/devsystem/llm.env`     |

#### 9.4.2 Was sind Zoo Code Modes?

Modes sind **spezialisierte KI-Personas**, die Zoo Codes Verhalten, Modellwahl und Fähigkeiten anpassen. Jeder Mode definiert:

- **Rolle** (roleDefinition): Wer ist der Assistent?
- **Anweisungen** (customInstructions): Welche Modelle für welche Aufgaben?
- **Berechtigungen** (groups): read, edit, browser, command, mcp

```
┌─────────────────────────────────────────────────────────────┐
│                 ZOO CODE MODES (KI-PERSONAS)                 │
│                                                              │
│  🦙 Ollama Local          🔀 Hybrid              ☁️ Cloud   │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────┐ │
│  │ Nur lokale      │    │ Lokal + Cloud   │    │ Nur     │ │
│  │ Ollama-Modelle  │    │ Intelligent     │    │ Cloud   │ │
│  │                  │    │ Routing         │    │ APIs    │ │
│  │ qwen2.5-coder:7b│    │ Lokal: qwen     │    │ Open-   │ │
│  │ qwen2.5:3b      │    │ Cloud: Claude   │    │ Router  │ │
│  └─────────────────┘    └─────────────────┘    └─────────┘ │
│                                                              │
│  Konfiguration: custom_modes.yaml (YAML, versioniert in Git) │
│  Deployment:    GitHub Actions → rsync → VPS GlobalStorage   │
└─────────────────────────────────────────────────────────────┘
```

#### 9.4.3 IaC-Dateien im Repository

```
DevSystem/                              # Git Repository
├── config/zoo/                         # 🆕 Zoo Code IaC-Konfiguration
│   ├── custom_modes.yaml               # Mode-Definitionen (YAML)
│   ├── providers.json                  # Provider-Konfiguration (JSON)
│   └── mcp_settings.json              # MCP-Server (falls verwendet)
├── scripts/qs/
│   ├── configure-code-server-qs.sh     # code-server + Extensions
│   └── deploy-zoo-config.sh            # 🆕 Zoo Provider & Modes deployen
├── .github/workflows/
│   └── deploy-zoo-config.yml           # 🆕 Workflow: Zoo Config IaC
└── docs/LLM/
    └── idee.md                         # Dieses Dokument
```

#### 9.4.4 Provider-Konfiguration (`providers.json`)

Die `providers.json` definiert für jeden der **5 Default-Modi** (ask, architect, code, debug, orchestrator) das optimale Modell pro Provider. Zoo Code wählt automatisch das passende Modell basierend auf dem aktiven Modus.

```json
{
  "providers": {
    "openrouter": {
      "name": "OpenRouter",
      "apiBase": "https://openrouter.ai/api/v1",
      "apiKeyEnv": "OPENROUTER_API_KEY",
      "defaultModel": "anthropic/claude-sonnet-4.6",
      "models": {
        "ask": "anthropic/claude-haiku-4.0",
        "architect": "anthropic/claude-sonnet-4.6",
        "code": "anthropic/claude-sonnet-4.6",
        "debug": "anthropic/claude-sonnet-4.6",
        "orchestrator": "anthropic/claude-opus-4.0"
      },
      "modelConfig": {
        "anthropic/claude-haiku-4.0": {
          "costPer1MInput": 0.25,
          "costPer1MOutput": 1.25,
          "contextWindow": 200000,
          "maxTokens": 8192,
          "description": "Schnell & günstig – für einfache Fragen, Erklärungen, Dokumentation"
        },
        "anthropic/claude-sonnet-4.6": {
          "costPer1MInput": 3.0,
          "costPer1MOutput": 15.0,
          "contextWindow": 200000,
          "maxTokens": 8192,
          "description": "Balanced – für Code, Architektur, Debugging"
        },
        "anthropic/claude-opus-4.0": {
          "costPer1MInput": 15.0,
          "costPer1MOutput": 75.0,
          "contextWindow": 200000,
          "maxTokens": 8192,
          "description": "Maximale Leistung – für komplexe Orchestrierung"
        }
      }
    },
    "ollama-local": {
      "name": "Ollama Local",
      "apiBase": "http://localhost:11434",
      "apiKeyEnv": null,
      "defaultModel": "qwen2.5-coder:7b",
      "models": {
        "ask": "qwen2.5:3b",
        "architect": "qwen2.5-coder:7b",
        "code": "qwen2.5-coder:7b",
        "debug": "qwen2.5-coder:7b",
        "orchestrator": "qwen2.5-coder:7b"
      },
      "modelConfig": {
        "qwen2.5:3b": {
          "size": "1.9 GB",
          "ramRequired": "2-4 GB",
          "contextWindow": 32768,
          "description": "Leichtgewichtig – für einfache Fragen, Deutsch, kurze Texte"
        },
        "qwen2.5-coder:7b": {
          "size": "4.7 GB",
          "ramRequired": "6-8 GB",
          "contextWindow": 32768,
          "description": "Code-spezialisiert – für Implementierung, Debugging, Refactoring"
        },
        "nomic-embed-text": {
          "size": "274 MB",
          "ramRequired": "0.5 GB",
          "dimensions": 768,
          "description": "Embedding-Modell – für Codebase Indexing & RAG"
        }
      }
    },
    "ollama-cloud": {
      "name": "Ollama Cloud",
      "apiBase": "https://ollama.com/api",
      "apiKeyEnv": "OLLAMA_API_KEY",
      "defaultModel": "deepseek-v4-pro",
      "models": {
        "ask": "deepseek-v4-pro",
        "architect": "deepseek-v4-pro",
        "code": "deepseek-v4-pro",
        "debug": "deepseek-v4-pro",
        "orchestrator": "deepseek-v4-pro"
      },
      "modelConfig": {
        "deepseek-v4-pro": {
          "contextWindow": 128000,
          "description": "Cloud-LLM – leistungsstark ohne lokale Ressourcen"
        }
      }
    }
  }
}
```

**Modus-zu-Modell-Matrix:**

| Modus            | OpenRouter          | Ollama Local       | Ollama Cloud      | Begründung                                      |
| ---------------- | ------------------- | ------------------ | ----------------- | ----------------------------------------------- |
| **ask**          | `claude-haiku-4.0`  | `qwen2.5:3b`       | `deepseek-v4-pro` | Günstig/schnell – keine komplexe Inferenz nötig |
| **architect**    | `claude-sonnet-4.6` | `qwen2.5-coder:7b` | `deepseek-v4-pro` | Strukturiertes Denken, Planung, Design          |
| **code**         | `claude-sonnet-4.6` | `qwen2.5-coder:7b` | `deepseek-v4-pro` | Code-Generierung, Refactoring, Implementierung  |
| **debug**        | `claude-sonnet-4.6` | `qwen2.5-coder:7b` | `deepseek-v4-pro` | Fehleranalyse, Logging, Root-Cause              |
| **orchestrator** | `claude-opus-4.0`   | `qwen2.5-coder:7b` | `deepseek-v4-pro` | Multi-Step-Koordination, komplexe Workflows     |

#### 9.4.5 Mode-Konfiguration (`custom_modes.yaml`)

Die `custom_modes.yaml` wird im Repository unter `config/zoo/` versioniert und per Workflow in den Zoo-Code-GlobalStorage deployt:

```yaml
# config/zoo/custom_modes.yaml
customModes:
  - slug: ollama-local
    name: "🦙 Ollama Local"
    iconName: codicon-server
    roleDefinition: >
      Du bist Zoo, ein KI-Assistent der ausschließlich lokale Ollama-Modelle nutzt.
      Für Code-Aufgaben verwendest du qwen2.5-coder:7b, für allgemeine Aufgaben qwen2.5:3b.
      Du arbeitest datenschutzfreundlich ohne Cloud-Abhängigkeit.
    customInstructions: >
      Nutze ausschließlich lokale Ollama-Modelle:
      - Code-Generierung, Debugging, Refactoring: qwen2.5-coder:7b
      - Allgemeine Fragen, Erklärungen, Deutsch: qwen2.5:3b
      - Embeddings/RAG: nomic-embed-text
      Ollama läuft auf: http://localhost:11434
    groups: [read, edit, browser, command, mcp]
    source: global

  - slug: hybrid-ollama-openrouter
    name: "🔀 Hybrid (Ollama + OpenRouter)"
    iconName: codicon-git-merge
    roleDefinition: >
      Du bist Zoo, ein KI-Assistent im Hybrid-Modus der sowohl lokale Ollama-Modelle
      als auch OpenRouter Cloud-Modelle intelligent kombiniert.
    customInstructions: >
      Hybrid-Strategie - wähle das Modell nach Aufgabentyp:
      LOKAL (Ollama - kostenlos, schnell):
      - Einfache Code-Snippets → qwen2.5-coder:7b
      - Kurze Erklärungen → qwen2.5:3b
      - Datenschutzsensitive Aufgaben → Ollama bevorzugen
      CLOUD (OpenRouter - leistungsstark):
      - Komplexe Architektur → Claude Sonnet 4.6
      - Große Codebase-Analysen → Claude Sonnet 4.6
      - Multi-Step Reasoning → Claude Sonnet 4.6
      Teile dem User mit welches Modell du verwendest.
    groups: [read, edit, browser, command, mcp]
    source: global
```

#### 9.4.6 Deployment-Skript (`deploy-zoo-config.sh`)

```bash
#!/bin/bash
# config/zoo/deploy-zoo-config.sh
# IaC-Deployment: Zoo Code Provider & Modes auf den VPS ausrollen
set -euo pipefail

ZOOGLOBAL="$HOME/.local/share/code-server/User/globalStorage/zoocodeorganization.zoo-code/settings"
REPO_CONFIG="/root/work/DevSystem/config/zoo"

echo "=== Zoo Code IaC Deployment ==="

# 1. Custom Modes deployen
if [ -f "${REPO_CONFIG}/custom_modes.yaml" ]; then
    mkdir -p "${ZOOGLOBAL}"
    cp "${REPO_CONFIG}/custom_modes.yaml" "${ZOOGLOBAL}/custom_modes.yaml"
    echo "✓ custom_modes.yaml → ${ZOOGLOBAL}/"
fi

# 2. Provider-Konfiguration in VS Code settings.json mergen
if [ -f "${REPO_CONFIG}/providers.json" ]; then
    SETTINGS="$HOME/.local/share/code-server/User/settings.json"
    python3 -c "
import json, os

with open('${REPO_CONFIG}/providers.json') as f:
    providers = json.load(f)

settings = {}
if os.path.exists('${SETTINGS}'):
    with open('${SETTINGS}') as f:
        settings = json.load(f)

# OpenRouter Provider
if 'openrouter' in providers.get('providers', {}):
    p = providers['providers']['openrouter']
    settings['zoo.openRouterApiKey'] = '\${OPENROUTER_API_KEY}'
    settings['zoo.openRouterBaseUrl'] = p['apiBase']
    settings['zoo.openRouterDefaultModel'] = p['defaultModel']

# Ollama Local Provider
if 'ollama-local' in providers.get('providers', {}):
    p = providers['providers']['ollama-local']
    settings['zoo.ollamaEnabled'] = True
    settings['zoo.ollamaHost'] = p['apiBase']
    settings['zoo.ollamaDefaultModel'] = p['defaultModel']

with open('${SETTINGS}', 'w') as f:
    json.dump(settings, f, indent=2)
"
    echo "✓ providers.json → ${SETTINGS} (gemerged)"
fi

# 3. MCP Settings deployen
if [ -f "${REPO_CONFIG}/mcp_settings.json" ]; then
    cp "${REPO_CONFIG}/mcp_settings.json" "${ZOOGLOBAL}/mcp_settings.json"
    echo "✓ mcp_settings.json → ${ZOOGLOBAL}/"
fi

# 4. API-Keys aus /etc/devsystem/llm.env laden
if [ -f /etc/devsystem/llm.env ]; then
    set -a; source /etc/devsystem/llm.env; set +a
    echo "✓ API-Keys aus /etc/devsystem/llm.env geladen"
fi

# 5. code-server neu starten
systemctl restart code-server-qs 2>/dev/null || systemctl restart code-server
echo "✓ code-server neu gestartet"
echo "=== Zoo Code IaC Deployment abgeschlossen ==="
```

#### 9.4.7 GitHub Actions Workflow (`deploy-zoo-config.yml`)

```yaml
# .github/workflows/deploy-zoo-config.yml
name: Deploy Zoo Code Config (IaC)

on:
  workflow_dispatch:
    inputs:
      target:
        description: "Ziel-VPS"
        required: true
        type: choice
        options:
          - qs-vps
          - prod-vps
  push:
    branches:
      - main
    paths:
      - "config/zoo/**"
      - ".github/workflows/deploy-zoo-config.yml"

jobs:
  deploy-zoo-config:
    name: "Zoo Config IaC → ${{ github.event.inputs.target || 'qs-vps' }}"
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4

      - name: Setup Tailscale
        uses: tailscale/github-action@v2
        with:
          oauth-client-id: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID }}
          oauth-secret: ${{ secrets.TAILSCALE_OAUTH_SECRET }}
          tags: tag:ci

      - name: Setup SSH Key
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.QS_VPS_SSH_KEY }}" > ~/.ssh/id_ed25519
          chmod 600 ~/.ssh/id_ed25519

      - name: Deploy Zoo Config Files
        run: |
          # Config-Dateien auf VPS kopieren
          rsync -avz \
            -e "ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no" \
            config/zoo/ \
            ${{ secrets.QS_VPS_USER }}@${{ secrets.QS_VPS_HOST }}:/root/work/DevSystem/config/zoo/

      - name: Deploy API Keys
        run: |
          ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no \
            ${{ secrets.QS_VPS_USER }}@${{ secrets.QS_VPS_HOST }} \
            "sudo mkdir -p /etc/devsystem && \
             echo 'OPENROUTER_API_KEY=${{ secrets.OPENROUTER_API_KEY }}' | sudo tee /etc/devsystem/llm.env && \
             echo 'OLLAMA_API_KEY=${{ secrets.OLLAMA_API_KEY }}' | sudo tee -a /etc/devsystem/llm.env && \
             sudo chmod 600 /etc/devsystem/llm.env"

      - name: Run Zoo Config Deployment
        run: |
          ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no \
            ${{ secrets.QS_VPS_USER }}@${{ secrets.QS_VPS_HOST }} \
            "bash /root/work/DevSystem/config/zoo/deploy-zoo-config.sh"

      - name: Validate Zoo Modes
        run: |
          ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no \
            ${{ secrets.QS_VPS_USER }}@${{ secrets.QS_VPS_HOST }} \
            "cat ~/.local/share/code-server/User/globalStorage/zoocodeorganization.zoo-code/settings/custom_modes.yaml | grep -c 'slug:'"

      - name: Cleanup
        if: always()
        run: rm -f ~/.ssh/id_ed25519
```

#### 9.4.8 IaC-Deployment-Ablauf

```
┌────────────────────────────────��─────────────────────────────┐
│                 ZOO CODE IAC DEPLOYMENT PIPELINE              │
│                                                               │
│  Git Push (config/zoo/*)                                      │
│       │                                                       │
│       ▼                                                       │
│  GitHub Actions: deploy-zoo-config.yml                        │
│       │                                                       │
│       ├─→ 1. Checkout Repository                              │
│       ├─→ 2. Tailscale OAuth (VPN zum VPS)                    │
│       ├─→ 3. SSH-Key aus Secrets laden                        │
│       ├─→ 4. rsync config/zoo/ → VPS:/root/work/DevSystem/    │
│       ├─→ 5. API-Keys aus Secrets → /etc/devsystem/llm.env    │
│       ├─→ 6. deploy-zoo-config.sh ausführen:                  │
│       │      ├─ custom_modes.yaml → GlobalStorage             │
│       │      ├─ providers.json → settings.json (merge)        │
│       │      ├─ mcp_settings.json → GlobalStorage             │
│       │      └─ code-server restart                           │
���       └─→ 7. Validierung: Modes zählen                        │
│                                                               │
│  Ergebnis: Zoo Code mit aktuellen Providern & Modes           │
└───────────────────────────────────────────────────────────────┘
```

#### 9.4.9 IaC-Vorteile

| Vorteil                | Beschreibung                                               |
| ---------------------- | ---------------------------------------------------------- |
| **Versionierung**      | Alle Provider/Modes-Änderungen sind in Git nachvollziehbar |
| **Reproduzierbarkeit** | Neuer VPS = ein Workflow-Run, identische Konfiguration     |
| **Rollback**           | `git revert` + Workflow-Run = Zurück zur vorherigen Config |
| **Review**             | PR-Review für Mode-Änderungen bevor sie live gehen         |
| **Audit**              | Wer hat wann welchen Mode/Provider geändert?               |
| **Kein UI-Klick**      | Kein manuelles Einrichten im code-server-Interface nötig   |

### 9.5 Deployment-Modi

| Modus        | Befehl                          | Beschreibung                                                           |
| ------------ | ------------------------------- | ---------------------------------------------------------------------- |
| **normal**   | `setup-qs-master.sh`            | Idempotentes Deployment – überspringt bereits installierte Komponenten |
| **force**    | `setup-qs-master.sh --force`    | Erzwingt Neuinstallation aller Komponenten                             |
| **dry-run**  | `setup-qs-master.sh --dry-run`  | Simuliert Deployment ohne Änderungen                                   |
| **rollback** | `setup-qs-master.sh --rollback` | Rollback auf vorherigen Stand                                          |

### 9.6 Deployment vom Smartphone

1. GitHub-App oder Browser öffnen
2. Repository → **Actions** → **Deploy QS-VPS**
3. **Run workflow** → Modus wählen → **Run workflow**
4. Workflow-Logs in Echtzeit verfolgen
5. Deployment-Report im Step Summary einsehen

---

## 10. API-Key-Speicherung in GitHub Secrets

Sämtliche API-Keys und Zugangsdaten werden als **GitHub Secrets** gespeichert und während des Deployments als Umgebungsvariablen injiziert. Sie erscheinen niemals im Klartext in Logs oder Konfigurationsdateien.

### 10.1 Secrets-Übersicht

| Secret Name                 | Typ          | Verwendung                                   | Workflow              |
| --------------------------- | ------------ | -------------------------------------------- | --------------------- |
| `OPENROUTER_API_KEY`        | API Key      | OpenRouter Cloud-Modelle (Claude)            | LLM-Deploy            |
| `OLLAMA_API_KEY`            | API Key      | Cloud Ollama (ollama.com)                    | LLM-Deploy            |
| `TAILSCALE_OAUTH_CLIENT_ID` | OAuth ID     | Tailscale-Netzwerkzugang                     | Alle Deploy-Workflows |
| `TAILSCALE_OAUTH_SECRET`    | OAuth Secret | Tailscale-Authentifizierung                  | Alle Deploy-Workflows |
| `TAILSCALE_AUTH_KEY`        | Auth Key     | Tailscale-Fallback (falls OAuth fehlschlägt) | Alle Deploy-Workflows |
| `QS_VPS_SSH_KEY`            | SSH Key      | SSH-Zugriff auf QS-VPS                       | QS-Deploy             |
| `QS_VPS_HOST`               | Hostname     | Tailscale-IP des QS-VPS                      | QS-Deploy             |
| `QS_VPS_USER`               | Username     | SSH-Benutzer (root)                          | QS-Deploy             |
| `PROD_VPS_SSH_KEY`          | SSH Key      | SSH-Zugriff auf Prod-VPS                     | Prod-Deploy           |
| `PROD_VPS_HOST`             | Hostname     | Tailscale-IP des Prod-VPS                    | Prod-Deploy           |
| `PROD_VPS_USER`             | Username     | SSH-Benutzer (root)                          | Prod-Deploy           |

### 10.2 Secrets im Workflow verwenden

GitHub Secrets werden in Workflow-Dateien via `${{ secrets.NAME }}` referenziert:

```yaml
# Beispiel: API-Key als Umgebungsvariable auf dem VPS setzen
- name: Configure API Keys on VPS
  run: |
    ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no \
      ${{ secrets.QS_VPS_USER }}@${{ secrets.QS_VPS_HOST }} \
      "echo 'OPENROUTER_API_KEY=${{ secrets.OPENROUTER_API_KEY }}' | sudo tee -a /etc/environment"
```

**Sicherheitsregeln:**

- Secrets werden in Logs automatisch maskiert (`***`)
- Secrets sind nur für Repository-Collaborators mit `write`-Zugriff sichtbar
- Secrets werden nie im Klartext in Workflow-Dateien gespeichert
- Secrets sind nach dem Setzen nicht mehr auslesbar (nur überschreibbar)

### 10.3 Secrets einrichten

#### Schritt 1: Repository Settings öffnen

1. GitHub Repository → **Settings** → **Secrets and variables** → **Actions**
2. Auf **New repository secret** klicken

#### Schritt 2: LLM-spezifische Secrets hinzufügen

**OPENROUTER_API_KEY:**

- **Name:** `OPENROUTER_API_KEY`
- **Value:** `sk-or-v1-...` (von [https://openrouter.ai/keys](https://openrouter.ai/keys))
- **Verwendung:** Hybrid-Modus Cloud-Komponente

**OLLAMA_API_KEY:**

- **Name:** `OLLAMA_API_KEY`
- **Value:** API-Key von [https://ollama.com](https://ollama.com)
- **Verwendung:** Cloud Ollama General Modus

#### Schritt 3: Secrets validieren

```bash
# Via GitHub CLI prüfen
gh secret list --repo HaraldKiessling/DevSystem

# Erwartete Ausgabe (Secrets sind maskiert):
# OPENROUTER_API_KEY    Updated 2026-05-31
# OLLAMA_API_KEY        Updated 2026-05-31
# TAILSCALE_OAUTH_CLIENT_ID  Updated 2026-04-12
# ...
```

### 10.4 Secrets auf den VPS übertragen

Während des Deployments werden Secrets als Umgebungsvariablen auf dem VPS gesetzt:

```bash
# Workflow-Step: API-Keys auf VPS konfigurieren
- name: Deploy API Keys to VPS
  run: |
    ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no \
      ${{ secrets.QS_VPS_USER }}@${{ secrets.QS_VPS_HOST }} \
      "sudo mkdir -p /etc/devsystem && \
       echo 'OPENROUTER_API_KEY=${{ secrets.OPENROUTER_API_KEY }}' | sudo tee /etc/devsystem/llm.env && \
       echo 'OLLAMA_API_KEY=${{ secrets.OLLAMA_API_KEY }}' | sudo tee -a /etc/devsystem/llm.env && \
       sudo chmod 600 /etc/devsystem/llm.env && \
       sudo chown root:root /etc/devsystem/llm.env"
```

**Zielverzeichnis auf dem VPS:**

```
/etc/devsystem/
└── llm.env              # API-Keys (600, root:root)
```

### 10.5 Sicherheitsarchitektur

```
┌─────────────────────────────────────────────────────────────┐
│                    SICHERHEITSEBENEN                         │
│                                                              │
│  Ebene 1: GitHub Secrets                                     │
│  ├─ Verschlüsselt in GitHub gespeichert                      │
│  ├─ Nur via GitHub Actions API zugänglich                    │
│  └─ Automatisch maskiert in Logs                             │
│                                                              │
│  Ebene 2: Tailscale VPN                                      │
│  ├─ Alle Verbindungen über verschlüsseltes Tailscale-Netz    │
│  ├─ OAuth/AuthKey-Authentifizierung                          │
│  └─ ACLs beschränken Zugriff auf tag:ci                     │
│                                                              │
│  Ebene 3: SSH Key                                            │
│  ├─ Dedizierter SSH-Key für GitHub Actions                   │
│  ├─ Key wird nach Deployment gelöscht (Cleanup-Step)         │
│  └─ Public Key nur auf autorisierten VPS hinterlegt          │
│                                                              │
│  Ebene 4: VPS-Dateisystem                                    │
│  ├─ /etc/devsystem/llm.env: 600 (nur root lesbar)            │
│  ├─ vscode.SecretStorage: Nicht dateibasiert                 │
│  └─ Ollama nur auf localhost:11434                           │
└─────────────────────────────────────────────────────────────┘
```

### 10.6 Key-Rotation über GitHub Actions

API-Keys können zentral über GitHub Secrets rotiert werden, ohne manuellen Zugriff auf den VPS:

```bash
# 1. Neuen Key im Provider-Dashboard generieren
#    - OpenRouter: https://openrouter.ai/keys
#    - Cloud Ollama: https://ollama.com/settings/api-keys

# 2. GitHub Secret aktualisieren
gh secret set OPENROUTER_API_KEY --repo HaraldKiessling/DevSystem --body "sk-or-v1-NEUER_KEY"

# 3. Deploy-Workflow auslösen
gh workflow run deploy-qs-vps.yml --ref main -f deployment_mode=normal

# 4. Alten Key im Provider-Dashboard deaktivieren
```

### 10.7 Monitoring & Audit

- **Workflow-Runs:** [GitHub Actions Tab](https://github.com/HaraldKiessling/DevSystem/actions)
- **OpenRouter Dashboard:** [https://openrouter.ai/activity](https://openrouter.ai/activity) – Kosten & Requests
- **Deployment-Logs:** `/var/log/qs-deployment/deployment-report-*.md` auf dem VPS
- **Secret-Updates:** GitHub Audit Log (Organisation → Settings → Audit log)

---

## 11. Codebase Indexing mit Qdrant & LLM-Embeddings

Zoo Code bietet eine **semantische Codebase-Indexierung**, die auf LLM-Embeddings und der Qdrant-Vektordatenbank basiert. Statt exakter Textsuche wird die **Bedeutung** von Code verstanden – Zoo findet relevante Dateien auch ohne Kenntnis konkreter Funktionsnamen.

> **Offizielle Dokumentation:** [docs.zoocode.dev/features/codebase-indexing](https://docs.zoocode.dev/features/codebase-indexing)

### 11.1 Funktionsweise

```
┌──────────────────────────────────────────────────────────────────┐
│                    CODEBASE INDEXING WORKFLOW                     │
│                                                                   │
│  1. PARSE                    2. EMBED              3. STORE      │
│  ┌──────────┐              ┌──────────┐          ┌──────────┐   │
│  │ Tree-    │              │ LLM      │          │ Qdrant   │   │
│  │ sitter   │ ──blocks──→  │ Embedding│──vectors→│ Vector   │   │
│  │ AST      │              │ Model    │          │ DB       │   │
│  └──────────┘              └──────────┘          └──────────┘   │
│       │                          │                     │         │
│  Funktionen,                nomic-embed-text       Port 6333     │
│  Klassen,                   (768 Dimensionen)      localhost     │
│  Methoden,                                                │      │
│  Markdown-Header                                          │      │
│                                                           ▼      │
│  4. SEARCH                                              ┌──────┐ │
│  ┌──────────────────────────────────────────────────┐   │Vektor│ │
│  │ "Wie funktioniert die SSH-Verbindung?"           │──→│Search│ │
│  │         ↓ LLM Embedding                          │   └──────┘ │
│  │         ↓ Semantische Ähnlichkeit                 │            │
│  │  → scripts/qs/diagnose-ssh-vps.sh (Score: 0.94)  │            │
│  │  → docs/operations/VPS-SSH-FIX-GUIDE.md (0.87)   │            │
│  └──────────────────────────────────────────────────┘            │
└──────────────────────────────────────────────────────────────────┘
```

**Ablauf:**

1. **Tree-sitter** parst den Code und identifiziert semantische Blöcke (Funktionen, Klassen, Methoden)
2. **LLM-Embedding-Modell** (`nomic-embed-text`) erzeugt 768-dimensionale Vektoren pro Codeblock
3. **Qdrant** speichert die Vektoren und ermöglicht schnelle Ähnlichkeitssuche
4. **Semantische Suche** findet relevanten Code anhand der Bedeutung, nicht des Wortlauts

### 11.2 DevSystem-Architektur: Lokal & Kostenlos

Das DevSystem nutzt eine **komplett lokale und kostenlose** Codebase-Indexing-Architektur:

| Komponente           | DevSystem-Implementierung             | Alternative (Cloud)             |
| -------------------- | ------------------------------------- | ------------------------------- |
| **Embedding-Modell** | `nomic-embed-text` via lokales Ollama | OpenAI `text-embedding-3-small` |
| **Vektordatenbank**  | Qdrant nativ auf VPS (`qdrant-qs`)    | Qdrant Cloud                    |
| **Parser**           | Tree-sitter (in Zoo Code integriert)  | –                               |
| **Kosten**           | **$0** (alles lokal)                  | ~$0.02/1M Tokens                |

```
┌──────────────────────────────────────────────────────────────┐
│                      DevSystem VPS                            │
│                                                               │
│  ┌──────────────────┐     ┌──────────────────┐              │
│  │ Zoo Code         │     │ Ollama           │              │
│  │ (code-server)    │────→│ localhost:11434   │              │
│  │                  │     │ nomic-embed-text  │              │
│  │ Tree-sitter      │     │ (768 dims, 274MB) │              │
│  │ Code-Parsing     │     └──────────────────┘              │
│  └────────┬─────────┘                                        │
│           │ Embeddings                                        │
│           ▼                                                   │
│  ┌──────────────────┐                                        │
│  │ Qdrant           │                                        │
│  │ localhost:6333    │                                        │
│  │ qdrant-qs Service│                                        │
│  │ /var/lib/qdrant-qs│                                       │
│  └──────────────────┘                                        │
└──────────────────────────────────────────────────────────────┘
```

### 11.3 Konfiguration in Zoo Code

Die Codebase-Indexing-Einstellungen werden im Zoo-Code-Interface konfiguriert (Status-Icon unten rechts im Chat-Input).

#### Embedding-Provider (Lokal)

| Feld         | Wert                     | Erklärung                                   |
| ------------ | ------------------------ | ------------------------------------------- |
| **Provider** | `Ollama`                 | Lokales Ollama statt OpenAI                 |
| **Model**    | `nomic-embed-text`       | 768 Dimensionen, 274 MB, optimiert für Code |
| **Base URL** | `http://localhost:11434` | Ollama API-Endpunkt                         |

#### Qdrant-Verbindung

| Feld               | Wert                    | Erklärung                                |
| ------------------ | ----------------------- | ---------------------------------------- |
| **Qdrant URL**     | `http://localhost:6333` | Qdrant HTTP API                          |
| **Qdrant API Key** | _(leer)_                | Nicht erforderlich bei localhost-Betrieb |
| **Collection**     | `codebase-index`        | Automatisch von Zoo Code erstellt        |

#### Status-Indikator

| Farbe       | Bedeutung                                                  |
| ----------- | ---------------------------------------------------------- |
| ⚪ **Grau** | Indexierung inaktiv / nicht konfiguriert                   |
| 🟡 **Gelb** | Indexierung läuft (Parsing + Embedding)                    |
| 🟢 **Grün** | Index aktuell, bereit für semantische Suche                |
| 🔴 **Rot**  | Fehler (Qdrant nicht erreichbar, Embedding fehlgeschlagen) |

### 11.4 Installation & Einrichtung

#### Schritt 1: Ollama Embedding-Modell bereitstellen

```bash
# nomic-embed-text herunterladen (274 MB)
ollama pull nomic-embed-text

# Testen
curl -X POST http://localhost:11434/api/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model":"nomic-embed-text","prompt":"Test embedding für Codebase Indexing"}'
```

#### Schritt 2: Qdrant-Verbindung prüfen

```bash
# Qdrant Service-Status
systemctl status qdrant-qs

# API-Test
curl http://localhost:6333/
# Erwartet: {"title":"qdrant - vector search engine","version":"1.7.4"}

# Collections anzeigen
curl http://localhost:6333/collections
```

#### Schritt 3: Zoo Code konfigurieren

1. Zoo Code in code-server öffnen
2. Auf das **Codebase-Indexing-Icon** (unten rechts im Chat-Input) klicken
3. **Embedding Provider:** Ollama → `nomic-embed-text`
4. **Qdrant URL:** `http://localhost:6333`
5. **Qdrant API Key:** leer lassen (localhost)
6. Auf **Start Indexing** klicken

#### Schritt 4: Indexierung starten

- Zoo Code parst automatisch alle Dateien im Workspace
- Tree-sitter extrahiert semantische Blöcke
- `nomic-embed-text` erzeugt Embeddings
- Qdrant speichert die Vektoren
- Status-Icon wechselt von Gelb auf Grün, sobald fertig

### 11.5 Deployment über GitHub Actions

Die Codebase-Indexing-Infrastruktur wird als Teil des bestehenden Deployments ausgerollt:

```yaml
# In deploy-qs-vps.yml bereits enthalten:
Steps:
  5. Sync Repository to VPS    # Code wird via rsync übertragen
  6. Run Master-Orchestrator   # deploy-qdrant-qs.sh installiert Qdrant
```

**Was automatisch deployt wird:**

| Komponente                       | Workflow                 | Skript                                                                |
| -------------------------------- | ------------------------ | --------------------------------------------------------------------- |
| Qdrant Service                   | `deploy-qs-vps.yml`      | [`deploy-qdrant-qs.sh`](../../scripts/qs/deploy-qdrant-qs.sh)         |
| Ollama + Embedding-Modell        | `deploy-ollama-qs.yml`   | [`install-ollama-qs.sh`](../../scripts/qs/install-ollama-qs.sh)       |
| Ollama + Embedding-Modell (Prod) | `deploy-ollama-prod.yml` | [`install-ollama-prod.sh`](../../scripts/prod/install-ollama-prod.sh) |

**Idempotenz:** Beide Skripte sind idempotent – sie erkennen bestehende Installationen und überspringen diese.

### 11.6 Index-Qualität & Performance

| Metrik                        | Wert                         |
| ----------------------------- | ---------------------------- |
| **Embedding-Dimensionen**     | 768 (nomic-embed-text)       |
| **Modell-Größe**              | 274 MB                       |
| **RAM-Nutzung (Modell)**      | ~500 MB                      |
| **Index-Größe (DevSystem)**   | ~50-100 MB (ca. 500 Dateien) |
| **Parsing-Geschwindigkeit**   | ~10-50 Dateien/Sekunde       |
| **Embedding-Geschwindigkeit** | ~5-20 Blöcke/Sekunde         |
| **Such-Latenz**               | < 50ms                       |

### 11.7 Wartung & Troubleshooting

#### Index neu aufbauen

```bash
# In Zoo Code: Popover → "Clear Index Data" → "Start Indexing"
# Oder via Qdrant API:
curl -X DELETE http://localhost:6333/collections/codebase-index
```

#### Häufige Probleme

| Problem              | Ursache                 | Lösung                                    |
| -------------------- | ----------------------- | ----------------------------------------- | ----------------- |
| 🔴 Rotes Icon        | Qdrant nicht erreichbar | `systemctl restart qdrant-qs`             |
| 🔴 Rotes Icon        | nomic-embed-text fehlt  | `ollama pull nomic-embed-text`            |
| Gelbes Icon bleibt   | Indexierung hängt       | Zoo Code neu starten, Index clearen       |
| "Connection failed"  | Port 6333 blockiert     | `ss -tlnp                                 | grep 6333` prüfen |
| Langsame Indexierung | Zu viele Dateien        | `.rooignore` für irrelevante Pfade nutzen |

#### `.rooignore` für optimale Indexierung

```gitignore
# .rooignore – Dateien von der Indexierung ausschließen
node_modules/
.git/
*.log
/var/
/tmp/
*.vsix
*.tar.gz
```

### 11.8 Sicherheit

- **Embeddings** sind mathematische Einweg-Repräsentationen – kein Quellcode rekonstruierbar
- **Lokale Verarbeitung:** Code verlässt den VPS nicht (Ollama + Qdrant auf localhost)
- **Keine API-Keys nötig:** Anders als OpenAI benötigt die lokale Lösung keine externen Keys
- **Qdrant nur auf localhost:** Port 6333 ist nicht öffentlich zugänglich
- **Collection-Isolation:** Zoo Code nutzt dedizierte Collection `codebase-index`

### 11.9 Vorteile der lokalen Architektur

| Vorteil             | Beschreibung                                                      |
| ------------------- | ----------------------------------------------------------------- |
| **Kostenlos**       | Keine Embedding-API-Kosten (OpenAI würde ~$0.02/1M Tokens kosten) |
| **Datenschutz**     | Quellcode verlässt nie den VPS                                    |
| **Offline-fähig**   | Funktioniert ohne Internetverbindung                              |
| **Geschwindigkeit** | Keine Netzwerk-Latenz zu externen APIs                            |
| **Kontrolle**       | Volle Kontrolle über Modell und Index                             |

---

**Erstellt:** 2026-05-31
**Autor:** DevSystem
**Nächste Überprüfung:** 2026-08-31
