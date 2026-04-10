#!/bin/bash
#
# QS-VPS: Caddy Konfigurationsskript für DevSystem Quality Server
#
# Zweck:
#   Konfiguration von Caddy als Reverse Proxy für QS-VPS code-server
#   Angepasste Version mit QS-spezifischen Einstellungen und Tailscale-IP
#   Mit integrierter Idempotenz-Library für wiederholbare Deployments
#
# Voraussetzungen:
#   - Caddy installiert (via install-caddy-qs.sh)
#   - Tailscale installiert und verbunden
#   - Root-Rechte
#
# Parameter:
#   QS_TAILSCALE_IP     Tailscale-IP des QS-VPS (MUSS gesetzt werden)
#   --code-server-port  Port für code-server (Standard: 8080)
#   --force             Force-Redeploy (ignoriert bestehende Marker)
#
# Verwendung:
#   # Platzhalter QS_TAILSCALE_IP im Script ersetzen:
#   sed -i 's/QS_TAILSCALE_IP/100.x.x.x/g' configure-caddy-qs.sh
#   # Dann ausführen:
#   sudo bash configure-caddy-qs.sh
#

set -euo pipefail

# ============================================================================
# IDEMPOTENZ-LIBRARY LADEN
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/idempotency.sh"

# ============================================================================
# KONFIGURATION UND KONSTANTEN
# ============================================================================

# !!! WICHTIG: Diese Variable MUSS vor der Ausführung gesetzt werden !!!
# Entweder als Environment-Variable oder durch sed-Ersetzung im Skript
QS_TAILSCALE_IP="${QS_TAILSCALE_IP:-QS_TAILSCALE_IP}"

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
readonly COMPONENT_NAME="caddy-config"

# Standardwerte für Konfigurationsparameter
CODE_SERVER_PORT="8080"
BACKUP_DIR="${BACKUP_DIR_DEFAULT}"
DOMAIN=""
HOSTNAME="devsystem-qs-vps"

# ============================================================================
# LOGGING-FUNKTIONEN
# ============================================================================

log_message() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] [QS-VPS] INFO:${NC} $1" | tee -a "$QS_LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [QS-VPS] ✓ SUCCESS:${NC} $1" | tee -a "$QS_LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [QS-VPS] ⚠ WARNING:${NC} $1" | tee -a "$QS_LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [QS-VPS] ✗ ERROR:${NC} $1" | tee -a "$QS_LOG_FILE"
}

log_step() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] [QS-VPS] STEP:${NC} $1" | tee -a "$QS_LOG_FILE"
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
  --force                   Force-Redeploy (ignoriert bestehende Marker)
  --help                    Diese Hilfe anzeigen

Beispiele:
  sudo bash configure-caddy-qs.sh
  sudo bash configure-caddy-qs.sh --code-server-port=8080
  sudo bash configure-caddy-qs.sh --force

Voraussetzungen:
  - Caddy muss installiert sein
  - Tailscale muss installiert und verbunden sein
  - Root-Rechte erforderlich

EOF
    exit 0
}

# Kommandozeilenargumente parsen
parse_arguments() {
    export FORCE_REDEPLOY=false
    
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
            --force)
                export FORCE_REDEPLOY=true
                log_warning "Force-Redeploy aktiviert - bestehende Marker werden ignoriert"
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
# KONFIGURATIONSFUNKTIONEN - IDEMPOTENT
# ============================================================================

# Verzeichnisstruktur erstellen
create_directory_structure() {
    run_idempotent "caddy-config-directories" "Caddy-Config-Verzeichnisstruktur erstellen" bash -c "
        mkdir -p '${CADDY_DIR}/sites'
        mkdir -p '${CADDY_DIR}/snippets'
        mkdir -p '${CADDY_DIR}/tls/tailscale'
        mkdir -p '${CADDY_LOG_DIR}'
        
        # QS-Environment Marker aktualisieren
        cat > '${CADDY_DIR}/QS-ENVIRONMENT' << 'EOF_ENV'
QS-VPS Quality Server - Configured: $(date -Iseconds)
Tailscale IP: ${QS_TAILSCALE_IP}
Code Server Port: ${CODE_SERVER_PORT}
EOF_ENV
        
        # Berechtigungen setzen
        if getent passwd caddy > /dev/null 2>&1; then
            chown -R caddy:caddy '${CADDY_DIR}' 2>/dev/null || true
            chown -R caddy:caddy '${CADDY_LOG_DIR}' 2>/dev/null || true
        fi
    "
    
    save_state "$COMPONENT_NAME" "directories_created" "true"
    log_success "Verzeichnisstruktur erstellt."
}

