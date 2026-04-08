#!/bin/bash
#
# DevSystem - Caddy Configuration Script
# Autor: DevSystem Team
# Datum: 2026-04-08
#
# Beschreibung: 
# Dieses Script konfiguriert Caddy als Reverse Proxy für das DevSystem-Projekt.
# Es führt folgende Aktionen aus:
# - Erstellung einer detaillierten Caddyfile-Konfiguration
# - Konfiguration als Reverse Proxy für code-server
# - Einrichtung von HTTPS mit Tailscale-Zertifikaten
# - Konfiguration von Sicherheitsheadern
# - Einrichtung von Logging und Monitoring
# - Performance-Optimierungen
#
# Voraussetzungen:
# - Caddy muss installiert sein
# - Tailscale muss installiert und konfiguriert sein
# - Root-Zugriff

set -e # Script beenden, wenn ein Befehl fehlschlägt
set -u # Script beenden, wenn eine Variable nicht definiert ist

# Farbige Ausgabe für bessere Lesbarkeit
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logs in einer Datei speichern
LOG_FILE="/var/log/devsystem-configure-caddy.log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

# Funktion zur Ausgabe von Nachrichten
log_message() {
  echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Funktion zur Ausgabe von Erfolgsmeldungen
log_success() {
  echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓ $1${NC}"
}

# Funktion zur Ausgabe von Warnungen
log_warning() {
  echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠ $1${NC}"
}

# Funktion zur Ausgabe von Fehlermeldungen
log_error() {
  echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗ $1${NC}"
}

# Standardwerte für Konfigurationsparameter
CODE_SERVER_PORT="8080"
HOSTNAME=$(hostname -s)
DOMAIN="${HOSTNAME}.tailcfea8a.ts.net"
TS_DOMAIN="code.devsystem.internal"
CADDY_DIR="/etc/caddy"
CADDY_LOG_DIR="/var/log/caddy"
TMATE_HOSTNAME="${HOSTNAME}"

# Kommandozeilenargumente parsen
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --code-server-port=*) CODE_SERVER_PORT="${1#*=}"; shift ;;
    --domain=*) DOMAIN="${1#*=}"; shift ;;
    --ts-domain=*) TS_DOMAIN="${1#*=}"; shift ;;
    --help) 
      echo "Verwendung: $0 [Optionen]"
      echo "Optionen:"
      echo "  --code-server-port=PORT   Port für code-server (Standard: 8080)"
      echo "  --domain=DOMAIN           Tailscale-Domain (Standard: hostname.tailcfea8a.ts.net)"
      echo "  --ts-domain=DOMAIN        Interne Domain (Standard: code.devsystem.internal)"
      exit 0
      ;;
    *) log_error "Unbekannter Parameter: $1"; exit 1 ;;
  esac
done

# Prüfen, ob das Script mit Root-Rechten ausgeführt wird
if [ "$(id -u)" != "0" ]; then
   log_error "Dieses Script muss mit Root-Rechten ausgeführt werden."
   exit 1
fi

# Prüfen, ob Caddy installiert ist
if ! command -v caddy &> /dev/null; then
    log_error "Caddy ist nicht installiert. Bitte zunächst Caddy installieren."
    exit 1
fi

# Prüfen, ob Tailscale installiert ist
if ! command -v tailscale &> /dev/null; then
    log_error "Tailscale ist nicht installiert. Bitte zunächst Tailscale installieren."
    exit 1
fi

# Willkommensnachricht
log_message "===== DevSystem Caddy Konfiguration ====="
log_message "Konfiguriere Caddy als Reverse Proxy für code-server"

# 1. Verzeichnisstruktur erstellen
log_message "1. Erstelle Verzeichnisstruktur..."

mkdir -p ${CADDY_DIR}/sites
mkdir -p ${CADDY_DIR}/snippets
mkdir -p ${CADDY_DIR}/tls/tailscale
mkdir -p ${CADDY_DIR}/tls/local
mkdir -p ${CADDY_LOG_DIR}

# Berechtigungen setzen
if getent passwd caddy > /dev/null; then
    chown -R caddy:caddy ${CADDY_DIR}
    chown -R caddy:caddy ${CADDY_LOG_DIR}
fi

