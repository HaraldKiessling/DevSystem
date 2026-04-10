#!/bin/bash
set -euo pipefail

# QS-VPS Setup Script
# Vollautomatisches Setup mit Tailscale + Basis-Security

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/qs-vps-setup.log"
AUTHKEY_FILE="${SCRIPT_DIR}/tailscale-authkey.txt"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Prüfe Root
if [[ $EUID -ne 0 ]]; then
   error "Dieses Script muss als root ausgeführt werden"
fi

log "QS-VPS Setup gestartet"

# 1. Auth Key laden
if [[ ! -f "$AUTHKEY_FILE" ]]; then
    error "Auth Key Datei nicht gefunden: $AUTHKEY_FILE"
fi

TAILSCALE_AUTHKEY=$(cat "$AUTHKEY_FILE" | tr -d '[:space:]')

if [[ -z "$TAILSCALE_AUTHKEY" || "$TAILSCALE_AUTHKEY" == "YOUR_TAILSCALE_AUTH_KEY_HERE" ]]; then
    error "Auth Key nicht konfiguriert in $AUTHKEY_FILE"
fi

log "Auth Key geladen: ${TAILSCALE_AUTHKEY:0:20}..."

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

# 5. Tailscale starten
log "Tailscale verbinden..."
tailscale up --authkey="$TAILSCALE_AUTHKEY" --hostname=devsystem-qs-vps --ssh

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
log "SSH: ssh root@$TAILSCALE_IP"
log ""
log "Nächste Schritte:"
log "  - Caddy: bash scripts/qs/install-caddy-qs.sh"
log "  - code-server: bash scripts/qs/install-code-server-qs.sh"
log "  - Qdrant: bash scripts/qs/deploy-qdrant-qs.sh"
