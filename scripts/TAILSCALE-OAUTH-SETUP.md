# Tailscale OAuth Setup für Scripts

## Schnellstart: QS-VPS mit OAuth

Das [`setup-qs-vps.sh`](setup-qs-vps.sh) Script unterstützt jetzt OAuth nativ für permanente Authentifizierung.

### Option 1: OAuth (Empfohlen - Permanent)

```bash
# 1. OAuth Credentials als Umgebungsvariablen exportieren
export TAILSCALE_OAUTH_CLIENT_ID='k1234...'
export TAILSCALE_OAUTH_SECRET='tskey-client-k1234...'

# 2. Setup-Script ausführen
sudo bash scripts/setup-qs-vps.sh
```

**Vorteile:**
- ✓ Permanente Authentifizierung (kein Ablauf)
- ✓ Keine manuelle Erneuerung alle 90 Tage
- ✓ Empfohlene Methode für Produktionsumgebungen

### Option 2: Auth Key (Fallback)

```bash
# 1. Auth Key in Datei oder als Umgebungsvariable
echo "tskey-auth-..." > scripts/tailscale-authkey.txt
# ODER
export TAILSCALE_AUTHKEY='tskey-auth-...'

# 2. Setup-Script ausführen
sudo bash scripts/setup-qs-vps.sh
```

**Hinweis:** Auth Keys laufen nach 90 Tagen ab und müssen erneuert werden.

## OAuth Credentials erstellen

1. Gehe zu: https://login.tailscale.com/admin/settings/oauth
2. Klicke auf "Generate OAuth Client"
3. Notiere:
   - **CLIENT ID**: `k1234...`
   - **CLIENT SECRET**: `tskey-client-k1234...`

## Automatische Methoden-Erkennung

Das Script erkennt automatisch, welche Authentifizierungsmethode verfügbar ist:

1. **OAuth** wird bevorzugt (wenn `TAILSCALE_OAUTH_CLIENT_ID` und `TAILSCALE_OAUTH_SECRET` gesetzt sind)
2. **Auth Key** als Fallback (wenn `TAILSCALE_AUTHKEY` gesetzt ist oder in `tailscale-authkey.txt` vorhanden)
3. **Fehler** wenn keine Methode konfiguriert ist

## Cloud-Init / GitHub Actions

### GitHub Actions mit OAuth

```yaml
env:
  TAILSCALE_OAUTH_CLIENT_ID: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID }}
  TAILSCALE_OAUTH_SECRET: ${{ secrets.TAILSCALE_OAUTH_SECRET }}

steps:
  - name: Deploy QS-VPS
    run: |
      ssh root@vps 'bash -s' < scripts/setup-qs-vps.sh
```

### Cloud-Init mit OAuth

```yaml
#cloud-config
write_files:
  - path: /etc/environment
    content: |
      TAILSCALE_OAUTH_CLIENT_ID=k1234...
      TAILSCALE_OAUTH_SECRET=tskey-client-k1234...
    append: true

runcmd:
  - source /etc/environment
  - bash /path/to/setup-qs-vps.sh
```

## Migration von Auth Key zu OAuth

Siehe detaillierte Anleitung: [`docs/operations/TAILSCALE-OAUTH-MIGRATION-GUIDE.md`](../docs/operations/TAILSCALE-OAUTH-MIGRATION-GUIDE.md)

## Weitere Informationen

- [OAuth Migration Guide](../docs/operations/TAILSCALE-OAUTH-MIGRATION-GUIDE.md)
- [Tailscale OAuth Docs](https://tailscale.com/kb/1215/oauth-clients)
- [Auth Methods Comparison](../docs/operations/TAILSCALE-AUTH-METHODS-COMPARISON.md)
