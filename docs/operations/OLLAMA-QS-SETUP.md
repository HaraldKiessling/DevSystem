# Ollama Deployment auf QS-VPS - phi3.5:3.8b

**Datum:** 2026-05-24  
**VPS:** `devsystem-qs-vps` (QS-Umgebung)  
**Modell:** `phi3.5:3.8b` (Microsoft Phi-3.5 Mini Instruct)  
**Zweck:** Lokales LLM für QS-Tests und KI-Integration

---

## Übersicht

Ollama wird auf dem QS-VPS mit dem LLM `phi3.5:3.8b` installiert.  
Dieses Modell ermöglicht lokale KI-Inferenz ohne Cloud-Abhängigkeit.

**Architektur:**

```
Roo Code / Anwendung (via Tailscale)
         │
         ▼
Caddy Reverse Proxy (ollama.devsystem-qs.internal)
         │
         ▼
Ollama API (localhost:11434)
   └── phi3.5:3.8b  → Lokale LLM-Inferenz
```

---

## Ressourcen-Anforderungen

| Ressource  | Minimum | Empfohlen | phi3.5:3.8b Bedarf   |
| ---------- | ------- | --------- | -------------------- |
| RAM frei   | 4 GB    | 6 GB      | ~4-5 GB beim Betrieb |
| RAM gesamt | 6 GB    | 8 GB      | -                    |
| Disk frei  | 5 GB    | 10 GB     | ~2.2 GB Modell       |
| CPU        | 2 Kerne | 4 Kerne   | -                    |

> **Wichtig:** Das Script prüft automatisch die Ressourcen und bricht ab wenn zu wenig RAM vorhanden ist.

---

## Deployment

### Option A: GitHub Actions (empfohlen)

Workflow: [`.github/workflows/deploy-ollama-qs.yml`](../../.github/workflows/deploy-ollama-qs.yml)

**Manuell auslösen:**

1. GitHub → Repository → Actions → **"Deploy Ollama (QS-VPS) - phi3.5:3.8b"**
2. "Run workflow" klicken
3. Modus wählen:

| Modus          | Beschreibung                            |
| -------------- | --------------------------------------- |
| `install`      | Vollinstallation (idempotent, Standard) |
| `force`        | Neuinstallation erzwingen               |
| `dry-run`      | Nur prüfen, nichts installieren         |
| `cleanup-only` | Nur alte Modelle löschen                |
| `validate`     | Nur Validierung (kein Install)          |

**Automatisch bei Push:**  
Der Workflow startet automatisch wenn `scripts/qs/install-ollama-qs.sh` auf `main` gepusht wird.

---

### Option B: Manuell via SSH

```bash
# 1. SSH auf QS-VPS
ssh root@<QS_VPS_HOST>

# 2. Repository klonen/aktualisieren
cd /root/work/DevSystem
git pull

# 3. Memory-Check (vor Installation)
free -h
df -h /
ollama list 2>/dev/null || echo "Ollama nicht installiert"

# 4. Alte Modelle aufräumen (falls nötig)
bash scripts/qs/install-ollama-qs.sh --cleanup-only

# 5. Installation
bash scripts/qs/install-ollama-qs.sh

# 6. Validierung
systemctl status ollama
ollama list
curl http://localhost:11434/api/version
```

---

## Memory-Management

Das Script enthält automatisches Memory-Management:

```
Freier RAM < 4 GB  → Abbruch mit Fehlermeldung
Freier RAM < 6 GB  → Warnung + automatischer Cleanup alter Modelle
Disk < 5 GB        → Automatischer Cleanup alter Modelle
```

**Manueller Cleanup:**

```bash
# Alle Modelle außer phi3.5:3.8b löschen
bash scripts/qs/install-ollama-qs.sh --cleanup-only

# Einzelnes Modell löschen
ollama rm <modellname>

# Alle Modelle anzeigen
ollama list
```

---

## Konfiguration

### systemd Service

```
/etc/systemd/system/ollama.service
```

Wichtige Einstellungen für `phi3.5:3.8b`:

| Parameter                  | Wert              | Begründung                                |
| -------------------------- | ----------------- | ----------------------------------------- |
| `OLLAMA_HOST`              | `127.0.0.1:11434` | Nur localhost, kein direkter Außenzugriff |
| `OLLAMA_KEEP_ALIVE`        | `15m`             | Modell nach 15min aus RAM entladen        |
| `OLLAMA_MAX_LOADED_MODELS` | `1`               | Nur 1 Modell gleichzeitig (RAM-Schonung)  |
| `OLLAMA_NUM_PARALLEL`      | `1`               | Sequentielle Anfragen (QS-Umgebung)       |
| `MemoryMax`                | `6G`              | Systemd-Limit                             |
| `MemoryHigh`               | `5G`              | Soft-Limit (Throttling)                   |
| `CPUQuota`                 | `150%`            | Max 1.5 CPU-Kerne                         |

