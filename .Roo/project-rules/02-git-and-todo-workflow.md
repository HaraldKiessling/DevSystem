# Projektmanagement & Git-Workflow

## MVP-Fokus (Minimum Viable Product)
- **Die MVP-Schranke:** Bevor du eine neue Aufgabe planst oder startest, musst du zwingend prüfen: "Ist das für die Kernfunktion (MVP) absolut notwendig?"
- **Backlog-Pflicht:** Wenn die Antwort "Nein" ist oder es sich um ein "Nice-to-have"-Feature handelt, verschiebst du die Aufgabe sofort und unaufgefordert in den Bereich "Backlog / Zukünftige Ausbaustufen" der `todo.md`. Arbeite nur an MVP-Aufgaben!

## MVP-Ausnahmen
- **Regel:** Nur MVP-Features werden entwickelt
- **Ausnahme:** Post-MVP-Features dürfen entwickelt werden, wenn:
  - MVP zu 100% funktionsfähig ist
  - Feature ist dokumentiert als "Post-MVP" in todo.md
  - Feature blockiert keine MVP-Arbeiten
  - User hat explizit zugestimmt
- **Backlog-Review:** Monatlich prüfen ob Post-MVP-Features noch relevant sind

## Zentrale To-Do Liste (`todo.md`)
- Jede Aufgabe muss in der `todo.md` dokumentiert sein.
- **Granularität:** Große Aufgaben MÜSSEN rekursiv in Teilaufgaben zerlegt werden, bis sie einzeln umsetzbar sind.
- **Status-Workflow:** Jede Aufgabe darf nur einen dieser Stati haben:
  1. `Todo`: Aufgabe ist definiert, aber noch nicht gestartet.
  2. `Branch Open`: Ein Feature-Branch wurde erstellt und die Entwicklung läuft.
  3. `E2E Check`: Der Code ist fertig, E2E-Tests gegen den VPS laufen gerade.
  4. `Merged`: E2E-Tests waren erfolgreich, der Branch wurde in `main` integriert.

## Git-Regeln
- **Main-Branch:** Enthält nur fertigen, getesteten Code und Architektur-Konzepte.
- **Feature-Branches:** Jede technische Umsetzung findet auf einem eigenen Branch statt.
- **Merge-Bedingung:** Ein Merge in den `main` passiert NUR nach erfolgreichem E2E-Test inkl. Log-Prüfung.

## Branch-Management
- **Nach Merge:** Feature-Branch MUSS sofort gelöscht werden (lokal + remote)
- **Cleanup-Befehle:**
  ```bash
  # Lokal löschen
  git branch -d feature/name
  # Remote löschen
  git push origin --delete feature/name
  ```
- **GitHub-Automatisierung:** "Automatically delete head branches" MUSS aktiviert sein
- **Default-Branch-Check:** Main-Branch MUSS als GitHub Default konfiguriert sein
- **Monatlicher Audit:** Verbleibende Branches prüfen und dokumentieren

## Hotfix-Prozess (für kritische Bugs in Production)
- **Branch-Naming:** `hotfix/<bug-beschreibung>`
- **Fast-Track:** Hotfixes dürfen E2E-Tests überspringen, wenn:
  - Bug blockiert produktive Nutzung
  - Fix ist minimal (< 20 Zeilen)
  - Code-Review durch zweite Person erfolgt
  - Rollback-Plan dokumentiert ist
- **Post-Merge:** E2E-Tests MÜSSEN nachgeholt werden innerhalb 24h
- **Dokumentation:** Hotfix MUSS in Changelog mit Severity dokumentiert werden

## Dokumentations-Commit-Pflicht
Nach jeder Änderung an Dokumentations-Dateien (*.md) müssen die Änderungen SOFORT committed und gepusht werden, außer die Doku-Änderung ist Teil eines unfertigen Features.

**Prozess:**
1. Dokumentation ändern
2. `git add <dateien>`
3. `git commit -m "docs: [Beschreibung]"`
4. `git push origin main`

**Betroffene Dateien:**
- `todo.md`
- `plans/*.md`
- Status-Reports (PHASE*.md, DEPLOYMENT*.md, etc.)
- Anleitungen (*.md im Root)

## Dokumentations-Konsistenz-Pflicht
Jedes Feature und jede Erweiterung MUSS in der relevanten Dokumentation beschrieben werden, bevor das Issue als abgeschlossen gilt.

### Features (neue Funktionalität)
Features müssen dokumentiert werden mit:
- **Was** es macht
- **Wozu** es dient

**Beispiel:**
```markdown
Dark Mode (#123) - Reduziert Augenbelastung bei Nachtnutzung
```

### Eigenschaften/Erweiterungen
Erweiterungen müssen dokumentiert werden mit:
- **Was** geändert wurde (kann ein Wort sein)

**Beispiele:**
```markdown
Caching (#124)
Performance-Optimierung (#125)
```

### Betroffene Dokumentation
- **Konzepte**: `docs/concepts/*.md` - Für neue Konzepte oder Architektur-Änderungen
- **Operations**: `docs/operations/*.md` - Für Workflow- oder Prozess-Änderungen
- **Deployment**: `docs/deployment/*.md` - Für Deployment-relevante Features
- **README.md**: Für User-facing Features oder wichtige Änderungen

### Prozess
1. Feature/Erweiterung implementieren
2. Relevante Dokumentation identifizieren
3. Kurz-Beschreibung hinzufügen (Was/Wozu oder nur Was)
4. Dokumentations-Update im selben PR/Commit
5. In Acceptance Criteria abhaken

### Warum?
- Verhindert Dokumentations-Drift
- Hält Code und Doku konsistent
- Erleichtert Onboarding neuer Entwickler
- Macht Projekt-Historie nachvollziehbar
