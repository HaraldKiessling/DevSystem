#!/bin/bash
#
# QS-VPS: Caddy Installationsskript für DevSystem Quality Server
# 
# Zweck:
#   Installation von Caddy als Reverse Proxy auf dem QS-VPS
#   Angepasste Version für den Quality-Server mit QS-spezifischen Einstellungen
#   Mit integrierter Idempotenz-Library für wiederholbare Deployments
#
# Voraussetzungen:
#   - Ubuntu System
#   - Root-Rechte
#   - Tailscale installiert und konfiguriert
#
# Parameter:
#   --hostname=NAME     Hostname (Standard: devsystem-qs-vps)
#   --config-only       Nur Konfiguration, keine Installation
#   --force             Force-Redeploy (ignoriert bestehende Marker)
#
# Verwendung:
#   sudo bash install-caddy-qs.sh [--hostname=devsystem-qs-vps] [--force]
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

# Farbdefinitionen für Terminal-Ausgabe
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# QS-spezifische Einstellungen
readonly QS_LOG_FILE="/var/log/qs-deployment.log"
readonly QS_MARKER="QS-VPS"
readonly COMPONENT_NAME="caddy"

# Logging-Funktion mit QS-Marker
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
    
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [${QS_MARKER}] [$level] $message${NC}" | tee -a "$QS_LOG_FILE"
}

# Fehlermeldung und Exit-Funktion
error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Root-Berechtigungen prüfen
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error_exit "Dieses Skript muss als Root ausgeführt werden. Bitte verwenden Sie 'sudo'."
    fi
}

# Kommandozeilenargumente parsen
parse_args() {
    CONFIG_ONLY=false
    export FORCE_REDEPLOY=false
    
    for arg in "$@"; do
        case $arg in
            --hostname=*)
                HOSTNAME="${arg#*=}"
                ;;
            --config-only)
                CONFIG_ONLY=true
                ;;
            --force)
                export FORCE_REDEPLOY=true
                log "WARN" "Force-Redeploy aktiviert - bestehende Marker werden ignoriert"
                ;;
            --help)
                echo "Verwendung: sudo bash install-caddy-qs.sh [--hostname=NAME] [--config-only] [--force]"
                echo ""
                echo "Optionen:"
                echo "  --hostname=NAME     Spezifiziert den QS-Hostname (Standard: devsystem-qs-vps)"
                echo "  --config-only       Nur Konfiguration durchführen, keine Installation"
                echo "  --force             Force-Redeploy (ignoriert bestehende Marker)"
                echo ""
                exit 0
                ;;
        esac
    done
    
    # QS-spezifischer Standardwert
    HOSTNAME=${HOSTNAME:-"devsystem-qs-vps"}
}

# Systemvoraussetzungen prüfen
check_prerequisites() {
    log "STEP" "Prüfe Systemvoraussetzungen für QS-VPS..."
    
    # Prüfen, ob Ubuntu verwendet wird
    if [ ! -f /etc/lsb-release ] || ! grep -q "Ubuntu" /etc/lsb-release; then
        error_exit "Dieses Skript ist für Ubuntu-Systeme ausgelegt."
    fi
    
    # Prüfen, ob Tailscale installiert ist
    if ! command -v tailscale &> /dev/null; then
        log "WARN" "Tailscale scheint nicht installiert zu sein. Es wird für HTTPS-Zertifikate benötigt."
    fi
    
    # Prüfen, ob die erforderlichen Befehle installiert sind
    for cmd in apt-get curl systemctl; do
        if ! command -v $cmd &> /dev/null; then
            error_exit "Der Befehl '$cmd' wird benötigt, ist aber nicht installiert."
        fi
    done
    
    log "INFO" "Systemvoraussetzungen erfüllt."
}

# Prüfen, ob Caddy bereits installiert ist (mit State-Check)
check_caddy_installation() {
    if marker_exists "caddy-installed"; then
        local installed_version=$(get_state "$COMPONENT_NAME" "version")
        log "INFO" "Caddy ist bereits installiert (Version: $installed_version)"
        return 0
    else
        return 1
    fi
}

# Caddy Repository hinzufügen
setup_caddy_repository() {
    run_idempotent "caddy-repo-setup" "Caddy Repository einrichten" bash -c '
        apt-get update -y
        apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
        curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
        curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt" | tee /etc/apt/sources.list.d/caddy-stable.list
        apt-get update -y
    '
}

# Caddy installieren
install_caddy() {
    log "STEP" "Installiere Caddy auf QS-VPS..."
    
    # Repository Setup
    setup_caddy_repository
    
    # Caddy-Paket installieren
    run_idempotent "caddy-package-install" "Caddy-Paket installieren" bash -c '
        apt-get install -y caddy
    '
    
    # Version speichern
    local caddy_version=$(caddy version 2>&1 | head -n1 || echo "unknown")
    save_state "$COMPONENT_NAME" "version" "$caddy_version"
    save_state "$COMPONENT_NAME" "install_date" "$(date -Iseconds)"
    
    # Gesamt-Marker setzen
    set_marker "caddy-installed" "Caddy installed: $caddy_version"
    
    log "INFO" "Caddy erfolgreich auf QS-VPS installiert: $caddy_version"
}

