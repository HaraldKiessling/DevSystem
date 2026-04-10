#!/bin/bash
#
# QS-VPS: Caddy Konfigurationsskript für DevSystem Quality Server
#
# Zweck:
#   Konfiguration von Caddy als Reverse Proxy für QS-VPS code-server
#   Angepasste Version mit QS-spezifischen Einstellungen und Tailscale-IP
#
# Voraussetzungen:
#   - Caddy installiert (via install-caddy-qs.sh)
#   - Tailscale installiert und verbunden
#   - Root-Rechte
#
# Parameter:
#   QS_TAILSCALE_IP     Tailscale-IP des QS-VPS (MUSS gesetzt werden)
#   --code-server-port  Port für code-server (Standard: 8080)
#
# Verwendung:
#   # Platzhalter QS_TAILSCALE_IP im Script ersetzen:
#   sed -i 's/QS_TAILSCALE_IP/100.x.x.x/g' configure-caddy-qs.sh
#   # Dann ausführen:
#   sudo bash configure-caddy-qs.sh
#

set -euo pipefail

# ============================================================================
# KONFIGURATION UND KONSTANTEN
# ============================================================================

# !!! WICHTIG: Diese Variable MUSS vor der Ausführung gesetzt werden !!!
QS_TAILSCALE_IP="QS_TAILSCALE_IP"

# Farbdefinitionen für Terminal-Ausgabe
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Verzeichnisse und Dateien
readonly CADDY_DIR="/etc/caddy"
readonly CADDY_LOG_DIR="/var/log/caddy"
readonly BACKUP_DIR_DEFAULT="/var/backups/caddy-qs"
readonly QS_LOG_FILE="/var/log/qs-deployment.log"

# Standardwerte für Konfigurationsparameter
CODE_SERVER_PORT="8080"
BACKUP_DIR="${BACKUP_DIR_DEFAULT}"
DOMAIN=""
HOSTNAME="devsystem-qs-vps"

# ============================================================================
# LOGGING-FUNKTIONEN
# ============================================================================

# Logging in Datei und Terminal
exec > >(tee -a "$QS_LOG_FILE")
exec 2>&1

log_message() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] [QS-VPS] INFO:${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [QS-VPS] ✓ SUCCESS:${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [QS-VPS] ⚠ WARNING:${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [QS-VPS] ✗ ERROR:${NC} $1"
}

log_step() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] [QS-VPS] STEP:${NC} $1"
}

# Fehlerbehandlung mit Exit
error_exit() {
    log_error "$1"
    log_error "Konfiguration fehlgeschlagen. Siehe Log: ${QS_LOG_FILE}"
    exit 1
}

# ============================================================================
# HILFSFUNKTIONEN
# ============================================================================

# Hilfe-Text anzeigen
show_help() {
    cat << EOF
QS-VPS - Caddy Konfigurationsskript für Quality Server

Verwendung: sudo bash configure-caddy-qs.sh [Optionen]

WICHTIG: Vor der Ausführung MUSS die Variable QS_TAILSCALE_IP gesetzt werden!
  sed -i 's/QS_TAILSCALE_IP/100.x.x.x/g' configure-caddy-qs.sh

Optionen:
  --code-server-port=PORT   Port für code-server (Standard: 8080)
  --backup-dir=DIR          Verzeichnis für Backups (Standard: ${BACKUP_DIR_DEFAULT})
  --help                    Diese Hilfe anzeigen

Beispiele:
  sudo bash configure-caddy-qs.sh
  sudo bash configure-caddy-qs.sh --code-server-port=8080

Voraussetzungen:
  - Caddy muss installiert sein
  - Tailscale muss installiert und verbunden sein
  - Root-Rechte erforderlich

EOF
    exit 0
}

# Kommandozeilenargumente parsen
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --code-server-port=*)
                CODE_SERVER_PORT="${1#*=}"
                shift
                ;;
            --backup-dir=*)
                BACKUP_DIR="${1#*=}"
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

# Root-Berechtigungen prüfen
check_root() {
    if [ "$(id -u)" != "0" ]; then
        error_exit "Dieses Skript muss mit Root-Rechten ausgeführt werden. Verwende 'sudo'."
    fi
}

