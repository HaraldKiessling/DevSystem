#!/bin/bash
#
# Tailscale Installationsskript für DevSystem
# Dieses Skript automatisiert die Installation und Konfiguration von Tailscale
# auf einem Ubuntu VPS für das DevSystem Projekt.
#
# Version: 1.0
# Autor: DevSystem Team
# Datum: $(date +%Y-%m-%d)
#
# Funktionen:
# - Installation von Tailscale
# - Konfiguration für automatischen Start
# - Interaktive Authentifizierung mit Tailscale
# - Grundlegende Sicherheitskonfiguration (Firewall)
#
# Verwendung: sudo bash install-tailscale.sh [--hostname=NAME] [--advertise-routes=CIDR]

# Fehler bei der Ausführung beenden das Skript
set -e

# Farbdefinitionen für Terminal-Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging-Funktion
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
    
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message${NC}"
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
    for arg in "$@"; do
        case $arg in
            --hostname=*)
                HOSTNAME="${arg#*=}"
                ;;
            --advertise-routes=*)
                ADVERTISE_ROUTES="${arg#*=}"
                ;;
            --help)
                echo "Verwendung: sudo bash install-tailscale.sh [--hostname=NAME] [--advertise-routes=CIDR]"
                echo ""
                echo "Optionen:"
                echo "  --hostname=NAME          Spezifiziert den Hostnamen des VPS im Tailscale-Netzwerk"
                echo "  --advertise-routes=CIDR  Aktiviert Subnetz-Routing für das angegebene CIDR-Netzwerk"
                echo ""
                exit 0
                ;;
        esac
    done
    
    # Standardwerte setzen, falls nicht angegeben
    HOSTNAME=${HOSTNAME:-"devsystem-vps"}
}

# Systemvoraussetzungen prüfen
check_prerequisites() {
    log "STEP" "Prüfe Systemvoraussetzungen..."
    
    # Prüfen, ob Ubuntu verwendet wird
    if [ ! -f /etc/lsb-release ] || ! grep -q "Ubuntu" /etc/lsb-release; then
        error_exit "Dieses Skript ist für Ubuntu-Systeme ausgelegt. Ihre Distribution wird nicht unterstützt."
    fi
    
    # Prüfen, ob die erforderlichen Befehle installiert sind
    for cmd in apt-get curl systemctl; do
        if ! command -v $cmd &> /dev/null; then
            error_exit "Der Befehl '$cmd' wird benötigt, ist aber nicht installiert."
        fi
    done
    
    log "INFO" "Systemvoraussetzungen erfüllt."
}

# Prüfen, ob Tailscale bereits installiert ist
check_tailscale() {
    if command -v tailscale &> /dev/null; then
        log "WARN" "Tailscale ist bereits installiert. Überspringe die Installation."
        return 0
    else
        return 1
    fi
}

# Tailscale installieren
install_tailscale() {
    log "STEP" "Installiere Tailscale..."
    
    # Aktualisieren der Paketlisten
    log "INFO" "Aktualisiere Paketlisten..."
    apt-get update -y || error_exit "Fehler beim Aktualisieren der Paketlisten."
    
    # Installation der erforderlichen Abhängigkeiten
    log "INFO" "Installiere erforderliche Abhängigkeiten..."
    apt-get install -y curl apt-transport-https gnupg || error_exit "Fehler bei der Installation von Abhängigkeiten."
    
    # Hinzufügen des Tailscale-Repositorys
    log "INFO" "Füge Tailscale-Repository hinzu..."
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.gpg | apt-key add - || error_exit "Fehler beim Hinzufügen des Tailscale-GPG-Schlüssels."
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.list | tee /etc/apt/sources.list.d/tailscale.list || error_exit "Fehler beim Hinzufügen des Tailscale-Repositorys."
    
    # Aktualisieren der Paketlisten mit dem neuen Repository
    log "INFO" "Aktualisiere Paketlisten mit neuem Repository..."
    apt-get update -y || error_exit "Fehler beim Aktualisieren der Paketlisten nach Hinzufügen des Repositorys."
    
    # Installation von Tailscale
    log "INFO" "Installiere Tailscale-Paket..."
    apt-get install -y tailscale || error_exit "Fehler bei der Installation von Tailscale."
    
    # Starten des Tailscale-Dienstes
    log "INFO" "Starte Tailscale-Dienst..."
    systemctl start tailscaled || error_exit "Fehler beim Starten des Tailscale-Dienstes."
    
    log "INFO" "Tailscale erfolgreich installiert."
}

