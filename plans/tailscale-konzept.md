# Tailscale-Konfigurationskonzept für DevSystem

Dieses Dokument beschreibt die Installation, Konfiguration und Integration von Tailscale als VPN-Lösung für das DevSystem-Projekt. Tailscale wird als primäre Netzwerksicherheitskomponente eingesetzt, um einen sicheren, privaten Zugriff auf die Entwicklungsumgebung zu gewährleisten.

## 1. Installation und Einrichtung von Tailscale auf dem Ubuntu VPS

### 1.1 Installationsschritte

```bash
# Aktualisieren der Paketlisten
sudo apt-get update

# Installation der erforderlichen Abhängigkeiten
sudo apt-get install -y curl apt-transport-https

# Hinzufügen des Tailscale-Repositorys
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.gpg | sudo apt-key add -
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.list | sudo tee /etc/apt/sources.list.d/tailscale.list

# Aktualisieren der Paketlisten mit dem neuen Repository
sudo apt-get update

# Installation von Tailscale
sudo apt-get install -y tailscale

# Starten des Tailscale-Dienstes
sudo systemctl start tailscale
```

### 1.2 Authentifizierung und Autorisierung

```bash
# Initialisierung von Tailscale und Authentifizierung
sudo tailscale up

# Optional: Spezifische Konfigurationsoptionen bei der Initialisierung
# sudo tailscale up --hostname="devsystem-vps" --advertise-routes=10.0.0.0/24
```

Nach Ausführung des `tailscale up`-Befehls wird ein Authentifizierungslink generiert. Dieser Link muss in einem Browser geöffnet werden, um den VPS mit dem Tailscale-Konto zu verknüpfen. Die Authentifizierung erfolgt über den Tailscale-Dienst und unterstützt verschiedene Identity Provider (Google, Microsoft, GitHub, etc.).

### 1.3 Konfiguration für automatischen Start

```bash
# Aktivieren des Tailscale-Dienstes beim Systemstart
sudo systemctl enable tailscale

# Überprüfen des Dienststatus
sudo systemctl status tailscale
```

### 1.4 Konfigurationsdatei

Die Hauptkonfigurationsdatei für Tailscale befindet sich unter `/etc/tailscale/tailscaled.defaults`. Hier können grundlegende Einstellungen angepasst werden:

```bash
# Beispiel für eine angepasste Konfiguration
sudo cat > /etc/tailscale/tailscaled.defaults << EOF
# Tailscale Defaults für DevSystem
TS_STATE_DIR=/var/lib/tailscale
TS_SOCKET=/var/run/tailscale/tailscaled.sock
TS_PORT=41641
EOF
```

## 2. Netzwerksicherheit

### 2.1 Zero-Trust-Zugriff

Tailscale implementiert ein Zero-Trust-Netzwerkmodell, bei dem jeder Zugriff explizit autorisiert werden muss:

- **Identitätsbasierte Authentifizierung**: Jeder Benutzer und jedes Gerät wird eindeutig identifiziert und authentifiziert.
- **Least-Privilege-Prinzip**: Standardmäßig hat kein Gerät Zugriff auf andere Geräte im Tailnet, bis dies explizit erlaubt wird.
- **Verschlüsselte Kommunikation**: Sämtlicher Datenverkehr zwischen Geräten im Tailnet wird Ende-zu-Ende verschlüsselt.

### 2.2 Zugriffskontrollen und ACLs

Tailscale verwendet Access Control Lists (ACLs), um den Zugriff zwischen Geräten im Tailnet zu steuern. Die ACLs werden in der Tailscale-Admin-Konsole konfiguriert und als JSON-Datei definiert:

```json
{
  "acls": [
    {
      "action": "accept",
      "users": ["user@example.com"],
      "ports": ["*:*"]
    }
  ],
  "tagOwners": {
    "tag:server": ["user@example.com"],
  },
  "hosts": {
    "devsystem-vps": "100.x.y.z",
  }
}
```

Für das DevSystem-Projekt empfehlen wir folgende ACL-Struktur:

1. **Admin-Gruppe**: Vollzugriff auf alle Dienste und Ports des VPS
2. **Entwickler-Gruppe**: Zugriff auf spezifische Dienste (code-server, SSH)
3. **Monitoring-Gruppe**: Zugriff auf Monitoring-Ports und -Dienste

### 2.3 Firewall-Konfiguration

Die Ubuntu-Firewall (UFW) sollte so konfiguriert werden, dass sie nur Verbindungen über Tailscale und lokale Verbindungen zulässt:

