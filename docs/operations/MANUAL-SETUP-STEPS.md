# Manuelle Setup-Schritte für GitHub Actions Deployment

**Datum**: 2026-04-12  
**Status**: Anleitung für verbleibende manuelle Schritte  
**Kontext**: SSH und Tailscale OAuth Client Setup

## 🎯 Überblick

Die automatische GitHub Secrets-Konfiguration wurde erfolgreich durchgeführt. Folgende **manuelle Schritte** sind erforderlich, um die Deployment-Pipeline vollständig einzurichten:

1. ✅ GitHub Secrets gesetzt (QS_VPS_HOST, QS_VPS_USER, QS_VPS_SSH_KEY)
2. ⏳ Public Key auf QS-VPS autorisieren (manuell)
3. ⏳ Tailscale OAuth Client erstellen (manuell)
4. ⏳ Tailscale Secrets setzen (nach OAuth-Erstellung)
5. ⏳ End-to-End Test durchführen

---

## 📋 Schritt 1: Public Key auf QS-VPS autorisieren

### Voraussetzungen
- Tailscale-Zugriff auf das Netzwerk
- SSH-Zugang zum QS-VPS (100.82.171.88)

### Anleitung

#### 1a. Tailscale-Authentifizierung durchführen

Da der SSH-Zugriff über Tailscale läuft, muss zuerst die Tailscale-Authentifizierung durchgeführt werden:

```bash
# SSH-Verbindung initiieren (öffnet Browser-Authentifizierung)
ssh root@100.82.171.88
```

**Wichtig**: Ein Browser-Fenster öffnet sich mit einer Tailscale-Authentifizierungs-URL:
- URL-Format: `https://login.tailscale.com/a/[ID]`
- Im Browser anmelden und Gerät autorisieren
- Nach erfolgreicher Authentifizierung wird die SSH-Verbindung hergestellt

#### 1b. Public Key autorisieren

Nach erfolgreicher Authentifizierung und Verbindung zum VPS:

```bash
# Public Key hinzufügen
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMpY6chJO6D7lJUls6Xc3cGevJqqgQEMEl7munP7XhdR github-actions-deploy-devsystem" >> ~/.ssh/authorized_keys

# Berechtigungen setzen
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh

# Verifizierung
grep "github-actions-deploy-devsystem" ~/.ssh/authorized_keys
```

