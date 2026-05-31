# Maßnahmenplan: VPS-Freeze-Behebung - Konkrete Schritte

**Datum:** 2026-05-31  
**Zeitpunkt:** 15:31 UTC  
**Problem:** SSH-Daemon nicht erreichbar (seit 14:49 UTC, 42 Minuten Downtime)  
**Status:** 🔴 KRITISCH - Sofortige Intervention erforderlich

---

## Aktuelle Situation

### Symptome (verifiziert 15:18 UTC)

```
✅ ICMP Ping:     Funktioniert (0% loss, 1ms)
✅ HTTPS (9443):  Funktioniert (HTTP 302)
❌ SSH (22):      Connection timeout (10s)
✅ Tailscale:     Active, Direct Connection
```

**Diagnose:** SSH-spezifisches Problem, KEIN Netzwerk-Freeze

---

## Phase 1: Sofort-Diagnose (via IONOS Console)

### Schritt 1.1: IONOS Console öffnen

**URL:** https://my.ionos.de/ oder https://cloud.ionos.de/

**Navigation:**
1. Login mit Credentials
2. "Server & Cloud" → "Cloud Server"
3. Server "devsystem-vps" auswählen
4. **"Remote Console"** öffnen (VNC/KVM-Zugriff)

### Schritt 1.2: Login und Basis-Diagnose

```bash
# Login als root (Passwort eingeben)

# 1. SSH-Daemon-Status
systemctl status sshd
# Erwartung: active (running) ODER inactive/failed

# 2. SSH-Prozess prüfen
ps aux | grep sshd | grep -v grep
# Erwartung: Mindestens 1 Prozess (Master-Daemon)

# 3. SSH-Port prüfen
ss -tlnp | grep ':22'
# Erwartung: LISTEN auf 0.0.0.0:22 oder *:22

# 4. Prozess-State prüfen (D-State = uninterruptible sleep)
ps aux | awk '$8 == "D"'
# Falls sshd dabei: Reboot erforderlich
```

---

## Phase 2: Schnelle Reparatur-Versuche

### Versuch 2.1: SSH-Daemon neu starten

```bash
# Neustart
systemctl restart sshd

# Status prüfen
systemctl status sshd

# Port prüfen
ss -tlnp | grep ':22'

# Von extern testen (anderes Terminal)
# ssh root@devsystem-vps.tailcfea8a.ts.net
```

**Falls erfolgreich:** → Weiter zu Phase 3 (Ursachenanalyse)  
**Falls nicht erfolgreich:** → Weiter zu Versuch 2.2

### Versuch 2.2: Overcommit-Schutz deaktivieren

```bash
# Aktuellen Wert prüfen
sysctl vm.overcommit_memory
# Erwartung: 2 (aus Branch-Reparaturen)

# Commit-Ratio prüfen
awk '/CommitLimit/ {limit=$2} /Committed_AS/ {commit=$2} END {print "Commit: " commit " / Limit: " limit " = " (commit/limit*100) "%"}' /proc/meminfo

# KRITISCH: Overcommit-Schutz temporär deaktivieren
sysctl -w vm.overcommit_memory=0

# SSH neu starten
systemctl restart sshd

# Von extern testen
```

**Falls erfolgreich:** → **vm.overcommit_memory=2 war die Ursache!**  
**Falls nicht erfolgreich:** → Weiter zu Versuch 2.3

### Versuch 2.3: Memory-Druck reduzieren

```bash
# Memory-Status prüfen
free -h

# Top Memory-Verbraucher
ps aux --sort=-%mem | head -20

# Docker-Container stoppen (temporär)
docker stop $(docker ps -q)

# SSH neu starten
systemctl restart sshd

# Von extern testen
```

**Falls erfolgreich:** → Docker-Container verursachen Speicherdruck  
**Falls nicht erfolgreich:** → Weiter zu Versuch 2.4

### Versuch 2.4: Firewall-Regeln prüfen

```bash
# UFW-Status
ufw status verbose

# iptables-Regeln für SSH
iptables -L INPUT -v -n | grep -E "22|ssh"

# nftables-Regeln (falls verwendet)
nft list ruleset | grep -E "22|ssh"

# Falls SSH blockiert: Regel temporär entfernen
ufw allow 22/tcp
# ODER
iptables -I INPUT -p tcp --dport 22 -j ACCEPT

# Von extern testen
```

### Versuch 2.5: PAM-Konfiguration prüfen

```bash
# PAM-Fehler in Logs
tail -50 /var/log/auth.log | grep -i "pam\|authentication"

# Bekanntes Problem: pam_lastlog.so fehlt
grep pam_lastlog /etc/pam.d/sshd

# Falls vorhanden und fehlt: Auskommentieren
sed -i 's/^session.*pam_lastlog.so/#&/' /etc/pam.d/sshd

# SSH neu starten
systemctl restart sshd
```

