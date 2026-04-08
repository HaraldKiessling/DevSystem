#!/bin/bash
#
# Tailscale Konfigurationsskript für DevSystem
# Dieses Skript automatisiert die Konfiguration von Tailscale nach der Installation
# auf einem Ubuntu VPS für das DevSystem Projekt.
#
# Version: 1.0
# Autor: DevSystem Team
# Datum: $(date +%Y-%m-%d)
#
# Funktionen:
# - Konfiguration von Tailscale-ACLs (Access Control Lists)
# - DNS-Konfiguration für Tailscale
# - Integration mit Caddy für HTTPS-Zertifikate
# - Einrichtung von Monitoring und Logging für Tailscale
# - Backup-Konfiguration für Tailscale-Einstellungen
#
# Verwendung: sudo bash configure-tailscale.sh [--acl-file=pfad] [--hostname=name] [--dns-domain=domain]

# Fehler bei der Ausführung beenden das Skript
set -e

# Farbdefinitionen für Terminal-Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging-Funktion
log() {
    local level=$1
    local message=$2
    local color=$NC
    
    case $level in
        "INFO") color=$GREEN ;;
        "WARN") color=$YELLOW ;;
        "ERROR") color=$RED ;;
        "STEP") color=$BLUE ;;
    esac
    
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message${NC}"
}

# Fehlermeldung und Exit-Funktion
error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Root-Berechtigungen prüfen
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error_exit "Dieses Skript muss als Root ausgeführt werden. Bitte verwenden Sie 'sudo'."
    fi
}

# Prüfen, ob Tailscale installiert ist
check_tailscale_installed() {
    if ! command -v tailscale &> /dev/null; then
        error_exit "Tailscale ist nicht installiert. Bitte installieren Sie Tailscale zuerst mit 'install-tailscale.sh'."
    fi
    
    if ! systemctl is-active --quiet tailscaled; then
        error_exit "Tailscale-Dienst läuft nicht. Bitte starten Sie den Dienst mit 'sudo systemctl start tailscaled'."
    fi
    
    log "INFO" "Tailscale ist installiert und läuft."
}

# Kommandozeilenargumente parsen
parse_args() {
    for arg in "$@"; do
        case $arg in
            --acl-file=*)
                ACL_FILE="${arg#*=}"
                ;;
            --hostname=*)
                HOSTNAME="${arg#*=}"
                ;;
            --dns-domain=*)
                DNS_DOMAIN="${arg#*=}"
                ;;
            --help)
                echo "Verwendung: sudo bash configure-tailscale.sh [--acl-file=pfad] [--hostname=name] [--dns-domain=domain]"
                echo ""
                echo "Optionen:"
                echo "  --acl-file=pfad       Pfad zu einer benutzerdefinierten ACL-Konfigurationsdatei (JSON-Format)"
                echo "  --hostname=name       Hostname des VPS im Tailscale-Netzwerk"
                echo "  --dns-domain=domain   Domain für MagicDNS"
                echo ""
                exit 0
                ;;
        esac
    done
    
    # Standardwerte setzen, falls nicht angegeben
    HOSTNAME=${HOSTNAME:-"devsystem-vps"}
    DNS_DOMAIN=${DNS_DOMAIN:-"devsystem.internal"}
    ACL_FILE=${ACL_FILE:-""}
}

