# GitHub Projects Board Setup - DevSystem Features

**Version:** 1.0.0  
**Erstellt:** 2026-04-12  
**Status:** Phase 1 - GitHub Project Board Setup  
**Zeitaufwand:** ~15-20 Minuten

---

## 🎯 Ziel

Erstellen eines GitHub Projects Boards für das DevSystem mit Mobile-First Workflow-Optimierung.

**Board-Name:** `DevSystem Features`  
**Board-Typ:** Board (Enhanced Project)  
**Zugriff:** Private (Repository-Mitglieder)

---

## 📋 Schritt-für-Schritt Anleitung

### AC1.1: Project Board erstellen

1. **Navigiere zu GitHub Projects**
   - Öffne: https://github.com/HaraldKiessling/DevSystem/projects
   - Alternativ: Repository → Tab "Projects"
   
2. **Neues Project erstellen**
   - Klicke auf **"New project"** (grüner Button)
   - Wähle **"Board"** Template (nicht Table oder Roadmap)
   
3. **Board konfigurieren**
   - **Project name:** `DevSystem Features`
   - **Description:** `Feature-Tracking für DevSystem mit Mobile-First Workflow`
   - **Visibility:** Private (Default)
   - Klicke **"Create project"**

✅ **Checkpoint:** Du siehst jetzt ein leeres Board mit Default-Columns (Todo, In Progress, Done)

---

### AC1.2: Custom Columns erstellen

Das Standard-Board hat 3 Columns. Wir benötigen 5 spezifische Columns:

1. **Lösche existierende Columns** (außer eine als Placeholder)
   - Klicke auf Column-Header → "⋮" Menü → "Delete column"
   - Behalte eine Column zum Umbenennen

2. **Erstelle die 5 Columns** (in dieser Reihenfolge):

   **Column 1: Icebox** ❄️
   - Column name: `Icebox`
   - Description: `Nice-to-have Features, niedrige Priorität`
   - Position: Ganz links
   - Automation: None

   **Column 2: Backlog** 📦
   - Column name: `Backlog`
   - Description: `Validierte Features, warten auf Priorisierung`
   - Automation: None

   **Column 3: Next** 🎯
   - Column name: `Next`
   - Description: `Höchste Priorität, als nächstes zu bearbeiten`
   - Automation: None

   **Column 4: In Progress** 🚧
   - Column name: `In Progress`
   - Description: `Aktiv in Bearbeitung (max 3 gleichzeitig)`
   - **WIP Limit:** 3 (Work in Progress Limit)
   - Automation: None (manuelles Move bei Start)

   **Column 5: Done** ✅
   - Column name: `Done`
   - Description: `Abgeschlossene Features`
   - Automation: **Enabled** (siehe AC1.3)

**Wie erstelle ich eine neue Column?**
- Klicke rechts neben der letzten Column auf **"+ Add column"**
- Fülle Name und Description aus
- Speichern

✅ **Checkpoint:** Du hast 5 Columns in der Reihenfolge: Icebox → Backlog → Next → In Progress → Done

---

### AC1.3: Automation konfigurieren

GitHub Projects bietet Built-in Workflows für Automation:

#### Done-Automation aktivieren

1. **Öffne Board Settings**
   - Klicke oben rechts auf **"⋮"** (drei Punkte)
   - Wähle **"Workflows"**

2. **Item Closed Workflow**
   - Finde Workflow: **"Item closed"**
   - Klicke auf **"Edit"**
   - Set status to: **"Done"**
   - Klicke **"Save"**

3. **Optional: Item Reopened Workflow**
   - Workflow: **"Item reopened"**
   - Set status to: **"Backlog"** oder **"Next"**
   - Klicke **"Save"**

**Was macht das?**
- Issues/PRs werden automatisch in "Done" verschoben, wenn sie geschlossen werden
- Bei Reopen werden sie automatisch zurück ins Backlog verschoben

✅ **Checkpoint:** Automation ist aktiv. Test folgt in AC1.5.

---

### AC1.4: Board-Views konfigurieren

**Board-View (Default)**
- Die Standard-Ansicht ist bereits perfekt für unseren Workflow
- Keine Änderungen nötig

