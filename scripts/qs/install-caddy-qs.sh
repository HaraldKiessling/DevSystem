#!/bin/bash
#
# QS-VPS: Caddy Installationsskript für DevSystem Quality Server
# 
# Zweck:
#   Installation von Caddy als Reverse Proxy auf dem QS-VPS
#   Angepasste Version für den Quality-Server mit QS-spezifischen Einstellungen
#
# Voraussetzungen:
#   - Ubuntu System
#   - Root-Rechte
#   - Tailscale installiert und konfiguriert
#
# Parameter:
#   --hostname=NAME     Hostname (Standard: devsystem-qs-vps)
#   --config-only       Nur Konfiguration, keine Installation
#
# Verwendung:
#   sudo bash install-caddy-qs.sh [--hostname=devsystem-qs-vps]
#

set -euo pipefail

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
    
    for arg in "$@"; do
        case $arg in
            --hostname=*)
                HOSTNAME="${arg#*=}"
                ;;
            --config-only)
                CONFIG_ONLY=true
                ;;
            --help)
                echo "Verwendung: sudo bash install-caddy-qs.sh [--hostname=NAME] [--config-only]"
                echo ""
                echo "Optionen:"
                echo "  --hostname=NAME     Spezifiziert den QS-Hostname (Standard: devsystem-qs-vps)"
                echo "  --config-only       Nur Konfiguration durchführen, keine Installation"
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

# Prüfen, ob Caddy bereits installiert ist
check_caddy() {
    if command -v caddy &> /dev/null; then
        log "WARN" "Caddy ist bereits installiert. Überspringe die Installation."
        return 0
    else
        return 1
    fi
}

# Caddy installieren
install_caddy() {
    log "STEP" "Installiere Caddy auf QS-VPS..."
    
    # Aktualisieren der Paketlisten
    log "INFO" "Aktualisiere Paketlisten..."
    apt-get update -y || error_exit "Fehler beim Aktualisieren der Paketlisten."
    
    # Installation der erforderlichen Abhängigkeiten
    log "INFO" "Installiere erforderliche Abhängigkeiten..."
    apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl || error_exit "Fehler bei der Installation von Abhängigkeiten."
    
    # Hinzufügen des Caddy-Repositorys
    log "INFO" "Füge Caddy-Repository hinzu..."
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg || error_exit "Fehler beim Hinzufügen des Caddy-GPG-Schlüssels."
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list || error_exit "Fehler beim Hinzufügen des Caddy-Repositorys."
    
    # Aktualisieren der Paketlisten mit dem neuen Repository
    log "INFO" "Aktualisiere Paketlisten mit neuem Repository..."
    apt-get update -y || error_exit "Fehler beim Aktualisieren der Paketlisten nach Hinzufügen des Repositorys."
    
    # Installation von Caddy
    log "INFO" "Installiere Caddy-Paket..."
    apt-get install -y caddy || error_exit "Fehler bei der Installation von Caddy."
    
    log "INFO" "Caddy erfolgreich auf QS-VPS installiert."
}

# Caddy Verzeichnisstruktur erstellen (QS-spezifisch)
create_directory_structure() {
    log "STEP" "Erstelle QS-spezifische Caddy-Verzeichnisstruktur..."
    
    # Erstelle Hauptverzeichnisse mit QS-Kennzeichnung
    mkdir -p /etc/caddy/sites
    mkdir -p /etc/caddy/snippets
    mkdir -p /etc/caddy/tls/tailscale
    mkdir -p /etc/caddy/tls/local
    mkdir -p /var/log/caddy
    
    # QS-Marker-Datei erstellen
    echo "QS-VPS Quality Server" > /etc/caddy/QS-ENVIRONMENT
    echo "Erstellt: $(date)" >> /etc/caddy/QS-ENVIRONMENT
    
    # Setze Berechtigungen
    chown -R caddy:caddy /etc/caddy
    chown -R caddy:caddy /var/log/caddy
    
    log "INFO" "QS-Verzeichnisstruktur erfolgreich erstellt."
}

# Konfiguration für automatischen Start
configure_autostart() {
    log "STEP" "Konfiguriere automatischen Start..."
    
    # Aktivieren des Caddy-Dienstes beim Systemstart
    systemctl enable caddy || error_exit "Fehler beim Aktivieren des Caddy-Dienstes für den Systemstart."
    
    log "INFO" "Automatischer Start erfolgreich konfiguriert."
}

# Erstellen der Grundkonfiguration (Caddyfile) mit QS-Kennzeichnung
create_base_config() {
    log "STEP" "Erstelle grundlegende QS-Caddyfile-Konfiguration..."
    
    cat > /etc/caddy/Caddyfile << EOF
# QS-VPS Caddy Konfiguration - Quality Server Environment
# Hostname: ${HOSTNAME}
# Erstellt: $(date)

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
    
    log "INFO" "Grundlegende QS-Caddyfile-Konfiguration erstellt."
}

# Sicherheitskonfiguration erstellen
create_security_config() {
    log "STEP" "Erstelle Sicherheitskonfiguration..."
    
    cat > /etc/caddy/snippets/security-headers.caddy << 'EOF'
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
    
    log "INFO" "Sicherheitskonfiguration erfolgreich erstellt."
}

# Verifiziere die Installation
verify_installation() {
    log "STEP" "Verifiziere die Caddy-Installation..."
    
    # Caddy-Version prüfen
    log "INFO" "Caddy-Version:"
    caddy version | tee -a "$QS_LOG_FILE"
    
    # Caddyfile validieren
    log "INFO" "Validiere Caddyfile..."
    if caddy validate --config /etc/caddy/Caddyfile 2>&1 | tee -a "$QS_LOG_FILE"; then
        log "INFO" "Caddyfile ist gültig."
    else
        log "ERROR" "Caddyfile enthält Fehler."
        return 1
    fi
    
    log "INFO" "Verifizierung abgeschlossen."
    return 0
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
    echo ""
    echo "Nächste Schritte:"
    echo "  1. Führe configure-caddy-qs.sh aus (mit QS_TAILSCALE_IP)"
    echo "  2. Teste die Caddy-Konfiguration"
    echo ""
}

# Hauptfunktion
main() {
    log "STEP" "Starte QS-VPS Caddy-Installation..."
    
    # Prüfungen
    check_root
    parse_args "$@"
    check_prerequisites
    
    # Installation, wenn Caddy noch nicht installiert ist
    if [ "$CONFIG_ONLY" != "true" ]; then
        if ! check_caddy; then
            install_caddy
        fi
    else
        log "INFO" "Überspringe Installation, nur Konfiguration wird durchgeführt."
    fi
    
    # Konfigurationen
    create_directory_structure
    configure_autostart
    create_base_config
    create_security_config
    
    # Verifizieren und abschließen
    verify_installation
    show_info
    
    log "INFO" "QS-VPS: Caddy-Installation erfolgreich abgeschlossen."
}

# Skript ausführen
main "$@"
