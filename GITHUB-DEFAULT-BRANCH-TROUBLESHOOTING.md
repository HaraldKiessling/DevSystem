# GitHub Default-Branch Troubleshooting: "Could not change default branch"

**Problem:** GitHub zeigt die Fehlermeldung "Could not change default branch" beim Versuch, von `feature/vps-preparation` auf `main` zu wechseln.

**Datum:** 2026-04-10 13:08 UTC  
**Repository:** https://github.com/HaraldKiessling/DevSystem

---

## Diagnose-Checkliste

### 1. Offene Pull Requests prüfen

**Problem:** Offene PRs, die auf `feature/vps-preparation` zielen, blockieren den Wechsel.

**Prüfen:**
```
https://github.com/HaraldKiessling/DevSystem/pulls
```

**Lösungen:**
- **Option A:** Alle offenen PRs schließen oder mergen
- **Option B:** PRs auf `main` als Target umstellen
  - Öffne jeden PR
  - Klicke auf "Edit" neben "base: feature/vps-preparation"
  - Ändere zu "base: main"
  - Speichern

---

### 2. Branch Protection Rules prüfen

**Problem:** Branch Protection Rules verhindern die Änderung.

**Prüfen:**
```
https://github.com/HaraldKiessling/DevSystem/settings/branches
```

**Suche nach:**
- Branch protection rules für `feature/vps-preparation`
- Regeln wie "Require pull request reviews before merging"
- "Lock branch" Status

**Lösung:**
1. Finde die Protection Rule für `feature/vps-preparation`
2. Klicke auf "Delete" neben der Rule
3. Bestätige die Löschung
4. Versuche den Default-Branch-Wechsel erneut

---

### 3. Workflows/GitHub Actions prüfen

**Problem:** Workflows referenzieren den Branch als Trigger.

**Prüfen:**
```
https://github.com/HaraldKiessling/DevSystem/actions
```

**Suche in `.github/workflows/*.yml` nach:**
```yaml
on:
  push:
    branches:
      - feature/vps-preparation  # ❌ Das blockiert!
```

**Lösung:**
1. Gehe zu: Code → `.github/workflows/`
2. Öffne alle Workflow-Dateien
3. Suche nach Referenzen auf `feature/vps-preparation`
4. Ändere zu `main` oder entferne die Referenz
5. Committe die Änderungen
6. Versuche den Default-Branch-Wechsel erneut

---

### 4. Repository Settings / Permissions prüfen

**Problem:** Fehlende Repository-Admin-Rechte

**Prüfen:**
```
https://github.com/HaraldKiessling/DevSystem/settings
```

**Verifiziere:**
- Siehst du die "Settings"-Seite?
- Bist du als "Owner" oder "Admin" gelistet?

**Falls NICHT:**
- Du benötigst Owner/Admin-Rechte
- Nur der Repository-Owner kann Default-Branch ändern

---

### 5. Main-Branch ist nicht vollständig synchronisiert

**Problem:** GitHub denkt, `main` ist nicht auf dem aktuellen Stand.

**Prüfen:**
```bash
# Lokal prüfen:
git log --oneline --graph --all --decorate
```

**Lösung:**
```bash
# Stelle sicher, dass main alle Commits hat:
git checkout main
git pull origin main

# Prüfe ob feature/vps-preparation ahead ist:
git log main..origin/feature/vps-preparation

# Wenn Output leer ist: Alles ist gemergt ✅
# Wenn Output Commits zeigt: Diese müssen erst in main ❌
```

Wenn Commits fehlen:
```bash
git checkout main
git merge origin/feature/vps-preparation
git push origin main
```

Dann erneut Default-Branch auf GitHub ändern.

---

### 6. GitHub Cache/UI Problem

**Problem:** GitHub UI hat einen temporären Fehler.

**Lösungen:**

**A. Anderen Browser/Inkognito versuchen:**
- Öffne GitHub in einem Inkognito-Fenster
- Versuche dort den Default-Branch zu ändern

**B. GitHub CLI verwenden:**
```bash
# GitHub CLI installieren (falls nicht vorhanden):
# https://cli.github.com/

# Default-Branch via CLI ändern:
gh repo edit HaraldKiessling/DevSystem --default-branch main
```

**C. GitHub API direkt verwenden:**
```bash
# Mit curl (benötigt Personal Access Token):
curl -X PATCH \
  -H "Authorization: token YOUR_GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/HaraldKiessling/DevSystem \
  -d '{"default_branch":"main"}'
```

---

## Alternative Lösung: Branch umbenennen statt löschen

Falls der Default-Branch absolut nicht geändert werden kann:

### Option: Feature-Branch zu Main umbenennen

```bash
# Via GitHub UI:
# 1. Gehe zu: https://github.com/HaraldKiessling/DevSystem/branches
# 2. NICHT möglich - Default-Branch kann nicht umbenannt werden

# Via Git (komplexer):
# 1. Alten main-Branch sichern
git branch -m main main-backup

# 2. Feature-Branch lokal zu main umbenennen
git branch -m feature/vps-preparation main

# 3. Main-Backup auf GitHub pushen
git push origin main-backup

# 4. Alten main auf GitHub löschen (nicht der Feature-Branch!)
git push origin :main

# 5. Neuen main (ehemals feature/vps-preparation) pushen
git push -u origin main

# ACHTUNG: Dies ist eine invasive Lösung!
```

---

## Empfohlene Vorgehensweise

**PRIORITÄT:**

1. **Zuerst prüfen: Offene Pull Requests** (häufigster Grund!)
   ```
   https://github.com/HaraldKiessling/DevSystem/pulls
   ```

2. **Dann prüfen: Branch Protection Rules**
   ```
   https://github.com/HaraldKiessling/DevSystem/settings/branches
   ```

3. **Workflows prüfen:**
   - Gibt es `.github/workflows/*.yml` Dateien?
   - Referenzieren sie den Branch?

4. **Wenn alles fehlschlägt: GitHub CLI/API verwenden**

5. **Letzte Option: GitHub Support kontaktieren**
   ```
   https://support.github.com/
   ```

---

## Debug-Informationen sammeln

Bitte sammle folgende Informationen:

```bash
# 1. Lokaler Git-Status
git status
git branch -a
git log --oneline --graph --all --decorate -20

# 2. Remote-Status
git ls-remote --heads origin
git ls-remote --symref origin HEAD

# 3. Commits vergleichen
git log --oneline main...origin/feature/vps-preparation
```

**Führe diese Befehle aus und teile die Ausgabe:**

---

## Nächste Schritte basierend auf Diagnose

Nachdem du die Diagnose-Checkliste durchgegangen bist, melde:

1. **Was hast du gefunden?**
   - Offene PRs? Wie viele?
   - Branch Protection Rules? Welche?
   - Workflows mit Branch-Referenzen?

2. **Welche Fehlermeldung zeigt GitHub genau?**
   - Screenshot oder exakter Wortlaut?

3. **Haben die vorgeschlagenen Lösungen funktioniert?**

---

**Erstellt:** 2026-04-10 13:08 UTC  
**Status:** Troubleshooting-Guide für "Could not change default branch"
