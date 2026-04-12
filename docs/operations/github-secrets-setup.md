# GitHub Secrets Setup für QS-VPS Deployment

> **🚀 Neu:** [Vereinfachter Tailscale Setup in 5 Minuten](QUICK-START-TAILSCALE-GITHUB.md) - Automatisiertes Setup-Skript verfügbar!

Dieses Dokument beschreibt die Konfiguration der GitHub Secrets, die für den automatischen Deploy-Workflow auf den QS-VPS benötigt werden.

## ⚡ Quick Start

Für einen schnellen, automatisierten Setup-Prozess (empfohlen):

```bash
# Automatisiertes Setup (5 Minuten)
./scripts/setup-tailscale-github-auth.sh
```

Siehe:
- [Quick Start Guide](QUICK-START-TAILSCALE-GITHUB.md) - Schnelleinstieg
- [Vereinfachter Setup](TAILSCALE-GITHUB-SETUP-SIMPLIFIED.md) - Detaillierte Anleitung
- [Methoden-Vergleich](TAILSCALE-AUTH-METHODS-COMPARISON.md) - Auth Key vs OAuth

---

## Übersicht (Manueller Setup)

Der Deploy-Workflow [`.github/workflows/deploy-qs-vps.yml`](../../.github/workflows/deploy-qs-vps.yml) ermöglicht das Deployment vom Smartphone oder jedem anderen Gerät aus. Er benötigt Zugriff auf das Tailscale-Netzwerk und den QS-VPS via SSH.

### Benötigte Secrets

| Secret Name | Beschreibung | Typ |
|-------------|--------------|-----|
| `TAILSCALE_OAUTH_CLIENT_ID` | OAuth Client ID für Tailscale-Zugriff | String |
| `TAILSCALE_OAUTH_SECRET` | OAuth Client Secret für Tailscale-Zugriff | String |
| `QS_VPS_SSH_KEY` | Privater SSH-Schlüssel für QS-VPS-Zugriff | Multi-line String |
| `QS_VPS_HOST` | Tailscale IP-Adresse des QS-VPS | String |
| `QS_VPS_USER` | SSH-Benutzername auf dem QS-VPS | String |

## 1. Tailscale OAuth Client erstellen

Die Tailscale GitHub Action benötigt OAuth-Credentials für den automatischen Zugriff auf das Tailscale-Netzwerk.

### Schritt 1: Tailscale Admin Console öffnen

