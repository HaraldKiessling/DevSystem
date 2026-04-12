# Rollback-Prozedur

**Version:** 1.0.0  
**Erstellt:** 2026-04-12  
**Status:** Aktiv

## Überblick

Strukturierte Prozedur zum Rollback von fehlgeschlagenen oder problematischen Deployments.

## 1. Wann Rollback?

### Trigger-Situationen
- 🔴 **Sofort:** System down, kritische Fehler in Production
- 🟠 **Schnell:** Features funktionieren nicht, Performance-Degradation >50%
- 🟡 **Geplant:** Nicht-kritische Bugs, rollback im nächsten Maintenance-Window

### Decision-Matrix

| Problem | Severity | Downtime | Workaround | Entscheidung |
|---------|----------|----------|------------|--------------|
| System down | Critical | Ja | Nein | Sofort Rollback |
| Feature broken | High | Nein | Ja | Evaluieren → ggf. Rollback |
| Performance slow | Medium | Nein | Ja | Forward-Fix bevorzugt |
| Cosmetic bug | Low | Nein | Ja | Kein Rollback |

**Regel:** Forward-Fix bevorzugt bei Low/Medium, Rollback bei High/Critical ohne schnellen Fix.

## 2. Rollback-Arten

### 2.1 Git-Rollback (Code)

**Variante A: Revert (bevorzugt)**
```bash
# Sicher - behält History
git revert <bad-commit-hash>
git push origin main

# Bei mehreren Commits
git revert <oldest-bad>..<newest-bad>
```

**Variante B: Reset (nur wenn main nicht gepusht)**
```bash
# ⚠️ ACHTUNG: Nur lokal!
git reset --hard <last-good-commit>
# NICHT pushen mit --force auf main!
```

### 2.2 Deployment-Rollback (Services)

**Idempotenter Rollback via QS-System:**
```bash
# Automatischer Rollback via Master-Orchestrator
ssh root@devsystem-qs-vps.tailcfea8a.ts.net \
  "bash /root/scripts/qs/setup-qs-master.sh --mode=rollback"
```

**Features:**
- Automatische Erkennung vorheriger stabiler Version
- State-Marker-basierte Rollback-Identifikation
- Service-by-Service Rollback möglich
- Health-Checks nach Rollback

### 2.3 State-Rollback (Konfiguration)

**Marker löschen und neu deployen:**
```bash
# 1. Marker für problematische Komponente löschen
ssh root@devsystem-qs-vps.tailcfea8a.ts.net \
  "rm -f /var/lib/qs-deployment/markers/COMPONENT_NAME.done"

# 2. State-Files prüfen
ssh root@devsystem-qs-vps.tailcfea8a.ts.net \
  "cat /var/lib/qs-deployment/state/deployment-state.txt"

# 3. Neu deployen mit alter Version
bash scripts/qs/setup-qs-master.sh --component=COMPONENT_NAME
```

### 2.4 Service-Rollback (systemd)

**Einzelner Service:**
```bash
# Service stoppen
systemctl stop SERVICE_NAME

# Konfiguration zurücksetzen (falls in Git)
git checkout <last-good-commit> -- /path/to/config

# Service neu starten
systemctl start SERVICE_NAME
systemctl status SERVICE_NAME
```

### 2.5 Database-Rollback (Qdrant)

**Snapshot-basiert:**
```bash
# 1. Backup vor kritischen Operationen
bash scripts/qs/backup-qs-system.sh

# 2. Rollback zu Backup
# (implementiert im Backup-Script)
bash scripts/qs/backup-qs-system.sh --restore=BACKUP_ID
```

## 3. Rollback-Workflow

### 3.1 Pre-Rollback-Checklist

```bash
# 1. Problem dokumentieren
echo "PROBLEM: Service XYZ down since $(date -u)" >> /tmp/rollback-log.txt

# 2. Backup erstellen (falls möglich)
ssh root@devsystem-qs-vps.tailcfea8a.ts.net \
  "bash /root/scripts/qs/backup-qs-system.sh"

# 3. Letzte stabile Version identifizieren
git log --oneline -10
# Oder: GitHub Actions Runs prüfen für letzten Success

# 4. Stakeholder benachrichtigen (bei Production)
# Slack/Email: "Rollback in progress, ETA 15 Min"
```

### 3.2 Rollback-Execution

```bash
# Schritt 1: Git Revert
git revert <bad-commit>

# Schritt 2: Deployment
bash scripts/qs/setup-qs-master.sh --mode=rollback

# Schritt 3: Validation
bash scripts/qs/run-e2e-tests.sh --host=devsystem-qs-vps.tailcfea8.ts.net

# Schritt 4: Health-Checks
for service in caddy code-server qdrant; do
  systemctl is-active $service || echo "FAILED: $service"
done
```

### 3.3 Post-Rollback-Actions

- [ ] System-Status validieren (alle Services laufen)
- [ ] Logs prüfen (keine kritischen Errors)
- [ ] E2E-Tests (Basisf unktionalität funktioniert)
- [ ] Stakeholder informieren: "Rollback abgeschlossen, System stabil"
- [ ] **Post-Mortem** innerhalb 24h:
  - Was ging schief?
  - Warum wurde es nicht im Test gefunden?
  - Wie verhindern wir es künftig?
  - Rollback-Prozedur Learnings?

## 4. Rollback-Modi im QS-System