# Generiere eine Standard-ACL-Konfiguration
generate_default_acl() {
    log "STEP" "Generiere Standard-ACL-Konfiguration..."
    
    # Temporäres Verzeichnis erstellen
    mkdir -p /etc/tailscale/acls
    
    # ACL-Datei erstellen
    cat > /etc/tailscale/acls/default_acl.json << EOF
{
  "acls": [
    {
      "action": "accept",
      "users": ["*"],
      "ports": ["*:*"]
    }
  ],
  "tagOwners": {
    "tag:server": ["autogroup:admin"],
    "tag:development": ["autogroup:admin"]
  },
  "groups": {
    "group:admins": ["admin@example.com"],
    "group:developers": ["dev1@example.com", "dev2@example.com"]
  },
  "hosts": {
    "devsystem-vps": "100.x.y.z"
  }
}
EOF
    
    log "INFO" "Standard-ACL-Datei erstellt unter: /etc/tailscale/acls/default_acl.json"
    log "WARN" "Dies ist nur eine Beispiel-ACL. Bitte passen Sie sie entsprechend Ihren Anforderungen an."
    
    # Muster-Editierungsanleitung
    cat > /etc/tailscale/acls/README.md << EOF
# Tailscale ACL-Konfiguration für DevSystem

Diese Datei enthält eine Beispiel-ACL-Konfiguration für Tailscale. Bitte passen Sie sie entsprechend Ihren Anforderungen an.

## Anleitung zur ACL-Konfiguration

1. Bearbeiten Sie die ACL-Datei (/etc/tailscale/acls/default_acl.json)
2. Ersetzen Sie die Beispiel-E-Mail-Adressen durch Ihre tatsächlichen Benutzerkonten
3. Passen Sie die Gruppen und Zugriffsberechtigungen an

Weitere Informationen finden Sie in der offiziellen Tailscale-ACL-Dokumentation:
https://tailscale.com/kb/1018/acls/
EOF
    
    log "INFO" "ACL-Anleitung erstellt unter: /etc/tailscale/acls/README.md"
}

# Anwenden einer benutzerdefinierten ACL-Konfiguration
apply_acl_config() {
    log "STEP" "Wende ACL-Konfiguration an..."
    
    # Wenn keine benutzerdefinierte ACL-Datei angegeben wurde, die Standard-ACL verwenden
    local acl_file=${ACL_FILE:-"/etc/tailscale/acls/default_acl.json"}
    
    # Überprüfen, ob die ACL-Datei existiert
    if [ ! -f "$acl_file" ]; then
        log "WARN" "ACL-Datei '$acl_file' existiert nicht. Generiere Standard-ACL..."
        generate_default_acl
        acl_file="/etc/tailscale/acls/default_acl.json"
    fi
    
    log "INFO" "Verwende ACL-Konfiguration von: $acl_file"
    
    # Hinweis: In einer Produktionsumgebung würde man diese Änderungen über die Tailscale Admin Console vornehmen
    # oder die Tailscale API verwenden. Für ein lokales Setup zeigen wir hier nur die ACL-Datei an.
    log "INFO" "ACL-Konfiguration:"
    cat "$acl_file"
    
    log "WARN" "In einer Produktionsumgebung müssen Sie diese ACL-Konfiguration in der Tailscale Admin Console hochladen."
    log "WARN" "Besuchen Sie https://login.tailscale.com/admin/acls, um Ihre ACLs zu konfigurieren."
    
    # Hier könnte man die Tailscale API verwenden, um die ACLs automatisch zu aktualisieren,
    # aber das erfordert API-Schlüssel und ist für ein Beispielskript zu komplex.
    
    log "INFO" "ACL-Konfiguration abgeschlossen. Bitte laden Sie die Datei in der Tailscale Admin Console hoch."
}

# DNS-Konfiguration für Tailscale
configure_dns() {
    log "STEP" "Konfiguriere DNS für Tailscale..."
    
    # Hostname setzen
    log "INFO" "Setze Hostname auf '$HOSTNAME'..."
    tailscale set \
        --hostname="$HOSTNAME" || error_exit "Fehler beim Setzen des Hostnames."
    
    # MagicDNS aktivieren
    log "INFO" "Aktiviere MagicDNS..."
    tailscale up \
        --accept-dns \
        --accept-routes || error_exit "Fehler beim Aktivieren von MagicDNS."
    
    log "INFO" "DNS-Konfiguration abgeschlossen."
    
    # Lokale hosts-Datei für DNS-Einträge erstellen
    log "INFO" "Erstelle lokale DNS-Konfiguration..."
    
    # IP-Adresse des Tailscale-Interfaces abrufen
    local ts_ip=$(tailscale ip -4)
    
    if [ -n "$ts_ip" ]; then
        # Erstelle DNS-Einträge für lokale Dienste
        cat > /etc/tailscale/local_dns.conf << EOF
# Tailscale DNS-Konfiguration für DevSystem
# Diese Datei enthält lokale DNS-Einträge für Tailscale-Dienste

# Hostname: $HOSTNAME
# Tailscale IP: $ts_ip

# Dienste
$ts_ip code.$DNS_DOMAIN
$ts_ip api.$DNS_DOMAIN
EOF
        
        log "INFO" "Lokale DNS-Konfiguration erstellt unter: /etc/tailscale/local_dns.conf"
        log "INFO" "Sie können diese Einträge in Ihre lokale hosts-Datei auf Client-Geräten einfügen, falls MagicDNS nicht ausreicht."
    else
        log "WARN" "Konnte Tailscale IP-Adresse nicht abrufen. DNS-Konfiguration unvollständig."
    fi
}