log_success "Verzeichnisstruktur wurde erstellt."

# 2. HTTPS mit Tailscale-Zertifikaten einrichten
log_message "2. Generiere und konfiguriere Tailscale-Zertifikate..."

# Falls die Domain im Parameter nicht gesetzt wurde, die Tailscale-IP-Adresse verwenden
if [[ -z "$DOMAIN" || "$DOMAIN" == "${HOSTNAME}.tailcfea8a.ts.net" ]]; then
    log_message "Ermittle Tailscale-Domain..."
    TS_STATUS=$(tailscale status --json)
    if command -v jq &> /dev/null; then
        DOMAIN=$(echo "$TS_STATUS" | jq -r '.Self.DNSName')
        if [[ "$DOMAIN" == "null" || -z "$DOMAIN" ]]; then
            DOMAIN=$(echo "$TS_STATUS" | jq -r '.Self.HostName')
        fi
    else
        # Fallback, wenn jq nicht installiert ist
        DOMAIN=$(hostname).tailcfea8a.ts.net
    fi
fi

log_message "Verwende Tailscale-Domain: $DOMAIN"
log_message "Erstelle Tailscale-Zertifikate für $DOMAIN..."

# Lösche alte Zertifikate, falls vorhanden
rm -f ${CADDY_DIR}/tls/tailscale/${DOMAIN}.crt
rm -f ${CADDY_DIR}/tls/tailscale/${DOMAIN}.key

# Tailscale-Zertifikate generieren
if tailscale cert "$DOMAIN" > /dev/null 2>&1; then
    cp /var/lib/tailscale/certs/${DOMAIN}.crt ${CADDY_DIR}/tls/tailscale/
    cp /var/lib/tailscale/certs/${DOMAIN}.key ${CADDY_DIR}/tls/tailscale/
    
    # Berechtigungen setzen
    if getent passwd caddy > /dev/null; then
        chown -R caddy:caddy ${CADDY_DIR}/tls
        chmod 600 ${CADDY_DIR}/tls/tailscale/${DOMAIN}.key
    fi
    
    log_success "Tailscale-Zertifikate wurden generiert und installiert."
else
    log_warning "Konnte keine Tailscale-Zertifikate generieren. Erstelle selbstsignierte Zertifikate als Fallback."
    
    # Selbstsignierte Zertifikate erstellen
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ${CADDY_DIR}/tls/local/${DOMAIN}.key \
        -out ${CADDY_DIR}/tls/local/${DOMAIN}.crt \
        -subj "/CN=${DOMAIN}"
    
    # Berechtigungen setzen
    if getent passwd caddy > /dev/null; then
        chown -R caddy:caddy ${CADDY_DIR}/tls
        chmod 600 ${CADDY_DIR}/tls/local/${DOMAIN}.key
    fi
    
    log_success "Selbstsignierte Zertifikate wurden erstellt."
    
    # Variablen für spätere Verwendung anpassen
    USE_SELF_SIGNED=true
fi

# 3. Sicherheits-Header-Snippet erstellen
log_message "3. Erstelle Sicherheits-Header-Snippet..."

cat > ${CADDY_DIR}/snippets/security-headers.caddy << EOF
header {
    # Strict-Transport-Security aktivieren
    Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    
    # XSS-Schutz aktivieren
    X-XSS-Protection "1; mode=block"
    
    # Clickjacking-Schutz
    X-Frame-Options "SAMEORIGIN"
    
    # MIME-Sniffing verhindern
    X-Content-Type-Options "nosniff"
    
    # Referrer-Policy einschränken
    Referrer-Policy "strict-origin-when-cross-origin"
    
    # Content-Security-Policy für erhöhte Sicherheit
    Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' wss:; frame-ancestors 'self';"
    
    # Entfernen von Server-Header
    -Server
}
EOF

log_success "Sicherheits-Header-Snippet wurde erstellt."

# 4. Tailscale-Authentifizierung-Snippet erstellen
log_message "4. Erstelle Tailscale-Authentifizierung-Snippet..."

cat > ${CADDY_DIR}/snippets/tailscale-auth.caddy << EOF
# Nur Zugriff über Tailscale erlauben
@tailscale {
    remote_ip 100.64.0.0/10
}

