# Kritische Analyse: VPS-Freeze-Reparaturen und aktuelle Systeminstabilität

**Datum:** 2026-05-31  
**Analysezeitpunkt:** 15:02 UTC  
**Analysierter Branch:** `docs/vps-freeze-analyse-2026-05-31`  
**Aktueller Systemzustand:** Partieller Service-Ausfall

---

## Executive Summary

**Bewertung:** ⚠️ **Die implementierten Reparaturmaßnahmen haben das Grundproblem NICHT gelöst**

### Kritische Befunde

1. **HTTPS funktioniert (Port 9443)** → Caddy läuft
2. **SSH funktioniert NICHT (Port 22)** → sshd crashed oder blockiert
3. **Tailscale zeigt "active"** → WireGuard-Interface funktioniert
4. **ICMP Ping funktioniert** → Netzwerk-Layer OK
5. **Selektiver Port-Ausfall** → Dienst-spezifisches Problem, KEIN Netzwerk-Freeze

**Schlussfolgerung:** Das System zeigt **identische Symptome wie vor den Reparaturen** (14:49 UTC). Die Freeze-Problematik ist **NICHT behoben**, sondern **reproduziert sich**.

---

## 1. Analyse der implementierten Maßnahmen

### 1.1 Was wurde implementiert (laut Branch-Analyse)

| Maßnahme | Implementiert | Validiert | Wirksamkeit |
|----------|---------------|-----------|-------------|
| **M1:** `tailscale.conf` entfernt | ✅ 14:37 UTC | ✅ | ⚠️ Symptomatisch |
| **M2:** `tailscale set --accept-dns=false` | ✅ 14:37 UTC | ✅ | ⚠️ Symptomatisch |
| **M3:** `/etc/resolv.conf` Symlink gesichert | ✅ 14:37 UTC | ✅ | ⚠️ Symptomatisch |
| **M4:** tailscaled Memory-Limit (256MB) | ✅ 14:37 UTC | ✅ | ❓ Ungetestet |
| **M5:** `vm.overcommit_memory=2` | ✅ 14:37 UTC | ✅ | ❓ Ungetestet |
| **M6:** systemd-Watchdog (60s) | ✅ 14:37 UTC | ✅ | ❌ **Versagt** |
| **M7:** Post-Reboot-Check Service | ✅ 14:37 UTC | ✅ | ❓ Nicht getriggert |
| **M8:** Cron-Watchdog (5min) | ✅ 14:37 UTC | ✅ | ❌ **Versagt** |
| **M9:** Kernel Panic Recovery (30s) | ✅ 14:37 UTC | ✅ | ❓ Nicht getriggert |

**Validierung:** 10/10 Tests bestanden um 14:54 UTC  
**Realität:** System zeigt erneuten Ausfall um 14:49 UTC (5 Minuten nach Validierung!)

---

## 2. Root-Cause-Analyse: Warum die Reparaturen versagten

### 2.1 Fehldiagnose: DNS-Problem als Hauptursache

**Annahme im Branch:**
> "Primärursache: Gleichzeitiger Zugriff mehrerer tailscaled-Prozesse auf WireGuard-Kernel-Ressourcen"

**Realität:**
- Die DNS-Konfigurationsprobleme waren **Symptom**, nicht **Ursache**
- Das Entfernen von `tailscale.conf` behebt NICHT die Kernel-Deadlock-Problematik
- Der manuelle `tailscaled`-Start war ein **einmaliges Ereignis** (13:56-14:02 UTC)
- Das aktuelle Problem (15:02 UTC) tritt **ohne manuellen tailscaled-Start** auf

### 2.2 Watchdog-Versagen

**Implementiert:**
- systemd-Watchdog: 60 Sekunden
- Cron-Watchdog: Alle 5 Minuten
- Kernel Panic Recovery: 30 Sekunden

**Problem:**
- SSH-Ausfall seit 14:49 UTC (13 Minuten)
- Cron-Watchdog hätte 2x laufen müssen (14:50, 14:55, 15:00)
- **Kein automatischer Recovery erfolgt**

**Mögliche Ursachen:**
1. **Cron-Daemon selbst crashed** → Watchdog läuft nicht
2. **Watchdog-Script kann nicht ausführen** → Ressourcen-Deadlock
3. **Watchdog erkennt Problem nicht** → Falsche Prüflogik
4. **systemd-Watchdog greift nicht** → sshd sendet kein Watchdog-Signal

