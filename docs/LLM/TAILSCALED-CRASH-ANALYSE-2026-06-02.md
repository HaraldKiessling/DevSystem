# Tailscaled Crash-Loop Analyse - 2026-06-02

**Datum:** 2026-06-02 05:10 UTC  
**System:** DevSystem (lokales System)  
**Problem:** Massive Log-Explosion durch tailscaled Crash-Loop

---

## Problem-Zusammenfassung

### Symptome

- **Festplatte zu 100% voll** (232 GB / 232 GB)
- `/var/log/syslog` war **174 GB groß** (vor Bereinigung)
- Ollama-Installation schlug fehl: "No space left on device"

### Root Cause

**tailscaled crasht kontinuierlich mit SIGABRT**

---

## Analyse-Daten

### Log-Statistik (letzte 2 Tage)

| Quelle                             | Anzahl Einträge | Anteil |
| ---------------------------------- | --------------- | ------ |
| **rsyslogd**                       | 226.230         | ~30%   |
| **tailscaled (verschiedene PIDs)** | ~700.000+       | ~70%   |

**Beispiel-PIDs mit hoher Aktivität:**

- `tailscaled[1746221]`: 44.996 Einträge
- `tailscaled[1580004]`: 44.994 Einträge
- `tailscaled[1498794]`: 44.994 Einträge
- `tailscaled[1462632]`: 42.490 Einträge
- ... (20+ verschiedene PIDs)

### Systemd Restart-Counter

```
Scheduled restart job, restart counter is at 1778
```

**Bedeutung:** tailscaled wurde in den letzten 2 Tagen **1778 Mal neu gestartet**!

### Crash-Muster

```
SIGABRT: abort
PC=0x493361 m=0 sigcode=0

goroutine 0 gp=0x1f4a460 m=0 mp=0x1f4b960 [idle]:
runtime.futex(0x1f4bab8, 0x80, 0x0, 0x0, 0x0, 0x0)
```

**Fehlertyp:** Go Runtime Panic/Abort (SIGABRT)

---

## Konfiguration

### Tailscale Version

```
1.98.4
tailscale commit: 9e69045b291a7cb1edc714442d68e83b95d05e6b
go version: go1.26.3 (tailscale/go e877d97384)
```

### Systemd Override (`/etc/systemd/system/tailscaled.service.d/override.conf`)

```ini
[Service]
# Verhindert mehrfache Instanzen beim Start
ExecStartPre=/bin/bash -c 'SYSTEMD_PID=$(systemctl show tailscaled --property=MainPID --value 2>/dev/null || echo 0); for PID in $(pgrep tailscaled 2>/dev/null); do [ "$PID" != "$SYSTEMD_PID" ] && kill "$PID" 2>/dev/null; done; sleep 1; true'

# Automatischer Neustart bei Absturz
Restart=on-failure
RestartSec=10s
RestartPreventExitStatus=0

# Ressourcenlimits
MemoryMax=256M
MemorySwapMax=0
TasksMax=50

# Watchdog
WatchdogSec=60s

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=tailscaled
```

**Problem:** `Restart=on-failure` + `RestartSec=10s` führt zu endloser Crash-Loop!

---

## Auswirkungen

### Speicherverbrauch

- **Vor Bereinigung:** 232 GB / 232 GB (100%)
- **Nach Bereinigung:** 58 GB / 232 GB (26%)
- **Freigegebener Speicher:** 174 GB

### Log-Dateien

```bash
-rw-r----- 1 syslog adm 174G Jun  2 05:04 /var/log/syslog (vor truncate)
-rw-r----- 1 syslog adm 549M Jun  2 05:07 /var/log/syslog (nach truncate)
-rw-r----- 1 syslog adm 7.3M May 31 00:00 /var/log/syslog.1
```

**Wachstumsrate:** ~87 GB/Tag (bei aktiver Crash-Loop)

---

## Sofortmaßnahmen (durchgeführt)

### 1. Log-Bereinigung

```bash
sudo truncate -s 0 /var/log/syslog
sudo systemctl restart rsyslog
```

**Ergebnis:** 174 GB freigegebener Speicher

### 2. Ollama Installation

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama pull nomic-embed-text:latest
```

**Status:** ✅ Erfolgreich installiert

---

## Empfohlene Lösungen

### Option 1: Tailscaled Neuinstallation (empfohlen)

```bash
# 1. Service stoppen
sudo systemctl stop tailscaled

# 2. Tailscale deinstallieren
sudo apt remove --purge tailscale -y

# 3. State-Dateien löschen
sudo rm -rf /var/lib/tailscale

# 4. Neuinstallation
curl -fsSL https://tailscale.com/install.sh | sh

# 5. Neu authentifizieren
sudo tailscale up --auth-key=<AUTH_KEY>
```

### Option 2: Crash-Loop Mitigation

```bash
# Override anpassen: Längere Restart-Delays
sudo tee /etc/systemd/system/tailscaled.service.d/override.conf <<EOF
[Service]
Restart=on-failure
RestartSec=60s
StartLimitBurst=5
StartLimitIntervalSec=300s
MemoryMax=512M
MemorySwapMax=0
TasksMax=100
WatchdogSec=120s
EOF

sudo systemctl daemon-reload
sudo systemctl restart tailscaled
```

### Option 3: Log-Rotation konfigurieren

```bash
# /etc/logrotate.d/rsyslog anpassen
sudo tee /etc/logrotate.d/rsyslog <<EOF
/var/log/syslog
{
    rotate 3
    daily
    maxsize 1G
    missingok
    notifempty
    compress
    delaycompress
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}
EOF
```

---

## Monitoring

### Crash-Rate überwachen

```bash
# Restarts in letzter Stunde
journalctl -u tailscaled --since "1 hour ago" | grep -c "Scheduled restart"

# Aktuelle Restart-Counter
systemctl show tailscaled --property=NRestarts

# Log-Größe überwachen
watch -n 60 'du -sh /var/log/syslog'
```

### Alerts einrichten

```bash
# Cron-Job für tägliche Prüfung
cat > /etc/cron.daily/check-tailscaled-crashes <<'EOF'
#!/bin/bash
CRASHES=$(journalctl -u tailscaled --since "1 day ago" | grep -c "SIGABRT")
if [ "$CRASHES" -gt 10 ]; then
    echo "WARNING: tailscaled crashed $CRASHES times in last 24h" | logger -t tailscaled-monitor
fi
EOF
chmod +x /etc/cron.daily/check-tailscaled-crashes
```

---

## Nächste Schritte

1. **Sofort:** Tailscaled Neuinstallation durchführen (Option 1)
2. **Kurzfristig:** Log-Rotation konfigurieren (Option 3)
3. **Mittelfristig:** Monitoring einrichten
4. **Langfristig:** Auf neuere Tailscale-Version upgraden

---

## Referenzen

- Tailscale Version: 1.98.4
- Go Version: go1.26.3
- System: Ubuntu Linux 6.8
- Dokumentation: [`docs/operations/OLLAMA-PROD-SETUP.md`](../operations/OLLAMA-PROD-SETUP.md)
