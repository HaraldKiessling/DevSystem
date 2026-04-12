#!/bin/bash
set -euo pipefail

# QS-VPS Setup Script
# Vollautomatisches Setup mit Tailscale OAuth (+ Auth Key Fallback) + Basis-Security
# Version: 2.0 - OAuth Support

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/qs-vps-setup.log"
AUTHKEY_FILE="${SCRIPT_DIR}/tailscale-authkey.txt"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

# Prüfe Root
if [[ $EUID -ne 0 ]]; then
   error "Dieses Script muss als root ausgeführt werden"
fi

log "QS-VPS Setup gestartet (OAuth + Auth Key Support)"

# 1. Tailscale-Authentifizierungsmethode erkennen
detect_auth_method() {
    local oauth_client_id="${TAILSCALE_OAUTH_CLIENT_ID:-}"
    local oauth_secret="${TAILSCALE_OAUTH_SECRET:-}"
    local auth_key="${TAILSCALE_AUTHKEY:-}"
    
    if [[ -n "$oauth_client_id" ]] && [[ -n "$oauth_secret" ]]; then
        echo "oauth"
    elif [[ -n "$auth_key" ]]; then
        echo "authkey"
    else
        echo "none"
    fi
}

# OAuth-Authentifizierung mit Tailscale
tailscale_oauth_auth() {
    local client_id="$1"
    local client_secret="$2"
    
    info "Verwende OAuth-Authentifizierung (permanente Lösung)"
    
    # OAuth-Token abrufen
    local token_response=$(curl -s -d "client_id=${client_id}" \
                                -d "client_secret=${client_secret}" \
                                -d "grant_type=client_credentials" \
                                https://api.tailscale.com/api/v2/oauth/token)
    
    local access_token=$(echo "$token_response" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)
    
    if [[ -z "$access_token" ]]; then
        error "OAuth-Token konnte nicht abgerufen werden"
    fi
    
    log "OAuth-Token erfolgreich abgerufen"
    
    # Tailscale mit OAuth verbinden
    export TS_AUTHKEY="$access_token"
    tailscale up --auth-key="$access_token" --hostname=devsystem-qs-vps --ssh
    
    log "✓ Tailscale mit OAuth verbunden (permanente Authentifizierung)"
}

# Auth Key-Authentifizierung mit Tailscale (Fallback)
tailscale_authkey_auth() {
    local auth_key="$1"
    
    warn "Verwende Auth Key-Authentifizierung (läuft nach 90 Tagen ab)"
    warn "Empfehlung: Wechsel zu OAuth für permanente Authentifizierung"
    warn "Guide: docs/operations/TAILSCALE-OAUTH-MIGRATION-GUIDE.md"
    
    tailscale up --authkey="$auth_key" --hostname=devsystem-qs-vps --ssh
    
    log "✓ Tailscale mit Auth Key verbunden (90 Tage gültig)"
}

# 1a. Umgebungsvariablen oder Auth Key Datei prüfen
TAILSCALE_OAUTH_CLIENT_ID="${TAILSCALE_OAUTH_CLIENT_ID:-}"
TAILSCALE_OAUTH_SECRET="${TAILSCALE_OAUTH_SECRET:-}"
TAILSCALE_AUTHKEY="${TAILSCALE_AUTHKEY:-}"

# Auth Key aus Datei laden, falls in env nicht gesetzt
if [[ -z "$TAILSCALE_AUTHKEY" ]] && [[ -f "$AUTHKEY_FILE" ]]; then
    TAILSCALE_AUTHKEY=$(cat "$AUTHKEY_FILE" | tr -d '[:space:]')
    
    # Template-Check
    if [[ "$TAILSCALE_AUTHKEY" == "YOUR_TAILSCALE_AUTH_KEY_HERE" ]]; then
        TAILSCALE_AUTHKEY=""
    fi
fi

# 1b. Methode erkennen
AUTH_METHOD=$(detect_auth_method)

case "$AUTH_METHOD" in
    oauth)
        info "Erkannte Methode: OAuth (empfohlen)"
        info "OAuth Client ID: ${TAILSCALE_OAUTH_CLIENT_ID:0:20}..."
        ;;
    authkey)
        info "Erkannte Methode: Auth Key (Fallback)"
        info "Auth Key: ${TAILSCALE_AUTHKEY:0:20}..."
        ;;
    none)
        error "Keine Tailscale-Authentifizierung konfiguriert!

Bitte eine der folgenden Methoden einrichten:

Option 1 (EMPFOHLEN): OAuth - Permanente Authentifizierung
  export TAILSCALE_OAUTH_CLIENT_ID='...'
  export TAILSCALE_OAUTH_SECRET='...'
  
  Setup-Guide: docs/operations/TAILSCALE-OAUTH-MIGRATION-GUIDE.md

Option 2 (Fallback): Auth Key - 90 Tage gültig
  export TAILSCALE_AUTHKEY='tskey-auth-...'
  
  oder in Datei: $AUTHKEY_FILE"
        ;;
esac

# 2. System Updates
log "System-Updates durchführen..."
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq curl ufw fail2ban

# 3. Hostname setzen
log "Hostname setzen..."
hostnamectl set-hostname devsystem-qs-vps

# 4. Tailscale installieren
log "Tailscale installieren..."
if ! command -v tailscale &> /dev/null; then
    curl -fsSL https://tailscale.com/install.sh | sh
else
    log "Tailscale bereits installiert"
fi

# 5. Tailscale starten (mit automatischer Methoden-Erkennung)
log "Tailscale verbinden..."

case "$AUTH_METHOD" in
    oauth)
        tailscale_oauth_auth "$TAILSCALE_OAUTH_CLIENT_ID" "$TAILSCALE_OAUTH_SECRET"
        ;;
    authkey)
        tailscale_authkey_auth "$TAILSCALE_AUTHKEY"
        ;;
esac

# 6. Tailscale-IP speichern
TAILSCALE_IP=$(tailscale ip -4)
echo "$TAILSCALE_IP" > /root/tailscale-ip.txt
log "Tailscale-IP: $TAILSCALE_IP"

# 7. UFW Firewall konfigurieren
log "Firewall konfigurieren..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow in on tailscale0 to any port 22 comment 'SSH via Tailscale'
ufw allow 41641/udp comment 'Tailscale VPN'
ufw --force enable

# 8. Fail2ban aktivieren
log "Fail2ban aktivieren..."
systemctl enable fail2ban
systemctl start fail2ban

log "Setup abgeschlossen!"
log "Tailscale-IP: $TAILSCALE_IP"
log "Authentifizierungsmethode: $AUTH_METHOD"
log "SSH: ssh root@$TAILSCALE_IP"
log ""

if [[ "$AUTH_METHOD" == "authkey" ]]; then
    warn "⚠ Auth Key läuft nach 90 Tagen ab!"
    warn "Migration zu OAuth empfohlen: docs/operations/TAILSCALE-OAUTH-MIGRATION-GUIDE.md"
    warn ""
fi

log "Nächste Schritte:"
log "  - Caddy: bash scripts/qs/install-caddy-qs.sh"
log "  - code-server: bash scripts/qs/install-code-server-qs.sh"
log "  - Qdrant: bash scripts/qs/deploy-qdrant-qs.sh"
log ""
log "Server ist jetzt einsatzbereit!"
