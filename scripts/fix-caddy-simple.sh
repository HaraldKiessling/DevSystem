#!/bin/bash
#
# DevSystem - Einfache Caddy Konfigurationskorrektur
# Autor: DevSystem Team
# Datum: 2026-04-08
#
# Beschreibung: 
# Dieses Skript erstellt eine einfache Caddy-Konfiguration, die mit älteren Caddy-Versionen kompatibel ist.

set -e

# Farbige Ausgabe für bessere Lesbarkeit
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funktion für Logausgaben
log_message() {
  echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

log_success() {
  echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓ $1${NC}"
}

log_error() {
  echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗ $1${NC}"
}

# Prüfen, ob das Script mit Root-Rechten ausgeführt wird
if [ "$(id -u)" != "0" ]; then
   log_error "Dieses Script muss mit Root-Rechten ausgeführt werden."
   exit 1
fi

CADDY_DIR="/etc/caddy"
DOMAIN=$(hostname).tailcfea8a.ts.net
TS_DOMAIN="code.devsystem.internal"
CODE_SERVER_PORT="8080"

# Parameter verarbeiten
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --domain=*) DOMAIN="${1#*=}"; shift ;;
        --ts-domain=*) TS_DOMAIN="${1#*=}"; shift ;;
        --code-server-port=*) CODE_SERVER_PORT="${1#*=}"; shift ;;
        *) log_error "Unbekannter Parameter: $1"; exit 1 ;;
    esac
done

log_message "Erstelle vereinfachte Caddy-Konfiguration..."

# Sichere die vorhandenen Konfigurationsdateien
if [ -f "${CADDY_DIR}/Caddyfile" ]; then
    mv "${CADDY_DIR}/Caddyfile" "${CADDY_DIR}/Caddyfile.bak.$(date +%s)"
fi

# Verzeichnisse erstellen, falls sie noch nicht existieren
mkdir -p "${CADDY_DIR}/tls/tailscale"
mkdir -p "${CADDY_DIR}/tls/local"
mkdir -p "/var/log/caddy"

# Bestimme, welches Zertifikat zu verwenden ist
USE_TAILSCALE_CERT=true
if [ ! -f "${CADDY_DIR}/tls/tailscale/${DOMAIN}.crt" ] || [ ! -f "${CADDY_DIR}/tls/tailscale/${DOMAIN}.key" ]; then
    if [ -f "${CADDY_DIR}/tls/local/${DOMAIN}.crt" ] && [ -f "${CADDY_DIR}/tls/local/${DOMAIN}.key" ]; then
        USE_TAILSCALE_CERT=false
    else
        log_message "Keine Zertifikate gefunden. Versuche, Tailscale-Zertifikate zu generieren..."
        if tailscale cert "${DOMAIN}" > /dev/null 2>&1; then
            cp /var/lib/tailscale/certs/${DOMAIN}.crt ${CADDY_DIR}/tls/tailscale/
            cp /var/lib/tailscale/certs/${DOMAIN}.key ${CADDY_DIR}/tls/tailscale/
            chmod 600 ${CADDY_DIR}/tls/tailscale/${DOMAIN}.key
            log_success "Tailscale-Zertifikate generiert und installiert."
        else
            log_message "Konnte keine Tailscale-Zertifikate generieren. Erstelle selbstsignierte Zertifikate..."
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                -keyout ${CADDY_DIR}/tls/local/${DOMAIN}.key \
                -out ${CADDY_DIR}/tls/local/${DOMAIN}.crt \
                -subj "/CN=${DOMAIN}" > /dev/null 2>&1
            chmod 600 ${CADDY_DIR}/tls/local/${DOMAIN}.key
            USE_TAILSCALE_CERT=false
            log_success "Selbstsignierte Zertifikate erstellt."
        fi
    fi
fi

# Bestimme den Pfad zu den Zertifikaten
if [ "${USE_TAILSCALE_CERT}" = true ]; then
    CERT_PATH="${CADDY_DIR}/tls/tailscale/${DOMAIN}.crt"
    KEY_PATH="${CADDY_DIR}/tls/tailscale/${DOMAIN}.key"
else
    CERT_PATH="${CADDY_DIR}/tls/local/${DOMAIN}.crt"
    KEY_PATH="${CADDY_DIR}/tls/local/${DOMAIN}.key"
fi

# Erstelle die neue Konfiguration
log_message "Erstelle neue vereinfachte Caddyfile..."

cat > "${CADDY_DIR}/Caddyfile" << EOF
# Globale Optionen
{
    admin off
    log {
        output file /var/log/caddy/access.log
    }
}