---

## Phase 3: Ursachenanalyse (nach erfolgreicher Reparatur)

### Schritt 3.1: Logs analysieren

```bash
# SSH-Logs seit 14:49 UTC
journalctl -u sshd --since "2026-05-31 14:49:00" --no-pager

# Auth-Logs
tail -100 /var/log/auth.log | grep -A 5 -B 5 "14:49\|14:50\|14:51"

# Kernel-Logs (OOM, Fork-Fehler)
dmesg | grep -i "oom\|fork\|memory" | tail -20

# systemd-Logs
journalctl -p err --since "2026-05-31 14:49:00" --no-pager
```

### Schritt 3.2: Memory-Analyse

```bash
# Commit-Ratio-Historie (falls sar verfügbar)
sar -r | tail -20

# Aktuelle Memory-Konfiguration
sysctl -a | grep -E "overcommit|oom"

# Prozess-Memory-Limits
systemctl show sshd | grep -i memory

# Docker-Memory-Nutzung
docker stats --no-stream
```

### Schritt 3.3: Fork-Fehler-Analyse

```bash
# Fork-Fehler in Logs
grep -i "fork\|cannot allocate memory" /var/log/auth.log | tail -20
grep -i "fork\|cannot allocate memory" /var/log/syslog | tail -20

# Prozess-Limits
ulimit -a

# systemd-Limits für sshd
systemctl show sshd | grep -i limit
```

---

## Phase 4: Permanente Lösung implementieren

### Lösung 4.1: Falls vm.overcommit_memory=2 die Ursache war

```bash
# Overcommit-Schutz dauerhaft deaktivieren
cat > /etc/sysctl.d/99-overcommit-fix.conf << 'EOF'
# Overcommit-Schutz deaktiviert (verursachte SSH-Ausfälle)
vm.overcommit_memory = 0
# Heuristic overcommit (Standard)
EOF

# Laden
sysctl -p /etc/sysctl.d/99-overcommit-fix.conf

# Alte Konfiguration entfernen
rm -f /etc/sysctl.d/99-freeze-prevention.conf

# Verifizieren
sysctl vm.overcommit_memory
```

### Lösung 4.2: sshd-Watchdog implementieren

```bash
# Watchdog-Script erstellen
cat > /usr/local/bin/sshd-watchdog.sh << 'EOF'
#!/bin/bash
# sshd-Watchdog: Prüft und repariert sshd alle 2 Minuten

LOG="/var/log/sshd-watchdog.log"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Test 1: systemd-Status
if ! systemctl is-active --quiet sshd; then
    echo "$TIMESTAMP CRITICAL: sshd inactive, restarting" >> "$LOG"
    systemctl restart sshd
    exit 0
fi

# Test 2: Port 22 lauscht
if ! ss -tlnp | grep -q ':22.*sshd'; then
    echo "$TIMESTAMP CRITICAL: sshd not listening on port 22, restarting" >> "$LOG"
    systemctl restart sshd
    exit 0
fi

# Test 3: Prozess existiert
if ! pgrep -x sshd > /dev/null; then
    echo "$TIMESTAMP CRITICAL: sshd process not found, restarting" >> "$LOG"
    systemctl restart sshd
    exit 0
fi

# Test 4: Prozess nicht in D-State
if ps aux | awk '$8 == "D"' | grep -q sshd; then
    echo "$TIMESTAMP CRITICAL: sshd in D-State, reboot required" >> "$LOG"
    # Optional: Automatischer Reboot
    # shutdown -r +1 "sshd in D-State, automatic reboot"
    exit 1
fi

# Alles OK
echo "$TIMESTAMP OK: sshd healthy" >> "$LOG"
EOF

chmod +x /usr/local/bin/sshd-watchdog.sh

# Cron-Job: Alle 2 Minuten
cat > /etc/cron.d/sshd-watchdog << 'EOF'
# sshd-Watchdog: Alle 2 Minuten
*/2 * * * * root /usr/local/bin/sshd-watchdog.sh
EOF

# Test
/usr/local/bin/sshd-watchdog.sh
cat /var/log/sshd-watchdog.log
```

### Lösung 4.3: sshd-Härtung