# Caddy Verzeichnisstruktur erstellen (QS-spezifisch)
create_directory_structure() {
    run_idempotent "caddy-directories" "Caddy-Verzeichnisstruktur erstellen" bash -c '
        # Erstelle Hauptverzeichnisse mit QS-Kennzeichnung
        mkdir -p /etc/caddy/sites
        mkdir -p /etc/caddy/snippets
        mkdir -p /etc/caddy/tls/tailscale
        mkdir -p /etc/caddy/tls/local
        mkdir -p /var/log/caddy
        
        # QS-Marker-Datei erstellen
        cat > /etc/caddy/QS-ENVIRONMENT << EOF_MARKER
QS-VPS Quality Server
Erstellt: $(date -Iseconds)
Hostname: '"${HOSTNAME}"'
EOF_MARKER
        
        # Setze Berechtigungen
        chown -R caddy:caddy /etc/caddy
        chown -R caddy:caddy /var/log/caddy
    '
    
    save_state "$COMPONENT_NAME" "directories_created" "true"
    log "INFO" "QS-Verzeichnisstruktur erfolgreich erstellt."
}

# Konfiguration für automatischen Start
configure_autostart() {
    run_idempotent "caddy-autostart" "Caddy automatischen Start konfigurieren" bash -c '
        systemctl enable caddy
    '
    
    log "INFO" "Automatischer Start erfolgreich konfiguriert."
}