# Konfiguration für automatischen Start
configure_autostart() {
    log "STEP" "Konfiguriere automatischen Start..."
    
    # Aktivieren des Tailscale-Dienstes beim Systemstart
    systemctl enable tailscaled || error_exit "Fehler beim Aktivieren des Tailscale-Dienstes für den Systemstart."
    
    # Überprüfen des Dienststatus
    if systemctl is-active tailscaled > /dev/null 2>&1; then
        log "INFO" "Tailscale-Dienst läuft."
    else
        log "WARN" "Tailscale-Dienst scheint nicht zu laufen. Versuche neu zu starten..."
        systemctl restart tailscaled
    fi
    
    log "INFO" "Automatischer Start erfolgreich konfiguriert."
}

# Tailscale-Konfigurationsdatei erstellen
create_config_file() {
    log "STEP" "Erstelle Tailscale-Konfigurationsdatei..."
    
    # Verzeichnis erstellen, falls es nicht existiert
    mkdir -p /etc/tailscale
    
    # Konfigurationsdatei erstellen
    cat > /etc/tailscale/tailscaled.defaults << EOF
# Tailscale Defaults für DevSystem
# Automatisch generiert durch install-tailscale.sh
TS_STATE_DIR=/var/lib/tailscale
TS_SOCKET=/var/run/tailscale/tailscaled.sock
TS_PORT=41641
EOF
    
    log "INFO" "Konfigurationsdatei erfolgreich erstellt."
}

# Tailscale-Authentifizierung
authenticate_tailscale() {
    log "STEP" "Starte Tailscale-Authentifizierung..."
    
    # Tailscale-Authentifizierungsoptionen
    TS_OPTS="--hostname=$HOSTNAME"
    
    # Advertise-Routes hinzufügen, wenn angegeben
    if [ -n "$ADVERTISE_ROUTES" ]; then
        TS_OPTS="$TS_OPTS --advertise-routes=$ADVERTISE_ROUTES"
    fi
    
    log "INFO" "Starte Tailscale mit Optionen: $TS_OPTS"
    log "WARN" "Sie werden nun durch den Authentifizierungsprozess geführt. Bitte folgen Sie den Anweisungen auf dem Bildschirm."
    log "WARN" "Ein Authentifizierungslink wird generiert, den Sie in einem Browser öffnen müssen."
    
    echo ""
    echo -e "${YELLOW}========================= TAILSCALE AUTHENTIFIZIERUNG =========================${NC}"
    # Kurze Pause für bessere Lesbarkeit
    sleep 2
    
    # Tailscale initialisieren und Authentifizierung starten
    if ! tailscale up $TS_OPTS; then
        log "ERROR" "Fehler bei der Tailscale-Authentifizierung."
        log "WARN" "Sie können die Authentifizierung später manuell mit 'sudo tailscale up' durchführen."
    else
        log "INFO" "Tailscale-Authentifizierung erfolgreich."
    fi
    
    echo -e "${YELLOW}==========================================================================${NC}"
    echo ""
}

