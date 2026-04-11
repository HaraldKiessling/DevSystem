# Git-Workflow Checkpoints

## Obligatorische Validierung bei Branch-basierten Workflows

**WICHTIG:** Bei jedem Branch-Workflow (Feature, Bugfix, Docs, etc.) MÜSSEN folgende Schritte vollständig durchlaufen werden:

### Phase 1: Branch-Erstellung ✓
- [ ] Feature-Branch erstellt (`git checkout -b feature/name`)
- [ ] Wechsel zum Branch bestätigt (`git branch --show-current`)

### Phase 2: Entwicklung & Commits ✓
- [ ] Änderungen durchgeführt
- [ ] Alle Änderungen gestaged (`git add`)
- [ ] Commits mit aussagekräftigen Messages (`git commit`)
- [ ] Mindestens 1 Commit vorhanden

### Phase 3: Merge zu main ✓
- [ ] Wechsel zu main (`git checkout main`)
- [ ] Merge durchgeführt (`git merge feature/name`)
- [ ] Merge-Konflikte gelöst (falls vorhanden)
- [ ] No-FF-Merge bei wichtigen Features

### Phase 4: Tagging (optional aber empfohlen) ✓
- [ ] Tag erstellt bei Meilensteinen (`git tag -a v1.0.0`)
- [ ] Annotated Tags mit Beschreibung verwendet

### Phase 5: **PUSH ZU REMOTE (KRITISCH!)** ⚠️
- [ ] **Main-Branch gepusht** (`git push origin main`)
- [ ] **Tags gepusht** (`git push origin --tags`)
- [ ] **Push-Erfolg verifiziert** (git log origin/main, github.com Überprüfung)

### Phase 6: Cleanup ✓
- [ ] Feature-Branch lokal gelöscht (`git branch -d feature/name`)
- [ ] Feature-Branch remote gelöscht falls vorhanden (`git push origin --delete feature/name`)

## ⚠️ KRITISCHE CHECKPOINTS

**Diese Schritte dürfen NIEMALS übersprungen werden:**

1. **Push-Verifikation**: Nach JEDEM Merge zu main MUSS ein Push zu GitHub erfolgen
2. **Tag-Push**: Erstellte Tags MÜSSEN zu Remote gepusht werden
3. **Status-Check**: Vor Abschluss IMMER `git status` und `git log origin/main` prüfen

## 🔴 Häufige Fehler vermeiden

**Fehler 1: "Nur lokal committed, nicht gepusht"**
- Symptom: Lokaler main ist ahead of origin/main
- Lösung: `git push origin main --tags`
- Prevention: IMMER nach Merge automatisch pushen

**Fehler 2: "Tags vergessen"**
- Symptom: Tags existieren lokal aber nicht auf GitHub
- Lösung: `git push origin --tags`
- Prevention: Tags IMMER im selben Zug mit main pushen

**Fehler 3: "Unvollständiger Workflow"**
- Symptom: Branch merged aber nicht gepusht, Branch nicht gelöscht
- Lösung: Workflow-Checkliste bis Ende durchgehen
- Prevention: Verwende diese Checkpoints als verbindliche Checkliste

## 📋 Workflow-Template (Copy-Paste)

```bash
# 1. Branch erstellen
git checkout -b feature/my-feature

# 2. Arbeiten und committen
git add .
git commit -m "feat: implement my feature"

# 3. Zu main mergen
git checkout main
git merge feature/my-feature --no-ff

# 4. Tag erstellen (optional)
git tag -a v1.0.0 -m "Release v1.0.0: My Feature"

# 5. ⚠️ KRITISCH: Push zu Remote
git push origin main
git push origin --tags

# 6. Branch cleanup
git branch -d feature/my-feature

# 7. Verifikation
git log origin/main -3
echo "Workflow abgeschlossen!"
```

## 🎯 Automatisierung

**Empfehlung:** Verwende Git-Hooks oder Aliases für automatisches Pushen:

```bash
# Git Alias für "Merge + Push + Tag Push"
git config --global alias.merge-push '!f() { git merge "$1" && git push origin main && git push origin --tags; }; f'

# Verwendung: git merge-push feature/my-feature
```

---

**Version:** 1.0  
**Erstellt:** 2026-04-11  
**Status:** Aktiv und verbindlich
