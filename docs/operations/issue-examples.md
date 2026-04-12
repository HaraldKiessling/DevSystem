# Issue Examples & Templates

## 📚 Related Documentation
- [Issue Guidelines](issue-guidelines.md) - Kernkonzepte & Prozesse
- [Acceptance Criteria](issue-acceptance-criteria.md) - AC-Framework & Best Practices
- [Feature Workflow](./feature-workflow.md) - Gesamter Feature-Workflow

## Übersicht

Dieses Dokument enthält vollständige, produktionsreife Beispiele für verschiedene Issue-Typen. Nutze diese als Templates für deine eigenen Issues.

Für Konzepte und Best Practices siehe [issue-guidelines.md](issue-guidelines.md).  
Für AC-Framework siehe [issue-acceptance-criteria.md](issue-acceptance-criteria.md).

---

## 📋 Commit-Message-Beispiele

### Feature mit Issue-Close

```
feat(ui): add dark mode toggle (Closes #42)

- Implemented theme switcher in settings panel
- Added CSS variables for color scheme
- Persisted user preference in localStorage

Value: 8/10 (high user demand)
Effort: 3/10 (straightforward implementation)
```

### Bug-Fix

```
fix(auth): extend token lifetime to 30min (Fixes #89)

Token was expiring too early (5min), causing frequent logouts.
Increased to 30min and added auto-refresh 5min before expiry.

Tested: Local dev, staging, manual QA
```

### Multi-Issue

```
feat(backup): automated daily backups (Closes #23, Closes #24)

Implements automated S3 backups with monitoring:
- #23: Backup script with S3 upload
- #24: Monitoring dashboard integration

Scheduled via cron: 02:00 UTC daily
```

### Refactoring ohne Issue

```
refactor(api): simplify user service logic

Extracted common validation logic into helper functions.
No functional changes, improved readability.
```

---

## 🎯 Beispiel 1: Feature Issue (komplett)

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

---

## 🐛 Beispiel 2: Bug Issue (komplett)

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

## ✅ Acceptance Criteria

- [ ] AC1: Token-Lebensdauer wird von 5min auf 30min erhöht
- [ ] AC2: Token-Refresh erfolgt automatisch 5min vor Ablauf
- [ ] AC3: User wird bei Inaktivität > 24h ausgeloggt (Security)
- [ ] AC4: Reproduktionsschritte aus Bug-Report schlagen fehl
- [ ] AC5: Bestehende Auth-Tests bleiben grün

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

## 📚 Beispiel 3: Documentation Issue

```markdown
---
name: Documentation Update
about: Verbesserung oder Ergänzung der Dokumentation
title: "[DOCS] Add troubleshooting guide for WebSocket issues"
labels: ["docs", "priority:medium", "component:docs"]
assignees: ''
---

## 📖 Documentation Need

### Problem
User stolpern wiederholt über WebSocket-Connection-Probleme.
Issue #34 und #89 zeigen: Häufige Fragen zu Timeouts, Proxy-Config, Debugging.

Aktuell: Informationen verstreut in Issues, keine zentrale Troubleshooting-Anleitung.

### Target Audience
- DevOps Engineers (Setup)
- Developers (Debugging)
- End Users (Workarounds)

## ✅ Acceptance Criteria

- [ ] AC1: Troubleshooting-Guide deckt 5 häufigste WebSocket-Probleme ab
- [ ] AC2: Jedes Problem hat: Symptome, Ursache, Lösung, Prevention
- [ ] AC3: Guide enthält funktionierende Code-Beispiele (Caddyfile-Snippets)
- [ ] AC4: Debugging-Kommandos sind copy-paste-ready
- [ ] AC5: Guide ist in `docs/TROUBLESHOOTING.md` verlinkt
- [ ] AC6: Alle Links (intern + extern) sind valide

## 📦 Deliverables

- [ ] `docs/operations/troubleshooting-websockets.md`
- [ ] Integration in `docs/TROUBLESHOOTING.md`
- [ ] Update in `docs/README.md` (add link)
- [ ] Issue #34 und #89 kommentieren (Link zu Guide)

## 📋 Content Outline

### 1. WebSocket Connection Timeouts
- Symptome
- Caddy timeout-Config
- Code-Server keep-alive settings

### 2. 502 Bad Gateway Errors
- Symptome
- Proxy-Header-Konfiguration
- Upstream connection issues

### 3. Reconnect Failures
- Symptome
- Client-side debugging
- Session-restore mechanisms

### 4. Performance Issues
- Symptome
- Bandwidth requirements
- Latency troubleshooting

### 5. Debugging Tools
- Browser DevTools (Network tab)
- Caddy logs analysis
- `wscat` for manual testing

## 🔗 References

- #34 - Original WebSocket config issue
- #89 - Connection stability improvements
- [MDN WebSocket API](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket)
- [Caddy WebSocket docs](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy#websockets)
```