```bash
# Firewall zurücksetzen und standardmäßig eingehende Verbindungen blockieren
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Lokale Verbindungen erlauben
sudo ufw allow from 127.0.0.1

# SSH nur über Tailscale erlauben (optional: für Notfallzugriff auch direkt)
sudo ufw allow in on tailscale0

# Tailscale-Schnittstelle erlauben
sudo ufw allow in on tailscale0 to any port 22 proto tcp
sudo ufw allow in on tailscale0 to any port 80,443 proto tcp

# Tailscale UDP-Port für die Verbindung zum Koordinationsserver
sudo ufw allow 41641/udp

# Firewall aktivieren
sudo ufw enable
```

## 3. Integration mit anderen Komponenten

### 3.1 Verbindung zu Caddy (Reverse Proxy)

Caddy wird als Reverse Proxy für die Dienste im DevSystem eingesetzt. Die Integration mit Tailscale erfolgt über die Konfiguration von Caddy, um nur Anfragen von der Tailscale-Schnittstelle zu akzeptieren:

```
{
  # Globale Caddy-Einstellungen
  admin off
}

# code-server über Tailscale
code.devsystem.internal {
  # Nur Zugriff über Tailscale erlauben
  @tailscale {
    remote_ip 100.64.0.0/10
  }
  reverse_proxy @tailscale localhost:8080
}
```

### 3.2 Zertifikatsmanagement für HTTPS

Tailscale bietet eine integrierte PKI (Public Key Infrastructure), die für die sichere Kommunikation zwischen Geräten im Tailnet verwendet werden kann. Für HTTPS-Verbindungen zu Diensten im DevSystem gibt es zwei Optionen:

#### Option 1: Tailscale-Zertifikate

Tailscale kann automatisch TLS-Zertifikate für Domains im Tailnet ausstellen:

```bash
# Aktivieren der Tailscale HTTPS-Zertifikate
sudo tailscale cert devsystem-vps.ts.net
```

In der Caddy-Konfiguration:

```
code.devsystem.ts.net {
  tls /etc/tailscale/certs/devsystem-vps.ts.net.crt /etc/tailscale/certs/devsystem-vps.ts.net.key
  reverse_proxy localhost:8080
}
```

#### Option 2: Lokale selbstsignierte Zertifikate

Alternativ kann Caddy selbstsignierte Zertifikate für die interne Verwendung generieren:

```
code.devsystem.internal {
  # Caddy generiert automatisch selbstsignierte Zertifikate
  tls internal
  reverse_proxy localhost:8080
}
```

### 3.3 DNS-Konfiguration

Tailscale bietet einen integrierten DNS-Dienst, der für die Namensauflösung im Tailnet verwendet werden kann:

```bash
# Aktivieren des Tailscale MagicDNS
sudo tailscale up --accept-dns

# Konfigurieren von benutzerdefinierten DNS-Einträgen
sudo tailscale set --hostname=devsystem-vps
```

Für das DevSystem empfehlen wir folgende DNS-Konfiguration:

1. **MagicDNS aktivieren**: Ermöglicht die Auflösung von Gerätenamen im Tailnet
2. **Benutzerdefinierte DNS-Einträge**: Für spezifische Dienste im DevSystem
   - `code.devsystem.internal` -> VPS-IP im Tailnet
   - `api.devsystem.internal` -> VPS-IP im Tailnet

## 4. Monitoring und Logging

### 4.1 Überwachung der Verbindung

Die Überwachung der Tailscale-Verbindung kann über verschiedene Methoden erfolgen:

```bash
# Status der Tailscale-Verbindung überprüfen
tailscale status

# Detaillierte Informationen über das Tailnet abrufen
tailscale netcheck
```

Für eine kontinuierliche Überwachung empfehlen wir die Einrichtung eines Monitoring-Skripts:

```bash
#!/bin/bash
# /usr/local/bin/tailscale-monitor.sh

# Überprüfen der Tailscale-Verbindung
if ! tailscale status | grep -q "Connected"; then
  echo "Tailscale-Verbindung unterbrochen - Versuche Wiederverbindung"
  sudo tailscale up
  
  # Benachrichtigung senden (z.B. per E-Mail oder Webhook)
  curl -X POST -H "Content-Type: application/json" \
    -d '{"text":"Tailscale-Verbindung auf devsystem-vps unterbrochen und wiederhergestellt"}' \
    https://hooks.example.com/services/XXX/YYY/ZZZ
fi
```

Dieses Skript kann als Cron-Job eingerichtet werden:

