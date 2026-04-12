# Feature-Based Task-Management Workflow

## Übersicht

Das DevSystem verwendet ein **Feature-Based Task-Management** System, das auf GitHub Issues und Projects basiert. Der Workflow ist optimiert für:

- **Value-Driven Development**: Priorisierung nach Business Value
- **Mobile-First**: Effiziente Nutzung auf mobilen Geräten
- **Transparenz**: Klare Sichtbarkeit des Projektfortschritts
- **Effizienz**: Fokus auf High-Value, Low-Effort Features

## 🎯 Kernprinzipien

### 1. Value/Effort-Ratio als Kompass
Jedes Feature wird bewertet nach:
- **Value Score (1-10)**: Business Value, User Impact, Strategic Alignment
- **Effort Score (1-10)**: Komplexität, Zeitaufwand, Risiko
- **Ratio = Value ÷ Effort**: Höhere Werte = höhere Priorität

### 2. Feature über Tasks
- Features beschreiben **Wert** (Value Statement)
- Tasks beschreiben **Arbeit** (To-Do Liste)
- Features treiben die Priorisierung

### 3. Mobile-Optimiert
- Templates sind kurz und strukturiert
- Pflichtfelder minimal
- Schnelle Erfassung unterwegs möglich

---

## 📊 Workflow-Phasen

Der Workflow folgt einem klaren Lifecycle durch die GitHub Projects Spalten:

```
Icebox → Backlog → Next → In Progress → Done
```

### 🧊 Icebox (Ideen-Sammlung)

**Zweck:** Sammlung für alle Ideen ohne Verpflichtung zur Umsetzung

**Kriterien:**
- Neue Feature-Ideen
- Verbesserungsvorschläge
- "Nice-to-have" Features
- Noch nicht bewertete Issues

**Aktionen:**
1. Issue mit Feature-Template erstellen
2. Grundlegende Beschreibung ausfüllen
3. Automatisch in Icebox platziert
4. **Kein Value/Effort-Score erforderlich**

**Beispiel:**
```markdown
Feature: Dark Mode Support
- Autofinished in Icebox
- Value/Effort: TBD
```

---

### 📚 Backlog (Bewertet & Priorisiert)

**Zweck:** Bereite Features mit Value/Effort-Bewertung, sortiert nach Priorität

**Kriterien:**
- Value/Effort-Score zugewiesen
- Acceptance Criteria definiert
- Dependencies geklärt
- Bereit für Umsetzung (technisch & fachlich)

**Aktionen:**
1. Issue aus Icebox reviewen
2. Value/Effort-Ratio berechnen
3. Acceptance Criteria vervollständigen
4. In **Backlog** verschieben
5. Nach Ratio sortieren (höchste zuerst)

**Priorisierungs-Beispiel:**
```
Feature A: Value=9, Effort=3 → Ratio=3.0 (Höchste Priorität)
Feature B: Value=8, Effort=2 → Ratio=4.0 (Höchste Priorität)
Feature C: Value=6, Effort=6 → Ratio=1.0 (Niedrige Priorität)
```

---

### ⏭️ Next (Sprint/Iteration Ready)

**Zweck:** Kurzfristig geplante Features für die nächste Arbeitsphase

**Kriterien:**
- Hohe Value/Effort-Ratio
- Keine blockierenden Dependencies
- Klare Deliverables
- Realistisch im nächsten Sprint/Iteration umsetzbar

**Aktionen:**
1. Top-Features aus Backlog auswählen
2. Kapazität berücksichtigen
3. In **Next** verschieben
4. Optional: Milestone zuweisen

**Kapazitätsplanung:**
- **Klein** (Effort 1-3): ~1-2 Tage
- **Mittel** (Effort 4-6): ~3-5 Tage
- **Groß** (Effort 7-10): ~1-2 Wochen

---

### 🚧 In Progress (Aktive Arbeit)

**Zweck:** Features, an denen aktuell gearbeitet wird

**Kriterien:**
- Arbeit hat begonnen
- Assignee zugewiesen
- Branch erstellt (optional)