**Erwartete Ausgabe**:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMpY6chJO6D7lJUls6Xc3cGevJqqgQEMEl7munP7XhdR github-actions-deploy-devsystem
```

#### 1c. SSH-Verbindung testen

```bash
# Von einem Gerät im Tailscale-Netzwerk
ssh -i /tmp/github-actions-keys/github-actions-qs-vps root@100.82.171.88 "echo 'SSH erfolgreich mit neuem Key'"
```

**Erfolg**: Wenn die Meldung "SSH erfolgreich mit neuem Key" erscheint, ist der Schritt abgeschlossen.

---

## 📋 Schritt 2: Tailscale OAuth Client erstellen

### Warum wird OAuth benötigt?

Die GitHub Actions benötigen OAuth-Credentials, um:
- Sich in das Tailscale-Netzwerk einzuwählen
- Verschlüsselte Verbindung zum QS-VPS herzustellen
- Deployments über die sichere Tailscale-Verbindung durchzuführen

### Anleitung

#### 2a. Tailscale Admin Console öffnen

1. Browser öffnen
2. URL aufrufen: https://login.tailscale.com/admin
3. Mit Tailscale-Konto anmelden

#### 2b. OAuth Client erstellen

1. Navigiere zu **Settings** (Zahnrad-Icon oben rechts)
2. Wähle **OAuth clients** in der linken Sidebar
3. Klicke auf **Generate OAuth client**

#### 2c. OAuth Client konfigurieren

**Konfigurationsdetails**:

| Feld | Wert | Beschreibung |
|------|------|--------------|
| **Description** | `GitHub Actions - DevSystem Deploy` | Beschreibender Name |
| **Tags** | `tag:ci` | Tag für CI/CD-Geräte |
| **Scopes** | Siehe unten | Erforderliche Berechtigungen |

**Erforderliche Scopes**:
- ✅ `devices:write` - Geräte im Netzwerk erstellen
- ✅ `all` - Vollzugriff (empfohlen für CI/CD)

**Alternative Minimal-Scopes** (falls `all` nicht gewünscht):
- `devices` - Geräte verwalten
- `routes:write` - Routen konfigurieren
- `keys:write` - Authentifizierungsschlüssel erstellen

#### 2d. Client Credentials sichern

Nach Klick auf **Generate** werden **einmalig** angezeigt:

```
Client ID:     k12AB34cd5EF6GH
Client Secret: tskey-client-kABcDeFgHiJkLmNo1234567890abcdefghij
```

⚠️ **WICHTIG**: 
- Das Client Secret wird **nur einmal** angezeigt!
- Sofort in sicherer Umgebung speichern
- Bei Verlust muss neuer OAuth Client erstellt werden

**Empfohlene Sicherung**:
```bash
# Temporär in Datei speichern (außerhalb des Git-Repos!)
echo "TAILSCALE_OAUTH_CLIENT_ID=k12AB34cd5EF6GH" > /tmp/tailscale-oauth.env
echo "TAILSCALE_OAUTH_SECRET=tskey-client-kABcDeFgHiJkLmNo1234567890abcdefghij" >> /tmp/tailscale-oauth.env
chmod 600 /tmp/tailscale-oauth.env
```

---

## 📋 Schritt 3: GitHub Secrets setzen

### Voraussetzungen
- OAuth Client ID und Secret aus Schritt 2
- GitHub CLI authentifiziert (`gh auth status`)

### Anleitung

#### 3a. Secrets setzen

```bash
# Client ID setzen
gh secret set TAILSCALE_OAUTH_CLIENT_ID \
  --body "DEINE_CLIENT_ID_HIER" \
  --repo HaraldKiessling/DevSystem

# Client Secret setzen (interaktiv, sicherer)
gh secret set TAILSCALE_OAUTH_SECRET \
  --repo HaraldKiessling/DevSystem
# Dann Secret eingeben und mit Enter bestätigen

# Alternative: Secret aus Datei
gh secret set TAILSCALE_OAUTH_SECRET \
  --body "$(grep TAILSCALE_OAUTH_SECRET /tmp/tailscale-oauth.env | cut -d= -f2)" \
  --repo HaraldKiessling/DevSystem
```

#### 3b. Secrets verifizieren

```bash
# Alle Secrets auflisten
gh secret list --repo HaraldKiessling/DevSystem
```

**Erwartete Ausgabe** (5 Secrets):
```
QS_VPS_HOST                  2024-04-12T10:32:12Z
QS_VPS_SSH_KEY              2024-04-12T10:32:14Z
QS_VPS_USER                 2024-04-12T10:32:13Z
TAILSCALE_OAUTH_CLIENT_ID   2024-04-12T10:45:00Z
TAILSCALE_OAUTH_SECRET      2024-04-12T10:45:01Z
```

#### 3c. Temporäre Dateien löschen

```bash
# OAuth-Credentials sicher löschen
shred -u /tmp/tailscale-oauth.env 2>/dev/null || rm -f /tmp/tailscale-oauth.env
```

---

## 📋 Schritt 4: ACL-Konfiguration (Optional aber empfohlen)

### Warum ACL konfigurieren?

Access Control Lists (ACLs) in Tailscale ermöglichen:
- Einschränkung des Zugriffs auf QS-VPS nur für CI/CD
- Sicherere Netzwerksegmentierung
- Audit-Trail für CI/CD-Zugriffe

### Anleitung

#### 4a. ACL Editor öffnen

1. Tailscale Admin Console: https://login.tailscale.com/admin
2. Navigiere zu **Access controls**
3. Klicke auf **Edit**

#### 4b. Tag-Owner definieren

Falls `tag:ci` noch nicht existiert, ergänzen:

```json
{
  "tagOwners": {
    "tag:ci": ["autogroup:admin"]
  }
}
```

#### 4c. ACL-Regeln hinzufügen

Zugriff für CI/CD auf QS-VPS erlauben:

```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["100.82.171.88:*"]
    }
  ]
}
```

#### 4d. Vollständige ACL-Beispiel-Konfiguration

```json
{
  "tagOwners": {
    "tag:ci": ["autogroup:admin"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["*:*"]
    },
    {
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["100.82.171.88:22", "100.82.171.88:80", "100.82.171.88:443"]
    }
  ]
}
```

#### 4e. ACL speichern und testen

1. Klicke auf **Save**
2. Tailscale validiert die ACL-Syntax
3. Bei Fehlern werden diese angezeigt (korrigieren und erneut speichern)

---

## 📋 Schritt 5: End-to-End Test durchführen

### 5a. Test-Vorbereitung

```bash
# Repository aktualisieren
cd /root/work/DevSystem
git pull origin main

