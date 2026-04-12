# GitHub Actions Workflows für DevSystem

## 📋 Übersicht

Dieses Repository enthält GitHub Actions Workflows für automatisierte Deployments zum QS-VPS.

---

## 🚀 Deploy QS-VPS Workflow

**Datei:** `deploy-qs-vps.yml`

### Zweck
Automatisiertes Deployment aller QS-Komponenten zum Quality Server via SSH über Tailscale VPN.

### Trigger

#### 1. Manueller Start (workflow_dispatch)
Kann jederzeit manuell im GitHub UI gestartet werden mit Optionen:
- **Deployment Mode:**
  - `normal`: Standard-Deployment
  - `force`: Force-Redeploy (ignoriert bestehende Marker)
  - `dry-run`: Simulation ohne echte Änderungen
  - `rollback`: Rollback auf vorherigen Zustand
- **Component:** Optional spezifische Komponente (z.B. `install-caddy`)

#### 2. Automatisch bei Push
Wird automatisch getriggert bei:
- Push zu `main` Branch
- Änderungen in `scripts/qs/**`
- Änderungen am Workflow selbst

### Ablauf

```
1. Checkout Repository
   ↓
2. Setup Tailscale VPN
   ↓
3. Setup SSH Key
   ↓
4. Test SSH Connection
   ↓
5. Sync Repository → QS-VPS (rsync)
   ↓
6. Run Master-Orchestrator (setup-qs-master.sh)
   ↓
7. Fetch Deployment Report
   ↓
8. Validate Services (caddy, qdrant)
   ↓
9. Run Health Checks (APIs)
```

### Outputs

- **GitHub Step Summary:** Deployment Report, Service Status, Health Checks
- **Deployment Reports:** Verfügbar auf VPS unter `/var/log/qs-deployment/`

---

## 📚 Documentation Validation Workflow

**Datei:** `docs-validation.yml`

### Zweck
Automatische Validierung der Dokumentations-Synchronisation.

### Trigger

#### 1. Pull Requests nach main
Bei Änderungen in:
- `docs/**`
- `scripts/**`
- `CHANGELOG.md`
- `.github/workflows/**`

#### 2. Push nach main
Bei Änderungen in:
- `docs/**`
- `scripts/**`
- `CHANGELOG.md`

#### 3. Schedule
Täglich um 08:00 UTC

#### 4. Manueller Trigger (workflow_dispatch)
Kann jederzeit manuell gestartet werden

### Checks

#### 1. **todo.md Timestamp Check** 📋
Validiert die Aktualität von [`docs/project/todo.md`](../../docs/project/todo.md):
- ✅ **OK:** < 24 Stunden alt
- ⚠️ **WARNING:** > 24 Stunden, aber < 7 Tage
- ❌ **ERROR:** > 7 Tage (Workflow schlägt fehl)

#### 2. **Branch Reference Check** 🔀
Sucht nach Feature-Branch-Namen in der Dokumentation:
- Warnt wenn Branch-Namen in `docs/` gefunden werden
- Verhindert veraltete Branch-Referenzen

#### 3. **CHANGELOG Update Check** 📝
Prüft bei Pull Requests, ob bei Code-Änderungen auch das [`CHANGELOG.md`](../../CHANGELOG.md) aktualisiert wurde:
- Code-Änderungen in `scripts/` oder `.github/`
- Warnung wenn CHANGELOG nicht aktualisiert

#### 4. **Broken Links Check** 🔗
Findet defekte relative Links in Markdown-Dateien:
- Prüft alle `*.md` Dateien in `docs/`
- Ignoriert externe Links (http/https)
- Erkennt fehlende Zieldateien

#### 5. **Health Report** 📊
Generiert Statistiken über Dokumentations-Status:
- Gesamt Dokumente
- Aktive vs. archivierte Dokumente
- todo.md Status

### Status-Levels

- ✅ **OK:** Alle Checks bestanden
- ⚠️ **WARNING:** Nicht-kritische Probleme (Workflow bleibt grün)
- ❌ **ERROR:** Kritische Probleme (Workflow schlägt fehl)

### Outputs

Alle Ergebnisse werden im **GitHub Actions Step Summary** angezeigt mit:
- Detaillierten Check-Ergebnissen
- Dokumentations-Statistiken
- Links zu relevanten Dokumenten

### Lokale Ausführung

Für lokale Pre-Merge-Checks verwende das Script:
```bash
bash scripts/docs/pre-merge-check.sh
```

