# GitHub Default-Branch ändern - Schritt-für-Schritt-Anleitung

**Problem:** Der Branch `feature/vps-preparation` kann nicht gelöscht werden, weil er noch als Default-Branch konfiguriert ist.

**Datum:** 2026-04-10  
**Repository:** https://github.com/HaraldKiessling/DevSystem

---

## Aktueller Status

```bash
# Prüfung zeigt:
git ls-remote --symref origin HEAD
# Output: ref: refs/heads/feature/vps-preparation	HEAD

# Branch existiert noch:
git ls-remote --heads origin
# Output zeigt beide Branches: feature/vps-preparation und main
```

---

## Lösung: Default-Branch ändern

### Schritt 1: Repository Settings öffnen

1. **Öffne das Repository:**
   ```
   https://github.com/HaraldKiessling/DevSystem
   ```

2. **Klicke auf "Settings" (Zahnrad-Icon)**
   - Oben rechts in der Repository-Ansicht
   - **WICHTIG:** Du musst Admin-Rechte haben!

### Schritt 2: Branches Section finden

1. **In der linken Sidebar:**
   - Scrolle runter bis "Code and automation"
   - Klicke auf "Branches"
   - ODER direkt: https://github.com/HaraldKiessling/DevSystem/settings/branches

### Schritt 3: Default-Branch ändern

1. **In der Section "Default branch":**
   ```
   Default branch
   The default branch is considered the "base" branch in your repository,
   against which all pull requests and code commits are automatically made...
   
   [feature/vps-preparation] [⟷ Switch to another branch]
   ```

2. **Klicke auf den "⟷ Switch to another branch" Button**
   - Es öffnet sich ein Dropdown-Menü

3. **Wähle "main" aus der Liste**
   - Klicke auf "main"

4. **Bestätige die Änderung:**
   - Ein Dialog erscheint: "Change default branch to main?"
   - **WICHTIG:** Lese die Warnung!
   - Klicke auf: **"I understand, update the default branch"**
   - Der Button ist ROT und prominent

### Schritt 4: Verifizierung (im Browser)

1. **Nach der Bestätigung solltest du sehen:**
   ```
   Default branch
   [main] [⟷ Switch to another branch]
   ```

2. **Zusätzliche Prüfung:**
   - Gehe zurück zur Repository-Hauptseite
   - Der Branch-Selector oben sollte jetzt "main" zeigen
   - GitHub sollte jetzt "main" als Standard anzeigen

### Schritt 5: Browser-Cache leeren (falls nötig)

Falls die Änderung nicht sofort sichtbar ist:

1. **Hard Refresh:**
   - Windows/Linux: `Ctrl + Shift + R` oder `Ctrl + F5`
   - Mac: `Cmd + Shift + R`

2. **Oder Browser-Cache leeren:**
   - Chrome: `Ctrl + Shift + Delete` → "Cached images and files" → "Clear data"
   - Firefox: `Ctrl + Shift + Delete` → "Cache" → "Clear Now"

3. **Oder Incognito/Private Window:**
   - Öffne GitHub in einem neuen Inkognito-Fenster
   - Prüfe, ob der Default-Branch dort `main` ist

### Schritt 6: Git-Prüfung (lokal)

Nachdem du den Default-Branch auf GitHub geändert hast:

```bash
# Warte 30 Sekunden, dann:
git ls-remote --symref origin HEAD

# Erwarteter Output (wenn erfolgreich):
# ref: refs/heads/main	HEAD
```

---

## Branch löschen (nach erfolgreicher Default-Branch-Änderung)

### Methode 1: Via Git Command Line

```bash
git push origin --delete feature/vps-preparation
```

**Erfolgs-Anzeige:**
```
To github.com:HaraldKiessling/DevSystem.git
 - [deleted]         feature/vps-preparation
```

### Methode 2: Via GitHub Web UI

1. **Öffne:**
   ```
   https://github.com/HaraldKiessling/DevSystem/branches
   ```

2. **Finde "feature/vps-preparation"**
   - In der Liste der Branches

3. **Klicke auf das Papierkorb-Icon (🗑️)**
   - Rechts neben dem Branch-Namen

4. **Bestätige die Löschung**

---

## Troubleshooting

### Problem 1: "Refusing to delete the current branch"

**Ursache:** Default-Branch ist noch nicht geändert

**Lösung:**
1. Prüfe auf GitHub: Settings → Branches
2. Stelle sicher, dass "main" als Default angezeigt wird
3. Warte 1-2 Minuten nach der Änderung
4. Leere Browser-Cache
5. Versuche erneut

### Problem 2: "You don't have permission to change settings"

**Ursache:** Keine Admin-Rechte

**Lösung:**
- Du musst Repository-Owner oder Admin sein
- Prüfe deine Rechte: Settings → Manage access

### Problem 3: Default-Branch-Änderung wird nicht übernommen

**Mögliche Ursachen:**
1. Browser-Cache nicht geleert
2. GitHub UI hat nicht richtig reagiert
3. Änderung wurde nicht gespeichert

**Lösung:**
1. Gehe zu Settings → Branches
2. Prüfe visuell: Steht da wirklich "[main]"?
3. Wenn nicht: Wiederhole Schritt 3 aus der Anleitung
4. Wenn ja: Leere Browser-Cache und warte 1-2 Minuten

### Problem 4: Git zeigt noch alten Default-Branch

```bash
git ls-remote --symref origin HEAD
# Output: ref: refs/heads/feature/vps-preparation	HEAD  ❌
```

**Lösung:**
- GitHub-Änderung ist noch nicht wirksam
- Warte 1-2 Minuten
- Führe aus: `git fetch --all --prune`
- Prüfe erneut

---

## Finaler Verifikations-Checklist

Nach erfolgreicher Durchführung:

- [ ] GitHub Settings → Branches zeigt "[main]" als Default
- [ ] GitHub Repository-Hauptseite zeigt "main" Branch
- [ ] `git ls-remote --symref origin HEAD` zeigt "ref: refs/heads/main"
- [ ] Branch kann gelöscht werden (via Git oder Web UI)
- [ ] `git branch -a` zeigt nur noch main (nach `git fetch --prune`)

**Erwartetes Endergebnis:**
```bash
$ git branch -a
* main
  remotes/origin/HEAD -> origin/main
  remotes/origin/main
```

---

## Nächste Schritte

Nachdem der Branch erfolgreich gelöscht wurde:

1. ✅ Remote-Referenzen bereinigen:
   ```bash
   git fetch --prune
   git remote prune origin
   ```

2. ✅ Verifizieren:
   ```bash
   git branch -a
   git remote show origin
   ```

3. ✅ Dokumentation finalisieren und committen

---

**Erstellt:** 2026-04-10 13:07 UTC  
**Für Repository:** HaraldKiessling/DevSystem  
**Status:** Troubleshooting-Guide für Default-Branch-Wechsel
