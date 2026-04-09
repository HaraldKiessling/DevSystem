#!/bin/bash
#
# DevSystem - Caddy Konfigurationsskript
# Autor: DevSystem Team
# Version: 2.0
# Datum: 2026-04-09
#
# Beschreibung:
# Dieses Skript konfiguriert Caddy als Reverse Proxy für das DevSystem-Projekt.
# Es führt folgende Aktionen aus:
# - Erstellung einer Caddyfile-Konfiguration für code-server
# - Reverse Proxy-Konfiguration (localhost:8080)
# - Zugriff NUR über Tailscale-IP (keine öffentliche IP)
# - Automatisches HTTPS/TLS über Tailscale
# - Tailscale-Auth-Integration (nur authentifizierte Tailscale-User)
# - Systemd-Service-Konfiguration
# - Detailliertes Logging und Fehlerbehandlung
# - Backup der alten Konfiguration
#
# Voraussetzungen:
# - Caddy muss installiert sein (via install-caddy.sh)
# - Tailscale muss installiert und konfiguriert sein
# - Root-Zugriff erforderlich
#
# Verwendung:
#   sudo bash configure-caddy.sh [--code-server-port=PORT] [--backup-dir=DIR]
#

set -e  # Script beenden bei Fehler
set -u  # Script beenden bei undefinierter Variable

# ============================================================================
# KONFIGURATION UND KONSTANTEN
# ============================================================================

# Farbdefinitionen für Terminal-Ausgabe
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Verzeichnisse und Dateien
readonly CADDY_DIR="/etc/caddy"
readonly CADDY_LOG_DIR="/var/log/caddy"
readonly BACKUP_DIR_DEFAULT="/var/backups/caddy"
readonly LOG_FILE="/var/log/devsystem-configure-caddy.log"

# Standardwerte für Konfigurationsparameter
CODE_SERVER_PORT="8080"
BACKUP_DIR="${BACKUP_DIR_DEFAULT}"
DOMAIN=""
TAILSCALE_IP=""

# ============================================================================
# LOGGING-FUNKTIONEN
# ============================================================================

# Logging in Datei und Terminal
exec > >(tee -a "$LOG_FILE")
exec 2>&1

log_message() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓ SUCCESS:${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠ WARNING:${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗ ERROR:${NC} $1"
}

log_step() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] STEP:${NC} $1"
}

# Fehlerbehandlung mit Exit
error_exit() {
    log_error "$1"
    log_error "Konfiguration fehlgeschlagen. Siehe Log: ${LOG_FILE}"
    exit 1
}

# ============================================================================
# HILFSFUNKTIONEN
# ============================================================================