### 2.3 Selektiver Service-Ausfall: Neue Erkenntnisse

**Beobachtung:**
```
HTTPS (Caddy, Port 9443):  ✅ Funktioniert (HTTP 302)
SSH (sshd, Port 22):       ❌ Connection timeout
Tailscale (WireGuard):     ✅ Active, Direct Connection
ICMP Ping:                 ✅ Funktioniert (23-46ms)
```

**Interpretation:**
- **KEIN Netzwerk-Freeze** (Caddy antwortet)
- **KEIN Kernel-Deadlock** (WireGuard funktioniert)
- **KEIN kompletter System-Freeze** (HTTPS-Requests werden verarbeitet)
- **Spezifisches sshd-Problem** → Prozess crashed, hängt oder ist blockiert

**Hypothese:** sshd-Daemon ist in einem **uninterruptible sleep** (D-State) oder wurde vom **OOM-Killer beendet**

---

## 3. Kritische Schwachstellen der Reparaturmaßnahmen

### 3.1 Symptom-Behandlung statt Root-Cause-Behebung

| Maßnahme | Behandelt | Behebt nicht |
|----------|-----------|--------------|
| DNS-Config-Fix | DNS-Auflösungsfehler | Kernel-Ressourcenkonflikte |
| `accept-dns=false` | Tailscale SERVFAIL-Logs | Prozess-Deadlocks |
| Memory-Limits | Einzelprozess-OOM | System-weite Speicherprobleme |
| Watchdogs | Erkennung von Ausfällen | **Verhinderung** von Ausfällen |

**Problem:** Alle Maßnahmen sind **reaktiv** (erkennen und beheben), nicht **präventiv** (verhindern).

### 3.2 Unvollständige OOM-Analyse

**Aus dem Branch:**
> "Hypothese B: OOM-Kill durch Speicherüberlastung (Wahrscheinlichkeit: 45%)"
> "Keine OOM-Kill-Einträge in kern.log oder journalctl gefunden"

**Kritik:**
- OOM-Analyse basiert auf **einem einzigen Zeitpunkt** (nach Reboot)
- **Keine kontinuierliche Überwachung** vor dem Freeze
- `%commit = 105,8%` ist **kritisch**, wurde aber als "beitragender Faktor" abgetan
- `vm.overcommit_memory=2` wurde implementiert, aber **Auswirkungen nicht getestet**

**Fehlende Analyse:**
- Welcher Prozess verursacht den hohen Commit?
- Wie verhält sich das System bei `overcommit_memory=2` unter Last?
- Können kritische Prozesse (sshd, systemd) bei Speicherdruck starten?

### 3.3 Fehlende Firewall-Analyse

**Aus dem Branch:**
> "UFW blockierte UDP-Pakete von 77.21.242.136 (Tailscale-Relay-IP)"

**Nicht analysiert:**
- Blockiert UFW auch TCP-Pakete?
- Gibt es Rate-Limiting-Regeln für SSH?
- Kann UFW selbst in einen fehlerhaften Zustand geraten?

**Aktuelles Symptom:** SSH timeout, HTTPS funktioniert → **Selektive Port-Blockierung möglich**

### 3.4 Keine Analyse der Docker-Container-Last

**Aus früherer Analyse (14:11 UTC):**
- 17 Docker-Container laufen
- Top Memory-Verbraucher:
  - open_webui: 816 MB
  - openhands: 421 MB
  - code-server: 419 MB
  - ollama runner: 391 MB (mit 297% CPU!)

**Nicht analysiert im Freeze-Branch:**
- Können Docker-Container sshd blockieren?
- Gibt es cgroup-Limits, die sshd beeinflussen?
- Verursacht Docker-Netzwerk-Overhead Probleme?

---

## 4. Aktuelle Symptome: Detailanalyse

### 4.1 Zeitlinie des erneuten Ausfalls