**Aktionen:**
1. Issue assignen
2. In **In Progress** verschieben
3. Branch erstellen (z.B. `feature/#123-dark-mode`)
4. Regelmäßige Updates im Issue
5. PR erstellen wenn fertig

**Best Practices:**
- **WIP-Limit:** Max. 2-3 Issues gleichzeitig pro Person
- **Daily Check:** Kurzes Status-Update
- **Blocker sofort melden:** Labels `blocked` hinzufügen

---

### ✅ Done (Abgeschlossen)

**Zweck:** Erfolgreich umgesetzte und geschlossene Features

**Kriterien:**
- Alle Acceptance Criteria erfüllt
- Code merged (falls relevant)
- Dokumentation aktualisiert
- Issue geschlossen via Commit/PR

**Aktionen:**
1. PR Review & Merge
2. Issue wird automatisch geschlossen durch Commit Message:
   ```
   git commit -m "feat: implement dark mode (Closes #123)"
   ```
3. Automatisch in **Done** verschoben
4. Optional: Retrospektive Notes hinzufügen

---

## 🎫 Issue-Templates verwenden

### Feature Request erstellen

1. **GitHub Issue erstellen:**
   - Gehe zu: `github.com/[repo]/issues/new/choose`
   - Wähle: **"Feature Request"**

2. **Pflichtfelder ausfüllen:**
   ```markdown
   ## Value Statement
   Als [Rolle] möchte ich [Ziel] damit [Nutzen]
   
   ## Acceptance Criteria
   - [ ] AC1: Konkrete Anforderung
   - [ ] AC2: Konkrete Anforderung
   
   ## Value/Effort Ratio
   Value: 8/10
   Effort: 3/10
   Ratio: 2.67
   ```

3. **Issue erstellen** → Landet automatisch in **Icebox**

### Bug Report erstellen

1. **GitHub Issue erstellen:**
   - Wähle: **"Bug Report"**

2. **Pflichtfelder ausfüllen:**
   ```markdown
   ## Bug Description
   [Klare Beschreibung]
   
   ## Steps to Reproduce
   1. Schritt 1
   2. Schritt 2
   
   ## Expected vs. Actual Behavior
   Erwartet: [...]
   Tatsächlich: [...]
   
   ## Impact Assessment
   Severity: Hoch
   Frequency: Immer
   ```

3. **Label setzen:** `bug`, `needs-triage`
4. **Priority ermitteln** anhand von Severity + Frequency

---

## 📱 Mobile Workflow

### GitHub Mobile App nutzen

**Vorteile:**
- Issues unterwegs erstellen/aktualisieren
- Notifications checken
- Schnelle Triage

**Optimierungen:**
1. **Kurze Templates:** Nur Pflichtfelder auf Mobile
2. **Voice-to-Text:** Für längere Beschreibungen
3. **Bookmarks:** Direktlinks zu "New Issue" speichern
4. **Notifications:** Push für wichtige Updates

**Typischer Mobile Flow:**
```
Idee haben → GitHub App öffnen → "New Issue" → 
Feature Template → Value Statement diktieren → 
Save → Fertig!
```

### Desktop-Nachbearbeitung

Details später am Desktop hinzufügen:
- Dependencies verlinken
- Out of Scope definieren
- Deliverables auflisten
- Value/Effort justieren

---

## 📈 GitHub Projects Board

### Board-Ansicht

**Spalten-Setup:**
```
| Icebox | Backlog | Next | In Progress | Done |
|   🧊   |   📚    |  ⏭️  |     🚧     |  ✅  |
```

**Views erstellen:**
1. **By Priority:** Sortiert nach Value/Effort-Ratio
2. **By Label:** Gruppiert nach `enhancement`, `bug`, `docs`
3. **By Milestone:** Gruppiert nach Sprint/Release
4. **My Issues:** Gefiltert nach Assignee

### Automatisierung

**Auto-Add Issues:** Neue Issues → Icebox
**Auto-Close:** PR merge → Issue close → Done
**Label-Trigger:** `priority:high` → Next

### Board-Pflege

**Wöchentlich:**
- [ ] Icebox reviewen → In Backlog priorisieren
- [ ] Backlog sortieren nach Ratio
- [ ] Done-Spalte archivieren

