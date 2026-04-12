# Issue Guidelines & Best Practices

## Übersicht

Dieses Dokument beschreibt Best Practices für die Erstellung, Verwaltung und Bearbeitung von GitHub Issues im DevSystem-Projekt. Es ergänzt den [Feature-Workflow](./feature-workflow.md) mit konkreten Anleitungen und Beispielen.

## 📋 Inhaltsverzeichnis

1. [Issue-Erstellung](#issue-erstellung)
2. [Acceptance Criteria Guidelines](#acceptance-criteria-guidelines)
3. [Value/Effort-Ratio Berechnung](#valueeffort-ratio-berechnung)
4. [Labels & Milestones](#labels--milestones)
5. [Commit-Message-Konventionen](#commit-message-konventionen)
6. [Issue-Linking & References](#issue-linking--references)
7. [Issue-Lifecycle Management](#issue-lifecycle-management)
8. [Beispiele & Templates](#beispiele--templates)

---

## 🎫 Issue-Erstellung

### Wann ein neues Issue erstellen?

**JA, erstelle ein Issue für:**
- ✅ Neue Features oder Verbesserungen
- ✅ Bugs und Fehler
- ✅ Dokumentations-Updates
- ✅ Refactoring-Vorschläge
- ✅ Technische Debt-Reduktion
- ✅ Performance-Optimierungen

**NEIN, kein Issue für:**
- ❌ Triviale Typos (direkt PR erstellen)
- ❌ Diskussionen (nutze Discussions)
- ❌ Fragen (nutze Discussions oder Ask-Issue mit Label `question`)
- ❌ Duplikate bestehender Issues

### Template-Auswahl

```
Feature Request → Neue Funktionen, Verbesserungen
Bug Report → Fehler, unerwartetes Verhalten
```

**Hinweis:** Für andere Typen (Docs, Refactoring) kannst du das Feature-Template anpassen oder ein Blank-Issue mit entsprechenden Labels erstellen.

### Titel-Konventionen

**Format:**
```
[TYPE] Prägnante Beschreibung (max. 60 Zeichen)
```

**Beispiele - GUT ✅:**
```
[FEATURE] Dark mode support for UI
[BUG] Login token expires too early
[DOCS] Update API authentication guide
[REFACTOR] Simplify user service logic
```

**Beispiele - SCHLECHT ❌:**
```
Feature  # Zu vage
Bug in the login  # Nicht spezifisch genug
This is a feature request for implementing a dark mode theme across the entire application  # Zu lang
```

### Beschreibung schreiben

**Struktur:**
1. **Was:** Kurze Zusammenfassung (1-2 Sätze)
2. **Warum:** Motivation und Kontext
3. **Wie:** Grober Lösungsansatz (optional)

**Beispiel:**
```markdown
## Was
Implementierung eines Dark-Mode-Themes für die gesamte UI.

## Warum
User berichten von Augenbelastung bei längerer Nutzung im Dunkeln.
Dark Mode ist mittlerweile Standard in modernen Apps.
Bessere UX für verschiedene Nutzungsszenarien.

## Wie (initial)
- Theme-Toggle in Settings
- CSS-Variablen für Farb-Schema
- Persistierung der User-Präferenz
```

---

## ✅ Acceptance Criteria Guidelines

### Was sind gute Acceptance Criteria?

**Eigenschaften guter AC:**
- ✅ **Testbar:** Klar prüfbar (Pass/Fail)
- ✅ **Specific:** Konkret, nicht vage
- ✅ **Measurable:** Messbare Kriterien
- ✅ **User-Focused:** Aus User-Perspektive
- ✅ **Complete:** Alle wichtigen Aspekte abdecken

### Format

**Empfohlenes Format:**
```markdown
- [ ] AC1: [Aktor] kann [Aktion] durchführen und [Ergebnis] sehen
- [ ] AC2: Wenn [Bedingung], dann [Verhalten]
- [ ] AC3: [Feature] erfüllt [Qualitätskriterium]
```

### Beispiele

**Feature: Dark Mode Support**

✅ **GUTE Acceptance Criteria:**
```markdown
- [ ] AC1: User kann in Settings zwischen Light/Dark/Auto Mode wählen
- [ ] AC2: Gewählter Mode wird persistent gespeichert und beim Reload wiederhergestellt
- [ ] AC3: Alle UI-Komponenten (Header, Sidebar, Content, Modals) passen Farben korrekt an
- [ ] AC4: Auto-Mode erkennt System-Präferenz via `prefers-color-scheme`
- [ ] AC5: Farbkontrast erfüllt WCAG 2.1 AA Standard (min. 4.5:1)
- [ ] AC6: Transition zwischen Modes ist smooth (max. 300ms)
```

❌ **SCHLECHTE Acceptance Criteria:**
```markdown
- [ ] AC1: Dark Mode funktioniert
- [ ] AC2: UI sieht gut aus
- [ ] AC3: User sind zufrieden
```
*Problem: Nicht testbar, zu vage*

**Bug: Login Token Expires Too Early**

✅ **GUTE Acceptance Criteria:**
```markdown
- [ ] AC1: Token-Lebensdauer wird von 5 Minuten auf 30 Minuten erhöht
- [ ] AC2: Token-Refresh erfolgt automatisch 5 Minuten vor Ablauf
- [ ] AC3: User wird bei Inaktivität > 24h ausgeloggt (Security)
- [ ] AC4: Keine Session-Verluste bei normalem Arbeitsfluss
- [ ] AC5: Error-Handling bei fehlgeschlagenem Refresh in ≤ 3s
```

### Anzahl der AC

**Richtwerte:**
- **Klein** (Effort 1-3): 2-4 AC
- **Mittel** (Effort 4-6): 4-8 AC
- **Groß** (Effort 7-10): 8-15 AC (oder Feature aufteilen!)

**Zu wenige AC** → Feature zu vage definiert  
**Zu viele AC** → Feature zu groß, aufteilen erwägen

### AC vs. Implementation Details

**Acceptance Criteria beschreiben WAS, nicht WIE:**

✅ **Richtig (AC):**
```markdown
- [ ] User kann Passwort zurücksetzen und erhält Bestätigungs-Email
```

❌ **Falsch (Implementation Detail):**
```markdown
- [ ] SendGrid API wird aufgerufen mit Template ID 123
- [ ] Redis-Cache speichert Token mit 24h TTL
```

*Implementation Details gehören in die Beschreibung oder Kommentare, nicht in AC.*

---

## 📊 Value/Effort-Ratio Berechnung

### Value Score (1-10)

**Bewertungs-Framework:**

| Kriterium | Gewichtung | Frage |
|-----------|------------|-------|
| **User Impact** | 40% | Wie viele User profitieren? Wie stark? |
| **Business Value** | 40% | Umsatz, Effizienz, strategische Ziele? |
| **Tech Debt** | 20% | Verbessert es langfristige Code-Qualität? |

**Scoring-Tabelle:**

| Score | User Impact | Business Value | Tech Debt |
|-------|-------------|----------------|-----------|
| 9-10 | Alle User, kritisch | Strategisch essentiell | Fundamentale Verbesserung |
| 7-8 | Viele User, hohes Benefit | Signifikanter ROI | Wichtige Verbesserung |
| 5-6 | Einige User, moderates Benefit | Positiver ROI | Moderate Verbesserung |
| 3-4 | Wenige User, kleines Benefit | Marginaler ROI | Kleine Verbesserung |
| 1-2 | Einzelne User, minimales Benefit | Kein ROI | Keine/negative Änderung |

**Berechnungs-Beispiel:**

```
Feature: Automated Daily Backups

User Impact: 9/10
- Alle User profitieren (100%)
- Kritisches Sicherheits-Feature
- Verhindert Datenverlust
→ 9 * 0.4 = 3.6

Business Value: 10/10
- Compliance-Anforderung (must-have)
- Reduziert Haftungsrisiko
- Erhöht Vertrauen
→ 10 * 0.4 = 4.0

Tech Debt: 6/10
- Schafft solide Backup-Infrastruktur
- Wiederverwendbar für andere Services
→ 6 * 0.2 = 1.2

TOTAL VALUE: 3.6 + 4.0 + 1.2 = 8.8/10
```

### Effort Score (1-10)

**Bewertungs-Framework:**

| Score | Zeitaufwand | Komplexität | Dependencies | Unsicherheit |
|-------|-------------|-------------|--------------|--------------|
| 9-10 | >2 Wochen | Sehr komplex | Viele externe | Sehr hoch |
| 7-8 | 1-2 Wochen | Komplex | Mehrere externe | Hoch |
| 5-6 | 3-5 Tage | Moderat | Wenige interne | Mittel |
| 3-4 | 1-2 Tage | Einfach | Keine | Niedrig |
| 1-2 | <1 Tag | Trivial | Keine | Minimal |

**Berechnungs-Beispiel:**

```
Feature: Automated Daily Backups

Zeitaufwand: 3-4 Tage (Score: 5)
- Backup-Script schreiben: 1 Tag
- S3/Storage-Integration: 1 Tag
- Cron-Setup + Monitoring: 1 Tag
- Testing + Docs: 1 Tag

Komplexität: Moderat (Score: 5)
- Standard-Backup-Tools verwenden
- Bekannte Storage-APIs
- Bewährte Cron-Patterns

Dependencies: Wenige (Score: 4)
- S3-Bucket bereitstellen (intern)
- Monitoring-Integration (vorhanden)

Unsicherheit: Niedrig (Score: 3)
- Ähnliche Backups bereits implementiert
- Klare Anforderungen

AVERAGE EFFORT: (5+5+4+3)/4 = 4.25/10 ≈ 4/10
```

### Ratio berechnen

```
Ratio = Value / Effort = 8.8 / 4 = 2.2
```

**Interpretation:**

| Ratio | Priorität | Aktion |
|-------|-----------|--------|
| >2.5 | Sehr hoch | Sofort umsetzen! (Quick Wins) |
| 2.0-2.5 | Hoch | Zeitnah umsetzen |
| 1.5-2.0 | Mittel | In nächsten Sprints |
| 1.0-1.5 | Niedrig | Bei freier Kapazität |
| <1.0 | Sehr niedrig | Kritisch hinterfragen |

### Justification schreiben

**Template:**
```markdown
**Justification:**
- Value (8.8): Kritisches Sicherheits-Feature für alle User, 
  Compliance-Anforderung, strategisch essentiell
- Effort (4): 3-4 Tage Entwicklung, moderate Komplexität, 
  wenige Dependencies, bekanntes Problem-Pattern
- Ratio (2.2): High-Priority Feature, sollte zeitnah umgesetzt werden
```

---

## 🏷️ Labels & Milestones

### Standard-Labels

**Type-Labels** (Pflicht):
```
feature      → Neue Funktionalität
bug          → Fehler/unerwartetes Verhalten
docs         → Dokumentation
refactor     → Code-Verbesserung ohne neue Features
test         → Test-bezogen
chore        → Maintenance-Arbeiten
```

**Priority-Labels:**
```
priority:critical  → Sofort (Blocker, Security)
priority:high      → Diese Woche
priority:medium    → Dieser Sprint
priority:low       → Backlog
```

**Status-Labels:**
```
needs-triage       → Noch nicht bewertet
blocked            → Wartet auf Dependencies
in-review          → Code-Review läuft
ready-for-merge    → Approved, kann gemerged werden
```

**Component-Labels:**
```
component:ui       → Frontend/User Interface
component:api      → Backend API
component:db       → Datenbank
component:infra    → Infrastructure/DevOps
component:docs     → Dokumentation
```

### Label-Kombinationen

**Beispiele:**
```
feature + priority:high + component:ui
→ High-Priority UI Feature

bug + priority:critical + blocked
→ Kritischer Bug, aktuell blockiert

docs + priority:low + component:api
→ Low-Priority API-Dokumentation
```

### Milestones verwenden

**Naming-Konvention:**
```
v1.0.0 Release      → Version-basiert
Sprint 2026-W15     → Sprint-basiert
Q2 2026 Goals       → Quartals-basiert
```

**Best Practices:**
- **Maximal 10-15 Issues pro Milestone** (realistisch!)
- **Due-Date setzen** für zeitgebundene Releases
- **Milestone-Progress tracken** (GitHub zeigt % Complete)
- **Issues re-assignen** wenn sich Prioritäten ändern

---

## 💬 Commit-Message-Konventionen

### Conventional Commits Format

**Struktur:**
```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

**Types:**
```
feat     → Neues Feature (User-sichtbar)
fix      → Bug-Fix (User-sichtbar)
docs     → Dokumentations-Änderung
style    → Code-Formatting (keine Logik-Änderung)
refactor → Code-Refactoring (keine neue Funktion)
test     → Test-Änderungen
chore    → Build/Tool-Änderungen
perf     → Performance-Verbesserung
```

### Issue-Closing Keywords

**Automatisches Schließen:**
```
Closes #123     → Preferred (clear & explicit)
Fixes #123      → For bug fixes
Resolves #123   → For general resolution
```

**Mehrere Issues:**
```
Closes #123, Closes #456
Fixes #123 and #124
```

**Verwandte Issues (kein Auto-Close):**
```
Related to #123
Ref #123
See #123
```

### Commit-Message-Beispiele

**Feature mit Issue-Close:**
```
feat(ui): add dark mode toggle (Closes #42)

- Implemented theme switcher in settings panel
- Added CSS variables for color scheme
- Persisted user preference in localStorage

Value: 8/10 (high user demand)
Effort: 3/10 (straightforward implementation)
```

**Bug-Fix:**
```
fix(auth): extend token lifetime to 30min (Fixes #89)

Token was expiring too early (5min), causing frequent logouts.
Increased to 30min and added auto-refresh 5min before expiry.

Tested: Local dev, staging, manual QA
```

**Multi-Issue:**
```
feat(backup): automated daily backups (Closes #23, Closes #24)

Implements automated S3 backups with monitoring:
- #23: Backup script with S3 upload
- #24: Monitoring dashboard integration

Scheduled via cron: 02:00 UTC daily
```

**Refactoring ohne Issue:**
```
refactor(api): simplify user service logic

Extracted common validation logic into helper functions.
No functional changes, improved readability.
```

### Commit-Message-Guidelines

**DO's ✅:**
- **Imperative mood:** "add feature", nicht "added feature"
- **Lowercase subject:** `feat: add`, nicht `Feat: Add`
- **No trailing period:** `add feature`, nicht `add feature.`
- **Max 72 chars:** Subject-Line kurz halten
- **Body für Details:** Erklärungen im Body, nicht Subject
- **Issue-Referenz:** Immer Issue verlinken wenn vorhanden

**DON'Ts ❌:**
- ❌ `fixed stuff` (zu vage)
- ❌ `Feature: Added new feature` (redundant)
- ❌ `closes #123` (sollte `Closes` sein - Großschreibung!)
- ❌ `lots of changes` (nicht aussagekräftig)

---

## 🔗 Issue-Linking & References

### Verlinkungs-Syntax

**Intra-Repo:**
```markdown
#123                → Issue #123 in gleichem Repo
PR #124             → Pull Request explizit
GH-123              → Alternative Syntax
```

**Cross-Repo:**
```markdown
owner/repo#123      → Issue in anderem Repo
```

**Commits:**
```markdown
abc1234             → Commit-Hash (kurz)
abc1234567890abcd   → Commit-Hash (lang)
```

### Dependency-Mapping

**Im Issue beschreiben:**

```markdown
## Dependencies

### Blocked by
- #42 - Dark mode must be implemented first
- #37 - Theming infrastructure required

### Blocks
- #55 - Custom theme colors (depends on this)
- #58 - Print styles (needs theme system)

### Related
- #12 - Original feature request
- #19 - Similar accessibility improvement
```

**GitHub Task Lists für Tracking:**
```markdown
## Implementation Steps

- [x] #42 Dark mode implementation
- [x] #37 Theming infrastructure
- [ ] #55 Custom theme colors ← blocked until this is done
- [ ] #58 Print styles
```

### Links in Commits verwenden

```bash
# Feature aufbaut auf anderem Issue
git commit -m "feat: custom themes (Closes #55)

Depends on #42 (dark mode) which provides theme infrastructure.
Enables users to customize colors beyond light/dark.

Ref: #12 (original feature request)"
```

---

## 🔄 Issue-Lifecycle Management

### Issue-States & Transitions

```
NEW → TRIAGED → ASSIGNED → IN PROGRESS → IN REVIEW → CLOSED
```

**State-Definitionen:**

| State | Label | Beschreibung | Verantwortlich |
|-------|-------|--------------|----------------|
| NEW | `needs-triage` | Neu erstellt, noch nicht bewertet | Maintainer |
| TRIAGED | (keine) | Bewertet, in Backlog priorisiert | Maintainer |
| ASSIGNED | (keine) | Assignee zugewiesen | Assignee |
| IN PROGRESS | (keine) | Arbeit läuft | Assignee |
| IN REVIEW | `in-review` | PR erstellt, Review läuft | Reviewer |
| CLOSED | (keine) | Erledigt oder abgelehnt | System |

### Wöchentliche Triage

**Triage-Checkliste** (jeden Montag):

```markdown
## Triage Meeting - 2026-04-14

### Neue Issues (needs-triage)
- [ ] #201 - Value/Effort bewerten
- [ ] #202 - Labels zuweisen
- [ ] #203 - In Backlog priorisieren

### Blocked Issues
- [ ] #189 - Dependency #187 noch in Progress → Follow-up
- [ ] #192 - External API issue → Contact vendor

### Stale Issues (>30 Tage inaktiv)
- [ ] #167 - Still relevant? → Close oder Update
- [ ] #172 - Waiting for response → Ping contributor

### Ready for Next Sprint
- [ ] Top 5 Issues aus Backlog → "Next" verschieben
```

### Stale Issue Policies

**30-Tage-Regel:**
- Issue ohne Aktivität > 30 Tage → `stale` Label
- Bot-Kommentar: "Is this still relevant?"
- Weitere 14 Tage keine Antwort → Auto-Close

**Ausnahmen:**
- `priority:high` oder `priority:critical`
- `blocked` (wartet auf externe Dependencies)
- `long-term` (strategische Projekte)

### Issue-Close-Gründe

**Gute Gründe zum Schließen:**
- ✅ Implemented (via PR + Commit)
- ✅ Won't Fix (mit Begründung)
- ✅ Duplicate of #X
- ✅ Stale (keine Aktivität, nicht mehr relevant)
- ✅ Invalid (kein Bug/falsche Annahme)

**Immer mit Kommentar schließen:**
```markdown
Closing as implemented in PR #234 (Closes #123)
All AC fulfilled, tests pass, docs updated.
```

```markdown
Closing as duplicate of #45 which has more discussion.
Please follow #45 for updates.
```

```markdown
Closing as won't fix. After discussion, the proposed change
conflicts with architectural decisions. See comment #3 for details.
```

---

## 📚 Beispiele & Templates

### Beispiel 1: Feature Issue (komplett)

```markdown
---
name: Feature Request
about: Erstelle eine neue Feature-Anfrage mit Value Statement
title: "[FEATURE] Automated backup notifications"
labels: ["feature", "needs-triage", "component:infra"]
assignees: ''
---

## 🎯 Value Statement

### User Need
**Als** DevOps Engineer
**möchte ich** Email-Benachrichtigungen bei erfolgreichen/fehlgeschlagenen Backups
**damit** ich Backup-Probleme sofort erkennen und beheben kann

### Problem
Backup-System läuft automatisch, aber es gibt keine Visibility.
Bei fehlgeschlagenen Backups erfährt man es erst bei Datenverlust.
Aktuell: Manuelle Log-Checks → ineffizient und fehleranfällig.

### Business Value
- **Impact:** Hoch
- **Urgency:** Mittel
- **User Benefit:** Proaktive Fehlererkennung, reduzierte Downtime

## ✅ Acceptance Criteria

- [ ] AC1: System sendet Email bei erfolgreichem Backup mit Timestamp und Backup-Size
- [ ] AC2: System sendet Email bei fehlgeschlagenem Backup mit Error-Details und Logs
- [ ] AC3: Email-Empfänger sind konfigurierbar via ENV-Variable (Komma-separiert)
- [ ] AC4: Email-Template ist übersichtlich und enthält alle relevanten Infos
- [ ] AC5: Keine Emails bei < 1% Abweichung von Average-Backup-Time (Noise-Reduktion)

## 📊 Value/Effort Ratio

**Value Score:** 7/10
**Effort Score:** 3/10
**Ratio:** 2.33

**Justification:**
- Value (7): Wichtig für Operations, verhindert unentdeckte Backup-Failures,
  aber nicht kritisch da Backups selbst schon funktionieren
- Effort (3): ~1-2 Tage - Email-Integration mit existierendem Backup-Script,
  Template erstellen, minimal Testing
- Ratio (2.33): High-Priority, sollte zeitnah umgesetzt werden

## 🚫 Out of Scope

- [ ] Slack/SMS-Notifications (separate Feature)
- [ ] Backup-Restore-Testing (separate Feature)
- [ ] Custom Email-Templates per User (v1: single template)

## 📦 Deliverables

- [ ] Email-Notification-Modul in Backup-Script
- [ ] HTML-Email-Template (success + failure)
- [ ] ENV-Variable `BACKUP_EMAIL_RECIPIENTS`
- [ ] Documentation in `docs/operations/`
- [ ] Test: Successful-Backup-Email
- [ ] Test: Failed-Backup-Email

## 🔗 Dependencies

### Blocked by
- #23 - Automated backup system (must exist first)

### Blocks
- #89 - Monitoring dashboard (könnte Email-Daten nutzen)

## 📚 References

- [Backup Infrastructure Discussion](https://github.com/org/repo/discussions/12)
- Related: #23 (Backup-System)
- Email-Service: SendGrid API (already in use)

## 💡 Additional Context

**Email-Template Mockup:**

```
Subject: ✅ Backup Successful - DevSystem - 2026-04-12

DevSystem Backup Report
========================

Status: SUCCESS ✅
Timestamp: 2026-04-12 02:00 UTC
Backup Size: 2.3 GB
Duration: 4m 32s
S3 Bucket: s3://devsystem-backups/

Files backed up: 12,345
Backup ID: backup-20260412-020000

Next backup: 2026-04-13 02:00 UTC
```

---

**Mobile Workflow Note:** Dieses Template ist optimiert für Mobile-Eingabe.
```

### Beispiel 2: Bug Issue (komplett)

```markdown
---
name: Bug Report
about: Melde einen Fehler oder unerwartetes Verhalten
title: "[BUG] Code-Server disconnects after 30min idle"
labels: ["bug", "needs-triage", "priority:high"]
assignees: ''
---

## 🐛 Bug Description

Code-Server WebSocket-Verbindung disconnected nach ~30 Minuten Inaktivität.
User muss Page reloaden um weiterzuarbeiten. Extensions und Terminal-Sessions gehen verloren.

## 🔄 Steps to Reproduce

1. Öffne Code-Server in Browser
2. Arbeite normal für 5-10 Minuten
3. Lasse Tab 30+ Minuten inaktiv (Pause, anderer Tab, etc.)
4. Kehre zurück zu Code-Server-Tab
5. Versuche zu tippen oder Command auszuführen

## ✅ Expected Behavior

- WebSocket-Verbindung bleibt bestehen oder reconnected automatisch
- User kann nahtlos weiterarbeiten
- Terminal-Sessions bleiben alive
- Keine manuellen Reloads nötig

## ❌ Actual Behavior

- WebSocket disconnected nach ~30min
- UI zeigt "Disconnected" Banner
- Reconnect schlägt fehl
- Terminal-Sessions beendet
- Extensions müssen neu geladen werden
- **Manueller Page-Reload erforderlich** → schlechte UX

## 🖥️ Environment Details

**System:**
- OS: Ubuntu 22.04 (VPS)
- Browser: Chrome 120.0 (auch Firefox 121.0 reproduzierbar)
- Version: code-server 4.21.1

**Relevant Components:**
- [x] Code-Server
- [x] Caddy (Reverse Proxy)
- [ ] Tailscale
- [ ] Qdrant
- [ ] Scripts
- [ ] Dokumentation

**Network:**
- Caddy als Reverse Proxy (Port 9443)
- WebSocket Proxy-Config aktiv
- Tailscale-Netzwerk

## 📋 Logs / Screenshots

<details>
<summary>Browser Console Logs</summary>

```
WebSocket connection to 'wss://dev.example.com:9443/...' failed:
Error during WebSocket handshake: Unexpected response code: 502

[Extension Host] Received fatal error from server: Connection lost
[Extension Host] Attempting reconnect... (failed)
```

</details>

<details>
<summary>Caddy Logs</summary>

```
2026/04/12 02:35:12 [ERROR] proxy: failed to read from backend: read tcp: i/o timeout
2026/04/12 02:35:12 [INFO] closing connection from 192.168.1.100:54321
```

</details>

**Screenshot:**
![Disconnected State](url-to-screenshot)

## 💡 Possible Solution

Verdacht: Caddy Timeout-Settings zu aggressiv für WebSocket-Verbindungen.

Mögliche Fixes:
1. Erhöhe `timeout` in Caddyfile für WebSocket-Routen
2. Implementiere WebSocket-Ping/Pong Keep-Alive
3. Code-Server: Automatischer Reconnect mit Session-Restore

Ähnliches Issue upstream: microsoft/vscode-remote-release#1234

## 📊 Impact Assessment

**Severity:** Hoch
<!-- Hauptfunktion betroffen: Remote Development unbrauchbar bei längeren Pausen -->

**Frequency:** Immer
<!-- Reproduzierbar bei jedem 30min+ Idle -->

**Affected Users:** Alle
<!-- Jeder User der Pausen macht/Multi-Tasking betreibt -->

## 🔗 Related Issues

- Related: #34 (Caddy WebSocket Config)
- Potentially: #56 (Code-Server Stability)

## 📚 Additional Context

**Workaround:** Page reload nach Inaktivität (suboptimal, verliert State)

**Upstream References:**
- [code-server WebSocket docs](https://github.com/coder/code-server/docs/websockets)
- [Caddy WebSocket reverse proxy](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy#websockets)

---

**Mobile Workflow Note:** Bug tritt auch auf Mobile-Browsers auf (iOS Safari, Android Chrome).
```

---

## ✅ Pre-Submit-Checkliste

Vor dem Erstellen eines Issues:

- [ ] Titel ist prägnant und beschreibend
- [ ] Template korrekt ausgefüllt (Feature oder Bug)
- [ ] Value/Effort-Score geschätzt (Feature)
- [ ] Impact Assessment (Bug)
- [ ] Acceptance Criteria konkret und testbar
- [ ] Labels zugewiesen
- [ ] Duplicates gecheckt (Search existierende Issues)
- [ ] Related Issues verlinkt
- [ ] Rechtschreibung geprüft

---

## 🔍 Häufige Fehler vermeiden

### ❌ Fehler 1: Vage Acceptance Criteria
**Problem:**
```markdown
- [ ] Feature funktioniert gut
- [ ] UI ist schön
```

**Lösung:**
```markdown
- [ ] User kann Feature X in ≤3 Klicks erreichen
- [ ] UI erfüllt WCAG 2.1 AA Standard (Kontrast, Accessibility)
```

### ❌ Fehler 2: Zu große Issues
**Problem:** Issue mit 20+ AC, Effort-Score 9/10, betrifft 5 Components

**Lösung:** Auftailen in kleinere, fokussierte Issues:
```markdown
#123 - Phase 1: Core Feature (Effort 4)
#124 - Phase 2: UI Polish (Effort 3)
#125 - Phase 3: Advanced Options (Effort 2)
```

### ❌ Fehler 3: Value-Score ohne Begründung
**Problem:**
```markdown
Value: 9/10
Effort: 2/10
```
*(Keine Justification)*

**Lösung:**
```markdown
Value: 9/10
- User Impact (9): Alle 100+ User profitieren täglich
- Business Value (10): Reduziert Support-Tickets um 50%
- Tech Debt (7): Schafft wiederverwendbare API

Effort: 2/10
- 1 Tag Entwicklung, triviale Logik, keine Dependencies

Ratio: 4.5 (Sofort umsetzen - Quick Win!)
```

### ❌ Fehler 4: Issue ohne Context schließen
**Problem:** Issue einfach schließen ohne Kommentar

**Lösung:** Immer Closing-Kommentar mit Reason:
```markdown
Closing as duplicate of #234 which has more comprehensive discussion.
Please follow #234 for updates on this feature.
```

---

## 📖 Weiterführende Ressourcen

**Projekt-Dokumentation:**
- [`feature-workflow.md`](./feature-workflow.md) - Gesamter Feature-Workflow
- [`git-workflow.md`](./git-workflow.md) - Git-Conventions
- [`.github/ISSUE_TEMPLATE/feature.md`](../../.github/ISSUE_TEMPLATE/feature.md) - Feature-Template
- [`.github/ISSUE_TEMPLATE/bug.md`](../../.github/ISSUE_TEMPLATE/bug.md) - Bug-Template

**Externe Referenzen:**
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Issue Linking](https://docs.github.com/en/issues/tracking-your-work-with-issues/linking-a-pull-request-to-an-issue)
- [User Story Mapping](https://www.jpattonassociates.com/user-story-mapping/)
- [INVEST Criteria](https://en.wikipedia.org/wiki/INVEST_(mnemonic))

---

**Version:** 1.0  
**Letzte Aktualisierung:** 2026-04-12  
**Maintainer:** DevSystem Team