---

## 🔧 Beispiel 4: Refactoring Issue

```markdown
---
name: Refactoring
about: Code-Qualität verbessern ohne funktionale Änderungen
title: "[REFACTOR] Extract common validation logic in API services"
labels: ["refactor", "priority:low", "component:api"]
assignees: ''
---

## 🔧 Refactoring Goal

### Current State
Validation-Logic ist dupliziert über 5 API-Services:
- `user-service.ts` (120 LOC validation)
- `auth-service.ts` (95 LOC validation)
- `profile-service.ts` (110 LOC validation)
- `settings-service.ts` (80 LOC validation)
- `admin-service.ts` (130 LOC validation)

**Total:** ~535 LOC Duplication

### Target State
Zentralisierte Validation-Helpers:
- `lib/validators/email.ts`
- `lib/validators/password.ts`
- `lib/validators/common.ts`

**Expected Reduction:** ~400 LOC durch Deduplication

### Why Now?
- Neue Features benötigen zusätzliche Validations
- Bug-Fixes müssen aktuell an 5 Stellen gepatcht werden
- Tech Debt behindert Entwicklungsgeschwindigkeit

## ✅ Acceptance Criteria

- [ ] AC1: Validation-Logic ist in `lib/validators/` zentralisiert
- [ ] AC2: Alle 5 Services nutzen neue Validators
- [ ] AC3: Code-Duplication reduziert um ≥70% (gemessen mit SonarQube)
- [ ] AC4: Alle bestehenden Tests bleiben grün (100% pass)
- [ ] AC5: Keine funktionalen Änderungen (identisches Verhalten)
- [ ] AC6: Performance gleich oder besser (Benchmark)
- [ ] AC7: Documentation für neue Validators in README

## 📊 Impact Assessment

**Benefits:**
- Wartbarkeit: Bug-Fixes nur an 1 Stelle
- Konsistenz: Einheitliche Validation-Messages
- Testing: Validators isoliert testbar
- Performance: Möglichkeit für zentrale Optimierung

**Risks:**
- Breaking Changes wenn schlecht umgesetzt
- Overhead bei Service-Imports

**Mitigation:**
- Step-by-step Migration (1 Service pro PR)
- Feature-Flag für Rollback
- Umfangreiche Test-Coverage

## 📦 Deliverables

- [ ] `lib/validators/email.ts` mit Tests
- [ ] `lib/validators/password.ts` mit Tests
- [ ] `lib/validators/common.ts` mit Tests
- [ ] Migration von 5 Services (kann gesplittet werden in Sub-Issues)
- [ ] Performance-Benchmark Vor/Nach
- [ ] Documentation in `lib/validators/README.md`

## 🔗 Out of Scope

- [ ] **NICHT** neue Validations hinzufügen (separate Feature)
- [ ] **NICHT** Validation-Logik ändern (nur extrahieren)
- [ ] **NICHT** andere Services migrieren (nur die 5 genannten)
```

---

## 🎨 Good vs. Bad: Acceptance Criteria

### ❌ SCHLECHT

```markdown
## ✅ Acceptance Criteria

- [ ] Dark Mode funktioniert
- [ ] UI sieht gut aus
- [ ] User sind zufrieden
- [ ] Performance ist okay
```

**Probleme:**
- Nicht testbar ("gut", "zufrieden", "okay")
- Keine messbaren Kriterien
- Vage Formulierungen
- Subjektive Bewertungen

### ✅ GUT (Dark Mode Example)