**Monatlich:**
- [ ] Value/Effort-Scores überprüfen und anpassen
- [ ] Alte Icebox-Items evaluieren (keep/close)
- [ ] Milestone-Fortschritt checken

---

## ⚙️ Value/Effort-basierte Priorisierung

### Value Score ermitteln (1-10)

**Faktoren:**
- **User Impact (40%):** Wie viele User profitieren? Wie stark?
- **Business Value (40%):** Umsatz, Effizienz, strategische Ziele
- **Technical Debt (20%):** Langfristige Code-Qualität

**Beispiel-Berechnung:**
```
Feature: Automated Backup System
- User Impact: 8 (alle User, kritisch)
- Business Impact: 9 (Datensicherheit, Compliance)
- Tech Debt: 6 (solide Grundlage)
→ Value = (8*0.4 + 9*0.4 + 6*0.2) = 8.0
```

### Effort Score ermitteln (1-10)

**Faktoren:**
- **Zeitaufwand:** Stunden/Tage/Wochen
- **Komplexität:** Technische Herausforderungen
- **Dependencies:** Externe Abhängigkeiten
- **Unsicherheit:** Unbekannte Faktoren

**Mapping:**
```
1-2:  Wenige Stunden, trivial
3-4:  1-2 Tage, klar definiert
5-6:  3-5 Tage, moderate Komplexität
7-8:  1-2 Wochen, komplex
9-10: >2 Wochen, sehr komplex/unsicher
```

### Priorisierungs-Strategie

**Quick Wins (High Value, Low Effort):**
```
Ratio > 2.0 → Sofort umsetzen!
Beispiel: Value=8, Effort=3 → Ratio=2.67
```

**Strategic Investments (High Value, High Effort):**
```
Ratio 1.0-2.0, Value>7 → In Phasen aufteilen
Beispiel: Value=9, Effort=8 → Ratio=1.125
```

**Fill-Ins (Low Value, Low Effort):**
```
Ratio >1.5, Value<6 → Bei freier Kapazität
Beispiel: Value=4, Effort=2 → Ratio=2.0
```

**Money Pits (Low Value, High Effort):**
```
Ratio <1.0 → Kritisch hinterfragen oder ablehnen
Beispiel: Value=4, Effort=8 → Ratio=0.5
```

---

## 🔗 Integration mit Git-Workflow

### Commits mit Issue-Referenz

**Syntax:**
```bash
git commit -m "feat: add dark mode toggle (Closes #123)"
git commit -m "fix: resolve login bug (Fixes #456)"
git commit -m "docs: update API guide (Resolves #789)"
```

**Keywords (schließen automatisch):**
- `Closes #X`
- `Fixes #X`
- `Resolves #X`

### Branch-Naming

**Konvention:**
```
feature/#123-dark-mode-support
bugfix/#456-login-token-expiry
docs/#789-api-documentation
```

### Pull Requests

**PR-Template:**
```markdown
## Related Issue
Closes #123

## Changes
- Implemented dark mode component
- Added user preference storage
- Updated documentation

## Checklist
- [x] All AC from #123 fulfilled
- [x] Tests added
- [x] Documentation updated
```

---

## 📋 Checklisten für verschiedene Aufgaben

### ✅ Neues Feature planen

- [ ] Feature-Issue mit Template erstellen
- [ ] Value Statement formulieren
- [ ] Acceptance Criteria definieren (min. 3)
- [ ] Value/Effort-Score schätzen
- [ ] Dependencies identifizieren
- [ ] In Icebox platzieren
- [ ] Review-Termin planen

### ✅ Feature priorisieren (Icebox → Backlog)

- [ ] Value/Effort-Ratio berechnen
- [ ] Mit anderen Features vergleichen
- [ ] Dependencies prüfen (Blockers?)
- [ ] Deliverables spezifizieren
- [ ] Out of Scope definieren
- [ ] In Backlog verschieben
- [ ] Nach Ratio sortieren

### ✅ Feature umsetzen (Backlog → Next → In Progress)

- [ ] Issue assignen
- [ ] In "Next" verschieben (Sprint-Planning)
- [ ] Branch erstellen
- [ ] In "In Progress" verschieben
- [ ] Acceptance Criteria abarbeiten
- [ ] Tests schreiben
- [ ] PR erstellen
- [ ] Review anfordern