```bash
# Alle 5 Minuten ausführen
*/5 * * * * /usr/local/bin/tailscale-monitor.sh >> /var/log/tailscale-monitor.log 2>&1
```

### 4.2 Log-Management

Tailscale-Logs werden im systemd-Journal gespeichert und können wie folgt abgerufen werden:

```bash
# Tailscale-Logs anzeigen
sudo journalctl -u tailscaled -f

# Logs in eine Datei exportieren
sudo journalctl -u tailscaled -n 1000 > tailscale-logs.txt
```

Für eine zentrale Log-Verwaltung empfehlen wir die Integration mit einem Log-Management-System wie Grafana Loki oder ELK Stack:

```bash
# Beispiel für die Konfiguration von Promtail (Loki-Agent)
cat > /etc/promtail/tailscale.yaml << EOF
- job_name: tailscale
  journal:
    json: false
    max_age: 12h
    path: /var/log/journal
    labels:
      job: tailscale
      host: devsystem-vps
  pipeline_stages:
  - match:
      selector: '{job="tailscale"}'
      stages:
      - regex:
          expression: '.*tailscaled\\[(?P<pid>\\d+)\\]: (?P<message>.*)'
      - labels:
          pid:
          message:
EOF
```

### 4.3 Alarmierung bei Verbindungsproblemen

Für die Alarmierung bei Verbindungsproblemen empfehlen wir die Einrichtung von Benachrichtigungen über verschiedene Kanäle:

1. **E-Mail-Benachrichtigungen**: Bei Verbindungsabbrüchen oder -problemen
2. **Webhook-Integration**: Für die Integration mit Diensten wie Slack, Microsoft Teams oder Discord
3. **SMS/Push-Benachrichtigungen**: Für kritische Probleme, die sofortige Aufmerksamkeit erfordern

Beispiel für ein Alarmierungsskript:

```bash
#!/bin/bash
# /usr/local/bin/tailscale-alert.sh

# Überprüfen der Tailscale-Verbindung
if ! tailscale status | grep -q "Connected"; then
  # E-Mail-Benachrichtigung
  echo "Tailscale-Verbindung auf devsystem-vps unterbrochen" | \
    mail -s "ALARM: Tailscale-Verbindung unterbrochen" admin@example.com
  
  # Webhook-Benachrichtigung (z.B. Slack)
  curl -X POST -H "Content-Type: application/json" \
    -d '{"text":"ALARM: Tailscale-Verbindung auf devsystem-vps unterbrochen"}' \
    https://hooks.slack.com/services/XXX/YYY/ZZZ
  
  # Wiederverbindungsversuch
  sudo tailscale up
  
  # Überprüfen, ob die Wiederverbindung erfolgreich war
  if tailscale status | grep -q "Connected"; then
    echo "Tailscale-Verbindung auf devsystem-vps wiederhergestellt" | \
      mail -s "INFO: Tailscale-Verbindung wiederhergestellt" admin@example.com
  else
    echo "KRITISCH: Tailscale-Verbindung konnte nicht wiederhergestellt werden" | \
      mail -s "KRITISCH: Tailscale-Verbindung nicht wiederherstellbar" admin@example.com
  fi
fi
```

## 5. Backup und Recovery

### 5.1 Sicherung der Tailscale-Konfiguration

Die wichtigsten Tailscale-Konfigurationsdateien, die gesichert werden sollten, sind:

1. `/var/lib/tailscale/tailscaled.state`: Enthält den Zustand der Tailscale-Verbindung
2. `/etc/tailscale/tailscaled.defaults`: Enthält die Standardkonfiguration für den Tailscale-Dienst

Backup-Skript für die Tailscale-Konfiguration:

```bash
#!/bin/bash
# /usr/local/bin/tailscale-backup.sh

# Backup-Verzeichnis
BACKUP_DIR="/var/backups/tailscale"
TIMESTAMP=$(date +%Y%m%d%H%M%S)

# Backup-Verzeichnis erstellen, falls es nicht existiert
mkdir -p $BACKUP_DIR

# Tailscale-Dienst anhalten
sudo systemctl stop tailscale

# Konfigurationsdateien sichern
sudo tar -czf $BACKUP_DIR/tailscale-config-$TIMESTAMP.tar.gz \
  /var/lib/tailscale/tailscaled.state \
  /etc/tailscale/tailscaled.defaults

# Tailscale-Dienst wieder starten
sudo systemctl start tailscale

# Alte Backups bereinigen (älter als 30 Tage)
find $BACKUP_DIR -name "tailscale-config-*.tar.gz" -type f -mtime +30 -delete
```