| Zeit (UTC) | Ereignis | Status |
|------------|----------|--------|
| 14:11 | System vollständig online (nach Reboot) | ✅ |
| 14:37-14:52 | Reparaturmaßnahmen implementiert | 🔧 |
| 14:43 | System verifiziert: SSH + HTTPS OK | ✅ |
| 14:49 | **Erster SSH-Timeout beobachtet** | ⚠️ |
| 14:54 | Validierung: 10/10 Tests bestanden | ✅ (Falsch-positiv!) |
| 15:02 | **SSH weiterhin timeout, HTTPS OK** | 🔴 |

**Kritischer Zeitraum:** 14:43-14:49 UTC (6 Minuten)  
**Downtime:** 13 Minuten (14:49-15:02 UTC)

### 4.2 Selektive Erreichbarkeit: Diagnose

```
Layer 3 (Network):     ✅ ICMP Ping funktioniert
Layer 4 (Transport):   ⚠️ TCP Port 9443 OK, Port 22 NICHT
Layer 7 (Application): ✅ HTTPS/Caddy antwortet, SSH nicht
```

**Mögliche Ursachen (priorisiert):**

1. **sshd-Prozess crashed** (Wahrscheinlichkeit: 60%)
   - Prozess läuft nicht mehr
   - systemd hat nicht neu gestartet (Restart=on-failure greift nicht bei SIGKILL)
   - Watchdog erkennt es nicht (prüft nur `systemctl is-active`)

2. **sshd in D-State (uninterruptible sleep)** (Wahrscheinlichkeit: 25%)
   - Prozess wartet auf I/O (Disk, NFS, etc.)
   - Kann keine neuen Verbindungen annehmen
   - systemd-Watchdog erkennt es nicht (Prozess ist "aktiv")

3. **UFW/iptables blockiert SSH selektiv** (Wahrscheinlichkeit: 10%)
   - Rate-Limiting greift
   - Fehlerhafte Regel nach Netzwerkänderung
   - Tailscale-Routing-Problem

4. **PAM-Modul blockiert** (Wahrscheinlichkeit: 5%)
   - Aus früheren Logs: `PAM unable to dlopen(pam_lastlog.so)`
   - PAM-Stack könnte bei SSH-Auth hängen

---

## 5. Was die Reparaturen NICHT adressiert haben

### 5.1 Fehlende Diagnose-Tools

**Nicht implementiert:**
- Kontinuierliches Process-Monitoring (ps, top)
- Disk-I/O-Monitoring (iostat, iotop)
- Netzwerk-Connection-Tracking (ss, netstat)
- Kernel-Trace-Logging (ftrace, perf)

**Problem:** Ohne diese Tools kann der Watchdog **nicht erkennen**, warum sshd ausfällt.

### 5.2 Fehlende sshd-spezifische Härtung

**Nicht implementiert:**
- sshd-Watchdog (analog zu tailscaled)
- sshd Memory-Limits
- sshd Restart-Policy
- sshd-Logging-Erhöhung (LogLevel DEBUG)

**Problem:** sshd wird als "unkritisch" behandelt, obwohl es der **einzige Remote-Zugang** ist.

### 5.3 Fehlende Fallback-Zugänge

**Nicht implementiert:**
- Alternative SSH-Ports (z.B. 2222)
- Serial Console Monitoring
- Automatischer Reboot bei SSH-Ausfall > 10 Minuten
- Emergency-Shell via Tailscale (nicht-SSH-basiert)

**Problem:** Wenn SSH ausfällt, ist **kein Remote-Zugang** mehr möglich (außer IONOS Console).

---

## 6. Neue Root-Cause-Hypothese

### 6.1 Primärhypothese: Speicherdruck führt zu selektivem Service-Ausfall

**Evidenz:**
- `%commit = 105,8%` vor Freeze (kritisch!)
- `vm.overcommit_memory=2` wurde implementiert → **Speicher-Allokationen werden jetzt abgelehnt**
- sshd muss bei jedem Login **neue Prozesse forken** (fork() benötigt Speicher)
- Caddy ist **bereits gestartet** und muss nicht forken → funktioniert weiter

**Mechanismus:**
1. System läuft mit hohem Speicher-Commit (>100%)
2. `vm.overcommit_memory=2` wird aktiviert
3. Neue Speicher-Allokationen werden abgelehnt
4. sshd versucht, neue Session zu forken → **fork() schlägt fehl**
5. sshd kann keine neuen Verbindungen annehmen → **Connection timeout**
6. Caddy (bereits laufend) verarbeitet weiter Requests → **HTTPS funktioniert**

