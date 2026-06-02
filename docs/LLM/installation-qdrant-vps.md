# Qdrant Installation & Konfiguration – QS-VPS & Lokaler Entwicklungsrechner

**Version:** 1.0  
**Datum:** 2026-06-02  
**System:** devsystem-qs-vps (6 Cores, 7.7 GB RAM, Ubuntu 24.04)  
**Gilt für:** QS-VPS und lokalen Entwicklungsrechner

---

## 1. Übersicht

Qdrant ist eine hochperformante Vektordatenbank, die für die semantische Codebase-Indexierung in Zoo Code verwendet wird. Sie speichert Embedding-Vektoren und ermöglicht schnelle Ähnlichkeitssuchen.

| Eigenschaft      | Wert                                                        |
| ---------------- | ----------------------------------------------------------- |
| **Version**      | 1.7.4                                                       |
| **Installation** | Native Binary (kein Docker)                                 |
| **Port**         | `localhost:6333`                                            |
| **Storage**      | `/var/lib/qdrant-qs` (QS) / `/var/lib/qdrant-local` (Lokal) |
| **RAM-Limit**    | 512 MB (systemd MemoryMax)                                  |
| **Service-Name** | `qdrant-qs` (QS) / `qdrant-local` (Lokal)                   |

---

## 2. Installation: QS-VPS

### 2.1 Binary herunterladen und installieren

```bash
# Download
cd /tmp
curl -sL https://github.com/qdrant/qdrant/releases/download/v1.7.4/qdrant-x86_64-unknown-linux-gnu.tar.gz \
  -o qdrant.tar.gz

# Entpacken
tar xzf qdrant.tar.gz

# Installieren
sudo mv qdrant /usr/local/bin/qdrant
sudo chmod +x /usr/local/bin/qdrant

# Version prüfen
/usr/local/bin/qdrant --version
```

### 2.2 Nutzer und Verzeichnisse

```bash
# System-Nutzer erstellen
sudo useradd -r -s /bin/false -d /var/lib/qdrant-qs qdrant

# Verzeichnisse
sudo mkdir -p /var/lib/qdrant-qs /etc/qdrant
sudo chown -R qdrant:qdrant /var/lib/qdrant-qs /etc/qdrant
```

### 2.3 systemd Service

```bash
sudo cat > /etc/systemd/system/qdrant-qs.service << 'SVC'
[Unit]
Description=Qdrant Vector Database (QS)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=qdrant
Group=qdrant
ExecStart=/usr/local/bin/qdrant --uri http://127.0.0.1:6333 --storage-path /var/lib/qdrant-qs
Restart=on-failure
RestartSec=5s
MemoryMax=512M
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
SVC

sudo systemctl daemon-reload
sudo systemctl enable --now qdrant-qs
```

### 2.4 Verifikation

```bash
# Service-Status
systemctl is-active qdrant-qs && echo "✅ Qdrant läuft" || echo "❌ Qdrant gestoppt"

# API-Test
curl -s http://localhost:6333/
# → {"title":"qdrant - vector search engine","version":"1.7.4"}

# Collections
curl -s http://localhost:6333/collections
# → {"result":{"collections":[]},"status":"ok"}
```

---

## 3. Installation: Lokaler Entwicklungsrechner

### 3.1 Binary installieren

```bash
# Gleiche Schritte wie QS-VPS, aber anderer Storage-Path
cd /tmp
curl -sL https://github.com/qdrant/qdrant/releases/download/v1.7.4/qdrant-x86_64-unknown-linux-gnu.tar.gz \
  -o qdrant.tar.gz
tar xzf qdrant.tar.gz
sudo mv qdrant /usr/local/bin/qdrant
sudo chmod +x /usr/local/bin/qdrant
```

### 3.2 Nutzer und Verzeichnisse

```bash
sudo useradd -r -s /bin/false -d /var/lib/qdrant-local qdrant 2>/dev/null || true
sudo mkdir -p /var/lib/qdrant-local /etc/qdrant
sudo chown -R qdrant:qdrant /var/lib/qdrant-local /etc/qdrant
```

