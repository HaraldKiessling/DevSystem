# .Roo Configuration Changelog

## [1.2.0] - 2026-04-12

### Added
- README.md mit vollständiger Struktur-Dokumentation
  - Beschreibung aller Verzeichnisse und Dateien
  - Verwendung für KI-Assistenten und Entwickler
  - Beziehungen zu anderen Dokumentationen
  - Wartungs- und Versionierungs-Guidelines

### Status
- **Konsolidierung .roo/.Roo**: ✅ Abgeschlossen
  - Nur `.Roo/` Verzeichnis existiert
  - Keine Redundanz mit `.roo/` vorhanden
  - Struktur ist klar organisiert und dokumentiert

### Reason
Beseitigung potenzieller Verwirrung durch parallele Verzeichnisse und Etablierung klarer Dokumentation der `.Roo/`-Struktur.

### Impact
- Klare Navigation in der `.Roo/`-Struktur durch README.md
- Dokumentierte Hierarchie der Regelwerke
- Verbesserte Auffindbarkeit von Regeln und Checklisten

---

## [1.1.0] - 2026-04-11

### Added
- Git-Workflow-Checkpoints Regel (`rules/git-workflow-checkpoints.md`)
  - Obligatorische Validierung bei Branch-basierten Workflows
  - 6 Workflow-Phasen mit Checkpoints
  - Kritische Push-Checkpoints und Fehler-Prevention
  - Workflow-Templates und Automatisierungs-Empfehlungen
- Projekt-Completion-Checkliste (`rules/project-completion-checklist.md`)
  - Git-Status-Validierung vor attempt_completion
  - GitHub-Push-Verifikation verpflichtend
  - Dokumentations- und Code-Qualitäts-Checkpoints

### Reason
Nach Root-Cleanup v1.2 wurde der GitHub-Push vergessen.
19 lokale Commits waren auf main aber nicht auf origin/main.
Neue Regeln stellen sicher, dass Push-Operationen nicht mehr übersehen werden.

### Impact
- Zukünftige Branch-Workflows müssen alle 6 Phasen durchlaufen
- attempt_completion darf nur noch nach GitHub-Push verwendet werden
- Automatisierungs-Empfehlungen für Git-Aliases verfügbar

### Migration
Keine erforderlich. Neue Regeln gelten ab sofort.

---

## [1.0.0] - Initial Configuration

### Added
- Basis-Struktur `.Roo/`
- Context und Rules Dateien
- Mode-spezifische Regeln (architect, code, debug)
- Projekt-Regeln (mission, git-workflow, testing, deployment, code-quality)

---

**Changelog Format:** [Keep a Changelog](https://keepachangelog.com/de/1.0.0/)  
**Versionierung:** [Semantic Versioning](https://semver.org/lang/de/)