Dieses Skript kann als wöchentlicher Cron-Job eingerichtet werden:

```bash
# Jeden Sonntag um 2:00 Uhr ausführen
0 2 * * 0 /usr/local/bin/tailscale-backup.sh >> /var/log/tailscale-backup.log 2>&1
```

### 5.2 Wiederherstellungsprozess

Im Falle eines Systemausfalls oder einer Neuinstallation kann die Tailscale-Konfiguration wie folgt wiederhergestellt werden:

```bash
#!/bin/bash
# /usr/local/bin/tailscale-restore.sh

# Backup-Datei als Parameter übergeben
BACKUP_FILE=$1

if [ -z "$BACKUP_FILE" ]; then
  echo "Bitte geben Sie die Backup-Datei an."
  exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Die angegebene Backup-Datei existiert nicht."
  exit 1
fi

# Tailscale-Dienst anhalten
sudo systemctl stop tailscale

# Backup wiederherstellen
sudo tar -xzf $BACKUP_FILE -C /

# Berechtigungen wiederherstellen
sudo chown -R root:root /var/lib/tailscale
sudo chmod 700 /var/lib/tailscale
sudo chmod 600 /var/lib/tailscale/tailscaled.state

# Tailscale-Dienst wieder starten
sudo systemctl start tailscale

# Status überprüfen
sudo tailscale status
```

Verwendung des Wiederherstellungsskripts:

```bash
sudo /usr/local/bin/tailscale-restore.sh /var/backups/tailscale/tailscale-config-20260407123456.tar.gz
```

### 5.3 Notfall-Wiederherstellung

Für den Fall, dass die Tailscale-Konfiguration nicht wiederhergestellt werden kann, ist eine Neuinstallation und -konfiguration erforderlich:

```bash
# Tailscale neu installieren
sudo apt-get update
sudo apt-get install -y tailscale

# Tailscale initialisieren
sudo tailscale up --hostname="devsystem-vps" --advertise-routes=10.0.0.0/24

# Firewall-Regeln wiederherstellen
sudo ufw allow in on tailscale0
sudo ufw allow 41641/udp
```

## 6. Zusammenfassung und nächste Schritte

Dieses Konzept beschreibt die Installation, Konfiguration und Integration von Tailscale als VPN-Lösung für das DevSystem-Projekt. Die wichtigsten Aspekte sind:

1. **Installation und Einrichtung**: Schritte zur Installation und Konfiguration von Tailscale auf dem Ubuntu VPS
2. **Netzwerksicherheit**: Zero-Trust-Zugriff, Zugriffskontrollen und Firewall-Konfiguration
3. **Integration mit anderen Komponenten**: Verbindung zu Caddy, Zertifikatsmanagement und DNS-Konfiguration
4. **Monitoring und Logging**: Überwachung der Verbindung, Log-Management und Alarmierung
5. **Backup und Recovery**: Sicherung der Tailscale-Konfiguration und Wiederherstellungsprozess

### Nächste Schritte

1. **Implementierung**: Umsetzung der in diesem Konzept beschriebenen Konfiguration auf dem Ubuntu VPS
2. **Testing**: Durchführung von Tests zur Überprüfung der Funktionalität und Sicherheit
3. **Dokumentation**: Erstellung einer Benutzeranleitung für die Verwendung von Tailscale im DevSystem-Projekt
4. **Schulung**: Schulung der Teammitglieder in der Verwendung von Tailscale und der Fehlerbehebung

## 7. Anhang

### 7.1 Nützliche Tailscale-Befehle

```bash
# Status der Tailscale-Verbindung anzeigen
tailscale status

# Detaillierte Informationen über das Tailnet anzeigen
tailscale netcheck

# Tailscale-Verbindung trennen
sudo tailscale down

# Tailscale-Verbindung wiederherstellen
sudo tailscale up

# Tailscale-Version anzeigen
tailscale version

# Tailscale-Konfiguration anzeigen
sudo cat /var/lib/tailscale/tailscaled.state | jq .

# Tailscale-Logs anzeigen
sudo journalctl -u tailscaled -f
```

### 7.2 Referenzen

- [Offizielle Tailscale-Dokumentation](https://tailscale.com/kb/)
- [Tailscale ACL-Dokumentation](https://tailscale.com/kb/1018/acls/)
- [Tailscale und Ubuntu](https://tailscale.com/kb/1039/install-ubuntu-2004/)
- [Tailscale MagicDNS](https://tailscale.com/kb/1081/magicdns/)
- [Tailscale HTTPS-Zertifikate](https://tailscale.com/kb/1153/enabling-https/)