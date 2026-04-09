ist das THW# QS-VPS Cloud-Init Anleitung

**Version:** 1.0  
**Datum:** 2026-04-09  
**Autor:** DevSystem Team

## Übersicht

Diese Anleitung beschreibt die Verwendung des Cloud-Init Scripts [`qs-vps-cloud-init.yaml`](qs-vps-cloud-init.yaml) zur automatischen Einrichtung eines Quality-Server (QS) VPS mit Tailscale-Integration bei IONOS.

## Was macht das Cloud-Init Script?

Das Script automatisiert die komplette VPS-Einrichtung:

- ✅ **System-Updates:** Vollständige Aktualisierung des Ubuntu-Systems
- ✅ **Tailscale-Installation:** Installation über offizielles Repository
- ✅ **Tailscale-Konfiguration:** Automatische Verbindung zum Tailscale-Netzwerk
- ✅ **Hostname:** Setzt den Hostname auf `devsystem-qs-vps`
- ✅ **UFW Firewall:** SSH nur über Tailscale erlaubt, Port 22 von außen blockiert
- ✅ **Fail2ban:** Schutz vor Brute-Force-Angriffen
- ✅ **Audit-System:** Erweiterte Systemüberwachung
- ✅ **Sicherheitshärtung:** Kernel-Parameter und automatische Sicherheitsupdates
- ✅ **Logging:** Detaillierte Protokollierung aller Schritte

## Tailscale Auth Key - Zwei Optionen

Vor der Verwendung des Scripts muss ein Tailscale Auth Key generiert werden. Es gibt zwei Arten von Keys:

### Option 1: Ephemeral Key (Einmalig verwendbar)

**Was ist das?**
Ein Key, der automatisch gelöscht wird, wenn das Gerät sich vom Tailscale-Netzwerk trennt.

**Vorteile:**
- ✅ Höhere Sicherheit - Key wird automatisch ungültig
- ✅ Kein dauerhafter Key im Script nach der Installation
- ✅ Gerät wird automatisch aus dem Netzwerk entfernt bei Löschung

**Nachteile:**
- ❌ Nur einmal verwendbar
- ❌ Bei VPS-Neuinstallation wird neuer Key benötigt
- ❌ Gerät verschwindet aus Admin-Panel bei Ausfall

**Best Practice für:**
- Produktions-Server mit stabiler Konfiguration
- Einmalige, dauerhafte Setups
- Server, die nicht oft neu installiert werden