```bash
# systemd-Override für sshd
mkdir -p /etc/systemd/system/sshd.service.d

cat > /etc/systemd/system/sshd.service.d/override.conf << 'EOF'
[Service]
# Automatischer Neustart bei Absturz
Restart=on-failure
RestartSec=10s

# Memory-Limit (verhindert OOM)
MemoryMax=512M

# Watchdog (systemd überwacht Prozess)
WatchdogSec=60s

# Prozess-Limits erhöhen
LimitNOFILE=65536
LimitNPROC=4096
EOF

# Reload und Neustart
systemctl daemon-reload
systemctl restart sshd

# Verifizieren
systemctl show sshd | grep -E "Restart=|MemoryMax=|WatchdogSec="
```

### Lösung 4.4: Alternative SSH-Zugänge

```bash
# Option 1: SSH auf alternativem Port
# /etc/ssh/sshd_config
echo "Port 2222" >> /etc/ssh/sshd_config
systemctl restart sshd

# UFW-Regel
ufw allow 2222/tcp

# Option 2: Tailscale SSH (empfohlen)
tailscale up --ssh

# Test von extern:
# ssh root@devsystem-vps.tailcfea8a.ts.net
```

---

## Phase 5: Validierung

### Schritt 5.1: Sofort-Tests

```bash
# Test 1: SSH von extern
ssh root@devsystem-vps.tailcfea8a.ts.net "echo 'SSH OK'"

# Test 2: sshd-Status
systemctl status sshd

# Test 3: Port 22 lauscht
ss -tlnp | grep ':22'

# Test 4: Watchdog läuft
cat /var/log/sshd-watchdog.log | tail -5

# Test 5: Memory-Konfiguration
sysctl vm.overcommit_memory
```

### Schritt 5.2: Stress-Test

```bash
# Simuliere Memory-Druck
stress-ng --vm 2 --vm-bytes 2G --timeout 60s &

# Während Stress: SSH-Test
ssh root@devsystem-vps.tailcfea8a.ts.net "echo 'SSH OK under load'"

# Watchdog-Log prüfen
tail -f /var/log/sshd-watchdog.log
```

### Schritt 5.3: 24h-Monitoring

```bash
# Kontinuierliches SSH-Monitoring
cat > /usr/local/bin/ssh-availability-monitor.sh << 'EOF'
#!/bin/bash
while true; do
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    if ss -tlnp | grep -q ':22.*sshd'; then
        echo "$TIMESTAMP SSH_OK" >> /var/log/ssh-availability.log
    else
        echo "$TIMESTAMP SSH_DOWN" >> /var/log/ssh-availability.log
    fi
    sleep 60
done
EOF

chmod +x /usr/local/bin/ssh-availability-monitor.sh

# Als systemd-Service
cat > /etc/systemd/system/ssh-availability-monitor.service << 'EOF'
[Unit]
Description=SSH Availability Monitor
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/ssh-availability-monitor.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now ssh-availability-monitor.service
```

---

## Phase 6: Dokumentation

### Schritt 6.1: Incident-Report erstellen

```bash
cat > /root/INCIDENT-REPORT-SSH-OUTAGE-2026-05-31.md << 'EOF'
# Incident Report: SSH-Ausfall 2026-05-31

**Zeitraum:** 14:49 - 15:XX UTC (XX Minuten)
**Ursache:** [HIER EINTRAGEN nach Analyse]
**Lösung:** [HIER EINTRAGEN]
**Präventivmaßnahmen:** [HIER EINTRAGEN]

## Timeline
- 14:49 UTC: Erster SSH-Timeout beobachtet
- 15:XX UTC: Reparatur via IONOS Console
- 15:XX UTC: SSH wiederhergestellt

## Root Cause
[DETAILLIERTE ANALYSE HIER]

## Lessons Learned
1. [HIER EINTRAGEN]
2. [HIER EINTRAGEN]

## Implementierte Maßnahmen
- [ ] sshd-Watchdog
- [ ] vm.overcommit_memory angepasst
- [ ] sshd-Härtung
- [ ] Alternative Zugänge

EOF
```

---

## Checkliste: Abschluss

- [ ] SSH von extern erreichbar
- [ ] sshd-Watchdog läuft
- [ ] vm.overcommit_memory korrekt konfiguriert
- [ ] sshd-Härtung implementiert
- [ ] Alternative Zugänge eingerichtet
- [ ] 24h-Monitoring aktiv
- [ ] Incident-Report erstellt
- [ ] Dokumentation aktualisiert

---

## Notfall-Kontakte

- **IONOS Support:** https://www.ionos.de/hilfe/
- **Tailscale Admin:** https://login.tailscale.com/admin/machines
- **GitHub Issues:** https://github.com/HaraldKiessling/DevSystem/issues

---

**Erstellt:** 2026-05-31T15:31 UTC  
**Status:** 🔴 Bereit zur Ausführung  
**Nächster Schritt:** IONOS Console öffnen und Phase 1 starten