Siehe auch: [`scripts/docs/pre-merge-check.sh`](../../scripts/docs/pre-merge-check.sh)

### Verwandte Dokumentation

- [Git Workflow & Definition of Done](../../docs/operations/git-workflow.md)
- [Documentation Sync Root-Cause-Analyse](../../docs/archive/retrospectives/DOCUMENTATION-SYNC-ROOT-CAUSE-ANALYSIS-20260411.md)
- [Pre-Merge-Check Script](../../scripts/docs/pre-merge-check.sh)

---

## 🔐 Benötigte GitHub Secrets

Konfiguriere folgende Secrets in: `Settings → Secrets and variables → Actions → New repository secret`

### 1. TAILSCALE_OAUTH_CLIENT_ID
**Beschreibung:** Tailscale OAuth Client ID für GitHub Actions  
**Erstellen:**
```bash
# In Tailscale Admin Console:
# Settings → OAuth clients → Generate OAuth client
# Scopes: devices:write
```
**Format:** `tsid-client-xxxxx`

### 2. TAILSCALE_OAUTH_SECRET
**Beschreibung:** Tailscale OAuth Secret  
**Format:** `tskey-client-xxxxx-xxxxx`  
**⚠️ Wichtig:** Nur einmal angezeigt, sicher speichern!

### 3. QS_VPS_SSH_KEY
**Beschreibung:** Private SSH-Key für QS-VPS Zugriff  
**Erstellen:**
```bash
# Zeige bestehenden Key an:
cat /root/.ssh/id_ed25519

# ODER erstelle neuen Key:
ssh-keygen -t ed25519 -C "github-actions-qs-vps" -f ~/.ssh/github_actions_ed25519
cat ~/.ssh/github_actions_ed25519

# Public Key auf VPS installieren:
ssh-copy-id -i ~/.ssh/github_actions_ed25519.pub root@devsystem-qs-vps.tailcfea8a.ts.net
```
**Format:** Kompletter private key inklusive `-----BEGIN OPENSSH PRIVATE KEY-----`

### 4. QS_VPS_HOST
**Beschreibung:** Hostname des QS-VPS  
**Wert:** `devsystem-qs-vps.tailcfea8a.ts.net`  
**Alternative:** Tailscale IP `100.82.171.88`

### 5. QS_VPS_USER
**Beschreibung:** SSH-User für VPS  
**Wert:** `root`

---

## 📝 Verwendung

### Manuelles Deployment

1. Gehe zu **Actions** Tab im GitHub Repository
2. Wähle **Deploy QS-VPS** Workflow
3. Klicke **Run workflow**
4. Wähle Optionen:
   - Branch: `main` (oder `feature/qs-github-integration` für Tests)
   - Deployment Mode: `normal` / `force` / `dry-run` / `rollback`
   - Component: Leer für alle, oder z.B. `install-caddy`
5. Klicke **Run workflow**
6. Beobachte Logs in Echtzeit
7. Prüfe **Summary** für Deployment Report

### Automatisches Deployment

```bash
# Lokale Änderungen an QS-Scripts committen:
git add scripts/qs/install-caddy-qs.sh
git commit -m "Update: Caddy installation"
git push origin main

# GitHub Actions wird automatisch getriggert
# Check workflow progress: https://github.com/USER/REPO/actions
```

### Deployment-Modi erklärt

#### Normal Mode
```bash
# In GitHub Actions:
Deployment Mode: normal

# Entspricht:
sudo bash scripts/qs/setup-qs-master.sh
```
- Deployed nur fehlende Komponenten
- Überspringt bereits deployed Komponenten

#### Force Mode
```bash
# In GitHub Actions:
Deployment Mode: force

# Entspricht:
sudo bash scripts/qs/setup-qs-master.sh --force
```
- Re-deployt ALLE Komponenten
- Ignoriert bestehende Marker

#### Dry-Run Mode
```bash
# In GitHub Actions:
Deployment Mode: dry-run

# Entspricht:
sudo bash scripts/qs/setup-qs-master.sh --dry-run
```
- Simuliert Deployment ohne Änderungen
- Testet Dependency-Chain

#### Rollback Mode
```bash
# In GitHub Actions:
Deployment Mode: rollback

# Entspricht:
sudo bash scripts/qs/setup-qs-master.sh --rollback
```
- Stellt vorherigen Zustand wieder her
- Nutzt Backups in `/var/backups/qs-deployment/`

### Spezifische Komponente deployen

