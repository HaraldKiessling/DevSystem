#!/usr/bin/env bash
#
# QS-System Backup Script
# Erstellt vollständiges Backup aller kritischen Komponenten via SSH
#
# Zweck:
#   Sichert vor Service-Reset alle wichtigen Konfigurationen und Daten
#   - Services-Konfiguration (Caddy, code-server)
#   - Qdrant-Daten
#   - Deployment-State
#   - Systemd-Services
#   - Logs
#
# Verwendung:
#   bash scripts/qs/backup-qs-system.sh [OPTIONS]
#
# Optionen:
#   --remote-host=HOST    Remote-Host (default: devsystem-qs-vps.tailcfea8a.ts.net)
#   --backup-dir=PATH     Lokales Backup-Verzeichnis (default: ./backups)
#   --verify              Verifiziere Backup nach Erstellung
#   --help                Diese Hilfe anzeigen
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
REMOTE_BACKUP_DIR="/tmp/qs-backup-$(date +%Y%m%d-%H%M%S)"

# Lokale Konfiguration
LOCAL_BACKUP_DIR="${PWD}/backups/qs-backup-$(date +%Y%m%d-%H%M%S)"
VERIFY_BACKUP=false

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
readonly EXIT_BACKUP_ERROR=3

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

# ============================================================================
# HILFSFUNKTIONEN
# ============================================================================

