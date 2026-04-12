# Bug-Fixing-Workflow

**Version:** 1.0.0  
**Erstellt:** 2026-04-12  
**Status:** Aktiv

## Überblick

Strukturierter Workflow für Bug-Identifikation, -Analysis und -Behebung.

## 1. Bug-Identifikation

### Quellen
- User-Reports
- Monitoring-Alerts
- CI/CD-Failures
- Code-Reviews
- Self-Testing

### Kategorien
- 🔴 **Critical:** System down, Datenverlust, Sicherheitslücke
- 🟠 **High:** Feature nicht nutzbar, Performance-Probleme
- 🟡 **Medium:** Eingeschränkte Funktionalität, Workaround möglich
- 🟢 **Low:** Kosmetisch, nice-to-have fixes

## 2. Bug-Triage

**Prüfung:**
```bash
# 1. Reproduzierbarkeit
# Kann der Bug reproduziert werden?
# Wenn ja: Schritte dokumentieren
# Wenn nein: "Cannot reproduce" labeln

# 2. Impact-Assessment
# Wie viele User betroffen?
# Gibt es Workarounds?
# Ist Production betroffen?

# 3. Root-Cause-Hypothese
# Was könnte die Ursache sein?
# Welche Komponente ist betroffen?
```

**Priorisierung:**
| Kritikalität | Reproduzierbar | Impact | Priorität |
|--------------|----------------|--------|-----------|
| Critical | Ja | High | P0 (sofort) |
| Critical | Nein | High | P1 (24h) |
| High | Ja | Medium | P1 (diese Woche) |
| Medium | Ja | Low | P2 (nächster Sprint) |
| Low | Nein | Low | P3 (backlog) |

## 3. Bug-Tracking

### In todo.md
```markdown
### 🐛 Bug #123: [Kurzbeschreibung]

**Priorität:** P0 | **Status:** [-] In Analysis  
**Reported:** 2026-04-12 05:14 UTC  
**Betrifft:** Caddy Proxy

**Symptome:**
- Service startet nicht nach Reboot
- Error in systemd logs

**Reproduktion:**
1. `systemctl restart caddy`
2. `systemctl status caddy` zeigt failed

**Root-Cause-Hypothese:**
- Tailscale VPN nicht ready bei Caddy-Start
- Dependency-Order-Problem
```

## 4. Debug-Prozess

### 4.1 Informationen sammeln
```bash
# Logs
journalctl -u SERVICE_NAME -n 100 --no-pager
tail -f /var/log/SERVICE/error.log

# System-Status
systemctl status SERVICE_NAME
ps aux | grep SERVICE

# Networking
ss -tulpn | grep PORT
curl -v http://localhost:PORT/health
```

### 4.2 Root-Cause-Analyse  
- **5-Why-Methode:** Warum? → Warum? → Warum? → Warum? → Warum?
- **Binary Search:** Half der Code letzte Woche noch? Wo ist die Regression?
- **Logs analysieren:** Error-Messages, Stack-Traces

### 4.3 Hypothesen testen
```bash
# Isolierte Tests
# Ändere EINE Variable und beobachte Effekt

# Bisect (wenn Regression)
git bisect start
git bisect bad HEAD
git bisect good <last-working-commit>
```

## 5. Fix-Implementation

### 5.1 Fix-Branch erstellen
```bash
git checkout -b fix/bug-123-short-description
```

### 5.2 Fix implementieren
```bash
# 1. Minimaler Fix (nicht über-engineeren!)
# 2. Unit-Test schreiben (falls möglich)
# 3. Lokal testen
# 4. E2E-Test gegen VPS
```

### 5.3 Dokumentation
- **CHANGELOG.md:** Unter `[Unreleased] - Fixed`
- **todo.md:** Bug-Status auf `[x]` ändern
- **Commit-Message:** `fix(component): short description`

## 6. Testing & Validation

### Pre-Merge Tests
```bash
# 1. Pre-Merge-Check
bash scripts/docs/pre-merge-check.sh

# 2. E2E-Tests (falls vorhanden)
bash scripts/qs/run-e2e-tests.sh

# 3. Manual Smoke-Test
# Prüfe dass Fix funktioniert UND nichts anderes kaputt geht
```

### Regression-Prevention
```bash
# Füge Test hinzu der diesen Bug catchet
# → Verhindert Regression
```

## 7. Deployment & Rollout

### Hot-Fix (Production)
```bash
# 1. Fix direkt auf main (nur bei Critical Bugs!)
git checkout main
git cherry-pick <fix-commit>
git push

# 2. Sofortiges Deployment
bash scripts/qs/setup-qs-master.sh --mode=hotfix

# 3. Monitoring
# Logs 15 Min beobachten

# 4. Post-Mortem
# Innerhalb 24h: Warum passierte der Bug?
```

### Normal-Fix (entwickelt)
```bash
# Definition of Done befolgen
# Merge nach main mit allen Checks
git checkout main
git merge --no-ff fix/bug-123-short-description
```

## 8. Post-Fix Actions

- [ ] Bug in todo.md als `[x]` markieren
- [ ] CHANGELOG.md aktualisiert
- [ ] Monitoring: 24h beobachten
- [ ] Post-Mortem (bei Critical Bugs):
  - Was war die Root-Cause?
  - Wie wurde es entdeckt?
  - Wie wurde es gefixt?
  - Wie verhindern wir Regression?
  - Was lernen wir daraus?

## 9. Eskalation

**Wenn Bug nicht innerhalb SLA gelöst:**

| Priorität | SLA | Eskalation |
|-----------|-----|------------|
| P0 | 2h | Tech-Lead sofort |
| P1 | 24h | Tech-Lead nach 12h |
| P2 | 1 Woche | Stakeholder nach 3 Tagen |
| P3 | Best-Effort | Keine Eskalation |

## Templates

### Bug-Report
Siehe oben Sektion 3 für todo.md Template

### Commit-Message
```
fix(component): resolve bug description

Bug: #123
Root-Cause: [kurze Beschreibung]
Solution: [kurze Beschreibung]

- [x] Bug reproduziert
- [x] Root-Cause identifiziert  
- [x] Fix implementiert
- [x] Tests bestanden
- [x] Dokumentation aktualisiert

Testing:
- Manual test: ✅
- E2E test: ✅
- Regression test: Added

Resolves: Bug #123
```

---

**Erstellt:** 2026-04-12  
**Grund:** Strukturierter Umgang mit Bugs, Verhinderung von Regression
