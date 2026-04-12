# Tailscale GitHub Actions Setup - Vereinfachter Prozess

Dieses Dokument beschreibt den **vereinfachten** Prozess zur Einrichtung von Tailscale für GitHub Actions. Der Benutzer muss nur **einmal im Browser auf "Authorize" klicken**, der Rest wird automatisiert.

## 🎯 Ziel

Minimaler manueller Aufwand für den Benutzer:
- ✅ Ein Klick im Browser (Auth Key generieren)
- ✅ Key kopieren und einfügen
- ✅ Alles andere wird automatisiert

## 📋 Übersicht der Methoden

### Methode 1: Auth Key (EMPFOHLEN) ⭐

**Vorteile:**
- ✅ Einfacher Setup-Prozess
- ✅ Nur EIN Secret erforderlich
- ✅ Direkt verwendbar
- ✅ Konfigurierbare Ablaufzeit (z.B. 90 Tage)

**Verwendung:**
Der Auth Key wird direkt in `TAILSCALE_OAUTH_SECRET` gespeichert. Die Tailscale GitHub Action erkennt automatisch, dass es sich um einen Auth Key handelt.

### Methode 2: OAuth Client

**Vorteile:**
- ✅ Permanente Lösung ohne Ablaufdatum
- ✅ Feingranulare Berechtigungen

**Nachteile:**
- ⚠️ ZWEI Secrets erforderlich (Client ID + Secret)
- ⚠️ Komplexerer Setup-Prozess

## 🚀 Automatisiertes Setup (Empfohlen)

### Schritt 1: Voraussetzungen prüfen

Stelle sicher, dass folgende Tools installiert sind:

```bash
# GitHub CLI
gh --version

# Falls nicht installiert:
# https://cli.github.com/

# GitHub CLI authentifizieren
gh auth login
```

### Schritt 2: Setup-Skript ausführen

```bash
# Im DevSystem Repository
cd /root/work/DevSystem

# Setup-Skript ausführen
./scripts/setup-tailscale-github-auth.sh
```

Das Skript führt dich durch den gesamten Prozess:

1. **Auswahl der Methode** (Auth Key oder OAuth)
2. **Browser-Fenster öffnen** (automatisch)
3. **Anweisungen anzeigen** (Schritt-für-Schritt)
4. **Secrets setzen** (automatisch via GitHub CLI)
5. **Verifizierung** (automatisch)

### Schritt 3: Im Browser autorisieren

#### Für Auth Key (Empfohlen):

1. Browser öffnet sich automatisch auf: `https://login.tailscale.com/admin/settings/keys`
2. Klicke auf **"Generate auth key"**
3. Konfiguriere:
   - ✅ **Reusable**: JA (für mehrere GitHub Actions Runs)
   - ✅ **Ephemeral**: JA (Runner werden automatisch entfernt)
   - ✅ **Preauthorized**: JA (keine manuelle Autorisierung)
   - 📝 **Tags**: `tag:ci` (optional)
   - ⏰ **Expiry**: 90 days (oder länger)
4. Klicke auf **"Generate key"**
5. Kopiere den Key (Format: `tskey-auth-...`)
6. Füge ihn im Terminal ein

#### Für OAuth:

1. Browser öffnet sich automatisch auf: `https://login.tailscale.com/admin/settings/oauth`
2. Klicke auf **"Generate OAuth client"**
3. Konfiguriere:
   - 📝 **Name**: `GitHub Actions - DevSystem`
   - 🏷️ **Scopes**: `devices:write`
4. Klicke auf **"Generate"**
5. Kopiere BEIDE Credentials:
   - Client ID (z.B. `k12AB34cd5EF6GH`)
   - Client Secret (z.B. `tskey-client-...`)
6. Füge sie im Terminal ein

### Schritt 4: Verifizierung

Das Skript verifiziert automatisch:
- ✅ Secrets wurden korrekt gesetzt
- ✅ GitHub CLI funktioniert
- ✅ Alle erforderlichen Secrets sind vorhanden

## 📖 Manuelle Setup-Alternative

Falls du das Setup lieber manuell durchführen möchtest:

### Auth Key Methode

```bash
# 1. Auth Key generieren (im Browser)
# https://login.tailscale.com/admin/settings/keys

# 2. Secret setzen
gh secret set TAILSCALE_OAUTH_SECRET --repo HaraldKiessling/DevSystem
# Füge den Auth Key ein (tskey-auth-...)

# 3. Verifizieren
gh secret list --repo HaraldKiessling/DevSystem | grep TAILSCALE
```

### OAuth Methode

```bash
# 1. OAuth Client erstellen (im Browser)
# https://login.tailscale.com/admin/settings/oauth

# 2. Client ID Secret setzen
echo "DEINE_CLIENT_ID" | gh secret set TAILSCALE_OAUTH_CLIENT_ID --repo HaraldKiessling/DevSystem

# 3. Client Secret setzen
gh secret set TAILSCALE_OAUTH_SECRET --repo HaraldKiessling/DevSystem
# Füge das Client Secret ein (tskey-client-...)

# 4. Verifizieren
gh secret list --repo HaraldKiessling/DevSystem | grep TAILSCALE
```

