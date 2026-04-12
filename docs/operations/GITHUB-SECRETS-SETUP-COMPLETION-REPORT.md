# GitHub Secrets Setup - Abschlussbericht

**Datum**: 2026-04-12  
**Status**: Teilweise abgeschlossen - Manuelle Schritte erforderlich

## ✅ Erfolgreich durchgeführt

### 1. SSH-Schlüssel generiert
- **Typ**: ed25519 (moderne, sichere Kryptographie)
- **Speicherort**: `/tmp/github-actions-keys/github-actions-qs-vps`
- **Fingerprint**: SHA256:OBRG3YlO5xLbGea8z4AKgMnwrUDDaiw2mxiuJ3ETL1E
- **Kommentar**: github-actions-deploy-devsystem

### 2. GitHub Secrets konfiguriert
Folgende Secrets wurden über GitHub CLI erfolgreich hinzugefügt:

| Secret Name | Wert | Status |
|-------------|------|--------|
| `QS_VPS_HOST` | 100.82.171.88 | ✅ Gesetzt |
| `QS_VPS_USER` | root | ✅ Gesetzt |
| `QS_VPS_SSH_KEY` | (privater Schlüssel) | ✅ Gesetzt |

**Verifizierung**: Alle Secrets wurden um 10:32 UTC am 12.04.2026 erfolgreich gesetzt.

### 3. GitHub CLI Authentication
- **Status**: ✅ Erfolgreich authentifiziert
- **Account**: HaraldKiessling
- **Repository**: HaraldKiessling/DevSystem
- **Berechtigungen**: admin:public_key, gist, read:org, repo

### 4. Tailscale-Status geprüft
- **QS-VPS Status**: ✅ Online und aktiv
- **Tailscale IP**: 100.82.171.88
- **Hostname**: devsystem-qs-vps
- **Verbindung**: Direct Connection (85.215.221.58:41641)

## ⚠️ Manuelle Schritte erforderlich

### 1. Public Key auf QS-VPS autorisieren

Der generierte Public Key muss auf dem QS-VPS in `authorized_keys` hinzugefügt werden.

**Public Key**:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMpY6chJO6D7lJUls6Xc3cGevJqqgQEMEl7munP7XhdR github-actions-deploy-devsystem
```

#### Option A: Via existierender SSH-Verbindung (Empfohlen)

Wenn bereits SSH-Zugriff auf den QS-VPS besteht:

```bash
# Auf einem Gerät im Tailscale-Netzwerk
ssh root@100.82.171.88

# Dann auf dem QS-VPS
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMpY6chJO6D7lJUls6Xc3cGevJqqgQEMEl7munP7XhdR github-actions-deploy-devsystem" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Verifizierung
tail -1 ~/.ssh/authorized_keys
```

#### Option B: Via Hetzner Cloud Console

Falls kein SSH-Zugriff möglich:

1. Öffne die [Hetzner Cloud Console](https://console.hetzner.cloud/)
2. Wähle das Projekt "DevSystem QS-VPS"
3. Klicke auf den Server "devsystem-qs-vps"
4. Klicke auf **Console** (Webkonsole öffnet sich)
5. Logge dich als `root` ein
6. Führe folgende Befehle aus:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
cat >> ~/.ssh/authorized_keys << 'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMpY6chJO6D7lJUls6Xc3cGevJqqgQEMEl7munP7XhdR github-actions-deploy-devsystem
EOF
chmod 600 ~/.ssh/authorized_keys
```

#### Option C: Via Cloud-Init oder User-Data

Beim nächsten VPS-Rebuild kann der Key automatisch hinzugefügt werden. Ergänze in `scripts/qs-vps-cloud-init.yaml`:

```yaml
ssh_authorized_keys:
  - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMpY6chJO6D7lJUls6Xc3cGevJqqgQEMEl7munP7XhdR github-actions-deploy-devsystem
```

### 2. Tailscale OAuth Client erstellen

Die Tailscale GitHub Action benötigt OAuth-Credentials. Diese können **nur manuell** über die Tailscale Admin Console erstellt werden.

#### Schritt-für-Schritt Anleitung:

1. **Tailscale Admin Console öffnen**
   - URL: https://login.tailscale.com/admin
   - Mit Tailscale-Konto anmelden

2. **OAuth Client erstellen**
   - Navigiere zu **Settings** → **OAuth clients**
   - Klicke auf **Generate OAuth client**

3. **OAuth Client konfigurieren**
   - **Description**: `GitHub Actions - DevSystem Deploy`
   - **Tags**: Wähle `tag:ci` oder erstelle diesen Tag
   - **Scopes**: Erforderliche Berechtigungen aktivieren
     - ✅ `devices:write` (Geräte im Netzwerk erstellen)
     - ✅ `all` (Vollzugriff - für CI/CD empfohlen)