# Caddy-Integration für HTTPS-Zertifikate
integrate_with_caddy() {
    log "STEP" "Konfiguriere Integration mit Caddy für HTTPS-Zertifikate..."
    
    # Prüfen, ob Caddy installiert ist
    if ! command -v caddy &> /dev/null; then
        log "WARN" "Caddy ist nicht installiert. Installiere es für die HTTPS-Integration."
        
        # Caddy installieren (hier vereinfacht dargestellt)
        apt-get update
        apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
        apt-get update
        apt-get install -y caddy
    fi
    
    # Verzeichnis für Caddy-Konfiguration erstellen
    mkdir -p /etc/caddy/conf.d
    
    # Tailscale-Zertifikate generieren
    log "INFO" "Generiere Tailscale-Zertifikate..."
    
    # IP-Adresse des Tailscale-Interfaces abrufen
    local ts_ip=$(tailscale ip -4)
    
    if [ -z "$ts_ip" ]; then
        log "WARN" "Konnte Tailscale IP-Adresse nicht abrufen. HTTPS-Konfiguration könnte unvollständig sein."
    fi
    
    # Tailscale-Hostname für Zertifikate
    local ts_hostname="$HOSTNAME.ts.net"
    
    # Zertifikate generieren
    log "INFO" "Generiere Zertifikat für $ts_hostname..."
    mkdir -p /etc/tailscale/certs
    
    # Führe den Zertifikatsbefehl aus
    if ! tailscale cert --cert-file=/etc/tailscale/certs/$ts_hostname.crt --key-file=/etc/tailscale/certs/$ts_hostname.key $ts_hostname; then
        log "WARN" "Konnte Zertifikat für $ts_hostname nicht generieren. Verwende selbstsignierte Zertifikate in Caddy."
    else
        log "INFO" "Zertifikat für $ts_hostname erfolgreich generiert."
    fi
    
    # Caddy-Konfiguration für Tailscale erstellen - Option 1 mit Tailscale-Zertifikaten
    cat > /etc/caddy/conf.d/tailscale-option1.conf << EOF
# Caddy-Konfiguration für Tailscale mit Tailscale-Zertifikaten
# Aktivieren Sie diese Konfiguration, wenn Sie Tailscale-Zertifikate verwenden möchten

{
  # Globale Caddy-Einstellungen
  admin off
}

# code-server über Tailscale mit Tailscale-Zertifikaten
code.$DNS_DOMAIN, code.$ts_hostname {
  tls /etc/tailscale/certs/$ts_hostname.crt /etc/tailscale/certs/$ts_hostname.key
  
  # Nur Zugriff über Tailscale erlauben
  @tailscale {
    remote_ip 100.64.0.0/10
  }
  
  reverse_proxy @tailscale localhost:8080
}
EOF
    
    # Caddy-Konfiguration für Tailscale erstellen - Option 2 mit selbstsignierten Zertifikaten
    cat > /etc/caddy/conf.d/tailscale-option2.conf << EOF
# Caddy-Konfiguration für Tailscale mit selbstsignierten Zertifikaten
# Aktivieren Sie diese Konfiguration, wenn Sie selbstsignierte Zertifikate verwenden möchten

{
  # Globale Caddy-Einstellungen
  admin off
}

# code-server über Tailscale mit selbstsignierten Zertifikaten
code.$DNS_DOMAIN {
  # Nur Zugriff über Tailscale erlauben
  @tailscale {
    remote_ip 100.64.0.0/10
  }
  
  # Selbstsignierte Zertifikate verwenden
  tls internal
  
  reverse_proxy @tailscale localhost:8080
}
EOF
    
    log "INFO" "Caddy-Konfigurationen erstellt:"
    log "INFO" "- Option 1 (Tailscale-Zertifikate): /etc/caddy/conf.d/tailscale-option1.conf"
    log "INFO" "- Option 2 (Selbstsignierte Zertifikate): /etc/caddy/conf.d/tailscale-option2.conf"
    
    # Hauptkonfigurationsdatei, die die einzelnen Konfigurationen importiert
    cat > /etc/caddy/Caddyfile << EOF
# Haupt-Caddyfile für DevSystem
# Importiert die Konfigurationen aus dem conf.d-Verzeichnis

{
  # Globale Einstellungen
  admin off
  # Größere Header erlauben
  header_up X-Forwarded-For {remote_host}
  header_up X-Forwarded-Proto {scheme}
}

# Importieren Sie eine der zwei Optionen, je nachdem, welche Zertifikate Sie verwenden möchten:
# import /etc/caddy/conf.d/tailscale-option1.conf  # Tailscale-Zertifikate
import /etc/caddy/conf.d/tailscale-option2.conf  # Selbstsignierte Zertifikate
EOF
    
    log "INFO" "Haupt-Caddyfile erstellt unter: /etc/caddy/Caddyfile"
    log "WARN" "Bitte bearbeiten Sie die Datei und aktivieren Sie die gewünschte Option (Option 1 oder Option 2)."
    
    # Prüfen und neustarten von Caddy
    if systemctl is-active --quiet caddy; then
        log "INFO" "Teste Caddy-Konfiguration..."
        if caddy validate --config /etc/caddy/Caddyfile; then
            log "INFO" "Caddy-Konfiguration ist gültig. Starte Caddy neu..."
            systemctl reload caddy
            log "INFO" "Caddy neu gestartet."
        else
            log "WARN" "Caddy-Konfiguration ist ungültig. Bitte überprüfen Sie die Konfiguration."
        fi
    else
        log "INFO" "Starte Caddy..."
        systemctl enable caddy
        systemctl start caddy
        log "INFO" "Caddy gestartet."
    fi
}

