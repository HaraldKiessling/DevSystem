#!/bin/bash
# ==========================================
# SSH-Diagnose-Script für QS-VPS
# ==========================================
# Prüft: Tailscale-Verbindung, SSH-Port-Erreichbarkeit, Service-Status
# Gibt klare Diagnose und Lösungsvorschläge aus
#
# Usage:
#   bash scripts/qs/diagnose-ssh-vps.sh --host=100.100.221.56
#   bash scripts/qs/diagnose-ssh-vps.sh --host=100.100.221.56 --port=22
#   bash scripts/qs/diagnose-ssh-vps.sh --host=100.100.221.56 --user=root
#
# Exit Codes:
#   0 - SSH vollständig funktionsfähig
#   1 - SSH nicht erreichbar (Port blockiert/Service down)
#   2 - Tailscale-Verbindung fehlgeschlagen
#   3 - Ungültige Parameter
# ==========================================

set -euo pipefail

# ==========================================
# Farben für Terminal-Output
# ==========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ==========================================
# Default-Werte
# ==========================================
TARGET_HOST=""
SSH_PORT="22"
SSH_USER="root"
TIMEOUT_SECONDS=5

# ==========================================
# Logging-Funktionen
# ==========================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}$1${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ==========================================
# Argument-Parsing
# ==========================================
show_usage() {
    cat << EOF
${BOLD}SSH-Diagnose-Script für QS-VPS${NC}

${BOLD}Usage:${NC}
  bash scripts/qs/diagnose-ssh-vps.sh --host=<IP> [OPTIONS]

${BOLD}Optionen:${NC}
  --host=<IP|FQDN>   Target-Host (Tailscale-IP oder FQDN) [REQUIRED]
  --port=<PORT>      SSH-Port (Standard: 22)
  --user=<USER>      SSH-User (Standard: root)
  --timeout=<SEC>    Connection-Timeout in Sekunden (Standard: 5)
  --help             Diese Hilfe anzeigen

${BOLD}Beispiele:${NC}
  bash scripts/qs/diagnose-ssh-vps.sh --host=100.100.221.56
  bash scripts/qs/diagnose-ssh-vps.sh --host=100.100.221.56 --port=2222
  bash scripts/qs/diagnose-ssh-vps.sh --host=devsystem-vps.tailcfea8a.ts.net --user=root

${BOLD}Exit Codes:${NC}
  0 - SSH vollständig funktionsfähig
  1 - SSH nicht erreichbar (Port blockiert/Service down)
  2 - Tailscale-Verbindung fehlgeschlagen
  3 - Ungültige Parameter
EOF
}

parse_args() {
    for arg in "$@"; do
        case $arg in
            --host=*)
                TARGET_HOST="${arg#*=}"
                ;;
            --port=*)
                SSH_PORT="${arg#*=}"
                ;;
            --user=*)
                SSH_USER="${arg#*=}"
                ;;
            --timeout=*)
                TIMEOUT_SECONDS="${arg#*=}"
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unbekannter Parameter: $arg"
                show_usage
                exit 3
                ;;
        esac
    done

    # Validierung
    if [[ -z "$TARGET_HOST" ]]; then
        log_error "Parameter --host ist erforderlich!"
        show_usage
        exit 3
    fi
}

# ==========================================
# Diagnose-Funktionen
# ==========================================

diagnose_tailscale() {
    log_section "1. Tailscale-Verbindung prüfen"
    
    # Tailscale-Dienst prüfen
    if systemctl is-active --quiet tailscaled; then
        log_success "tailscaled Service ist aktiv"
    else
        log_error "tailscaled Service ist NICHT aktiv"
        log_warning "Lösung: sudo systemctl start tailscaled"
        return 2
    fi

    # Tailscale-Status prüfen
    if tailscale status &>/dev/null; then
        log_success "Tailscale ist verbunden"
        
        # Zeige Tailscale-Peers
        if tailscale status | grep -q "$TARGET_HOST"; then
            log_success "Target-Host '$TARGET_HOST' ist im Tailscale-Netzwerk sichtbar"
            local peer_info=$(tailscale status | grep "$TARGET_HOST")
            log_info "Peer-Info: $peer_info"
        else
            log_warning "Target-Host '$TARGET_HOST' NICHT in Tailscale-Peer-Liste gefunden"
            log_info "Verfügbare Peers:"
            tailscale status | grep -E "^\s*[0-9]" | sed 's/^/  /'
        fi
    else
        log_error "Tailscale ist NICHT verbunden"
        log_warning "Lösung: tailscale up"
        return 2
    fi

    # Ping-Test
    log_info "Ping-Test zu $TARGET_HOST..."
    if ping -c 3 -W "$TIMEOUT_SECONDS" "$TARGET_HOST" &>/dev/null; then
        local ping_stats=$(ping -c 3 -W "$TIMEOUT_SECONDS" "$TARGET_HOST" 2>&1 | tail -1)
        log_success "Ping erfolgreich: $ping_stats"
    else
        log_error "Ping fehlgeschlagen zu $TARGET_HOST"
        log_warning "Host ist nicht erreichbar oder antwortet nicht auf ICMP"
        return 2
    fi

    return 0
}

