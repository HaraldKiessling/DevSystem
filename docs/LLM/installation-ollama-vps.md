# OLLAMA Installation & Konfiguration – QS-VPS (Lokal + Cloud)

**Version:** 1.0  
**Datum:** 2026-06-02  
**System:** devsystem-qs-vps (6 Cores, 7.7 GB RAM, Ubuntu 24.04)  
**Gilt für:** QS-VPS und lokalen Entwicklungsrechner

---

## 1. Übersicht

Diese Anleitung beschreibt die vollständige Installation und Konfiguration von Ollama auf dem QS-VPS – sowohl für lokale Modelle als auch für die Cloud-Anbindung via OpenRouter.

| Komponente         | Typ   | Endpunkt                       | Kosten      |
| ------------------ | ----- | ------------------------------ | ----------- |
| **Ollama (lokal)** | Local | `http://localhost:11434`       | $0          |
| **OpenRouter**     | Cloud | `https://openrouter.ai/api/v1` | Pay-per-use |
| **Ollama Cloud**   | Cloud | `https://ollama.com/api`       | Pay-per-use |

---

## 2. Installation: Ollama (Lokal)

### 2.1 Ollama installieren

```bash
# Offizielle Installation
curl -fsSL https://ollama.com/install.sh | sh

# Version prüfen
ollama --version
# → ollama version is 0.24.0
```

### 2.2 Service-Status prüfen

```bash
systemctl status ollama
# → active (running)

# API-Verfügbarkeit testen
curl http://localhost:11434/api/version
# → {"version":"0.24.0"}
```

### 2.3 Modelle herunterladen

```bash
# === Empfohlene Modelle für QS-VPS ===

# Embedding-Modell (274 MB) – für Qdrant Codebase-Indexierung
ollama pull nomic-embed-text

# Chat-Modell (1.9 GB) – für einfache Fragen/Erklärungen (ask-Agent)
ollama pull qwen2.5:3b

# Optional: Code-Modell (4.7 GB) – NUR wenn RAM ausreicht!
# WARNUNG: Überfordert den VPS bei gleichzeitigem Betrieb mit anderen Diensten
# ollama pull qwen2.5-coder:7b
```

### 2.4 Installierte Modelle prüfen

```bash
ollama list
# Erwartete Ausgabe:
# NAME                       ID              SIZE      MODIFIED
# qwen2.5:3b                 357c53fb659c    1.9 GB    ...
# nomic-embed-text:latest    0a109f422b47    274 MB    ...
```

### 2.5 Ollama-Konfiguration optimieren

```bash
# /etc/systemd/system/ollama.service.d/override.conf
mkdir -p /etc/systemd/system/ollama.service.d
cat > /etc/systemd/system/ollama.service.d/override.conf << 'EOF'
[Service]
# Maximal 2 Modelle gleichzeitig im RAM halten
Environment="OLLAMA_MAX_LOADED_MODELS=2"
# Modelle nach 5 Minuten Inaktivität entladen
Environment="OLLAMA_KEEP_ALIVE=5m"
# Nur auf localhost lauschen (Sicherheit)
Environment="OLLAMA_HOST=127.0.0.1"
# Maximale Parallel-Requests
Environment="OLLAMA_NUM_PARALLEL=2"
# Memory-Limit (verhindert OOM)
MemoryMax=6G
EOF

systemctl daemon-reload
systemctl restart ollama
```

### 2.6 Firewall (UFW)

```bash
# Ollama NUR auf localhost – KEIN öffentlicher Zugriff!
ufw deny 11434/tcp 2>/dev/null || true
# Port 11434 darf NICHT in der Firewall geöffnet sein
```

---

## 3. Konfiguration: OpenRouter (Cloud)

### 3.1 API-Key generieren

