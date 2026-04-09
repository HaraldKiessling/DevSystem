# Qdrant Vektordatenbank - VPS Installation

**Installationsdatum:** 2026-04-09  
**Version:** Qdrant 1.7.4  
**Installationsart:** Native Binary (kein Docker)  
**Server:** IONOS Ubuntu VPS (100.100.221.56)

## Übersicht

Qdrant wurde als native Vektordatenbank für KI/RAG-Anwendungen auf dem VPS installiert. Die Installation erfolgte mit minimaler Konfiguration für lokalen Zugriff über localhost.

## Installationsdetails

### System-Informationen

- **OS:** Ubuntu 24.04.4 LTS (noble)
- **Architektur:** x86_64
- **Verfügbarer Speicher:** 176GB (/dev/vda1, 25% belegt)

### Installierte Komponenten

| Komponente | Pfad | Berechtigung |
|------------|------|--------------|
| Binary | `/opt/qdrant/qdrant` | root:root (755) |
| Konfiguration | `/opt/qdrant/config.yaml` | root:root (644) |
| Storage | `/var/lib/qdrant/storage` | qdrant:qdrant (755) |
| Snapshots | `/var/lib/qdrant/snapshots` | qdrant:qdrant (755) |
| Logs | `/var/log/qdrant` | qdrant:qdrant (755) |
| systemd Service | `/etc/systemd/system/qdrant.service` | root:root (644) |

### Konfiguration

**Netzwerk:**
- HTTP API: `127.0.0.1:6333`
- gRPC API: `127.0.0.1:6334`
- Nur localhost-Zugriff (keine externe Erreichbarkeit)

**Storage:**
- Storage-Pfad: `/var/lib/qdrant/storage`
- Snapshots: `/var/lib/qdrant/snapshots`
- Log-Level: INFO

**Performance-Einstellungen (minimal für Entwicklung):**
- `deleted_threshold`: 0.2
- `vacuum_min_vector_number`: 1000
- `default_segment_number`: 0
- HNSW Index `m`: 16
- HNSW Index `ef_construct`: 100

### Sicherheit

- **Dedizierter User:** `qdrant` (system user, no login)
- **systemd Hardening:**
  - `NoNewPrivileges=true`
  - `PrivateTmp=true`
  - `ProtectSystem=strict`
  - `ProtectHome=true`
  - Read-Write Zugriff nur auf `/var/lib/qdrant` und `/var/log/qdrant`
- **Ressourcen-Limits:**
  - `LimitNOFILE=65536` (Max. offene Dateien)

## Installation durchgeführt

### Phase 1: System-Vorbereitung ✅

```bash
# Prüfung durchgeführt
uname -m        # x86_64
lsb_release -a  # Ubuntu 24.04.4 LTS
df -h /opt      # 176GB verfügbar
```

### Phase 2: Qdrant Binary Installation ✅

```bash
sudo mkdir -p /opt/qdrant
cd /opt/qdrant
QDRANT_VERSION="v1.7.4"
wget "https://github.com/qdrant/qdrant/releases/download/${QDRANT_VERSION}/qdrant-x86_64-unknown-linux-gnu.tar.gz"
tar -xzf qdrant-x86_64-unknown-linux-gnu.tar.gz
chmod +x qdrant
rm qdrant-x86_64-unknown-linux-gnu.tar.gz
./qdrant --version  # qdrant 1.7.4
```

**Binary-Größe:** 49MB

### Phase 3: Storage und User ✅

```bash
# Verzeichnisse erstellt
sudo mkdir -p /var/lib/qdrant/storage
sudo mkdir -p /var/lib/qdrant/snapshots
sudo mkdir -p /var/log/qdrant

# User erstellt und Berechtigungen gesetzt
sudo useradd -r -s /bin/false -d /var/lib/qdrant qdrant
sudo chown -R qdrant:qdrant /var/lib/qdrant
sudo chown -R qdrant:qdrant /var/log/qdrant
sudo chown root:root /opt/qdrant/qdrant
```

### Phase 4: Konfiguration ✅

Datei `/opt/qdrant/config.yaml` wurde erstellt mit:
- Localhost-only Binding (127.0.0.1)
- HTTP Port 6333
- gRPC Port 6334
- Storage-Pfade
- Minimale Performance-Settings

### Phase 5: systemd-Service ✅

Service-Datei `/etc/systemd/system/qdrant.service` erstellt und aktiviert:

```bash
sudo systemctl daemon-reload
sudo systemctl enable qdrant
sudo systemctl start qdrant
```