# Prüfen, ob QS_TAILSCALE_IP gesetzt wurde
check_tailscale_ip_placeholder() {
    log_step "Prüfe QS_TAILSCALE_IP..."
    
    if [ "$QS_TAILSCALE_IP" = "QS_TAILSCALE_IP" ]; then
        error_exit "QS_TAILSCALE_IP wurde nicht gesetzt! Bitte ersetze den Platzhalter vor der Ausführung."
    fi
    
    # IP-Format validieren (100.x.x.x)
    if [[ ! "$QS_TAILSCALE_IP" =~ ^100\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        error_exit "Ungültige QS_TAILSCALE_IP: ${QS_TAILSCALE_IP}. Erwartet: 100.x.x.x"
    fi
    
    log_success "QS_TAILSCALE_IP ist gültig: ${QS_TAILSCALE_IP}"
}

# Prüfen, ob Caddy installiert ist
check_caddy_installed() {
    log_step "Prüfe ob Caddy installiert ist..."
    
    if ! command -v caddy &> /dev/null; then
        error_exit "Caddy ist nicht installiert. Bitte führe zuerst 'install-caddy-qs.sh' aus."
    fi
    
    local caddy_version=$(caddy version 2>&1 | head -n1)
    log_success "Caddy ist installiert: ${caddy_version}"
}

# Prüfen, ob Tailscale installiert und verbunden ist
check_tailscale() {
    log_step "Prüfe Tailscale-Installation und -Status..."
    
    if ! command -v tailscale &> /dev/null; then
        error_exit "Tailscale ist nicht installiert."
    fi
    
    # Tailscale-Status prüfen
    if ! tailscale status &> /dev/null; then
        error_exit "Tailscale ist nicht verbunden. Bitte verbinde Tailscale zuerst."
    fi
    
    log_success "Tailscale ist installiert und verbunden."
}

# Tailscale-Domain ermitteln
get_tailscale_domain() {
    log_step "Ermittle Tailscale-Domain für QS-VPS..."
    
    # Versuche Domain aus Tailscale-Status zu ermitteln
    if command -v jq &> /dev/null; then
        local ts_status=$(tailscale status --json 2>/dev/null)
        DOMAIN=$(echo "$ts_status" | jq -r '.Self.DNSName' | sed 's/\.$//')
        
        if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "null" ]; then
            DOMAIN="${HOSTNAME}.tailscale.net"
        fi
    else
        DOMAIN="${HOSTNAME}.tailscale.net"
    fi
    
    log_success "Tailscale-Domain: ${DOMAIN}"
}

# Prüfen, ob code-server läuft
check_code_server() {
    log_step "Prüfe ob code-server auf Port ${CODE_SERVER_PORT} erreichbar ist..."
    
    if ! nc -z localhost "${CODE_SERVER_PORT}" 2>/dev/null && ! timeout 2 bash -c "echo > /dev/tcp/localhost/${CODE_SERVER_PORT}" 2>/dev/null; then
        log_warning "code-server scheint nicht auf Port ${CODE_SERVER_PORT} zu laufen."
        log_warning "Caddy wird trotzdem konfiguriert."
    else
        log_success "code-server ist auf Port ${CODE_SERVER_PORT} erreichbar."
    fi
}

# ============================================================================
# BACKUP-FUNKTIONEN
# ============================================================================

# Backup der alten Konfiguration erstellen
backup_config() {
    log_step "Erstelle Backup der aktuellen Konfiguration..."
    
    mkdir -p "${BACKUP_DIR}"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="${BACKUP_DIR}/caddy_qs_backup_${timestamp}"
    
    if [ -f "${CADDY_DIR}/Caddyfile" ]; then
        mkdir -p "${backup_path}"
        cp -r "${CADDY_DIR}/Caddyfile" "${backup_path}/" 2>/dev/null || true
        
        if [ -d "${CADDY_DIR}/sites" ]; then
            cp -r "${CADDY_DIR}/sites" "${backup_path}/" 2>/dev/null || true
        fi
        
        if [ -d "${CADDY_DIR}/snippets" ]; then
            cp -r "${CADDY_DIR}/snippets" "${backup_path}/" 2>/dev/null || true
        fi
        
        log_success "Backup erstellt: ${backup_path}"
        echo "${backup_path}" > "${BACKUP_DIR}/latest_backup.txt"
    else
        log_message "Keine vorherige Konfiguration gefunden. Kein Backup notwendig."
    fi
}

# ============================================================================
# KONFIGURATIONSFUNKTIONEN
# ============================================================================

# Verzeichnisstruktur erstellen
create_directory_structure() {
    log_step "Erstelle Verzeichnisstruktur..."
    
    mkdir -p "${CADDY_DIR}/sites"
    mkdir -p "${CADDY_DIR}/snippets"
    mkdir -p "${CADDY_DIR}/tls/tailscale"
    mkdir -p "${CADDY_LOG_DIR}"
    
    # QS-Environment Marker aktualisieren
    echo "QS-VPS Quality Server - Configured: $(date)" > "${CADDY_DIR}/QS-ENVIRONMENT"
    echo "Tailscale IP: ${QS_TAILSCALE_IP}" >> "${CADDY_DIR}/QS-ENVIRONMENT"
    
    # Berechtigungen setzen
    if getent passwd caddy > /dev/null 2>&1; then
        chown -R caddy:caddy "${CADDY_DIR}" 2>/dev/null || true
        chown -R caddy:caddy "${CADDY_LOG_DIR}" 2>/dev/null || true
    fi
    
    log_success "Verzeichnisstruktur erstellt."
}

# Tailscale-Zertifikate generieren und konfigurieren
setup_tailscale_certificates() {
    log_step "Generiere Tailscale-Zertifikate..."
    
    local cert_dir="${CADDY_DIR}/tls/tailscale"
    
    # Tailscale-Zertifikate generieren
    if tailscale cert "${DOMAIN}" 2>&1 | tee -a "$QS_LOG_FILE"; then
        if [ -f "/var/lib/tailscale/certs/${DOMAIN}.crt" ] && [ -f "/var/lib/tailscale/certs/${DOMAIN}.key" ]; then
            cp "/var/lib/tailscale/certs/${DOMAIN}.crt" "${cert_dir}/"
            cp "/var/lib/tailscale/certs/${DOMAIN}.key" "${cert_dir}/"
            
            if getent passwd caddy > /dev/null 2>&1; then
                chown -R caddy:caddy "${cert_dir}"
                chmod 600 "${cert_dir}/${DOMAIN}.key"
            fi
            
            log_success "Tailscale-Zertifikate generiert und installiert."
            return 0
        fi
    fi
    
    log_message "Verwende Caddy's automatisches HTTPS über Tailscale."
    return 1
}

# Sicherheits-Header-Snippet erstellen
create_security_headers() {
    log_step "Erstelle Sicherheits-Header-Snippet..."
    
    cat > "${CADDY_DIR}/snippets/security-headers.caddy" << 'EOF'
# Benanntes Snippet für Security-Headers (QS-VPS)
(security_headers) {
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-XSS-Protection "1; mode=block"
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "strict-origin-when-cross-origin"
        X-Environment "QS-VPS"
        -Server
    }
}
EOF
    
    log_success "Sicherheits-Header-Snippet erstellt."
}

