# devsystem-vps Offline - Troubleshooting Report

**Datum:** 2026-05-31  
**Problem:** VPS über Tailscale nicht erreichbar  
**URL:** https://devsystem-vps.tailcfea8a.ts.net:9443  
**Status:** 🔴 Offline

---

## Problem-Beschreibung

Der devsystem-vps ist über Tailscale nicht mehr erreichbar:

```
100.100.221.56  devsystem-vps  HaraldKiessling@  linux  
  active; relay "fra"; offline, last seen 3m ago
```

### Symptome

1. **SSH-Verbindung:** Connection timeout
2. **Ping:** Keine Antwort
3. **Tailscale-Status:** "offline, last seen 3m ago"
4. **Web-Interface:** Nicht erreichbar

---

## Diagnose

### Durchgeführte Tests

```bash
# SSH-Test
ssh root@devsystem-vps.tailcfea8a.ts.net
# Ergebnis: Connection timed out

# Ping-Test
ping 100.100.221.56
# Ergebnis: Timeout

# Tailscale-Status
tailscale status
# Ergebnis: devsystem-vps offline
```

### Mögliche Ursachen

1. **VPS komplett offline**
   - Server heruntergefahren
   - Hardware-Problem beim Hoster
   - Stromausfall im Rechenzentrum

2. **Tailscale-Dienst gestoppt**
   - tailscaled Service crashed
   - OOM-Killer hat Prozess beendet
   - Systemd-Problem

3. **Netzwerk-Problem**
   - Netzwerk-Interface down
   - Firewall blockiert Tailscale
   - Routing-Problem

4. **Speicher-Problem (OOM)**
   - Bekanntes Problem: VPS hatte bereits OOM-Events
   - Ollama Container könnte zu viel RAM verbrauchen
   - Siehe: [OLLAMA-PROD-DEPLOYMENT-2026-05-24.md](../operations/OLLAMA-PROD-DEPLOYMENT-2026-05-24.md)

---

## Lösungsansätze

### Option 1: IONOS Cloud Panel (Empfohlen)

**Zugriff über IONOS Cloud Panel:**

1. Login: https://my.ionos.de/ oder https://cloud.ionos.de/
2. "Server & Cloud" → "Cloud Server" auswählen
3. Server "devsystem-vps" auswählen
4. "Remote Console" öffnen (VNC/KVM-Zugriff)

**Im Console-Fenster:**

```bash
# 1. Login als root
# 2. Diagnose-Skript ausführen
cd /root/work/DevSystem
bash scripts/prod/diagnose-and-fix-devsystem-vps.sh
```

Das Skript wird:
- System-Status prüfen
- Alle Services diagnostizieren
- Automatische Reparatur anbieten

### Option 2: Server-Neustart über IONOS

Falls Console nicht funktioniert:

1. IONOS Cloud Panel öffnen
2. Server "devsystem-vps" auswählen
3. "Aktionen" → "Neustart" klicken
4. 2-3 Minuten warten
5. Tailscale-Status prüfen: `tailscale status`

**Nach Neustart:**

```bash
# Warten bis VPS wieder online
tailscale status | grep devsystem-vps

# Dann SSH-Verbindung testen
ssh root@devsystem-vps.tailcfea8a.ts.net

# Services prüfen
systemctl status tailscaled caddy code-server@root
docker ps
```

### Option 3: Rescue-System (Notfall)

Falls Server nicht bootet:

1. IONOS Cloud Panel → Server auswählen
2. "Rescue-Modus" aktivieren (falls verfügbar)
3. Alternativ: ISO-Image mounten für Recovery
4. Im Rescue-System:
   - Logs prüfen: `/mnt/var/log/syslog`
   - Filesystem-Check: `fsck /dev/sda1`
   - Probleme beheben

---

## Reparatur-Skript

Erstellt: [`scripts/prod/diagnose-and-fix-devsystem-vps.sh`](../../scripts/prod/diagnose-and-fix-devsystem-vps.sh)

**Features:**
- ✅ Vollständige System-Diagnose
- ✅ Service-Status-Checks (Tailscale, Caddy, Code-Server, Ollama)
- ✅ Speicher-Analyse (OOM-Detection)
- ✅ Netzwerk-Tests
- ✅ Automatische Reparatur-Option
- ✅ Interaktive Ausführung