# Hilfe-Text anzeigen
show_help() {
    cat << EOF
DevSystem - Caddy Konfigurationsskript

Verwendung: sudo bash configure-caddy.sh [Optionen]

Optionen:
  --code-server-port=PORT   Port für code-server (Standard: 8080)
  --backup-dir=DIR          Verzeichnis für Backups (Standard: ${BACKUP_DIR_DEFAULT})
  --help                    Diese Hilfe anzeigen

Beispiele:
  sudo bash configure-caddy.sh
  sudo bash configure-caddy.sh --code-server-port=8080
  sudo bash configure-caddy.sh --backup-dir=/backup/caddy

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

# Prüfen, ob Caddy installiert ist
check_caddy_installed() {
    log_step "Prüfe ob Caddy installiert ist..."
    
    if ! command -v caddy &> /dev/null; then
        error_exit "Caddy ist nicht installiert. Bitte führe zuerst 'install-caddy.sh' aus."
    fi
    
    local caddy_version=$(caddy version 2>&1 | head -n1)
    log_success "Caddy ist installiert: ${caddy_version}"
}

# Prüfen, ob Tailscale installiert und verbunden ist
check_tailscale() {
    log_step "Prüfe Tailscale-Installation und -Status..."
    
    if ! command -v tailscale &> /dev/null; then
        error_exit "Tailscale ist nicht installiert. Bitte führe zuerst 'install-tailscale.sh' aus."
    fi
    
    # Tailscale-Status prüfen
    if ! tailscale status &> /dev/null; then
        error_exit "Tailscale ist nicht verbunden. Bitte verbinde Tailscale zuerst."
    fi
    
    log_success "Tailscale ist installiert und verbunden."
}

# Tailscale-IP ermitteln und validieren
get_tailscale_ip() {
    log_step "Ermittle Tailscale-IP-Adresse..."
    
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null | head -n1)
    
    if [ -z "$TAILSCALE_IP" ]; then
        error_exit "Konnte Tailscale-IP nicht ermitteln. Ist Tailscale verbunden?"
    fi
    
    # IP-Format validieren (100.x.x.x)
    if [[ ! "$TAILSCALE_IP" =~ ^100\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        error_exit "Ungültige Tailscale-IP: ${TAILSCALE_IP}. Erwartet: 100.x.x.x"
    fi
    
    log_success "Tailscale-IP ermittelt: ${TAILSCALE_IP}"
}

# Tailscale-Domain ermitteln
get_tailscale_domain() {
    log_step "Ermittle Tailscale-Domain..."
    
    # Versuche Domain aus Tailscale-Status zu ermitteln
    if command -v jq &> /dev/null; then
        local ts_status=$(tailscale status --json 2>/dev/null)
        DOMAIN=$(echo "$ts_status" | jq -r '.Self.DNSName' | sed 's/\.$//')
        
        if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "null" ]; then
            DOMAIN=$(hostname -f 2>/dev/null || hostname)
        fi
    else
        # Fallback ohne jq
        DOMAIN=$(tailscale status --json 2>/dev/null | grep -o '"DNSName":"[^"]*"' | cut -d'"' -f4 | sed 's/\.$//' || hostname)
    fi
    
    if [ -z "$DOMAIN" ]; then
        DOMAIN="$(hostname).tailscale.net"
        log_warning "Konnte Domain nicht automatisch ermitteln. Verwende: ${DOMAIN}"
    else
        log_success "Tailscale-Domain ermittelt: ${DOMAIN}"
    fi
}

# Prüfen, ob code-server läuft
check_code_server() {
    log_step "Prüfe ob code-server auf Port ${CODE_SERVER_PORT} erreichbar ist..."
    
    if ! nc -z localhost "${CODE_SERVER_PORT}" 2>/dev/null && ! timeout 2 bash -c "echo > /dev/tcp/localhost/${CODE_SERVER_PORT}" 2>/dev/null; then
        log_warning "code-server scheint nicht auf Port ${CODE_SERVER_PORT} zu laufen."
        log_warning "Caddy wird trotzdem konfiguriert, aber der Proxy funktioniert erst, wenn code-server läuft."
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
    
    # Backup-Verzeichnis erstellen
    mkdir -p "${BACKUP_DIR}"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="${BACKUP_DIR}/caddy_backup_${timestamp}"
    
    # Prüfen, ob Konfiguration existiert
    if [ -f "${CADDY_DIR}/Caddyfile" ]; then
        mkdir -p "${backup_path}"
        
        # Caddyfile sichern
        cp -r "${CADDY_DIR}/Caddyfile" "${backup_path}/" 2>/dev/null || true
        
        # Sites-Verzeichnis sichern
        if [ -d "${CADDY_DIR}/sites" ]; then
            cp -r "${CADDY_DIR}/sites" "${backup_path}/" 2>/dev/null || true
        fi
        
        # Snippets-Verzeichnis sichern
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
    
    # Alte Zertifikate entfernen
    rm -f "${cert_dir}/${DOMAIN}.crt" 2>/dev/null || true
    rm -f "${cert_dir}/${DOMAIN}.key" 2>/dev/null || true
    
    # Tailscale-Zertifikate generieren
    if tailscale cert "${DOMAIN}" 2>&1 | tee -a "$LOG_FILE"; then
        # Zertifikate kopieren
        if [ -f "/var/lib/tailscale/certs/${DOMAIN}.crt" ] && [ -f "/var/lib/tailscale/certs/${DOMAIN}.key" ]; then
            cp "/var/lib/tailscale/certs/${DOMAIN}.crt" "${cert_dir}/"
            cp "/var/lib/tailscale/certs/${DOMAIN}.key" "${cert_dir}/"
            
            # Berechtigungen setzen
            if getent passwd caddy > /dev/null 2>&1; then
                chown -R caddy:caddy "${cert_dir}"
                chmod 600 "${cert_dir}/${DOMAIN}.key"
            fi
            
            log_success "Tailscale-Zertifikate generiert und installiert."
            return 0
        else
            log_warning "Zertifikatsdateien nicht gefunden in /var/lib/tailscale/certs/"
        fi
    else
        log_warning "Konnte Tailscale-Zertifikate nicht generieren."
    fi
    
    # Fallback: Verwende Caddy's automatisches HTTPS
    log_message "Verwende Caddy's automatisches HTTPS über Tailscale."
    return 1
}

# Sicherheits-Header-Snippet erstellen
create_security_headers() {
    log_step "Erstelle Sicherheits-Header-Snippet..."
    
    cat > "${CADDY_DIR}/snippets/security-headers.caddy" << 'EOF'
header {
    # Strict-Transport-Security aktivieren
    Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    
    # XSS-Schutz aktivieren
    X-XSS-Protection "1; mode=block"
    
    # Clickjacking-Schutz
    X-Frame-Options "SAMEORIGIN"
    
    # MIME-Sniffing verhindern
    X-Content-Type-Options "nosniff"
    
    # Referrer-Policy einschränken
    Referrer-Policy "strict-origin-when-cross-origin"
    
    # Content-Security-Policy für erhöhte Sicherheit
    Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; connect-src 'self' ws: wss:; font-src 'self' data:; frame-ancestors 'self';"
    
    # Entfernen von Server-Header
    -Server
}
EOF
    
    log_success "Sicherheits-Header-Snippet erstellt."
}

# Tailscale-Auth-Snippet erstellen
create_tailscale_auth() {
    log_step "Erstelle Tailscale-Authentifizierung-Snippet..."
    
    cat > "${CADDY_DIR}/snippets/tailscale-auth.caddy" << 'EOF'
# Nur Zugriff über Tailscale erlauben (CGNAT-Bereich)
@tailscale {
    remote_ip 100.64.0.0/10
}

# Zugriff verweigern, wenn nicht über Tailscale
handle @not_tailscale {
    respond "Zugriff nur über Tailscale erlaubt" 403
}
EOF
    
    log_success "Tailscale-Authentifizierung-Snippet erstellt."
}

# code-server Site-Konfiguration erstellen
create_code_server_config() {
    log_step "Erstelle code-server Konfiguration..."
    
    # Prüfen, ob Zertifikate vorhanden sind
    local use_manual_tls=false
    if [ -f "${CADDY_DIR}/tls/tailscale/${DOMAIN}.crt" ] && [ -f "${CADDY_DIR}/tls/tailscale/${DOMAIN}.key" ]; then
        use_manual_tls=true
    fi
    
    cat > "${CADDY_DIR}/sites/code-server.caddy" << EOF
# code-server Reverse Proxy Konfiguration
# Zugriff nur über Tailscale-IP: ${TAILSCALE_IP}
https://${TAILSCALE_IP} {
EOF

    # TLS-Konfiguration hinzufügen, falls manuelle Zertifikate vorhanden
    if [ "$use_manual_tls" = true ]; then
        cat >> "${CADDY_DIR}/sites/code-server.caddy" << EOF
    # Manuelle TLS-Konfiguration mit Tailscale-Zertifikaten
    tls ${CADDY_DIR}/tls/tailscale/${DOMAIN}.crt ${CADDY_DIR}/tls/tailscale/${DOMAIN}.key
EOF
    else
        cat >> "${CADDY_DIR}/sites/code-server.caddy" << EOF
    # Automatisches HTTPS über Tailscale
    tls internal
EOF
    fi

    cat >> "${CADDY_DIR}/sites/code-server.caddy" << EOF
    
    # Nur Zugriff über Tailscale-IP-Bereich erlauben
    @tailscale {
        remote_ip 100.64.0.0/10
    }
    
    # Reverse Proxy zu code-server
    reverse_proxy @tailscale localhost:${CODE_SERVER_PORT} {
        # Header für WebSocket-Unterstützung (wichtig für code-server)
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
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
    respond @not_tailscale "Zugriff nur über Tailscale erlaubt" 403
    
    # Sicherheits-Header importieren
    import ${CADDY_DIR}/snippets/security-headers.caddy
    
    # Kompression aktivieren
    encode gzip zstd
    
    # Logging
    log {
        output file ${CADDY_LOG_DIR}/code-server.log {
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
        cat >> "${CADDY_DIR}/sites/code-server.caddy" << EOF
    tls ${CADDY_DIR}/tls/tailscale/${DOMAIN}.crt ${CADDY_DIR}/tls/tailscale/${DOMAIN}.key
EOF
    fi

    cat >> "${CADDY_DIR}/sites/code-server.caddy" << EOF
    
    @tailscale {
        remote_ip 100.64.0.0/10
    }
    
    reverse_proxy @tailscale localhost:${CODE_SERVER_PORT} {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
        header_up Connection {http.request.header.Connection}
        header_up Upgrade {http.request.header.Upgrade}
        
        transport http {
            keepalive 30m
            keepalive_idle_conns 10
            read_timeout 0
            write_timeout 0
        }
    }
    
    respond @not_tailscale "Zugriff nur über Tailscale erlaubt" 403
    
    import ${CADDY_DIR}/snippets/security-headers.caddy
    encode gzip zstd
    
    log {
        output file ${CADDY_LOG_DIR}/code-server.log {
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
    
    log_success "code-server Konfiguration erstellt."
}

# Hauptkonfigurationsdatei (Caddyfile) erstellen
create_main_config() {
    log_step "Erstelle Hauptkonfigurationsdatei (Caddyfile)..."
    
    cat > "${CADDY_DIR}/Caddyfile" << 'EOF'
# DevSystem Caddy Hauptkonfiguration
# Generiert durch configure-caddy.sh

# Globale Optionen
{
    # Admin-API deaktivieren (Sicherheit)
    admin off
    
    # Server-Einstellungen
    servers {
        protocol {
            # Nur moderne TLS-Versionen
            min_tls_version 1.2
            
            # HTTP/3 experimentell aktivieren
            experimental_http3
            
            # Strict SNI Host
            strict_sni_host
        }
        
        # Timeouts
        timeouts {
            read_body 30s
            read_header 10s
            write 60s
            idle 5m
        }
    }
    
    # Globales Logging
    log {
        output file /var/log/caddy/access.log {
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

# Zertifikatserneuerung-Skript erstellen
create_cert_renewal_script() {
    log_step "Erstelle Zertifikatserneuerung-Skript..."
    
    cat > /usr/local/bin/tailscale-cert-renew.sh << EOF
#!/bin/bash
#
# Tailscale-Zertifikatserneuerung für Caddy
# Automatisch generiert durch configure-caddy.sh
#

DOMAIN="${DOMAIN}"
CERT_DIR="${CADDY_DIR}/tls/tailscale"

echo "\$(date '+%Y-%m-%d %H:%M:%S') - Starte Zertifikatserneuerung für \${DOMAIN}"

# Zertifikate erneuern
if tailscale cert "\${DOMAIN}"; then
    # Zertifikate kopieren
    if [ -f "/var/lib/tailscale/certs/\${DOMAIN}.crt" ] && [ -f "/var/lib/tailscale/certs/\${DOMAIN}.key" ]; then
        cp "/var/lib/tailscale/certs/\${DOMAIN}.crt" "\${CERT_DIR}/"
        cp "/var/lib/tailscale/certs/\${DOMAIN}.key" "\${CERT_DIR}/"
        
        # Berechtigungen setzen
        chown -R caddy:caddy "\${CERT_DIR}"
        chmod 600 "\${CERT_DIR}/\${DOMAIN}.key"
        
        # Caddy neu laden
        systemctl reload caddy
        
        echo "\$(date '+%Y-%m-%d %H:%M:%S') - Zertifikate erfolgreich erneuert und Caddy neu geladen"
    else
        echo "\$(date '+%Y-%m-%d %H:%M:%S') - FEHLER: Zertifikatsdateien nicht gefunden"
        exit 1
    fi
else
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - FEHLER: Konnte Zertifikate nicht erneuern"
    exit 1
fi
EOF
    
    chmod +x /usr/local/bin/tailscale-cert-renew.sh
    
    # Cron-Job einrichten (monatlich)
    local cron_job="0 0 1 * * /usr/local/bin/tailscale-cert-renew.sh >> /var/log/tailscale-cert-renew.log 2>&1"
    (crontab -l 2>/dev/null | grep -v "tailscale-cert-renew.sh"; echo "$cron_job") | crontab -
    
    log_success "Zertifikatserneuerung-Skript erstellt und Cron-Job eingerichtet."
}

# ============================================================================
# SERVICE-MANAGEMENT
# ============================================================================

# Caddy-Konfiguration validieren
validate_config() {
    log_step "Validiere Caddy-Konfiguration..."
    
    if caddy validate --config "${CADDY_DIR}/Caddyfile" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Caddy-Konfiguration ist gültig."
        return 0
    else
        log_error "Caddy-Konfiguration ist ungültig!"
        log_error "Bitte überprüfe die Konfigurationsdateien in ${CADDY_DIR}"
        return 1
    fi
}

# Caddy-Service aktivieren
enable_caddy_service() {
    log_step "Aktiviere Caddy-Service für automatischen Start..."
    
    if systemctl enable caddy 2>&1 | tee -a "$LOG_FILE"; then
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
        if systemctl reload caddy 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Caddy-Konfiguration neu geladen."
        else
            log_warning "Reload fehlgeschlagen. Versuche Neustart..."
            systemctl restart caddy 2>&1 | tee -a "$LOG_FILE"
        fi
    else
        log_message "Starte Caddy-Service..."
        if systemctl start caddy 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Caddy-Service gestartet."
        else
            error_exit "Konnte Caddy-Service nicht starten. Prüfe Logs mit: journalctl -u caddy -n 50"
        fi
    fi
    
    # Kurz warten, damit Service hochfahren kann
    sleep 2
}

# Service-Status prüfen
check_service_status() {
    log_step "Prüfe Caddy-Service-Status..."
    
    if systemctl is-active --quiet caddy; then
        log_success "Caddy-Service läuft."
        
        # Detaillierte Status-Informationen
        log_message "Service-Details:"
        systemctl status caddy --no-pager -l | head -n 15 | tee -a "$LOG_FILE"
        
        return 0
    else
        log_error "Caddy-Service läuft nicht!"
        log_error "Prüfe Logs mit: journalctl -u caddy -n 50"
        
        # Zeige letzte Log-Einträge
        log_message "Letzte Log-Einträge:"
        journalctl -u caddy -n 20 --no-pager | tee -a "$LOG_FILE"
        
        return 1
    fi
}

# ============================================================================
# ZUSAMMENFASSUNG UND AUSGABE
# ============================================================================

# Abschlussinformationen anzeigen
show_summary() {
    echo ""
    echo "============================================================================"
    log_success "Caddy-Konfiguration erfolgreich abgeschlossen!"
    echo "============================================================================"
    echo ""
    log_message "Konfigurationsdetails:"
    echo "  • Tailscale-IP:        ${TAILSCALE_IP}"
    echo "  • Tailscale-Domain:    ${DOMAIN}"
    echo "  • code-server Port:    ${CODE_SERVER_PORT}"
    echo "  • Zugriff nur über:    Tailscale VPN (100.64.0.0/10)"
    echo ""
    log_message "Zugriffs-URLs:"
    echo "  • https://${TAILSCALE_IP}"
    echo "  • https://${DOMAIN}"
    echo ""
    log_message "Wichtige Dateien:"
    echo "  • Hauptkonfiguration:  ${CADDY_DIR}/Caddyfile"
    echo "  • Site-Konfiguration:  ${CADDY_DIR}/sites/code-server.caddy"
    echo "  • Sicherheits-Header:  ${CADDY_DIR}/snippets/security-headers.caddy"
    echo "  • Access-Log:          ${CADDY_LOG_DIR}/access.log"
    echo "  • code-server-Log:     ${CADDY_LOG_DIR}/code-server.log"
    echo "  • Konfig-Log:          ${LOG_FILE}"
    echo ""
    log_message "Nützliche Befehle:"
    echo "  • Status prüfen:       sudo systemctl status caddy"
    echo "  • Logs anzeigen:       sudo journalctl -u caddy -f"
    echo "  • Config validieren:   sudo caddy validate --config ${CADDY_DIR}/Caddyfile"
    echo "  • Config neu laden:    sudo systemctl reload caddy"
    echo "  • Service neustarten:  sudo systemctl restart caddy"
    echo "  • Zertifikate erneuern: sudo /usr/local/bin/tailscale-cert-renew.sh"
    echo ""
    log_message "Nächste Schritte:"
    echo "  1. Stelle sicher, dass code-server auf Port ${CODE_SERVER_PORT} läuft"
    echo "  2. Greife über Tailscale auf https://${TAILSCALE_IP} zu"
    echo "  3. Prüfe die Logs bei Problemen: journalctl -u caddy -f"
    echo ""
    echo "============================================================================"
    echo ""
}

# ============================================================================
# HAUPTPROGRAMM
# ============================================================================

main() {
    # Banner
    echo ""
    echo "============================================================================"
    echo "  DevSystem - Caddy Konfigurationsskript"
    echo "  Version 2.0"
    echo "============================================================================"
    echo ""
    
    # Argumente parsen
    parse_arguments "$@"
    
    # Validierungen
    check_root
    check_caddy_installed
    check_tailscale
    get_tailscale_ip
    get_tailscale_domain
    check_code_server
    
    # Backup erstellen
    backup_config
    
    # Konfiguration erstellen
    create_directory_structure
    setup_tailscale_certificates
    create_security_headers
    create_tailscale_auth
    create_code_server_config
    create_main_config
    create_cert_renewal_script
    
    # Konfiguration validieren
    if ! validate_config; then
        error_exit "Konfigurationsvalidierung fehlgeschlagen. Breche ab."
    fi
    
    # Service-Management
    enable_caddy_service
    restart_caddy_service
    
    # Status prüfen
    if ! check_service_status; then
        error_exit "Caddy-Service läuft nicht korrekt. Prüfe die Logs."
    fi
    
    # Zusammenfassung anzeigen
    show_summary
    
    log_success "Konfiguration erfolgreich abgeschlossen!"
    exit 0
}

# Skript ausführen
main "$@"