# code-server Site-Konfiguration erstellen
create_code_server_config() {
    log_step "Erstelle code-server QS-Konfiguration..."
    
    # Prüfen, ob Zertifikate vorhanden sind
    local use_manual_tls=false
    if [ -f "${CADDY_DIR}/tls/tailscale/${DOMAIN}.crt" ] && [ -f "${CADDY_DIR}/tls/tailscale/${DOMAIN}.key" ]; then
        use_manual_tls=true
    fi
    
    cat > "${CADDY_DIR}/sites/code-server-qs.caddy" << EOF
# QS-VPS code-server Reverse Proxy Konfiguration
# Quality Server Environment
# Zugriff nur über QS-Tailscale-IP: ${QS_TAILSCALE_IP}
https://${QS_TAILSCALE_IP} {
EOF

    if [ "$use_manual_tls" = true ]; then
        cat >> "${CADDY_DIR}/sites/code-server-qs.caddy" << EOF
    # Manuelle TLS-Konfiguration mit Tailscale-Zertifikaten
    tls ${CADDY_DIR}/tls/tailscale/${DOMAIN}.crt ${CADDY_DIR}/tls/tailscale/${DOMAIN}.key
EOF
    else
        cat >> "${CADDY_DIR}/sites/code-server-qs.caddy" << EOF
    # Automatisches HTTPS über Tailscale
    tls internal
EOF
    fi

    cat >> "${CADDY_DIR}/sites/code-server-qs.caddy" << EOF
    
    # Matcher für Tailscale-Zugriff definieren
    @tailscale {
        remote_ip 100.64.0.0/10
    }
    
    @not_tailscale {
        not remote_ip 100.64.0.0/10
    }
    
    # Reverse Proxy zu code-server
    reverse_proxy @tailscale localhost:${CODE_SERVER_PORT} {
        # Header für WebSocket-Unterstützung
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up Connection {http.request.header.Connection}
        header_up Upgrade {http.request.header.Upgrade}
        
        # Timeouts erhöhen für lange Entwicklungssitzungen
        transport http {
            keepalive 30m
            keepalive_idle_conns 10
            read_timeout 0
            write_timeout 0
        }
    }
    
    # Zugriff verweigern, wenn nicht über Tailscale
    respond @not_tailscale "Zugriff nur über Tailscale erlaubt (QS-VPS)" 403
    
    # Sicherheits-Header importieren
    import security_headers
    
    # Kompression aktivieren
    encode gzip zstd
    
    # Logging
    log {
        output file ${CADDY_LOG_DIR}/qs-code-server.log {
            roll_size 50MB
            roll_keep 5
            roll_keep_for 168h
        }
        format json {
            time_format iso8601
        }
        level INFO
    }
}

