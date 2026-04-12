🚀 Migration zu Feature-Based Task-Management

**Epic/Milestone:** Code-Quality & Governance  
**Value:** 🔥🔥 High - Effizienz-Steigerung 10x  
**Effort:** ⏱️ 2h über 3 Phasen  
**Ratio:** 10+ (Critical Priority - Quick-Win!)

---

## 💡 Value Statement

**User-Need:** Als Entwickler möchte ich **auf einen Blick sehen was zu tun ist** und Tasks **mobil vom Handy verwalten**, um effizienter zu arbeiten.

**Problem:** 
- Aktuelle todo.md: 933 Zeilen, 5+ Min Scan-Zeit  
- Abgeschlossene Tasks + Details verstopfen die Übersicht
- Kein Mobile-UX
- "Was ist zu tun?" Antwort dauert zu lange

**Business-Value:** 🔥🔥 High
- 10x schnellerer Task-Überblick (5 Min → 30s)
- Mobile-First-Workflow (GitHub Projects App)
- Automatisches Issue-Closing via Commits
- Value/Effort-basierte Priorisierung transparent

---

## ✅ Acceptance Criteria

### Phase 1: GitHub Project-Board Setup (30 Min)

- [ ] **AC1.1:** GitHub Project-Board "DevSystem Features" erstellt
- [ ] **AC1.2:** 5 Columns konfiguriert: Icebox, Backlog, Next, In Progress (WIP:3), Done
- [ ] **AC1.3:** 10-15 initiale Feature-Issues aus STATUS.md erstellt mit:
  - Feature-Template verwendet
  - Value/Effort-Ratio berechnet
  - Acceptance Criteria definiert
  - Labels: enhancement, priority:high/medium/low
  - Milestones: QS-Integration, Post-MVP, etc.
- [ ] **AC1.4:** Features auf Board verteilt (2 in Next, 8-10 in Backlog, Rest in Icebox)
- [ ] **AC1.5:** Mobile-Access getestet (GitHub Mobile App → Projects funktioniert)

### Phase 2: todo.md Migration (1h)

- [ ] **AC2.1:** Abgeschlossene Tasks archiviert nach `docs/archive/tasks/completed-2026-Q1.md`
- [ ] **AC2.2:** todo.md radikal gekürzt auf ~50 Zeilen:
  - Link zu GitHub Issues & Projects
  - Link zu STATUS.md
  - Link zu Archive
  - Keine Details mehr
- [ ] **AC2.3:** README.md aktualisiert mit Link zu GitHub Projects
- [ ] **AC2.4:** STATUS.md aktualisiert (Primary Source für Quick-Status)

### Phase 3: Workflow-Etablierung (30 Min)

- [ ] **AC3.1:** Issue-Templates erstellt in `.github/ISSUE_TEMPLATE/`:
  - feature.md (Feature-Template)
  - bug.md (Bug-Template, integriert in Features)
- [ ] **AC3.2:** Dokumentiert in docs/operations/:
  - feature-workflow.md (Wie Features verwaltet werden)
  - issue-guidelines.md (Issue-Creation-Rules, Granularität, AC-Best-Practices)
- [ ] **AC3. 3:** Erstes Feature vom Handy getestet:
  - Issue auf Board bewegen
  - AC abhaken
  - Via Commit schließen (Closes #X)
- [ ] **AC3.4:** Git-Workflow aktualisiert (Commit-Messages mit "Closes #X")

---

## 🚫 Out of Scope

Was NICHT in dieser Migration enthalten ist:
- ❌ Komplexe Automation (Auto-Labeling, Bots) → Separates Feature
- ❌ Issue-Analytics-Dashboard → Nice-to-Have
- ❌ Integration mit externen Tools (Jira, Trello) → Nicht nötig
- ❌ Perfektionierung aller Issues → Iterativ verbessern

---

## 🔄 Feature-Splitting

**Dieses Feature NICHT splitten:**
- ✅ Alle 3 Phasen zusammen liefern vollständigen Wert
- ✅ Phase 1 ohne Phase 2 = incomplete (Board ohne migrierte Tasks)
- ✅ Aufwand 2h ist manageable

**Falls Probleme:** Nach Phase 1 evaluieren, ggf. Phase 2+3 separates Issue.

---

## 📦 Deliverables

**Nach Completion verfügbar:**
1. **GitHub Project-Board** mit 10-15 Features
2. **Minimierte todo.md** (~50 Zeilen, nur Links)
3. **Feature-Templates** (.github/ISSUE_TEMPLATE/)
4. **Workflow-Dokumentation** (docs/operations/feature-workflow.md)
5. **Archivierte Historie** (docs/archive/tasks/)
6. **Mobile-Workflow** validiert und dokumentiert

**Nutzen:**
- "Was ist zu tun?" in 30s statt 5 Min beantwortet
- Tasks vom Smartphone manageable
- Automatisches Issue-Closing via Commits

---

## 🧪 Testing-Strategy

- [ ] **Manual Test:** Mobile-Access via GitHub App testen
- [ ] **Workflow-Test:** Feature erstellen, bearbeiten, schließen via Commit
- [ ] **UX-Test:** Nicht-terminaler User kann Board verstehen?
- [ ] **Regression-Test:** Keine Informationen bei Migration verloren?

---

## 📚 References

- **Konzept:** Diskussion vom 2026-04-12 05:38-06:12 UTC
- **Status-Dashboard:** [STATUS.md](STATUS.md)
- **Aktuelle todo.md:** [docs/project/todo.md](docs/project/todo.md) (933 Zeilen)
- **Shellcheck-Report:** [reports/shellcheck/SHELLCHECK-REPORT.md](reports/shellcheck/SHELLCHECK-REPORT.md)

---

## 🎯 Success-Metrics

**Messung nach 1 Woche:**
- [ ] Task-Scan-Zeit: < 1 Min (vorher: 5+ Min)
- [ ] Mobile-Usage: Mindestens 1x Task vom Handy verwaltet
- [ ] Board-Nutzung: Features bewegt zwischen Columns
- [ ] Auto-Close: Mindestens 1 Feature via "Closes #X" geschlossen

**Ziel:** Effizienzgewinn 10x bei Task-Management

---

## 🔗 Dependencies

**Blocked by:** Keine  
**Blocks:** Zukünftige Feature-Erstellung (neue Features folgen Template)

---

**Priority:** 🔴 High (Quick-Win mit massivem Value/Effort-Ratio)  
**Estimate:** 2h total  
**Assignee:** self  
**Milestone:** Code-Quality & Governance
