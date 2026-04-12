# Tailscale OAuth Migration Guide - Von Auth Key zu OAuth

## 🎯 Ziel

**Einmaliger Setup** statt periodischer Erneuerung: Migriere von Tailscale Auth Key (90 Tage Ablauf) zu OAuth Client (permanent gültig).

## ❓ Problem: Warum muss ich Tailscale immer wieder einrichten?

### Aktuelle Situation (Auth Key)

```
Auth Key (tskey-auth-...) 
    ↓
Läuft nach 90 Tagen ab
    ↓
Workflow schlägt fehl
    ↓
Manuelle Erneuerung erforderlich
```

**Ergebnis:** Alle 90 Tage muss das Secret manuell erneuert werden.

### Lösung: OAuth Client (Permanent)

```
OAuth Client (tskey-client-...)
    ↓
Permanent gültig (kein Ablaufdatum)
    ↓
Einmaliges Setup
    ↓
Keine Wartung erforderlich (nur bei Ubuntu-Neuinstallation)
```

**Ergebnis:** Setup einmal durchführen, dann nie wieder.

## 📊 Vergleich

| Feature | Auth Key (Aktuell) | OAuth Client (Empfohlen) |
|---------|-------------------|--------------------------|
| **Ablaufdatum** | ✅ 90 Tage (konfigurierbar) | ❌ Permanent |
| **Wartungsaufwand** | ⚠️ Periodisch (alle 90 Tage) | ✅ Einmalig |
| **Anzahl Secrets** | 1 | 2 |
| **Setup-Komplexität** | Einfach | Mittel |
| **Empfohlen für** | Testing, Entwicklung | **Produktion, QS-VPS** |
| **Automatische Rotation** | Notwendig | Nicht notwendig |

## 🚀 Migration durchführen

### Voraussetzungen

```bash
# GitHub CLI muss installiert und authentifiziert sein
gh --version
gh auth status

# Falls nicht:
gh auth login
```

### Schritt 1: Setup-Skript ausführen

```bash
cd /root/work/DevSystem
./scripts/setup-tailscale-github-auth.sh
```

### Schritt 2: OAuth wählen

Bei der Frage **"Welche Methode möchtest du verwenden?"**:

```
Wähle: 2 (OAuth Client)
```

### Schritt 3: OAuth Client erstellen

Das Skript öffnet automatisch: https://login.tailscale.com/admin/settings/oauth

1. **Klicke:** "Generate OAuth client"
2. **Konfiguriere:**
   - Name: `GitHub Actions - DevSystem`
   - Scopes: `devices:write`
3. **Klicke:** "Generate"
4. **Kopiere BEIDE Credentials:**
   - OAuth Client ID (z.B. `k12AB34cd5EF6GH`)
   - OAuth Client Secret (z.B. `tskey-client-k...`)

### Schritt 4: Credentials eingeben

Das Skript fragt nach beiden Werten:

```bash
Füge die OAuth Client ID ein: 
[Client ID hier einfügen]

Füge das OAuth Client Secret ein (wird nicht angezeigt):
[Client Secret hier einfügen]
```

### Schritt 5: Automatische Konfiguration

Das Skript setzt automatisch beide GitHub Secrets:
- `TAILSCALE_OAUTH_CLIENT_ID`
- `TAILSCALE_OAUTH_SECRET`

✅ **Fertig!** OAuth ist jetzt eingerichtet.

## 🔄 Workflow-Verhalten nach Migration

### Automatische Erkennung

Der Workflow [`deploy-qs-vps.yml`](../../.github/workflows/deploy-qs-vps.yml) erkennt automatisch, welche Methode konfiguriert ist:

```yaml
# 1. Versuche OAuth (wenn TAILSCALE_OAUTH_CLIENT_ID existiert)
- name: Setup Tailscale (OAuth)
  if: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID != '' }}
  uses: tailscale/github-action@v2
  with:
    oauth-client-id: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID }}
    oauth-secret: ${{ secrets.TAILSCALE_OAUTH_SECRET }}

# 2. Fallback zu Auth Key (wenn OAuth nicht konfiguriert)
- name: Setup Tailscale (Auth Key Fallback)
  if: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID == '' }}
  uses: tailscale/github-action@v2
  with:
    oauth-secret: ${{ secrets.TAILSCALE_OAUTH_SECRET }}
```

### Nach erfolgreicher Migration

**Nach der Migration zu OAuth:**
- ✅ Workflow verwendet automatisch OAuth
- ✅ Kein Ablaufdatum mehr
- ✅ Keine periodische Wartung erforderlich
- ✅ Funktioniert, solange Ubuntu nicht neu installiert wird

## ✅ Verifizierung

### Prüfe GitHub Secrets

```bash
# Zeige konfigurierte Secrets
gh secret list --repo HaraldKiessling/DevSystem | grep TAILSCALE

# Erwartete Ausgabe (nach Migration):
# TAILSCALE_OAUTH_CLIENT_ID    Updated YYYY-MM-DD
# TAILSCALE_OAUTH_SECRET       Updated YYYY-MM-DD
```

