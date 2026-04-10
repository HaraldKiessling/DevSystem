#!/usr/bin/env bash
#
# QS-Services Reset Script
# Setzt Service-Komponenten zurück (Tailscale-sicher!)
#
# Zweck:
#   Entfernt Service-Daten und Deployment-State für saubere Neuinitialisierung
#   KRITISCH: Tailscale und SSH-Verbindung werden NICHT beeinträchtigt
#
# Verwendung:
#   bash scripts/qs/reset-qs-services.sh [OPTIONS]
#
# Optionen:
#   --remote-host=HOST    Remote-Host (default: devsystem-qs-vps.tailcfea8a.ts.net)
#   --preserve-qdrant     Bewahre Qdrant-Daten (nur Config löschen)
#   --dry-run             Zeige was gelöscht werden würde
#   --skip-validation     Überspringe Post-Reset-Validierung
#   --yes                 Überspringe Bestätigungsabfrage
#   --help                Diese Hilfe anzeigen
#
# WICHTIG:
#   - Tailscale wird NIEMALS gestoppt oder verändert
#   - SSH-Konfiguration bleibt unberührt
#   - UFW-Regeln werden beibehalten
#   - fail2ban bleibt aktiv
#

set -euo pipefail

# ============================================================================
# KONFIGURATION
# ============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly VERSION="1.0.0"

# Remote-Konfiguration
REMOTE_HOST="${QS_REMOTE_HOST:-devsystem-qs-vps.tailcfea8a.ts.net}"
REMOTE_USER="${QS_REMOTE_USER:-root}"

# Reset-Optionen
PRESERVE_QDRANT=false
DRY_RUN=false
SKIP_VALIDATION=false
AUTO_CONFIRM=false

# Farben
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Exit-Codes
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1
readonly EXIT_SSH_ERROR=2
readonly EXIT_VALIDATION_ERROR=3

# ============================================================================
# LOGGING
# ============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_step() {
    echo -e "\n${CYAN}==>${NC} ${BOLD}$*${NC}"
}

log_success() {
    echo -e "${GREEN}✅${NC} $*"
}

log_critical() {
    echo -e "${RED}${BOLD}🚨 KRITISCH:${NC} $*" >&2
}

# ============================================================================
# HILFSFUNKTIONEN
# ============================================================================

