#!/bin/bash
#
# DevSystem - Caddy Tailscale-Auth-Snippet Fix
# Autor: DevSystem Team
# Datum: 2026-04-08
#
# Beschreibung: 
# Dieses Skript korrigiert das Tailscale-Auth-Snippet für Caddy.
# Der Fehler tritt auf, weil Anfrage-Matcher (@tailscale) nicht global 
# definiert werden dürfen, sondern in einem Site-Block stehen müssen.

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
AUTH_SNIPPET="${CADDY_DIR}/snippets/tailscale-auth.caddy"

log_message "Korrigiere Tailscale-Auth-Snippet..."

# Sichern der ursprünglichen Datei
cp "${AUTH_SNIPPET}" "${AUTH_SNIPPET}.bak"

# Korrigieren des Snippets
cat > "${AUTH_SNIPPET}" << 'EOF'
# Tailscale-Authentifizierung-Snippet
# Dieses Snippet muss innerhalb eines Site-Blocks importiert werden

# Nur Zugriff über Tailscale erlauben
@tailscale {
    remote_ip 100.64.0.0/10
}

# Zugriff verweigern, wenn nicht über Tailscale
respond @not_tailscale 403 {
    body "Zugriff nur über Tailscale erlaubt"
}

# HINWEIS: Die @not_tailscale Direktive muss vom Site-Block definiert werden.
# Füge diese Zeile zur Caddyfile-Konfiguration hinzu, NACHDEM dieses Snippet importiert wurde:
# @not_tailscale {
#     not remote_ip 100.64.0.0/10
# }
EOF

log_success "Tailscale-Auth-Snippet korrigiert."

# Korrigiere auch die code-server Site-Konfiguration
CODE_SERVER_SITE="${CADDY_DIR}/sites/code-server.caddy"

log_message "Korrigiere code-server Site-Konfiguration..."

# Sichern der ursprünglichen Datei
cp "${CODE_SERVER_SITE}" "${CODE_SERVER_SITE}.bak"

# Domain auslesen
TS_DOMAIN=$(grep -m 1 "^[^#].*{" "${CODE_SERVER_SITE}" | awk '{print $1}')

# TLS-Konfiguration auslesen
TLS_CONFIG=$(grep -A 1 "tls" "${CODE_SERVER_SITE}" | tail -1 | awk '{$1=$1};1')

# Code-Server-Port auslesen 
CODE_SERVER_PORT=$(grep -m 1 "reverse_proxy" "${CODE_SERVER_SITE}" | grep -o "localhost:[0-9]*" | cut -d ":" -f 2)

# Neue Site-Konfiguration erstellen
cat > "${CODE_SERVER_SITE}" << EOF
${TS_DOMAIN} {
    # Tailscale-Authentifizierung
    import /etc/caddy/snippets/tailscale-auth.caddy
    
    # Definiere @not_tailscale Matcher
    @not_tailscale {
        not remote_ip 100.64.0.0/10
    }
    
    # TLS-Konfiguration
    tls ${TLS_CONFIG}
    
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

log_success "code-server Site-Konfiguration korrigiert."

# Validiere die Caddy-Konfiguration
log_message "Validiere korrigierte Caddy-Konfiguration..."

if caddy validate --config "${CADDY_DIR}/Caddyfile" &>/dev/null; then
    log_success "Caddy-Konfiguration ist gültig."
    
    # Neustart von Caddy
    log_message "Starte Caddy-Dienst neu..."
    systemctl restart caddy
    
    if systemctl is-active --quiet caddy; then
        log_success "Caddy-Dienst wurde erfolgreich neu gestartet."
    else
        log_error "Caddy-Dienst konnte nicht gestartet werden."
        log_message "Prüfe die Details mit 'journalctl -u caddy'."
        exit 1
    fi
else
    log_error "Caddy-Konfiguration ist immer noch ungültig."
    log_message "Fehler in der Konfiguration:"
    caddy validate --config "${CADDY_DIR}/Caddyfile"
    exit 1
fi

log_success "Caddy-Konfiguration wurde erfolgreich korrigiert und Dienst neu gestartet."