# Einrichtung von Monitoring und Logging
setup_monitoring() {
    log "STEP" "Richte Monitoring und Logging für Tailscale ein..."
    
    # Erstelle Monitoring-Verzeichnis
    local monitoring_dir="/opt/tailscale-monitoring"
    mkdir -p "$monitoring_dir"
    
    # Überwachungsskript erstellen
    cat > "$monitoring_dir/tailscale-monitor.sh" << 'EOF'
#!/bin/bash
#
# Tailscale-Monitoring-Skript für DevSystem
# Überwacht den Status der Tailscale-Verbindung und führt bei Problemen Wiederherstellungsmaßnahmen durch

# Konfiguration
LOG_FILE="/var/log/tailscale-monitor.log"
MAX_LOG_SIZE=$((10 * 1024 * 1024)) # 10 MB
ALERT_EMAIL="admin@example.com"
WEBHOOK_URL=""  # Optional: URL für Webhook-Benachrichtigungen (z.B. Slack, Discord)

# Log-Rotation
if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt $MAX_LOG_SIZE ]; then
    mv "$LOG_FILE" "$LOG_FILE.old"
    touch "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Log-Rotation durchgeführt" >> "$LOG_FILE"
fi

# Funktion zum Protokollieren
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] $2" >> "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] $2"
}

# Funktion zur E-Mail-Benachrichtigung
send_email() {
    if command -v mail &> /dev/null; then
        echo "$1" | mail -s "$2" "$ALERT_EMAIL"
        log "INFO" "E-Mail gesendet: $2"
    else
        log "WARN" "E-Mail-Client nicht installiert. Keine E-Mail gesendet."
    fi
}

# Funktion zur Webhook-Benachrichtigung
send_webhook() {
    if [ -n "$WEBHOOK_URL" ] && command -v curl &> /dev/null; then
        curl -s -X POST -H "Content-Type: application/json" \
            -d "{\"text\":\"$1\"}" \
            "$WEBHOOK_URL" \
            >> "$LOG_FILE" 2>&1
        log "INFO" "Webhook-Benachrichtigung gesendet"
    fi
}

# Überprüfen der Tailscale-Verbindung
log "INFO" "Überprüfe Tailscale-Verbindung..."

if ! command -v tailscale &> /dev/null; then
    log "ERROR" "Tailscale ist nicht installiert"
    send_email "Tailscale ist auf dem Server nicht installiert" "ERROR: Tailscale nicht installiert"
    exit 1
