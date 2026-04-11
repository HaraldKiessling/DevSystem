# GitHub-Automation: Lokaler Abschlussplan

**Datum:** 2026-04-11 04:49 UTC  
**Ziel:** Lokale Git/Branch-Situation abschließen und GitHub-Automation vorbereiten  
**Fokus:** `feature/qs-system-optimization` → PR + GitHub CLI Setup

---

## 📊 Aktuelle Lokale Situation (IST-Zustand)

### ✅ Funktionierende Komponenten

#### 1. Git-Konfiguration
```bash
✅ Remote: git@github.com:HaraldKiessling/DevSystem.git (SSH)
✅ Default Branch: main
✅ Current Branch: feature/qs-system-optimization (10 Commits ready)
✅ Working Directory: Clean, synchronized with origin
```

#### 2. SSH-Keys
```bash
✅ Private Key: /root/.ssh/id_ed25519
✅ Public Key: /root/.ssh/id_ed25519.pub
✅ Typ: Ed25519 (modern, sicher)
✅ Status: Funktionsfähig (bereits auf GitHub registriert)
```

#### 3. Branch-Status
```bash
✅ feature/qs-system-optimization
   - 10 Commits (dee7c69..2df35b8)
   - Synchronized mit origin/feature/qs-system-optimization
   - Ready for Pull Request
   - Dokumentation: PR-CREATION-INSTRUCTIONS.md existiert

⚠️ feature/vps-preparation
   - Kann nicht über Git gelöscht werden
   - GitHub Default-Branch Problem
   - 87,5% Cleanup erreicht (dokumentiert)
   - Impact: MINIMAL (nur kosmetisch)
```

#### 4. Bestehende Workflows
```bash
✅ .github/workflows/deploy-qs-vps.yml
   - Automatisches Deployment zu QS-VPS
   - Funktioniert mit GitHub Secrets
   - GITHUB_TOKEN automatisch verfügbar in Actions
```

### ❌ Fehlende Komponenten

#### 1. GitHub CLI Authentifizierung
```bash
❌ Status: GitHub CLI v2.89.0 installiert aber nicht authentifiziert
❌ Impact: Keine CLI-basierten PR-Operationen möglich
❌ Workaround: Manuelle PR-Erstellung über GitHub Web UI
```

#### 2. Git Credential Helper
```bash
❌ ~/.gitconfig: Nicht vorhanden (keine credential helper konfiguriert)
❌ Impact: Keine Token-basierte HTTP(S)-Authentifizierung
✅ Workaround: SSH-Keys funktionieren für git operations
```

#### 3. GITHUB_TOKEN Environment Variable
```bash
❌ Keine lokale GITHUB_TOKEN Environment Variable
✅ Workaround: Token wird in GitHub Actions automatisch bereitgestellt
```

---

## 🎯 SOLL-Zustand (Zielarchitektur)

### Kurzfristig (Heute - Manuelle Lösung)
1. ✅ Pull Request für `feature/qs-system-optimization` über GitHub Web UI erstellen
2. ✅ `feature/vps-preparation` als "Known Issue" akzeptieren (dokumentiert)
3. ✅ GitHub CLI Authentifizierungs-Anleitung erstellen (für zukünftige Nutzung)

### Mittelfristig (Diese Woche - Semi-Automatisch)
1. GitHub CLI mit Personal Access Token authentifizieren
2. Helper-Scripts für PR-Erstellung entwickeln
3. Git-Hooks für lokale Automation einrichten

### Langfristig (Nächster Monat - Vollautomatisch)
1. GitHub Actions für automatische PR-Erstellung aus Feature-Branches
2. Branch-Sync-Automation
3. Automatische PR-Updates bei Push

---

## 📋 Schritt-für-Schritt Abschlussplan

### PHASE 1: Sofortige Aktionen (Heute)

#### Schritt 1: Pull Request für `feature/qs-system-optimization` erstellen ✅

**Status:** Vorbereitet, manuelle Ausführung erforderlich

