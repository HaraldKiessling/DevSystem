# Git-Workflow für das DevSystem-Projekt

Dieses Dokument beschreibt den Git-Workflow für das DevSystem-Projekt. Es definiert die Branch-Strategie, Commit-Richtlinien, den Merge-Prozess sowie Test- und Dokumentationsanforderungen.

## 1. Definition of Done (DoD)

Ein Feature, Bugfix oder Task gilt als "Done" wenn **ALLE** folgenden Schritte erfüllt sind:

### Code
- [ ] Implementation vollständig abgeschlossen
- [ ] Lokale Tests bestanden
- [ ] Code selbst reviewed oder AI-Self-Review dokumentiert
- [ ] Keine offensichtlichen TODOs oder FIXME-Kommentare im Code

### Testing
- [ ] E2E-Tests erfolgreich (lokal und/oder remote)
- [ ] Logs auf Fehler geprüft (keine Errors oder kritische Warnings)
- [ ] Service-Status validiert (systemctl is-active bei Services)
- [ ] Funktionale Tests der geänderten Features durchgeführt

### Dokumentation (PFLICHT) 🔴

**Wichtig:** Dokumentation ist **NICHT optional** - sie ist Teil der Implementation!

#### docs/project/todo.md
- [ ] Task-Status auf `[x]` gesetzt für abgeschlossene Aufgaben
- [ ] Neue Tasks hinzugefügt, falls während der Arbeit entdeckt
- [ ] "Offene Entscheidungen" aktualisiert (gelöste als ✅ GELÖST markiert)
- [ ] **Zeitstempel aktualisiert:** `**Stand:** YYYY-MM-DD HH:MM UTC`

#### CHANGELOG.md
- [ ] Änderung in `[Unreleased]` oder Version-Sektion eingetragen
- [ ] Korrekte Kategorie gewählt:
  - `Added` für neue Features
  - `Changed` für Änderungen existierender Funktionalität
  - `Fixed` für Bugfixes
  - `Removed` für entfernte Features
  - `Security` für Sicherheits-relevante Änderungen

#### Status-Reports (bei relevanten Änderungen)
- [ ] [`docs/reports/DevSystem-Implementation-Status.md`](../reports/DevSystem-Implementation-Status.md) aktualisiert
- [ ] Relevante Konzept-Dokumente in [`docs/concepts/`](../concepts/) aktualisiert
- [ ] Bei Major-Changes: Deployment-Success-Report in [`docs/archive/phases/`](../archive/phases/) erstellt

#### Branch-Referenzen bereinigen
- [ ] Branch-Namen aus todo.md entfernt (nach Merge)
- [ ] Keine Referenzen zu gelöschten Branches in Dokumentation

