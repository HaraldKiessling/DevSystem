# Issue Guidelines & Best Practices

## 📚 Related Documentation
- [Acceptance Criteria](issue-acceptance-criteria.md) - AC-Framework & Best Practices
- [Issue Examples](issue-examples.md) - Templates & Beispiele
- [Feature Workflow](./feature-workflow.md) - Gesamter Feature-Workflow

## Übersicht

Dieses Dokument beschreibt Best Practices für die Erstellung, Verwaltung und Bearbeitung von GitHub Issues im DevSystem-Projekt. Es ergänzt den [Feature-Workflow](./feature-workflow.md) mit konkreten Anleitungen.

Für detaillierte Informationen zu Acceptance Criteria siehe [issue-acceptance-criteria.md](issue-acceptance-criteria.md).  
Für vollständige Templates und Beispiele siehe [issue-examples.md](issue-examples.md).

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

### Issue-Typen

**Feature Request**
- Neue Funktionen oder Verbesserungen
- Benötigt: Value/Effort-Ratio, Value Statement
- Template: `.github/ISSUE_TEMPLATE/feature.md`

**Bug Report**
- Fehler oder unerwartetes Verhalten
- Benötigt: Reproduktionsschritte, Impact Assessment
- Template: `.github/ISSUE_TEMPLATE/bug.md`

**Documentation**
- Dokumentations-Updates oder -Ergänzungen
- Feature-Template anpassen oder Blank-Issue mit `docs` Label

**Refactoring/Chore**
- Code-Verbesserungen, Maintenance, technische Debt
- Feature-Template anpassen oder Blank-Issue mit entsprechenden Labels

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
This is a feature request for implementing...  # Zu lang
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

## Wie (initial)
- Theme-Toggle in Settings
- CSS-Variablen für Farb-Schema
- Persistierung der User-Präferenz
```

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

### Effort Score (1-10)

**Bewertungs-Framework:**

| Score | Zeitaufwand | Komplexität | Dependencies | Unsicherheit |
|-------|-------------|-------------|--------------|--------------|
| 9-10 | >2 Wochen | Sehr komplex | Viele externe | Sehr hoch |
| 7-8 | 1-2 Wochen | Komplex | Mehrere externe | Hoch |
| 5-6 | 3-5 Tage | Moderat | Wenige interne | Mittel |
| 3-4 | 1-2 Tage | Einfach | Keine | Niedrig |
| 1-2 | <1 Tag | Trivial | Keine | Minimal |

### Ratio berechnen

```
Ratio = Value / Effort
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
- Value (X): [Begründung mit Fokus auf Impact]
- Effort (Y): [Zeitaufwand, Komplexität, Dependencies]
- Ratio (Z): [Prioritäts-Einschätzung]
```

**Beispiel:**
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
## Triage Meeting - YYYY-MM-DD

### Neue Issues (needs-triage)
- [ ] #XXX - Value/Effort bewerten
- [ ] #XXX - Labels zuweisen
- [ ] #XXX - In Backlog priorisieren

### Blocked Issues
- [ ] #XXX - Dependency check → Follow-up
- [ ] #XXX - External API issue → Contact vendor

### Stale Issues (>30 Tage inaktiv)
- [ ] #XXX - Still relevant? → Close oder Update
- [ ] #XXX - Waiting for response → Ping contributor

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

---

## ✅ Pre-Submit-Checkliste

Vor dem Erstellen eines Issues:

- [ ] Titel ist prägnant und beschreibend
- [ ] Template korrekt ausgefüllt (Feature oder Bug)
- [ ] Value/Effort-Score geschätzt (Feature)
- [ ] Impact Assessment (Bug)
- [ ] Acceptance Criteria konkret und testbar (siehe [AC-Guidelines](issue-acceptance-criteria.md))
- [ ] Labels zugewiesen
- [ ] Duplicates gecheckt (Search existierende Issues)
- [ ] Related Issues verlinkt
- [ ] Rechtschreibung geprüft

---

## 📖 Weiterführende Ressourcen

**Projekt-Dokumentation:**
- [Acceptance Criteria Guidelines](issue-acceptance-criteria.md) - AC-Framework & Best Practices
- [Issue Examples & Templates](issue-examples.md) - Vollständige Beispiele
- [Feature Workflow](./feature-workflow.md) - Gesamter Feature-Workflow
- [Git Workflow](./git-workflow.md) - Git-Conventions
- [`.github/ISSUE_TEMPLATE/`](../../.github/ISSUE_TEMPLATE/) - Issue-Templates

**Externe Referenzen:**
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Issue Linking](https://docs.github.com/en/issues/tracking-your-work-with-issues/linking-a-pull-request-to-an-issue)
- [User Story Mapping](https://www.jpattonassociates.com/user-story-mapping/)
- [INVEST Criteria](https://en.wikipedia.org/wiki/INVEST_(mnemonic))

---

**Version:** 2.0  
**Letzte Aktualisierung:** 2026-04-12  
**Maintainer:** DevSystem Team