**Dokumentation vorhanden:**
- [`PR-CREATION-INSTRUCTIONS.md`](../PR-CREATION-INSTRUCTIONS.md) - Vollständige Anleitung
- [`PULL_REQUEST_TEMPLATE.md`](../PULL_REQUEST_TEMPLATE.md) - 443 Zeilen PR-Body

**Aktion:**
```bash
# Direktlink (im Browser öffnen):
https://github.com/HaraldKiessling/DevSystem/compare/main...feature/qs-system-optimization?expand=1

# Status nach Erstellung dokumentieren in:
# - PR-CREATION-INSTRUCTIONS.md (Zeile 296-302)
# - todo.md (Post-MVP Section)
```

**Erfolgskriterien:**
- ✅ PR ist auf GitHub sichtbar
- ✅ Alle 10 Commits enthalten
- ✅ Template korrekt übernommen
- ✅ Labels gesetzt (enhancement, documentation, optimization)
- ✅ Keine Merge-Konflikte

**Zeitaufwand:** ~5 Minuten

---

#### Schritt 2: `feature/vps-preparation` Problem dokumentiert belassen ✅

**Status:** Bereits dokumentiert, keine weitere Aktion erforderlich

**Dokumentation:**
- [`GIT-BRANCH-CLEANUP-FINAL.md`](../GIT-BRANCH-CLEANUP-FINAL.md) - Vollständige Analyse
- [`GITHUB-DEFAULT-BRANCH-TROUBLESHOOTING.md`](../GITHUB-DEFAULT-BRANCH-TROUBLESHOOTING.md) - Troubleshooting
- [`BRANCH-DELETION-VIA-GITHUB-UI.md`](../BRANCH-DELETION-VIA-GITHUB-UI.md) - Alternative Lösungswege

**Empfehlung:** Als "Known Issue" akzeptieren
- ✅ 87,5% Cleanup erreicht
- ✅ Kein funktionaler Impact
- ✅ main Branch voll funktionsfähig
- ✅ Branch ist inaktiv und identisch mit main

**Optional - wenn 100% Cleanup kritisch:**
```bash
# Via GitHub CLI (nach Authentifizierung):
gh api --method PATCH /repos/HaraldKiessling/DevSystem -f default_branch='main'
gh api --method DELETE /repos/HaraldKiessling/DevSystem/git/refs/heads/feature/vps-preparation

# Via curl + Personal Access Token:
curl -X PATCH \
  -H "Authorization: token GITHUB_TOKEN" \
  https://api.github.com/repos/HaraldKiessling/DevSystem \
  -d '{"default_branch":"main"}'
```

**Zeitaufwand:** 0 Minuten (bereits dokumentiert) oder 3 Minuten (wenn API-Lösung gewählt)

---

### PHASE 2: GitHub CLI Authentifizierung einrichten

#### Schritt 3: Personal Access Token (PAT) erstellen

**Methode:** GitHub Web UI (einmalig)

**Schritte:**
```bash
# 1. Im Browser öffnen:
https://github.com/settings/tokens/new

# 2. Token-Konfiguration:
Name: DevSystem GitHub CLI Token
Expiration: 90 days (oder länger)
Scopes:
  ✅ repo (Full control of repositories)
  ✅ workflow (Update GitHub Action workflows)
  ✅ admin:org (optional, falls Organisation)

# 3. Token generieren und SICHER SPEICHERN
# Format: ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**⚠️ WICHTIG:** Token nur EINMAL angezeigt - sofort speichern!

**Zeitaufwand:** ~2 Minuten

---

#### Schritt 4: GitHub CLI authentifizieren

**Methode A: Mit Token (Empfohlen - headless-tauglich)**

```bash
# Token in Variable setzen (temporär)
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# GitHub CLI authentifizieren
echo "$GITHUB_TOKEN" | gh auth login --with-token

# Authentifizierung verifizieren
gh auth status

# Expected Output:
# ✓ Logged in to github.com as HaraldKiessling
# ✓ Token: ghp_************************************
```

**Methode B: Interaktiv (via Browser)**

```bash
# Interaktiven Login starten
gh auth login

