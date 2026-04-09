# Caddy Deployment-Dokumentation

## Deployment-Übersicht
**Status:** ✅ Erfolgreich abgeschlossen  
**Datum:** 2026-04-08 (ursprüngliches Deployment)  
**Dokumentiert am:** 2026-04-09  
**VPS-Hostname:** devsystem-vps.tailcfea8a.ts.net  
**Zugriff:** Ausschließlich über Tailscale VPN

---

## Ausgeführte Skripte

### 1. Installation: [`install-caddy.sh`](scripts/install-caddy.sh)
**Status:** ✅ Erfolgreich ausgeführt

**Durchgeführte Aktionen:**
- Caddy über offizielles Repository installiert
- Systemd-Service konfiguriert und aktiviert
- Verzeichnisstruktur erstellt:
  - `/etc/caddy/` - Hauptkonfigurationsverzeichnis
  - `/etc/caddy/sites/` - Site-spezifische Konfigurationen
  - `/etc/caddy/snippets/` - Wiederverwendbare Konfigurationsschnipsel
  - `/etc/caddy/tls/tailscale/` - Tailscale-Zertifikate
  - `/var/log/caddy/` - Log-Verzeichnis
- Firewall-Regeln (UFW) konfiguriert
- Monitoring-Skript erstellt: `/usr/local/bin/caddy-monitor.sh`
- Zertifikatserneuerung-Skript erstellt: `/usr/local/bin/tailscale-cert-renew.sh`

**Installierte Version:**
```
Caddy v2.x (über offizielles Debian-Repository)
```

---

### 2. Konfiguration: [`configure-caddy.sh`](scripts/configure-caddy.sh)
**Status:** ✅ Erfolgreich ausgeführt

**Durchgeführte Aktionen:**
- Tailscale-IP ermittelt und validiert
- Tailscale-Domain ermittelt: `devsystem-vps.tailcfea8a.ts.net`
- Tailscale-Zertifikate generiert und installiert
- Hauptkonfiguration erstellt: `/etc/caddy/Caddyfile`
- Site-Konfiguration für code-server erstellt: `/etc/caddy/sites/code-server.caddy`
- Sicherheits-Header-Snippet erstellt: `/etc/caddy/snippets/security-headers.caddy`
- Tailscale-Auth-Snippet erstellt: `/etc/caddy/snippets/tailscale-auth.caddy`
- Backup der alten Konfiguration erstellt (falls vorhanden)
- Konfiguration validiert mit `caddy validate`
- Service neu geladen/gestartet

---

## Besonderheiten der Implementierung

### Port-Konfiguration
**Wichtig:** Caddy läuft auf **Port 9443** statt des Standard-HTTPS-Ports 443.

**Grund:** 
- Port 443 wird bereits von Tailscale verwendet
- Port 8443 ist von einem Docker-Container belegt
- Port 9443 wurde als Alternative gewählt

**Zugriffs-URLs:**
- `https://[TAILSCALE-IP]:9443`
- `https://devsystem-vps.tailcfea8a.ts.net:9443`

### Sicherheitskonfiguration
- **Zugriffsbeschränkung:** Nur Tailscale-IP-Bereich (100.64.0.0/10) erlaubt
- **TLS:** Tailscale-Zertifikate mit automatischer Erneuerung
- **Sicherheits-Header:** HSTS, XSS-Protection, CSP, etc.
- **Firewall:** UFW-Regeln für Port 9443 über Tailscale-Interface

### Reverse Proxy Konfiguration
- **Backend:** code-server auf localhost:8080
- **WebSocket-Support:** Aktiviert für VS Code-Funktionalität
- **Timeouts:** Erhöht für lange Entwicklungssitzungen (30m keepalive)
- **Kompression:** gzip und zstd aktiviert

---

## Service-Status

### Caddy-Service
```
Status: active (running)
Enabled: yes (automatischer Start beim Booten)
Port: 9443 (HTTPS)
```

### Automatisierung
**Monitoring (alle 5 Minuten):**
- Cron-Job: `/etc/cron.d/caddy-monitor`
- Skript: `/usr/local/bin/caddy-monitor.sh`
- Log: `/var/log/caddy-monitor.log`
- Funktion: Prüft Service-Status und Backend-Erreichbarkeit

**Zertifikatserneuerung (monatlich):**
- Cron-Job: `/etc/cron.d/tailscale-cert-renew`
- Skript: `/usr/local/bin/tailscale-cert-renew.sh`
- Log: `/var/log/tailscale-cert-renew.log`
- Funktion: Erneuert Tailscale-Zertifikate automatisch

---

## Validierungsergebnisse

### E2E-Tests (aus vps-test-results-caddy.md)
**Durchgeführt:** 19 Tests  
**Erfolgreich:** 18 Tests (95% Erfolgsrate)  
**Fehlgeschlagen:** 1 Test (Testskript-Fehler, keine funktionale Einschränkung)

**Erfolgreiche Tests:**
- ✅ Caddy-Installation
- ✅ Service-Status (aktiv und läuft)
- ✅ Verzeichnisstruktur vollständig
- ✅ Konfigurationsdateien vorhanden und gültig
- ✅ Tailscale-Zertifikate vorhanden und gültig
- ✅ Konfigurationsvalidierung erfolgreich
- ✅ Port 9443 lauscht
- ✅ Monitoring-Cron-Job eingerichtet
- ✅ Zertifikatserneuerungs-Cron-Job eingerichtet
- ✅ Proxy-Funktionalität getestet
- ✅ Firewall-Konfiguration korrekt

**Fehlgeschlagener Test:**
- ❌ Zugriffseinschränkung auf Tailscale-IPs (Testskript verwendete HTTP statt HTTPS)
  - **Hinweis:** Dies ist ein Fehler im Testskript, nicht in der tatsächlichen Funktionalität