**Optional: Table-View hinzufügen**
1. Klicke oben links auf **"Board"** Dropdown
2. Wähle **"+ New view"**
3. Wähle **"Table"**
4. Nenne es: `All Features (Table)`
5. Konfiguriere sichtbare Felder:
   - Title
   - Status (Column)
   - Labels
   - Assignees
   - Milestone

**Warum Table-View?**
- Bulk-Editing auf Desktop
- Bessere Übersicht über viele Issues
- Filtern/Sortieren nach Labels, Milestones

✅ **Checkpoint:** Board hat mindestens 1 View (Board-View). Optional: Table-View.

---

### AC1.5: Mobile Access testen

**Voraussetzung:** GitHub Mobile App installiert  
📱 Download: [iOS](https://apps.apple.com/app/github/id1477376905) | [Android](https://play.google.com/store/apps/details?id=com.github.android)

#### Mobile Test Checklist

1. **App öffnen und einloggen**
   - Öffne GitHub Mobile App
   - Login mit deinem Account

2. **Zum Project navigieren**
   - Tippe auf **"☰"** (Hamburger Menu)
   - Wähle **"Repositories"**
   - Öffne: **"HaraldKiessling/DevSystem"**
   - Tippe auf **"Projects"** Tab
   - Wähle **"DevSystem Features"**

3. **Board testen**
   - ✅ Kannst du alle 5 Columns sehen?
   - ✅ Kannst du horizontal scrollen?
   - ✅ Ist die Schrift gut lesbar?

4. **Issue erstellen (Mobile)**
   - Tippe auf **"+"** Button (unten rechts)
   - Wähle **"Issue"**
   - Repository: DevSystem
   - Title: `Test Issue from Mobile`
   - Assign to project: `DevSystem Features`
   - Column: `Backlog`
   - Erstelle Issue

5. **Issue verschieben (Mobile)**
   - Tippe auf das Test-Issue
   - Tippe auf **"Status"** Feld
   - Wähle neue Column (z.B. "Next")
   - Verifiziere: Issue ist verschoben

6. **Issue schließen (Mobile)**
   - Öffne das Test-Issue
   - Tippe auf **"⋮"** (drei Punkte)
   - Wähle **"Close issue"**
   - Gehe zurück zum Board
   - ✅ Verifiziere: Issue ist automatisch in "Done"

7. **Test-Issue aufräumen**
   - Lösche das Test-Issue (optional)

✅ **Checkpoint:** Mobile Workflow funktioniert vollständig. Board ist einsatzbereit!

---

## 🎨 Board Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│ DevSystem Features                                          ⋮  + Add │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│ ❄️ Icebox   📦 Backlog   🎯 Next   🚧 In Progress   ✅ Done        │
│ ──────────  ───────────  ────────  ───────────────  ───────────     │
│                                                                       │
│ Nice-to-    Validiert,   Höchste   Aktiv in         Abgeschlossen   │
│ have        wartet       Priorität  Bearbeitung     Features         │
│ Features    auf Prio                (WIP: 3)                         │
│                                                                       │
│ [Issues]    [Issues]     [Issues]  [Issues]         [Issues]        │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 📊 Column Guidelines

### Icebox ❄️
**Purpose:** Ideen-Speicher für Nice-to-have Features

**Wann hierher?**
- Value/Effort < 0.5
- Niedrige Business-Priorität
- Experimentelle Features
- "Someday/Maybe" Items

**Typische Labels:** `enhancement`, `nice-to-have`, `exploration`

---

### Backlog 📦
**Purpose:** Validierte Features, bereit für Priorisierung

**Wann hierher?**
- Feature ist definiert (Acceptance Criteria vorhanden)
- Value/Effort ≥ 0.5
- Medium Business Value
- Keine unmittelbaren Dependencies

**Typische Labels:** `enhancement`, `feature`, `documentation`

**Ziel-Anzahl:** 8-10 Issues (gute Auswahl für Sprint-Planning)

---

### Next 🎯
**Purpose:** Höchste Priorität - als nächstes zu bearbeiten

**Wann hierher?**
- High Business Value
- Value/Effort > 1.0 (idealerweise)
- Alle Dependencies erfüllt
- Klar definiert und schätzbar

**Typische Labels:** `priority-high`, `ready`, `quick-win`

**Ziel-Anzahl:** 2-3 Issues (kurze, fokussierte Liste)

---

### In Progress 🚧
**Purpose:** Aktiv in Bearbeitung

**WIP Limit:** Max 3 Issues gleichzeitig

**Wann hierher?**
- Arbeit hat begonnen
- Branch erstellt oder PR offen
- Assignee zugewiesen

**Typische Labels:** `in-progress`, `blocked` (falls blockiert)

**Regel:** Neue Issues nur starten, wenn WIP < 3

---

### Done ✅
**Purpose:** Abgeschlossene Features

**Wann hierher?**
- Issue ist geschlossen (closed)
- Alle Acceptance Criteria erfüllt
- Code merged (falls Code-Change)
- Dokumentation aktualisiert

**Automation:** ✅ Automatisch beim Schließen

**Archivierung:** Nach 30 Tagen automatisch ausgeblendet (GitHub-Feature)

---

## 🔄 Workflow: Issue Lifecycle

```
1. CREATE
   └─> Icebox (Low Priority)
       └─> Backlog (Validated, Medium Priority)
           └─> Next (High Priority, Ready)
               └─> In Progress (Actively Working, WIP ≤ 3)
                   └─> Done (Closed, Automated)
```

**Mobile Workflow:**
1. Erstelle Issue via Mobile
2. Assign to Project: "DevSystem Features"
3. Wähle Column basierend auf Priorität
4. Verschiebe beim Start in "In Progress"
5. Schließe Issue → Auto-move to "Done"

---

## 🎯 Best Practices

### Priorisierung
- **Icebox:** Unlimited
- **Backlog:** 8-10 Issues (Sprint-Ready)
- **Next:** 2-3 Issues (Fokus!)
- **In Progress:** Max 3 (WIP Limit)

### Value/Effort-Ratios
- **Quick Wins (> 2.0):** Sofort in "Next"
- **High Value (1.0-2.0):** "Backlog" oder "Next"
- **Medium Value (0.5-1.0):** "Backlog"
- **Low Value (< 0.5):** "Icebox"

### Labels verwenden
- `priority-high`, `priority-medium`, `priority-low`
- `quick-win` (Value/Effort > 2.0)
- `epic` (große Features, mehrere Sub-Issues)
- `enhancement`, `bug`, `documentation`

### Mobile-First Mindset
- Kurze, klare Issue-Titles (< 50 Zeichen)
- Klare Acceptance Criteria (Checkboxen)
- Labels für schnelle Filterung
- Emojis für visuelle Orientierung

---

## ✅ Validierung

Nach Setup solltest du:
- ✅ Ein Board mit 5 Columns haben
- ✅ Done-Automation aktiviert haben
- ✅ Board auf Desktop UND Mobile sehen
- ✅ Issues erstellen, verschieben und schließen können
- ✅ Auto-Move in "Done" beim Schließen beobachten

---

## 🔗 Next Steps

Nach erfolgreichem Board-Setup:
1. Siehe [`feature-issues-batch-1.md`](feature-issues-batch-1.md) für vordefinierte Feature-Issues
2. Siehe [`phase1-checklist.md`](phase1-checklist.md) für komplette Checklist

---

## 📚 Referenzen

**GitHub:**
- [GitHub Projects Documentation](https://docs.github.com/en/issues/planning-and-tracking-with-projects)
- [GitHub Mobile App](https://github.com/mobile)

**Workflow:**
- [Feature Workflow Guide](feature-workflow.md)
- [Issue Guidelines](issue-guidelines.md) - Kernkonzepte & Prozesse
- [Acceptance Criteria](issue-acceptance-criteria.md) - AC-Framework
- [Issue Examples](issue-examples.md) - Templates

---

**Erstellt für:** [GitHub Issue #1 - Phase 1](https://github.com/HaraldKiessling/DevSystem/issues/1)  
**Letztes Update:** 2026-04-12  
**Maintainer:** DevSystem Team