# Auswahl:
# 1. GitHub.com
# 2. HTTPS
# 3. Login via Browser (empfohlen)
# 4. Folge Anweisungen im Browser
```

**Sicherheit: Token-Speicherung**

GitHub CLI speichert Token automatisch in:
```bash
~/.config/gh/hosts.yml

# Format:
github.com:
    user: HaraldKiessling
    oauth_token: ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    git_protocol: https
```

**Berechtigungen setzen:**
```bash
chmod 600 ~/.config/gh/hosts.yml
```

**Zeitaufwand:** ~2 Minuten

---

#### Schritt 5: GitHub CLI testen

```bash
# 1. Authentifizierungsstatus prüfen
gh auth status

# 2. Repository-Info abrufen
gh repo view HaraldKiessling/DevSystem

# 3. Branches listen
gh api repos/HaraldKiessling/DevSystem/branches --jq '.[].name'

# 4. Pull Requests listen
gh pr list --repo HaraldKiessling/DevSystem

# 5. Test-Issue erstellen (optional)
gh issue create \
  --repo HaraldKiessling/DevSystem \
  --title "Test: GitHub CLI Authentifizierung funktioniert" \
  --body "Automatisch erstellt via GitHub CLI nach Setup"

# 6. Test-Issue sofort schließen
gh issue close 1 --repo HaraldKiessling/DevSystem
```

**Erfolgskriterien:**
- ✅ `gh auth status` zeigt "Logged in"
- ✅ `gh repo view` zeigt Repository-Details
- ✅ Keine "authentication required" Fehler

**Zeitaufwand:** ~2 Minuten

---

### PHASE 3: Helper-Scripts entwickeln

#### Schritt 6: PR-Creation-Script erstellen

**Datei:** [`scripts/create-pr.sh`](../scripts/create-pr.sh)

```bash
#!/bin/bash
#
# create-pr.sh - Automatische Pull Request-Erstellung
#
# Usage:
#   ./scripts/create-pr.sh [branch-name] [title] [body-file]
#
# Beispiel:
#   ./scripts/create-pr.sh feature/my-feature "feat: My Feature" PR_TEMPLATE.md

set -euo pipefail

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper-Funktionen
log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Konfiguration
REPO="HaraldKiessling/DevSystem"
BASE_BRANCH="main"

# Parameter
BRANCH="${1:-$(git branch --show-current)}"
TITLE="${2:-}"
BODY_FILE="${3:-PULL_REQUEST_TEMPLATE.md}"

# Validierung
if [ "$BRANCH" = "$BASE_BRANCH" ]; then
    log_error "Kann keinen PR vom main Branch erstellen!"
    exit 1
fi

# GitHub CLI Authentifizierung prüfen
if ! gh auth status >/dev/null 2>&1; then
    log_error "GitHub CLI nicht authentifiziert!"
    log_info "Führe aus: gh auth login"
    exit 1
fi

# Branch-Status prüfen
log_info "Prüfe Branch-Status: $BRANCH"

# Unpushed commits?
UNPUSHED=$(git log origin/$BRANCH..HEAD --oneline 2>/dev/null | wc -l || echo "0")
if [ "$UNPUSHED" -gt 0 ]; then
    log_warn "$UNPUSHED unpushed commits gefunden. Pushe zuerst!"
    log_info "git push origin $BRANCH"
    exit 1
fi

# Existiert PR bereits?
EXISTING_PR=$(gh pr list --repo "$REPO" --head "$BRANCH" --json number --jq '.[0].number' 2>/dev/null || echo "")

if [ -n "$EXISTING_PR" ]; then
    log_warn "Pull Request #$EXISTING_PR existiert bereits für Branch $BRANCH"
    PR_URL=$(gh pr view "$EXISTING_PR" --repo "$REPO" --json url --jq '.url')
    log_info "URL: $PR_URL"
    
    # PR im Browser öffnen?
    read -p "Im Browser öffnen? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        gh pr view "$EXISTING_PR" --repo "$REPO" --web
    fi
    exit 0
fi