**Test:** Prüfe `/var/log/auth.log` auf sshd-Fork-Fehler

### 6.2 Sekundärhypothese: Docker cgroup-Limits beeinflussen Host-Prozesse

**Evidenz:**
- 17 Docker-Container mit Memory-Limits
- cgroup v2 kann Host-Prozesse beeinflussen
- sshd läuft außerhalb von Docker, aber im selben cgroup-Tree

**Mechanismus:**
- Docker-Container verbrauchen Speicher bis zu ihren Limits
- Kernel-cgroup-Accounting beeinflusst Host-Prozesse
- sshd kann nicht genug Speicher allokieren für neue Sessions

---

## 7. Kritische Bewertung: Wirksamkeit der Maßnahmen

### 7.1 Erfolgreiche Maßnahmen

| Maßnahme | Wirksamkeit | Bewertung |
|----------|-------------|-----------|
| DNS-Config-Fix | ✅ Wirksam | DNS-Auflösung funktioniert |
| `accept-dns=false` | ✅ Wirksam | Tailscale SERVFAIL gestoppt |
| Post-Reboot-Check | ✅ Wirksam | Wird nach Reboot ausgeführt |

### 7.2 Unwirksame Maßnahmen

| Maßnahme | Wirksamkeit | Grund |
|----------|-------------|-------|
| systemd-Watchdog (60s) | ❌ Unwirksam | Erkennt sshd-Ausfall nicht |
| Cron-Watchdog (5min) | ❌ Unwirksam | Läuft nicht oder erkennt Problem nicht |
| Memory-Limits (tailscaled) | ❓ Ungetestet | Betrifft nicht sshd |
| `vm.overcommit_memory=2` | ⚠️ **Kontraproduktiv** | **Verhindert möglicherweise sshd-Forks** |

### 7.3 Fehlende Maßnahmen

| Maßnahme | Priorität | Warum fehlt es? |
|----------|-----------|-----------------|
| sshd-Watchdog | 🔴 Kritisch | Nicht als kritisch erkannt |
| Kontinuierliches Process-Monitoring | 🔴 Kritisch | Fokus lag auf DNS |
| Alternative Zugänge | 🟡 Wichtig | Nicht berücksichtigt |
| Docker-Last-Analyse | 🟡 Wichtig | Nicht als Ursache betrachtet |
| Disk-I/O-Monitoring | 🟡 Wichtig | Nicht analysiert |

---

## 8. Empfohlene Sofortmaßnahmen (JETZT)

### 8.1 Kritisch: System-Zugang wiederherstellen

**Via IONOS Console:**

```bash
# 1. sshd-Status prüfen
systemctl status sshd
ps aux | grep sshd

# 2. Falls sshd nicht läuft
systemctl restart sshd

# 3. Falls sshd in D-State
ps aux | awk '$8 == "D"'  # Prozesse in uninterruptible sleep
# Falls sshd dabei: Reboot erforderlich

# 4. Memory-Status prüfen
free -h
cat /proc/meminfo | grep -E "Commit|Available"

# 5. Fork-Fehler prüfen
tail -50 /var/log/auth.log | grep -i "fork\|memory\|resource"
dmesg | grep -i "fork\|oom"
```

### 8.2 Kritisch: vm.overcommit_memory temporär deaktivieren

```bash
# SOFORT: Overcommit-Schutz deaktivieren (Test)
sysctl -w vm.overcommit_memory=0

# sshd neu starten
systemctl restart sshd

# SSH-Test von extern
# Falls erfolgreich: overcommit_memory=2 war die Ursache!
```

### 8.3 Kritisch: sshd-Watchdog implementieren

```bash
cat > /usr/local/bin/sshd-watchdog.sh << 'EOF'
#!/bin/bash
# sshd-Watchdog: Prüft und repariert sshd

if ! systemctl is-active --quiet sshd; then
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) sshd inactive, restarting" >> /var/log/sshd-watchdog.log
    systemctl restart sshd
fi

# Prüfe ob sshd Port 22 lauscht
if ! ss -tlnp | grep -q ':22.*sshd'; then
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) sshd not listening on port 22, restarting" >> /var/log/sshd-watchdog.log
    systemctl restart sshd
fi
EOF

chmod +x /usr/local/bin/sshd-watchdog.sh

# Cron: Alle 2 Minuten
echo "*/2 * * * * root /usr/local/bin/sshd-watchdog.sh" > /etc/cron.d/sshd-watchdog
```