# Workflow-Datei prüfen
ls -la .github/workflows/deploy-qs-vps.yml
```

### 5b. Dry-Run Test (empfohlen für ersten Test)

```bash
# Via GitHub CLI
gh workflow run deploy-qs-vps.yml \
  --repo HaraldKiessling/DevSystem \
  --ref main \
  -f mode=dry-run
```

**Alternative: Via GitHub Web-Interface**

1. Repository öffnen: https://github.com/HaraldKiessling/DevSystem
2. Navigiere zu **Actions**
3. Wähle **Deploy QS-VPS** Workflow
4. Klicke auf **Run workflow**
5. Branch: `main`
6. Mode: `dry-run`
7. Klicke auf **Run workflow**

### 5c. Workflow-Status überwachen

```bash
# Letzte Workflow-Runs anzeigen
gh run list --workflow=deploy-qs-vps.yml --repo HaraldKiessling/DevSystem --limit 5

# Letzen Run im Detail anzeigen
gh run view --repo HaraldKiessling/DevSystem

# Live-Logs verfolgen
gh run watch --repo HaraldKiessling/DevSystem
```

### 5d. Erfolgskriterien

✅ **Workflow erfolgreich**, wenn:
- GitHub Actions kann sich mit Tailscale verbinden
- SSH-Verbindung zum QS-VPS wird hergestellt
- Deployment-Skripte werden ausgeführt
- Alle Tests bestehen (bei Dry-Run: Simulation erfolgreich)

❌ **Workflow fehlgeschlagen**, wenn:
- Tailscale-Authentifizierung scheitert → OAuth Secrets prüfen
- SSH-Verbindung fehlschlägt → Public Key auf VPS prüfen
- Timeout bei SSH → VPS-Erreichbarkeit über Tailscale prüfen

### 5e. Troubleshooting

**Problem**: Tailscale-Authentifizierung scheitert

```bash
# Secrets erneut prüfen
gh secret list --repo HaraldKiessling/DevSystem | grep TAILSCALE

# OAuth Client in Tailscale Admin Console prüfen
# Settings → OAuth clients → "GitHub Actions - DevSystem Deploy"
```

**Problem**: SSH-Verbindung scheitert

```bash
# Manuell vom lokalen Rechner testen
ssh -i /tmp/github-actions-keys/github-actions-qs-vps root@100.82.171.88 "echo 'Test'"

# Authorized Keys auf VPS prüfen
ssh root@100.82.171.88 "cat ~/.ssh/authorized_keys | grep github-actions"
```

**Problem**: VPS nicht erreichbar

```bash
# Tailscale-Status prüfen (vom lokalen Rechner)
tailscale status | grep devsystem-qs-vps