## 🔧 Workflow-Konfiguration

Die GitHub Action [`tailscale/github-action@v2`](https://github.com/tailscale/github-action) unterstützt **beide Methoden automatisch**:

### Mit Auth Key

```yaml
- name: Setup Tailscale
  uses: tailscale/github-action@v2
  with:
    oauth-secret: ${{ secrets.TAILSCALE_OAUTH_SECRET }}
    tags: tag:ci
```

Die Action erkennt automatisch, dass `oauth-secret` einen Auth Key enthält (beginnt mit `tskey-auth-`).

### Mit OAuth

```yaml
- name: Setup Tailscale
  uses: tailscale/github-action@v2
  with:
    oauth-client-id: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID }}
    oauth-secret: ${{ secrets.TAILSCALE_OAUTH_SECRET }}
    tags: tag:ci
```

## 🧪 Testing

### Workflow testen

```bash
# Workflow manuell starten
gh workflow run deploy-qs-vps.yml

# Workflow-Status überwachen
gh run watch

# Logs anzeigen (bei Fehlern)
gh run view --log
```

### Erwartetes Ergebnis

Bei erfolgreichem Setup sollte der Workflow:
1. ✅ Tailscale-Verbindung herstellen
2. ✅ SSH-Verbindung zum QS-VPS aufbauen
3. ✅ Deployment durchführen

## 🔄 Wartung

### Auth Key erneuern (nach Ablauf)

Auth Keys haben eine konfigurierbare Ablaufzeit (z.B. 90 Tage). Vor Ablauf:

```bash
# 1. Neuen Auth Key generieren (siehe oben)

# 2. Secret updaten
gh secret set TAILSCALE_OAUTH_SECRET --repo HaraldKiessling/DevSystem
# Füge den neuen Auth Key ein

# 3. Test-Workflow starten
gh workflow run deploy-qs-vps.yml
```

### OAuth Client erneuern

OAuth Clients haben in der Regel kein Ablaufdatum, aber falls nötig:

```bash
# 1. Alten OAuth Client in Tailscale Admin Console löschen
# 2. Neuen OAuth Client erstellen (siehe oben)
# 3. Secrets updaten (siehe manuelle Setup-Alternative)
```

## 🆚 Vergleich: Auth Key vs OAuth

| Kriterium | Auth Key ⭐ | OAuth |
|-----------|------------|-------|
| **Setup-Komplexität** | 🟢 Einfach (1 Secret) | 🟡 Mittel (2 Secrets) |
| **Wartungsaufwand** | 🟡 Periodisch (90 Tage) | 🟢 Minimal |
| **Sicherheit** | 🟢 Sehr gut (ephemeral) | 🟢 Sehr gut |
| **GitHub Actions** | ✅ Vollständig unterstützt | ✅ Vollständig unterstützt |
| **Empfohlen für** | Entwicklung, QS | Produktion |

## 📚 Weitere Ressourcen

- [Tailscale GitHub Action](https://github.com/tailscale/github-action)
- [Tailscale Auth Keys](https://tailscale.com/kb/1085/auth-keys/)
- [Tailscale OAuth Clients](https://tailscale.com/kb/1215/oauth-clients/)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)

## ❓ Troubleshooting

### Problem: "Command 'gh' not found"

```bash
# GitHub CLI installieren
# Linux/macOS: https://cli.github.com/
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh
```

### Problem: "gh auth status" zeigt "Not authenticated"

```bash
# GitHub CLI authentifizieren
gh auth login
# Folge den Anweisungen im Terminal
```

### Problem: Workflow schlägt fehl mit "Tailscale connection failed"

**Mögliche Ursachen:**
1. Auth Key ist abgelaufen → Neuen Key generieren
2. OAuth Secret ist ungültig → Secrets erneut setzen
3. ACL-Konfiguration verhindert Zugriff → ACLs in Tailscale Admin Console prüfen

**Lösung:**

```bash
# 1. Secrets prüfen
gh secret list --repo HaraldKiessling/DevSystem | grep TAILSCALE

# 2. Workflow-Logs ansehen
gh run view --log

# 3. Setup-Skript erneut ausführen
./scripts/setup-tailscale-github-auth.sh
```

### Problem: SSH-Verbindung zum VPS schlägt fehl

**Hinweis:** Dies ist ein separates Problem vom Tailscale-Setup.

**Lösung:** Siehe [`VPS-SSH-FIX-GUIDE.md`](VPS-SSH-FIX-GUIDE.md) für SSH-spezifische Probleme.

## 🎉 Zusammenfassung

Mit diesem vereinfachten Prozess benötigt der Benutzer nur:

1. ✅ **5 Minuten Zeit**
2. ✅ **Ein Klick im Browser** (Auth Key generieren)
3. ✅ **Copy & Paste** (Key ins Terminal)

Alles andere wird automatisiert! 🚀