diagnose_ssh_port() {
    log_section "2. SSH-Port-Erreichbarkeit prüfen (Port $SSH_PORT)"
    
    # Port-Scan mit nc (netcat)
    if command -v nc &>/dev/null; then
        log_info "Teste Port $SSH_PORT mit netcat..."
        if timeout "$TIMEOUT_SECONDS" nc -zv "$TARGET_HOST" "$SSH_PORT" 2>&1 | grep -q "succeeded"; then
            log_success "Port $SSH_PORT ist OFFEN auf $TARGET_HOST"
        else
            log_error "Port $SSH_PORT ist GESCHLOSSEN oder GEFILTERT auf $TARGET_HOST"
            return 1
        fi
    fi

    # Alternative: Port-Scan mit timeout+bash
    if ! command -v nc &>/dev/null; then
        log_info "Teste Port $SSH_PORT mit bash-socket..."
        if timeout "$TIMEOUT_SECONDS" bash -c "echo > /dev/tcp/$TARGET_HOST/$SSH_PORT" 2>/dev/null; then
            log_success "Port $SSH_PORT ist OFFEN auf $TARGET_HOST"
        else
            log_error "Port $SSH_PORT ist GESCHLOSSEN oder GEFILTERT auf $TARGET_HOST"
            return 1
        fi
    fi

    return 0
}

diagnose_ssh_connection() {
    log_section "3. SSH-Verbindung testen"
    
    # SSH-Key prüfen
    local ssh_key_path="$HOME/.ssh/id_ed25519"
    if [[ -f "$ssh_key_path" ]]; then
        log_success "SSH-Key gefunden: $ssh_key_path"
    else
        log_warning "SSH-Key NICHT gefunden: $ssh_key_path"
        log_info "Teste SSH mit Password-Auth oder anderen Keys..."
        ssh_key_path=""
    fi

    # SSH-Verbindungstest mit echo
    log_info "Teste SSH-Verbindung: ssh $SSH_USER@$TARGET_HOST -p $SSH_PORT"
    
    local ssh_opts="-o ConnectTimeout=$TIMEOUT_SECONDS -o BatchMode=yes -o StrictHostKeyChecking=no"
    if [[ -n "$ssh_key_path" ]]; then
        ssh_opts="$ssh_opts -i $ssh_key_path"
    fi

    local ssh_output
    if ssh_output=$(ssh $ssh_opts "$SSH_USER@$TARGET_HOST" -p "$SSH_PORT" "echo 'SSH_CONNECTION_SUCCESS'" 2>&1); then
        if echo "$ssh_output" | grep -q "SSH_CONNECTION_SUCCESS"; then
            log_success "SSH-Verbindung erfolgreich!"
            log_success "Remote-Command-Execution funktioniert"
            return 0
        else
            log_warning "SSH-Verbindung möglich, aber Command-Output unerwartet:"
            echo "$ssh_output" | sed 's/^/  /'
            return 0
        fi
    else
        log_error "SSH-Verbindung fehlgeschlagen!"
        log_error "Fehler-Details:"
        echo "$ssh_output" | sed 's/^/  /' | head -20
        return 1
    fi
}

diagnose_tailscale_ssh() {
    log_section "4. Tailscale SSH prüfen"
    
    # Prüfe ob Tailscale SSH aktiviert ist
    log_info "Prüfe Tailscale SSH-Feature..."
    if tailscale status --json 2>/dev/null | grep -q '"RunSSH":true'; then
        log_success "Tailscale SSH ist AKTIVIERT"
        
        # Teste Tailscale SSH
        log_info "Teste Tailscale SSH-Verbindung..."
        if timeout "$TIMEOUT_SECONDS" tailscale ssh "$SSH_USER@$TARGET_HOST" "echo 'TAILSCALE_SSH_SUCCESS'" 2>&1 | grep -q "TAILSCALE_SSH_SUCCESS"; then
            log_success "Tailscale SSH funktioniert!"
            return 0
        else
            log_error "Tailscale SSH schlägt fehl"
            return 1
        fi
    else
        log_warning "Tailscale SSH ist NICHT aktiviert"
        log_info "Hinweis: Kann auf dem VPS mit 'tailscale set --ssh' aktiviert werden"
        return 1
    fi
}