1. Account erstellen: [https://openrouter.ai/](https://openrouter.ai/)
2. API-Key generieren: [https://openrouter.ai/keys](https://openrouter.ai/keys)
3. Key format: `sk-or-v1-...`

### 3.2 API-Key auf dem VPS hinterlegen

```bash
# Verzeichnis erstellen
sudo mkdir -p /etc/devsystem

# API-Key speichern (restriktive Berechtigungen)
echo 'OPENROUTER_API_KEY=sk-or-v1-...' | sudo tee /etc/devsystem/llm.env
sudo chmod 600 /etc/devsystem/llm.env
sudo chown root:root /etc/devsystem/llm.env
```

### 3.3 OpenRouter-Verbindung testen

```bash
source /etc/devsystem/llm.env
curl -s https://openrouter.ai/api/v1/models \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  | python3 -c "import sys,json; [print(m['id']) for m in json.load(sys.stdin)['data'][:5]]"
```

### 3.4 Empfohlene Modelle

| Modell                        | Verwendung                         | Kosten (Input/Output pro 1M) |
| ----------------------------- | ---------------------------------- | ---------------------------- |
| `anthropic/claude-haiku-4.0`  | ask-Agent, einfache Tasks          | $0.25 / $1.25                |
| `anthropic/claude-sonnet-4.6` | code, debug, arc-Agent             | $3.00 / $15.00               |
| `anthropic/claude-opus-4.0`   | org-Agent, komplexe Orchestrierung | $15.00 / $75.00              |

---

## 4. Konfiguration: Ollama Cloud (optional)

### 4.1 API-Key generieren

1. Account: [https://ollama.com](https://ollama.com)
2. Settings → API Keys → Generate

### 4.2 API-Key hinterlegen

```bash
echo 'OLLAMA_API_KEY=dein-key' | sudo tee -a /etc/devsystem/llm.env
sudo chmod 600 /etc/devsystem/llm.env
```

---

## 5. Zoo Code Provider-Konfiguration

### 5.1 providers.json

Die Provider-Konfiguration in [`config/zoo/providers.json`](../../config/zoo/providers.json) definiert die Modell-Zuordnung pro Agent:

```json
{
  "providers": {
    "ollama-local": {
      "name": "Ollama Local",
      "apiBase": "http://localhost:11434",
      "defaultModel": "qwen2.5:3b",
      "models": {
        "ask": "qwen2.5:3b",
        "architect": "qwen2.5:3b",
        "code": "qwen2.5:3b",
        "debug": "qwen2.5:3b",
        "orchestrator": "qwen2.5:3b"
      }
    },
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
      }
    }
  }
}
```

### 5.2 Deployment

```bash
# Manuelles Deployment
sudo bash /root/work/DevSystem/config/zoo/deploy-zoo-config.sh

# Oder via GitHub Actions:
# gh workflow run deploy-zoo-config.yml --ref main -f target=qs-vps
```

---

## 6. Validierung

### 6.1 Ollama lokal

```bash
# Service-Status
systemctl is-active ollama && echo "✅ Ollama läuft" || echo "❌ Ollama gestoppt"

# API-Test
curl -s http://localhost:11434/api/tags | python3 -c "
import sys, json
models = json.load(sys.stdin)['models']
print(f'✅ {len(models)} Modelle installiert')
for m in models:
    print(f'   - {m[\"name\"]} ({m[\"size\"]/(1024**3):.1f} GB)')
"

# Embedding-Test
curl -s -X POST http://localhost:11434/api/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model":"nomic-embed-text","prompt":"test"}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'✅ Embedding: {len(d[\"embedding\"])} Dimensionen')"
```

### 6.2 OpenRouter

```bash
source /etc/devsystem/llm.env
curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  https://openrouter.ai/api/v1/models
# Erwartet: 200
```

### 6.3 Zoo Code Modes

```bash
grep -c 'slug:' ~/.local/share/code-server/User/globalStorage/zoocodeorganization.zoo-code/settings/custom_modes.yaml
# Erwartet: 3 (ollama-local, hybrid-ollama-openrouter, ollama-cloud-general)
```

---

## 7. Wartung

### 7.1 Modelle aktualisieren

```bash
# Alle installierten Modelle aktualisieren
ollama list | tail -n +2 | awk '{print $1}' | while read model; do
    echo "Updating: $model"
    ollama pull "$model"
done
```

### 7.2 API-Key-Rotation

```bash
# 1. Neuen Key im Provider-Dashboard generieren
# 2. GitHub Secret aktualisieren
gh secret set OPENROUTER_API_KEY --repo HaraldKiessling/DevSystem --body "sk-or-v1-NEUER_KEY"

# 3. Deployment auslösen
gh workflow run deploy-zoo-config.yml --ref main -f target=qs-vps

# 4. Alten Key deaktivieren
```

### 7.3 RAM-Überwachung

```bash
# Ollama RAM-Nutzung prüfen
ps aux | grep "ollama runner" | grep -v grep | awk '{print "Ollama RAM: " $6/1024 " MB"}'

# Gesamten RAM-Status
free -h
```

---

## 8. Troubleshooting

| Problem                     | Ursache                  | Lösung                                                 |
| --------------------------- | ------------------------ | ------------------------------------------------------ |
| Ollama antwortet nicht      | Service gestoppt         | `systemctl restart ollama`                             |
| 401/403 von OpenRouter      | Key abgelaufen           | Key rotieren (siehe 7.2)                               |
| "out of memory"             | 7B-Modell überlastet RAM | Nur 3B-Modelle verwenden, `OLLAMA_MAX_LOADED_MODELS=1` |
| Langsame Inferenz           | CPU-Überlastung          | `OLLAMA_NUM_PARALLEL=1` setzen                         |
| Modell wird nicht gefunden  | Nicht heruntergeladen    | `ollama pull <modell>`                                 |
| OpenRouter nicht erreichbar | DNS-Problem              | `host openrouter.ai` prüfen                            |

---

## 9. Sicherheit

- **Ollama nur auf localhost:** `OLLAMA_HOST=127.0.0.1` – kein öffentlicher Zugriff
- **API-Keys restriktiv:** `/etc/devsystem/llm.env` mit `chmod 600`, nur root lesbar
- **Firewall:** Port 11434 nicht öffentlich öffnen
- **Sensible Daten:** Nur an lokale Modelle senden, nicht an Cloud-APIs
- **Key-Rotation:** Alle 90 Tage oder nach Sicherheitsvorfällen

---

## 10. Referenzen

- [UC1: Qdrant Codebase-Indexierung](uc1-qdrant-codebase-indexing.md)
- [UC2: Zoo-Agentensystem](uc2-zoo-agent-system.md)
- [UC3: OpenClaw Multiagentensystem](uc3-openclaw-multiagent.md)
- [Qdrant Installation & Konfiguration](installation-qdrant-vps.md)
- [LLM-Gesamtkonzept](concept_llm_usage.md)
- [OpenRouter Setup](../operations/SETUP-HINWEIS-OPENROUTER.md)

---

**Erstellt:** 2026-06-02  
**Autor:** Zoo (AI Assistant)  
**Nächste Überprüfung:** 2026-09-02