```bash
# In GitHub Actions:
Deployment Mode: normal
Component: install-caddy

# Entspricht:
sudo bash scripts/qs/setup-qs-master.sh --component=install-caddy
```

---

## 🔍 Monitoring & Debugging

### Workflow Status prüfen

```bash
# GitHub CLI:
gh workflow list
gh run list --workflow=deploy-qs-vps.yml
gh run view <run-id>
```

### Deployment Reports ansehen

Reports werden in GitHub Step Summary angezeigt:
1. Gehe zu Workflow Run
2. Scrolle zu **Summary**
3. Siehe **Deployment Report**, **Service Status**, **Health Checks**

Alternativ direkt auf dem VPS:
```bash
ssh root@devsystem-qs-vps.tailcfea8a.ts.net
ls -lt /var/log/qs-deployment/deployment-report-*.md
cat /var/log/qs-deployment/deployment-report-LATEST.md
```

### Service-Status prüfen

```bash
# Via GitHub Actions Output (in Step Summary)
# Oder direkt:
ssh root@devsystem-qs-vps.tailcfea8a.ts.net "systemctl status caddy qdrant-qs"
```

### Logs analysieren

```bash
# Master-Orchestrator Logs:
ssh root@devsystem-qs-vps.tailcfea8a.ts.net "tail -f /var/log/qs-deployment/master-orchestrator.log"

# Service-Logs:
ssh root@devsystem-qs-vps.tailcfea8a.ts.net "journalctl -u caddy -f"
ssh root@devsystem-qs-vps.tailcfea8a.ts.net "journalctl -u qdrant-qs -f"
```

---

## 🛡️ Sicherheit

### Tailscale VPN
- Alle Verbindungen laufen über Tailscale VPN
- Zero-Trust-Netzwerk
- End-to-End verschlüsselt
- Nur autorisierte Geräte

### SSH-Keys
- Ed25519 Keys (modern, sicher)
- Keys werden nur für Workflow-Dauer verwendet
- Cleanup nach Workflow-Ende
- Separate Keys für GitHub Actions empfohlen

### Secrets Management
- Secrets werden niemals in Logs angezeigt
- GitHub Actions masked sensitive data automatically
- Secrets nur in private Repository verfügbar
- Regelmäßige Rotation empfohlen

---

## 📊 Success Criteria

Ein Deployment gilt als erfolgreich wenn:
- ✅ SSH-Verbindung funktioniert
- ✅ Repository erfolgreich synchronisiert
- ✅ Master-Orchestrator läuft ohne Fehler
- ✅ Alle Services sind `active`
- ✅ Health Checks bestehen
- ✅ Keine kritischen Fehler in Logs

---

## 🐛 Troubleshooting

### Problem: "Permission denied (publickey)"
**Lösung:** 
```bash
# Prüfe QS_VPS_SSH_KEY Secret:
# 1. Kompletter private key inklusive header/footer?
# 2. Keine zusätzlichen Leerzeichen?
# 3. Public key auf VPS installiert?
```

### Problem: "Tailscale authentication failed"
**Lösung:**
```bash
# Prüfe Tailscale Secrets:
# 1. OAuth Client korrekt erstellt?
# 2. Scope: devices:write gesetzt?
# 3. Client nicht abgelaufen?
```

### Problem: "Service health check failed"
**Lösung:**
```bash
# SSH zum VPS:
ssh root@devsystem-qs-vps.tailcfea8a.ts.net

# Prüfe Services:
systemctl status caddy qdrant-qs

# Prüfe Logs:
journalctl -u caddy -n 50
journalctl -u qdrant-qs -n 50
```

### Problem: "Deployment failed but services running"
**Lösung:**
```bash
# Führe Force-Deployment aus:
# In GitHub Actions: Deployment Mode = force

# ODER direkt auf VPS:
cd /root/work/DevSystem
sudo bash scripts/qs/setup-qs-master.sh --force
```

---

## 📚 Weitere Informationen

- [Master-Orchestrator Dokumentation](../../PHASE2-ORCHESTRATOR-STATUS.md)
- [Idempotenz-Framework](../../PHASE1-IDEMPOTENZ-STATUS.md)
- [VPS SSH Setup](../../VPS-SSH-FIX-GUIDE.md)
- [Deployment Success Report](../../DEPLOYMENT-SUCCESS-PHASE1-2.md)

---

**Erstellt:** 2026-04-10  
**Status:** Production-Ready  
**Maintainer:** DevSystem Team
