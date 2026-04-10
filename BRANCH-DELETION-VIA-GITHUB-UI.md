# Branch-Löschung via GitHub Web UI

**Problem:** `git push origin --delete feature/vps-preparation` wird blockiert mit "refusing to delete the current branch"

**Grund:** GitHub's Default-Branch-Änderung ist noch nicht vollständig propagiert

**Lösung:** Branch direkt über GitHub Web UI löschen

---

## Anleitung: Branch über GitHub UI löschen

### Schritt 1: Branches-Seite öffnen

**URL:**
```
https://github.com/HaraldKiessling/DevSystem/branches
```

**Oder navigiere:**
1. Öffne https://github.com/HaraldKiessling/DevSystem
2. Klicke auf "Branches" (neben dem Branch-Dropdown)
3. Oder klicke auf "X branches" unter dem Code-Tab

### Schritt 2: Branch finden

Auf der Branches-Seite siehst du eine Liste:

```
Active branches
--------------
main            [default]  [...]
feature/vps-preparation    [🗑️ Delete icon]
```

**Suche:** `feature/vps-preparation`

### Schritt 3: Branch löschen

1. **Rechts neben dem Branch-Namen** findest du ein Papierkorb-Icon 🗑️
2. **Klicke auf das Papierkorb-Icon**
3. **Bestätige die Löschung**
   - Ein Dialog erscheint: "Are you sure you want to delete feature/vps-preparation?"
   - Klicke: **"Delete this branch"** (roter Button)

### Schritt 4: Bestätigung

Nach erfolgreicher Löschung:
- Der Branch verschwindet aus der Liste
- Du siehst eine Confirmation-Meldung: "Branch feature/vps-preparation was deleted"
- *(Restore-Option ist 7 Tage verfügbar falls Fehler)*

---

## Nach der Löschung: Lokale Bereinigung

Nachdem du den Branch auf GitHub gelöscht hast, bereinige lokal:

```bash
# Remote-Referenzen aktualisieren
git fetch --prune
git remote prune origin

# Verifizieren
git branch -a

# Erwartetes Ergebnis:
# * main
#   remotes/origin/HEAD -> origin/main
#   remotes/origin/main
```

---

## Troubleshooting

### "Ich finde das Papierkorb-Icon nicht"

**Mögliche Gründe:**

1. **Branch ist protected:**
   - Gehe zu: Settings → Branches
   - Suche nach Branch Protection Rules
   - Lösche die Rule für `feature/vps-preparation`

2. **Fehlende Berechtigungen:**
   - Du benötigst Admin/Write-Rechte
   - Prüfe: Settings → Manage access

3. **Branch ist Default-Branch:**
   - Das Papierkorb-Icon wird NICHT angezeigt für Default-Branches
   - **WICHTIG:** Prüfe Settings → Branches
   - Stelle sicher, dass dort "main" als Default steht!

### "Nach Löschung zeigt Git den Branch noch an"

```bash
# Aggressive Bereinigung:
git remote update --prune
rm -rf .git/refs/remotes/origin/feature/vps-preparation
git fetch --all --prune

# Dann prüfen:
git branch -a
```

### "Branch wurde gelöscht, aber ist wieder da"

- Jemand hat den Branch gepusht (unwahrscheinlich)
- GitHub hat ein temporäres Problem
- Du bist in einem anderen Repository

---

## Alternative: GitHub CLI

Falls Web UI nicht funktioniert:

```bash
# GitHub CLI installieren
# https://cli.github.com/

# Login
gh auth login

# Branch löschen
gh api \
  --method DELETE \
  repos/HaraldKiessling/DevSystem/git/refs/heads/feature/vps-preparation

# Oder einfacher:
gh api repos/HaraldKiessling/DevSystem/git/refs/heads/feature/vps-preparation \
  -X DELETE
```

---

## Nach erfolgreicher Löschung

1. ✅ Branch auf GitHub gelöscht
2. ✅ Lokal bereinigt: `git fetch --prune`
3. ✅ Verifiziert: `git branch -a` zeigt nur main
4. ✅ Dokumentation finalisiert
5. ✅ Commit & Push

**Cleanup ist komplett! 🎉**

---

**Erstellt:** 2026-04-10 13:13 UTC  
**Für:** Branch-Cleanup via GitHub Web UI  
**Status:** Alternative Lösung bei Git-Command-Blockierung