**Generierung:**
1. Öffne [Tailscale Admin Panel](https://login.tailscale.com/admin/settings/keys)
2. Klicke auf **"Generate auth key"**
3. Setze folgende Optionen:
   - ✅ **Reusable:** NEIN (nicht aktivieren)
   - ✅ **Ephemeral:** JA (aktivieren)
   - Optional: **Tags** hinzufügen (z.B. `tag:qs-vps`)
4. Optional: **Expiry** auf kurze Zeit setzen (z.B. 1 Stunde)
5. Klicke auf **"Generate key"**
6. Kopiere den generierten Key (beginnt mit `tskey-auth-`)

### Option 2: Reusable Key (Wiederverwendbar)

**Was ist das?**
Ein Key, der mehrfach verwendet werden kann, mit optionalem Ablaufdatum.

**Vorteile:**
- ✅ Kann für mehrere VPS-Installationen verwendet werden
- ✅ Bei Neuinstallation wiederverwendbar
- ✅ Praktisch für Test- und QS-Umgebungen
- ✅ Gerät bleibt im Admin-Panel sichtbar

**Nachteile:**
- ❌ Wenn kompromittiert, könnten mehrere Systeme betroffen sein
- ❌ Muss manuell aus dem Netzwerk entfernt werden
- ❌ Sicherheitsrisiko bei längerer Gültigkeit

**Best Practice für:**
- Test-/QS-Umgebungen (wie dieser VPS)
- Automatisierte Deployments
- Umgebungen, die häufig neu aufgesetzt werden
- Entwicklungs-Server

**Generierung:**
1. Öffne [Tailscale Admin Panel](https://login.tailscale.com/admin/settings/keys)
2. Klicke auf **"Generate auth key"**
3. Setze folgende Optionen:
   - ✅ **Reusable:** JA (aktivieren)
   - ❌ **Ephemeral:** NEIN (nicht aktivieren)
   - Optional: **Tags** hinzufügen (z.B. `tag:qs-vps`)
4. Setze **Expiry:** 90 Tage (empfohlen für QS-VPS)
5. Klicke auf **"Generate key"**
6. Kopiere den generierten Key (beginnt mit `tskey-auth-`)

### 🎯 Empfehlung für QS-VPS

**Verwende einen Reusable Key mit 90 Tagen Ablaufdatum**

**Begründung:**
- Der QS-VPS ist eine Test-/Quality-Umgebung
- Wird möglicherweise mehrfach neu aufgesetzt
- 90 Tage bieten gute Balance zwischen Sicherheit und Wiederverwendbarkeit
- Key kann bei Bedarf widerrufen werden
- Nach 90 Tagen wird automatisch ein neuer Key benötigt

## Schritt-für-Schritt Anleitung

### Schritt 1: Tailscale Auth Key generieren

1. Gehe zum [Tailscale Admin Panel](https://login.tailscale.com/admin/settings/keys)
2. Generiere einen **Reusable Key** mit 90 Tagen Ablaufdatum (siehe oben)
3. Kopiere den generierten Key (z.B. `tskey-auth-k1234567890abcdef-abcdefghijklmnop`)
4. ⚠️ **WICHTIG:** Bewahre den Key sicher auf (z.B. in einem Passwort-Manager)

### Schritt 2: Cloud-Init Script anpassen

1. Öffne die Datei [`qs-vps-cloud-init.yaml`](qs-vps-cloud-init.yaml)
2. Suche nach der Zeile mit `YOUR_TAILSCALE_AUTH_KEY_HERE`
3. Ersetze den Platzhalter mit deinem Tailscale Auth Key:

```yaml
# Vorher:
TAILSCALE_AUTH_KEY="YOUR_TAILSCALE_AUTH_KEY_HERE"

# Nachher:
TAILSCALE_AUTH_KEY="tskey-auth-k1234567890abcdef-abcdefghijklmnop"
```

4. Speichere die Datei

### Schritt 3: VPS bei IONOS bestellen

1. Logge dich in dein [IONOS-Konto](https://www.ionos.de/) ein
2. Navigiere zu **Server & Cloud** → **VPS**
3. Wähle einen passenden VPS-Tarif:
   - **Empfehlung für QS-VPS:** VPS Linux L oder höher
   - **Mindestanforderungen:** 2 vCPU, 4 GB RAM, 80 GB SSD
4. Wähle **Ubuntu 22.04 LTS** oder **Ubuntu 24.04 LTS** als Betriebssystem

### Schritt 4: Cloud-Init Script hinterlegen

1. Im IONOS-Bestellprozess unter **"Erweiterte Einstellungen"** oder **"Cloud-Init"**
2. Option **"Cloud-Init aktivieren"** oder **"Benutzerdefiniertes Script"** auswählen
3. Kopiere den **kompletten Inhalt** der Datei `qs-vps-cloud-init.yaml`
4. Füge den Inhalt in das Cloud-Init-Eingabefeld ein
5. ⚠️ **Wichtig:** Stelle sicher, dass die erste Zeile `#cloud-config` ist
6. Bestätige und schließe die Bestellung ab

### Schritt 5: VPS-Start und Initialisierung

1. Warte 5-10 Minuten nach VPS-Bestellung
2. Das Cloud-Init Script wird automatisch beim ersten Boot ausgeführt
3. Die Installation läuft im Hintergrund und kann 10-15 Minuten dauern
4. ⚠️ **Nicht unterbrechen:** Warte, bis die Installation abgeschlossen ist

### Schritt 6: Tailscale-IP abrufen

**Option A: Über Tailscale Admin Panel (empfohlen)**
1. Öffne [Tailscale Admin Panel](https://login.tailscale.com/admin/machines)
2. Suche nach `devsystem-qs-vps` in der Geräteliste
3. Notiere die Tailscale-IP (z.B. `100.64.0.10`)

**Option B: Über IONOS-Console (Fallback)**
1. Logge dich in IONOS-Console ein
2. Navigiere zu Server & Cloud → VPS → [Dein VPS]
3. Klicke auf **"Console"** oder **"KVM-Zugriff"**
4. Logge dich als `root` ein (Passwort wurde per E-Mail gesendet)
5. Führe aus: `cat /root/tailscale-ip.txt`
6. Die Tailscale-IP wird angezeigt

### Schritt 7: SSH-Verbindung testen

1. Stelle sicher, dass dein lokales Gerät im Tailscale-Netzwerk ist
2. Öffne ein Terminal
3. Verbinde dich via SSH:

```bash
ssh root@100.64.0.10
# Ersetze 100.64.0.10 mit der tatsächlichen Tailscale-IP
```

4. Bei erfolgreicher Verbindung solltest du eingeloggt sein

### Schritt 8: Installation verifizieren

Nach dem Login führe folgende Befehle aus:

```bash
# 1. Hostname prüfen
hostname
# Sollte ausgeben: devsystem-qs-vps

# 2. Tailscale-Status prüfen
tailscale status
# Sollte zeigen: "online" und verbundene Geräte

# 3. UFW-Firewall prüfen
ufw status verbose
# Sollte zeigen: Status: active und SSH nur über tailscale0

# 4. Fail2ban prüfen
systemctl status fail2ban
# Sollte zeigen: active (running)

# 5. Cloud-Init Logs prüfen
cat /var/log/cloud-init-output.log
# Sollte keine ERRORS zeigen, nur SUCCESS-Meldungen

# 6. Tailscale Setup Log prüfen
cat /var/log/tailscale-setup.log
# Sollte "Tailscale successfully connected!" zeigen

# 7. Firewall Setup Log prüfen
cat /var/log/ufw-setup.log
# Sollte "Firewall setup completed successfully" zeigen
```

## Sicherheitshinweise

### 🔒 Kritische Sicherheitsfeatures

1. **SSH nur über Tailscale:**
   - Standard SSH Port 22 ist von außen NICHT erreichbar
   - SSH-Zugriff NUR über Tailscale-VPN (verschlüsselt)
   - Öffentliche IP erlaubt KEINE SSH-Verbindungen

2. **Firewall-Konfiguration:**
   - UFW mit `default deny incoming` aktiviert
   - Nur Tailscale-Interface (`tailscale0`) erlaubt eingehende Verbindungen
   - Tailscale UDP-Port 41641 für Koordination offen

3. **Fail2ban:**
   - Automatischer Schutz vor Brute-Force-Angriffen
   - 5 Fehlversuche in 10 Minuten = 1 Stunde gesperrt
   - Logs unter: `/var/log/fail2ban.log`

4. **Kernel-Härtung:**
   - IP Spoofing Protection aktiviert
   - SYN Flood Protection aktiviert
   - Source Routing deaktiviert

5. **Audit-System:**
   - Überwachung kritischer Systemdateien
   - Protokollierung von Benutzeränderungen
   - Logs unter: `/var/log/audit/audit.log`

6. **Automatische Sicherheitsupdates:**
   - Ubuntu Security-Updates werden automatisch installiert
   - Konfiguration: `/etc/apt/apt.conf.d/50unattended-upgrades`

### ⚠️ Wichtige Warnungen

1. **Auth Key Sicherheit:**
   - Teile deinen Tailscale Auth Key NIEMALS öffentlich
   - Speichere ihn NICHT in Git-Repositories
   - Widerrufe alte Keys nach Verwendung

2. **Console-Zugriff:**
   - IONOS KVM-Console funktioniert weiterhin als Fallback
   - Nutze sie nur im Notfall (wenn Tailscale ausfällt)
   - Normale Verwaltung sollte über Tailscale erfolgen

3. **Firewall-Änderungen:**
   - Sei SEHR vorsichtig bei UFW-Änderungen
   - Du kannst dich aussperren, wenn du `ufw deny in on tailscale0` ausführst
   - Teste Änderungen immer mit offener Console-Verbindung

4. **Tailscale-Ausfall:**
   - Bei Tailscale-Ausfall ist SSH NICHT erreichbar
   - Nutze IONOS Console als Fallback
   - Prüfe Tailscale-Status regelmäßig

## Validierung nach VPS-Start

### Automatische Validierung (empfohlen)

Führe dieses Validierungs-Script aus:

```bash
#!/bin/bash
# QS-VPS Validierungs-Script
# Speichere als: validate-qs-vps.sh

echo "========================================="
echo "QS-VPS Installation Validation"
echo "========================================="
echo ""

# 1. Hostname
echo "1. Checking hostname..."
HOSTNAME=$(hostname)
if [ "$HOSTNAME" = "devsystem-qs-vps" ]; then
    echo "   ✓ Hostname correct: $HOSTNAME"
else
    echo "   ✗ Hostname incorrect: $HOSTNAME (expected: devsystem-qs-vps)"
fi
echo ""

# 2. Tailscale
echo "2. Checking Tailscale..."
if systemctl is-active --quiet tailscaled; then
    echo "   ✓ Tailscale daemon running"
    TS_IP=$(tailscale ip -4 2>/dev/null)
    if [ -n "$TS_IP" ]; then
        echo "   ✓ Tailscale connected: $TS_IP"
    else
        echo "   ✗ Tailscale not connected"
    fi
else
    echo "   ✗ Tailscale daemon not running"
fi
echo ""

# 3. UFW Firewall
echo "3. Checking UFW firewall..."
if ufw status | grep -q "Status: active"; then
    echo "   ✓ UFW active"
    if ufw status | grep -q "tailscale0"; then
        echo "   ✓ Tailscale interface allowed"
    else
        echo "   ✗ Tailscale interface not configured"
    fi
else
    echo "   ✗ UFW not active"
fi
echo ""

# 4. Fail2ban
echo "4. Checking Fail2ban..."
if systemctl is-active --quiet fail2ban; then
    echo "   ✓ Fail2ban running"
else
    echo "   ✗ Fail2ban not running"
fi
echo ""

# 5. Audit System
echo "5. Checking Audit system..."
if systemctl is-active --quiet auditd; then
    echo "   ✓ Auditd running"
else
    echo "   ✗ Auditd not running"
fi
echo ""

# 6. Cloud-Init Logs
echo "6. Checking Cloud-Init logs..."
if grep -q "Cloud-Init Setup Completed" /var/log/cloud-init-output.log 2>/dev/null; then
    echo "   ✓ Cloud-Init completed successfully"
else
    echo "   ✗ Cloud-Init may not have completed"
fi
echo ""

echo "========================================="
echo "Validation Complete"
echo "========================================="
echo ""
echo "For detailed logs, check:"
echo "  - /var/log/cloud-init-output.log"
echo "  - /var/log/tailscale-setup.log"
echo "  - /var/log/ufw-setup.log"
echo ""
```

Ausführung:
```bash
bash validate-qs-vps.sh
```

### Manuelle Validierung

Schritt-für-Schritt manuelle Prüfung:

```bash
# 1. System-Info
echo "=== SYSTEM INFO ==="
cat /etc/os-release
uname -a
echo ""

# 2. Hostname
echo "=== HOSTNAME ==="
hostname
hostnamectl
echo ""

# 3. Tailscale
echo "=== TAILSCALE ==="
tailscale version
tailscale status
tailscale netcheck
echo ""

# 4. Netzwerk-Interfaces
echo "=== NETWORK INTERFACES ==="
ip addr show tailscale0
echo ""

# 5. UFW Status
echo "=== FIREWALL (UFW) ==="
ufw status verbose
echo ""

# 6. Fail2ban Status
echo "=== FAIL2BAN ==="
systemctl status fail2ban --no-pager
fail2ban-client status
echo ""

# 7. Audit Status
echo "=== AUDIT SYSTEM ==="
systemctl status auditd --no-pager
echo ""

# 8. Sicherheitsparameter
echo "=== SECURITY PARAMETERS ==="
sysctl net.ipv4.tcp_syncookies
sysctl net.ipv4.conf.all.rp_filter
echo ""

# 9. Logs prüfen
echo "=== LOGS SUMMARY ==="
echo "Cloud-Init status:"
tail -n 20 /var/log/cloud-init-output.log | grep -E "(ERROR|SUCCESS|Complete)"
echo ""
echo "Tailscale setup:"
cat /var/log/tailscale-setup.log
echo ""
echo "UFW setup:"
cat /var/log/ufw-setup.log
echo ""
```

### Erwartete Ausgabe bei erfolgreicher Installation:

```
✓ Hostname: devsystem-qs-vps
✓ Tailscale: connected mit IP 100.64.x.x
✓ UFW: active mit Regeln für tailscale0
✓ Fail2ban: active (running)
✓ Auditd: active (running)
✓ Cloud-Init: Setup Completed
✓ SSH: Nur über Tailscale erreichbar
```

## Fehlerbehebung

### Problem: Tailscale verbindet sich nicht

**Symptom:** `tailscale status` zeigt "Not connected" oder Fehler

**Lösung:**
```bash
# 1. Tailscale-Logs prüfen
journalctl -u tailscaled -n 50

# 2. Tailscale neu starten
systemctl restart tailscaled
sleep 5

# 3. Manuell verbinden (mit neuem Auth Key)
tailscale up --authkey="dein-neuer-auth-key" --hostname="devsystem-qs-vps" --ssh

# 4. Firewall prüfen
ufw status verbose
```

### Problem: SSH-Verbindung schlägt fehl

**Symptom:** `ssh root@<tailscale-ip>` gibt Timeout oder "Connection refused"

**Lösung:**
```bash
# Über IONOS Console einloggen, dann:

# 1. Prüfe ob Tailscale läuft
systemctl status tailscaled
tailscale status

# 2. Prüfe UFW-Regeln
ufw status verbose
# SSH sollte auf tailscale0 erlaubt sein

# 3. Prüfe ob SSH-Dienst läuft
systemctl status sshd

# 4. Prüfe Tailscale-Interface
ip addr show tailscale0
```

### Problem: UFW blockiert Tailscale-Zugriff

**Symptom:** Nach UFW-Aktivierung ist SSH nicht mehr erreichbar

**Lösung (NUR über IONOS Console!):**
```bash
# WARNUNG: Dies setzt die Firewall zurück!

# 1. UFW deaktivieren
ufw disable

# 2. UFW zurücksetzen
ufw --force reset

# 3. Korrekt neu konfigurieren
ufw default deny incoming
ufw default allow outgoing
ufw allow in on tailscale0
ufw allow 41641/udp

# 4. UFW aktivieren
echo "y" | ufw enable

# 5. Status prüfen
ufw status verbose
```

### Problem: Auth Key ungültig

**Symptom:** Tailscale-Setup zeigt "Auth key expired" oder "Invalid auth key"

**Lösung:**
```bash
# 1. Generiere neuen Auth Key im Tailscale Admin Panel
# 2. Verbinde manuell:

tailscale up --authkey="dein-neuer-auth-key" --hostname="devsystem-qs-vps" --ssh

# 3. Für zukünftige Deployments: Auth Key im Cloud-Init Script aktualisieren
```

### Problem: Cloud-Init Script wurde nicht ausgeführt

**Symptom:** Hostname ist falsch, Tailscale nicht installiert

**Lösung:**
```bash
# 1. Cloud-Init Status prüfen
cloud-init status

# 2. Cloud-Init Logs prüfen
cat /var/log/cloud-init-output.log
cat /var/log/cloud-init.log

# 3. Falls Script nicht lief: Manuell ausführen ist NICHT empfohlen
# Besser: VPS neu installieren mit korrektem Cloud-Init Script
```

## Nächste Schritte nach erfolgreicher Installation

Nach erfolgreicher QS-VPS-Installation:

1. **Weitere DevSystem-Komponenten installieren:**
   - Caddy (Reverse Proxy)
   - code-server (VS Code im Browser)
   - Ollama (Lokale KI)

2. **Automatisierung:**
   - Erstelle Deployment-Scripts für Anwendungen
   - Richte CI/CD für QS-Tests ein

3. **Monitoring:**
   - Richte Tailscale MagicDNS ein
   - Konfiguriere Logging/Monitoring

4. **Backup:**
   - Erstelle VPS-Snapshot bei IONOS
   - Richte automatische Backups ein

## Support und Dokumentation

- **Tailscale Dokumentation:** https://tailscale.com/kb/
- **Cloud-Init Dokumentation:** https://cloudinit.readthedocs.io/
- **Ubuntu UFW Guide:** https://help.ubuntu.com/community/UFW
- **IONOS VPS Hilfe:** https://www.ionos.de/hilfe/

## Änderungshistorie

| Version | Datum | Änderungen |
|---------|-------|------------|
| 1.0 | 2026-04-09 | Initiale Version mit Tailscale-Integration und vollständiger Dokumentation |

---

**Erstellt für:** DevSystem QS-VPS Automatisierung  
**Maintainer:** DevSystem Team  
**Lizenz:** Interner Gebrauch