### 3.3 systemd Service

```bash
sudo cat > /etc/systemd/system/qdrant-local.service << 'SVC'
[Unit]
Description=Qdrant Vector Database (Local)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=qdrant
Group=qdrant
ExecStart=/usr/local/bin/qdrant --uri http://127.0.0.1:6333 --storage-path /var/lib/qdrant-local
Restart=on-failure
RestartSec=5s
MemoryMax=512M
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
SVC

sudo systemctl daemon-reload
sudo systemctl enable --now qdrant-local
```

### 3.4 Verifikation

```bash
systemctl is-active qdrant-local && echo "✅ Qdrant läuft" || echo "❌ Qdrant gestoppt"
curl -s http://localhost:6333/
```

---

## 4. Zoo Code Integration

### 4.1 Konfiguration in Zoo Code

1. Zoo Code in code-server öffnen
2. Auf das **Codebase-Indexing-Icon** (unten rechts im Chat-Input) klicken
3. Folgende Einstellungen vornehmen:

| Feld                   | Wert                           |
| ---------------------- | ------------------------------ |
| **Embedding Provider** | Ollama                         |
| **Model**              | `nomic-embed-text`             |
| **Base URL**           | `http://localhost:11434`       |
| **Qdrant URL**         | `http://localhost:6333`        |
| **Qdrant API Key**     | _(leer lassen)_                |
| **Collection**         | `codebase-index` (automatisch) |

4. Auf **Start Indexing** klicken

### 4.2 Status-Indikator

| Farbe       | Bedeutung                                                  |
| ----------- | ---------------------------------------------------------- |
| ⚪ **Grau** | Indexierung inaktiv / nicht konfiguriert                   |
| 🟡 **Gelb** | Indexierung läuft (Parsing + Embedding)                    |
| 🟢 **Grün** | Index aktuell, bereit für semantische Suche                |
| 🔴 **Rot**  | Fehler (Qdrant nicht erreichbar, Embedding fehlgeschlagen) |

---

## 5. Index-Management

### 5.1 Index neu aufbauen

```bash
# Collection löschen (Zoo Code legt sie automatisch neu an)
curl -X DELETE http://localhost:6333/collections/codebase-index

# Oder in Zoo Code: Popover → "Clear Index Data" → "Start Indexing"
```

### 5.2 Index-Statistiken

```bash
# Collection-Info
curl -s http://localhost:6333/collections/codebase-index | python3 -m json.tool

# Vektoranzahl
curl -s http://localhost:6333/collections/codebase-index \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'Vektoren: {d[\"result\"][\"vectors_count\"]}')"
```

### 5.3 `.rooignore` für optimale Indexierung

```gitignore
# .rooignore – Dateien von der Indexierung ausschließen
node_modules/
.git/
*.log
/var/
/tmp/
*.vsix
*.tar.gz
*.jpg
*.png
*.pdf
```

---

## 6. Performance-Optimierung

### 6.1 Qdrant-Konfiguration

```bash
# Storage-Pfad auf schneller Disk (SSD)
/usr/local/bin/qdrant --storage-path /var/lib/qdrant-qs

# RAM-Limit im systemd Service
MemoryMax=512M  # Verhindert OOM bei großen Collections
```

### 6.2 Embedding-Optimierung

```bash
# Ollama: Maximal 2 Modelle gleichzeitig
Environment="OLLAMA_MAX_LOADED_MODELS=2"

# nomic-embed-text ist mit 274 MB das optimale Embedding-Modell
# Keine größeren Embedding-Modelle verwenden!
```

### 6.3 Index-Größe schätzen

| Dateien | Code-Blöcke | Vektoren      | Index-Größe |
| ------- | ----------- | ------------- | ----------- |
| 100     | ~500        | 500 × 768d    | ~5 MB       |
| 500     | ~2.500      | 2.500 × 768d  | ~25 MB      |
| 1.000   | ~5.000      | 5.000 × 768d  | ~50 MB      |
| 5.000   | ~25.000     | 25.000 × 768d | ~250 MB     |

---

## 7. Wartung

### 7.1 Tägliche Checks

