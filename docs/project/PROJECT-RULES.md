# DevSystem - Project Rules

> **Quick-Reference** für Projektstandards, Workflows und Best Practices. Details in verlinkten Dokumenten.

## 1. Dokumentation im Repository

### Markdown-Standards
- **UTF-8 Encoding**: Alle Markdown-Dateien
- **Syntax-Highlighting**: Code-Blöcke mit Sprachbezeichner (```bash, ```yaml, ```typescript)
- **Relative Pfade**: Verlinkungen immer relativ zur aktuellen Datei (`../operations/file.md`)
- **Zeilenlänge**: Maximal 120 Zeichen pro Zeile für bessere Lesbarkeit

### Dokumentenstruktur
- **H1 (`#`)**: Nur ein Mal als Dokumenttitel
- **H2 (`##`)**: Hauptabschnitte
- **H3 (`###`)**: Unterabschnitte
- **Inhaltsverzeichnis**: Bei Dokumenten > 50 Zeilen
- **Datum**: ISO-Format (YYYY-MM-DD) in Changelog-Einträgen

### Dokumentengröße & Diagramme

**Zielbereich:** 100-500 Zeilen pro Dokument

**Diagramme werden NICHT gezählt:**
- Mermaid-Diagramme (```mermaid```)
- PlantUML-Diagramme (```plantuml```)
- Graphviz/DOT-Diagramme (```dot```, ```graphviz```)

**Rationale:**
Diagramme verbessern die Lesbarkeit und verdichten Information. Sie sind ausdrücklich erwünscht für:
- Workflow-Visualisierung (Sequenz-, Flow-Diagramme)
- Architektur-Übersichten (Komponentendiagramme)
- State-Machines und Zustandsübergänge
- Deployment-Topologien

**Beispiel:**
Ein Dokument mit 450 Textzeilen + 100 Zeilen Mermaid-Diagramm = 450 Zeilen (für Validierung)

**Best Practices:**
- Nutze Diagramme für komplexe Zusammenhänge
- Ergänze Diagramme mit kurzen Textbeschreibungen
- Bevorzuge Mermaid (nativ in GitHub)

### Automatische Validierung

Die Dokumentationsregeln werden automatisch überwacht:
- **Pre-commit Hook:** Lokale Prüfung vor jedem Commit
- **GitHub Actions:** CI-Pipeline bei jedem PR
- **Manuelle Prüfung:** `./scripts/docs/validate-docs.sh`

Siehe [`documentation-governance.md`](../operations/documentation-governance.md) für Details.

### Code-Beispiele
```bash
# Beispiel-Script-Aufruf mit Kontext
./scripts/setup-qs-vps.sh
```

**Best Practice**: Immer Kontext zu Code-Snippets liefern (Was macht es? Wann nutzen?)

## 2. System- und Projektanforderungen

### Infrastruktur & Zielsystem
- **Host**: Ubuntu VPS bei IONOS
- **Netzwerkzugang**: Initialer Root-Zugriff per SSH ausschließlich über Tailscale
- **Kernkomponenten**:
  - **Tailscale**: VPN und Netzwerksicherheit
  - **Caddy**: Reverse Proxy (SSL/HTTPS)
  - **code-server**: Web-IDE für Remote-Entwicklung und Multi-Agent-Nutzung

### System-Architektur
- Detaillierte Architektur: [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md)
- Tailscale-Konzept: [`docs/concepts/tailscale-konzept.md`](../concepts/tailscale-konzept.md)
- Caddy-Konzept: [`docs/concepts/caddy-konzept.md`](../concepts/caddy-konzept.md)
- code-server-Konzept: [`docs/concepts/code-server-konzept.md`](../concepts/code-server-konzept.md)

## 3. Projektmanagement & GitHub Issues

### Feature-basierter Workflow
- **Zentrale Steuerung**: Alle Features, Bugs und Tasks über GitHub Issues und GitHub Projects
- **Issue-Templates**: Standardisierte Templates für Konsistenz
- **Bewertungskriterien**:
  - **Value**: Business-Value (1-10, höher = wichtiger)
  - **Effort**: Aufwand in Story Points (1-10, höher = mehr Aufwand)
  - **Ratio**: Value/Effort (höher = höhere Priorität)

### Issue-Lifecycle
```
Icebox → Backlog → Next → In Progress → Done
```

- **Icebox**: Ideen ohne sofortige Priorität
- **Backlog**: Validierte Features, noch nicht geplant
- **Next**: Geplant für nächste Iteration
- **In Progress**: Aktiv in Entwicklung
- **Done**: Abgeschlossen und verifiziert

### Milestone-Management
- **Sprint-basiert**: 2-4 Wochen pro Milestone
- **Clear Goals**: Jeder Milestone hat klar definierte Ziele
- **Retrospektive**: Nach jedem Milestone dokumentieren (siehe [`docs/archive/retrospectives/`](../archive/retrospectives/))

### Labels & Bedeutung
- `type:feature` - Neue Funktionalität
- `type:bug` - Fehlerbehebung
- `type:docs` - Dokumentationsänderung
- `priority:high` - Hohe Priorität
- `priority:low` - Niedrige Priorität
- `status:blocked` - Blockiert durch Abhängigkeiten

**Details**: [`docs/operations/issue-guidelines.md`](../operations/issue-guidelines.md), [`docs/operations/issue-acceptance-criteria.md`](../operations/issue-acceptance-criteria.md), [`docs/operations/issue-examples.md`](../operations/issue-examples.md)

### Value/Effort-Ratio Beispiel
```
Feature: "API Rate Limiting implementieren"
Value: 8 (Security wichtig)
Effort: 4 (Moderate Implementierung)
Ratio: 8/4 = 2.0 (Gute Priorität)

Feature: "Dashboard UI polieren"
Value: 3 (Nice-to-have)
Effort: 6 (Aufwändiges Redesign)
Ratio: 3/6 = 0.5 (Niedrige Priorität)
```

## 4. Entwicklungs- und Test-Workflow

### Iterativer Ansatz
- **MVP-Fokus**: Schnellstmögliche Erreichung eines Minimum Viable Product
- **Inkrementell**: Kleine, testbare Änderungen bevorzugen
- **Feedback-Loop**: Schnelle Validierung durch Tests

### Testing-Strategie
1. **Unit-Tests**: Module und Funktionen isoliert testen
2. **Integration-Tests**: Komponenten-Interaktion validieren
3. **E2E-Tests**: Live gegen Ubuntu VPS (siehe [`docs/concepts/testkonzept.md`](../concepts/testkonzept.md))
4. **Log-Validierung**: Alle Tests müssen Log-Ausgaben prüfen (kritisch!)

### Git-Workflow
- **Konzept-Commits**: Direkt in `main` (nur Dokumentation/Planung)
- **Feature-Entwicklung**: Zwingend auf separaten Feature-Branches
- **Branch-Naming**: `feature/<issue-number>-<short-description>` (z.B. `feature/42-api-rate-limiting`)
- **Merge-Policy**: Nur nach erfolgreichem E2E-Test in `main` mergen

**Details**: [`docs/operations/git-workflow.md`](../operations/git-workflow.md), [`docs/strategies/branch-strategie.md`](../strategies/branch-strategie.md)

### Code-Review-Prozess
1. **Self-Review**: Eigenen Code vor PR prüfen
2. **PR erstellen**: Klare Beschreibung mit Issue-Referenz
3. **Automatische Checks**: CI/CD-Pipeline muss grün sein
4. **Peer-Review**: Optional bei komplexen Änderungen
5. **Merge**: Nach Approval und Tests

### Deployment-Checkliste
- [ ] Alle Tests erfolgreich
- [ ] Dokumentation aktualisiert
- [ ] CHANGELOG.md ergänzt
- [ ] Breaking Changes kommuniziert
- [ ] Rollback-Plan vorhanden

## 5. Richtlinien für Implementierung

### Security-Best-Practices
- **Secrets**: Niemals in Git committen
- **Environment Variables**: Für sensible Daten nutzen
- **SSH-Keys**: Nur über Tailscale-Netzwerk
- **HTTPS**: Obligatorisch für alle Web-Dienste (Caddy)

### Performance-Überlegungen
- **Idempotenz**: Scripts müssen mehrfach ausführbar sein
- **Ressourcen**: Memory/CPU-Limits beachten (VPS-Kontext)
- **Caching**: Wo sinnvoll implementieren
- **Monitoring**: Log-Ausgaben für Debugging

### Code-Qualität
- **Self-Documenting**: Code sollte sich selbst erklären
- **Comments**: Nur für komplexe Logik oder "Warum"-Erklärungen
- **Bash-Scripts**: ShellCheck-konform
- **Error-Handling**: Immer Exit-Codes prüfen

## 6. Systemarchitektur & Roo

### Globale Systemregel
**Roo Code muss diese Regeln als Systemanweisungen verinnerlichen und während des gesamten Projektverlaufs beachten.**

### Roo-Mode-Nutzung

**Code-Mode** (`💻`):
- Feature-Implementierung
- Bug-Fixes
- Script-Erstellung
- Refactoring

**Architect-Mode** (`🏗️`):
- System-Design
- Konzept-Erstellung
- Architektur-Entscheidungen
- Dokumentations-Planung

**Debug-Mode** (`🪲`):
- Fehleranalyse
- Log-Auswertung
- Troubleshooting
- Root-Cause-Analyse

**Orchestrator-Mode** (`🪃`):
- Multi-Step-Workflows
- Komplexe Tasks koordinieren
- Cross-Domain-Aufgaben
- Projekt-Management

### Best Practices für Roo
1. **Modus wählen**: Passenden Modus für Task-Typ verwenden
2. **Context beachten**: Bestehende Dokumentation/Code analysieren
3. **Inkrementell arbeiten**: Kleine, verifizierbare Schritte
4. **Dokumentieren**: Änderungen immer in DOCUMENTATION-CHANGELOG.md festhalten

### Roo-Rules-Referenz
Detaillierte Roo-Konfiguration: [`.Roo/roo-rules.md`](../../.Roo/roo-rules.md)

## 7. Definition of Done (DoD)

### Generische DoD (alle Tasks)
- [ ] Funktionalität implementiert und getestet
- [ ] Code entspricht Projekt-Standards
- [ ] Dokumentation aktualisiert
- [ ] Tests erfolgreich (lokal und CI/CD)
- [ ] Issue referenziert in Commits/PR
- [ ] Peer-Review durchgeführt (wenn nötig)
- [ ] In `main` gemerged

### Feature-spezifische DoD
**Feature-Entwicklung**:
- [ ] E2E-Tests gegen VPS erfolgreich
- [ ] CHANGELOG.md ergänzt
- [ ] User-Dokumentation erstellt

**Bug-Fix**:
- [ ] Root-Cause identifiziert und dokumentiert
- [ ] Regression-Test hinzugefügt
- [ ] Fix verifiziert in Produktions-ähnlicher Umgebung

**Dokumentation**:
- [ ] Markdown-Linting erfolgreich
- [ ] Links validiert
- [ ] DOCUMENTATION-CHANGELOG.md aktualisiert

**Details**: [`docs/operations/git-workflow.md`](../operations/git-workflow.md) (Abschnitt "Definition of Done")

## 8. Kommunikationsrichtlinien

### Commit-Message-Konventionen
Format: `<type>(<scope>): <subject>`

**Typen**:
- `feat`: Neue Funktionalität
- `fix`: Fehlerbehebung
- `docs`: Dokumentation
- `refactor`: Code-Umstrukturierung
- `test`: Test-Ergänzung
- `chore`: Wartungsarbeiten

**Beispiel**:
```
feat(caddy): Add rate limiting for API endpoints (#42)
```

### PR-Beschreibungen
```markdown
## Beschreibung
Kurze Zusammenfassung der Änderungen

## Issue
Closes #42

## Änderungen
- Datei X modifiziert
- Feature Y hinzugefügt

## Tests
- Unit-Tests: ✅
- E2E-Tests: ✅
```

### Issue-Kommentare
- **Updates**: Status-Änderungen dokumentieren
- **Blockers**: Explizit erwähnen mit @mention
- **Lösungen**: Technische Details für andere teilen

### Code-Dokumentation
- **Functions**: Docstring mit Parameter/Return-Beschreibung
- **Scripts**: Header-Kommentar mit Usage-Beispiel
- **Complex Logic**: Inline-Kommentare für "Warum", nicht "Was"

## 9. Troubleshooting & Support

### Hilfe finden
1. **Dokumentation**: Start bei [`docs/README.md`](../README.md)
2. **Troubleshooting-Guide**: [`docs/TROUBLESHOOTING.md`](../TROUBLESHOOTING.md)
3. **Archive**: Gelöste Probleme in [`docs/archive/troubleshooting/`](../archive/troubleshooting/)
4. **GitHub Issues**: Suche nach ähnlichen Problemen

### Debugging-Workflow
1. **Symptom dokumentieren**: Was ist das Problem?
2. **Logs sammeln**: Relevante Log-Ausgaben erfassen
3. **Kontext prüfen**: Was hat sich geändert?
4. **Hypothese**: Vermutete Ursache formulieren
5. **Testen**: Hypothese verifizieren/falsifizieren
6. **Fix implementieren**: Lösung umsetzen
7. **Verifizieren**: Problem als gelöst bestätigen
8. **Dokumentieren**: In Troubleshooting-Guide aufnehmen

### Eskalationspfad
1. **Self-Service**: Dokumentation und Archive durchsuchen
2. **Issue erstellen**: Bei neuen Problemen GitHub Issue öffnen
3. **Debug-Mode**: Roo im Debug-Mode für Analyse nutzen
4. **Dokumentieren**: Lösung für zukünftige Referenz festhalten

## 10. Wichtige Querverweise

### Operations & Workflows
- [`feature-workflow.md`](../operations/feature-workflow.md) - Feature-Entwicklung Schritt-für-Schritt
- [`issue-guidelines.md`](../operations/issue-guidelines.md) - Issue-Erstellung Standards
- [`git-workflow.md`](../operations/git-workflow.md) - Git-Branching und Commits
- [`documentation-governance.md`](../operations/documentation-governance.md) - Dokumentations-Standards

### Strategien & Konzepte
- [`branch-strategie.md`](../strategies/branch-strategie.md) - Branch-Management Details
- [`deployment-prozess.md`](../strategies/deployment-prozess.md) - Deployment-Strategie
- [`VISION.md`](VISION.md) - Projekt-Vision und Ziele

### Architektur & Konzepte
- [`ARCHITECTURE.md`](../ARCHITECTURE.md) - System-Architektur Übersicht
- [`testkonzept.md`](../concepts/testkonzept.md) - Testing-Strategie
- [`sicherheitskonzept.md`](../concepts/sicherheitskonzept.md) - Security-Architektur

## 11. Branch Protection & Deployment

### Green Green Deployment für Dokumentation

**Branch Protection auf `main`:**
- ✅ Dokumentations-Validierung muss erfolgreich sein
- ✅ validate-docs.sh muss durchlaufen (Größe, Referenzen, Diagramme)
- ❌ Direct pushes zu main mit fehlerhafter Dokumentation werden blockiert

**Workflow:**
1. Erstelle Feature-Branch: `git checkout -b docs/feature-name`
2. Ändere Dokumentation
3. Pushe Branch: `git push origin docs/feature-name`
4. GitHub Actions läuft automatisch
5. Bei ✅: Merge möglich
6. Bei ❌: Fehler beheben, erneut pushen

**Status Check:**
- Required: "Validate Documentation Rules" (aus docs-validation.yml)
- Strict mode: Branch muss up-to-date mit main sein
- Force pushes: Verboten
- Branch deletion: Verboten

**Setup-Details:**
Siehe [`documentation-governance.md`](../operations/documentation-governance.md#branch-protection--deployment)

**Override nur im Notfall:**
```bash
# Admin-Override bei critical hotfix (nur wenn absolut notwendig)
# Kontaktiere Tech-Lead vor Override
```

---

**Version**: 2.1 (Branch Protection)
**Letzte Aktualisierung**: 2026-04-12 14:14 UTC
**Maintainer**: DevSystem Team via Roo