# Erstellen der Grundkonfiguration (Caddyfile) mit QS-Kennzeichnung
create_base_config() {
    log "STEP" "Erstelle grundlegende QS-Caddyfile-Konfiguration..."
    
    local config_content=$(cat << EOF
# QS-VPS Caddy Konfiguration - Quality Server Environment
# Hostname: ${HOSTNAME}
# Erstellt: $(date -Iseconds)

# Globale Optionen
{
    # Admin-API deaktivieren (Sicherheitsmaßnahme)
    admin off
    
    # Standardprotokoll auf HTTP/2 setzen
    servers {
        protocol {
            experimental_http3
            strict_sni_host
            min_tls_version 1.2
        }
        
        # Verbindungs-Timeouts und Limits
        timeouts {
            read_body 30s
            read_header 10s
            write 60s
            idle 5m
        }
    }
    
    # Log-Einstellungen
    log {
        output file /var/log/caddy/qs-access.log {
            roll_size 100MB
            roll_keep 10
            roll_keep_for 720h
        }
        format json
    }
}

# Gemeinsame Snippets importieren
import /etc/caddy/snippets/*.caddy

# Site-Konfigurationen importieren
import /etc/caddy/sites/*.caddy
EOF
)
    
    local config_file="/etc/caddy/Caddyfile"
    local current_checksum=""
    local new_checksum=""
    
    # Checksum berechnen falls Datei existiert
    if [ -f "$config_file" ]; then
        current_checksum=$(file_checksum "$config_file")
    fi
    
    # Neue Checksum berechnen
    new_checksum=$(echo "$config_content" | sha256sum | cut -d' ' -f1)
    
    # Nur aktualisieren wenn sich etwas geändert hat
    if [ "$current_checksum" != "$new_checksum" ]; then
        # Backup erstellen
        backup_file "$config_file" "caddy-base-config"
        
        # Neue Config schreiben
        echo "$config_content" > "$config_file"
        
        save_state "$COMPONENT_NAME" "base_config_checksum" "$new_checksum"
        save_state "$COMPONENT_NAME" "base_config_updated" "$(date -Iseconds)"
        
        set_marker "caddy-base-config" "Base Caddyfile created"
        log "INFO" "Grundlegende QS-Caddyfile-Konfiguration erstellt/aktualisiert."
    else
        log "INFO" "QS-Caddyfile-Konfiguration unverändert, überspringe Aktualisierung."
    fi
}

# Sicherheitskonfiguration erstellen
create_security_config() {
    run_idempotent "caddy-security-config" "Sicherheitskonfiguration erstellen" bash -c '
        cat > /etc/caddy/snippets/security-headers.caddy << '\''EOF_SEC'\''
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
EOF_SEC
    '
    
    log "INFO" "Sicherheitskonfiguration erfolgreich erstellt."
}

# Verifiziere die Installation
verify_installation() {
    log "STEP" "Verifiziere die Caddy-Installation..."
    
    # Caddy-Version prüfen
    if command -v caddy &> /dev/null; then
        local version=$(caddy version 2>&1 | head -n1)
        log "INFO" "Caddy-Version: $version"
    else
        error_exit "Caddy-Befehl nicht gefunden nach Installation!"
    fi
    
    # Caddyfile validieren
    log "INFO" "Validiere Caddyfile..."
    if caddy validate --config /etc/caddy/Caddyfile 2>&1 | tee -a "$QS_LOG_FILE"; then
        log "INFO" "Caddyfile ist gültig."
        set_marker "caddy-validated" "Caddyfile validation successful"
    else
        log "ERROR" "Caddyfile enthält Fehler."
        return 1
    fi
    
    # Systemd-Service prüfen
    if systemctl is-enabled caddy &> /dev/null; then
        log "INFO" "Caddy-Service ist aktiviert."
    else
        log "WARN" "Caddy-Service ist nicht aktiviert."
    fi
    
    log "INFO" "Verifizierung abgeschlossen."
    return 0
}

# Installation-Status-Report generieren
generate_status_report() {
    log "STEP" "Generiere Installations-Status-Report..."
    
    local report_file="/var/lib/qs-deployment/reports/caddy-install-report.txt"
    mkdir -p "$(dirname "$report_file")"
    
    cat > "$report_file" << EOF
=============================================================================
QS-VPS Caddy Installation Status Report
=============================================================================
Datum: $(date -Iseconds)
Hostname: $HOSTNAME
Component: $COMPONENT_NAME

Installation Details:
- Version: $(get_state "$COMPONENT_NAME" "version")
- Install-Datum: $(get_state "$COMPONENT_NAME" "install_date")
- Directories: $(get_state "$COMPONENT_NAME" "directories_created")
- Base Config Checksum: $(get_state "$COMPONENT_NAME" "base_config_checksum")
- Letztes Config-Update: $(get_state "$COMPONENT_NAME" "base_config_updated")

Aktive Marker:
$(list_markers | grep "^caddy" || echo "Keine")

Systemd Service Status:
$(systemctl status caddy --no-pager -l || echo "Service-Status konnte nicht abgerufen werden")

Config Validation:
$(caddy validate --config /etc/caddy/Caddyfile 2>&1 || echo "Validation fehlgeschlagen")

=============================================================================
EOF
    
    log "INFO" "Status-Report erstellt: $report_file"
}

# Informationen anzeigen
show_info() {
    echo ""
    log "STEP" "QS-VPS: Caddy-Installation abgeschlossen!"
    echo ""
    echo -e "${GREEN}Caddy wurde erfolgreich auf dem QS-VPS installiert.${NC}"
    echo ""
    echo "QS-spezifische Konfiguration:"
    echo "  - Hostname:                     $HOSTNAME"
    echo "  - Environment:                  QS-VPS (Quality Server)"
    echo "  - Hauptkonfiguration:           /etc/caddy/Caddyfile"
    echo "  - Site-Konfigurationen:         /etc/caddy/sites/"
    echo "  - Sicherheits-Snippets:         /etc/caddy/snippets/"
    echo "  - QS-Marker:                    /etc/caddy/QS-ENVIRONMENT"
    echo "  - Logs:                         /var/log/qs-deployment.log"
    echo "  - Status-Report:                /var/lib/qs-deployment/reports/caddy-install-report.txt"
    echo ""
    echo "Idempotenz-Status:"
    echo "  - Marker-Directory:             $MARKER_DIR"
    echo "  - State-Directory:              $STATE_DIR"
    echo "  - Aktive Marker:                $(list_markers | grep "^caddy" | wc -l)"
    echo ""
    echo "Nächste Schritte:"
    echo "  1. Führe configure-caddy-qs.sh aus (mit QS_TAILSCALE_IP)"
    echo "  2. Teste die Caddy-Konfiguration"
    echo ""
}

# Hauptfunktion
main() {
    log "STEP" "Starte QS-VPS Caddy-Installation (mit Idempotenz)..."
    
    # Prüfungen
    check_root
    parse_args "$@"
    check_prerequisites
    
    # Installation, wenn Caddy noch nicht installiert ist
    if [ "$CONFIG_ONLY" != "true" ]; then
        if ! check_caddy_installation; then
            install_caddy
        else
            log "INFO" "Caddy ist bereits installiert, überspringe Installation."
        fi
    else
        log "INFO" "Überspringe Installation, nur Konfiguration wird durchgeführt."
    fi
    
    # Konfigurationen (idempotent)
    create_directory_structure
    configure_autostart
    create_base_config
    create_security_config
    
    # Verifizieren und abschließen
    verify_installation
    generate_status_report
    show_info
    
    # Finaler Marker
    set_marker "caddy-install-complete" "Full installation completed"
    
    log "INFO" "QS-VPS: Caddy-Installation erfolgreich abgeschlossen."
}

# Skript ausführen
main "$@"