```markdown
## ✅ Acceptance Criteria

### Funktionale Anforderungen
- [ ] AC1: User kann in Settings zwischen Light/Dark/Auto Mode wählen
- [ ] AC2: Gewählter Mode wird persistent gespeichert und beim Reload wiederhergestellt
- [ ] AC3: Alle UI-Komponenten (Header, Sidebar, Content, Modals) passen Farben korrekt an
- [ ] AC4: Auto-Mode erkennt System-Präferenz via `prefers-color-scheme`

### Quality & Performance
- [ ] AC5: Farbkontrast erfüllt WCAG 2.1 AA Standard (min. 4.5:1)
- [ ] AC6: Transition zwischen Modes ist smooth (max. 300ms)
- [ ] AC7: Keine Flash of Unstyled Content (FOUC)

### Testing
- [ ] AC8: E2E-Tests für alle 3 Modi (Light/Dark/Auto)
- [ ] AC9: Visual Regression Tests für kritische Komponenten
```

**Stärken:**
- Konkret testbar (Zahlen, Standards)
- Messbare Kriterien
- Umfassend (Functional, Quality, Testing)
- User-Perspektive

---

## 🔍 Edge Cases & Special Scenarios

### Scenario 1: Breaking Change

```markdown
## ⚠️ Breaking Changes

**Affected API Endpoints:**
- `POST /api/v1/users` response format changed
- `GET /api/v1/profile` requires new auth header

**Migration Path:**
1. Deploy v2 API alongside v1 (2 weeks parallel run)
2. Notify API consumers (Email + Slack)
3. Deprecate v1 endpoints
4. Remove v1 after 4 weeks

## ✅ Acceptance Criteria

- [ ] AC1: v2 API funktioniert wie spezifiziert
- [ ] AC2: v1 API läuft parallel für 2 Wochen
- [ ] AC3: Migration-Guide dokumentiert
- [ ] AC4: API-Consumers wurden 1 Woche vor Rollout informiert
- [ ] AC5: Deprecation-Warnings in v1 API responses
- [ ] AC6: Analytics tracking für v1 vs v2 Usage
```

### Scenario 2: Feature mit mehreren Phasen

```markdown
## 📋 Multi-Phase Implementation

### Phase 1: MVP (dieser Issue)
- [ ] Core Feature X funktioniert
- [ ] Basic UI
- [ ] Happy Path

### Phase 2: Enhancement (separates Issue #XXX)
- [ ] Advanced Filters
- [ ] Bulk Operations
- [ ] Export Functionality

### Phase 3: Polish (separates Issue #XXX)
- [ ] Animations
- [ ] Accessibility
- [ ] Performance Optimization

## ✅ Acceptance Criteria (Phase 1 nur)

- [ ] AC1: User kann Feature X grundlegend nutzen
- [ ] AC2: Error-Handling für API-Failures
- [ ] AC3: Basic Documentation
```

### Scenario 3: Security-Critical Feature

```markdown
## 🔒 Security Considerations

**Threat Model:**
- XSS-Injection via user input
- SQL-Injection via URL parameters
- CSRF attacks on state-changing operations

**Mitigation:**
- Input sanitization (DOMPurify)
- Parameterized queries (no raw SQL)
- CSRF tokens on all POST/PUT/DELETE

## ✅ Acceptance Criteria

- [ ] AC1: Funktionale Anforderungen erfüllt
- [ ] AC2: XSS-Prevention tested (manual + automated)
- [ ] AC3: SQL-Injection-Prevention tested
- [ ] AC4: CSRF-Tokens validiert
- [ ] AC5: Security-Scan passed (OWASP ZAP)
- [ ] AC6: Code-Review von Security-Lead approved
- [ ] AC7: Security-Dokumentation aktualisiert
```

---

## 📖 Weiterführende Ressourcen

**Projekt-Dokumentation:**
- [Issue Guidelines](issue-guidelines.md) - Kernkonzepte & Prozesse
- [Acceptance Criteria](issue-acceptance-criteria.md) - AC-Framework & Best Practices
- [Feature Workflow](./feature-workflow.md) - End-to-End-Workflow
- [`.github/ISSUE_TEMPLATE/`](../../.github/ISSUE_TEMPLATE/) - GitHub Issue Templates

**Externe Referenzen:**
- [GitHub Issues Documentation](https://docs.github.com/en/issues)
- [User Story Mapping](https://www.jpattonassociates.com/user-story-mapping/)
- [Behavior-Driven Development](https://cucumber.io/docs/bdd/)

---

**Version:** 1.0  
**Letzte Aktualisierung:** 2026-04-12  
**Maintainer:** DevSystem Team