# Title automatisch generieren falls nicht angegeben
if [ -z "$TITLE" ]; then
    # Ersten Commit-Message als Title verwenden
    TITLE=$(git log --format=%s origin/$BASE_BRANCH..HEAD | tail -n 1)
    log_info "Auto-detected title: $TITLE"
fi

# PR erstellen
log_info "Erstelle Pull Request..."
log_info "  Branch: $BRANCH → $BASE_BRANCH"
log_info "  Title: $TITLE"
log_info "  Body: $BODY_FILE"

if [ -f "$BODY_FILE" ]; then
    # Mit Body-File
    gh pr create \
        --repo "$REPO" \
        --base "$BASE_BRANCH" \
        --head "$BRANCH" \
        --title "$TITLE" \
        --body-file "$BODY_FILE" \
        --label enhancement \
        --label documentation
else
    log_warn "Body-File nicht gefunden: $BODY_FILE"
    # Ohne Body-File (nur Commit-Messages)
    gh pr create \
        --repo "$REPO" \
        --base "$BASE_BRANCH" \
        --head "$BRANCH" \
        --title "$TITLE" \
        --label enhancement
fi

# PR-Details abrufen
PR_NUMBER=$(gh pr list --repo "$REPO" --head "$BRANCH" --json number --jq '.[0].number')
PR_URL=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json url --jq '.url')

log_info "✅ Pull Request erstellt!"
log_info "   Number: #$PR_NUMBER"
log_info "   URL: $PR_URL"

# PR im Browser öffnen?
read -p "Im Browser öffnen? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    gh pr view "$PR_NUMBER" --repo "$REPO" --web
fi
```

**Installation:**
```bash
# Script erstellen
cat > scripts/create-pr.sh << 'EOF'
[... Script-Inhalt von oben ...]
EOF

# Ausführbar machen
chmod +x scripts/create-pr.sh

# Testen
./scripts/create-pr.sh --help
```

**Zeitaufwand:** ~3 Minuten

---

#### Schritt 7: Branch-Sync-Script erstellen

**Datei:** [`scripts/sync-branch.sh`](../scripts/sync-branch.sh)

```bash
#!/bin/bash
#
# sync-branch.sh - Branch mit main synchronisieren
#
# Usage:
#   ./scripts/sync-branch.sh [branch-name]

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

BRANCH="${1:-$(git branch --show-current)}"
BASE="main"

log_info "Synchronisiere Branch: $BRANCH mit $BASE"

# 1. Fetch latest
log_info "Fetching latest changes..."
git fetch origin

# 2. Prüfe auf Konflikte
log_info "Prüfe auf potenzielle Konflikte..."
CONFLICTS=$(git merge-tree $(git merge-base $BRANCH origin/$BASE) $BRANCH origin/$BASE | grep -c "^changed in both" || echo "0")

if [ "$CONFLICTS" -gt 0 ]; then
    log_warn "$CONFLICTS potenzielle Konflikte gefunden!"
    log_warn "Führe manuellen Merge durch:"
    log_warn "  git checkout $BRANCH"
    log_warn "  git merge origin/$BASE"
    exit 1
fi

# 3. Merge
log_info "Merge $BASE → $BRANCH"
git checkout "$BRANCH"
git merge origin/$BASE --no-edit

# 4. Push
log_info "Pushing to origin/$BRANCH"
git push origin "$BRANCH"

log_info "✅ Branch $BRANCH erfolgreich mit $BASE synchronisiert"
```

**Zeitaufwand:** ~2 Minuten

---

### PHASE 4: Git-Hooks einrichten

#### Schritt 8: Pre-Push-Hook für Tests

**Datei:** [`.git/hooks/pre-push`](../.git/hooks/pre-push)

```bash
#!/bin/bash
#
# pre-push - Validierung vor Push
#

set -e

echo "🔍 Pre-Push Validierung läuft..."

# 1. Prüfe auf TODO/FIXME in staged files
if git diff --cached --name-only | xargs grep -i "TODO\|FIXME" 2>/dev/null; then
    echo "⚠️  TODO/FIXME gefunden - Push trotzdem fortsetzen? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 2. Prüfe Markdown-Syntax
