# DevSystem VPS Vorbereitung

Dieses Verzeichnis enthält Skripte für die Vorbereitung des Ubuntu VPS für die DevSystem-Umgebung.

## Übersicht

Die VPS-Vorbereitung ist der erste Schritt beim Aufbau der DevSystem-Umgebung und umfasst:
- Systemaktualisierung
- Installation notwendiger Pakete
- Firewall-Konfiguration
- Grundlegende Systemhärtung gemäß Sicherheitskonzept

## Enthaltene Skripte

### 1. prepare-vps.sh

Hauptskript zur Vorbereitung des Ubuntu VPS. Es führt folgende Aktionen aus:
- Systemaktualisierung
- Installation notwendiger Pakete (curl, wget, git, etc.)
- Konfiguration der Firewall (UFW)
- Grundlegende Systemhärtung (SSH, Fail2Ban, Kernel-Parameter, etc.)

#### Verwendung

```bash
# Verbinde dich mit dem VPS über SSH
ssh root@ubuntu.tailcfea8a.ts.net

# Lade das Skript auf den Server
scp scripts/prepare-vps.sh root@ubuntu.tailcfea8a.ts.net:/root/

# Mache das Skript ausführbar
ssh root@ubuntu.tailcfea8a.ts.net "chmod +x /root/prepare-vps.sh"

# Führe das Skript aus
ssh root@ubuntu.tailcfea8a.ts.net "/root/prepare-vps.sh"
```

### 2. test-vps-preparation.sh

Skript zum Testen, ob die VPS-Vorbereitung erfolgreich war. Es überprüft:
- Systemupdates
- Installation notwendiger Pakete
- Firewall-Konfiguration
- SSH-Sicherheitseinstellungen
- Fail2Ban-Konfiguration
- Kernel-Sicherheitseinstellungen
- Logging und Audit

#### Verwendung

```bash
# Führe das Testskript lokal aus, um den VPS zu überprüfen
./scripts/test-vps-preparation.sh ubuntu.tailcfea8a.ts.net
```

## Voraussetzungen

- Ubuntu 22.04 LTS oder höher
- Root-Zugriff auf den VPS
- SSH-Schlüssel für den Zugriff auf den VPS
- Tailscale-Verbindung zum VPS

## Hinweise

- Alle Aktionen werden in einer Logdatei auf dem VPS protokolliert: `/var/log/devsystem-prepare-vps.log`
- Das Testskript erstellt eine lokale Logdatei: `vps-preparation-test.log`
- Nach erfolgreicher VPS-Vorbereitung kann mit der Installation von Tailscale fortgefahren werden

## Nächste Schritte

Nach erfolgreicher VPS-Vorbereitung folgen diese Schritte:
1. Installation und Konfiguration von Tailscale
2. Installation und Konfiguration von Caddy
3. Installation und Konfiguration von code-server

## Dokumentations-Tools

### pre-merge-check.sh

Validiert Dokumentations-Anforderungen vor Git-Merge.

**Verwendung:**

```bash
bash scripts/docs/pre-merge-check.sh
```

**Checks:**
- Branch-Referenzen in Dokumentation
- todo.md Timestamp-Aktualität
- CHANGELOG.md Updates
- TODOs/FIXMEs im Code
- Dokumentations-Updates bei Code-Änderungen
- Git Working Directory Status
- Merge-Konflikte mit main

**Exit Codes:**
- 0: Alle Checks bestanden
- 1: Checks fehlgeschlagen

## Git-Hooks für Dokumentations-Sync

### Setup
Installiere alle Dokumentations-Git-Hooks:

```bash
bash scripts/docs/setup-git-hooks.sh
```

### Post-Merge Hook
Zeigt nach jedem `git merge` einen Reminder zur Dokumentations-Aktualisierung.

**Features:**
- Checkliste für todo.md, CHANGELOG.md, Status-Reports
- Link zur Definition of Done
- Hinweis auf Pre-Merge-Check-Script

**Deaktivierung:**
```bash
rm .git/hooks/post-merge
```

**Re-Installation:**
```bash
bash scripts/docs/setup-git-hooks.sh
```

### Hook-Templates
Die Hook-Templates liegen in `scripts/docs/` und können angepasst werden:
- `post-merge-hook-template.sh` - Post-Merge Dokumentations-Reminder

Nach Änderungen am Template, Setup-Script erneut ausführen.