### Git
- [ ] Commit-Message folgt [Conventional Commits](https://www.conventionalcommits.org/)
  - Format: `<type>(<scope>): <description>`
  - Beispiele: `feat(caddy): add HTTPS support`, `fix(qdrant): resolve connection timeout`
- [ ] Branch ist aktuell mit main (`git merge main` oder `git rebase main`)
- [ ] Keine Merge-Konflikte vorhanden
- [ ] Commits sind logisch gruppiert (nicht 50x "fix typo")

### Pre-Merge Validierung
Vor `git merge` in main, führe aus:

```bash
# 1. Prüfe, ob Branch in Dokumentation erwähnt wird
git branch --show-current
grep -r "$(git branch --show-current)" docs/
# ⚠️ Wenn gefunden: Entfernen aus Dokumentation!

# 2. Prüfe todo.md Timestamp
grep "Stand:" docs/project/todo.md
# ⚠️ Sollte nicht älter als 1h sein!

# 3. Prüfe CHANGELOG
git diff main...HEAD -- CHANGELOG.md
# ⚠️ Sollte mindestens eine Zeile geändert haben!
```

### Post-Merge Aktionen (innerhalb 30 Minuten)
- [ ] Branch lokal gelöscht: `git branch -d <branch-name>`
- [ ] Branch remote gelöscht: `git push origin --delete <branch-name>`
  - Oder GitHub "Auto-delete head branches" aktiviert
- [ ] **todo.md erneut geprüft** auf GitHub.com (Branch-Referenzen wirklich weg?)
- [ ] Team benachrichtigt bei Breaking Changes (optional)

---

## DoD-Checkliste für verschiedene Task-Typen

### Feature-Implementation
Vollständige Checklist oben + zusätzlich:
- [ ] Feature in [`docs/concepts/`](../concepts/) dokumentiert (falls neues Konzept)
- [ ] User-facing Änderungen in README.md erwähnt

### Bugfix
Minimale Checklist:
- [ ] Code + Tests ✅
- [ ] **todo.md:** Bug-Task als `[x]` markiert
- [ ] **CHANGELOG.md:** Eintrag unter `Fixed`
- [ ] Zeitstempel in todo.md aktualisiert

### Dokumentations-Update
- [ ] Mindestens 2 Personen reviewed (oder AI-Review dokumentiert)
- [ ] Links funktionieren (relative Pfade korrekt)
- [ ] Zeitstempel aktualisiert
- [ ] **NICHT in CHANGELOG** (nur Code-Änderungen)

### Deployment/Operations
- [ ] Deployment erfolgreich (Services laufen)
- [ ] Deployment-Success-Report in [`docs/archive/phases/`](../archive/phases/)
- [ ] todo.md: Deployment-Task als `[x]`

---

## Eskalation bei Nicht-Einhaltung

**Regel:** Ein Merge nach main OHNE vollständige DoD ist ein **Prozess-Verstoß**.

**Konsequenzen:**
1. Post-Mortem-Analyse erforderlich (warum wurde DoD nicht eingehalten?)
2. Sofortiges Dokumentations-Update (innerhalb 1h)
3. Prozess-Review nach 3 Verstößen

**Ausnahme:** Hotfixes in Production-Notfällen dürfen dokumentation aufholen innerhalb 24h.

---

## Template: Merge-Commit-Message

```
<type>(<scope>): <kurze Beschreibung>

Abgeschlossen:
- [x] Task ID 123: Feature XYZ
- [x] Task ID 124: Tests für XYZ

Dokumentation:
- Updated: docs/project/todo.md (Zeitstempel: 2026-04-11 19:45 UTC)
- Updated: CHANGELOG.md (v1.3.0 - Added)
- Created: docs/archive/phases/FEATURE-XYZ-SUCCESS.md

Tests:
- E2E-Tests: 25/25 passed
- Unit-Tests: 142/142 passed

DoD-Checklist: ✅ Vollständig erfüllt

Closes: #issue-number (falls vorhanden)
```

---

## Automatisierung

**Geplant:**
- Pre-Merge-Check-Script: `scripts/docs/pre-merge-check.sh`
- GitHub Actions: `.github/workflows/docs-validation.yml`
- Post-Merge-Hook: `.git/hooks/post-merge`

Siehe [`docs/archive/retrospectives/DOCUMENTATION-SYNC-ROOT-CAUSE-ANALYSIS-20260411.md`](../archive/retrospectives/DOCUMENTATION-SYNC-ROOT-CAUSE-ANALYSIS-20260411.md) für Details.

## 2. Branch-Strategie

### 2.1 Branch-Typen

- **main**: Der Hauptbranch enthält die stabile Produktionsversion des Projekts. Dieser Branch sollte immer in einem funktionsfähigen Zustand sein.
- **feature**: Feature-Branches werden für die Entwicklung neuer Funktionen und Komponenten verwendet. Sie werden vom main-Branch abgezweigt und nach Fertigstellung wieder in diesen zurückgeführt.

### 2.2 Namenskonventionen für Branches

Feature-Branches sollten nach folgendem Schema benannt werden:

```
feature/<komponente>-<beschreibung>
```

Beispiele:
- `feature/tailscale-setup`
- `feature/caddy-config`
- `feature/code-server-installation`
- `feature/ollama-integration`

### 2.3 Besonderheiten

- **Konzeptentwicklung**: Konzepte werden direkt im main-Branch entwickelt und committet.
- **Feature-Entwicklung**: Echter Code und Setup-Skripte für Features werden ausschließlich in separaten Feature-Branches entwickelt.

## 3. Commit-Richtlinien

### 3.1 Aussagekräftige Commit-Nachrichten

Commit-Nachrichten sollten klar und präzise sein und folgendem Format entsprechen:

```
<typ>: <kurze beschreibung>

<detaillierte beschreibung (optional)>
```

Typen:
- `feat`: Neue Funktionalität
- `fix`: Fehlerbehebung
- `docs`: Dokumentationsänderungen
- `test`: Hinzufügen oder Ändern von Tests
- `config`: Konfigurationsänderungen
- `refactor`: Code-Refactoring ohne Funktionsänderung

Beispiele:
- `feat: Tailscale-Installation und Konfiguration hinzugefügt`
- `docs: Installationsanleitung für Caddy aktualisiert`
- `test: E2E-Tests für code-server-Zugriff implementiert`

### 3.2 Atomare Commits

- Jeder Commit sollte eine logische, in sich abgeschlossene Änderung enthalten.
- Vermeiden Sie mehrere unabhängige Änderungen in einem einzigen Commit.
- Teilen Sie große Änderungen in mehrere kleinere, logisch zusammenhängende Commits auf.

### 3.3 Referenzierung von Aufgaben

Commit-Nachrichten sollten auf die entsprechenden Aufgaben in der todo.md verweisen:

```
feat: Tailscale-Installation und Konfiguration hinzugefügt

Implementiert die Aufgabe "Tailscale VPN installieren und konfigurieren" aus todo.md
```

### 3.4 Closing Issues via Commit Messages

GitHub unterstützt das automatische Schließen von Issues durch spezielle Keywords in Commit-Messages. Dies ermöglicht eine nahtlose Integration zwischen Code-Änderungen und Issue-Tracking.

#### Keywords zum automatischen Schließen

Die folgenden Keywords schließen verlinkte Issues automatisch, wenn der Commit in den Default-Branch (main) gemerged wird:

**Primary Keywords:**
- `Closes #123` - Bevorzugt für allgemeine Issue-Closes
- `Fixes #123` - Bevorzugt für Bug-Fixes
- `Resolves #123` - Alternative für allgemeine Resolutionen

**Unterstützte Varianten:**
- `Close`, `Closes`, `Closed`
- `Fix`, `Fixes`, `Fixed`
- `Resolve`, `Resolves`, `Resolved`

**Wichtig:** Keywords müssen **großgeschrieben** sein (z.B. `Closes`, nicht `closes`), um zuverlässig zu funktionieren.

#### Syntax und Beispiele

**Einfaches Issue-Close:**
```bash
git commit -m "feat(ui): add dark mode toggle (Closes #42)"
```

**Bug-Fix mit Issue-Referenz:**
```bash
git commit -m "fix(auth): extend token lifetime to 30min (Fixes #89)

Token was expiring too early (5min), causing frequent logouts.
Increased to 30min and added auto-refresh 5min before expiry.

Tested: Local dev, staging, manual QA"
```

**Mehrere Issues gleichzeitig schließen:**
```bash
git commit -m "feat(backup): automated daily backups (Closes #23, Closes #24)

Implements automated S3 backups with monitoring:
- #23: Backup script with S3 upload
- #24: Monitoring dashboard integration

Scheduled via cron: 02:00 UTC daily"
```

**Alternative Syntax für mehrere Issues:**
```bash
# Mit 'and'
git commit -m "fix: resolve login issues (Fixes #45 and #46)"

# Komma-separiert
git commit -m "feat: user profile improvements (Closes #78, Resolves #79)"
```

**Verwandte Issues ohne Auto-Close:**
```bash
git commit -m "refactor(api): simplify user service logic

Improves code quality and prepares for upcoming features.
Related to #123, See also #124"
```
*Hinweis: `Related to`, `Ref`, `See` schließen Issues NICHT automatisch.*

#### Cross-Repository-Referenzen

Issues in anderen Repositories können ebenfalls referenziert werden:

```bash
git commit -m "feat: API integration (Closes owner/other-repo#42)"
```

#### Commit-Message Format mit Issue-Close

**Empfohlenes Format (Conventional Commits + Issue-Close):**

```
<type>(<scope>): <subject> (Closes #X)

[optional body]

[optional footer with additional issue references]
```

**Vollständiges Beispiel:**
```bash
git commit -m "feat(monitoring): add email notifications for backup failures (Closes #67)

Implements email alerts for failed backups:
- SendGrid integration for email delivery
- HTML template for success/failure notifications
- Configurable recipients via BACKUP_EMAIL_RECIPIENTS env var
- Noise reduction: No alerts for <1% variance from avg backup time

All acceptance criteria from #67 fulfilled.

Related to #23 (backup system infrastructure)
Ref: docs/operations/feature-workflow.md"
```

#### Best Practices

✅ **DO's:**
- **Keyword am Ende des Subjects:** Erhöht Lesbarkeit
  ```
  feat(ui): add dark mode (Closes #42)
  ```
- **Großschreibung verwenden:** `Closes` nicht `closes`
- **Issue-Nummer mit #:** Immer `#123`, nicht `123`
- **Ein Issue pro Feature:** Fördert atomare Commits
- **AC-Erfüllung erwähnen:** "All AC from #X fulfilled"
- **Tests dokumentieren:** Welche Tests durchgeführt wurden
- **Body für Details:** Subject kurz, Details im Body

✅ **Empfohlen:**
```bash
git commit -m "fix(api): resolve timeout on large requests (Fixes #156)

Increased timeout from 30s to 60s for /api/export endpoint.
Added connection pooling to prevent resource exhaustion.

Tested:
- Export with 10k records: Success (42s)
- Export with 50k records: Success (58s)
- Concurrent exports: No resource issues

All AC from #156 fulfilled."
```

❌ **DON'Ts:**
- **Lowercase keywords verwenden:**
  ```
  fixes #123  ❌ (könnte nicht funktionieren)
  Fixes #123  ✅
  ```
- **Keywords im Body statt Subject:**
  ```
  feat: new feature
  
  This closes #123  ❌ (funktioniert nicht zuverlässig)
  ```
- **Vage Referenzen:**
  ```
  fixes the login bug  ❌ (keine Issue-Nummer)
  Fixes #45  ✅
  ```
- **Mehrere Features in einem Commit:**
  ```
  feat: dark mode + notifications + settings (Closes #1, #2, #3)  ❌
  ```
  *Besser: 3 separate Commits mit je einem Issue*

#### Integration mit GitHub Projects

**Automatischer Workflow:**

1. **Issue erstellen** → Landet in "Icebox" oder "Backlog"
2. **Issue in "In Progress" verschieben** → Arbeit beginnt
3. **Branch erstellen:** `feature/#42-dark-mode`
4. **Commits mit Referenz:**
   ```bash
   git commit -m "feat: implement theme switcher (partial #42)"
   git commit -m "feat: add theme persistence (partial #42)"
   git commit -m "feat: complete dark mode UI (Closes #42)"
   ```
5. **PR erstellen** mit "Closes #42" in Beschreibung
6. **PR mergen** → Issue wird automatisch geschlossen
7. **Issue in "Done" verschoben** (automatisch via Projects)

**Partial Progress Tracking:**

Für große Features, die mehrere Commits benötigen:

```bash
# Erster Commit (kein Close)
git commit -m "feat(ui): implement theme toggle component (#42)

Partial progress on #42. Still needed:
- Color scheme CSS variables
- Persistence logic
- Auto-mode support"

# Zweiter Commit (kein Close)
git commit -m "feat(ui): add theme persistence (#42)

Continued work on #42. Remaining:
- Auto-mode support
- Final testing"

# Finaler Commit (Close)
git commit -m "feat(ui): complete dark mode implementation (Closes #42)

All AC from #42 fulfilled:
- [x] Theme toggle in settings
- [x] Persistent user preference
- [x] All components support dark mode
- [x] Auto-mode with system preference
- [x] WCAG 2.1 AA compliance
- [x] Smooth transitions"
```

#### Troubleshooting

**Problem: Issue schließt nicht automatisch**

**Mögliche Ursachen:**
1. ❌ Keyword lowercase: `closes #123` → Verwende `Closes #123`
2. ❌ Issue in anderem Repo: `#123` → Verwende `owner/repo#123`
3. ❌ Commit nicht in main: Feature-Branch → Erst nach Merge in main
4. ❌ Keyword im Body: Verwende Subject-Line
5. ❌ PR nicht gemerged: Nur Keyword in PR → Keyword in Commit-Message

**Lösung:**
```bash
# Korrekter Workflow
git commit -m "feat: new feature (Closes #123)"
git push origin feature/xyz
# PR erstellen
# PR Review & Approve
# PR mergen in main → Issue schließt automatisch
```

**Manuelles Schließen als Fallback:**

Falls automatisches Schließen fehlschlägt:
```bash
gh issue close 123 --comment "Implemented in commit abc1234 and PR #124"
```

#### Checkliste: Issue-Close via Commit

Vor dem Commit:
- [ ] Issue-Nummer korrekt? (z.B. #42)
- [ ] Alle Acceptance Criteria erfüllt?
- [ ] Tests durchgeführt und bestanden?
- [ ] Dokumentation aktualisiert?

Im Commit:
- [ ] Keyword großgeschrieben? (`Closes` nicht `closes`)
- [ ] Keyword im Subject? (nicht nur im Body)
- [ ] Format: `<type>: <description> (Closes #X)`
- [ ] Optional: AC-Erfüllung im Body erwähnt?

Nach dem Merge:
- [ ] Issue automatisch geschlossen?
- [ ] Issue in "Done"-Spalte verschoben? (Projects)
- [ ] Branch gelöscht?

---

## 4. Merge-Prozess

### 4.1 Voraussetzungen für Merges in den main-Branch

Ein Feature-Branch darf nur unter folgenden Bedingungen in den main-Branch gemergt werden:

1. Alle E2E-Tests wurden erfolgreich durchgeführt und bestanden.
2. Die Log-Validierung wurde durchgeführt und zeigt keine Fehler.
3. Der Code wurde einem Review unterzogen und genehmigt.
4. Die Dokumentation wurde aktualisiert.

### 4.2 Code-Review-Prozess

1. Der Entwickler erstellt einen Pull Request vom Feature-Branch in den main-Branch.
2. Ein oder mehrere Teammitglieder überprüfen den Code auf:
   - Funktionalität
   - Codequalität
   - Einhaltung der Projektstandards
   - Vollständigkeit der Tests
   - Vollständigkeit der Dokumentation
3. Feedback wird gegeben und ggf. Änderungen angefordert.
4. Nach Genehmigung kann der Merge durchgeführt werden.

### 4.3 Konfliktlösung

Bei Merge-Konflikten:

1. Den main-Branch in den Feature-Branch mergen, um die Konflikte lokal zu lösen.
2. Konflikte manuell auflösen und sicherstellen, dass die Funktionalität erhalten bleibt.
3. Nach der Konfliktlösung erneut alle Tests durchführen.
4. Den aktualisierten Feature-Branch pushen und den Merge-Prozess fortsetzen.

## 5. Testanforderungen

### 5.1 Tests vor einem Merge

Vor einem Merge in den main-Branch müssen folgende Tests erfolgreich durchgeführt werden:

1. **E2E-Tests**: Live-Tests gegen den Ubuntu VPS, die die Funktionalität der implementierten Features überprüfen.
2. **Integrationstests**: Tests, die die Interaktion zwischen verschiedenen Komponenten überprüfen.
3. **Sicherheitstests**: Überprüfung auf potenzielle Sicherheitslücken.

### 5.2 Validierung von Log-Einträgen

- Alle Tests müssen explizit auf korrekte Log-Ausgaben der jeweiligen Dienste prüfen.
- Log-Einträge sollten auf Fehler, Warnungen und unerwartetes Verhalten überprüft werden.
- Die Log-Validierung muss dokumentiert werden.

## 6. Dokumentationsanforderungen

### 6.1 Aktualisierung der todo.md

- Nach Abschluss einer Aufgabe muss der Status in der todo.md aktualisiert werden.
- Neue Aufgaben, die während der Entwicklung identifiziert werden, müssen in die todo.md aufgenommen werden.
- Die Statusänderung einer Aufgabe muss im Commit dokumentiert werden.

### 6.2 Aktualisierung von Konzeptdokumenten

- Konzeptdokumente müssen aktuell gehalten werden und die tatsächliche Implementierung widerspiegeln.
- Bei Änderungen an der Architektur oder dem Design müssen die entsprechenden Dokumente aktualisiert werden.
- Neue Erkenntnisse oder Entscheidungen müssen dokumentiert werden.

## 7. Workflow-Diagramm

```mermaid
graph TD
    A[Start: Neue Aufgabe] --> B{Konzept oder Code?}
    B -->|Konzept| C[Direkt in main entwickeln]
    B -->|Code/Setup| D[Feature-Branch erstellen]
    D --> E[Implementierung]
    E --> F[Tests schreiben]
    F --> G[E2E-Tests durchführen]
    G --> H[Log-Validierung]
    H --> I[Code-Review]
    I --> J{Review bestanden?}
    J -->|Nein| E
    J -->|Ja| K[In main mergen]
    C --> L[Dokumentation aktualisieren]
    K --> L
    L --> M[Aufgabenstatus aktualisieren]
    M --> N[Ende]

---

## 8. Branch-Management & Cleanup

### 8.1 Wann sollte ein Branch gelöscht werden?

Ein Feature-Branch sollte **sofort nach erfolgreichem Merge** gelöscht werden:

**Lokal löschen:**
```bash
git branch -d feature/name    # Safe delete (nur wenn gemergt)
git branch -D feature/name    # Force delete
```

**Remote löschen:**
```bash
git push origin --delete feature/name
```

### 8.2 Periodischer Branch-Cleanup

**Empfehlung:** Monatlicher oder quartalsweiser Cleanup aller gemergter Branches.

**Cleanup-Workflow:**

1. **Analysiere verbleibende Branches:**
   ```bash
   git branch -a
   git log main..feature/branch-name --oneline
   ```

2. **Prüfe ob vollständig gemergt:**
   ```bash
   git diff main..feature/branch-name
   ```

3. **Lösche lokale Branches:**
   ```bash
   git branch -d feature/branch-1
   git branch -d feature/branch-2
   ```

4. **Lösche Remote-Branches:**
   ```bash
   git push origin --delete feature/branch-1
   git push origin --delete feature/branch-2
   ```

5. **Räume Remote-Referenzen auf:**
   ```bash
   git remote prune origin
   git fetch --prune
   ```

6. **Verifiziere Ergebnis:**
   ```bash
   git branch -a
   ```
   Erwartetes Ergebnis: Nur `main` Branch (lokal + remote)

### 8.3 GitHub Branch Protection & Automatisierung

**Empfohlene GitHub Settings:**

1. **Branch Protection Rules für `main`:**
   - Settings → Branches → Add rule
   - Pattern: `main`
   - ✅ Require pull request reviews before merging
   - ✅ Require status checks to pass before merging
   - ✅ Require branches to be up to date before merging

2. **Automatisches Branch-Cleanup:**
   - Settings → General → "Pull Requests"
   - ✅ Automatically delete head branches
   - Löscht Feature-Branches automatisch nach Merge

3. **Default Branch korrekt setzen:**
   - Settings → General → "Default branch"
   - Muss immer `main` sein
   - **NIEMALS** ein Feature-Branch als Default

### 8.4 Troubleshooting: Branch kann nicht gelöscht werden

**Problem:** `refusing to delete the current branch`

**Ursache:** Branch ist noch als Default-Branch auf GitHub konfiguriert.

**Lösung:**
1. Öffne: `https://github.com/USER/REPO/settings`
2. Navigiere zu "Default branch"
3. Ändere zu `main`
4. Versuche Löschung erneut

### 8.5 Best Practices

✅ **DOs:**
- Feature-Branches sofort nach Merge löschen
- Kurze Lebensdauer von Feature-Branches (Tage, nicht Wochen)
- Regelmäßiger Branch-Cleanup (monatlich/quartalsweise)
- Klare Namenskonventionen einhalten
- Automatisches Branch-Cleanup auf GitHub aktivieren

❌ **DON'Ts:**
- Branches "vergessen" nach Merge
- Lange lebende Feature-Branches (>2 Wochen)
- Feature-Branch als Default-Branch verwenden
- Branches ohne Analyse löschen
- Branches löschen die noch ungemergte Commits haben

### 8.6 Branch-Cleanup Checklist

Bei jedem Cleanup:

- [ ] Alle Branches mit `git branch -a` listen
- [ ] Für jeden Branch: Commits mit main vergleichen
- [ ] Für jeden Branch: Änderungen mit `git diff` prüfen
- [ ] Unfertige Aufgaben in `todo.md` dokumentieren
- [ ] Lokale Branches löschen (`git branch -d`)
- [ ] Remote-Branches löschen (`git push origin --delete`)
- [ ] Remote-Referenzen aufräumen (`git remote prune origin`)
- [ ] Ergebnis verifizieren (`git branch -a`)
- [ ] Cleanup-Report erstellen
- [ ] GitHub Default-Branch auf `main` prüfen

---

## 9. Lessons Learned aus Branch-Cleanup (2026-04-10)

**Situation:** 8 Branches (1 main + 7 feature) aufgeräumt

**Erkenntnisse:**
1. ✅ Alle Feature-Branches waren vollständig gemergt
2. ✅ Keine Datenverluste durch systematische Analyse
3. ⚠️ GitHub Default-Branch war fälschlicherweise auf Feature-Branch gesetzt
4. ⚠️ Branches wurden nicht zeitnah nach Merge gelöscht

**Empfehlungen für die Zukunft:**
1. **Sofortige Löschung:** Branches direkt nach erfolgreichem Merge löschen
2. **GitHub Automation:** "Automatically delete head branches" aktivieren
3. **Default Branch:** Regelmäßig prüfen dass Default auf `main` steht
4. **Dokumentation:** Cleanup-Prozess im Workflow verankern
5. **Prävention:** Single-Purpose-Branches mit kurzer Lebensdauer

**Erfolgsrate:** 87,5% (7 von 8 Branches gelöscht, 1 manueller Schritt nötig)

Siehe vollständigen Report: [`GIT-BRANCH-CLEANUP-REPORT.md`](GIT-BRANCH-CLEANUP-REPORT.md)

---

## Änderungshistorie dieses Dokuments

### 2026-04-11 19:41 UTC
- Definition of Done (DoD) Sektion hinzugefügt
- Dokumentations-Checklist als Pflicht-Bestandteil etabliert
- Pre-Merge und Post-Merge Validierungs-Schritte definiert
- Merge-Commit-Message Template hinzugefügt
- Grund: Verhinderung von Dokumentations-Drift (siehe Root-Cause-Analyse)