if command -v markdownlint >/dev/null 2>&1; then
    echo "📝 Markdown-Syntax prüfen..."
    git diff --cached --name-only --diff-filter=ACM | grep '\.md$' | xargs markdownlint || true
fi

# 3. Prüfe Shell-Scripts
if command -v shellcheck >/dev/null 2>&1; then
    echo "🐚 Shell-Scripts prüfen..."
    git diff --cached --name-only --diff-filter=ACM | grep '\.sh$' | xargs shellcheck -x || true
fi

# 4. Idempotenz-Tests für QS-Scripts (optional)
if [ -f "scripts/qs/test-idempotency-lib.sh" ]; then
    echo "🔄 Idempotenz-Tests laufen..."
    bash scripts/qs/test-idempotency-lib.sh || {
        echo "❌ Idempotenz-Tests fehlgeschlagen!"
        exit 1
    }
fi

echo "✅ Pre-Push Validierung erfolgreich"
```

**Installation:**
```bash
# Hook erstellen
cat > .git/hooks/pre-push << 'EOF'
[... Hook-Inhalt ...]
EOF

# Ausführbar machen
chmod +x .git/hooks/pre-push

# Testen
git push --dry-run
```

**Zeitaufwand:** ~2 Minuten

---

#### Schritt 9: Post-Commit-Hook für Branch-Info

**Datei:** [`.git/hooks/post-commit`](../.git/hooks/post-commit)

```bash
#!/bin/bash
#
# post-commit - Info nach Commit anzeigen
#

BRANCH=$(git branch --show-current)
COMMITS_AHEAD=$(git rev-list --count origin/$BRANCH..$BRANCH 2>/dev/null || echo "0")

if [ "$COMMITS_AHEAD" -gt 0 ]; then
    echo ""
    echo "📊 Branch-Status: $BRANCH"
    echo "   Unpushed Commits: $COMMITS_AHEAD"
    echo "   Tipp: git push origin $BRANCH"
    echo ""
fi
```

**Installation:**
```bash
cat > .git/hooks/post-commit << 'EOF'
[... Hook-Inhalt ...]
EOF

chmod +x .git/hooks/post-commit
```

**Zeitaufwand:** ~1 Minute

---

### PHASE 5: GitHub Actions erweitern (optional)

#### Schritt 10: Auto-PR-Workflow für Feature-Branches

**Datei:** [`.github/workflows/auto-pr-feature-branches.yml`](../.github/workflows/auto-pr-feature-branches.yml)

```yaml
name: Auto-PR für Feature-Branches

on:
  push:
    branches:
      - 'feature/**'
      - 'fix/**'
      - 'refactor/**'

jobs:
  create-pr:
    runs-on: ubuntu-latest
    
    # Nur ausführen wenn noch kein PR existiert
    if: github.event_name == 'push'
    
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Prüfe ob PR bereits existiert
        id: check-pr
        run: |
          PR_COUNT=$(gh pr list --head ${{ github.ref_name }} --json number --jq 'length')
          echo "pr_count=$PR_COUNT" >> $GITHUB_OUTPUT
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Erstelle Pull Request
        if: steps.check-pr.outputs.pr_count == '0'
        run: |
          # Auto-generate title from branch name
          BRANCH="${{ github.ref_name }}"
          TITLE=$(echo "$BRANCH" | sed 's/feature\//feat: /; s/fix\//fix: /; s/refactor\//refactor: /' | sed 's/-/ /g')
          
          # Create PR
          gh pr create \
            --base main \
            --head "$BRANCH" \
            --title "$TITLE" \
            --body "Automatisch erstellter PR für Branch: $BRANCH" \
            --label "auto-created"
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      
      - name: PR-Info ausgeben
        if: steps.check-pr.outputs.pr_count == '0'
        run: |
          PR_URL=$(gh pr view --json url --jq '.url')
          echo "### 🎉 Pull Request erstellt!" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Branch:** ${{ github.ref_name }}" >> $GITHUB_STEP_SUMMARY
          echo "**URL:** $PR_URL" >> $GITHUB_STEP_SUMMARY
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Aktivierung:** Datei committen und pushen

