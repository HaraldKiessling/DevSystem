# Manuelle Setup-Schritte - Kurzreferenz

**Status**: 2026-04-12 10:37 UTC  
**Kontext**: Verbleibende Schritte für GitHub Actions Deployment

## 📊 Aktueller Stand

### ✅ Automatisch abgeschlossen
```bash
# GitHub Secrets gesetzt (3 von 5)
QS_VPS_HOST       = 100.82.171.88
QS_VPS_USER       = root
QS_VPS_SSH_KEY    = (gesetzt)
```

### ⏳ Manuell erforderlich
```bash
# Fehlende Secrets (2 von 5)
TAILSCALE_OAUTH_CLIENT_ID = (noch zu setzen)
TAILSCALE_OAUTH_SECRET    = (noch zu setzen)
```

## 🚀 Schnellanleitung

### Schritt 1: SSH Public Key autorisieren (~5 Min)

```bash
# 1. SSH-Verbindung herstellen (öffnet Browser für Tailscale Auth)
ssh root@100.82.171.88

# 2. Nach erfolgreicher Authentifizierung auf dem VPS:
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMpY6chJO6D7lJUls6Xc3cGevJqqgQEMEl7munP7XhdR github-actions-deploy-devsystem" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# 3. Verifizierung
grep "github-actions-deploy-devsystem" ~/.ssh/authorized_keys
```

### Schritt 2: Tailscale OAuth Client (~5 Min)

1. **Browser öffnen**: https://login.tailscale.com/admin
2. **Navigieren**: Settings → OAuth clients → Generate OAuth client
3. **Konfigurieren**:
   - Description: `GitHub Actions - DevSystem Deploy`
   - Tags: `tag:ci`
   - Scopes: `devices:write` + `all`
4. **Client ID und Secret sichern** (einmalige Anzeige!)

### Schritt 3: Secrets setzen (~2 Min)

```bash
# Client ID setzen
gh secret set TAILSCALE_OAUTH_CLIENT_ID \
  --body "DEINE_CLIENT_ID" \
  --repo HaraldKiessling/DevSystem

# Client Secret setzen (interaktiv)
gh secret set TAILSCALE_OAUTH_SECRET \
  --repo HaraldKiessling/DevSystem

# Verifizierung (sollte 5 Secrets zeigen)
gh secret list --repo HaraldKiessling/DevSystem
```

### Schritt 4: End-to-End Test (~10 Min)

```bash
# Dry-Run Workflow starten
gh workflow run deploy-qs-vps.yml \
  --repo HaraldKiessling/DevSystem \
  --ref main \
  -f mode=dry-run

# Status überwachen
gh run watch --repo HaraldKiessling/DevSystem
```

## 🔑 Public Key (Kopiervorlage)

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMpY6chJO6D7lJUls6Xc3cGevJqqgQEMEl7munP7XhdR github-actions-deploy-devsystem
```

## 📚 Vollständige Dokumentation

Für detaillierte Anleitungen mit Troubleshooting und Erklärungen:
- **[MANUAL-SETUP-STEPS.md](./MANUAL-SETUP-STEPS.md)** - Vollständige Anleitung
- **[GITHUB-SECRETS-SETUP-COMPLETION-REPORT.md](./GITHUB-SECRETS-SETUP-COMPLETION-REPORT.md)** - Status-Report

## ⏱️ Zeitplan

- Schritt 1 (SSH): 5 Min
- Schritt 2 (OAuth): 5 Min
- Schritt 3 (Secrets): 2 Min
- Schritt 4 (Test): 10 Min
- **Total**: ~25 Min

---

**Hinweis**: Tailscale-Authentifizierung erfordert Browser-Zugang. SSH-Befehle öffnen automatisch eine Authentifizierungs-URL im Format `https://login.tailscale.com/a/[ID]`.