1. Öffne die [Tailscale Admin Console](https://login.tailscale.com/admin)
2. Melde dich mit deinem Tailscale-Konto an

### Schritt 2: OAuth Client erstellen

1. Navigiere zu **Settings** → **OAuth clients**
2. Klicke auf **Generate OAuth client**
3. Konfiguriere den OAuth Client:
   - **Description**: `GitHub Actions - DevSystem Deploy`
   - **Tags**: Wähle `tag:ci` (oder erstelle diesen Tag)
     - Falls der Tag noch nicht existiert, musst du ihn zuerst in den ACLs definieren
   - **Scopes**: 
     - ✅ Alle erforderlichen Berechtigungen aktivieren
     - Empfohlen: Nur die minimal benötigten Rechte vergeben

### Schritt 3: OAuth Credentials sichern

Nach der Erstellung werden **einmalig** angezeigt:
- **Client ID**: z.B. `k12AB34cd5EF6GH`
- **Client Secret**: z.B. `tskey-client-kABcDeFgHiJkLmNo1234567890abcdefghij`

⚠️ **WICHTIG**: Das Client Secret wird nur einmal angezeigt! Speichere es sofort sicher.

### Schritt 4: ACL-Konfiguration (optional)

Falls der Tag `tag:ci` noch nicht existiert, muss er in den Tailscale ACLs definiert werden:

1. Navigiere zu **Access controls** in der Tailscale Admin Console
2. Füge folgende ACL-Einträge hinzu:

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

3. Klicke auf **Save** um die ACL-Änderungen zu übernehmen

## 2. SSH-Schlüssel für QS-VPS vorbereiten

Der Deploy-Workflow benötigt SSH-Zugriff auf den QS-VPS. Du solltest einen dedizierten SSH-Schlüssel für GitHub Actions verwenden.

### Option A: Neuen SSH-Schlüssel erstellen (Empfohlen)

```bash
# SSH-Schlüsselpaar generieren
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/github-actions-qs-vps

# Öffentlichen Schlüssel zum QS-VPS hinzufügen
ssh-copy-id -i ~/.ssh/github-actions-qs-vps.pub root@100.82.171.88
```

### Option B: Existierenden SSH-Schlüssel verwenden

Falls bereits SSH-Zugriff auf den QS-VPS besteht:

```bash
# Öffentlichen Schlüssel anzeigen
cat ~/.ssh/id_ed25519.pub

# Manuell auf dem QS-VPS hinzufügen
ssh root@100.82.171.88
echo "ssh-ed25519 AAAA... github-actions-deploy" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### Privaten Schlüssel auslesen

```bash
# Privaten Schlüssel anzeigen (für GitHub Secret)
cat ~/.ssh/github-actions-qs-vps
# oder
cat ~/.ssh/id_ed25519
```

Der komplette Inhalt (inkl. `-----BEGIN OPENSSH PRIVATE KEY-----` Header) wird als GitHub Secret benötigt.

## 3. Tailscale IP-Adresse des QS-VPS ermitteln

Die Tailscale IP-Adresse des QS-VPS wird benötigt, damit GitHub Actions über das Tailscale-Netzwerk darauf zugreifen kann.

```bash
# Auf einem Gerät im Tailscale-Netzwerk ausführen
tailscale status | grep qs-vps
```

Beispiel-Output:
```
100.82.171.88   devsystem-qs-vps  HaraldKiessling@  linux    -
```

Die IP-Adresse ist: `100.82.171.88`

### Alternative: Via Tailscale Admin Console

1. Öffne die [Tailscale Admin Console](https://login.tailscale.com/admin/machines)
2. Suche nach `devsystem-qs-vps`
3. Die Tailscale IP wird in der Liste angezeigt

## 4. GitHub Secrets konfigurieren

### Schritt 1: Repository Settings öffnen

1. Öffne das GitHub Repository: [DevSystem](https://github.com/DEIN_USERNAME/DevSystem)
2. Navigiere zu **Settings** → **Secrets and variables** → **Actions**
3. Klicke auf **New repository secret**

### Schritt 2: Secrets hinzufügen

Füge die folgenden Secrets nacheinander hinzu:

#### TAILSCALE_OAUTH_CLIENT_ID

- **Name**: `TAILSCALE_OAUTH_CLIENT_ID`
- **Value**: Die Client ID aus Schritt 1.3 (z.B. `k12AB34cd5EF6GH`)
- Klicke auf **Add secret**

#### TAILSCALE_OAUTH_SECRET

- **Name**: `TAILSCALE_OAUTH_SECRET`
- **Value**: Das Client Secret aus Schritt 1.3 (z.B. `tskey-client-kABcDeFgHiJkLmNo1234567890abcdefghij`)
- Klicke auf **Add secret**

#### QS_VPS_SSH_KEY

- **Name**: `QS_VPS_SSH_KEY`
- **Value**: Der komplette Inhalt des privaten SSH-Schlüssels (inkl. Header und Footer)
  
  ```
  -----BEGIN OPENSSH PRIVATE KEY-----
  b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
  ...
  (mehrere Zeilen)
  ...
  -----END OPENSSH PRIVATE KEY-----
  ```
- Klicke auf **Add secret**

#### QS_VPS_HOST

- **Name**: `QS_VPS_HOST`
- **Value**: `100.82.171.88` (Tailscale IP des QS-VPS)
- Klicke auf **Add secret**

#### QS_VPS_USER

- **Name**: `QS_VPS_USER`
- **Value**: `root` (Standard-Benutzer für VPS-Zugriff)
- Klicke auf **Add secret**

### Schritt 3: Secrets verifizieren

Nach dem Hinzufügen sollten folgende Secrets in der Liste erscheinen:

- ✅ TAILSCALE_OAUTH_CLIENT_ID
- ✅ TAILSCALE_OAUTH_SECRET
- ✅ QS_VPS_SSH_KEY
- ✅ QS_VPS_HOST
- ✅ QS_VPS_USER

## 5. Deployment testen

### Test vom Smartphone aus

1. Öffne die GitHub-App oder den Browser
2. Navigiere zum Repository → **Actions**
3. Wähle den Workflow **Deploy QS-VPS**
4. Klicke auf **Run workflow**
5. Wähle die gewünschten Optionen:
   - **Deployment Mode**: `dry-run` (für ersten Test)
   - **Component**: Leer lassen (für alle Komponenten)
6. Klicke auf **Run workflow**

### Workflow-Status prüfen

1. Der Workflow sollte automatisch starten
2. Prüfe die einzelnen Steps:
   - ✅ **Setup Tailscale**: Verbindung zum Tailscale-Netzwerk
   - ✅ **Setup SSH Key**: SSH-Schlüssel wird konfiguriert
   - ✅ **Test SSH Connection**: Verbindung zum QS-VPS wird getestet
   - ✅ **Sync Repository**: Code wird auf den QS-VPS übertragen
   - ✅ **Run Master-Orchestrator**: Deployment wird ausgeführt

### Bei Fehlern

#### Fehler: "Tailscale authentication failed"

- Prüfe, ob `TAILSCALE_OAUTH_CLIENT_ID` und `TAILSCALE_OAUTH_SECRET` korrekt gesetzt sind
- Stelle sicher, dass der OAuth Client in Tailscale noch aktiv ist
- Prüfe die ACL-Konfiguration für `tag:ci`

#### Fehler: "SSH connection failed"

- Prüfe, ob `QS_VPS_SSH_KEY` korrekt kopiert wurde (inkl. Header/Footer)
- Stelle sicher, dass der öffentliche Schlüssel auf dem QS-VPS in `~/.ssh/authorized_keys` vorhanden ist
- Prüfe, ob `QS_VPS_HOST` die korrekte Tailscale IP ist
- Verifiziere, dass der QS-VPS online und im Tailscale-Netzwerk erreichbar ist:
  ```bash
  tailscale status | grep qs-vps
  ```

#### Fehler: "Permission denied"

- Prüfe die Dateiberechtigungen auf dem QS-VPS:
  ```bash
  ssh root@100.82.171.88
  chmod 700 ~/.ssh
  chmod 600 ~/.ssh/authorized_keys
  ```

## 6. Sicherheitshinweise

### OAuth Token Rotation

- Rotiere die OAuth-Credentials regelmäßig (z.B. alle 6 Monate)
- Bei Verdacht auf Kompromittierung sofort neue Credentials erstellen

### SSH-Schlüssel-Management

- Verwende dedizierte SSH-Schlüssel für GitHub Actions
- Rotiere SSH-Schlüssel regelmäßig
- Überwache SSH-Zugriffe auf dem QS-VPS:
  ```bash
  tail -f /var/log/auth.log | grep sshd
  ```

### Minimal Privileges

- Der OAuth Client sollte nur Zugriff auf den QS-VPS haben (nicht auf andere Geräte)
- SSH-Zugriff sollte nur für Deployments verwendet werden
- Erwäge die Verwendung eines dedizierten Deployment-Users statt `root`

### Audit-Logging

- Überprüfe regelmäßig die Workflow-Runs in GitHub Actions
- Monitore Deployment-Aktivitäten auf dem QS-VPS:
  ```bash
  tail -f /var/log/qs-deployment/deployment-report-*.md
  ```

## 7. Workflow-Nutzung

### Manuelles Deployment vom Smartphone

Der Workflow kann mit verschiedenen Modi ausgeführt werden:

#### Normal Deployment
```yaml
Deployment Mode: normal
Component: (leer lassen)
```
Führt ein reguläres Deployment aller Komponenten durch.

#### Force Deployment
```yaml
Deployment Mode: force
Component: (leer lassen)
```
Erzwingt ein Deployment, auch wenn Idempotenz-Checks fehlschlagen.

#### Dry-Run
```yaml
Deployment Mode: dry-run
Component: (leer lassen)
```
Simuliert ein Deployment ohne Änderungen vorzunehmen. Ideal für Tests.

#### Rollback
```yaml
Deployment Mode: rollback
Component: (leer lassen)
```
Rollt das Deployment auf den vorherigen Stand zurück.

#### Spezifische Komponente
```yaml
Deployment Mode: normal
Component: caddy
```
Deployed nur die angegebene Komponente (z.B. `caddy`, `qdrant`, `code-server`).

### Automatisches Deployment

Der Workflow wird automatisch ausgelöst bei:
- Push auf den `main`-Branch
- Änderungen in `scripts/qs/**`
- Änderungen in `.github/workflows/deploy-qs-vps.yml`

## 8. Troubleshooting

### Tailscale-Verbindung prüfen

Auf einem lokalen Gerät im Tailscale-Netzwerk:

```bash
# Status aller Geräte anzeigen
tailscale status

# Netzwerk-Check
tailscale netcheck

# Verbindung zum QS-VPS testen
ping 100.82.171.88
```

### SSH-Verbindung manuell testen

```bash
# Von einem Gerät im Tailscale-Netzwerk
ssh -i ~/.ssh/github-actions-qs-vps root@100.82.171.88

# Oder mit existierendem Schlüssel
ssh root@100.82.171.88
```

### GitHub Actions Logs analysieren

1. Navigiere zu **Actions** im GitHub Repository
2. Wähle den fehlgeschlagenen Workflow-Run
3. Klicke auf den fehlgeschlagenen Step
4. Analysiere die Logs für Fehlermeldungen

### QS-VPS Deployment-Logs prüfen

```bash
# Via SSH auf dem QS-VPS
ssh root@100.82.171.88

# Deployment-Logs anzeigen
tail -f /var/log/qs-deployment/deployment-report-*.md

# System-Logs prüfen
journalctl -u caddy -f
journalctl -u qdrant-qs -f
```

## 9. Weiterführende Dokumentation

- [Tailscale-Konzept](../concepts/tailscale-konzept.md) - Detaillierte Tailscale-Konfiguration
- [Deploy-Workflow](.github/workflows/deploy-qs-vps.yml) - Der GitHub Actions Workflow
- [QS-VPS Setup](../../scripts/QS-VPS-SETUP.md) - Setup-Dokumentation für den QS-VPS
- [VPS SSH Fix Guide](./VPS-SSH-FIX-GUIDE.md) - Troubleshooting für SSH-Probleme

## 10. Zusammenfassung

Dieser Leitfaden beschreibt die vollständige Konfiguration der GitHub Secrets für den QS-VPS Deploy-Workflow:

1. ✅ **Tailscale OAuth Client** erstellt und konfiguriert
2. ✅ **SSH-Schlüssel** generiert und auf dem QS-VPS hinterlegt
3. ✅ **Tailscale IP** des QS-VPS ermittelt
4. ✅ **GitHub Secrets** konfiguriert
5. ✅ **Workflow** getestet und validiert

Nach erfolgreicher Konfiguration kannst du Deployments vom Smartphone, Desktop oder jedem anderen Gerät aus durchführen - ohne direkten SSH-Zugriff, da GitHub Actions über das Tailscale-Netzwerk auf den QS-VPS zugreift.

---

**Erstellt**: 2026-04-12  
**Zuletzt aktualisiert**: 2026-04-12  
**Status**: Produktiv
