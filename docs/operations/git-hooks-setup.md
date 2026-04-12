# Git-Hooks Setup für Dokumentations-Synchronisation

**Letzte Aktualisierung:** 2026-04-11

---

## Überblick

Git-Hooks unterstützen die Dokumentations-Synchronisation durch automatische Reminder und Validierungen.

**Verfügbare Hooks:**
- **Post-Merge:** Reminder zur Dokumentations-Aktualisierung nach Merges

---

## Installation

### One-Time Setup

1. **Vom Repository-Root ausführen:**
   ```bash
   bash scripts/docs/setup-git-hooks.sh
   ```

2. **Bestätigung:**
   ```
   ✅ Setup abgeschlossen!
   ```

3. **Test:**
   ```bash
   # Trigger Post-Merge Hook manuell
   .git/hooks/post-merge
   ```

### Nach Git-Clone

**Wichtig:** Git-Hooks werden **NICHT** automatisch gecloned!

Jeder neue Entwickler muss nach `git clone` einmalig ausführen:
```bash
bash scripts/docs/setup-git-hooks.sh
```

**Empfehlung:** In Onboarding-Dokumentation aufnehmen.

---

## Post-Merge Hook Details

### Funktionsweise

Nach jedem `git merge` wird automatisch eine Checkliste angezeigt:

```
╔════════════════════════════════════════════════════╗
║  📝 DOKUMENTATIONS-UPDATE ERFORDERLICH!           ║
╚════════════════════════════════════════════════════╝

Nach einem Merge sollten folgende Dokumente aktualisiert werden:

  1. 📋 docs/project/todo.md
     - [ ] Tasks als [x] markieren
     - [ ] Zeitstempel aktualisieren
     - [ ] Branch-Referenzen entfernen

  2. 📝 CHANGELOG.md
     - [ ] Änderungen dokumentieren
     
  3. 📊 docs/reports/DevSystem-Implementation-Status.md
```

### Deaktivierung

**Dauerhaft:**
```bash
rm .git/hooks/post-merge
```

**Temporär:** (für einen Merge)
```bash
git merge --no-verify <branch>
```

### Anpassung

1. Template bearbeiten: `scripts/docs/post-merge-hook-template.sh`
2. Setup erneut ausführen: `bash scripts/docs/setup-git-hooks.sh`

---

## Troubleshooting

### Hook wird nicht ausgeführt

**Prüfe Ausführbarkeit:**
```bash
ls -la .git/hooks/post-merge
# Sollte zeigen: -rwxr-xr-x (executable)
```

**Fehlerbehebung:**
```bash
chmod +x .git/hooks/post-merge
```

### Hook existiert bereits

Setup-Script erstellt automatisch Backup:
```bash
.git/hooks/post-merge.backup-YYYYMMDD-HHMMSS
```

### Hook nach Pull verschwunden

Git-Hooks sind **lokal** und werden nicht per Git synchronisiert.

**Lösung:** Setup erneut ausführen:
```bash
bash scripts/docs/setup-git-hooks.sh
```

---

## Best Practices

1. **Nach jedem Clone:** Setup-Script ausführen
2. **Team-Konvention:** Hooks als Standard etablieren
3. **Dokumentation:** In Onboarding-Docs integrieren
4. **Anpassungen:** Via Template-Dateien, nicht direkt in `.git/hooks/`

---

## Referenzen

- [Git Hooks Dokumentation](https://git-scm.com/docs/githooks)
- [Definition of Done](git-workflow.md#definition-of-done-dod)
- [Pre-Merge-Check Script](../../scripts/docs/pre-merge-check.sh)
- [Root-Cause-Analyse](../archive/retrospectives/DOCUMENTATION-SYNC-ROOT-CAUSE-ANALYSIS-20260411.md)

---

**Erstellt:** 2026-04-11  
**Grund:** Automatisierung der Dokumentations-Synchronisation nach Root-Cause-Analyse