---

## 9. Langfristige Empfehlungen

### 9.1 Vollständige Neuanalyse erforderlich

**Erforderlich:**
1. **Speicher-Profiling unter Last**
   - Welche Prozesse verursachen hohen Commit?
   - Wie verhält sich System bei `overcommit_memory=2` unter Last?
   - Können kritische Prozesse (sshd, systemd) bei Speicherdruck starten?

2. **Docker-Container-Optimierung**
   - 17 Container sind zu viel für 8 GB RAM
   - Welche Container sind kritisch?
   - Können Container konsolidiert werden?

3. **Disk-I/O-Analyse**
   - Gibt es I/O-Bottlenecks?
   - Verursacht Docker-Overlay-FS Probleme?
   - Ist Swap auf langsamer Disk?

### 9.2 Architektur-Änderungen

**Empfohlen:**
1. **RAM-Upgrade: 8 GB → 16 GB**
   - Aktuell: 17 Container + Services = ~5-6 GB RAM
   - Headroom: Nur 2-3 GB
   - Bei Spitzen: OOM-Risiko

2. **Container-Konsolidierung**
   - Nicht-kritische Container auf separaten VPS
   - Nur kritische Services auf devsystem-vps

3. **Alternative SSH-Zugänge**
   - Tailscale SSH (nicht Port 22)
   - Serial Console Monitoring
   - Emergency-Shell via Caddy

---

## 10. Zusammenfassung: Kritische Bewertung

### 10.1 Was funktioniert hat

✅ DNS-Konfiguration ist stabil  
✅ Tailscale läuft ohne SERVFAIL  
✅ Post-Reboot-Recovery funktioniert  
✅ Dokumentation ist exzellent

### 10.2 Was NICHT funktioniert hat

❌ **Freeze-Problem ist NICHT gelöst** (reproduziert sich)  
❌ **Watchdogs versagen** (erkennen sshd-Ausfall nicht)  
❌ **vm.overcommit_memory=2 möglicherweise kontraproduktiv**  
❌ **Keine präventiven Maßnahmen** (nur reaktiv)  
❌ **Root-Cause falsch diagnostiziert** (DNS statt Speicher)

### 10.3 Kritische Lücken

🔴 **Kein sshd-Watchdog** → Kein Remote-Zugang bei Ausfall  
🔴 **Keine kontinuierliche Überwachung** → Probleme werden nicht erkannt  
🔴 **Keine Alternative Zugänge** → IONOS Console ist einziger Fallback  
🔴 **Docker-Last nicht analysiert** → Mögliche Hauptursache ignoriert  
🔴 **Speicher-Profiling fehlt** → overcommit_memory=2 ungetestet

---

## 11. Fazit

**Die implementierten Reparaturmaßnahmen haben:**
- ✅ DNS-Probleme behoben (Symptom)
- ✅ Tailscale stabilisiert (Symptom)
- ❌ **Freeze-Problematik NICHT gelöst** (Root-Cause)
- ⚠️ **Möglicherweise neue Probleme verursacht** (overcommit_memory=2)

**Das System zeigt:**
- Identische Symptome wie vor den Reparaturen
- Selektiven Service-Ausfall (SSH down, HTTPS up)
- Versagen aller Watchdog-Mechanismen
- Reproduzierbare Instabilität (2x Ausfall in 1 Stunde)

**Empfehlung:**
1. **Sofort:** IONOS Console öffnen, sshd reparieren, overcommit_memory=0 setzen
2. **Heute:** sshd-Watchdog implementieren, Alternative Zugänge einrichten
3. **Diese Woche:** Vollständige Neuanalyse mit Fokus auf Speicher und Docker
4. **Nächsten Monat:** RAM-Upgrade oder Container-Konsolidierung

**Status:** 🔴 **System ist instabil und benötigt dringende Intervention**

---

**Analysiert:** 2026-05-31T15:02 UTC  
**Analyst:** Zoo (AI Assistant)  
**Methode:** Branch-Analyse + Live-System-Diagnose + Root-Cause-Analyse  
**Nächste Schritte:** IONOS Console-Zugriff erforderlich