fi

# Tailscale-Status prüfen
if ! tailscale status | grep -q "Connected"; then
    log "WARN" "Tailscale-Verbindung unterbrochen - Versuche Wiederverbindung"
    
    # Wiederherstellungsversuch
    sudo systemctl restart tailscaled
    sleep 5
    sudo tailscale up
    
    # Erneut prüfen
    if tailscale status | grep -q "Connected"; then
        log "INFO" "Tailscale-Verbindung wiederhergestellt"
        send_email "Tailscale-Verbindung wurde unterbrochen und erfolgreich wiederhergestellt" "INFO: Tailscale-Verbindung wiederhergestellt"
        send_webhook "Tailscale-Verbindung wurde unterbrochen und erfolgreich wiederhergestellt"
    else
        log "ERROR" "Tailscale-Verbindung konnte nicht wiederhergestellt werden"
        send_email "KRITISCH: Tailscale-Verbindung konnte nicht wiederhergestellt werden. Bitte überprüfen Sie den Server." "KRITISCH: Tailscale-Verbindung ausgefallen"
        send_webhook "KRITISCH: Tailscale-Verbindung konnte nicht wiederhergestellt werden"
    fi
else
    log "INFO" "Tailscale-Verbindung OK"
fi

# Netzwerkprüfung durchführen
log "INFO" "Führe Netzwerkprüfung durch..."
tailscale netcheck >> "$LOG_FILE" 2>&1
EOF
    
    # Skript ausführbar machen
    chmod +x "$monitoring_dir/tailscale-monitor.sh"
    
    # Cron-Job für Monitoring einrichten
    log "INFO" "Richte Cron-Job für Monitoring ein..."
    
    # Crontab-Eintrag erstellen
    echo "# Tailscale-Monitoring alle 5 Minuten
*/5 * * * * root $monitoring_dir/tailscale-monitor.sh" > /etc/cron.d/tailscale-monitor
    
    # Berechtigungen für Crontab-Datei setzen
    chmod 0644 /etc/cron.d/tailscale-monitor
    
    # Promtail-Konfiguration für Loki (wenn gewünscht)
    log "INFO" "Erstelle Beispiel-Konfiguration für Log-Management..."
    
    mkdir -p /etc/promtail
    cat > /etc/promtail/tailscale.yaml << EOF
# Promtail-Konfiguration für Tailscale-Logs
# Dies ist eine Beispielkonfiguration für die Integration mit Grafana Loki

- job_name: tailscale
  journal:
    json: false
    max_age: 12h
    path: /var/log/journal
    labels:
      job: tailscale
      host: $HOSTNAME
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
    
    log "INFO" "Promtail-Konfiguration erstellt unter: /etc/promtail/tailscale.yaml"
    log "INFO" "Für eine vollständige Log-Management-Lösung können Sie Grafana Loki und Promtail installieren."
    
    # Logrotate-Konfiguration für Tailscale-Logs
    cat > /etc/logrotate.d/tailscale-monitor << EOF
/var/log/tailscale-monitor.log {
    daily
    rotate 7
    missingok
    notifempty
    compress
    delaycompress
    create 0640 root adm
    postrotate
        systemctl reload rsyslog >/dev/null 2>&1 || true
    endscript
}
EOF
    
    log "INFO" "Logrotate-Konfiguration erstellt."
    log "INFO" "Monitoring und Logging-Setup abgeschlossen."
    
    # Erstelle README für Monitoring
    cat > "$monitoring_dir/README.md" << EOF
# Tailscale Monitoring für DevSystem

Dieses Verzeichnis enthält Skripte und Konfigurationen für das Monitoring der Tailscale-Verbindung.

## Monitoring-Skript

