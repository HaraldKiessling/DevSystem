# Ollama Deployment auf Produktions-VPS - Setup-Anleitung

**Datum:** 2026-05-24  
**VPS:** `devsystem-vps` (100.100.221.56)  
**Zweck:** Ollama Embedding-Server für Qdrant/RAG-Integration

---

## Übersicht

Ollama wird auf dem Produktions-VPS mit dem Embedding-Modell `nomic-embed-text` installiert.
Dieses Modell erzeugt Vektoren für die Qdrant-Datenbank (RAG-Anwendungen).

**Architektur:**

```
Roo Code / Anwendung
        │
        ▼
Ollama API (localhost:11434)
  └── nomic-embed-text  → Vektoren → Qdrant (localhost:6333)
  └── mxbai-embed-large (optional)
        │
        ▼ (via Caddy Reverse Proxy)
ollama.devsystem.internal (nur Tailscale)
```

---

## Schritt 1: SSH-Key für Produktions-VPS generieren

Auf deinem lokalen Rechner (mit Tailscale-Zugriff auf den VPS):

```bash
# Neuen SSH-Key für GitHub Actions generieren
ssh-keygen -t ed25519 -C "github-actions-prod-vps" -f ~/.ssh/github-actions-prod-vps -N ""

# Public Key anzeigen (wird auf VPS hinterlegt)
cat ~/.ssh/github-actions-prod-vps.pub

# Private Key anzeigen (wird als GitHub Secret gespeichert)
cat ~/.ssh/github-actions-prod-vps
```

---

## Schritt 2: Public Key auf Produktions-VPS hinterlegen

```bash
# Via IONOS Web-Konsole oder bestehendem SSH-Zugang:
ssh root@100.100.221.56

# Auf dem VPS:
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Public Key hinzufügen (Inhalt von ~/.ssh/github-actions-prod-vps.pub einfügen):
echo "ssh-ed25519 AAAA... github-actions-prod-vps" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Test:
exit
ssh -i ~/.ssh/github-actions-prod-vps root@100.100.221.56 "echo 'SSH OK'"
```

---

## Schritt 3: GitHub Secrets einrichten

Gehe zu: **GitHub → Repository → Settings → Secrets and variables → Actions**

Folgende Secrets anlegen:

| Secret Name        | Wert                                        | Beschreibung                             |
| ------------------ | ------------------------------------------- | ---------------------------------------- |
| `PROD_VPS_SSH_KEY` | Inhalt von `~/.ssh/github-actions-prod-vps` | Private SSH-Key (komplett, inkl. Header) |
| `PROD_VPS_HOST`    | `100.100.221.56`                            | Tailscale-IP des Produktions-VPS         |
| `PROD_VPS_USER`    | `root`                                      | SSH-Benutzer                             |

**Bereits vorhandene Secrets** (werden auch für diesen Workflow benötigt):

- `TAILSCALE_OAUTH_CLIENT_ID` ✅
- `TAILSCALE_OAUTH_SECRET` ✅
- `TAILSCALE_AUTH_KEY` ✅ (Fallback)

---

## Schritt 4: Workflow manuell triggern

1. Gehe zu: **GitHub → Actions → "Deploy Ollama (Prod-VPS)"**
2. Klicke: **"Run workflow"**
3. Wähle:
   - **Deployment Mode:** `dry-run` (erst testen!)
   - **Optionales Modell:** `false`
4. Prüfe den Output im GitHub Actions Log
5. Bei Erfolg: erneut mit `normal` ausführen

---

## Schritt 5: Installation validieren

Nach erfolgreichem Deployment auf dem VPS prüfen:

```bash
ssh root@100.100.221.56

# Service-Status
systemctl status ollama

# Installierte Modelle
ollama list

# API-Test
curl http://localhost:11434/api/version

# Embedding-Test
curl -X POST http://localhost:11434/api/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model":"nomic-embed-text","prompt":"Test für Qdrant"}'

# Logs
journalctl -u ollama -n 50
```

---

## Qdrant-Integration

Nach der Ollama-Installation können Embeddings für Qdrant generiert werden:

```python
import requests

# Embedding via Ollama generieren
def get_embedding(text: str) -> list[float]:
    response = requests.post(
        "http://localhost:11434/api/embeddings",
        json={"model": "nomic-embed-text", "prompt": text}
    )
    return response.json()["embedding"]

# In Qdrant speichern
from qdrant_client import QdrantClient
from qdrant_client.models import PointStruct

client = QdrantClient(host="localhost", port=6333)

# Collection erstellen (nomic-embed-text = 768 Dimensionen)
client.create_collection(
    collection_name="devsystem-docs",
    vectors_config={"size": 768, "distance": "Cosine"}
)

# Dokument einbetten und speichern
embedding = get_embedding("DevSystem Dokumentation")
client.upsert(
    collection_name="devsystem-docs",
    points=[PointStruct(id=1, vector=embedding, payload={"text": "..."})]
)
```

---

## Ressourcen-Übersicht

| Modell              | Größe  | RAM     | Dimensionen | Zweck                          |
| ------------------- | ------ | ------- | ----------- | ------------------------------ |
| `nomic-embed-text`  | 274 MB | ~500 MB | 768         | Standard-Embeddings für Qdrant |
| `mxbai-embed-large` | 670 MB | ~1 GB   | 1024        | Höhere Qualität (optional)     |

**Systemd-Service:** `ollama.service`  
**Logs:** `/var/log/ollama/ollama.log`  
**Modelle:** `/var/lib/ollama/models/`  
**API:** `http://localhost:11434` (nur localhost)  
**Caddy-Domain:** `https://ollama.devsystem.internal` (nur Tailscale)

---

## Troubleshooting

### Service startet nicht

```bash
journalctl -u ollama -n 100 --no-pager
systemctl status ollama --no-pager
```

### Modell-Download fehlgeschlagen

```bash
# Manuell pullen
ollama pull nomic-embed-text

# Disk-Speicher prüfen
df -h /var/lib/ollama
```

### Zu wenig RAM

```bash
free -h
# Falls < 2 GB frei: andere Services prüfen
ps aux --sort=-%mem | head -10
```

### Caddy-Konfiguration

```bash
caddy validate --config /etc/caddy/Caddyfile
systemctl reload caddy
cat /var/log/caddy/ollama.log
```

---

## Verwandte Dateien

- [`scripts/prod/install-ollama-prod.sh`](../../scripts/prod/install-ollama-prod.sh) - Installations-Script
- [`.github/workflows/deploy-ollama-prod.yml`](../../.github/workflows/deploy-ollama-prod.yml) - GitHub Actions Workflow
- [`docs/concepts/ki-integration-konzept.md`](../concepts/ki-integration-konzept.md) - KI-Architektur-Konzept
- [`docs/deployment/vps-deployment-qdrant.md`](../deployment/vps-deployment-qdrant.md) - Qdrant-Deployment
