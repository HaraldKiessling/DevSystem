# Debug-Modus Regeln

## Systematisches Debugging

### 1. Problem reproduzieren
- Exakte Schritte dokumentieren
- Umgebungsbedingungen festhalten
- Fehlermeldungen vollständig kopieren

### 2. Logs analysieren
- Systemd-Services: `journalctl -u <service>`
- Caddy-Logs: `/var/log/caddy/`
- code-server-Logs: `~/.local/share/code-server/`
- Tailscale-Status: `tailscale status`

### 3. Hypothese bilden
- Mögliche Ursachen identifizieren
- Von wahrscheinlichster zu unwahrscheinlichster sortieren
- Dokumentieren für spätere Referenz

### 4. Testen
- Hypothese systematisch validieren/falsifizieren
- Nur eine Variable pro Test ändern
- Ergebnisse dokumentieren

### 5. Fix implementieren
- In separatem Branch entwickeln
- Atomare Commits
- Tests für Regression hinzufügen

### 6. Verifizieren
- E2E-Test nach Fix durchführen
- Sicherstellen, dass Problem gelöst ist
- Keine neuen Probleme eingeführt

## Log-Analyse

### Systemd-Services
```bash
# Service-Status prüfen
systemctl status <service>

# Logs anzeigen
journalctl -u <service> -n 100 --no-pager

# Logs in Echtzeit verfolgen
journalctl -u <service> -f

# Logs nach Fehler filtern
journalctl -u <service> -p err
```

### Caddy
```bash
# Caddy-Logs anzeigen
journalctl -u caddy -n 100

# Konfiguration testen
caddy validate --config /etc/caddy/Caddyfile

# Caddy neu laden
systemctl reload caddy
```

### code-server
```bash
# code-server-Logs
journalctl -u code-server -n 100

# Konfiguration prüfen
cat ~/.config/code-server/config.yaml

# Prozess prüfen
ps aux | grep code-server
```

### Tailscale
```bash
# Status anzeigen
tailscale status

# Verbindung testen
tailscale ping <hostname>

# Logs anzeigen
journalctl -u tailscaled -n 100
```

## Debugging-Tools

### Netzwerk
```bash
# Port-Belegung prüfen
netstat -tulpn | grep <port>
# oder
ss -tulpn | grep <port>

# HTTP-Verbindung testen
curl -v https://<hostname>

# DNS-Auflösung testen
nslookup <hostname>
dig <hostname>

# Firewall-Status
ufw status verbose
```

### Prozesse
```bash
# Prozesse anzeigen
ps aux | grep <name>

# Ressourcenverbrauch
top
htop

# Prozess-Details
systemctl status <service>
```

### Dateisystem
```bash
# Berechtigungen prüfen
ls -la <path>

# Disk-Usage
df -h
du -sh <directory>

# Datei-Inhalt prüfen
cat <file>
less <file>
tail -f <file>  # Echtzeit
```

### SSL/TLS
```bash
# Zertifikat prüfen
openssl s_client -connect <hostname>:443 -servername <hostname>

# Zertifikat-Details
openssl x509 -in <cert.pem> -text -noout

# Zertifikat-Gültigkeit
openssl x509 -in <cert.pem> -noout -dates
```

## Häufige Probleme und Lösungen

### Problem: Service startet nicht

**Debugging-Schritte**:
```bash
# 1. Status prüfen
systemctl status <service>

# 2. Logs analysieren
journalctl -u <service> -n 50

# 3. Konfiguration validieren
<service> --validate-config

# 4. Berechtigungen prüfen
ls -la /etc/<service>/
```

### Problem: Netzwerkverbindung fehlschlägt

**Debugging-Schritte**:
```bash
# 1. Port-Erreichbarkeit
telnet <host> <port>
nc -zv <host> <port>

# 2. Firewall prüfen
ufw status
iptables -L

# 3. DNS-Auflösung
nslookup <hostname>

# 4. Routing
traceroute <host>
```

### Problem: SSL-Zertifikat-Fehler

**Debugging-Schritte**:
```bash
# 1. Zertifikat prüfen
openssl s_client -connect <host>:443

# 2. Gültigkeit prüfen
openssl x509 -in <cert> -noout -dates

# 3. Caddy-Logs
journalctl -u caddy | grep -i cert

# 4. Tailscale-Zertifikate
tailscale cert <hostname>
```

## Fehlerbehandlung

### Prinzipien
- Fehler niemals ignorieren
- Root Cause Analysis durchführen
- Temporäre Workarounds dokumentieren
- Langfristige Lösung in todo.md aufnehmen

### Dokumentation
```markdown
## Bug-Report: [Titel]

### Symptom
[Was ist das beobachtbare Problem?]

### Reproduktion
1. Schritt 1
2. Schritt 2
3. Fehler tritt auf

### Logs
```
[Relevante Log-Ausgaben]
```

### Root Cause
[Was ist die eigentliche Ursache?]

### Workaround
[Temporäre Lösung]

### Langfristige Lösung
[Geplante dauerhafte Lösung]
```

## Sicherheits-Debugging

### Firewall
```bash
# UFW-Status
ufw status verbose

# Regeln auflisten
ufw show added

# Logs
tail -f /var/log/ufw.log
```

### Berechtigungen
```bash
# Datei-Berechtigungen
ls -la <file>

# Prozess-Benutzer
ps aux | grep <process>

# SELinux/AppArmor
aa-status  # AppArmor
```

### Authentifizierung
```bash
# SSH-Logs
tail -f /var/log/auth.log

# Failed login attempts
grep "Failed password" /var/log/auth.log

# Tailscale-Authentifizierung
tailscale status
```

## Performance-Debugging

### CPU
```bash
# CPU-Auslastung
top
htop

# Prozess-spezifisch
ps aux --sort=-%cpu | head
```

### Memory
```bash
# Speicherverbrauch
free -h

# Prozess-spezifisch
ps aux --sort=-%mem | head
```

### Disk I/O
```bash
# I/O-Statistiken
iostat -x 1

# Disk-Usage
df -h
du -sh /*
```

## Debug-Checkliste

- [ ] Problem ist reproduzierbar
- [ ] Logs wurden analysiert
- [ ] Hypothese wurde gebildet
- [ ] Tests wurden durchgeführt
- [ ] Root Cause wurde identifiziert
- [ ] Fix wurde implementiert
- [ ] E2E-Tests bestanden
- [ ] Dokumentation aktualisiert
- [ ] Keine Regression eingeführt