**Zeitaufwand:** ~3 Minuten

---

## 📊 Zeitplan & Aufwandsschätzung

| Phase | Schritte | Zeitaufwand | Priorität |
|-------|----------|-------------|-----------|
| **Phase 1** | Sofortige Aktionen | ~5-8 Min | 🔴 HOCH |
| - PR erstellen | Schritt 1 | ~5 Min | 🔴 HOCH |
| - Branch-Problem akzeptieren | Schritt 2 | ~0 Min | 🟡 MITTEL |
| **Phase 2** | GitHub CLI Setup | ~6 Min | 🔴 HOCH |
| - PAT erstellen | Schritt 3 | ~2 Min | 🔴 HOCH |
| - CLI authentifizieren | Schritt 4 | ~2 Min | 🔴 HOCH |
| - CLI testen | Schritt 5 | ~2 Min | 🔴 HOCH |
| **Phase 3** | Helper-Scripts | ~5 Min | 🟡 MITTEL |
| - PR-Script | Schritt 6 | ~3 Min | 🟡 MITTEL |
| - Sync-Script | Schritt 7 | ~2 Min | 🟡 MITTEL |
| **Phase 4** | Git-Hooks | ~3 Min | 🟢 NIEDRIG |
| - Pre-Push Hook | Schritt 8 | ~2 Min | 🟢 NIEDRIG |
| - Post-Commit Hook | Schritt 9 | ~1 Min | 🟢 NIEDRIG |
| **Phase 5** | GitHub Actions | ~3 Min | 🟢 NIEDRIG |
| - Auto-PR Workflow | Schritt 10 | ~3 Min | 🟢 NIEDRIG |
| **GESAMT** | | **~22-25 Min** | |

**Kritischer Pfad (Minimum):**
- Phase 1 + Phase 2 = ~11-14 Minuten
- Ermöglicht: PR-Erstellung + Zukünftige CLI-Nutzung

---

## ✅ Erfolgskriterien

### Phase 1: Sofort
- ✅ Pull Request #X für `feature/qs-system-optimization` existiert auf GitHub
- ✅ PR hat alle 10 Commits
- ✅ PR-Template korrekt übernommen
- ✅ Branch `feature/vps-preparation` als "Known Issue" dokumentiert

### Phase 2: GitHub CLI
- ✅ `gh auth status` zeigt "Logged in to github.com"
- ✅ Personal Access Token sicher in `~/.config/gh/hosts.yml` gespeichert
- ✅ Test-Kommandos funktionieren ohne Authentifizierungsfehler

### Phase 3-5: Automation
- ✅ `./scripts/create-pr.sh` funktioniert für neue Features
- ✅ Git-Hooks validieren Code vor Push
- ✅ GitHub Actions erstellt PRs automatisch (optional)

---

## 🎯 Nächste Schritte nach Abschluss

### Unmittelbar
1. PR für `feature/qs-system-optimization` reviewen lassen
2. Nach Approval: Merge in `main`
3. Branch `feature/qs-system-optimization` lokal und remote löschen

### Diese Woche
1. Weitere Features in neuen Branches entwickeln
2. PR-Creation mit `./scripts/create-pr.sh` testen
3. Git-Hooks in Praxis testen

### Nächster Monat
1. GitHub Actions Workflows erweitern
2. Automatische PR-Updates implementieren
3. Branch-Protection-Rules einrichten

---

## 📚 Referenz-Dokumentation

### Bestehende Dokumente
1. [`PR-CREATION-INSTRUCTIONS.md`](../PR-CREATION-INSTRUCTIONS.md) - PR-Anleitung (manuell)
2. [`PULL_REQUEST_TEMPLATE.md`](../PULL_REQUEST_TEMPLATE.md) - PR-Template
3. [`GIT-BRANCH-CLEANUP-FINAL.md`](../GIT-BRANCH-CLEANUP-FINAL.md) - Branch-Cleanup-Analyse
4. [`git-workflow.md`](../git-workflow.md) - Git-Workflow-Dokumentation
5. [`GIT-SYNC-REPORT-QS-VPS.md`](../GIT-SYNC-REPORT-QS-VPS.md) - Sync-Status