4. **Client Credentials sichern**
   
   Nach der Erstellung werden **einmalig** angezeigt:
   - **Client ID**: z.B. `k12AB34cd5EF6GH`
   - **Client Secret**: z.B. `tskey-client-kABcDeFgHiJkLmNo1234567890abcdefghij`
   
   ⚠️ **WICHTIG**: Das Client Secret wird nur einmal angezeigt! Sofort sichern!

5. **GitHub Secrets hinzufügen**
   
   Jetzt können die Tailscale-Secrets manuell oder per CLI gesetzt werden:
   
   **Option A: Via GitHub CLI (Empfohlen)**
   ```bash
   # Client ID setzen
   gh secret set TAILSCALE_OAUTH_CLIENT_ID --body "DEINE_CLIENT_ID" --repo HaraldKiessling/DevSystem
   
   # Client Secret setzen
   gh secret set TAILSCALE_OAUTH_SECRET --body "DEIN_CLIENT_SECRET" --repo HaraldKiessling/DevSystem
   
   # Verifizierung
   gh secret list --repo HaraldKiessling/DevSystem
   ```
   
   **Option B: Via GitHub Web-Interface**
   - Repository öffnen: https://github.com/HaraldKiessling/DevSystem
   - Navigiere zu **Settings** → **Secrets and variables** → **Actions**
   - Klicke auf **New repository secret**
   - Füge `TAILSCALE_OAUTH_CLIENT_ID` hinzu
   - Füge `TAILSCALE_OAUTH_SECRET` hinzu

6. **ACL-Konfiguration (optional)**
   
   Falls der Tag `tag:ci` noch nicht existiert:
   
   - Navigiere zu **Access controls** in der Tailscale Admin Console
   - Füge folgende ACL-Einträge hinzu:
   
   ```json
   {
     "tagOwners": {
       "tag:ci": ["autogroup:admin"]
     },
     "acls": [
       {
         "action": "accept",
         "src": ["tag:ci"],
         "dst": ["devsystem-qs-vps:*"]
       }
     ]
   }
   ```
   
   - Klicke auf **Save**

## 📋 Checkliste für vollständige Konfiguration

### Sofort erforderlich
- [ ] Public Key auf QS-VPS hinzufügen (siehe oben)
- [ ] Tailscale OAuth Client erstellen (siehe oben)
- [ ] `TAILSCALE_OAUTH_CLIENT_ID` Secret setzen
- [ ] `TAILSCALE_OAUTH_SECRET` Secret setzen

### Verifizierung
- [ ] SSH-Verbindung mit neuem Key testen:
  ```bash
  ssh -i /tmp/github-actions-keys/github-actions-qs-vps root@100.82.171.88 "echo 'Erfolgreich verbunden'"
  ```

- [ ] Alle Secrets vorhanden prüfen:
  ```bash
  gh secret list --repo HaraldKiessling/DevSystem
  ```
  
  Erforderliche Secrets:
  - ✅ QS_VPS_HOST
  - ✅ QS_VPS_USER  
  - ✅ QS_VPS_SSH_KEY
  - ⏳ TAILSCALE_OAUTH_CLIENT_ID (manuell erforderlich)
  - ⏳ TAILSCALE_OAUTH_SECRET (manuell erforderlich)

- [ ] Deploy-Workflow testen:
  ```bash
  # Via GitHub Web-Interface oder CLI
  gh workflow run deploy-qs-vps.yml --repo HaraldKiessling/DevSystem -f mode=dry-run
  ```

## 🔒 Sicherheitshinweise

### SSH-Schlüssel Management

1. **Privater Schlüssel**
   - Speicherort: `/tmp/github-actions-keys/github-actions-qs-vps`
   - ⚠️ **Temporär**: Wird bei Neustart gelöscht
   - Wurde als GitHub Secret gesichert
   - **Backup**: Falls benötigt, sicher außerhalb des Repositories speichern

2. **Public Key**
   - Kann bedenkenlos geteilt werden
   - Sollte nur auf dem QS-VPS vorhanden sein
   - Bei Kompromittierung: Aus `authorized_keys` entfernen

3. **Key Rotation**
   - Empfohlen: Alle 6 Monate rotieren
   - Bei Verdacht auf Kompromittierung: Sofort neuen Key generieren

### OAuth Token Security

1. **Token Rotation**
   - Tailscale OAuth Tokens regelmäßig rotieren (empfohlen: alle 6 Monate)
   - Bei Kompromittierung in Tailscale Admin Console widerrufen

2. **Minimal Privileges**
   - OAuth Client sollte nur Zugriff auf QS-VPS haben
   - ACL-Regeln auf minimum beschränken

3. **Audit Logging**
   - GitHub Actions Workflow-Runs regelmäßig überprüfen
   - Tailscale Admin Console: Audit-Logs monitoren

## 🧪 Test-Workflow

Nach vollständiger Konfiguration:

1. **Dry-Run Test** (empfohlen für ersten Test)
   ```bash
   gh workflow run deploy-qs-vps.yml \
     --repo HaraldKiessling/DevSystem \
     --ref main \
     -f mode=dry-run
   ```

2. **Workflow-Status überwachen**
   ```bash
   gh run list --workflow=deploy-qs-vps.yml --repo HaraldKiessling/DevSystem --limit 1
   ```

3. **Logs bei Fehler anzeigen**
   ```bash
   gh run view --repo HaraldKiessling/DevSystem --log
   ```

4. **Deployment vom Smartphone testen**
   - GitHub-App oder Browser öffnen
   - Repository → Actions → Deploy QS-VPS
   - "Run workflow" → Mode: dry-run
   - Workflow-Logs live verfolgen

## 📊 Aktueller Status

### ✅ Vollständig konfiguriert (2026-04-12 10:36 UTC)
- SSH-Schlüssel generiert und gesichert
- QS_VPS_HOST Secret gesetzt (100.82.171.88)
- QS_VPS_USER Secret gesetzt (root)
- QS_VPS_SSH_KEY Secret gesetzt
- GitHub CLI authentifiziert
- Tailscale-Netzwerk aktiv
- **Detaillierte Anleitung erstellt**: [MANUAL-SETUP-STEPS.md](./MANUAL-SETUP-STEPS.md)

### ⏳ Ausstehend (manuelle Schritte)

**Hinweis**: SSH-Zugriff auf QS-VPS erfordert manuelle Tailscale-Authentifizierung über Browser:
- Authentifizierungs-URL: `https://login.tailscale.com/a/[ID]`
- Nach Authentifizierung können folgende Schritte durchgeführt werden:

1. **Public Key auf QS-VPS autorisieren** (~5 Min)
   - SSH-Verbindung herstellen (Browser-Authentifizierung)
   - Public Key zu `~/.ssh/authorized_keys` hinzufügen
   - Berechtigungen setzen (600 für authorized_keys, 700 für .ssh)
   - SSH-Verbindung mit neuem Key testen

2. **Tailscale OAuth Client erstellen** (~5 Min)
   - Tailscale Admin Console öffnen
   - OAuth Client mit Tag `tag:ci` erstellen
   - Client ID und Secret sichern (einmalige Anzeige!)

3. **Tailscale Secrets setzen** (~2 Min)
   - `TAILSCALE_OAUTH_CLIENT_ID` Secret setzen
   - `TAILSCALE_OAUTH_SECRET` Secret setzen
   - Alle 5 Secrets verifizieren

4. **End-to-End Test** (~10 Min)
   - Dry-Run Workflow ausführen
   - Logs prüfen und bei Erfolg vollständiges Deployment testen

### 🎯 Nächste Schritte

**Vollständige Schritt-für-Schritt-Anleitung**: [MANUAL-SETUP-STEPS.md](./MANUAL-SETUP-STEPS.md)

**Kurzübersicht**:
1. **Sofort**: [MANUAL-SETUP-STEPS.md](./MANUAL-SETUP-STEPS.md) lesen
2. **Schritt 1**: Public Key auf QS-VPS autorisieren (ca. 5 Min)
3. **Schritt 2**: Tailscale OAuth Client erstellen (ca. 5 Min)
4. **Schritt 3**: Secrets setzen und verifizieren (ca. 2 Min)
5. **Schritt 4**: ACL konfigurieren - optional (ca. 5 Min)
6. **Schritt 5**: End-to-End Test durchführen (ca. 10 Min)

**Geschätzte Gesamtdauer**: 25-30 Minuten

## 📚 Weiterführende Dokumentation

- [GitHub Secrets Setup Guide](./github-secrets-setup.md) - Vollständige Anleitung
- [Deploy QS-VPS Workflow](../../.github/workflows/deploy-qs-vps.yml) - Der GitHub Actions Workflow
- [Tailscale Konzept](../concepts/tailscale-konzept.md) - Tailscale-Integration
- [QS-VPS Setup](../../scripts/QS-VPS-SETUP.md) - VPS-Konfiguration

## 🔑 Schnellreferenz: Erforderliche Werte

### Bereits gesetzt (in GitHub)
```
QS_VPS_HOST=100.82.171.88
QS_VPS_USER=root
QS_VPS_SSH_KEY=(gesetzt, siehe GitHub Secrets)
```

### Auf QS-VPS autorisieren
```bash
# Public Key hinzufügen:
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMpY6chJO6D7lJUls6Xc3cGevJqqgQEMEl7munP7XhdR github-actions-deploy-devsystem
```

### Manuell zu erstellen
```
TAILSCALE_OAUTH_CLIENT_ID=(via Tailscale Admin Console)
TAILSCALE_OAUTH_SECRET=(via Tailscale Admin Console)
```

---

**Erstellt**: 2026-04-12 10:32 UTC  
**Autor**: Automatisierte GitHub Secrets-Konfiguration  
**Repository**: HaraldKiessling/DevSystem
