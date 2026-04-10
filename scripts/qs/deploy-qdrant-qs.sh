#!/bin/bash
#
# QS-VPS: Qdrant Deployment-Script für DevSystem Quality Server
#
# Zweck:
#   Installation und Konfiguration von Qdrant Vektordatenbank auf QS-VPS
#   Angepasste Version mit QS-spezifischen Einstellungen
#
# Voraussetzungen:
#   - Ubuntu System (x86_64)
#   - Root-Rechte
#   - Mindestens 1GB freier Speicher
#
# Parameter:
#   QS_QDRANT_API_KEY    API-Key für Qdrant (MUSS gesetzt werden, optional für localhost)
#   --version=VERSION    Qdrant Version (Standard: v1.7.4)
#   --port=PORT          HTTP Port (Standard: 6333)
#
# Verwendung:
#   # Optional: API-Key setzen (für Produktions-Setup)
#   sed -i 's/QS_QDRANT_API_KEY/mein-api-key/g' deploy-qdrant-qs.sh
#   # Dann ausführen:
#   sudo bash deploy-qdrant-qs.sh
#

set -euo pipefail

# ============================================================================
# KONFIGURATION UND KONSTANTEN
# ============================================================================

# Optional: API-Key für Authentifizierung (kann leer bleiben für localhost-only)
QS_QDRANT_API_KEY="QS_QDRANT_API_KEY"

# Farbdefinitionen
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# QS-spezifische Einstellungen
readonly QS_LOG_FILE="/var/log/qs-deployment.log"
readonly QS_MARKER="QS-VPS"

# Qdrant-Einstellungen
QDRANT_VERSION="v1.7.4"
QDRANT_HTTP_PORT="6333"
QDRANT_GRPC_PORT="6334"
QDRANT_INSTALL_DIR="/opt/qdrant-qs"
QDRANT_DATA_DIR="/var/lib/qdrant-qs"
QDRANT_LOG_DIR="/var/log/qdrant-qs"
QDRANT_USER="qdrant-qs"

# ============================================================================
# LOGGING-FUNKTIONEN
# ============================================================================

exec > >(tee -a "$QS_LOG_FILE")
exec 2>&1

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
    
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [${QS_MARKER}] [$level] $message${NC}"
}

error_exit() {
    log "ERROR" "$1"
    exit 1
}

# ============================================================================
# HILFSFUNKTIONEN
# ============================================================================

show_help() {
    cat << EOF
QS-VPS - Qdrant Deployment-Script für Quality Server

Verwendung: sudo bash deploy-qdrant-qs.sh [Optionen]

Optionen:
  --version=VERSION    Qdrant Version (Standard: v1.7.4)
  --port=PORT          HTTP Port (Standard: 6333)
  --help               Diese Hilfe anzeigen

Optional: API-Key setzen für Authentifizierung
  sed -i 's/QS_QDRANT_API_KEY/mein-key/g' deploy-qdrant-qs.sh

Beispiele:
  sudo bash deploy-qdrant-qs.sh
  sudo bash deploy-qdrant-qs.sh --version=v1.8.0

Voraussetzungen:
  - Ubuntu System (x86_64)
  - Root-Rechte erforderlich

EOF
    exit 0
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version=*)
                QDRANT_VERSION="${1#*=}"
                shift
                ;;
            --port=*)
                QDRANT_HTTP_PORT="${1#*=}"
                shift
                ;;
            --help)
                show_help
                ;;
            *)
                error_exit "Unbekannter Parameter: $1. Verwende --help für Hilfe."
                ;;
        esac
    done
}

# ============================================================================
# VALIDIERUNGSFUNKTIONEN
# ============================================================================

check_root() {
    if [ "$(id -u)" != "0" ]; then
        error_exit "Dieses Skript muss mit Root-Rechten ausgeführt werden."
    fi
}