### Neue Dokumente (werden erstellt)
1. `scripts/create-pr.sh` - Automatische PR-Erstellung
2. `scripts/sync-branch.sh` - Branch-Synchronisation
3. `.git/hooks/pre-push` - Pre-Push Validierung
4. `.git/hooks/post-commit` - Post-Commit Info
5. `.github/workflows/auto-pr-feature-branches.yml` - Auto-PR Workflow

---

## 🔐 Sicherheitshinweise

### Personal Access Token
- ✅ Token nur einmal angezeigt - sofort sicher speichern
- ✅ Token in `~/.config/gh/hosts.yml` wird mit chmod 600 geschützt
- ✅ Token NIEMALS in Git committen
- ✅ Token alle 90 Tage rotieren (GitHub-Einstellung)
- ✅ Bei Kompromittierung: Sofort revoken auf https://github.com/settings/tokens

### SSH-Keys
- ✅ Private Key `/root/.ssh/id_ed25519` ist mit chmod 600 geschützt
- ✅ Key-Passphrase empfohlen (optional): `ssh-keygen -p -f ~/.ssh/id_ed25519`
- ✅ ssh-agent für bequeme Nutzung: `eval $(ssh-agent); ssh-add ~/.ssh/id_ed25519`

### Environment Variables
- ❌ GITHUB_TOKEN NICHT in Shell-History: `export HISTCONTROL=ignorespace`
- ✅ Token in Variablen: `export GITHUB_TOKEN="ghp_..."`
- ✅ Nach Session löschen: `unset GITHUB_TOKEN`

---

## 🐛 Troubleshooting

### Problem: "GitHub CLI not authenticated"
```bash
# Lösung:
gh auth login
# Oder:
echo "GITHUB_TOKEN" | gh auth login --with-token
```

### Problem: "refusing to delete the current branch"
```bash
# Lösung: Via API (nach CLI-Authentifizierung)
gh api --method PATCH /repos/HaraldKiessling/DevSystem -f default_branch='main'
```

### Problem: "Permission denied (publickey)"
```bash
# SSH-Key-Berechtigung prüfen:
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub

# SSH-Agent starten:
eval $(ssh-agent)
ssh-add ~/.ssh/id_ed25519

# Testen:
ssh -T git@github.com
```

### Problem: "PR already exists"
```bash
# Existierenden PR finden:
gh pr list --head feature/branch-name

# PR im Browser öffnen:
gh pr view NUMBER --web
```

---

## 📝 Zusammenfassung

### Was wird erreicht?
1. ✅ **Sofort:** Pull Request für `feature/qs-system-optimization` erstellt
2. ✅ **Heute:** GitHub CLI funktionsfähig für CLI-basierte Operationen
3. ✅ **Diese Woche:** Helper-Scripts für schnellere PR-Workflows
4. ✅ **Optional:** Git-Hooks für lokale Validierung
5. ✅ **Optional:** GitHub Actions für vollautomatische PR-Erstellung

### Hauptvorteile
- 🚀 **Schnellere PR-Erstellung:** Von 5 Minuten (manuell) auf 30 Sekunden (CLI)
- 🔄 **Automation:** Weniger manuelle Schritte, mehr Reproducibility
- ✅ **Validierung:** Git-Hooks fangen Fehler vor dem Push
- 📊 **Transparenz:** Automatische Dokumentation via GitHub Actions
- 🔐 **Sicherheit:** Token-basierte Authentifizierung mit Rotation

### Zeitersparnis
- **Manuell (aktuell):** ~5 Min pro PR
- **Mit CLI:** ~30 Sek pro PR
- **Mit Automation:** ~0 Sek (automatisch)
- **Bei 20 PRs/Monat:** ~100 Min gespart → **~1,5 Stunden**

---

**Erstellt:** 2026-04-11 04:49 UTC  
**Autor:** Roo (Architect Mode)  
**Status:** Ready for Implementierung  
**Nächster Schritt:** Phase 1 - Schritt 1 - PR erstellen