# Tailscale-Zertifikate generieren und konfigurieren
setup_tailscale_certificates() {
    log_step "Prüfe/Generiere Tailscale-Zertifikate..."
    
    local cert_dir="${CADDY_DIR}/tls/tailscale"
    local cert_marker="caddy-tailscale-certs-${DOMAIN}"
    
    # Prüfe ob Zertifikate bereits vorhanden und gültig sind
    if marker_exists "$cert_marker" && [ -f "${cert_dir}/${DOMAIN}.crt" ] && [ -f "${cert_dir}/${DOMAIN}.key" ]; then
        log_message "Tailscale-Zertifikate bereits vorhanden, überspringe Generierung."
        save_state "$COMPONENT_NAME" "tls_mode" "manual"
        return 0
    fi
    
    # Versuche Zertifikate zu generieren
    if tailscale cert "${DOMAIN}" 2>&1 | tee -a "$QS_LOG_FILE"; then
        if [ -f "/var/lib/tailscale/certs/${DOMAIN}.crt" ] && [ -f "/var/lib/tailscale/certs/${DOMAIN}.key" ]; then
            cp "/var/lib/tailscale/certs/${DOMAIN}.crt" "${cert_dir}/"
            cp "/var/lib/tailscale/certs/${DOMAIN}.key" "${cert_dir}/"
            
            if getent passwd caddy > /dev/null 2>&1; then
                chown -R caddy:caddy "${cert_dir}"
                chmod 600 "${cert_dir}/${DOMAIN}.key"
            fi
            
            set_marker "$cert_marker" "Tailscale certificates generated for ${DOMAIN}"
            save_state "$COMPONENT_NAME" "tls_mode" "manual"
            log_success "Tailscale-Zertifikate generiert und installiert."
            return 0
        fi
    fi
    
    # Fallback zu Internal TLS
    save_state "$COMPONENT_NAME" "tls_mode" "internal"
    log_message "Verwende Caddy's automatisches HTTPS (Internal TLS)."
    return 0
}

# Sicherheits-Header-Snippet erstellen
create_security_headers() {
    log_step "Erstelle Sicherheits-Header-Snippet..."
    
    local config_content=$(cat << 'EOF'
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
)
    
    local config_file="${CADDY_DIR}/snippets/security-headers.caddy"
    local current_checksum=""
    local new_checksum=""
    
    # Checksum berechnen
    if [ -f "$config_file" ]; then
        current_checksum=$(file_checksum "$config_file")
    fi
    new_checksum=$(echo "$config_content" | sha256sum | cut -d' ' -f1)
    
    # Nur aktualisieren wenn geändert
    if [ "$current_checksum" != "$new_checksum" ]; then
        backup_file "$config_file" "caddy-security-headers"
        echo "$config_content" > "$config_file"
        
        save_state "$COMPONENT_NAME" "security_headers_checksum" "$new_checksum"
        set_marker "caddy-security-headers" "Security headers snippet created"
        log_success "Sicherheits-Header-Snippet erstellt/aktualisiert."
    else
        log_message "Sicherheits-Header-Snippet unverändert, überspringe."
    fi
}