# Zusätzlicher Zugriff über Domain (falls DNS konfiguriert)
https://${DOMAIN} {
EOF

    if [ "$use_manual_tls" = true ]; then
        cat >> "${CADDY_DIR}/sites/code-server-qs.caddy" << EOF
    tls ${CADDY_DIR}/tls/tailscale/${DOMAIN}.crt ${CADDY_DIR}/tls/tailscale/${DOMAIN}.key
EOF
    fi

    cat >> "${CADDY_DIR}/sites/code-server-qs.caddy" << EOF
    
    @tailscale {
        remote_ip 100.64.0.0/10
    }
    
    @not_tailscale {
        not remote_ip 100.64.0.0/10
    }
    
    reverse_proxy @tailscale localhost:${CODE_SERVER_PORT} {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up Connection {http.request.header.Connection}
        header_up Upgrade {http.request.header.Upgrade}
        
        transport http {
            keepalive 30m
            keepalive_idle_conns 10
            read_timeout 0
            write_timeout 0
        }
    }
    
    respond @not_tailscale "Zugriff nur über Tailscale erlaubt (QS-VPS)" 403
    
    import security_headers
    encode gzip zstd
    
    log {
        output file ${CADDY_LOG_DIR}/qs-code-server.log {
            roll_size 50MB
            roll_keep 5
            roll_keep_for 168h
        }
        format json {
            time_format iso8601
        }
        level INFO
    }
}
EOF
    
    log_success "code-server QS-Konfiguration erstellt."
}