### Teste den Workflow

```bash
# Starte einen Test-Deploy
gh workflow run deploy-qs-vps.yml \
  -f deployment_mode=dry-run \
  -f component=""

# Warte 10 Sekunden
sleep 10

# Überwache den Workflow
gh run watch
```

**Erwartetes Ergebnis:**
- ✅ "Setup Tailscale (OAuth)" Step erfolgreich
- ✅ "Setup Tailscale (Auth Key Fallback)" Step übersprungen
- ✅ Restlicher Workflow läuft durch

## 🔧 Troubleshooting

### Problem: OAuth-Setup schlägt fehl

**Symptom:**
```
Setup Tailscale (OAuth): failed
Setup Tailscale (Auth Key Fallback): failed
```

**Lösung 1: Prüfe Secrets**
```bash
gh secret list --repo HaraldKiessling/DevSystem | grep TAILSCALE

# Beide müssen vorhanden sein:
# - TAILSCALE_OAUTH_CLIENT_ID
# - TAILSCALE_OAUTH_SECRET
```

**Lösung 2: Erstelle OAuth Client neu**
```bash
# Führe Setup-Skript erneut aus
./scripts/setup-tailscale-github-auth.sh

# Wähle Option 2 (OAuth)
```

### Problem: OAuth Client ID ist leer

**Symptom:** Workflow verwendet weiterhin Auth Key statt OAuth

**Ursache:** `TAILSCALE_OAUTH_CLIENT_ID` Secret ist nicht gesetzt

**Lösung:**
```bash
# Manuell setzen
gh secret set TAILSCALE_OAUTH_CLIENT_ID --repo HaraldKiessling/DevSystem
# Client ID einfügen und Enter
```

### Problem: Welches Secret ist welches?

**OAuth benötigt 2 Secrets:**

1. **TAILSCALE_OAUTH_CLIENT_ID**
   - Format: Alphanumerisch (z.B. `k12AB34cd5EF6GH`)
   - Sichtbar in Tailscale Admin Console
   - Nicht geheim, aber auch nicht öffentlich teilen

2. **TAILSCALE_OAUTH_SECRET**
   - Format: `tskey-client-k...`
   - Nur einmal beim Erstellen sichtbar
   - Geheim! Niemals commiten oder teilen

## 📝 Wartung

### OAuth (nach Migration)

**Erforderliche Wartung:** ❌ Keine

**Erneute Einrichtung nur bei:**
- Ubuntu-Neuinstallation auf dem VPS
- OAuth Client wurde in Tailscale gelöscht
- Security-Incident (Credential Rotation)

### Alte Auth Key entfernen (optional)

Nach erfolgreicher Migration kannst du den alten Auth Key in Tailscale deaktivieren:

1. Öffne: https://login.tailscale.com/admin/settings/keys
2. Finde deinen alten Auth Key
3. Klicke: "Revoke"

Das alte `TAILSCALE_OAUTH_SECRET` mit dem Auth Key wird automatisch ignoriert, sobald `TAILSCALE_OAUTH_CLIENT_ID` gesetzt ist.

## 🔄 Rollback zu Auth Key (falls nötig)

Falls du zurück zu Auth Key möchtest:

```bash
# Lösche OAuth Client ID Secret
gh secret delete TAILSCALE_OAUTH_CLIENT_ID --repo HaraldKiessling/DevSystem

# Workflow verwendet dann automatisch wieder Auth Key
# (falls TAILSCALE_OAUTH_SECRET noch einen gültigen Auth Key enthält)
```

## 📚 Weiterführende Dokumentation

- **Setup-Anleitung:** [`TAILSCALE-GITHUB-SETUP-SIMPLIFIED.md`](./TAILSCALE-GITHUB-SETUP-SIMPLIFIED.md)
- **Methoden-Vergleich:** [`TAILSCALE-AUTH-METHODS-COMPARISON.md`](./TAILSCALE-AUTH-METHODS-COMPARISON.md)
- **Setup-Skript:** [`scripts/setup-tailscale-github-auth.sh`](../../scripts/setup-tailscale-github-auth.sh)
- **Workflow:** [`.github/workflows/deploy-qs-vps.yml`](../../.github/workflows/deploy-qs-vps.yml)

## ✨ Zusammenfassung

**Vorher (Auth Key):**
- ⚠️ Alle 90 Tage manuelle Erneuerung
- ⚠️ Workflow schlägt bei Ablauf fehl
- ⚠️ Wartungsaufwand

**Nachher (OAuth):**
- ✅ Einmalig einrichten
- ✅ Permanent gültig
- ✅ Keine Wartung erforderlich
- ✅ Professionelle Lösung

**Nächster Schritt:**
→ Führe das Setup-Skript aus und wähle Option 2 (OAuth)