Das Skript \`tailscale-monitor.sh\` wird alle 5 Minuten per Cron ausgeführt und überwacht:

1. Tailscale-Verbindungsstatus
2. Netzwerkverbindung
3. Bei Problemen werden Benachrichtigungen gesendet und Wiederherstellungsmaßnahmen durchgeführt

## Anpassung

Um die E-Mail-Adresse für Benachrichtigungen oder Webhook-URL zu ändern, bearbeiten Sie:
\`/opt/tailscale-monitoring/tailscale-monitor.sh\`

## Logs

Die Logs des Monitoring-Skripts werden gespeichert unter:
\`/var/log/tailscale-monitor.log\`

Die Tailscale-Systemlogs können mit folgendem Befehl angezeigt werden:
\`sudo journalctl -u tailscaled -f\`
EOF
    
    log "INFO" "Monitoring-Dokumentation erstellt unter: $monitoring_dir/README.md"
}

# Backup-Konfiguration für Tailscale-Einstellungen
setup_backup() {
    log "STEP" "Richte Backup-Konfiguration für Tailscale-Einstellungen ein..."
    
    # Backup-Verzeichnis
    local backup_dir="/var/backups/tailscale"
    mkdir -p "$backup_dir"
    
    # Backup-Skript erstellen
    cat > /usr/local/bin/tailscale-backup.sh << 'EOF'
#!/bin/bash
#
# Backup-Skript für Tailscale-Konfiguration
# Dieses Skript sichert die Tailscale-Konfigurationsdateien und -Zustände

# Konfiguration
BACKUP_DIR="/var/backups/tailscale"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
RETENTION_DAYS=30

# Backup-Verzeichnis erstellen, falls es nicht existiert
mkdir -p $BACKUP_DIR

# Prüfen, ob Tailscale läuft
if systemctl is-active --quiet tailscaled; then
    echo "Tailscale läuft. Fahre mit Backup fort."
else
    echo "WARNUNG: Tailscale scheint nicht zu laufen. Backup wird trotzdem durchgeführt."
fi

# Backup-Archiv erstellen
echo "Erstelle Backup-Archiv..."
tar -czf $BACKUP_DIR/tailscale-config-$TIMESTAMP.tar.gz \
    /var/lib/tailscale/tailscaled.state \
    /etc/tailscale \
    /etc/caddy/conf.d/tailscale-*.conf \
    /opt/tailscale-monitoring 2>/dev/null || echo "Einige Dateien konnten nicht gesichert werden"

# Dateien über 30 Tage löschen
echo "Bereinige alte Backups..."
find $BACKUP_DIR -name "tailscale-config-*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete

echo "Backup abgeschlossen: $BACKUP_DIR/tailscale-config-$TIMESTAMP.tar.gz"
echo "Backup-Größe: $(du -h $BACKUP_DIR/tailscale-config-$TIMESTAMP.tar.gz | cut -f1)"
EOF
    
    # Skript ausführbar machen
    chmod +x /usr/local/bin/tailscale-backup.sh
    
    # Wiederherstellungsskript erstellen
    cat > /usr/local/bin/tailscale-restore.sh << 'EOF'
#!/bin/bash
#
# Wiederherstellungsskript für Tailscale-Konfiguration
# Dieses Skript stellt die Tailscale-Konfigurationsdateien und -Zustände aus einem Backup wieder her

# Backup-Datei als Parameter übergeben
BACKUP_FILE=$1

if [ -z "$BACKUP_FILE" ]; then
  echo "Bitte geben Sie die Backup-Datei an."
  echo "Verwendung: sudo $0 /pfad/zu/tailscale-config-YYYYMMDDHHMMSS.tar.gz"
  exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Die angegebene Backup-Datei existiert nicht: $BACKUP_FILE"
  exit 1
fi

# Bestätigung einholen
echo "WARNUNG: Dies wird die aktuelle Tailscale-Konfiguration überschreiben."
read -p "Sind Sie sicher, dass Sie fortfahren möchten? (j/N) " confirm
if [ "$confirm" != "j" ] && [ "$confirm" != "J" ]; then
  echo "Wiederherstellung abgebrochen."
  exit 0
fi

# Tailscale-Dienst anhalten
echo "Halte Tailscale-Dienst an..."
systemctl stop tailscaled

# Backup wiederherstellen
echo "Stelle Backup wieder her: $BACKUP_FILE"
tar -xzf "$BACKUP_FILE" -C /

# Berechtigungen wiederherstellen
echo "Stelle Berechtigungen wieder her..."
chown -R root:root /var/lib/tailscale
chmod 700 /var/lib/tailscale
chmod 600 /var/lib/tailscale/tailscaled.state

# Tailscale-Dienst wieder starten
echo "Starte Tailscale-Dienst..."
systemctl start tailscaled

# Caddy neu laden, falls vorhanden
if command -v caddy &> /dev/null && systemctl is-active --quiet caddy; then
  echo "Lade Caddy-Konfiguration neu..."
  systemctl reload caddy
fi

# Status überprüfen
echo "Überprüfe Tailscale-Status..."
sleep 5
tailscale status

echo "Wiederherstellung abgeschlossen."
EOF
    
    # Skript ausführbar machen
    chmod +x /usr/local/bin/tailscale-restore.sh
    
    # Cron-Job für Backup einrichten
    log "INFO" "Richte Cron-Job für Backups ein..."
    
    # Crontab-Eintrag erstellen
    echo "# Tailscale-Backup sonntags um 2:00 Uhr
0 2 * * 0 root /usr/local/bin/tailscale-backup.sh >> /var/log/tailscale-backup.log 2>&1" > /etc/cron.d/tailscale-backup
    
    # Berechtigungen für Crontab-Datei setzen
    chmod 0644 /etc/cron.d/tailscale-backup
    
    # Erstelle README für Backup
    cat > "$backup_dir/README.md" << EOF
# Tailscale Backup für DevSystem

Dieses Verzeichnis enthält automatische Backups der Tailscale-Konfiguration.

## Backup-Inhalt

Die Backup-Archive enthalten:
- Tailscale-Zustandsdatei (/var/lib/tailscale/tailscaled.state)
- Tailscale-Konfigurationsdateien (/etc/tailscale/*)
- Caddy-Konfigurationen für Tailscale
- Monitoring-Skripte und -Konfigurationen

## Backup-Zeitplan

Backups werden automatisch jeden Sonntag um 2:00 Uhr erstellt.
Alte Backups (älter als 30 Tage) werden automatisch gelöscht.

## Wiederherstellung

Um ein Backup wiederherzustellen, verwenden Sie:
\`sudo /usr/local/bin/tailscale-restore.sh /var/backups/tailscale/tailscale-config-YYYYMMDDHHMMSS.tar.gz\`

## Manuelles Backup

Um ein manuelles Backup zu erstellen, führen Sie aus:
\`sudo /usr/local/bin/tailscale-backup.sh\`
EOF
    
    log "INFO" "Backup-Dokumentation erstellt unter: $backup_dir/README.md"
    log "INFO" "Backup-Konfiguration abgeschlossen."
}

# Zusätzliche hilfreiche Informationen anzeigen
show_info() {
    echo ""
    log "STEP" "Konfiguration abgeschlossen!"
    echo ""
    echo -e "${GREEN}Tailscale wurde erfolgreich konfiguriert.${NC}"
    echo ""
    echo "Konfigurierte Komponenten:"
    echo "  - ACL-Konfiguration: /etc/tailscale/acls/"
    echo "  - DNS-Konfiguration: MagicDNS aktiviert"
    echo "  - Caddy-Integration: /etc/caddy/conf.d/tailscale-*.conf"
    echo "  - Monitoring und Logging: /opt/tailscale-monitoring/"
    echo "  - Backup-Konfiguration: /var/backups/tailscale/"
    echo ""
    echo "Nützliche Befehle:"
    echo "  - Tailscale-Status anzeigen:    tailscale status"
    echo "  - Netzwerktest durchführen:     tailscale netcheck"
    echo "  - Manuelles Backup erstellen:   sudo /usr/local/bin/tailscale-backup.sh"
    echo "  - Monitoring manuell ausführen: sudo /opt/tailscale-monitoring/tailscale-monitor.sh"
    echo ""
    echo "Weitere Informationen finden Sie in der Dokumentation in den jeweiligen Verzeichnissen."
    echo ""
}

# Hauptfunktion
main() {
    log "STEP" "Starte Tailscale-Konfiguration für DevSystem..."
    
    # Prüfungen
    check_root
    parse_args "$@"
    check_tailscale_installed
    
    # Konfigurationen
    apply_acl_config
    configure_dns
    integrate_with_caddy
    setup_monitoring
    setup_backup
    
    # Abschluss
    show_info
    
    log "INFO" "Tailscale-Konfiguration erfolgreich abgeschlossen."
}

# Skript ausführen
main "$@"