# Zugriff verweigern, wenn nicht über Tailscale
respond !@tailscale 403 {
    body "Zugriff nur über Tailscale erlaubt"
}
EOF

log_success "Tailscale-Authentifizierung-Snippet wurde erstellt."

# 5. Code-Server-Konfiguration
log_message "5. Erstelle code-server Konfiguration..."

cat > ${CADDY_DIR}/sites/code-server.caddy << EOF
${TS_DOMAIN} {
    # Tailscale-Authentifizierung importieren
    import /etc/caddy/snippets/tailscale-auth.caddy
    
    # TLS-Konfiguration
EOF

if [ "${USE_SELF_SIGNED:-false}" = true ]; then
    cat >> ${CADDY_DIR}/sites/code-server.caddy << EOF
    tls /etc/caddy/tls/local/${DOMAIN}.crt /etc/caddy/tls/local/${DOMAIN}.key
EOF
else
    cat >> ${CADDY_DIR}/sites/code-server.caddy << EOF
    tls /etc/caddy/tls/tailscale/${DOMAIN}.crt /etc/caddy/tls/tailscale/${DOMAIN}.key
EOF
fi

cat >> ${CADDY_DIR}/sites/code-server.caddy << EOF
    
    # Reverse Proxy zu code-server
    reverse_proxy @tailscale localhost:${CODE_SERVER_PORT} {
        # Header für WebSocket-Unterstützung
        header_up Connection {http.request.header.Connection}
        header_up Upgrade {http.request.header.Upgrade}
        
        # Timeouts erhöhen für lange Entwicklungssitzungen
        transport http {
            keepalive 30m
            keepalive_idle_conns 10
        }
    }
    
    # Sicherheits-Header importieren
    import /etc/caddy/snippets/security-headers.caddy
    
    # Kompression
    encode gzip zstd
    
    # Logging
    log {
        output file /var/log/caddy/code-server.log {
            roll_size 50MB
            roll_keep 5
            roll_keep_for 168h
        }
        format json
    }
}
EOF

log_success "code-server Konfiguration wurde erstellt."

# 6. Hauptkonfigurationsdatei erstellen
log_message "6. Erstelle Hauptkonfigurationsdatei (Caddyfile)..."

cat > ${CADDY_DIR}/Caddyfile << EOF
# Globale Optionen
{
    admin off
    
    servers {
        protocol {
            min_tls_version 1.2
            experimental_http3
            strict_sni_host
        }
        
        timeouts {
            read_body 30s
            read_header 10s
            write 60s
            idle 5m
        }
    }
    
    log {
        output file /var/log/caddy/access.log {
            roll_size 100MB
            roll_keep 10
            roll_keep_for 720h
        }
        format json
    }
    
    # Metriken für Prometheus
    metrics
}

# Metriken-Endpunkt
:2019 {
    # Nur Zugriff über Tailscale erlauben
    @tailscale {
        remote_ip 100.64.0.0/10
    }
    
    # Metriken-Endpunkt nur über Tailscale zugänglich machen
    metrics @tailscale /metrics
    
    # Zugriff verweigern, wenn nicht über Tailscale
    respond !@tailscale 403
}

# Snippets importieren
import /etc/caddy/snippets/*.caddy

# Sites importieren
import /etc/caddy/sites/*.caddy
EOF

log_success "Hauptkonfigurationsdatei wurde erstellt."

# 7. Caddy-Monitoring-Skript erstellen
log_message "7. Erstelle Caddy-Monitoring-Skript..."

cat > /usr/local/bin/caddy-monitor.sh << EOF
#!/bin/bash

# Überprüfen, ob Caddy läuft
if ! systemctl is-active --quiet caddy; then
    echo "\$(date '+%Y-%m-%d %H:%M:%S') Caddy ist nicht aktiv - Versuche Neustart"
    systemctl restart caddy
fi

# Überprüfen, ob die Proxy-Verbindungen funktionieren
if ! curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:${CODE_SERVER_PORT}; then
    echo "\$(date '+%Y-%m-%d %H:%M:%S') code-server ist nicht erreichbar"
fi
EOF

chmod +x /usr/local/bin/caddy-monitor.sh

# 8. Cron-Job für Monitoring und Zertifikatserneuerung einrichten
log_message "8. Richte Cron-Jobs für Monitoring und Zertifikatserneuerung ein..."

# Monitoring-Cron-Job
MONITOR_CRON="*/10 * * * * /usr/local/bin/caddy-monitor.sh >> /var/log/caddy-monitor.log 2>&1"
(crontab -l 2>/dev/null | grep -v "caddy-monitor.sh" ; echo "$MONITOR_CRON") | crontab -

