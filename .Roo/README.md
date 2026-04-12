# .Roo Configuration Directory

Dieses Verzeichnis enthält alle Projekt-spezifischen Konfigurationen, Regelwerke und Kontext-Informationen für das DevSystem-Projekt.

## Verzeichnisstruktur

```
.Roo/
├── README.md                      # Diese Datei - Struktur-Dokumentation
├── CHANGELOG.md                   # Änderungshistorie der .Roo-Konfiguration
├── context.md                     # Projekt-Kontext und Übersicht
├── rules.md                       # Quickstart-Zusammenfassung aller Regeln
│
├── mode-rules/                    # Mode-spezifische Regeln
│   ├── architect.md              # Regeln für Architekt-Mode
│   ├── code.md                   # Regeln für Code-Mode
│   └── debug.md                  # Regeln für Debug-Mode
│
├── project-rules/                 # Grundlegende Projekt-Regeln
│   ├── 01-mission-and-stack.md   # Projekt-Mission und Tech-Stack
│   ├── 02-git-and-todo-workflow.md  # Git- und To-Do-Workflow
│   ├── 03-testing-and-decission.md  # Testing und Entscheidungsfindung
│   ├── 04-deployment-and-operations.md  # Deployment und Operations
│   └── 05-code-quality.md        # Code-Qualitäts-Standards
│
└── rules/                         # Spezifische Workflow-Checklisten
    ├── git-workflow-checkpoints.md     # 6-Phasen Git-Workflow mit Checkpoints
    └── project-completion-checklist.md # Checkliste vor attempt_completion
```

## Zweck der Komponenten

### Kern-Dateien

#### [`context.md`](context.md)
Projekt-Kontext und Übersicht - gibt einen schnellen Überblick über das DevSystem-Projekt.

#### [`rules.md`](rules.md)
Kompakte Zusammenfassung aller wichtigen Regeln als Quickstart-Referenz. Enthält:
- Unverrückbare Kernregeln (To-Do, Git, Entwicklungsprinzipien)
- Technologie-Stack
- Dokumentationsstandards

### Mode-spezifische Regeln ([`mode-rules/`](mode-rules/))

Spezifische Anweisungen für verschiedene Roo-Modi:
- **Architect Mode**: Planung, Design, Strategie
- **Code Mode**: Implementierung, Refactoring
- **Debug Mode**: Fehleranalyse, Troubleshooting

### Projekt-Regeln ([`project-rules/`](project-rules/))

Detaillierte, nummerierte Regelwerke in logischer Reihenfolge:

1. **Mission & Stack**: Projektziele, Technologie-Entscheidungen
2. **Git & To-Do Workflow**: Branching-Strategie, Commit-Konventionen, To-Do-Management
3. **Testing & Decision**: Test-Strategien, Entscheidungsfindungs-Prozesse
4. **Deployment & Operations**: Deployment-Prozeduren, Operations-Guidelines
5. **Code Quality**: Coding-Standards, Best Practices

### Workflow-Checklisten ([`rules/`](rules/))

Spezialisierte Checklisten für kritische Workflows:

- **[`git-workflow-checkpoints.md`](rules/git-workflow-checkpoints.md)**: 6-Phasen-Workflow für Branch-basierte Entwicklung mit obligatorischen Checkpoints. Verhindert häufige Fehler wie vergessene Pushes.

- **[`project-completion-checklist.md`](rules/project-completion-checklist.md)**: Validation-Checkliste vor Verwendung von `attempt_completion`. Stellt sicher, dass Git-Status, Dokumentation und Code-Qualität stimmen.

## Verwendung

### Für KI-Assistenten (Roo)
Alle Dateien in diesem Verzeichnis sind Teil der Projekt-Governance und sollten bei Entwicklungsaktivitäten berücksichtigt werden. Die Regeln sind hierarchisch organisiert:

1. **Start**: [`rules.md`](rules.md) für Quickstart
2. **Details**: [`project-rules/`](project-rules/) für vertiefte Information
3. **Workflows**: [`rules/`](rules/) für spezifische Checklisten
4. **Mode-spezifisch**: [`mode-rules/`](mode-rules/) für jeweiligen Mode

### Für Entwickler
Diese Konfiguration dokumentiert Best Practices und etablierte Workflows für das DevSystem-Projekt. Sie sollte bei Codeänderungen, Deployments und Architektur-Entscheidungen konsultiert werden.

## Beziehung zu anderen Dokumentationen

- **Projekt-Dokumentation**: [`docs/project/`](../docs/project/) - Projektweite Dokumentation
- **Operations**: [`docs/operations/`](../docs/operations/) - Operative Guides und Workflows
- **Architektur**: [`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md) - System-Architektur

Die `.Roo/`-Konfiguration fokussiert auf **Entwicklungs-Workflows und Regeln**, während `docs/` die **technische Dokumentation** enthält.

## Wartung

### Änderungen dokumentieren
Alle Änderungen an der `.Roo/`-Konfiguration müssen in [`CHANGELOG.md`](CHANGELOG.md) eingetragen werden.

### Versionierung
Die Konfiguration folgt [Semantic Versioning](https://semver.org/lang/de/):
- **MAJOR**: Grundlegende Änderungen an Workflows/Regeln
- **MINOR**: Neue Regeln oder Checklisten
- **PATCH**: Kleinere Verbesserungen, Bugfixes

Aktuelle Version siehe [`CHANGELOG.md`](CHANGELOG.md).

## Historie

- **2026-04-12**: README.md hinzugefügt, Struktur dokumentiert, Konsolidierungs-Status dokumentiert
- **2026-04-11**: Git-Workflow-Checkpoints und Project-Completion-Checklist hinzugefügt (v1.1.0)
- **Initial**: Basis-Struktur mit Context, Rules, Mode-Rules und Project-Rules (v1.0.0)

---

**Erstellt:** 2026-04-12  
**Zweck:** Zentrale Projekt-Konfiguration und Regelwerk  
**Wartung:** Bei jeder Regeländerung aktualisieren