# Hauptkonfigurationsdatei (Caddyfile) erstellen
create_main_config() {
    log_step "Erstelle Hauptkonfigurationsdatei (Caddyfile)..."
    
    cat > "${CADDY_DIR}/Caddyfile" << 'EOF'
# QS-VPS Caddy Hauptkonfiguration - Quality Server
# Generiert durch configure-caddy-qs.sh

# Globale Optionen
{
    # Admin-API deaktivieren (Sicherheit)
    admin off
    
    # Server-Einstellungen
    servers {
        protocols h1 h2 h3
        strict_sni_host
    }
    
    # Globales Logging
    log {
        output file /var/log/caddy/qs-access.log {
            roll_size 100MB
            roll_keep 10
            roll_keep_for 720h
        }
        format json {
            time_format iso8601
        }
        level INFO
    }
}

# Snippets importieren
import /etc/caddy/snippets/*.caddy

# Site-Konfigurationen importieren
import /etc/caddy/sites/*.caddy
EOF
    
    log_success "Hauptkonfigurationsdatei erstellt."
}

# ============================================================================
# SERVICE-MANAGEMENT
# ============================================================================

# Caddy-Konfiguration validieren
validate_config() {
    log_step "Validiere Caddy-Konfiguration..."
    
    if caddy validate --config "${CADDY_DIR}/Caddyfile" 2>&1 | tee -a "$QS_LOG_FILE"; then
        log_success "Caddy-Konfiguration ist gültig."
        return 0
    else
        log_error "Caddy-Konfiguration ist ungültig!"
        return 1
    fi
}

# Caddy-Service aktivieren
enable_caddy_service() {
    log_step "Aktiviere Caddy-Service..."
    
    if systemctl enable caddy 2>&1 | tee -a "$QS_LOG_FILE"; then
        log_success "Caddy-Service aktiviert."
    else
        log_warning "Konnte Caddy-Service nicht aktivieren."
    fi
}

# Caddy-Service starten/neu laden
restart_caddy_service() {
    log_step "Starte Caddy-Service..."
    
    if systemctl is-active --quiet caddy; then
        log_message "Caddy läuft bereits. Lade Konfiguration neu..."
        if systemctl reload caddy 2>&1 | tee -a "$QS_LOG_FILE"; then
            log_success "Caddy-Konfiguration neu geladen."
        else
            log_warning "Reload fehlgeschlagen. Versuche Neustart..."
            systemctl restart caddy 2>&1 | tee -a "$QS_LOG_FILE"
        fi
    else
        log_message "Starte Caddy-Service..."
        if systemctl start caddy 2>&1 | tee -a "$QS_LOG_FILE"; then
            log_success "Caddy-Service gestartet."
        else
            error_exit "Konnte Caddy-Service nicht starten."
        fi
    fi
    
    sleep 2
}

# Service-Status prüfen
check_service_status() {
    log_step "Prüfe Caddy-Service-Status..."
    
    if systemctl is-active --quiet caddy; then
        log_success "Caddy-Service läuft."
        
        log_message "Service-Details:"
        systemctl status caddy --no-pager -l | head -n 15 | tee -a "$QS_LOG_FILE"
        
        return 0
    else
        log_error "Caddy-Service läuft nicht!"
        log_error "Prüfe Logs mit: journalctl -u caddy -n 50"
        
        log_message "Letzte Log-Einträge:"
        journalctl -u caddy -n 20 --no-pager | tee -a "$QS_LOG_FILE"
        
        return 1
    fi
}

# ============================================================================
# ZUSAMMENFASSUNG
# ============================================================================

# Abschlussinformationen anzeigen
show_summary() {
    echo ""
    echo "============================================================================"
    log_success "QS-VPS: Caddy-Konfiguration erfolgreich abgeschlossen!"
    echo "============================================================================"
    echo ""
    log_message "Konfigurationsdetails:"
    echo "  • QS-Tailscale-IP:     ${QS_TAILSCALE_IP}"
    echo "  • Tailscale-Domain:    ${DOMAIN}"
    echo "  • Hostname:            ${HOSTNAME}"
    echo "  • code-server Port:    ${CODE_SERVER_PORT}"
    echo "  • Environment:         QS-VPS (Quality Server)"
    echo ""
    log_message "Zugriffs-URLs:"
    echo "  • https://${QS_TAILSCALE_IP}"
    echo "  • https://${DOMAIN}"
    echo ""
    log_message "Wichtige Dateien:"
    echo "  • Hauptkonfiguration:  ${CADDY_DIR}/Caddyfile"
    echo "  • Site-Konfiguration:  ${CADDY_DIR}/sites/code-server-qs.caddy"
    echo "  • QS-Environment:      ${CADDY_DIR}/QS-ENVIRONMENT"
    echo "  • Access-Log:          ${CADDY_LOG_DIR}/qs-access.log"
    echo "  • code-server-Log:     ${CADDY_LOG_DIR}/qs-code-server.log"
    echo "  • Deployment-Log:      ${QS_LOG_FILE}"
    echo ""
    log_message "Nützliche Befehle:"
    echo "  • Status prüfen:       sudo systemctl status caddy"
    echo "  • Logs anzeigen:       sudo journalctl -u caddy -f"
    echo "  • Config validieren:   sudo caddy validate --config ${CADDY_DIR}/Caddyfile"
    echo "  • Config neu laden:    sudo systemctl reload caddy"
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
    echo "  QS-VPS - Caddy Konfigurationsskript für Quality Server"
    echo "  Version 1.0"
    echo "============================================================================"
    echo ""
    
    # Argumente parsen
    parse_arguments "$@"
    
    # Validierungen
    check_root
    check_tailscale_ip_placeholder
    check_caddy_installed
    check_tailscale
    get_tailscale_domain
    check_code_server
    
    # Backup erstellen
    backup_config
    
    # Konfiguration erstellen
    create_directory_structure
    setup_tailscale_certificates
    create_security_headers
    create_code_server_config
    create_main_config
    
    # Konfiguration validieren
    if ! validate_config; then
        error_exit "Konfigurationsvalidierung fehlgeschlagen."
    fi
    
    # Service-Management
    enable_caddy_service
    restart_caddy_service
    
    # Status prüfen
    if ! check_service_status; then
        error_exit "Caddy-Service läuft nicht korrekt."
    fi
    
    # Zusammenfassung anzeigen
    show_summary
    
    log_success "QS-VPS: Konfiguration erfolgreich abgeschlossen!"
    exit 0
}

# Skript ausführen
main "$@"