**Verwendung:**

```bash
# Über Hetzner Console
cd /root/work/DevSystem
bash scripts/prod/diagnose-and-fix-devsystem-vps.sh

# Automatische Reparatur (non-interactive)
bash scripts/prod/diagnose-and-fix-devsystem-vps.sh <<< "j"
```

---

## Präventive Maßnahmen

### 1. Monitoring einrichten

**Empfehlung:** Uptime-Monitoring für devsystem-vps

Optionen:
- UptimeRobot (kostenlos, 5min Intervall)
- Healthchecks.io (kostenlos, Ping-basiert)
- Tailscale Health Checks

**Setup:**

```bash
# Healthcheck-Endpoint in Caddy
# Bereits vorhanden: https://devsystem-vps.tailcfea8a.ts.net:9443/health
```

### 2. Auto-Restart für Services

**Bereits konfiguriert:**

```bash
# Tailscale
systemctl enable tailscaled

# Caddy
systemctl enable caddy

# Code-Server
systemctl enable code-server@root

# Ollama (Docker)
docker update --restart=unless-stopped ollama
```

### 3. OOM-Protection verbessern

**Memory-Limits prüfen:**

```bash
# Ollama Container Limits
docker inspect ollama | grep -A 5 Memory

# Sollte sein:
# Memory: 4.5 GB
# MemorySwap: 5.5 GB
```

**Swap erhöhen (falls nötig):**

```bash
# Aktuellen Swap prüfen
free -h

# Swap-File vergrößern (auf 4 GB)
sudo swapoff -a
sudo dd if=/dev/zero of=/swapfile bs=1M count=4096
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### 4. Automatisches Backup

**Backup-Skript:** [`scripts/qs/backup-qs-system.sh`](../../scripts/qs/backup-qs-system.sh)

```bash
# Cronjob einrichten (täglich um 3 Uhr)
crontab -e

# Hinzufügen:
0 3 * * * /root/work/DevSystem/scripts/qs/backup-qs-system.sh
```

---

## Verifikation nach Reparatur

**Checkliste:**

```bash
# 1. Tailscale erreichbar
tailscale status | grep devsystem-vps
# Erwartung: "active; direct" oder "active; relay"

# 2. SSH funktioniert
ssh root@devsystem-vps.tailcfea8a.ts.net "echo 'SSH OK'"

# 3. Web-Interface erreichbar
curl -k https://devsystem-vps.tailcfea8a.ts.net:9443/health
# Erwartung: HTTP 200

# 4. Services laufen
ssh root@devsystem-vps.tailcfea8a.ts.net "systemctl is-active tailscaled caddy code-server@root"
# Erwartung: 3x "active"

# 5. Ollama läuft
ssh root@devsystem-vps.tailcfea8a.ts.net "docker ps | grep ollama"
# Erwartung: Container "ollama" mit Status "Up"
```

---

## Nächste Schritte

1. **Sofort:** Zugriff über Hetzner Console herstellen
2. **Diagnose:** Reparatur-Skript ausführen
3. **Reparatur:** Services neu starten
4. **Verifikation:** Alle Checks durchführen
5. **Monitoring:** Uptime-Monitoring einrichten
6. **Dokumentation:** Ursache dokumentieren (Update dieses Dokuments)

---

## Kontakt & Ressourcen

- **Hetzner Cloud Console:** https://console.hetzner.cloud/
- **Tailscale Admin:** https://login.tailscale.com/admin/machines
- **Diagnose-Skript:** [`scripts/prod/diagnose-and-fix-devsystem-vps.sh`](../../scripts/prod/diagnose-and-fix-devsystem-vps.sh)
- **OOM-Report:** [OLLAMA-PROD-DEPLOYMENT-2026-05-24.md](../operations/OLLAMA-PROD-DEPLOYMENT-2026-05-24.md)

---

**Status:** 🔴 Warte auf Hetzner Console Zugriff  
**Erstellt:** 2026-05-31  
**Letztes Update:** 2026-05-31