# VPS-IP prüfen
ping 100.82.171.88
```

---

## 📋 Checkliste: Vollständige Konfiguration

### ✅ Automatisch abgeschlossen
- [x] SSH-Schlüssel generiert (ed25519)
- [x] GitHub Secret `QS_VPS_HOST` gesetzt
- [x] GitHub Secret `QS_VPS_USER` gesetzt
- [x] GitHub Secret `QS_VPS_SSH_KEY` gesetzt

### ⏳ Manuell erforderlich
- [ ] **Schritt 1**: Public Key auf QS-VPS autorisieren
  - [ ] Tailscale-Authentifizierung durchführen
  - [ ] SSH-Verbindung zum VPS herstellen
  - [ ] Public Key zu `authorized_keys` hinzufügen
  - [ ] SSH-Verbindung mit neuem Key testen

- [ ] **Schritt 2**: Tailscale OAuth Client erstellen
  - [ ] Admin Console öffnen
  - [ ] OAuth Client mit Tag `tag:ci` erstellen
  - [ ] Client ID und Secret sichern

- [ ] **Schritt 3**: Tailscale Secrets setzen
  - [ ] `gh secret set TAILSCALE_OAUTH_CLIENT_ID`
  - [ ] `gh secret set TAILSCALE_OAUTH_SECRET`
  - [ ] Secrets verifizieren (5 Secrets total)

- [ ] **Schritt 4**: ACL konfigurieren (optional)
  - [ ] Tag `tag:ci` in ACL definieren
  - [ ] Zugriff auf QS-VPS erlauben
  - [ ] ACL speichern und validieren

- [ ] **Schritt 5**: End-to-End Test
  - [ ] Dry-Run Workflow ausführen
  - [ ] Logs prüfen
  - [ ] Bei Erfolg: Vollständiges Deployment testen

---

## 🔒 Sicherheitshinweise

### SSH Key Management
- **Privater Schlüssel**: Nur als GitHub Secret gespeichert
- **Public Key**: Nur auf QS-VPS autorisiert
- **Rotation**: Alle 6 Monate empfohlen
- **Bei Kompromittierung**: Sofort aus `authorized_keys` entfernen und neue Keys generieren

### OAuth Token Management
- **Client Secret**: Niemals in Git committen
- **Rotation**: Alle 6 Monate empfohlen
- **Bei Kompromittierung**: In Tailscale Admin Console OAuth Client löschen und neu erstellen
- **Minimal Privileges**: Nur erforderliche Scopes aktivieren

### Tailscale ACL Best Practices
- Zugriff nur auf benötigte Ports beschränken (22, 80, 443)
- Regelmäßig Audit-Logs in Tailscale Admin Console prüfen
- Bei Verdacht auf Missbrauch: OAuth Client sofort widerrufen

---

## 📊 Aktueller Status

### ✅ Abgeschlossen (2026-04-12 10:32 UTC)
- SSH-Schlüssel generiert und als Secret gesichert
- QS_VPS_HOST Secret gesetzt: `100.82.171.88`
- QS_VPS_USER Secret gesetzt: `root`
- QS_VPS_SSH_KEY Secret gesetzt
- GitHub CLI authentifiziert

### ⏳ Ausstehend (manuelle Schritte)
- Public Key auf QS-VPS autorisieren
- Tailscale OAuth Client erstellen
- TAILSCALE_OAUTH_CLIENT_ID Secret setzen
- TAILSCALE_OAUTH_SECRET Secret setzen
- End-to-End Test durchführen

### 🎯 Geschätzte Dauer
- **Schritt 1** (SSH): ~5 Minuten
- **Schritt 2** (OAuth): ~5 Minuten
- **Schritt 3** (Secrets): ~2 Minuten
- **Schritt 4** (ACL, optional): ~5 Minuten
- **Schritt 5** (Test): ~10 Minuten
- **Total**: ~25-30 Minuten

---

## 📚 Weiterführende Dokumentation

- [GitHub Secrets Setup Guide](./github-secrets-setup.md)
- [GitHub Secrets Setup Completion Report](./GITHUB-SECRETS-SETUP-COMPLETION-REPORT.md)
- [Deploy QS-VPS Workflow](../../.github/workflows/deploy-qs-vps.yml)
- [Tailscale Konzept](../concepts/tailscale-konzept.md)
- [QS-VPS Setup](../../scripts/QS-VPS-SETUP.md)
- [Tailscale ACL Documentation](https://tailscale.com/kb/1018/acls/)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)

---

**Erstellt**: 2026-04-12 10:36 UTC  
**Autor**: DevSystem Automation  
**Repository**: HaraldKiessling/DevSystem  
**Status**: Anleitung für manuelle Setup-Schritte