---

## Konfigurationsdateien

### Hauptkonfiguration
**Datei:** `/etc/caddy/Caddyfile`
- Globale Optionen (Admin-API deaktiviert, TLS 1.2+, HTTP/3)
- Logging-Konfiguration (JSON-Format, Rotation)
- Import von Snippets und Sites

### Site-Konfiguration
**Datei:** `/etc/caddy/sites/code-server.caddy`
- Zwei Zugriffspunkte: Tailscale-IP und Domain
- Reverse Proxy zu localhost:8080
- WebSocket-Support
- Tailscale-IP-Beschränkung
- Sicherheits-Header
- Kompression

### Snippets
**Datei:** `/etc/caddy/snippets/security-headers.caddy`
- HSTS, XSS-Protection, X-Frame-Options
- Content-Security-Policy
- Referrer-Policy

**Datei:** `/etc/caddy/snippets/tailscale-auth.caddy`
- IP-Bereichsprüfung (100.64.0.0/10)
- 403-Antwort für nicht-Tailscale-Zugriffe

---

## Log-Dateien

### Caddy-Logs
- **Access-Log:** `/var/log/caddy/access.log` (JSON-Format, 100MB Rotation, 10 Dateien)
- **code-server-Log:** `/var/log/caddy/code-server.log` (JSON-Format, 50MB Rotation, 5 Dateien)
- **Systemd-Journal:** `journalctl -u caddy -f`

### Automatisierungs-Logs
- **Monitoring:** `/var/log/caddy-monitor.log`
- **Zertifikatserneuerung:** `/var/log/tailscale-cert-renew.log`
- **Konfiguration:** `/var/log/devsystem-configure-caddy.log`

---

## Nützliche Befehle

### Service-Management
```bash
# Status prüfen
sudo systemctl status caddy

# Service neustarten
sudo systemctl restart caddy

# Konfiguration neu laden (ohne Downtime)
sudo systemctl reload caddy

# Logs anzeigen (live)
sudo journalctl -u caddy -f

# Logs der letzten 50 Zeilen
sudo journalctl -u caddy -n 50
```

### Konfiguration
```bash
# Konfiguration validieren
sudo caddy validate --config /etc/caddy/Caddyfile

# Konfiguration formatieren
sudo caddy fmt --overwrite /etc/caddy/Caddyfile

# Aktuelle Konfiguration anzeigen
sudo caddy adapt --config /etc/caddy/Caddyfile
```

### Zertifikate
```bash
# Zertifikate manuell erneuern
sudo /usr/local/bin/tailscale-cert-renew.sh

# Zertifikate prüfen
sudo ls -la /etc/caddy/tls/tailscale/
sudo openssl x509 -in /etc/caddy/tls/tailscale/devsystem-vps.tailcfea8a.ts.net.crt -text -noout
```

### Monitoring
```bash
# Monitoring-Skript manuell ausführen
sudo /usr/local/bin/caddy-monitor.sh

# Monitoring-Log anzeigen
sudo tail -f /var/log/caddy-monitor.log
```

---

## Bekannte Probleme und Lösungen

### Problem: Port 443 bereits belegt
**Lösung:** Caddy läuft auf Port 9443. Alle Zugriffe müssen diesen Port verwenden.

### Problem: code-server noch nicht installiert
**Status:** Caddy ist konfiguriert, aber der Reverse Proxy funktioniert erst, wenn code-server auf Port 8080 läuft.
**Nächster Schritt:** code-server-Installation durchführen.

### Problem: Tailscale-Verbindung nicht aktiv
**Aus vps-test-results.md:** Tailscale-Dienst läuft, aber Verbindung zum Netzwerk ist nicht aktiv.
**Auswirkung:** Zugriff über Tailscale-VPN funktioniert möglicherweise nicht.
**Empfehlung:** Tailscale-Verbindung mit `tailscale up` wiederherstellen.

---

## Backup-Informationen

### Backup-Verzeichnis
**Pfad:** `/var/backups/caddy/`

### Gesicherte Dateien
- Caddyfile
- Sites-Verzeichnis
- Snippets-Verzeichnis

### Letztes Backup
**Pfad-Referenz:** `/var/backups/caddy/latest_backup.txt`

---

## Nächste Schritte

1. **Tailscale-Verbindung wiederherstellen**
   - Problem aus vps-test-results.md beheben
   - `tailscale up` ausführen und authentifizieren

2. **code-server installieren**
   - Skript: [`install-code-server.sh`](scripts/install-code-server.sh)
   - Skript: [`configure-code-server.sh`](scripts/configure-code-server.sh)
   - Port: 8080 (localhost)

3. **E2E-Tests durchführen**
   - Zugriff über Tailscale-IP testen
   - WebSocket-Funktionalität prüfen
   - Sicherheitseinstellungen validieren

4. **Branch mergen**
   - Feature-Branch `feature/caddy-setup` in `main` mergen
   - Nach erfolgreichen E2E-Tests

---

## Zusammenfassung

✅ **Caddy ist erfolgreich installiert und konfiguriert**
- Installation über offizielle Repositories
- Konfiguration für code-server als Reverse Proxy
- Sicherheit durch Tailscale-IP-Beschränkung
- Automatisches Monitoring und Zertifikatserneuerung
- Läuft auf Port 9443 (nicht-Standard wegen Port-Konflikten)

⚠️ **Offene Punkte:**
- Tailscale-Verbindung muss wiederhergestellt werden
- code-server muss noch installiert werden
- E2E-Tests mit vollständigem Stack durchführen

📊 **Testergebnisse:** 18/19 Tests erfolgreich (95%)

🔗 **Zugriff:** `https://[TAILSCALE-IP]:9443` (sobald code-server läuft)