# code-server Konfiguration
${TS_DOMAIN} {
    # TLS-Konfiguration
    tls ${CERT_PATH} ${KEY_PATH}
    
    # Tailscale-Zugriffsbeschränkung
    @tailscale {
        remote_ip 100.64.0.0/10
    }
    
    @not_tailscale {
        not remote_ip 100.64.0.0/10
    }
    
    # Verweigere Zugriff, wenn nicht über Tailscale
    respond @not_tailscale 403 {
        body "Zugriff nur über Tailscale erlaubt"
    }
    
    # Reverse Proxy zu code-server
    reverse_proxy @tailscale localhost:${CODE_SERVER_PORT} {
        header_up Connection {http.request.header.Connection}
        header_up Upgrade {http.request.header.Upgrade}
    }
    
    # Sicherheits-Header
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-XSS-Protection "1; mode=block"
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        -Server
    }
    
    # Logging
    log {
        output file /var/log/caddy/code-server.log
    }
}
EOF

log_success "Neue vereinfachte Caddyfile erstellt."

# Validiere die Caddy-Konfiguration
log_message "Validiere neue Caddy-Konfiguration..."

if caddy validate --config "${CADDY_DIR}/Caddyfile" &>/dev/null; then
    log_success "Caddy-Konfiguration ist gültig."
    
    # Setze Berechtigungen, falls caddy als eigener Benutzer läuft
    if getent passwd caddy > /dev/null; then
        chown -R caddy:caddy ${CADDY_DIR}
        chown -R caddy:caddy /var/log/caddy
    fi
    
    # Neustart von Caddy
    log_message "Starte Caddy-Dienst neu..."
    systemctl restart caddy
    
    if systemctl is-active --quiet caddy; then
        log_success "Caddy-Dienst wurde erfolgreich neu gestartet."
    else
        log_error "Caddy-Dienst konnte nicht gestartet werden."
        systemctl status caddy --no-pager
        exit 1
    fi
else
    log_error "Caddy-Konfiguration ist ungültig."
    caddy validate --config "${CADDY_DIR}/Caddyfile"
    exit 1
fi

# Aktualisiere Monitoring-Skript
log_message "Aktualisiere Monitoring-Skript..."

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

# Aktualisiere Zertifikatserneuerungsskript
if [ "${USE_TAILSCALE_CERT}" = true ]; then
    log_message "Aktualisiere Zertifikatserneuerungsskript..."
    
    cat > /usr/local/bin/tailscale-cert-renew.sh << EOF
#!/bin/bash

# Zertifikate erneuern
tailscale cert ${DOMAIN}

# Zertifikate für Caddy kopieren
cp /var/lib/tailscale/certs/${DOMAIN}.crt ${CADDY_DIR}/tls/tailscale/
cp /var/lib/tailscale/certs/${DOMAIN}.key ${CADDY_DIR}/tls/tailscale/

# Berechtigungen setzen
chmod 600 ${CADDY_DIR}/tls/tailscale/${DOMAIN}.key

# Caddy neu laden
systemctl reload caddy
EOF

    chmod +x /usr/local/bin/tailscale-cert-renew.sh
    
    CERT_CRON="0 0 1 * * /usr/local/bin/tailscale-cert-renew.sh > /var/log/tailscale-cert-renew.log 2>&1"
    (crontab -l 2>/dev/null | grep -v "tailscale-cert-renew.sh" ; echo "$CERT_CRON") | crontab -
    
    log_success "Zertifikatserneuerungsskript aktualisiert."
fi

# Stelle sicher, dass der Monitoring-Cron-Job existiert
MONITOR_CRON="*/10 * * * * /usr/local/bin/caddy-monitor.sh >> /var/log/caddy-monitor.log 2>&1"
(crontab -l 2>/dev/null | grep -v "caddy-monitor.sh" ; echo "$MONITOR_CRON") | crontab -

log_success "Monitoring-Cron-Job aktualisiert."
log_success "Caddy-Konfiguration wurde erfolgreich aktualisiert."

# Zusammenfassung
log_message "===== Caddy-Konfiguration abgeschlossen ====="
log_message "Caddy wurde erfolgreich als Reverse Proxy für code-server konfiguriert."
log_message "Verwendete Domain: ${DOMAIN}"
log_message "Interne Domain für Code-Server: ${TS_DOMAIN}"
log_message "Code-Server-Port: ${CODE_SERVER_PORT}"
log_message "Zertifikat-Typ: $(if [ "${USE_TAILSCALE_CERT}" = true ]; then echo "Tailscale"; else echo "Selbstsigniert"; fi)"
log_message ""
log_message "Nächste Schritte:"
log_message "1. Zugriff über '${TS_DOMAIN}' testen"
log_message "2. Prüfen, ob Tailscale-DNS richtig konfiguriert ist:"
log_message "   tailscale up --accept-dns=true"
log_message ""
log_message "Logs:"
log_message "- Caddy-Logs: /var/log/caddy/access.log, /var/log/caddy/code-server.log"
log_message "- Monitoring-Log: /var/log/caddy-monitor.log"
if [ "${USE_TAILSCALE_CERT}" = true ]; then
    log_message "- Zertifikatserneuerung-Log: /var/log/tailscale-cert-renew.log"
fi