#!/bin/bash
#
# DevSystem - Caddy Port-Korrektur auf Port 9443
# Autor: DevSystem Team
# Datum: 2026-04-08
#
# Beschreibung: 
# Dieses Skript konfiguriert Caddy auf Port 9443, da sowohl Port 443 (Tailscale) 
# als auch Port 8443 (Docker) bereits belegt sind.

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
CADDY_HTTPS_PORT="9443"

# Parameter verarbeiten
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --domain=*) DOMAIN="${1#*=}"; shift ;;
        --ts-domain=*) TS_DOMAIN="${1#*=}"; shift ;;
        --code-server-port=*) CODE_SERVER_PORT="${1#*=}"; shift ;;
        --caddy-https-port=*) CADDY_HTTPS_PORT="${1#*=}"; shift ;;
        *) log_error "Unbekannter Parameter: $1"; exit 1 ;;
    esac
done

log_message "Prüfe, ob Port ${CADDY_HTTPS_PORT} verfügbar ist..."
if ss -tulpn | grep ":${CADDY_HTTPS_PORT}" > /dev/null; then
    log_error "Port ${CADDY_HTTPS_PORT} ist bereits belegt. Bitte wähle einen anderen Port."
    log_message "Verwende --caddy-https-port=XXXX, um einen anderen Port zu wählen."
    exit 1
fi

log_message "Konfiguriere Caddy für Port ${CADDY_HTTPS_PORT}..."

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

# Erstelle die neue Konfiguration für Port 9443
log_message "Erstelle neue Caddyfile für Port ${CADDY_HTTPS_PORT}..."

cat > "${CADDY_DIR}/Caddyfile" << EOF
# Globale Optionen
{
    admin off
    log {
        output file /var/log/caddy/access.log
    }
}

# code-server Konfiguration auf Port ${CADDY_HTTPS_PORT}
:${CADDY_HTTPS_PORT} {
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
    
    # Host-basiertes Routing
    @code_server_host {
        host ${TS_DOMAIN}
    }
    
    handle @code_server_host {
        # Reverse Proxy zu code-server
        reverse_proxy @tailscale localhost:${CODE_SERVER_PORT} {
            header_up Connection {http.request.header.Connection}
            header_up Upgrade {http.request.header.Upgrade}
        }
    }
    
    # Standard-Antwort für nicht übereinstimmende Host-Header
    handle {
        respond "DevSystem Caddy Server" 200
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

log_success "Neue Caddyfile für Port ${CADDY_HTTPS_PORT} erstellt."

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
        
        # Zeige an, dass der Dienst läuft und auf welchem Port
        log_message "Caddy läuft und hört auf Port ${CADDY_HTTPS_PORT}:"
        ss -tulpn | grep caddy | grep ":${CADDY_HTTPS_PORT}"
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

# Öffne den Port in der Firewall, falls UFW aktiv ist
if command -v ufw &> /dev/null && ufw status | grep -q "active"; then
    log_message "Öffne Port ${CADDY_HTTPS_PORT} in der Firewall..."
    ufw allow ${CADDY_HTTPS_PORT}/tcp comment "Caddy HTTPS"
    log_success "Firewall-Regel hinzugefügt."
fi

log_success "Monitoring-Cron-Job aktualisiert."
log_success "Caddy-Konfiguration wurde erfolgreich aktualisiert."

# Zusammenfassung
log_message "===== Caddy-Konfiguration abgeschlossen ====="
log_message "Caddy wurde erfolgreich als Reverse Proxy für code-server konfiguriert."
log_message "Verwendete Domain: ${DOMAIN}"
log_message "Interne Domain für Code-Server: ${TS_DOMAIN}"
log_message "Caddy HTTPS-Port: ${CADDY_HTTPS_PORT}"
log_message "Code-Server-Port: ${CODE_SERVER_PORT}"
log_message "Zertifikat-Typ: $(if [ "${USE_TAILSCALE_CERT}" = true ]; then echo "Tailscale"; else echo "Selbstsigniert"; fi)"
log_message ""
log_message "WICHTIG: Caddy läuft auf Port ${CADDY_HTTPS_PORT} statt dem Standard-Port 443,"
log_message "da Port 443 von Tailscale und Port 8443 von einem Docker-Container bereits verwendet werden."
log_message ""
log_message "Zugriff über: https://${TS_DOMAIN}:${CADDY_HTTPS_PORT}"
log_message ""
log_message "Nächste Schritte:"
log_message "1. Zugriff über '${TS_DOMAIN}:${CADDY_HTTPS_PORT}' testen"
log_message "2. Prüfen, ob Tailscale-DNS richtig konfiguriert ist:"
log_message "   tailscale up --accept-dns=true"
log_message ""
log_message "Logs:"
log_message "- Caddy-Logs: /var/log/caddy/access.log, /var/log/caddy/code-server.log"
log_message "- Monitoring-Log: /var/log/caddy-monitor.log"
if [ "${USE_TAILSCALE_CERT}" = true ]; then
    log_message "- Zertifikatserneuerung-Log: /var/log/tailscale-cert-renew.log"
fi