# Firewall-Konfiguration (UFW)
configure_firewall() {
    log "STEP" "Konfiguriere Firewall für Tailscale..."
    
    # Prüfen, ob UFW installiert ist
    if ! command -v ufw &> /dev/null; then
        log "INFO" "UFW (Uncomplicated Firewall) ist nicht installiert. Installiere UFW..."
        apt-get install -y ufw || error_exit "Fehler bei der Installation von UFW."
    fi
    
    log "INFO" "Konfiguriere UFW-Regeln für Tailscale..."
    
    # Prüfen, ob UFW bereits aktiviert ist
    UFW_ENABLED=$(ufw status | grep -c "Status: active" || echo 0)
    
    # Wenn UFW noch nicht aktiviert ist, konfigurieren wir es von Grund auf
    if [ "$UFW_ENABLED" -eq 0 ]; then
        log "INFO" "UFW ist nicht aktiv. Konfiguriere UFW neu..."
        
        # Firewall zurücksetzen und Standardregeln setzen
        ufw --force reset
        ufw default deny incoming
        ufw default allow outgoing
        
        # SSH-Zugriff erlauben (wichtig, um Ausschluss zu vermeiden!)
        ufw allow ssh
        
        # Tailscale UDP-Port für die Verbindung zum Koordinationsserver
        ufw allow 41641/udp
        
        # Tailscale-Schnittstelle erlauben
        ufw allow in on tailscale0
        
        # Spezifische Dienste über Tailscale erlauben (kann angepasst werden)
        ufw allow in on tailscale0 to any port 22 proto tcp
        
        log "WARN" "Aktiviere UFW Firewall. SSH-Zugang bleibt erhalten."
        
        # UFW aktivieren aber sicherstellen, dass SSH nicht geblockt wird
        echo "y" | ufw enable
    else
        log "INFO" "UFW ist bereits aktiv. Füge Tailscale-spezifische Regeln hinzu..."
        
        # Tailscale UDP-Port hinzufügen
        ufw allow 41641/udp
        
        # Tailscale-Schnittstelle erlauben
        ufw allow in on tailscale0
        
        # Spezifische Dienste über Tailscale erlauben
        ufw allow in on tailscale0 to any port 22 proto tcp
        
        # UFW-Regeln neu laden
        ufw reload
    fi
    
    log "INFO" "Firewall-Konfiguration für Tailscale abgeschlossen."
    log "INFO" "UFW-Status:"
    ufw status
}

# Verifiziere die Installation
verify_installation() {
    log "STEP" "Verifiziere die Tailscale-Installation..."
    
    # Prüfen, ob der Tailscale-Dienst läuft
    if ! systemctl is-active --quiet tailscaled; then
        log "WARN" "Tailscale-Dienst läuft nicht. Versuche neu zu starten..."
        systemctl restart tailscaled
        
        if ! systemctl is-active --quiet tailscaled; then
            log "ERROR" "Tailscale-Dienst konnte nicht gestartet werden. Bitte überprüfen Sie das System-Log mit 'journalctl -u tailscaled'."
        fi
    fi
    
    # Tailscale-Status abrufen
    log "INFO" "Tailscale-Status:"
    tailscale status || log "WARN" "Konnte Tailscale-Status nicht abrufen."
    
    log "INFO" "Verifizierung abgeschlossen."
}

# Zusätzliche hilfreiche Informationen anzeigen
show_info() {
    echo ""
    log "STEP" "Installation abgeschlossen!"
    echo ""
    echo -e "${GREEN}Tailscale wurde erfolgreich installiert und konfiguriert.${NC}"
    echo ""
    echo "Nützliche Befehle:"
    echo "  - Status anzeigen:              tailscale status"
    echo "  - Verbindung testen:            tailscale ping <hostname>"
    echo "  - Verbindung trennen:           sudo tailscale down"
    echo "  - Verbindung wiederherstellen:  sudo tailscale up"
    echo "  - Dienst neustarten:            sudo systemctl restart tailscaled"
    echo "  - Logs anzeigen:                sudo journalctl -u tailscaled -f"
    echo ""
    echo "Weitere Informationen finden Sie in der offiziellen Dokumentation:"
    echo "  https://tailscale.com/kb/"
    echo ""
}

# Hauptfunktion
main() {
    log "STEP" "Starte Tailscale-Installation für DevSystem..."
    
    # Prüfungen
    check_root
    parse_args "$@"
    check_prerequisites
    
    # Installation, wenn Tailscale noch nicht installiert ist
    if ! check_tailscale; then
        install_tailscale
    fi
    
    # Konfigurationen
    configure_autostart
    create_config_file
    configure_firewall
    
    # Authentifizierung durchführen
    authenticate_tailscale
    
    # Verifizieren und abschließen
    verify_installation
    show_info
    
    log "INFO" "Tailscale-Installation und -Konfiguration erfolgreich abgeschlossen."
}

# Skript ausführen
main "$@"