### ✅ Feature abschließen (In Progress → Done)

- [ ] Alle AC erfüllt?
- [ ] Tests bestehen?
- [ ] Dokumentation aktualisiert?
- [ ] PR reviewed & approved?
- [ ] PR mergen mit "Closes #X" in Commit
- [ ] Issue automatisch geschlossen?
- [ ] In "Done" verschoben?
- [ ] Retrospektive Notes (optional)

---

## 🛠️ Tools & Integrationen

### GitHub CLI

**Issues erstellen:**
```bash
gh issue create --template feature.md --title "[FEATURE] Dark Mode"
```

**Issue-Status checken:**
```bash
gh issue list --state open --label feature
```

**Issue schließen:**
```bash
gh issue close 123 --comment "Implemented in PR #124"
```

### VS Code Extensions

Empfohlen:
- **GitHub Pull Requests:** PR-Workflow direkt in VS Code
- **GitHub Issues:** Issue-Ansicht in VS Code
- **GitLens:** Erweiterte Git-Integration

### Mobile Apps

- **GitHub Mobile:** Issues/PR/Notifications
- **Working Copy (iOS):** Git-Client mit GitHub-Integration
- **Termux (Android):** CLI-Access unterwegs

---

## 📚 Best Practices

### DO's ✅

- **Value-Driven:** Immer Value/Effort-Ratio berechnen
- **Atomic Issues:** Ein Feature = Ein Issue
- **Clear AC:** Konkrete, testbare Acceptance Criteria
- **Early Triage:** Regelmäßig Icebox reviewen
- **Close Loop:** Issues immer via Commit schließen
- **Update Status:** Board aktuell halten

### DON'Ts ❌

- **Keine Value-Zahlen ohne Begründung**
- **Keine vagen AC:** "sollte gut funktionieren"
- **Keine offenen Issues vergessen:** Regelmäßig aufräumen
- **Keine Manual-Closes:** Immer via Keyword schließen
- **Keine Riesen-Issues:** Lieber in mehrere aufteilen
- **Keine veralteten Scores:** Regelmäßig neu bewerten

---

## 🔍 Troubleshooting

### Issue landet nicht im Board
**Problem:** Neues Issue erscheint nicht im Projects Board

**Lösung:**
1. Prüfe GitHub Actions (Auto-Add aktiviert?)
2. Manuell zum Board hinzufügen
3. Workflow-Settings in `.github/workflows/` prüfen

### Issue schließt nicht automatisch
**Problem:** Commit mit "Closes #X" schließt Issue nicht

**Lösung:**
- Prüfe: Issue und PR im selben Repo?
- Prüfe: Keyword richtig geschrieben? (`Closes`, nicht `closes`)
- Prüfe: Issue-Nummer korrekt? (`#123`)
- Prüfe: PR merged (nicht nur created)?

### Falsche Priorisierung
**Problem:** Features in falscher Reihenfolge

**Lösung:**
1. Value/Effort-Scores überprüfen
2. Mit Team diskutieren (Perspektivwechsel)
3. Business-Ziele neu abgleichen
4. Board manuell neu sortieren

---

## 📖 Weiterführende Dokumentation

**Issue Management:**
- [`issue-guidelines.md`](./issue-guidelines.md) - Issue-Erstellung, Lifecycle, Labels & Commits
- [`issue-acceptance-criteria.md`](./issue-acceptance-criteria.md) - AC-Framework & Best Practices
- [`issue-examples.md`](./issue-examples.md) - Vollständige Templates & Beispiele

**Git Workflow:**
- [`git-workflow.md`](./git-workflow.md) - Git-Workflow und Commit-Konventionen
- [`.github/ISSUE_TEMPLATE/feature.md`](../../.github/ISSUE_TEMPLATE/feature.md) - Feature-Template
- [`.github/ISSUE_TEMPLATE/bug.md`](../../.github/ISSUE_TEMPLATE/bug.md) - Bug-Template

---

**Version:** 1.0  
**Letzte Aktualisierung:** 2026-04-12  
**Maintainer:** DevSystem Team
