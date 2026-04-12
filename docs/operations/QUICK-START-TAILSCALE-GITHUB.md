# Quick Start: Tailscale für GitHub Actions einrichten

> **Ziel:** In 5 Minuten Tailscale für GitHub Actions konfigurieren

## 🚀 Ein-Befehl-Setup

```bash
./scripts/setup-tailscale-github-auth.sh
```

Das wars! Das Skript führt dich durch den gesamten Prozess.

## 📋 Was du brauchst

- ✅ GitHub CLI installiert (`gh`)
- ✅ Zugriff auf Tailscale Admin Console
- ✅ 5 Minuten Zeit

## 🎯 Schritte im Überblick

### 1. Setup-Skript starten

```bash
cd /root/work/DevSystem
./scripts/setup-tailscale-github-auth.sh
```

### 2. Methode wählen

Das Skript fragt:
```
Welche Methode möchtest du verwenden?
(1 für Auth Key, 2 für OAuth) [1]:
```

**Empfehlung:** Drücke **Enter** für Auth Key (Standard).

### 3. Im Browser autorisieren

Der Browser öffnet sich automatisch:
- Klicke auf **"Generate auth key"**
- Aktiviere: **Reusable**, **Ephemeral**, **Preauthorized**
- Setze **Expiry**: 90 days
- Klicke auf **"Generate key"**
- Kopiere den Key

### 4. Key ins Terminal einfügen

Zurück im Terminal:
- Füge den kopierten Key ein (wird nicht angezeigt)
- Drücke **Enter**

### 5. Fertig! 🎉

Das Skript:
- ✅ Setzt automatisch die GitHub Secrets
- ✅ Verifiziert die Konfiguration
- ✅ Zeigt Test-Anweisungen

## 🧪 Testen

```bash
# Workflow starten
gh workflow run deploy-qs-vps.yml

# Status überwachen
gh run watch
```

## 📖 Detaillierte Anleitung

Siehe [`TAILSCALE-GITHUB-SETUP-SIMPLIFIED.md`](TAILSCALE-GITHUB-SETUP-SIMPLIFIED.md) für:
- Hintergrundinfos zu Auth Key vs OAuth
- Manuelle Setup-Alternative
- Troubleshooting
- Wartung (Auth Key erneuern)

## ❓ Probleme?

### "Command 'gh' not found"

```bash
# GitHub CLI installieren
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
  sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
  sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh

# Authentifizieren
gh auth login
```

### "Workflow schlägt fehl"

```bash
# Logs ansehen
gh run view --log

# Setup erneut ausführen
./scripts/setup-tailscale-github-auth.sh
```

## 🔄 Auth Key erneuern (nach 90 Tagen)

```bash
# 1. Neuen Key generieren (Browser)
# https://login.tailscale.com/admin/settings/keys

# 2. Secret updaten
gh secret set TAILSCALE_OAUTH_SECRET --repo HaraldKiessling/DevSystem
# (Key einfügen)

# 3. Testen
gh workflow run deploy-qs-vps.yml
```

---

**Zeitaufwand:** ~5 Minuten  
**Schwierigkeit:** ⭐ Einfach  
**Häufigkeit:** Einmalig (+ alle 90 Tage Key erneuern)
