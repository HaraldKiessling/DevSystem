# LLM-Integration: Lokale Einrichtung & Setup

**Version:** 1.0  
**Datum:** 2026-05-31  
**Zielgruppe:** Entwickler, die das DevSystem lokal oder auf einem VPS einrichten

---

## 1. Überblick

Das DevSystem nutzt eine mehrstufige LLM-Infrastruktur mit drei Betriebsmodi:

| Modus                            | Icon | Typ                                  | Benötigte Keys       |
| -------------------------------- | ---- | ------------------------------------ | -------------------- |
| **Ollama Local**                 | 🦙   | Nur lokale Modelle (qwen2.5)         | Keine                |
| **Hybrid (Ollama + OpenRouter)** | 🔀   | Lokal + Cloud, intelligentes Routing | `OPENROUTER_API_KEY` |
| **Ollama Cloud General**         | ☁️   | Cloud-basierte Modelle (deepseek)    | `OLLAMA_API_KEY`     |

---

## 2. Voraussetzungen

- **Ollama** lokal installiert und gestartet (`systemctl status ollama`)
- **code-server** mit Zoo Code Extension
- **Tailscale** für VPS-Zugriff (bei Remote-Setup)
- **GitHub CLI** (`gh`) für Secrets-Management

---

## 3. Schnellstart (Lokal)

### 3.1 Ollama starten & Modelle laden

```bash
# Ollama installieren (falls nicht vorhanden)
curl -fsSL https://ollama.com/install.sh | sh

# Modelle für den lokalen Modus laden
ollama pull qwen2.5-coder:7b    # Code-Modell (4.7 GB)
ollama pull qwen2.5:3b          # Allgemein (1.9 GB)
ollama pull nomic-embed-text    # Embeddings (274 MB)

# Prüfen
ollama list
curl http://localhost:11434/api/version
```

### 3.2 Zoo Code Modes deployen

```bash
# Aus dem Repository-Verzeichnis
cd /root/work/DevSystem

# Deployment-Skript ausführen
sudo bash config/zoo/deploy-zoo-config.sh
```

Das Skript deployt:

- `custom_modes.yaml` → Zoo Code GlobalStorage (3 Modes)
- `providers.json` → VS Code `settings.json` (gemerged)
- API-Keys aus `/etc/devsystem/llm.env` (falls vorhanden)

### 3.3 code-server neu starten

```bash
sudo systemctl restart code-server-qs   # QS-VPS
# oder
sudo systemctl restart code-server       # Standard
```

---

## 4. API-Keys einrichten

### 4.1 OpenRouter API-Key