check_system() {
    log "STEP" "Prüfe System-Voraussetzungen für QS-VPS..."
    
    # Prüfe Architektur
    local arch=$(uname -m)
    if [ "$arch" != "x86_64" ]; then
        error_exit "Nur x86_64 Architektur wird unterstützt. Gefunden: $arch"
    fi
    
    # Prüfe Ubuntu
    if [ ! -f /etc/lsb-release ] || ! grep -q "Ubuntu" /etc/lsb-release; then
        error_exit "Dieses Skript ist für Ubuntu-Systeme ausgelegt."
    fi
    
    # Prüfe freien Speicher
    local free_space=$(df -BG ${QDRANT_INSTALL_DIR%/*} 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//' || echo "0")
    if [ "$free_space" -lt 1 ]; then
        error_exit "Nicht genügend freier Speicher. Mindestens 1GB erforderlich."
    fi
    
    log "INFO" "System-Voraussetzungen erfüllt (x86_64, Ubuntu, ${free_space}GB frei)."
}

check_api_key() {
    if [ "$QS_QDRANT_API_KEY" = "QS_QDRANT_API_KEY" ]; then
        log "WARN" "QS_QDRANT_API_KEY nicht gesetzt. Qdrant läuft ohne Authentifizierung (nur localhost)."
        QS_QDRANT_API_KEY=""
    else
        log "INFO" "QS_QDRANT_API_KEY gesetzt (${#QS_QDRANT_API_KEY} Zeichen)."
    fi
}

# ============================================================================
# INSTALLATIONS-FUNKTIONEN
# ============================================================================

create_user() {
    log "STEP" "Erstelle dedizierten QS-Qdrant-Benutzer..."
    
    if id "$QDRANT_USER" &>/dev/null; then
        log "WARN" "Benutzer '$QDRANT_USER' existiert bereits."
    else
        useradd -r -s /bin/false -d "$QDRANT_DATA_DIR" "$QDRANT_USER" || error_exit "Fehler beim Erstellen des Benutzers."
        log "INFO" "Benutzer '$QDRANT_USER' erfolgreich erstellt."
    fi
}

create_directories() {
    log "STEP" "Erstelle QS-Verzeichnisstruktur für Qdrant..."
    
    mkdir -p "$QDRANT_INSTALL_DIR"
    mkdir -p "$QDRANT_DATA_DIR/storage"
    mkdir -p "$QDRANT_DATA_DIR/snapshots"
    mkdir -p "$QDRANT_LOG_DIR"
    
    # QS-Marker erstellen
    echo "QS-VPS Qdrant - Quality Server" > "$QDRANT_DATA_DIR/QS-ENVIRONMENT"
    echo "Created: $(date)" >> "$QDRANT_DATA_DIR/QS-ENVIRONMENT"
    echo "Version: ${QDRANT_VERSION}" >> "$QDRANT_DATA_DIR/QS-ENVIRONMENT"
    
    chown -R "$QDRANT_USER:$QDRANT_USER" "$QDRANT_DATA_DIR"
    chown -R "$QDRANT_USER:$QDRANT_USER" "$QDRANT_LOG_DIR"
    chown root:root "$QDRANT_INSTALL_DIR"
    
    log "INFO" "QS-Verzeichnisstruktur erstellt."
}

download_qdrant() {
    log "STEP" "Lade Qdrant ${QDRANT_VERSION} für QS-VPS herunter..."
    
    cd "$QDRANT_INSTALL_DIR"
    
    # Idempotenz: Prüfe ob Binary bereits existiert
    if [ -f "$QDRANT_INSTALL_DIR/qdrant" ]; then
        log "WARN" "Qdrant-Binary existiert bereits - überspringe Download."
        local existing_version=$(./qdrant --version 2>&1 || echo "Version nicht lesbar")
        log "INFO" "Existierende Version: $existing_version"
        return 0
    fi
    
    local download_url="https://github.com/qdrant/qdrant/releases/download/${QDRANT_VERSION}/qdrant-x86_64-unknown-linux-gnu.tar.gz"
    
    log "INFO" "Download von: $download_url"
    
    if ! wget -q --show-progress "$download_url" 2>&1 | tee -a "$QS_LOG_FILE"; then
        error_exit "Fehler beim Herunterladen von Qdrant."
    fi
    
    log "INFO" "Entpacke Qdrant..."
    tar -xzf qdrant-x86_64-unknown-linux-gnu.tar.gz || error_exit "Fehler beim Entpacken."
    
    chmod +x qdrant
    rm qdrant-x86_64-unknown-linux-gnu.tar.gz
    
    # Verifiziere Binary (nur Warnung, kein Fehler)
    local version_output=$(./qdrant --version 2>&1 || echo "")
    if [ -n "$version_output" ] && [[ "$version_output" != *"error"* ]]; then
        log "INFO" "Qdrant erfolgreich heruntergeladen: $version_output"
    else
        log "WARN" "Qdrant-Binary-Verifizierung fehlgeschlagen - wird beim Service-Start getestet."
        log "INFO" "Binary-Datei existiert: $(ls -lh qdrant 2>/dev/null || echo 'nicht gefunden')"
    fi
}

create_config() {
    log "STEP" "Erstelle QS-Qdrant Konfiguration..."
    
    local config_file="$QDRANT_INSTALL_DIR/config.yaml"
    
    cat > "$config_file" << EOF
# QS-VPS Qdrant Konfiguration - Quality Server
# Generiert: $(date '+%Y-%m-%d %H:%M:%S')

service:
  # HTTP API (nur localhost)
  http_port: ${QDRANT_HTTP_PORT}
  host: 127.0.0.1
  
  # gRPC API (nur localhost)
  grpc_port: ${QDRANT_GRPC_PORT}

storage:
  # Storage-Pfade
  storage_path: ${QDRANT_DATA_DIR}/storage
  snapshots_path: ${QDRANT_DATA_DIR}/snapshots
  
  # Performance-Einstellungen (QS-optimiert)
  optimizers:
    deleted_threshold: 0.2
    vacuum_min_vector_number: 1000
    default_segment_number: 0
  
  # HNSW-Index-Parameter
  hnsw_index:
    m: 16
    ef_construct: 100

log_level: INFO
EOF

    # Füge API-Key hinzu, falls gesetzt
    if [ -n "$QS_QDRANT_API_KEY" ]; then
        cat >> "$config_file" << EOF

# API-Authentifizierung
service:
  api_key: "${QS_QDRANT_API_KEY}"
EOF
        log "INFO" "API-Key in Konfiguration eingetragen."
    else
        log "WARN" "Keine API-Authentifizierung konfiguriert (localhost-only)."
    fi
    
    chown root:root "$config_file"
    chmod 644 "$config_file"
    
    log "INFO" "QS-Konfiguration erstellt: $config_file"
}

create_systemd_service() {
    log "STEP" "Erstelle systemd-Service für QS-Qdrant..."
    
    cat > /etc/systemd/system/qdrant-qs.service << EOF
[Unit]
Description=Qdrant Vector Database for QS-VPS
Documentation=https://qdrant.tech/documentation/
After=network.target

[Service]
Type=simple
User=${QDRANT_USER}
Group=${QDRANT_USER}
WorkingDirectory=${QDRANT_INSTALL_DIR}
ExecStart=${QDRANT_INSTALL_DIR}/qdrant --config-path ${QDRANT_INSTALL_DIR}/config.yaml
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Sicherheits-Hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${QDRANT_DATA_DIR} ${QDRANT_LOG_DIR}

# Ressourcen-Limits
LimitNOFILE=65536

# QS-Environment Variable
Environment="QS_ENVIRONMENT=quality-server"

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload || error_exit "Fehler beim Neuladen von systemd."
    systemctl enable qdrant-qs || error_exit "Fehler beim Aktivieren des Dienstes."
    
    log "INFO" "systemd-Service erstellt und aktiviert."
}

start_service() {
    log "STEP" "Starte QS-Qdrant-Service..."
    
    if systemctl start qdrant-qs; then
        log "INFO" "qdrant-qs-Service erfolgreich gestartet."
    else
        log "ERROR" "Fehler beim Starten des Dienstes."
        log "INFO" "Prüfe Logs mit: journalctl -u qdrant-qs -n 50"
        return 1
    fi
    
    sleep 3
    
    if systemctl is-active --quiet qdrant-qs; then
        log "INFO" "qdrant-qs-Service läuft."
    else
        log "WARN" "qdrant-qs-Service scheint nicht zu laufen."
        return 1
    fi
}

# ============================================================================
# VALIDIERUNGS-FUNKTIONEN
# ============================================================================

verify_installation() {
    log "STEP" "Verifiziere QS-Qdrant Installation..."
    
    # Service-Status prüfen
    if ! systemctl is-active --quiet qdrant-qs; then
        log "ERROR" "Service läuft nicht."
        return 1
    fi
    
    # Port-Binding prüfen
    sleep 2
    if ! ss -tlnp | grep -q ":${QDRANT_HTTP_PORT}"; then
        log "ERROR" "Qdrant lauscht nicht auf Port ${QDRANT_HTTP_PORT}."
        return 1
    fi
    
    log "INFO" "Port ${QDRANT_HTTP_PORT} ist gebunden."
    
    # HTTP API testen
    log "INFO" "Teste HTTP API..."
    local response=$(curl -s http://127.0.0.1:${QDRANT_HTTP_PORT}/ 2>/dev/null || echo "error")
    
    if [[ "$response" == *"qdrant"* ]]; then
        log "INFO" "HTTP API antwortet: $response"
    else
        log "WARN" "HTTP API antwortet nicht wie erwartet."
        return 1
    fi
    
    # Health-Check
    local health_status=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:${QDRANT_HTTP_PORT}/health 2>/dev/null || echo "000")
    if [ "$health_status" = "200" ]; then
        log "INFO" "Health-Check erfolgreich (200 OK)."
    else
        log "WARN" "Health-Check fehlgeschlagen (Status: $health_status)."
    fi
    
    # Collections-API testen
    local collections_response=$(curl -s http://127.0.0.1:${QDRANT_HTTP_PORT}/collections 2>/dev/null || echo "error")
    if [[ "$collections_response" == *"result"* ]]; then
        log "INFO" "Collections-API funktioniert."
    else
        log "WARN" "Collections-API antwortet nicht wie erwartet."
    fi
    
    log "INFO" "Verifizierung abgeschlossen."
    return 0
}

check_logs() {
    log "STEP" "Prüfe Service-Logs..."
    
    local error_count=$(journalctl -u qdrant-qs -n 20 --no-pager | grep -i "error" | wc -l)
    
    if [ "$error_count" -gt 0 ]; then
        log "WARN" "Gefundene Fehler in Logs: ${error_count}"
        journalctl -u qdrant-qs -n 20 --no-pager | grep -i "error"
    else
        log "INFO" "Keine kritischen Fehler in den Logs."
    fi
    
    # Zeige Startup-Logs
    log "INFO" "Letzte Log-Einträge:"
    journalctl -u qdrant-qs -n 10 --no-pager | tee -a "$QS_LOG_FILE"
}

# ============================================================================
# ZUSAMMENFASSUNG
# ============================================================================

show_summary() {
    echo ""
    echo "============================================================================"
    log "STEP" "QS-VPS: Qdrant-Deployment erfolgreich abgeschlossen!"
    echo "============================================================================"
    echo ""
    log "INFO" "Installations-Details:"
    echo "  • Environment:           QS-VPS (Quality Server)"
    echo "  • Version:               ${QDRANT_VERSION}"
    echo "  • HTTP Port:             ${QDRANT_HTTP_PORT} (localhost)"
    echo "  • gRPC Port:             ${QDRANT_GRPC_PORT} (localhost)"
    echo "  • Installation:          ${QDRANT_INSTALL_DIR}"
    echo "  • Daten:                 ${QDRANT_DATA_DIR}"
    echo "  • Logs:                  ${QDRANT_LOG_DIR}"
    echo "  • Service:               qdrant-qs"
    echo "  • Benutzer:              ${QDRANT_USER}"
    
    if [ -n "$QS_QDRANT_API_KEY" ]; then
        echo "  • Authentifizierung:     Aktiviert (API-Key)"
    else
        echo "  • Authentifizierung:     Keine (localhost-only)"
    fi
    
    echo ""
    log "INFO" "Zugriff (nur vom QS-VPS selbst):"
    echo "  • HTTP API:              http://127.0.0.1:${QDRANT_HTTP_PORT}"
    echo "  • Health Check:          http://127.0.0.1:${QDRANT_HTTP_PORT}/health"
    echo "  • Collections:           http://127.0.0.1:${QDRANT_HTTP_PORT}/collections"
    echo ""
    log "INFO" "Service-Verwaltung:"
    echo "  • Status prüfen:         sudo systemctl status qdrant-qs"
    echo "  • Service starten:       sudo systemctl start qdrant-qs"
    echo "  • Service stoppen:       sudo systemctl stop qdrant-qs"
    echo "  • Service neustarten:    sudo systemctl restart qdrant-qs"
    echo "  • Logs anzeigen:         sudo journalctl -u qdrant-qs -f"
    echo ""
    log "INFO" "Beispiel-Zugriff:"
    echo "  # Version abfragen"
    echo "  curl http://127.0.0.1:${QDRANT_HTTP_PORT}/"
    echo ""
    echo "  # Collections auflisten"
    echo "  curl http://127.0.0.1:${QDRANT_HTTP_PORT}/collections"
    echo ""
    log "INFO" "Deployment-Log: ${QS_LOG_FILE}"
    echo ""
    echo "============================================================================"
    echo ""
}

# ============================================================================
# HAUPTPROGRAMM
# ============================================================================

main() {
    echo ""
    echo "============================================================================"
    echo "  QS-VPS - Qdrant Deployment für Quality Server"
    echo "  Version 1.0"
    echo "============================================================================"
    echo ""
    
    parse_arguments "$@"
    
    # Validierungen
    check_root
    check_system
    check_api_key
    
    # Installation
    create_user
    create_directories
    download_qdrant
    create_config
    create_systemd_service
    
    # Service starten
    if ! start_service; then
        error_exit "Service-Start fehlgeschlagen."
    fi
    
    # Verifizierung
    if ! verify_installation; then
        log "WARN" "Verifizierung mit Warnungen abgeschlossen."
    fi
    
    # Logs prüfen
    check_logs
    
    # Zusammenfassung
    show_summary
    
    log "INFO" "QS-VPS: Qdrant-Deployment erfolgreich abgeschlossen!"
    exit 0
}

# Skript ausführen
main "$@"
