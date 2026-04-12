# QS-VPS Deploy-Workflow Debug-Bericht

**Datum**: 2026-04-12  
**Workflow**: [`deploy-qs-vps.yml`](.github/workflows/deploy-qs-vps.yml:1)  
**Status**: ⚠️ Fehler identifiziert - Manuelle Aktion erforderlich

---

## 🔍 Zusammenfassung

Der QS-VPS Deploy-Workflow schlägt beim Tailscale-Setup Schritt mit folgendem Fehler fehl:

```
backend error: invalid key: unable to validate API key
```

**Workflow-Runs:**
1. **Run #1** (24305413734): ❌ Fehlgeschlagen - OAuth-Client-ID fehlt
2. **Run #2** (24305501282): ❌ Fehlgeschlagen - Ungültiger Auth-Key

---

## 📊 Fehleranalyse

### 1. Erster Workflow-Run (24305413734)

**Problem**: Fehlende `TAILSCALE_OAUTH_CLIENT_ID`

Der Workflow verwendete ursprünglich die OAuth-Client-Methode:
```yaml
- name: Setup Tailscale
  uses: tailscale/github-action@v2
  with:
    oauth-client-id: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID }}
    oauth-secret: ${{ secrets.TAILSCALE_OAUTH_SECRET }}
    tags: tag:ci
```

**Vorhandene Secrets:**
```
QS_VPS_HOST             ✅ Gesetzt
QS_VPS_USER             ✅ Gesetzt
QS_VPS_SSH_KEY          ✅ Gesetzt
TAILSCALE_OAUTH_SECRET  ✅ Gesetzt
TAILSCALE_OAUTH_CLIENT_ID  ❌ Fehlt
```

**Log-Auszug:**
```
Deploy to QS-VPS Setup Tailscale 2026-04-12T11:15:25.1260793Z 
backend error: invalid key: unable to validate API key
```

### 2. Zweiter Workflow-Run (24305501282)

**Durchgeführte Änderung:**