# Zertifikatserneuerung-Cron-Job
if [ "${USE_SELF_SIGNED:-false}" != true ]; then
    cat > /usr/local/bin/tailscale-cert-renew.sh << EOF
#!/bin/bash

# Zertifikate erneuern
tailscale cert ${DOMAIN}

# Zertifikate für Caddy kopieren
cp /var/lib/tailscale/certs/${DOMAIN}.crt /etc/caddy/tls/tailscale/
cp /var/lib/tailscale/certs/${DOMAIN}.key /etc/caddy/tls/tailscale/

# Berechtigungen setzen
chown -R caddy:caddy /etc/caddy/tls/tailscale
chmod 600 /etc/caddy/tls/tailscale/${DOMAIN}.key

# Caddy neu laden
systemctl reload caddy
EOF

    chmod +x /usr/local/bin/tailscale-cert-renew.sh

    CERT_CRON="0 0 1 * * /usr/local/bin/tailscale-cert-renew.sh > /var/log/tailscale-cert-renew.log 2>&1"
    (crontab -l 2>/dev/null | grep -v "tailscale-cert-renew.sh" ; echo "$CERT_CRON") | crontab -
fi

log_success "Cron-Jobs für Monitoring und Zertifikatserneuerung wurden eingerichtet."

# 9. Konfiguration validieren
log_message "9. Validiere Caddy-Konfiguration..."

if caddy validate --config ${CADDY_DIR}/Caddyfile > /dev/null 2>&1; then
    log_success "Caddy-Konfiguration ist gültig."
else
    log_error "Caddy-Konfiguration ist ungültig. Bitte überprüfe die Konfigurationsdateien."
    
    # Versuche, den genauen Fehler anzuzeigen
    caddy validate --config ${CADDY_DIR}/Caddyfile
    
    exit 1
fi

# 10. Caddy-Dienst neu laden oder starten
log_message "10. Lade Caddy-Dienst neu..."

if systemctl is-active --quiet caddy; then
    systemctl reload caddy
    log_success "Caddy-Dienst wurde neu geladen."
else
    systemctl restart caddy
    log_success "Caddy-Dienst wurde (neu) gestartet."
fi

# 11. Überprüfen, ob Caddy erfolgreich gestartet wurde
log_message "11. Überprüfe Caddy-Dienst-Status..."

if systemctl is-active --quiet caddy; then
    log_success "Caddy-Dienst läuft."
else
    log_error "Caddy-Dienst konnte nicht gestartet werden. Bitte überprüfe die Logs mit 'journalctl -u caddy'."
    exit 1
fi

# Zusammenfassung
log_success "===== Caddy-Konfiguration abgeschlossen ====="
log_message "Caddy wurde erfolgreich als Reverse Proxy für code-server konfiguriert."
log_message "Verwendete Tailscale-Domain: ${DOMAIN}"
log_message "Interne Domain für Code-Server: ${TS_DOMAIN}"
log_message "Code-Server-Port: ${CODE_SERVER_PORT}"
log_message ""
log_message "Nächste Schritte:"
log_message "1. Zugriff über '${TS_DOMAIN}' testen"
log_message "2. Prüfen, ob Tailscale-DNS richtig konfiguriert ist, falls der Zugriff nicht funktioniert:"
log_message "   - DNS-Eintrag für '${TS_DOMAIN}' sollte auf '${DOMAIN}' verweisen"
log_message ""
log_message "Logs:"
log_message "- Caddy-Logs: /var/log/caddy/access.log, /var/log/caddy/code-server.log"
log_message "- Konfigurationslog: ${LOG_FILE}"
log_message "- Monitoring-Log: /var/log/caddy-monitor.log"
if [ "${USE_SELF_SIGNED:-false}" != true ]; then
    log_message "- Zertifikatserneuerung-Log: /var/log/tailscale-cert-renew.log"
fi

exit 0