show_help() {
    cat << EOF
QS-System Backup Script v${VERSION}

Erstellt vollständiges Backup aller kritischen QS-VPS-Komponenten.

VERWENDUNG:
    $SCRIPT_NAME [OPTIONS]

OPTIONEN:
    --remote-host=HOST    Remote-Host (default: $REMOTE_HOST)
    --backup-dir=PATH     Lokales Backup-Verzeichnis (default: ./backups)
    --verify              Verifiziere Backup nach Erstellung
    --help                Diese Hilfe anzeigen

BEISPIELE:
    # Standard-Backup
    $SCRIPT_NAME

    # Mit Verifikation
    $SCRIPT_NAME --verify

    # Custom Remote-Host
    $SCRIPT_NAME --remote-host=100.82.171.88

RÜCKGABEWERTE:
    0    Erfolg
    1    Allgemeiner Fehler
    2    SSH-Verbindungsfehler
    3    Backup-Fehler

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

calculate_checksum() {
    local file="$1"
    sha256sum "$file" | awk '{print $1}'
}

# ============================================================================
# BACKUP-FUNKTIONEN
# ============================================================================

execute_remote_backup() {
    log_step "Führe Remote-Backup aus..."
    
    # Backup auf Remote-Host erstellen und Pfad zurückgeben
    local remote_backup_dir=$(ssh "${REMOTE_USER}@${REMOTE_HOST}" bash << 'REMOTE_SCRIPT'
set -euo pipefail

BACKUP_DIR="/tmp/qs-backup-$(date +%Y%m%d-%H%M%S)"
MANIFEST_FILE="${BACKUP_DIR}/BACKUP-MANIFEST.txt"

echo "[REMOTE] Erstelle Backup-Verzeichnis: ${BACKUP_DIR}" >&2
mkdir -p "${BACKUP_DIR}"/{config,data,state,services,logs}

# Backup-Manifest initialisieren
cat > "${MANIFEST_FILE}" << EOF
QS-System Backup Manifest
=========================
Timestamp: $(date -Iseconds)
Hostname: $(hostname)
Kernel: $(uname -r)

EOF

echo "[REMOTE] Sichernde Komponenten..."

# 1. Caddy-Konfiguration
echo "=== Caddy Configuration ===" >> "${MANIFEST_FILE}"
if [ -d /etc/caddy ]; then
    tar -czf "${BACKUP_DIR}/config/caddy-config.tar.gz" -C /etc caddy 2>/dev/null || true
    if [ -f "${BACKUP_DIR}/config/caddy-config.tar.gz" ]; then
        CHECKSUM=$(sha256sum "${BACKUP_DIR}/config/caddy-config.tar.gz" | awk '{print $1}')
        SIZE=$(stat -f%z "${BACKUP_DIR}/config/caddy-config.tar.gz" 2>/dev/null || stat -c%s "${BACKUP_DIR}/config/caddy-config.tar.gz")
        echo "caddy-config.tar.gz: ${CHECKSUM} (${SIZE} bytes)" >> "${MANIFEST_FILE}"
        echo "[REMOTE] ✓ Caddy-Config gesichert"
    fi
fi

# 2. code-server Konfiguration
echo "=== code-server Configuration ===" >> "${MANIFEST_FILE}"
if [ -d /var/lib/code-server ]; then
    tar -czf "${BACKUP_DIR}/config/code-server-config.tar.gz" -C /var/lib code-server 2>/dev/null || true
    if [ -f "${BACKUP_DIR}/config/code-server-config.tar.gz" ]; then
        CHECKSUM=$(sha256sum "${BACKUP_DIR}/config/code-server-config.tar.gz" | awk '{print $1}')
        SIZE=$(stat -f%z "${BACKUP_DIR}/config/code-server-config.tar.gz" 2>/dev/null || stat -c%s "${BACKUP_DIR}/config/code-server-config.tar.gz")
        echo "code-server-config.tar.gz: ${CHECKSUM} (${SIZE} bytes)" >> "${MANIFEST_FILE}"
        echo "[REMOTE] ✓ code-server-Config gesichert"
    fi
fi

# 3. Qdrant-Daten
echo "=== Qdrant Data ===" >> "${MANIFEST_FILE}"
if [ -d /var/lib/qdrant ]; then
    tar -czf "${BACKUP_DIR}/data/qdrant-data.tar.gz" -C /var/lib qdrant 2>/dev/null || true
    if [ -f "${BACKUP_DIR}/data/qdrant-data.tar.gz" ]; then
        CHECKSUM=$(sha256sum "${BACKUP_DIR}/data/qdrant-data.tar.gz" | awk '{print $1}')
        SIZE=$(stat -f%z "${BACKUP_DIR}/data/qdrant-data.tar.gz" 2>/dev/null || stat -c%s "${BACKUP_DIR}/data/qdrant-data.tar.gz")
        echo "qdrant-data.tar.gz: ${CHECKSUM} (${SIZE} bytes)" >> "${MANIFEST_FILE}"
        echo "[REMOTE] ✓ Qdrant-Daten gesichert"
    fi
fi

# 4. Deployment-State
echo "=== Deployment State ===" >> "${MANIFEST_FILE}"
if [ -d /var/lib/qs-deployment ]; then
    tar -czf "${BACKUP_DIR}/state/qs-deployment-state.tar.gz" -C /var/lib qs-deployment . 2>/dev/null || true
    if [ -f "${BACKUP_DIR}/state/qs-deployment-state.tar.gz" ]; then
        CHECKSUM=$(sha256sum "${BACKUP_DIR}/state/qs-deployment-state.tar.gz" | awk '{print $1}')
        SIZE=$(stat -f%z "${BACKUP_DIR}/state/qs-deployment-state.tar.gz" 2>/dev/null || stat -c%s "${BACKUP_DIR}/state/qs-deployment-state.tar.gz")
        echo "qs-deployment-state.tar.gz: ${CHECKSUM} (${SIZE} bytes)" >> "${MANIFEST_FILE}"
        echo "[REMOTE] ✓ Deployment-State gesichert"
    fi
fi

# 5. Systemd-Services
echo "=== Systemd Services ===" >> "${MANIFEST_FILE}"
for service in caddy.service code-server.service qdrant.service; do
    if systemctl list-unit-files | grep -q "^${service}"; then
        systemctl cat "${service}" > "${BACKUP_DIR}/services/${service}.unit" 2>/dev/null || true
        if [ -f "${BACKUP_DIR}/services/${service}.unit" ]; then
            CHECKSUM=$(sha256sum "${BACKUP_DIR}/services/${service}.unit" | awk '{print $1}')
            SIZE=$(stat -f%z "${BACKUP_DIR}/services/${service}.unit" 2>/dev/null || stat -c%s "${BACKUP_DIR}/services/${service}.unit")
            echo "${service}.unit: ${CHECKSUM} (${SIZE} bytes)" >> "${MANIFEST_FILE}"
            echo "[REMOTE] ✓ Service ${service} gesichert"
        fi
    fi
done

# 6. Service-Status
echo "=== Service Status ===" >> "${MANIFEST_FILE}"
systemctl status caddy.service --no-pager > "${BACKUP_DIR}/services/caddy-status.txt" 2>&1 || true
systemctl status code-server.service --no-pager > "${BACKUP_DIR}/services/code-server-status.txt" 2>&1 || true
systemctl status qdrant.service --no-pager > "${BACKUP_DIR}/services/qdrant-status.txt" 2>&1 || true

# 7. Logs
echo "=== Logs ===" >> "${MANIFEST_FILE}"
if [ -d /var/log/caddy ]; then
    tar -czf "${BACKUP_DIR}/logs/caddy-logs.tar.gz" -C /var/log caddy 2>/dev/null || true
fi

# Journalctl-Logs
journalctl -u caddy.service --no-pager -n 1000 > "${BACKUP_DIR}/logs/caddy-journal.log" 2>&1 || true
journalctl -u code-server.service --no-pager -n 1000 > "${BACKUP_DIR}/logs/code-server-journal.log" 2>&1 || true
journalctl -u qdrant.service --no-pager -n 1000 > "${BACKUP_DIR}/logs/qdrant-journal.log" 2>&1 || true

# 8. System-Info
echo "=== System Information ===" >> "${MANIFEST_FILE}"
{
    echo "--- Disk Usage ---"
    df -h
    echo ""
    echo "--- Memory Usage ---"
    free -h
    echo ""
    echo "--- Uptime ---"
    uptime
    echo ""
    echo "--- Network ---"
    ip addr show
} > "${BACKUP_DIR}/system-info.txt"

# 9. Tailscale-Status (nicht ändern!)
echo "=== Tailscale Status ===" >> "${MANIFEST_FILE}"
tailscale status > "${BACKUP_DIR}/tailscale-status.txt" 2>&1 || echo "Tailscale status nicht verfügbar"

# Backup-Summary
echo "" >> "${MANIFEST_FILE}"
echo "=== Backup Summary ===" >> "${MANIFEST_FILE}"
echo "Total Size: $(du -sh "${BACKUP_DIR}" | awk '{print $1}')" >> "${MANIFEST_FILE}"
echo "File Count: $(find "${BACKUP_DIR}" -type f | wc -l)" >> "${MANIFEST_FILE}"

echo "[REMOTE] Backup abgeschlossen: ${BACKUP_DIR}" >&2
# Ausgabe des Pfads auf stdout für Capture
echo "${BACKUP_DIR}"
REMOTE_SCRIPT
)
    
    if [ -z "$remote_backup_dir" ]; then
        log_error "Remote-Backup fehlgeschlagen"
        return 1
    fi
    
    log_success "Remote-Backup erstellt: ${remote_backup_dir}"
    echo "$remote_backup_dir"
}

download_backup() {
    local remote_dir="$1"
    
    log_step "Lade Backup herunter..."
    
    # Lokales Verzeichnis erstellen
    mkdir -p "$LOCAL_BACKUP_DIR"
    
    # RSYNC über SSH
    if command -v rsync &>/dev/null; then
        log_info "Nutze rsync für Transfer..."
        rsync -avz --progress \
            -e "ssh -o ConnectTimeout=30" \
            "${REMOTE_USER}@${REMOTE_HOST}:${remote_dir}/" \
            "${LOCAL_BACKUP_DIR}/" || return 1
    else
        log_info "Nutze scp für Transfer..."
        scp -r "${REMOTE_USER}@${REMOTE_HOST}:${remote_dir}/*" "${LOCAL_BACKUP_DIR}/" || return 1
    fi
    
    log_success "Backup heruntergeladen nach: ${LOCAL_BACKUP_DIR}"
}

compress_backup() {
    log_step "Komprimiere Backup..."
    
    local archive_name="${LOCAL_BACKUP_DIR}.tar.gz"
    
    tar -czf "$archive_name" -C "$(dirname "$LOCAL_BACKUP_DIR")" "$(basename "$LOCAL_BACKUP_DIR")" || return 1
    
    local archive_size=$(du -h "$archive_name" | awk '{print $1}')
    local archive_checksum=$(calculate_checksum "$archive_name")
    
    log_success "Backup komprimiert: ${archive_name}"
    log_info "Größe: ${archive_size}"
    log_info "SHA256: ${archive_checksum}"
    
    # Checksum-Datei erstellen
    echo "${archive_checksum}  $(basename "$archive_name")" > "${archive_name}.sha256"
    
    echo "$archive_name"
}

verify_backup() {
    local backup_path="$1"
    
    log_step "Verifiziere Backup..."
    
    # Prüfe Manifest
    if [ ! -f "${LOCAL_BACKUP_DIR}/BACKUP-MANIFEST.txt" ]; then
        log_error "Backup-Manifest fehlt!"
        return 1
    fi
    
    # Prüfe kritische Dateien
    local critical_files=(
        "config/caddy-config.tar.gz"
        "services/caddy.service.unit"
    )
    
    local missing_files=0
    for file in "${critical_files[@]}"; do
        if [ ! -f "${LOCAL_BACKUP_DIR}/${file}" ]; then
            log_warn "Kritische Datei fehlt: ${file}"
            ((missing_files++))
        fi
    done
    
    if [ $missing_files -gt 0 ]; then
        log_warn "Backup unvollständig (${missing_files} Dateien fehlen)"
        return 1
    fi
    
    # Prüfe Archive-Integrität
    if [ -f "${backup_path}.sha256" ]; then
        log_info "Prüfe Checksum..."
        if sha256sum -c "${backup_path}.sha256" &>/dev/null; then
            log_success "Checksum-Verifikation erfolgreich"
        else
            log_error "Checksum-Verifikation fehlgeschlagen!"
            return 1
        fi
    fi
    
    log_success "Backup-Verifikation erfolgreich"
    return 0
}

cleanup_remote_backup() {
    local remote_dir="$1"
    
    log_step "Bereinige Remote-Backup..."
    
    ssh "${REMOTE_USER}@${REMOTE_HOST}" "rm -rf '${remote_dir}'" || log_warn "Remote-Cleanup fehlgeschlagen"
    
    log_success "Remote-Backup bereinigt"
}

generate_backup_report() {
    local backup_archive="$1"
    
    log_step "Erstelle Backup-Report..."
    
    local report_file="${LOCAL_BACKUP_DIR}/BACKUP-REPORT.txt"
    
    cat > "$report_file" << EOF
QS-System Backup Report
=======================
Datum: $(date -Iseconds)
Script: ${SCRIPT_NAME} v${VERSION}

Remote-Host: ${REMOTE_HOST}
Backup-Verzeichnis: ${LOCAL_BACKUP_DIR}
Backup-Archive: ${backup_archive}

Backup-Inhalt:
$(cat "${LOCAL_BACKUP_DIR}/BACKUP-MANIFEST.txt")

Archive-Informationen:
  Größe: $(du -h "$backup_archive" | awk '{print $1}')
  SHA256: $(cat "${backup_archive}.sha256")

Status: ✅ ERFOLGREICH
EOF
    
    log_success "Backup-Report erstellt: ${report_file}"
    
    # Report anzeigen
    cat "$report_file"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    # Banner
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║         QS-System Backup Script v${VERSION}               ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Parameter parsen
    while [[ $# -gt 0 ]]; do
        case $1 in
            --remote-host=*)
                REMOTE_HOST="${1#*=}"
                shift
                ;;
            --backup-dir=*)
                LOCAL_BACKUP_DIR="${1#*=}/qs-backup-$(date +%Y%m%d-%H%M%S)"
                shift
                ;;
            --verify)
                VERIFY_BACKUP=true
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
    
    # SSH-Verbindung prüfen
    if ! check_ssh_connection; then
        exit $EXIT_SSH_ERROR
    fi
    
    # Remote-Backup erstellen
    REMOTE_BACKUP_DIR=$(execute_remote_backup) || {
        log_error "Remote-Backup fehlgeschlagen"
        exit $EXIT_BACKUP_ERROR
    }
    
    # Backup herunterladen
    if ! download_backup "$REMOTE_BACKUP_DIR"; then
        log_error "Backup-Download fehlgeschlagen"
        exit $EXIT_BACKUP_ERROR
    fi
    
    # Backup komprimieren
    BACKUP_ARCHIVE=$(compress_backup) || {
        log_error "Backup-Komprimierung fehlgeschlagen"
        exit $EXIT_BACKUP_ERROR
    }
    
    # Verifikation (optional)
    if [ "$VERIFY_BACKUP" = true ]; then
        if ! verify_backup "$BACKUP_ARCHIVE"; then
            log_error "Backup-Verifikation fehlgeschlagen"
            exit $EXIT_BACKUP_ERROR
        fi
    fi
    
    # Remote-Cleanup
    cleanup_remote_backup "$REMOTE_BACKUP_DIR"
    
    # Report generieren
    generate_backup_report "$BACKUP_ARCHIVE"
    
    # Erfolg
    echo ""
    log_success "Backup erfolgreich abgeschlossen!"
    log_info "Backup-Archive: ${BACKUP_ARCHIVE}"
    log_info "Backup-Verzeichnis: ${LOCAL_BACKUP_DIR}"
    
    exit $EXIT_SUCCESS
}

# Script ausführen
main "$@"