## E2E-Validierung

### Test 1: Service Status ✅

```bash
$ systemctl status qdrant
● qdrant.service - Qdrant Vector Database
     Loaded: loaded (/etc/systemd/system/qdrant.service; enabled)
     Active: active (running) since Thu 2026-04-09 16:43:29 UTC
```

**Ergebnis:** Service läuft stabil als User `qdrant`

### Test 2: Port-Binding ✅

```bash
$ ss -tlnp | grep -E "6333|6334"
LISTEN 0 128   127.0.0.1:6334   0.0.0.0:*   users:(("qdrant",pid=491959))
LISTEN 0 1024  127.0.0.1:6333   0.0.0.0:*   users:(("qdrant",pid=491959))
```

**Ergebnis:** Beide Ports korrekt gebunden an localhost

### Test 3: HTTP API Root ✅

```bash
$ curl -s http://127.0.0.1:6333/
{"title":"qdrant - vector search engine","version":"1.7.4"}
```

**Ergebnis:** API antwortet korrekt

### Test 4: Health Endpoint ✅

```bash
$ curl -s http://127.0.0.1:6333/health
(HTTP 200 OK - leer wie erwartet)
```

**Ergebnis:** Health-Check erfolgreich

### Test 5: Collections List ✅

```bash
$ curl -s http://127.0.0.1:6333/collections
{"result":{"collections":[{"name":"ws-0e5ba2087ce23a04"}]},"status":"ok","time":4.807e-6}
```

**Ergebnis:** Collections-API funktioniert (Vorhandene Collection von Roo-Code erkannt)

### Test 6: Journal Logs ✅

```bash
$ sudo journalctl -u qdrant -n 20 --no-pager
Apr 09 16:43:29 ubuntu qdrant[491959]: Qdrant HTTP listening on 6333
Apr 09 16:43:29 ubuntu qdrant[491959]: Qdrant gRPC listening on 6334
```

**Ergebnis:** Service startet sauber, keine kritischen Fehler

### Test 7: Prozess-Validierung ✅

```bash
$ ps aux | grep '[q]drant'
qdrant  491959  1.9  ... /opt/qdrant/qdrant --config-path /opt/qdrant/config.yaml
```

**Ergebnis:** Prozess läuft korrekt als User `qdrant` (nicht root)

## Zusammenfassung

✅ **Installation erfolgreich abgeschlossen**

- Qdrant 1.7.4 läuft stabil auf dem VPS
- Alle E2E-Tests bestanden
- Service ist aktiviert (Autostart)
- Sicherheits-Hardening aktiv
- Nur localhost-Zugriff (127.0.0.1)
- Bereit für KI/RAG-Integration

## Zugriff auf Qdrant

### Von localhost (VPS selbst):

```bash
# HTTP API
curl http://127.0.0.1:6333/

# Collections abrufen
curl http://127.0.0.1:6333/collections

# Python SDK
from qdrant_client import QdrantClient
client = QdrantClient(host="localhost", port=6333)
```

### Service-Verwaltung:

```bash
# Status prüfen
sudo systemctl status qdrant

# Logs ansehen
sudo journalctl -u qdrant -f

# Service neu starten
sudo systemctl restart qdrant

# Service stoppen
sudo systemctl stop qdrant
```

## Performance & Ressourcen

- **Memory Usage:** ~20MB (bei Start)
- **CPU Usage:** Minimal im Idle
- **Startup Time:** ~500ms
- **Binary Size:** 49MB

## Bekannte Hinweise

1. **Static Web UI:** Die Web-UI ist nicht installiert (./static Ordner fehlt). Für Entwicklung nicht benötigt, API-Zugriff ist ausreichend.

2. **Hostname Warning:** `unable to resolve host ubuntu` - Kosmetisches Problem ohne funktionale Auswirkung.

3. **Init File Warning:** `Failed to create init file indicator: Read-only file system` - Aufgrund systemd-Hardening (ProtectSystem=strict), funktional nicht relevant.

## Nächste Schritte

- [ ] Integration mit Ollama für lokale Embeddings
- [ ] Integration mit OpenRouter für Cloud-Embeddings
- [ ] RAG-Pipeline Tests durchführen
- [ ] Backup-Strategie für Vektordaten entwickeln
- [ ] Monitoring für Qdrant einrichten

## Dokumentation

- **Offizielle Docs:** https://qdrant.tech/documentation/
- **GitHub:** https://github.com/qdrant/qdrant
- **API Reference:** https://qdrant.tech/documentation/api-reference/