### Caddy Reverse Proxy

Konfiguration: `/etc/caddy/sites/ollama-qs.caddy`

```caddyfile
ollama.devsystem-qs.internal {
    # Nur Tailscale-Zugriff (100.64.0.0/10)
    reverse_proxy localhost:11434
}
```

---

## API-Nutzung

### Inference (Text generieren)

```bash
curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "phi3.5:3.8b",
    "prompt": "Erkläre kurz was Qdrant ist",
    "stream": false
  }'
```

### Chat

```bash
curl -X POST http://localhost:11434/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "phi3.5:3.8b",
    "messages": [
      {"role": "user", "content": "Hallo, wie geht es dir?"}
    ]
  }'
```

### Interaktiv (Terminal)

```bash
ollama run phi3.5:3.8b
```

### API-Version prüfen

```bash
curl http://localhost:11434/api/version
```

---

## Monitoring und Logs

```bash
# Service-Status
systemctl status ollama

# Live-Logs
journalctl -u ollama -f

# Log-Dateien
tail -f /var/log/ollama/ollama.log
tail -f /var/log/ollama/ollama-error.log

# RAM-Nutzung
ps aux | grep "ollama serve"
free -h

# Installierte Modelle
ollama list
```

---

## Troubleshooting

### Service startet nicht

```bash
systemctl status ollama --no-pager
journalctl -u ollama -n 50 --no-pager
```

### OOM (Out of Memory)

```bash
# Prüfen ob OOM-Killer aktiv war
dmesg | grep -i "oom\|killed"

# Freien RAM prüfen
free -h

# Andere Prozesse beenden
systemctl stop qdrant  # temporär falls nötig

# Ollama neu starten
systemctl restart ollama
```

### Modell lädt nicht

```bash
# Modell-Status prüfen
ollama list

# Modell neu pullen
ollama pull phi3.5:3.8b

# Disk-Speicher prüfen
df -h /var/lib/ollama
```

### API nicht erreichbar

```bash
# Port prüfen
ss -tlnp | grep 11434

# Service-Status
systemctl is-active ollama

# Manuell starten
systemctl start ollama
sleep 5
curl http://localhost:11434/api/version
```

---

## Unterschiede zu Prod-VPS

| Aspekt       | QS-VPS                                 | Prod-VPS                            |
| ------------ | -------------------------------------- | ----------------------------------- |
| Modell       | `phi3.5:3.8b` (LLM)                    | `nomic-embed-text` (Embeddings)     |
| Zweck        | Lokale KI-Inferenz / Tests             | Qdrant/RAG-Embeddings               |
| Memory-Limit | 6 GB                                   | 4 GB                                |
| Keep-Alive   | 15 min                                 | 10 min                              |
| Max Modelle  | 1                                      | 2                                   |
| Caddy-Domain | `ollama.devsystem-qs.internal`         | `ollama.devsystem.internal`         |
| Marker-Datei | `/var/lib/ollama/.qs-install-complete` | `/var/lib/ollama/.install-complete` |

---

## Benötigte GitHub Secrets

| Secret                      | Beschreibung               |
| --------------------------- | -------------------------- |
| `QS_VPS_SSH_KEY`            | SSH Private Key für QS-VPS |
| `QS_VPS_HOST`               | Tailscale-IP des QS-VPS    |
| `QS_VPS_USER`               | SSH-Benutzer (z.B. `root`) |
| `TAILSCALE_OAUTH_CLIENT_ID` | Tailscale OAuth Client ID  |
| `TAILSCALE_OAUTH_SECRET`    | Tailscale OAuth Secret     |

> Diese Secrets sind bereits für den `deploy-qs-vps.yml` Workflow konfiguriert.

---

## Verwandte Dokumente

- [`docs/operations/OLLAMA-PROD-SETUP.md`](OLLAMA-PROD-SETUP.md) - Ollama auf Prod-VPS
- [`docs/concepts/qs-vps-konzept.md`](../concepts/qs-vps-konzept.md) - QS-VPS Konzept
- [`scripts/qs/install-ollama-qs.sh`](../../scripts/qs/install-ollama-qs.sh) - Install-Script
- [`.github/workflows/deploy-ollama-qs.yml`](../../.github/workflows/deploy-ollama-qs.yml) - GitHub Actions Workflow