```bash
# Service-Status
systemctl is-active qdrant-qs

# API erreichbar?
curl -s -o /dev/null -w "%{http_code}" http://localhost:6333/
# Erwartet: 200

# RAM-Nutzung
ps -o pid,rss,comm -p $(pgrep -f "qdrant --uri") | tail -1 | \
  awk '{printf "Qdrant RAM: %.0f MB\n", $2/1024}'
```

### 7.2 Backup

```bash
# Storage-Verzeichnis sichern
sudo tar -czf /backup/qdrant-$(date +%Y%m%d).tar.gz /var/lib/qdrant-qs

# Wiederherstellen
sudo systemctl stop qdrant-qs
sudo rm -rf /var/lib/qdrant-qs/*
sudo tar -xzf /backup/qdrant-20260602.tar.gz -C /
sudo systemctl start qdrant-qs
```

### 7.3 Qdrant aktualisieren

```bash
# Neue Version herunterladen
cd /tmp
curl -sL https://github.com/qdrant/qdrant/releases/download/v1.8.0/qdrant-x86_64-unknown-linux-gnu.tar.gz \
  -o qdrant.tar.gz
tar xzf qdrant.tar.gz

# Service stoppen, Binary ersetzen, starten
sudo systemctl stop qdrant-qs
sudo mv qdrant /usr/local/bin/qdrant
sudo chmod +x /usr/local/bin/qdrant
sudo systemctl start qdrant-qs
```

---

## 8. Troubleshooting

| Problem                   | Ursache                 | Lösung                                            |
| ------------------------- | ----------------------- | ------------------------------------------------- |
| 🔴 Rotes Icon in Zoo Code | Qdrant nicht erreichbar | `systemctl restart qdrant-qs`                     |
| 🔴 Rotes Icon             | nomic-embed-text fehlt  | `ollama pull nomic-embed-text`                    |
| Gelbes Icon bleibt        | Indexierung hängt       | Zoo Code neu starten, Index clearen               |
| "Connection refused"      | Port 6333 nicht offen   | `ss -tlnp \| grep 6333` prüfen                    |
| Qdrant startet nicht      | Port bereits belegt     | `lsof -i :6333` – anderen Prozess stoppen         |
| "Out of memory"           | Collection zu groß      | `MemoryMax=512M` erhöhen oder `.rooignore` nutzen |
| Langsame Indexierung      | Zu viele Dateien        | `.rooignore` für irrelevante Pfade nutzen         |

---

## 9. Sicherheit

- **Qdrant nur auf localhost:** `--uri http://127.0.0.1:6333` – kein öffentlicher Zugriff
- **Kein API-Key nötig:** Bei localhost-Betrieb ist keine Authentifizierung erforderlich
- **Firewall:** Port 6333 nicht öffentlich öffnen
- **Storage:** `/var/lib/qdrant-qs` mit `qdrant:qdrant` 700 Berechtigungen
- **Embeddings:** Mathematische Einweg-Repräsentationen – kein Quellcode rekonstruierbar

---

## 10. Deployment über GitHub Actions

Die Qdrant-Installation ist Teil des automatisierten Deployments:

```yaml
# In .github/workflows/deploy-qs-vps.yml
Steps: 5. Sync Repository to VPS
  6. Run Master-Orchestrator # → deploy-qdrant-qs.sh
```

Das Skript [`scripts/qs/deploy-qdrant-qs.sh`](../../scripts/qs/deploy-qdrant-qs.sh) ist idempotent – es erkennt bestehende Installationen und überspringt diese.

---

## 11. Referenzen

- [UC1: Qdrant Codebase-Indexierung](uc1-qdrant-codebase-indexing.md)
- [OLLAMA Installation & Konfiguration](installation-ollama-vps.md)
- [LLM-Gesamtkonzept](concept_llm_usage.md)
- [Qdrant Deployment (Archiv)](../deployment/vps-deployment-qdrant.md)

---

**Erstellt:** 2026-06-02  
**Autor:** Zoo (AI Assistant)  
**Nächste Überprüfung:** 2026-09-02