### Mode 1: Full Rollback
```bash
bash scripts/qs/setup-qs-master.sh --mode=rollback
```
- Rollt alle Komponenten zur letzten stabilen Version zurück
- Basiert auf Marker-Timestamps
- Vollautomatisch

### Mode 2: Component Rollback
```bash
bash scripts/qs/setup-qs-master.sh --component=caddy --rollback
```
- Rollt nur eine Komponente zurück
- Andere Services bleiben stabil
- Selektiver Rollback

### Mode 3: Configuration Rollback
```bash
bash scripts/qs/setup-qs-master.sh --config-only --rollback
```
- Rollt nur Config-Files zurück
- Services werden neu gestartet
- Code bleibt unverändert

## 5. Rollback-Testing

### Pre-Production Rollback-Test
```bash
# 1. Deployment durchführen
bash scripts/qs/setup-qs-master.sh

# 2. Marker überprüfen
ssh root@devsystem-qs-vps.tailcfea8a.ts.net \
  "ls -la /var/lib/qs-deployment/markers/"

# 3. Rollback simulieren
bash scripts/qs/setup-qs-master.sh --mode=rollback --dry-run

# 4. Tatsächlicher Rollback
bash scripts/qs/setup-qs-master.sh --mode=rollback

# 5. Validation
bash scripts/qs/run-e2e-tests.sh
```

**Erwartetes Ergebnis:** System in vorherigem stabilen Zustand.

## 6. Rollback-SLA

| Severity | Target Rollback Time | Max Downtime |
|----------|---------------------|--------------|
| Critical | 15 Minuten | 30 Minuten |
| High | 1 Stunde | 2 Stunden |
| Medium | 4 Stunden | 8 Stunden |
| Low | Best-Effort | N/A |

## 7. Rollback-Dokumentation Template

### In todo.md
```markdown
### 🔄 Rollback #456: [Deployment XYZ]

**Datum:** 2026-04-12 05:16 UTC  
**Grund:** Critical service failure after deployment  
**Target:** Commit abc123 → def456

**Durchgeführt:**
- [x] Pre-Rollback Backup erstellt
- [x] Git revert durchgeführt
- [x] Deployment rolled back via QS-System
- [x] E2E-Tests: 25/25 passed ✅
- [x] Stakeholder benachrichtigt

**Dauer:** 12 Minuten (unter 15 Min SLA ✅)

**Post-Mortem:** Scheduled for 2026-04-13
```

### Commit-Message
```
revert: rollback deployment xyz due to critical failure

Reason: Service caddy failed to start after deployment
Root-Cause: Configuration syntax error in Caddyfile

Rollback:
- [x] Git reverted to commit def456
- [x] QS-Master-Orchestrator rollback executed
- [x] All services restored to stable state
- [x] E2E tests passed

Downtime: 12 minutes (SLA: 15 min ✅)

Testing:
- Health-Checks: ✅ All services active
- E2E-Tests: 25/25 passed
- Logs: Clean, no errors

Post-Mortem: Scheduled for 2026-04-13
See: docs/archive/retrospectives/ROLLBACK-POSTMORTEM-20260412.md

Resolves: Critical incident #456
```

## 8. Eskalation bei Rollback-Failure

**Wenn Rollback fehlschlägt:**

1. **Immediate (0-5 Min)**
   - Alle Deployments stoppen
   - System-Status dokumentieren
   - Tech-Lead alarmieren

2. **Emergency (5-15 Min)**
   - Manueller Service-Restart
   - Config-Files manuell zurücksetzen
   - Logs sammeln für Analysis

3. **Recovery (15-60 Min)**
   - Fresh Deployment von bekannt stabiler Version
   - Falls nicht möglich: VPS-Reset vom Provider
   - Backup-Restore

## 9. Prevention

### Vor jedem Deployment
- [ ] Backup erstellen
- [ ] Rollback-Plan haben
- [ ] Rollback-Command bereit in Terminal
- [ ] Monitoring aktiv

### Rollback-Testing regelmäßig
```bash
# Monatlich: Rollback-Dry-Run
bash scripts/qs/setup-qs-master.sh --mode=rollback --dry-run

# Dokumentiere Ergebnis
```

## 10. Tools & Scripts

### Verfügbare Rollback-Tools
- [`scripts/qs/setup-qs-master.sh`](../../scripts/qs/setup-qs-master.sh) - Mit `--mode=rollback`
- [`scripts/qs/backup-qs-system.sh`](../../scripts/qs/backup-qs-system.sh) - Backup/Restore
- [`scripts/qs/reset-qs-services.sh`](../../scripts/qs/reset-qs-services.sh) - Service-Reset

### Monitoring während Rollback
```bash
# Terminal 1: Logs
ssh root@devsystem-qs-vps.tailcfea8a.ts.net "journalctl -f"

# Terminal 2: Rollback ausführen
bash scripts/qs/setup-qs-master.sh --mode=rollback

# Terminal 3: Health-Checks
watch -n 5 'curl -s https://devsystem-vps.tailcfea8a.ts.net:9443/health'
```

## Referenzen

- [Bug-Fixing-Workflow](06-bug-fixing-workflow.md) - Bevor Rollback erwogen wird
- [Deployment-Process](../../docs/strategies/deployment-prozess.md)
- [Git-Workflow](../../docs/operations/git-workflow.md)

---

**Erstellt:** 2026-04-12  
**Grund:** Strukturierter Rollback bei fehlgeschlagenen Deployments