# code-server Site-Konfiguration erstellen
create_code_server_config() {
    log_step "Erstelle code-server QS-Konfiguration..."
    
    # TLS-Modus ermitteln
    local tls_mode=$(get_state "$COMPONENT_NAME" "tls_mode")
    local use_manual_tls=false
    
    if [ "$tls_mode" = "manual" ] && [ -f "${CADDY_DIR}/tls/tailscale/${DOMAIN}.crt" ] && [ -f "${CADDY_DIR}/tls/tailscale/${DOMAIN}.key" ]; then
        use_manual_tls=true
    fi
    
    # Config-Content generieren
    local config_content=""
    
    # IP-Block
    config_content+="# QS-VPS code-server Reverse Proxy Konfiguration
# Quality Server Environment
# Zugriff nur über QS-Tailscale-IP: ${QS_TAILSCALE_IP}
https://${QS_TAILSCALE_IP}:9443 {
"
    
    if [ "$use_manual_tls" = true ]; then
        config_content+="    # Manuelle TLS-Konfiguration mit Tailscale-Zertifikaten
    tls ${CADDY_DIR}/tls/tailscale/${DOMAIN}.crt ${CADDY_DIR}/tls/tailscale/${DOMAIN}.key
"
    else
        config_content+="    # Automatisches HTTPS über Tailscale
    tls internal
"
    fi
    
    config_content+="    
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
    respond @not_tailscale \"Zugriff nur über Tailscale erlaubt (QS-VPS)\" 403
    
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
https://${DOMAIN}:9443 {
"
    
    if [ "$use_manual_tls" = true ]; then
        config_content+="    tls ${CADDY_DIR}/tls/tailscale/${DOMAIN}.crt ${CADDY_DIR}/tls/tailscale/${DOMAIN}.key
"
    fi
    
    config_content+="    
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
    
    respond @not_tailscale \"Zugriff nur über Tailscale erlaubt (QS-VPS)\" 403
    
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
"
    
    local config_file="${CADDY_DIR}/sites/code-server-qs.caddy"
    local current_checksum=""
    local new_checksum=""
    
    # Checksum berechnen
    if [ -f "$config_file" ]; then
        current_checksum=$(file_checksum "$config_file")
    fi
    new_checksum=$(echo "$config_content" | sha256sum | cut -d' ' -f1)
    
    # Nur aktualisieren wenn geändert
    if [ "$current_checksum" != "$new_checksum" ]; then
        backup_file "$config_file" "caddy-code-server-config"
        echo "$config_content" > "$config_file"
        
        save_state "$COMPONENT_NAME" "code_server_config_checksum" "$new_checksum"
        save_state "$COMPONENT_NAME" "code_server_port" "$CODE_SERVER_PORT"
        save_state "$COMPONENT_NAME" "tailscale_ip" "$QS_TAILSCALE_IP"
        set_marker "caddy-code-server-config" "Code-server config created"
        log_success "code-server QS-Konfiguration erstellt/aktualisiert."
    else
        log_message "code-server-Konfiguration unverändert, überspringe."
    fi
}

# Hauptkonfigurationsdatei (Caddyfile) erstellen
create_main_config() {
    log_step "Erstelle Hauptkonfigurationsdatei (Caddyfile)..."
    
    local config_content=$(cat << 'EOF'
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
)
    
    local config_file="${CADDY_DIR}/Caddyfile"
    local current_checksum=""
    local new_checksum=""
    
    # Checksum berechnen
    if [ -f "$config_file" ]; then
        current_checksum=$(file_checksum "$config_file")
    fi
    new_checksum=$(echo "$config_content" | sha256sum | cut -d' ' -f1)
    
    # Nur aktualisieren wenn geändert
    if [ "$current_checksum" != "$new_checksum" ]; then
        backup_file "$config_file" "caddy-main-config"
        echo "$config_content" > "$config_file"
        
        save_state "$COMPONENT_NAME" "main_config_checksum" "$new_checksum"
        set_marker "caddy-main-config" "Main Caddyfile created"
        log_success "Hauptkonfigurationsdatei erstellt/aktualisiert."
    else
        log_message "Hauptkonfigurationsdatei unverändert, überspringe."
    fi
}

# ============================================================================
# SERVICE-MANAGEMENT
# ============================================================================

# Caddy-Konfiguration validieren
validate_config() {
    log_step "Validiere Caddy-Konfiguration..."
    
    if caddy validate --config "${CADDY_DIR}/Caddyfile" 2>&1 | tee -a "$QS_LOG_FILE"; then
        log_success "Caddy-Konfiguration ist gültig."
        set_marker "caddy-config-validated" "Config validation successful"
        return 0
    else
        log_error "Caddy-Konfiguration ist ungültig!"
        return 1
    fi
}

# Caddy-Service aktivieren
enable_caddy_service() {
    run_idempotent "caddy-service-enabled" "Caddy-Service aktivieren" bash -c '
        systemctl enable caddy
    '
}