Workflow wurde auf Auth-Key-Methode umgestellt ([Commit f75b7f0](https://github.com/HaraldKiessling/DevSystem/commit/f75b7f0)):

```yaml
- name: Setup Tailscale
  uses: tailscale/github-action@v2
  with:
    oauth-secret: ${{ secrets.TAILSCALE_OAUTH_SECRET }}  # Nur noch oauth-secret
    tags: tag:ci
```

**Problem**: Ungültiger Auth-Key-Wert

Das Secret `TAILSCALE_OAUTH_SECRET` enthält wahrscheinlich:
- Ein abgelaufenes OAuth-Client-Secret (Format: `tskey-client-...`)
- Einen ungültigen/abgelaufenen Auth-Key

**Log-Auszug:**
```
Deploy to QS-VPS Setup Tailscale 2026-04-12T11:20:36.9212491Z 
backend error: invalid key: unable to validate API key
```

---

## 🔑 Root Cause Analysis

### Problem

Der Wert in `TAILSCALE_OAUTH_SECRET` ist **ungültig oder abgelaufen**.

### Mögliche Ursachen

1. **Falsches Format**: OAuth-Client-Secret statt Auth-Key
2. **Abgelaufen**: Auth-Keys haben standardmäßig 90 Tage Gültigkeit
3. **Widerrufen**: Der Key wurde in der Tailscale Admin Console deaktiviert
4. **Falsche Berechtigungen**: Der Key hat nicht die erforderlichen Tags/ACLs

---

## ✅ Lösung

### Option 1: Neuen Auth-Key generieren (Empfohlen)

Auth-Keys sind einfacher zu verwalten und benötigen nur ein Secret.

#### Schritt 1: Auth-Key in Tailscale erstellen

1. Öffne die **Tailscale Admin Console**: https://login.tailscale.com/admin/settings/keys
2. Klicke auf **Generate auth key**
3. Konfiguriere den Key:
   ```
   Description:     GitHub Actions - DevSystem Deploy
   Reusable:        ✅ Yes (für mehrere Workflow-Runs)
   Ephemeral:       ✅ Yes (temporäre Nodes)
   Preauthorized:   ✅ Yes (keine manuelle Genehmigung)
   Tags:            tag:ci
   Expiry:          90 days (Standard)
   ```
4. Klicke auf **Generate key**
5. **Kopiere den Auth-Key** (Format: `tskey-auth-...`)

   ⚠️ **WICHTIG**: Der Key wird nur einmal angezeigt!

#### Schritt 2: GitHub Secret aktualisieren

```bash
# Auth-Key in Secret speichern (interaktiv)
gh secret set TAILSCALE_OAUTH_SECRET \
  --repo HaraldKiessling/DevSystem

# Bei Aufforderung den Auth-Key einfügen (tskey-auth-...)
```

**Alternative: Direkt mit Wert**
```bash
echo "tskey-auth-DEIN_AUTH_KEY_HIER" | \
  gh secret set TAILSCALE_OAUTH_SECRET \
  --repo HaraldKiessling/DevSystem
```

#### Schritt 3: Verifizierung

```bash
# Secret-Liste prüfen
gh secret list --repo HaraldKiessling/DevSystem

# Workflow erneut ausführen
gh workflow run deploy-qs-vps.yml \
  -f deployment_mode=dry-run \
  -f component=""

# Status überwachen
gh run watch
```

### Option 2: OAuth-Client-Methode verwenden

Falls du OAuth-Clients bevorzugst (mehr Kontrolle, keine Ablaufzeit):

#### Schritt 1: OAuth-Client in Tailscale erstellen

1. Öffne: https://login.tailscale.com/admin/settings/oauth
2. Klicke auf **Generate OAuth client**
3. Konfiguriere:
   ```
   Description: GitHub Actions - DevSystem
   Tags:        tag:ci
   Scopes:      devices:write, all
   ```
4. Speichere:
   - **Client ID** (z.B. `k12AB34cd5EF6GH`)
   - **Client Secret** (z.B. `tskey-client-...`)

#### Schritt 2: Beide Secrets setzen

```bash
# Client ID setzen
echo "DEINE_CLIENT_ID" | \
  gh secret set TAILSCALE_OAUTH_CLIENT_ID \
  --repo HaraldKiessling/DevSystem

# Client Secret setzen
echo "DEIN_CLIENT_SECRET" | \
  gh secret set TAILSCALE_OAUTH_SECRET \
  --repo HaraldKiessling/DevSystem
```

#### Schritt 3: Workflow anpassen

```bash
# Workflow-Datei bearbeiten
nano .github/workflows/deploy-qs-vps.yml
```

Ändere zurück zu OAuth-Client-Methode:
```yaml
- name: Setup Tailscale
  uses: tailscale/github-action@v2
  with:
    oauth-client-id: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID }}
    oauth-secret: ${{ secrets.TAILSCALE_OAUTH_SECRET }}
    tags: tag:ci
```

---

## 🔧 Durchgeführte Änderungen

### Commit f75b7f0: Workflow auf Auth-Key-Methode umgestellt

**Datei**: [`.github/workflows/deploy-qs-vps.yml`](.github/workflows/deploy-qs-vps.yml:37)

**Änderung:**
```diff
  - name: Setup Tailscale
    uses: tailscale/github-action@v2
    with:
-     oauth-client-id: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID }}
      oauth-secret: ${{ secrets.TAILSCALE_OAUTH_SECRET }}
      tags: tag:ci
```

**Begründung:**
- Auth-Key-Methode ist einfacher (nur 1 Secret)
- Reduziert Komplexität
- Empfohlene Methode für CI/CD laut Dokumentation

**Referenz**: [`docs/operations/TAILSCALE-AUTH-METHODS-COMPARISON.md`](docs/operations/TAILSCALE-AUTH-METHODS-COMPARISON.md:21)

---

## 📝 Weitere Probleme entdeckt

### SSH-Key nicht auf QS-VPS autorisiert

Beide Workflow-Runs zeigen in "Fetch Deployment Report":
```
Warning: Identity file /home/runner/.ssh/id_ed25519 not accessible: No such file or directory.
ssh: connect to host *** port 22: Connection timed out
```

**Grund**: Der generierte SSH Public Key wurde noch nicht auf dem QS-VPS autorisiert.

**Public Key** (aus [`docs/operations/GITHUB-SECRETS-SETUP-COMPLETION-REPORT.md`](docs/operations/GITHUB-SECRETS-SETUP-COMPLETION-REPORT.md:44)):
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMpY6chJO6D7lJUls6Xc3cGevJqqgQEMEl7munP7XhdR github-actions-deploy-devsystem
```

**Lösung**: Public Key auf QS-VPS autorisieren

```bash
# Via SSH auf QS-VPS
ssh root@100.82.171.88

# Public Key hinzufügen
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMpY6chJO6D7lJUls6Xc3cGevJqqgQEMEl7munP7XhdR github-actions-deploy-devsystem" >> ~/.ssh/authorized_keys

# Verifizierung
tail -1 ~/.ssh/authorized_keys
```

---

## ✅ Nächste Schritte

### Sofort erforderlich

- [ ] **Tailscale Auth-Key generieren** (siehe Option 1 oben)
- [ ] **GitHub Secret aktualisieren**: `TAILSCALE_OAUTH_SECRET`
- [ ] **SSH Public Key auf QS-VPS autorisieren**

### Verifizierung

- [ ] **Workflow erneut ausführen**:
  ```bash
  gh workflow run deploy-qs-vps.yml \
    -f deployment_mode=dry-run \
    -f component=""
  ```

- [ ] **Status überwachen**:
  ```bash
  gh run watch
  ```

- [ ] **Logs prüfen bei Fehler**:
  ```bash
  gh run list --limit 1 --workflow=deploy-qs-vps.yml
  gh run view [RUN_ID] --log
  ```

### Dokumentation

- [ ] Nach erfolgreicher Ausführung: Report abschließen
- [ ] Best Practices dokumentieren
- [ ] In [`docs/operations/GITHUB-SECRETS-SETUP-COMPLETION-REPORT.md`](docs/operations/GITHUB-SECRETS-SETUP-COMPLETION-REPORT.md:1) verlinken

---

## 📚 Referenzen

- **Workflow-Datei**: [`.github/workflows/deploy-qs-vps.yml`](.github/workflows/deploy-qs-vps.yml:1)
- **Tailscale Auth-Methoden**: [`docs/operations/TAILSCALE-AUTH-METHODS-COMPARISON.md`](docs/operations/TAILSCALE-AUTH-METHODS-COMPARISON.md:1)
- **Tailscale Setup**: [`docs/operations/QUICK-START-TAILSCALE-GITHUB.md`](docs/operations/QUICK-START-TAILSCALE-GITHUB.md:1)
- **Secrets Setup**: [`docs/operations/GITHUB-SECRETS-SETUP-COMPLETION-REPORT.md`](docs/operations/GITHUB-SECRETS-SETUP-COMPLETION-REPORT.md:1)
- **GitHub Actions Runs**:
  - Run #1: https://github.com/HaraldKiessling/DevSystem/actions/runs/24305413734
  - Run #2: https://github.com/HaraldKiessling/DevSystem/actions/runs/24305501282

---

## 🎯 Lessons Learned

### Was gut funktioniert hat

1. ✅ **Schnelle Fehleridentifikation** durch `gh run watch` und `gh run view --log`
2. ✅ **Strukturierte Fehleranalyse** mit Logs und Secret-Verifizierung
3. ✅ **Dokumentierte Lösung** mit klaren Schritten

### Was verbessert werden kann

1. ⚠️ **Secret-Validierung**: Prüfe Format/Gültigkeit vor Workflow-Run
2. ⚠️ **Automatisierte Tests**: Mock-Tests für Tailscale-Setup
3. ⚠️ **Besseres Error Handling**: Workflow sollte spezifischere Fehler ausgeben

### Empfehlungen

1. **Auth-Key-Ablauf überwachen**: Kalender-Erinnerung 7 Tage vor Ablauf
2. **Secret-Rotation**: Regelmäßige Erneuerung alle 60 Tage
3. **Lokaler Test**: Tailscale-Setup lokal testen vor GitHub Actions
4. **Monitoring**: Webhook für fehlgeschlagene Workflow-Runs einrichten

---

**Erstellt**: 2026-04-12 11:23 UTC  
**Autor**: Roo (Code Mode)  
**Workflow-Runs**: 2 (beide fehlgeschlagen)  
**Status**: Wartet auf manuelle Tailscale Auth-Key-Generierung