generate_diagnosis_report() {
    local tailscale_status=$1
    local port_status=$2
    local ssh_status=$3
    local ts_ssh_status=$4

    log_section "🔍 Diagnose-Zusammenfassung"

    echo ""
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│                  SSH-DIAGNOSE-REPORT                    │"
    echo "├─────────────────────────────────────────────────────────┤"
    echo "│ Host:        $TARGET_HOST"
    echo "│ Port:        $SSH_PORT"
    echo "│ User:        $SSH_USER"
    echo "│ Timestamp:   $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    echo "├─────────────────────────────────────────────────────────┤"
    
    if [[ $tailscale_status -eq 0 ]]; then
        echo "│ Tailscale:   ${GREEN}✓ Funktionsfähig${NC}"
    else
        echo "│ Tailscale:   ${RED}✗ Fehlgeschlagen${NC}"
    fi
    
    if [[ $port_status -eq 0 ]]; then
        echo "│ Port $SSH_PORT:     ${GREEN}✓ Offen${NC}"
    else
        echo "│ Port $SSH_PORT:     ${RED}✗ Geschlossen/Gefiltert${NC}"
    fi
    
    if [[ $ssh_status -eq 0 ]]; then
        echo "│ SSH:         ${GREEN}✓ Verbindung erfolgreich${NC}"
    else
        echo "│ SSH:         ${RED}✗ Verbindung fehlgeschlagen${NC}"
    fi
    
    if [[ $ts_ssh_status -eq 0 ]]; then
        echo "│ TS SSH:      ${GREEN}✓ Funktioniert${NC}"
    elif [[ $ts_ssh_status -eq 1 ]]; then
        echo "│ TS SSH:      ${YELLOW}⚠ Nicht aktiviert/Fehlgeschlagen${NC}"
    fi
    
    echo "└─────────────────────────────────────────────────────────┘"
    echo ""
}

