# QS-VPS Setup - Master-Anleitung

Vollständige Anleitung für QS-VPS Setup mit einem Script.

## Übersicht

Dieses Setup nutzt **ein Bash-Script** das alles automatisiert:
- Tailscale VPN Installation
- UFW Firewall (SSH nur via Tailscale)
- Fail2ban
- System-Updates

## Voraussetzungen

- IONOS VPS mit Ubuntu 24.04 LTS (oder ähnlich)
- Tailscale Account
- SSH-Zugriff auf VPS

## Schritt-für-Schritt Anleitung

### 1. Tailscale Auth Key generieren

```
1. Gehe zu: https://login.tailscale.com/admin/settings/keys
2. Klicke: "Generate auth key"
3. Konfiguration:
   ✅ Reusable (mehrfach verwendbar)
   ✅ Ephemeral (für temporäre QS-VPS)
   ⏱️ Expiration: 90 Tage
4. Klicke: "Generate key"
5. Key kopieren (Format: tskey-auth-XXXXX-YYYYY)
```

**Wichtig:** Key sichern, wird gleich benötigt!

### 2. Repository auf VPS klonen

```bash
# SSH auf VPS (initial via IONOS-Zugangsdaten)
ssh root@<ionos-vps-ip>

# Repository klonen
cd /root
git clone https://github.com/HaraldKiessling/DevSystem.git
cd DevSystem
git checkout feature/qs-vps-cloud-init
```

### 3. Auth Key Datei erstellen

```bash
# Template kopieren
cp scripts/tailscale-authkey.txt.template scripts/tailscale-authkey.txt

# Auth Key eintragen (Editor deiner Wahl)
nano scripts/tailscale-authkey.txt
# ODER
echo "tskey-auth-DEIN_KEY_HIER" > scripts/tailscale-authkey.txt
```

**Datei sollte nur den Key enthalten, keine Leerzeichen!**

### 4. Setup-Script ausführen

```bash
# Script ausführen
sudo bash scripts/setup-qs-vps.sh
```

**Das Script führt aus:**
1. ✅ System-Updates (apt update/upgrade)
2. ✅ Tailscale-Installation (via offizielles Script)
3. ✅ Tailscale-Login mit deinem Auth Key
4. ✅ Hostname: `devsystem-qs-vps`
5. ✅ UFW Firewall (SSH nur via Tailscale)
6. ✅ Fail2ban

**Dauer:** ~5 Minuten

### 5. Tailscale-IP ermitteln

```bash
# Im VPS (nach Setup)
cat /root/tailscale-ip.txt

# Output z.B.: 100.100.221.56
```

**Oder im Tailscale Admin Panel:**
https://login.tailscale.com/admin/machines
→ Suche: "devsystem-qs-vps"

### 6. SSH via Tailscale

```bash
# Von deinem Hauptrechner
ssh root@100.100.221.56

# Oder via Hostname (wenn MagicDNS aktiv)
ssh root@devsystem-qs-vps
```

## Validierung

```bash
# Tailscale Status
tailscale status

# Sollte zeigen:
# - devsystem-qs-vps
# - IP: 100.x.x.x
# - Online

# Firewall prüfen
sudo ufw status verbose

# Sollte zeigen:
# - Status: active
# - 22/tcp on tailscale0: ALLOW IN
# - 41641/udp: ALLOW IN

# Fail2ban prüfen
sudo systemctl status fail2ban

# Sollte zeigen:
# - Active: active (running)
```

## Weitere Komponenten installieren

Nach dem Basis-Setup kannst du zusätzliche Komponenten installieren:

### Caddy Reverse-Proxy

```bash
bash scripts/qs/install-caddy-qs.sh
bash scripts/qs/configure-caddy-qs.sh
```

### code-server Web-IDE

```bash
bash scripts/qs/install-code-server-qs.sh
bash scripts/qs/configure-code-server-qs.sh
```

### Qdrant Vektordatenbank

```bash
bash scripts/qs/deploy-qdrant-qs.sh
```

### Alle Tests durchführen

```bash
bash scripts/qs/test-qs-deployment.sh
```

## Troubleshooting

### Problem: "Auth Key Datei nicht gefunden"

**Lösung:**
```bash
# Prüfe ob Datei existiert
ls -la scripts/tailscale-authkey.txt

# Falls nicht, erstelle sie
echo "DEIN_KEY" > scripts/tailscale-authkey.txt
```

### Problem: "Invalid authkey"

**Lösung:**
```bash
# 1. Neuen Key generieren (login.tailscale.com/admin)
# 2. Key in Datei eintragen
echo "NEUER_KEY" > scripts/tailscale-authkey.txt
# 3. Script erneut ausführen
```

### Problem: Kann mich nicht via SSH verbinden

**Ursache:** Firewall blockiert SSH von extern

**Lösung:**
```bash
# Nutze Tailscale-IP (nicht IONOS-IP)
ssh root@<tailscale-ip>

# Falls Tailscale nicht funktioniert, nutze IONOS Web-Konsole
```

## Sicherheitshinweise

### ✅ Best Practices

- **Ephemeral Keys verwenden:** QS-VPS werden automatisch entfernt
- **Keys nicht committen:** `tailscale-authkey.txt` ist in `.gitignore`
- **Key-Rotation:** Nach Projektabschluss Keys löschen
- **Monitoring:** Prüfe regelmäßig Tailscale Admin Panel

### 🔒 Auth Key Sicherheit

**NIEMALS:**
- Auth Keys in Git committen
- Auth Keys in Chat-Messages posten
- Auth Keys in Dokumentation hardcoden

**IMMER:**
- Keys in separaten Dateien (außerhalb Git)
- Keys in Password-Manager speichern
- Alte Keys widerrufen nach Verwendung

## Quick-Reference

```bash
# Setup durchführen
sudo bash scripts/setup-qs-vps.sh

# Tailscale-IP anzeigen
cat /root/tailscale-ip.txt

# SSH via Tailscale
ssh root@$(cat /root/tailscale-ip.txt)

# Logs prüfen
tail -f /var/log/qs-vps-setup.log

# Komponenten-Übersicht
ls -l scripts/qs/
```

## Cleanup (VPS entfernen)

Wenn du den QS-VPS nicht mehr brauchst:

```bash
# 1. Tailscale trennen (falls nicht ephemeral)
tailscale down

# 2. VPS bei IONOS löschen (via Cloud Panel)

# 3. Optional: Key widerrufen (falls nicht ephemeral)
# login.tailscale.com/admin/settings/keys
```

Bei Ephemeral Keys wird das Device automatisch aus Tailscale entfernt.

---

**Das war's!** Mit diesem One-Script-Setup hast du in 5 Minuten einen sicheren QS-VPS.