# Caddy-Service starten/neu laden
restart_caddy_service() {
    log_step "Starte/Lade Caddy-Service..."
    
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
    set_marker "caddy-service-restarted" "Caddy service restarted/reloaded"
}

# Service-Status prüfen
check_service_status() {
    log_step "Prüfe Caddy-Service-Status..."
    
    if systemctl is-active --quiet caddy; then
        log_success "Caddy-Service läuft."
        
        log_message "Service-Details:"
        systemctl status caddy --no-pager -l | head -n 15 | tee -a "$QS_LOG_FILE"
        
        save_state "$COMPONENT_NAME" "service_status" "active"
        return 0
    else
        log_error "Caddy-Service läuft nicht!"
        log_error "Prüfe Logs mit: journalctl -u caddy -n 50"
        
        log_message "Letzte Log-Einträge:"
        journalctl -u caddy -n 20 --no-pager | tee -a "$QS_LOG_FILE"
        
        save_state "$COMPONENT_NAME" "service_status" "inactive"
        return 1
    fi
}

# Status-Report generieren
generate_status_report() {
    log_step "Generiere Konfigurations-Status-Report..."
    
    local report_file="/var/lib/qs-deployment/reports/caddy-config-report.txt"
    mkdir -p "$(dirname "$report_file")"
    
    cat > "$report_file" << EOF
=============================================================================
QS-VPS Caddy Configuration Status Report
=============================================================================
Datum: $(date -Iseconds)
Component: $COMPONENT_NAME

Konfigurationsparameter:
- QS Tailscale IP: $QS_TAILSCALE_IP
- Tailscale Domain: $DOMAIN
- Code Server Port: $CODE_SERVER_PORT
- TLS Mode: $(get_state "$COMPONENT_NAME" "tls_mode")
- Service Status: $(get_state "$COMPONENT_NAME" "service_status")

Config Checksums:
- Security Headers: $(get_state "$COMPONENT_NAME" "security_headers_checksum")
- Code Server Config: $(get_state "$COMPONENT_NAME" "code_server_config_checksum")
- Main Config: $(get_state "$COMPONENT_NAME" "main_config_checksum")

Aktive Marker:
$(list_markers | grep "^caddy-" || echo "Keine")

Systemd Service Status:
$(systemctl status caddy --no-pager -l 2>&1 || echo "Service-Status konnte nicht abgerufen werden")

=============================================================================
EOF
    
    log_success "Status-Report erstellt: $report_file"
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
    echo "  • TLS Mode:            $(get_state "$COMPONENT_NAME" "tls_mode")"
    echo "  • Environment:         QS-VPS (Quality Server)"
    echo ""
    log_message "Zugriffs-URLs:"
    echo "  • https://${QS_TAILSCALE_IP}:9443"
    echo "  • https://${DOMAIN}:9443"
    echo ""
    log_message "Wichtige Dateien:"
    echo "  • Hauptkonfiguration:  ${CADDY_DIR}/Caddyfile"
    echo "  • Site-Konfiguration:  ${CADDY_DIR}/sites/code-server-qs.caddy"
    echo "  • QS-Environment:      ${CADDY_DIR}/QS-ENVIRONMENT"
    echo "  • Access-Log:          ${CADDY_LOG_DIR}/qs-access.log"
    echo "  • code-server-Log:     ${CADDY_LOG_DIR}/qs-code-server.log"
    echo "  • Deployment-Log:      ${QS_LOG_FILE}"
    echo "  • Status-Report:       /var/lib/qs-deployment/reports/caddy-config-report.txt"
    echo ""
    log_message "Idempotenz-Status:"
    echo "  • Marker-Directory:    $MARKER_DIR"
    echo "  • State-Directory:     $STATE_DIR"
    echo "  • Aktive Marker:       $(list_markers | grep "^caddy-" | wc -l)"
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
    echo "  Version 2.0 (mit Idempotenz)"
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
    
    # Konfiguration erstellen (idempotent)
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
    
    # Status-Report generieren
    generate_status_report
    
    # Zusammenfassung anzeigen
    show_summary
    
    # Finaler Marker
    set_marker "caddy-config-complete" "Full configuration completed"
    
    log_success "QS-VPS: Konfiguration erfolgreich abgeschlossen!"
    exit 0
}

# Skript ausführen
main "$@"