generate_solutions() {
    local tailscale_status=$1
    local port_status=$2
    local ssh_status=$3

    log_section "💡 Empfohlene Lösungen"

    if [[ $ssh_status -eq 0 ]]; then
        log_success "SSH funktioniert vollständig! Keine weiteren Aktionen erforderlich."
        return 0
    fi

    # Tailscale-Problem
    if [[ $tailscale_status -ne 0 ]]; then
        echo ""
        log_error "Problem 1: Tailscale-Verbindung"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Lösungsschritte:"
        echo "  1. Tailscale-Service starten:"
        echo "     ${CYAN}sudo systemctl start tailscaled${NC}"
        echo ""
        echo "  2. Tailscale verbinden:"
        echo "     ${CYAN}tailscale up${NC}"
        echo ""
        echo "  3. Status prüfen:"
        echo "     ${CYAN}tailscale status${NC}"
        echo ""
    fi

    # Port-Problem
    if [[ $port_status -ne 0 ]] && [[ $tailscale_status -eq 0 ]]; then
        echo ""
        log_error "Problem 2: SSH-Port $SSH_PORT nicht erreichbar"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Mögliche Ursachen & Lösungen:"
        echo ""
        echo "${BOLD}A) SSH-Dienst ist nicht gestartet (HÄUFIGSTE URSACHE)${NC}"
        echo "   Auf dem VPS ausführen (z.B. via IONOS Console/VNC):"
        echo "   ${CYAN}# Prüfen ob SSH installiert ist${NC}"
        echo "   ${CYAN}systemctl status ssh || systemctl status sshd${NC}"
        echo ""
        echo "   ${CYAN}# SSH aktivieren und starten${NC}"
        echo "   ${CYAN}sudo systemctl enable --now ssh${NC}"
        echo ""
        echo "   ${CYAN}# Status prüfen${NC}"
        echo "   ${CYAN}sudo systemctl status ssh${NC}"
        echo ""
        echo "${BOLD}B) Firewall blockiert Port $SSH_PORT${NC}"
        echo "   Auf dem VPS ausführen:"
        echo "   ${CYAN}# UFW-Status prüfen${NC}"
        echo "   ${CYAN}sudo ufw status${NC}"
        echo ""
        echo "   ${CYAN}# Port 22 für Tailscale-Netz freigeben (EMPFOHLEN)${NC}"
        echo "   ${CYAN}sudo ufw allow from 100.64.0.0/10 to any port 22 comment 'SSH via Tailscale'${NC}"
        echo ""
        echo "   ${CYAN}# Alternativ: Port 22 komplett freigeben (weniger sicher)${NC}"
        echo "   ${CYAN}sudo ufw allow 22/tcp${NC}"
        echo ""
        echo "${BOLD}C) SSH läuft auf anderem Port${NC}"
        echo "   Auf dem VPS prüfen:"
        echo "   ${CYAN}sudo grep '^Port' /etc/ssh/sshd_config${NC}"
        echo ""
        echo "   Falls ein anderer Port konfiguriert ist (z.B. 2222):"
        echo "   ${CYAN}bash scripts/qs/diagnose-ssh-vps.sh --host=$TARGET_HOST --port=2222${NC}"
        echo ""
        echo "${BOLD}D) Tailscale SSH verwenden (Alternative)${NC}"
        echo "   Auf dem VPS:"
        echo "   ${CYAN}tailscale set --ssh${NC}"
        echo ""
        echo "   Dann SSH via Tailscale:"
        echo "   ${CYAN}tailscale ssh $SSH_USER@$TARGET_HOST${NC}"
        echo ""
    fi

    # SSH-Verbindungs-Problem (Port offen, aber SSH schlägt fehl)
    if [[ $port_status -eq 0 ]] && [[ $ssh_status -ne 0 ]]; then
        echo ""
        log_error "Problem 3: SSH-Port ist offen, aber Verbindung schlägt fehl"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Mögliche Ursachen & Lösungen:"
        echo ""
        echo "${BOLD}A) SSH-Key-Authentifizierung schlägt fehl${NC}"
        echo "   SSH-Key auf VPS kopieren:"
        echo "   ${CYAN}ssh-copy-id -i ~/.ssh/id_ed25519.pub $SSH_USER@$TARGET_HOST${NC}"
        echo ""
        echo "   Oder manuell in authorized_keys eintragen:"
        echo "   ${CYAN}cat ~/.ssh/id_ed25519.pub${NC}"
        echo "   (Dann auf VPS in ~/.ssh/authorized_keys einfügen)"
        echo ""
        echo "${BOLD}B) Password-Authentifizierung deaktiviert${NC}"
        echo "   Auf VPS /etc/ssh/sshd_config prüfen:"
        echo "   ${CYAN}grep 'PasswordAuthentication' /etc/ssh/sshd_config${NC}"
        echo ""
        echo "   Falls 'no', dann aktivieren (temporär für Setup):"
        echo "   ${CYAN}sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config${NC}"
        echo "   ${CYAN}sudo systemctl restart ssh${NC}"
        echo ""
        echo "${BOLD}C) Root-Login ist deaktiviert${NC}"
        echo "   Auf VPS /etc/ssh/sshd_config prüfen:"
        echo "   ${CYAN}grep 'PermitRootLogin' /etc/ssh/sshd_config${NC}"
        echo ""
        echo "   Falls 'no' oder 'prohibit-password', dann für Setup aktivieren:"
        echo "   ${CYAN}sudo sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config${NC}"
        echo "   ${CYAN}sudo systemctl restart ssh${NC}"
        echo ""
    fi

    echo ""
    log_info "Detaillierte Anleitung: VPS-SSH-FIX-GUIDE.md"
    echo ""
}

# ==========================================
# Main
# ==========================================
main() {
    log_section "SSH-Diagnose für QS-VPS"
    echo "Target: $TARGET_HOST:$SSH_PORT (User: $SSH_USER)"
    echo "Timeout: $TIMEOUT_SECONDS Sekunden"
    echo ""

    # Diagnose-Tests durchführen
    local tailscale_status=0
    local port_status=0
    local ssh_status=0
    local ts_ssh_status=0

    diagnose_tailscale || tailscale_status=$?
    diagnose_ssh_port || port_status=$?
    diagnose_ssh_connection || ssh_status=$?
    diagnose_tailscale_ssh || ts_ssh_status=$?

    # Report generieren
    generate_diagnosis_report "$tailscale_status" "$port_status" "$ssh_status" "$ts_ssh_status"
    generate_solutions "$tailscale_status" "$port_status" "$ssh_status"

    # Exit-Code bestimmen
    if [[ $ssh_status -eq 0 ]]; then
        log_section "✅ Diagnose abgeschlossen: SSH funktioniert!"
        exit 0
    elif [[ $tailscale_status -ne 0 ]]; then
        log_section "❌ Diagnose abgeschlossen: Tailscale-Problem"
        exit 2
    else
        log_section "❌ Diagnose abgeschlossen: SSH nicht erreichbar"
        exit 1
    fi
}

# Script Entry Point
parse_args "$@"
main