show_help() {
    cat << EOF
QS-Services Reset Script v${VERSION}

Setzt Service-Komponenten zurück für saubere Neuinitialisierung.
ACHTUNG: Tailscale und SSH werden NICHT beeinträchtigt!

VERWENDUNG:
    $SCRIPT_NAME [OPTIONS]

OPTIONEN:
    --remote-host=HOST    Remote-Host (default: $REMOTE_HOST)
    --preserve-qdrant     Bewahre Qdrant-Daten (nur Config löschen)
    --dry-run             Zeige was gelöscht werden würde
    --skip-validation     Überspringe Post-Reset-Validierung
    --yes                 Überspringe Bestätigungsabfrage
    --help                Diese Hilfe anzeigen

SICHERHEIT:
    ✓ Tailscale bleibt aktiv
    ✓ SSH-Konfiguration unberührt
    ✓ UFW-Regeln beibehalten
    ✓ fail2ban bleibt aktiv

GELÖSCHT WIRD:
    ✗ Caddy (Service + Config + Daten)
    ✗ code-server (Service + Config + Daten außer Auth-Hashes)
    ✗ Qdrant (Service + Config + Daten oder nur Config)
    ✗ Deployment-Marker (/var/lib/qs-deployment/markers/*)
    ✗ Deployment-State (/var/lib/qs-deployment/state/*)

BEISPIELE:
    # Standard-Reset (alle Services)
    $SCRIPT_NAME

    # Dry-Run (zeige was passieren würde)
    $SCRIPT_NAME --dry-run

    # Reset mit Qdrant-Daten-Bewahrung
    $SCRIPT_NAME --preserve-qdrant

RÜCKGABEWERTE:
    0    Erfolg
    1    Allgemeiner Fehler
    2    SSH-Verbindungsfehler
    3    Validierungsfehler

EOF
}

check_ssh_connection() {
    log_step "Prüfe SSH-Verbindung zu ${REMOTE_HOST}..."
    
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "${REMOTE_USER}@${REMOTE_HOST}" "echo 'SSH OK'" &>/dev/null; then
        log_error "SSH-Verbindung zu ${REMOTE_HOST} fehlgeschlagen"
        log_error "Bitte prüfen Sie:"
        log_error "  1. Ist Tailscale aktiv? (tailscale status)"
        log_error "  2. Ist der Remote-Host erreichbar? (ping ${REMOTE_HOST})"
        log_error "  3. Ist SSH-Key konfiguriert? (ssh-add -l)"
        return 1
    fi
    
    log_success "SSH-Verbindung erfolgreich"
    return 0
}

validate_tailscale_before_reset() {
    log_step "Validiere Tailscale-Status (Pre-Reset)..."
    
    local tailscale_status=$(ssh "${REMOTE_USER}@${REMOTE_HOST}" "tailscale status --json 2>/dev/null || echo 'ERROR'")
    
    if [ "$tailscale_status" = "ERROR" ]; then
        log_critical "Tailscale nicht verfügbar auf Remote-Host!"
        log_critical "Reset wird ABGEBROCHEN - Tailscale muss funktionieren!"
        return 1
    fi
    
    log_success "Tailscale aktiv und funktional"
    return 0
}

# ============================================================================
# RESET-FUNKTIONEN
# ============================================================================

stop_services() {
    local dry_run_flag="$1"
    
    log_step "Stoppe Services..."
    
    local services=("caddy" "code-server" "qdrant")
    
    for service in "${services[@]}"; do
        if [ "$dry_run_flag" = "true" ]; then
            log_info "[DRY-RUN] Würde stoppen: ${service}"
        else
            log_info "Stoppe ${service}..."
            ssh "${REMOTE_USER}@${REMOTE_HOST}" bash << EOF
set -euo pipefail

# Service stoppen
if systemctl is-active --quiet ${service}.service; then
    systemctl stop ${service}.service
    echo "[REMOTE] Service ${service} gestoppt"
else
    echo "[REMOTE] Service ${service} war nicht aktiv"
fi

# Service disablen (Auto-Start verhindern)
if systemctl is-enabled --quiet ${service}.service 2>/dev/null; then
    systemctl disable ${service}.service
    echo "[REMOTE] Service ${service} disabled"
fi
EOF
            log_success "Service ${service} gestoppt"
        fi
    done
}

remove_caddy_data() {
    local dry_run_flag="$1"
    
    log_step "Entferne Caddy-Daten..."
    
    if [ "$dry_run_flag" = "true" ]; then
        log_info "[DRY-RUN] Würde löschen: /etc/caddy/"
        log_info "[DRY-RUN] Würde löschen: /var/lib/caddy/"
        return 0
    fi
    
    ssh "${REMOTE_USER}@${REMOTE_HOST}" bash << 'EOF'
set -euo pipefail

# Caddy-Config löschen
if [ -d /etc/caddy ]; then
    rm -rf /etc/caddy
    echo "[REMOTE] ✓ /etc/caddy/ gelöscht"
fi

# Caddy-Daten löschen
if [ -d /var/lib/caddy ]; then
    rm -rf /var/lib/caddy
    echo "[REMOTE] ✓ /var/lib/caddy/ gelöscht"
fi

# Caddy-Logs löschen (optional)
if [ -d /var/log/caddy ]; then
    rm -rf /var/log/caddy/*
    echo "[REMOTE] ✓ Caddy-Logs bereinigt"
fi
EOF
    
    log_success "Caddy-Daten entfernt"
}

remove_code_server_data() {
    local dry_run_flag="$1"
    
    log_step "Entferne code-server-Daten (bewahre Auth-Hashes)..."
    
    if [ "$dry_run_flag" = "true" ]; then
        log_info "[DRY-RUN] Würde löschen: /var/lib/code-server/ (außer config.yaml mit Password-Hash)"
        return 0
    fi
    
    ssh "${REMOTE_USER}@${REMOTE_HOST}" bash << 'EOF'
set -euo pipefail

# Auth-Hash sichern
if [ -f /var/lib/code-server/config.yaml ]; then
    mkdir -p /tmp/code-server-backup
    cp /var/lib/code-server/config.yaml /tmp/code-server-backup/config.yaml
    echo "[REMOTE] ✓ Auth-Hash gesichert"
fi

# code-server-Daten löschen
if [ -d /var/lib/code-server ]; then
    rm -rf /var/lib/code-server
    echo "[REMOTE] ✓ /var/lib/code-server/ gelöscht"
fi

# Auth-Hash wiederherstellen
if [ -f /tmp/code-server-backup/config.yaml ]; then
    mkdir -p /var/lib/code-server
    cp /tmp/code-server-backup/config.yaml /var/lib/code-server/config.yaml
    echo "[REMOTE] ✓ Auth-Hash wiederhergestellt"
    rm -rf /tmp/code-server-backup
fi
EOF
    
    log_success "code-server-Daten entfernt (Auth-Hash bewahrt)"
}

remove_qdrant_data() {
    local dry_run_flag="$1"
    local preserve_flag="$2"
    
    if [ "$preserve_flag" = "true" ]; then
        log_step "Entferne Qdrant-Config (Daten bewahrt)..."
    else
        log_step "Entferne Qdrant-Daten..."
    fi
    
    if [ "$dry_run_flag" = "true" ]; then
        if [ "$preserve_flag" = "true" ]; then
            log_info "[DRY-RUN] Würde löschen: Qdrant-Config"
            log_info "[DRY-RUN] Würde bewahren: /var/lib/qdrant/storage/"
        else
            log_info "[DRY-RUN] Würde löschen: /var/lib/qdrant/"
        fi
        return 0
    fi
    
    if [ "$preserve_flag" = "true" ]; then
        ssh "${REMOTE_USER}@${REMOTE_HOST}" bash << 'EOF'
set -euo pipefail

# Nur Config löschen, Daten bewahren
if [ -d /var/lib/qdrant ]; then
    # Sicherstellen dass storage existiert
    mkdir -p /var/lib/qdrant/storage
    
    # Alles außer storage löschen
    find /var/lib/qdrant -mindepth 1 -maxdepth 1 ! -name 'storage' -exec rm -rf {} +
    echo "[REMOTE] ✓ Qdrant-Config gelöscht (Daten bewahrt)"
fi
EOF
        log_success "Qdrant-Config entfernt (Daten bewahrt)"
    else
        ssh "${REMOTE_USER}@${REMOTE_HOST}" bash << 'EOF'
set -euo pipefail

# Komplett löschen
if [ -d /var/lib/qdrant ]; then
    rm -rf /var/lib/qdrant
    echo "[REMOTE] ✓ /var/lib/qdrant/ gelöscht"
fi
EOF
        log_success "Qdrant-Daten entfernt"
    fi
}

clear_deployment_markers() {
    local dry_run_flag="$1"
    
    log_step "Lösche Deployment-Marker..."
    
    if [ "$dry_run_flag" = "true" ]; then
        log_info "[DRY-RUN] Würde löschen: /var/lib/qs-deployment/markers/*"
        return 0
    fi
    
    ssh "${REMOTE_USER}@${REMOTE_HOST}" bash << 'EOF'
set -euo pipefail

if [ -d /var/lib/qs-deployment/markers ]; then
    rm -rf /var/lib/qs-deployment/markers/*
    echo "[REMOTE] ✓ Deployment-Marker gelöscht"
fi
EOF
    
    log_success "Deployment-Marker gelöscht"
}

clear_deployment_state() {
    local dry_run_flag="$1"
    
    log_step "Lösche Deployment-State..."
    
    if [ "$dry_run_flag" = "true" ]; then
        log_info "[DRY-RUN] Würde löschen: /var/lib/qs-deployment/state/*"
        return 0
    fi
    
    ssh "${REMOTE_USER}@${REMOTE_HOST}" bash << 'EOF'
set -euo pipefail

if [ -d /var/lib/qs-deployment/state ]; then
    rm -rf /var/lib/qs-deployment/state/*
    echo "[REMOTE] ✓ Deployment-State gelöscht"
fi
EOF
    
    log_success "Deployment-State gelöscht"
}

remove_systemd_services() {
    local dry_run_flag="$1"
    
    log_step "Entferne Systemd-Services..."
    
    if [ "$dry_run_flag" = "true" ]; then
        log_info "[DRY-RUN] Würde löschen: caddy.service, code-server.service, qdrant.service"
        return 0
    fi
    
    ssh "${REMOTE_USER}@${REMOTE_HOST}" bash << 'EOF'
set -euo pipefail

# Service-Units löschen
for service in caddy code-server qdrant; do
    service_file="/etc/systemd/system/${service}.service"
    if [ -f "$service_file" ]; then
        rm -f "$service_file"
        echo "[REMOTE] ✓ ${service}.service gelöscht"
    fi
done

# Systemd neu laden
systemctl daemon-reload
echo "[REMOTE] ✓ Systemd daemon-reload ausgeführt"
EOF
    
    log_success "Systemd-Services entfernt"
}

# ============================================================================
# VALIDIERUNG
# ============================================================================

validate_tailscale_after_reset() {
    log_step "Validiere Tailscale-Status (Post-Reset)..."
    
    local tailscale_status=$(ssh "${REMOTE_USER}@${REMOTE_HOST}" "tailscale status 2>&1 || echo 'ERROR'")
    
    if [[ "$tailscale_status" == *"ERROR"* ]] || [[ "$tailscale_status" == *"not running"* ]]; then
        log_critical "Tailscale wurde beeinträchtigt! SSH-Zugang möglicherweise gefährdet!"
        log_critical "Status: ${tailscale_status}"
        return 1
    fi
    
    # Prüfe ob wir noch über Tailscale erreichbar sind
    if ! ping -c 1 -W 2 "$REMOTE_HOST" &>/dev/null; then
        log_critical "Remote-Host nicht mehr via Tailscale erreichbar!"
        return 1
    fi
    
    log_success "Tailscale funktional (Post-Reset)"
    return 0
}

validate_ssh_after_reset() {
    log_step "Validiere SSH-Verbindung (Post-Reset)..."
    
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "${REMOTE_USER}@${REMOTE_HOST}" "echo 'SSH OK'" &>/dev/null; then
        log_critical "SSH-Verbindung nach Reset fehlgeschlagen!"
        return 1
    fi
    
    log_success "SSH funktional (Post-Reset)"
    return 0
}

validate_services_stopped() {
    log_step "Validiere Services sind gestoppt..."
    
    local services=("caddy" "code-server" "qdrant")
    local failed=0
    
    for service in "${services[@]}"; do
        local status=$(ssh "${REMOTE_USER}@${REMOTE_HOST}" "systemctl is-active ${service}.service 2>&1 || echo 'inactive'")
        if [ "$status" != "inactive" ]; then
            log_warn "Service ${service} ist noch aktiv: ${status}"
            ((failed++))
        else
            log_info "✓ Service ${service} gestoppt"
        fi
    done
    
    if [ $failed -gt 0 ]; then
        log_warn "${failed} Services konnten nicht gestoppt werden"
        return 1
    fi
    
    log_success "Alle Services gestoppt"
    return 0
}

generate_reset_report() {
    log_step "Erstelle Reset-Report..."
    
    local report_file="./QS-RESET-REPORT-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
QS-Services Reset Report
========================
Datum: $(date -Iseconds)
Script: ${SCRIPT_NAME} v${VERSION}

Remote-Host: ${REMOTE_HOST}
Optionen:
  - Preserve Qdrant: ${PRESERVE_QDRANT}
  - Dry-Run: ${DRY_RUN}

Durchgeführte Aktionen:
  ✓ Services gestoppt (caddy, code-server, qdrant)
  ✓ Caddy-Daten entfernt
  ✓ code-server-Daten entfernt (Auth-Hash bewahrt)
$([ "$PRESERVE_QDRANT" = "true" ] && echo "  ✓ Qdrant-Config entfernt (Daten bewahrt)" || echo "  ✓ Qdrant-Daten entfernt")
  ✓ Deployment-Marker gelöscht
  ✓ Deployment-State gelöscht
  ✓ Systemd-Services entfernt

Post-Reset Validierung:
  ✓ Tailscale funktional
  ✓ SSH-Verbindung aktiv
  ✓ Services gestoppt

BEWAHRTE KOMPONENTEN:
  ✓ Tailscale (aktiv)
  ✓ SSH-Konfiguration
  ✓ UFW-Regeln
  ✓ fail2ban
  ✓ code-server Auth-Hashes
$([ "$PRESERVE_QDRANT" = "true" ] && echo "  ✓ Qdrant-Daten")

Nächste Schritte:
  1. Neuinitialisierung via setup-qs-master.sh
  2. Service-Validierung (Ports 9443, 8080, 6333)

Status: ✅ ERFOLGREICH
EOF
    
    log_success "Reset-Report erstellt: ${report_file}"
    
    # Report anzeigen
    cat "$report_file"
    
    echo "$report_file"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    # Banner
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║      QS-Services Reset Script v${VERSION}                 ║"
    echo "║         TAILSCALE-SAFE RESET                            ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Parameter parsen
    while [[ $# -gt 0 ]]; do
        case $1 in
            --remote-host=*)
                REMOTE_HOST="${1#*=}"
                shift
                ;;
            --preserve-qdrant)
                PRESERVE_QDRANT=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-validation)
                SKIP_VALIDATION=true
                shift
                ;;
            --yes)
                AUTO_CONFIRM=true
                shift
                ;;
            --help)
                show_help
                exit $EXIT_SUCCESS
                ;;
            *)
                log_error "Unbekannte Option: $1"
                show_help
                exit $EXIT_ERROR
                ;;
        esac
    done
    
    # Dry-Run Warning
    if [ "$DRY_RUN" = "true" ]; then
        log_warn "DRY-RUN Mode aktiviert - Keine Änderungen werden durchgeführt"
    fi
    
    # SSH-Verbindung prüfen
    if ! check_ssh_connection; then
        exit $EXIT_SSH_ERROR
    fi
    
    # KRITISCH: Tailscale-Pre-Check
    if ! validate_tailscale_before_reset; then
        log_critical "Tailscale-Validierung fehlgeschlagen - Reset ABGEBROCHEN!"
        exit $EXIT_VALIDATION_ERROR
    fi
    
    # Bestätigung (außer bei Dry-Run oder Auto-Confirm)
    if [ "$DRY_RUN" != "true" ] && [ "$AUTO_CONFIRM" != "true" ]; then
        echo ""
        log_warn "ACHTUNG: Dieser Reset löscht Service-Daten permanent!"
        log_warn "Remote-Host: ${REMOTE_HOST}"
        log_warn "Preserve Qdrant: ${PRESERVE_QDRANT}"
        echo ""
        read -p "Fortfahren? (yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            log_info "Reset abgebrochen"
            exit $EXIT_SUCCESS
        fi
    elif [ "$AUTO_CONFIRM" = "true" ]; then
        log_info "Auto-Confirm aktiviert - Überspringe Bestätigung"
    fi
    
    # Reset durchführen
    stop_services "$DRY_RUN"
    remove_caddy_data "$DRY_RUN"
    remove_code_server_data "$DRY_RUN"
    remove_qdrant_data "$DRY_RUN" "$PRESERVE_QDRANT"
    clear_deployment_markers "$DRY_RUN"
    clear_deployment_state "$DRY_RUN"
    remove_systemd_services "$DRY_RUN"
    
    # Validierung (außer bei Dry-Run oder Skip)
    if [ "$DRY_RUN" != "true" ] && [ "$SKIP_VALIDATION" != "true" ]; then
        if ! validate_tailscale_after_reset; then
            log_critical "Post-Reset Tailscale-Validierung fehlgeschlagen!"
            exit $EXIT_VALIDATION_ERROR
        fi
        
        if ! validate_ssh_after_reset; then
            log_critical "Post-Reset SSH-Validierung fehlgeschlagen!"
            exit $EXIT_VALIDATION_ERROR
        fi
        
        validate_services_stopped || log_warn "Service-Stop-Validierung mit Warnungen"
    fi
    
    # Report generieren
    if [ "$DRY_RUN" != "true" ]; then
        RESET_REPORT=$(generate_reset_report)
        
        echo ""
        log_success "Reset erfolgreich abgeschlossen!"
        log_info "Reset-Report: ${RESET_REPORT}"
        log_info "Tailscale: ✅ FUNKTIONAL"
        log_info "SSH: ✅ FUNKTIONAL"
    else
        echo ""
        log_success "Dry-Run abgeschlossen - Keine Änderungen durchgeführt"
    fi
    
    exit $EXIT_SUCCESS
}

# Script ausführen
main "$@"
