# QS-VPS Simple Setup - Quick Start

Vereinfachte Cloud-Init Variante für schnelle Testing-Umgebungen.

## Unterschied zur Full-Version

| Feature | Simple | Full |
|---------|--------|------|
| Zeilen Code | 47 | 358 |
| Setup-Zeit | ~5 Min | ~15 Min |
| Tailscale | ✅ (via Script) | ✅ (manuell) |
| UFW Firewall | ✅ Basis | ✅ Erweitert |
| Fail2ban | ✅ Standard | ✅ Custom |
| Audit-System | ❌ | ✅ |
| Kernel-Härtung | ❌ | ✅ |

## Verwendung

### 1. Tailscale Auth Key generieren
```
https://login.tailscale.com/admin/settings/keys
- Reusable: ✅
- Ephemeral: ✅ (für temporäre QS-VPS)
- Expiration: 90 Tage
```

### 2. Script vorbereiten
```bash
# Download
curl -o cloud-init.yaml https://raw.githubusercontent.com/HaraldKiessling/DevSystem/feature/qs-vps-cloud-init/scripts/qs-vps-cloud-init-simple.yaml

# Auth Key einsetzen (Zeile 21)
sed -i 's/YOUR_TAILSCALE_AUTH_KEY_HERE/tskey-auth-DEIN_KEY/' cloud-init.yaml
```

### 3. IONOS VPS erstellen
- Ubuntu 24.04 LTS
- Cloud-Init: Kopiere modifiziertes Script
- Server erstellen

### 4. Zugriff (nach 5-7 Min)
```bash
# Tailscale-IP aus Admin Panel holen
# https://login.tailscale.com/admin/machines

# SSH
ssh root@<tailscale-ip>

# Oder via Hostname
ssh root@devsystem-qs-vps
```

## Validierung

```bash
# Tailscale Status
tailscale status

# Firewall Rules
sudo ufw status verbose

# Fail2ban
sudo systemctl status fail2ban
```

## Weitere Komponenten installieren

Nach dem Basis-Setup:

```bash
# Caddy
bash /path/to/scripts/qs/install-caddy-qs.sh
bash /path/to/scripts/qs/configure-caddy-qs.sh

# code-server
bash /path/to/scripts/qs/install-code-server-qs.sh
bash /path/to/scripts/qs/configure-code-server-qs.sh

# Qdrant
bash /path/to/scripts/qs/deploy-qdrant-qs.sh
```

## Empfehlung

- **QS-VPS:** Simple-Version (diese)
- **Produktiv-VPS:** Full-Version (qs-vps-cloud-init.yaml)