1. Account erstellen: [https://openrouter.ai/](https://openrouter.ai/)
2. API-Key generieren: [https://openrouter.ai/keys](https://openrouter.ai/keys)
3. Key als GitHub Secret speichern:

```bash
gh secret set OPENROUTER_API_KEY --repo HaraldKiessling/DevSystem --body "sk-or-v1-..."
```

4. Deployment auslösen:

```bash
gh workflow run deploy-zoo-config.yml --ref main -f target=qs-vps
```

### 4.2 Ollama Cloud API-Key

1. Account erstellen: [https://ollama.com](https://ollama.com)
2. API-Key generieren: Settings → API Keys
3. Key als GitHub Secret speichern:

```bash
gh secret set OLLAMA_API_KEY --repo HaraldKiessling/DevSystem --body "..."
```

---

## 5. Deployment über GitHub Actions

Die gesamte Zoo-Code-Konfiguration wird als **Infrastructure as Code (IaC)** versioniert und per GitHub Actions deployt:

```
Git Push (config/zoo/*)
  → GitHub Actions: deploy-zoo-config.yml
    → Tailscale OAuth (VPN)
    → rsync config/zoo/ → VPS
    → API-Keys aus Secrets → /etc/devsystem/llm.env
    → deploy-zoo-config.sh ausführen
    → code-server restart
```

### Manuelles Deployment

1. GitHub → Actions → **Deploy Zoo Code Config (IaC)**
2. **Run workflow** → Ziel wählen → **Run workflow**
3. Workflow-Logs in Echtzeit verfolgen

---

## 6. Verzeichnisstruktur

```
DevSystem/
├── config/zoo/                         # Zoo Code IaC (versioniert in Git)
│   ├── custom_modes.yaml               # Mode-Definitionen (3 Modes)
│   ├── providers.json                  # Provider-Konfiguration (OpenRouter, Ollama)
│   └── deploy-zoo-config.sh            # Deployment-Skript
├── .github/workflows/
│   └── deploy-zoo-config.yml           # GitHub Actions Workflow
└── docs/LLM/
    ├── concept_llm_usage.md            # Vollständiges Konzept
    └── setup.md                        # Diese Datei
```

Auf dem VPS:

```
/etc/devsystem/
└── llm.env                             # API-Keys (600, root:root)

~/.local/share/code-server/User/
├── settings.json                       # Provider-Config (von providers.json)
└── globalStorage/zoocodeorganization.zoo-code/settings/
    └── custom_modes.yaml               # 3 Custom Modes
```

---

## 7. Validierung

### Modes prüfen

```bash
grep -c 'slug:' ~/.local/share/code-server/User/globalStorage/zoocodeorganization.zoo-code/settings/custom_modes.yaml
# Erwartet: 3
```

### API-Keys prüfen (ohne Werte preiszugeben)

```bash
sudo cat /etc/devsystem/llm.env | cut -d= -f1
# Erwartet:
# OPENROUTER_API_KEY
# OLLAMA_API_KEY
```

### Ollama-Verfügbarkeit prüfen

```bash
curl -s http://localhost:11434/api/tags | python3 -c "import sys,json; [print(m['name']) for m in json.load(sys.stdin)['models']]"
```

---

## 8. Troubleshooting

| Problem                      | Ursache                        | Lösung                                                   |
| ---------------------------- | ------------------------------ | -------------------------------------------------------- |
| Hybrid-Modus nutzt nur lokal | OpenRouter-Key fehlt           | `gh secret set OPENROUTER_API_KEY` + Workflow auslösen   |
| Ollama antwortet nicht       | Service gestoppt               | `systemctl restart ollama`                               |
| 401/403 von OpenRouter       | Key abgelaufen                 | Key rotieren (siehe 4.1)                                 |
| Nur 2 Modes sichtbar         | Deployment fehlgeschlagen      | `bash config/zoo/deploy-zoo-config.sh` manuell ausführen |
| `llm.env` nicht gefunden     | Workflow Step 6 fehlgeschlagen | Workflow-Logs prüfen, Secrets validieren                 |

---

## 9. Sicherheit

- **API-Keys** werden **niemals** in Klartext-Dateien oder Git-Repositories gespeichert
- **OpenRouter-Key** und **Ollama-Cloud-Key** liegen als GitHub Secrets vor
- Auf dem VPS: `/etc/devsystem/llm.env` mit `chmod 600`, nur `root` lesbar
- **Lokales Ollama** nur über `localhost:11434` erreichbar (Firewall: Port nicht öffentlich)
- **Sensible Daten** nur an lokale Modelle senden
- `.gitignore` schließt alle `*.llm.env`, `api-keys.txt` und ähnliche Dateien aus

---

## 10. Referenzen

- [Vollständiges LLM-Konzept](concept_llm_usage.md) – Architektur, Routing, Kosten
- [KI-Integration Konzept](../concepts/ki-integration-konzept.md) – Detaillierte Architektur
- [OpenRouter Setup-Hinweis](../operations/SETUP-HINWEIS-OPENROUTER.md)
- [Ollama QS Setup](../operations/OLLAMA-QS-SETUP.md)
- [GitHub Secrets Setup](../operations/github-secrets-setup.md)
