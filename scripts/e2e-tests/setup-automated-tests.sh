#!/bin/bash
#
# setup-automated-tests.sh - Einrichtung der automatisierten Testumgebung
#
# Dieses Skript installiert die notwendigen Abhängigkeiten und richtet 
# die Umgebung für automatisierte E2E-Tests ein.
#
# Version: 1.0
# Autor: DevSystem Team
# Datum: 2026-04-12
#
# Verwendung: bash setup-automated-tests.sh [--non-interactive]
#

# Fehlerbehandlungskonfiguration
set -e                      # Fehler bei der Ausführung beenden das Skript
set -o pipefail             # Fehlererkennung in Pipes
set -u                      # Nicht definierte Variablen verursachen Fehler
trap 'cleanup_on_error $LINENO' ERR # Aufräumen bei Fehler mit Zeilennummer

# Konfigurationsoptionen
INTERACTIVE=true
VERBOSE=true
SCRIPT_NAME=$(basename "${BASH_SOURCE[0]}")
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
LOGS_DIR="/var/log/devsystem-e2e-tests"
TEMP_DIR="/tmp/code-server-e2e-test-setup"
OS_TYPE="unknown"
ARCH_TYPE="unknown"
SHELL_TYPE="unknown"
SUDO_CMD=""

# Farbdefinitionen für Terminal-Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Liste benötigter Abhängigkeiten
REQUIRED_PACKAGES=(
    # Grundlegende Tools
    "curl"
    "jq"
    "net-tools"
    "procps"
    "grep"
    "findutils"
    "coreutils"
    # Für Tailscale-Tests
    "ca-certificates"
    "iproute2"
    # Für PWA-Tests
    "wget"
    "sed"
    # Für Log-Tests
    "gawk"
    "diffutils"
    # Für HTML-Berichte
    "xsltproc"
)

# Liste optionaler Hilfspakete
OPTIONAL_PACKAGES=(
    "yamllint"     # Validierung von YAML-Konfigurationen
    "logrotate"    # Log-Rotation-Tests
    "jq"           # Verbesserte JSON-Verarbeitung
    "htmldoc"      # Erweiterte HTML-Berichterstellung
    "vim"          # Einfache Textbearbeitung für Tests
    "htop"         # Prozessmonitoring während Tests
    "rsync"        # Für Backup-Tests
    "parallel"     # Für parallele Testausführung
)

# Liste der erforderlichen Anwendungen
REQUIRED_APPLICATIONS=(
    "code-server"
    "tailscale"
)

# ============================================================================
# LOGGING-FUNKTIONEN
# ============================================================================

# Log-Funktion mit erweiterten Funktionen
log() {
    local level=$1
    local message=$2
    local color=$NC
    
    case $level in
        "INFO") color=$GREEN ;;
        "WARN") color=$YELLOW ;;
        "ERROR") color=$RED ;;
        "SETUP") color=$BLUE ;;
        "STEP") color=$CYAN ;;
        "DEBUG")
            if [ "$VERBOSE" != "true" ]; then
                return 0  # Skip debug messages unless verbose
            fi
            color=$CYAN
            ;;
    esac
    
    # Stellen Sie sicher, dass Log-Verzeichnis existiert
    if [ ! -f "$TEMP_DIR/setup.log" ]; then
        mkdir -p "$TEMP_DIR" 2>/dev/null || true
        touch "$TEMP_DIR/setup.log" 2>/dev/null || true
    fi
    
    # Formatierter Zeitstempel mit Millisekundengenauigkeit (falls möglich)
    local timestamp
    if command -v perl &>/dev/null; then
        timestamp=$(perl -MTime::HiRes=time -e 'printf "%s.%03d", (localtime)[0..5], (time - int(time))*1000')
    else
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    fi
    
    echo -e "${color}[$timestamp] [SETUP] [$level] $message${NC}" | tee -a "$TEMP_DIR/setup.log"
}

# Ausgabe einer Fehlermeldung und Beenden des Skripts
fail() {
    log "ERROR" "$1"
    exit 1
}

# Log-Funktion für detaillierte Debug-Ausgaben
debug() {
    local message=$1
    if [ "$VERBOSE" = true ]; then
        log "DEBUG" "$message"
    fi
}

# ============================================================================
# HILFSFUNKTIONEN
# ============================================================================

# Bereinigung bei Fehlern
cleanup_on_error() {
    local error_code=$?
    local line_number=$1
    
    log "ERROR" "Fehler in Zeile $line_number mit Exit-Code $error_code"
    log "ERROR" "Skript wird abgebrochen und temporäre Dateien werden bereinigt"
    
    # Nur bereinigen, wenn TEMP_DIR existiert
    if [ -d "$TEMP_DIR" ]; then
        log "STEP" "Bereinige temporäre Dateien in $TEMP_DIR"
        rm -rf "$TEMP_DIR" 2>/dev/null || sudo rm -rf "$TEMP_DIR" 2>/dev/null || true
    fi
    
    exit $error_code
}

# Erkennung des Betriebssystems und der Architektur
detect_environment() {
    log "STEP" "Erkenne Betriebssystemtyp und Architektur..."
    
    # Erkennung des Betriebssystems
    if [ -f /etc/os-release ]; then
        # Standard Linux-Erkennung über os-release
        OS_TYPE=$(. /etc/os-release && echo "$ID")
        OS_VERSION=$(. /etc/os-release && echo "$VERSION_ID")
        OS_LIKE=$(. /etc/os-release && echo "$ID_LIKE")
        OS_FAMILY="linux"
        log "INFO" "Betriebssystem erkannt: $OS_TYPE $OS_VERSION"
        
    elif [ -f /etc/redhat-release ]; then
        # Ältere Red Hat basierte Systeme
        OS_TYPE="rhel"
        OS_FAMILY="linux"
        OS_LIKE="fedora rhel"
        OS_VERSION=$(cat /etc/redhat-release | sed 's/.*release \([0-9]\).*/\1/')
        log "INFO" "Red Hat basiertes System erkannt: $OS_TYPE $OS_VERSION"
        
    elif command -v sw_vers &>/dev/null; then
        # macOS
        OS_TYPE="macos"
        OS_FAMILY="darwin"
        OS_VERSION=$(sw_vers -productVersion)
        log "INFO" "macOS erkannt: Version $OS_VERSION"
        
    elif command -v uname &>/dev/null && [ "$(uname -s)" = "FreeBSD" ]; then
        # FreeBSD
        OS_TYPE="freebsd"
        OS_FAMILY="bsd"
        OS_VERSION=$(uname -r)
        log "INFO" "FreeBSD erkannt: Version $OS_VERSION"
        
    elif [ -n "$WINDIR" ] || [ -n "$windir" ] || [ -n "$SYSTEMDRIVE" ]; then
        # Windows-Erkennung (WSL oder Cygwin oder MSYS2)
        if [ -n "$WSL_DISTRO_NAME" ]; then
            OS_TYPE="wsl-$WSL_DISTRO_NAME"
            OS_FAMILY="linux"
            log "INFO" "Windows Subsystem for Linux erkannt: $WSL_DISTRO_NAME"
        elif command -v cygcheck &>/dev/null; then
            OS_TYPE="cygwin"
            OS_FAMILY="windows"
            log "INFO" "Cygwin unter Windows erkannt"
        elif [ -n "$MSYSTEM" ]; then
            OS_TYPE="msys2-$MSYSTEM"
            OS_FAMILY="windows"
            log "INFO" "MSYS2 unter Windows erkannt: $MSYSTEM"
        else
            OS_TYPE="windows"
            OS_FAMILY="windows"
            log "INFO" "Windows-Umgebung erkannt"
        fi
    else
        # Fallback zur grundlegenden Erkennung
        if command -v uname &>/dev/null; then
            OS_TYPE=$(uname -s | tr '[:upper:]' '[:lower:]')
            OS_FAMILY=$OS_TYPE
            log "INFO" "Betriebssystem durch uname erkannt: $OS_TYPE"
        else
            OS_TYPE="unknown"
            OS_FAMILY="unknown"
            log "WARN" "Betriebssystem konnte nicht erkannt werden"
        fi
    fi
    
    # Erkennung der Architektur
    if command -v uname &>/dev/null; then
        ARCH_TYPE=$(uname -m)
        log "INFO" "Architektur erkannt: $ARCH_TYPE"
    else
        ARCH_TYPE="unknown"
        log "WARN" "Konnte Architekturtyp nicht erkennen"
    fi
    
    # Erkennung der verwendeten Shell
    if [ -n "$BASH_VERSION" ]; then
        SHELL_TYPE="bash"
        log "INFO" "Shell erkannt: Bash $BASH_VERSION"
    elif [ -n "$ZSH_VERSION" ]; then
        SHELL_TYPE="zsh"
        log "INFO" "Shell erkannt: ZSH $ZSH_VERSION"
    elif [ -n "$FISH_VERSION" ]; then
        SHELL_TYPE="fish"
        log "INFO" "Shell erkannt: Fish $FISH_VERSION"
    elif command -v ps &>/dev/null; then
        # Versuche Shell aus Prozessliste zu erkennen
        local shell_name
        shell_name=$(ps -p $$ -o comm= 2>/dev/null || true)
        if [ -n "$shell_name" ]; then
            SHELL_TYPE=$(basename "$shell_name")
            log "INFO" "Shell aus Prozessinfo erkannt: $SHELL_TYPE"
        else
            SHELL_TYPE="unknown"
            log "WARN" "Shell konnte nicht erkannt werden"
        fi
    else
        SHELL_TYPE="unknown"
        log "WARN" "Shell konnte nicht erkannt werden"
    fi
    
    # Sudo-Kommando bestimmen
    if command -v sudo &>/dev/null && [ "$(id -u)" -ne 0 ]; then
        SUDO_CMD="sudo"
        log "INFO" "Sudo wird für privilegierte Operationen verwendet"
    else
        SUDO_CMD=""
        if [ "$(id -u)" -eq 0 ]; then
            log "INFO" "Ausführung als Root, kein Sudo erforderlich"
        else
            log "WARN" "Sudo nicht verfügbar. Privilegierte Operationen könnten fehlschlagen."
        fi
    fi
    
    # Überprüfung der Kompatibilität
    check_compatibility
}

# Überprüfung der Systemkompatibilität
check_compatibility() {
    local compatible=true
    
    # Überprüfung, ob das OS unterstützt wird
    case "$OS_FAMILY" in
        linux)
            log "INFO" "Linux-Umgebung wird unterstützt"
            ;;
        darwin)
            log "WARN" "macOS wird nur eingeschränkt unterstützt. Einige Funktionen könnten nicht funktionieren."
            ;;
        windows)
            log "WARN" "Windows (Cygwin/MSYS2) wird nur eingeschränkt unterstützt. Mit Problemen ist zu rechnen."
            ;;
        bsd)
            log "WARN" "BSD-Systeme werden nur eingeschränkt unterstützt."
            ;;
        *)
            log "WARN" "Unbekanntes Betriebssystem. Tests sind möglicherweise nicht funktional."
            compatible=false
            ;;
    esac
    
    # Überprüfung der Bash-Version (wenn Bash verwendet wird)
    if [ "$SHELL_TYPE" = "bash" ]; then
        local bash_major_version="${BASH_VERSION%%.*}"
        if [ "$bash_major_version" -lt 4 ]; then
            log "WARN" "Bash-Version ist älter als 4.0 (erkannt: $BASH_VERSION). Einige Features könnten nicht funktionieren."
            log "WARN" "Empfohlen ist Bash 4.0 oder höher."
            
            if [ "$OS_TYPE" = "macos" ]; then
                log "INFO" "Unter macOS kann eine neuere Bash-Version installiert werden mit: 'brew install bash'"
            fi
        else
            log "INFO" "Bash-Version ist kompatibel: $BASH_VERSION"
        fi
    fi
    
    # Überprüfung auf GNU Tools
    if [ "$OS_FAMILY" = "darwin" ] || [ "$OS_FAMILY" = "bsd" ]; then
        log "INFO" "Überprüfe auf GNU-kompatible Tools..."
        
        for cmd in date sed awk grep; do
            if ! command -v "g$cmd" &>/dev/null; then
                log "WARN" "GNU-$cmd nicht gefunden. Standardversion könnte inkompatibel sein."
                if [ "$OS_TYPE" = "macos" ]; then
                    log "INFO" "Unter macOS können GNU-Tools installiert werden mit: 'brew install coreutils gnu-sed gawk grep'"
                fi
            else
                log "INFO" "GNU-$cmd gefunden: $(command -v "g$cmd")"
            fi
        done
    fi
    
    # Überprüfung von Systemressourcen
    if command -v free &>/dev/null; then
        local mem_info
        mem_info=$(free -m | grep Mem)
        local total_mem
        total_mem=$(echo $mem_info | awk '{print $2}')
        
        if [ "$total_mem" -lt 512 ]; then
            log "WARN" "Geringer Arbeitsspeicher erkannt: ${total_mem}MB. Mindestens 512MB empfohlen."
            compatible=false
        else
            log "INFO" "Arbeitsspeicher ausreichend: ${total_mem}MB"
        fi
    fi
    
    # Überprüfung des verfügbaren Speicherplatzes
    if command -v df &>/dev/null; then
        local space
        space=$(df -m /tmp | tail -1 | awk '{print $4}')
        
        if [ "$space" -lt 200 ]; then
            log "WARN" "Wenig freier Speicherplatz in /tmp: ${space}MB. Mindestens 200MB empfohlen."
            compatible=false
        else
            log "INFO" "Ausreichend freier Speicherplatz: ${space}MB in /tmp"
        fi
    fi
    
    if [ "$compatible" = false ] && [ "$INTERACTIVE" = true ]; then
        log "WARN" "Systemkompatibilitätsprobleme wurden erkannt. Die Tests könnten fehlschlagen."
        read -p "Trotzdem fortfahren? (j/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Jj]$ ]]; then
            log "INFO" "Installation abgebrochen."
            exit 1
        fi
    elif [ "$compatible" = false ]; then
        log "WARN" "Systemkompatibilitätsprobleme wurden erkannt. Führe Installation mit begrenzter Funktionalität durch."
    fi
}

# Initialisierung
init_setup() {
    # Erstelle temporäres Verzeichnis
    mkdir -p "$TEMP_DIR"
    > "$TEMP_DIR/setup.log"
    
    log "SETUP" "Starte Einrichtung der automatisierten Testumgebung..."
    log "INFO" "Skriptversion: 1.1 (2026-04-12)"
    log "INFO" "Ausgeführt als: $(whoami)@$(hostname)"
    
    # Erkennung der Systemumgebung
    detect_environment
    
    # Überprüfe Root-Rechte
    if [ "$(id -u)" -ne 0 ] && [ -z "$SUDO_CMD" ]; then
        log "WARN" "Dieses Skript sollte idealerweise als Root ausgeführt werden oder sudo verfügbar sein."
        log "WARN" "Einige Installationsschritte könnten fehlschlagen."
        
        if [ "$INTERACTIVE" = true ]; then
            read -p "Möchten Sie trotzdem fortfahren? (j/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Jj]$ ]]; then
                log "INFO" "Installation abgebrochen."
                exit 1
            fi
        fi
    fi
    
    # Erstelle Log-Verzeichnis mit erweiterten Fallbacks
    if [ ! -d "$LOGS_DIR" ]; then
        log "STEP" "Erstelle Log-Verzeichnis: $LOGS_DIR"
        
        if ! mkdir -p "$LOGS_DIR" 2>/dev/null; then
            if [ -n "$SUDO_CMD" ]; then
                log "INFO" "Versuche Log-Verzeichnis mit Sudo zu erstellen..."
                $SUDO_CMD mkdir -p "$LOGS_DIR" 2>/dev/null || {
                    log "WARN" "Konnte Log-Verzeichnis nicht erstellen: $LOGS_DIR"
                    # Versuche alternative Verzeichnisse
                    for alt_dir in "/var/tmp/devsystem-logs" "$HOME/.devsystem-logs" "$TEMP_DIR"; do
                        log "INFO" "Versuche alternatives Log-Verzeichnis: $alt_dir"
                        if mkdir -p "$alt_dir" 2>/dev/null; then
                            log "INFO" "Alternatives Log-Verzeichnis erstellt: $alt_dir"
                            LOGS_DIR="$alt_dir"
                            break
                        fi
                    done
                    
                    if [ "$LOGS_DIR" = "/var/log/devsystem-e2e-tests" ]; then
                        log "INFO" "Verwende Fallback-Verzeichnis: $TEMP_DIR"
                        LOGS_DIR="$TEMP_DIR"
                    fi
                }
            else
                log "WARN" "Konnte Log-Verzeichnis nicht erstellen: $LOGS_DIR"
                log "INFO" "Verwende Fallback-Verzeichnis: $TEMP_DIR"
                LOGS_DIR="$TEMP_DIR"
            fi
        fi
    fi
    
    # Setze Berechtigungen für Log-Verzeichnis
    if [ -d "$LOGS_DIR" ]; then
        log "STEP" "Setze Berechtigungen für Log-Verzeichnis..."
        chmod 755 "$LOGS_DIR" 2>/dev/null || $SUDO_CMD chmod 755 "$LOGS_DIR" 2>/dev/null || {
            log "WARN" "Konnte Berechtigungen nicht setzen für: $LOGS_DIR"
            log "WARN" "Log-Rotation könnte eingeschränkt sein."
        }
    fi
    
    # Erstelle Unterverzeichnisse für bessere Organisation
    for subdir in "reports" "snapshots" "metrics"; do
        local full_dir="$LOGS_DIR/$subdir"
        if [ ! -d "$full_dir" ]; then
            mkdir -p "$full_dir" 2>/dev/null || $SUDO_CMD mkdir -p "$full_dir" 2>/dev/null || {
                log "WARN" "Konnte Unterverzeichnis nicht erstellen: $full_dir"
            }
        fi
    done
    
    log "INFO" "Setup-Umgebung initialisiert. Log-Verzeichnis: $LOGS_DIR"
    log "INFO" "Temporäres Verzeichnis: $TEMP_DIR"
    
    # Kopiere eine README-Datei ins Log-Verzeichnis
    cat <<EOF > "$TEMP_DIR/LOGS-README.txt"
DevSystem E2E-Test-Logs
=======================

Dieses Verzeichnis enthält Logs der automatisierten E2E-Tests für den DevSystem.

Struktur:
- automated-e2e-tests.log: Hauptlog der automatisierten Tests
- setup.log: Log der Setup-Prozedur
- reports/: HTML-Testberichte
- snapshots/: Screenshots und Zustandssnapshots
- metrics/: Leistungsmetriken

Diese Logs werden täglich rotiert und für 7 Tage aufbewahrt.

Erstellt: $(date)
EOF
    
    cp "$TEMP_DIR/LOGS-README.txt" "$LOGS_DIR/README.txt" 2>/dev/null || $SUDO_CMD cp "$TEMP_DIR/LOGS-README.txt" "$LOGS_DIR/README.txt" 2>/dev/null || true
}

# Funktion zum Parsen der Kommandozeilenargumente
parse_args() {
    for arg in "$@"; do
        case $arg in
            --non-interactive)
                INTERACTIVE=false
                ;;
            --help)
                echo "Verwendung: bash setup-automated-tests.sh [--non-interactive]"
                echo ""
                echo "Optionen:"
                echo "  --non-interactive      Interaktive Rückfragen deaktivieren"
                echo "  --help                 Diese Hilfe anzeigen"
                echo ""
                exit 0
                ;;
        esac
    done
}

# Funktion zur Erkennung des Paketmanagers
detect_package_manager() {
    log "STEP" "Erkenne Paketmanager..."
    
    if command -v apt &> /dev/null; then
        PM="apt"
        PM_INSTALL="apt install -y"
        PM_UPDATE="apt update"
        log "INFO" "Paketmanager erkannt: apt (Debian/Ubuntu)"
        return 0
    elif command -v dnf &> /dev/null; then
        PM="dnf"
        PM_INSTALL="dnf install -y"
        PM_UPDATE="dnf check-update"
        log "INFO" "Paketmanager erkannt: dnf (Fedora/RHEL/CentOS)"
        return 0
    elif command -v yum &> /dev/null; then
        PM="yum"
        PM_INSTALL="yum install -y"
        PM_UPDATE="yum check-update"
        log "INFO" "Paketmanager erkannt: yum (RHEL/CentOS)"
        return 0
    elif command -v zypper &> /dev/null; then
        PM="zypper"
        PM_INSTALL="zypper install -y"
        PM_UPDATE="zypper refresh"
        log "INFO" "Paketmanager erkannt: zypper (openSUSE)"
        return 0
    elif command -v pacman &> /dev/null; then
        PM="pacman"
        PM_INSTALL="pacman -S --noconfirm"
        PM_UPDATE="pacman -Sy"
        log "INFO" "Paketmanager erkannt: pacman (Arch Linux)"
        return 0
    else
        log "WARN" "Konnte keinen unterstützten Paketmanager erkennen."
        log "WARN" "Abhängigkeiten müssen manuell installiert werden."
        PM=""
        return 1
    fi
}

# Funktion zum Prüfen von Abhängigkeiten
check_dependencies() {
    log "STEP" "Prüfe benötigte Abhängigkeiten..."
    local missing_deps=()
    local optional_missing=()
    local missing_apps=()
    
    # Prüfe Paketabhängigkeiten
    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        # Extrahiere den Paketnamen ohne Kommentare
        pkg_name=$(echo "$pkg" | awk '{print $1}')
        if [[ -z "$pkg_name" || "$pkg_name" == \#* ]]; then
            continue  # Überspringe Kommentarzeilen oder leere Einträge
        fi
        
        # Prüfe, ob das Paket installiert ist
        if ! command -v "$pkg_name" &> /dev/null; then
            # Für einige Pakete können wir alternative Prüfungen durchführen
            case "$pkg_name" in
                "ca-certificates")
                    # Prüfe, ob das Zertifikatsverzeichnis existiert
                    if [ -d "/etc/ssl/certs" ] || [ -d "/etc/pki/ca-trust/extracted" ]; then
                        log "INFO" "Abhängigkeit vorhanden (Verzeichnis): $pkg_name"
                        continue
                    fi
                    ;;
                "iproute2")
                    # Prüfe auf ip-Befehl
                    if command -v ip &> /dev/null; then
                        log "INFO" "Abhängigkeit vorhanden (ip-Befehl): $pkg_name"
                        continue
                    fi
                    ;;
                *)
                    # Standard-Prüfung fehlgeschlagen
                    ;;
            esac
            
            missing_deps+=("$pkg_name")
            log "WARN" "Benötigte Abhängigkeit fehlt: $pkg_name"
        else
            log "INFO" "Abhängigkeit vorhanden: $pkg_name"
        fi
    done
    
    # Prüfe optionale Pakete
    for pkg in "${OPTIONAL_PACKAGES[@]}"; do
        # Extrahiere den Paketnamen ohne Kommentare
        pkg_name=$(echo "$pkg" | awk '{print $1}')
        if [[ -z "$pkg_name" || "$pkg_name" == \#* ]]; then
            continue  # Überspringe Kommentarzeilen oder leere Einträge
        fi
        
        if ! command -v "$pkg_name" &> /dev/null; then
            optional_missing+=("$pkg_name")
            log "INFO" "Optionale Abhängigkeit fehlt: $pkg_name"
        else
            log "INFO" "Optionale Abhängigkeit vorhanden: $pkg_name"
        fi
    done
    
    # Prüfe erforderliche Anwendungen
    for app in "${REQUIRED_APPLICATIONS[@]}"; do
        if ! command -v "$app" &> /dev/null; then
            missing_apps+=("$app")
            log "WARN" "Erforderliche Anwendung fehlt: $app"
        else
            log "INFO" "Erforderliche Anwendung gefunden: $(which "$app") ($(command -v "$app" | xargs basename 2>/dev/null) --version 2>&1 | head -n 1)"
        fi
    done
    
    # Speichern der fehlenden Abhängigkeiten für spätere Installation
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log "WARN" "Fehlende Abhängigkeiten: ${missing_deps[*]}"
        echo "${missing_deps[*]}" > "$TEMP_DIR/missing_deps.txt"
    else
        log "INFO" "Alle benötigten Abhängigkeiten sind bereits installiert."
    fi
    
    if [ ${#optional_missing[@]} -gt 0 ]; then
        log "INFO" "Fehlende optionale Abhängigkeiten: ${optional_missing[*]}"
        echo "${optional_missing[*]}" > "$TEMP_DIR/missing_optional.txt"
    else
        log "INFO" "Alle optionalen Abhängigkeiten sind bereits installiert."
    fi
    
    if [ ${#missing_apps[@]} -gt 0 ]; then
        log "WARN" "Fehlende Anwendungen: ${missing_apps[*]}"
        echo "${missing_apps[*]}" > "$TEMP_DIR/missing_apps.txt"
    else
        log "INFO" "Alle erforderlichen Anwendungen sind installiert."
    fi
    
    # Rückgabewert: 0 wenn alle erforderlichen Abhängigkeiten vorhanden sind, 1 sonst
    if [ ${#missing_deps[@]} -gt 0 ] || [ ${#missing_apps[@]} -gt 0 ]; then
        return 1
    else
        return 0
    fi
}

# Installiere fehlende Abhängigkeiten
install_dependencies() {
    if [ -z "$PM" ]; then
        log "WARN" "Kein Paketmanager verfügbar. Abhängigkeiten müssen manuell installiert werden."
        if [ "$INTERACTIVE" = true ]; then
            log "WARN" "Benötigte Pakete: ${REQUIRED_PACKAGES[*]}"
            log "INFO" "Optionale Pakete: ${OPTIONAL_PACKAGES[*]}"
            
            # Wenn code-server oder Tailscale fehlen, gib Installationshinweise
            if [ -f "$TEMP_DIR/missing_apps.txt" ]; then
                local missing_apps=$(cat "$TEMP_DIR/missing_apps.txt")
                if [ -n "$missing_apps" ]; then
                    log "WARN" "Erforderliche Anwendungen fehlen: $missing_apps"
                    
                    if [[ "$missing_apps" == *"code-server"* ]]; then
                        log "INFO" "Installation von code-server: https://github.com/coder/code-server#installation"
                    fi
                    
                    if [[ "$missing_apps" == *"tailscale"* ]]; then
                        log "INFO" "Installation von Tailscale: https://tailscale.com/download"
                    fi
                fi
            fi
        fi
        return 1
    fi
    
    # Installation fehlender Pakete
    if [ -f "$TEMP_DIR/missing_deps.txt" ]; then
        local missing_deps=$(cat "$TEMP_DIR/missing_deps.txt")
        
        if [ -n "$missing_deps" ]; then
            log "STEP" "Installiere fehlende Abhängigkeiten: $missing_deps"
            
            # Aktualisiere Paketquellen
            log "INFO" "Aktualisiere Paketquellen..."
            eval "sudo $PM_UPDATE" || {
                log "WARN" "Konnte Paketquellen nicht aktualisieren. Versuche Installation trotzdem."
            }
            
            # Installiere Pakete
            log "INFO" "Installiere fehlende Pakete..."
            
            local installation_failures=0
            for pkg in $missing_deps; do
                log "INFO" "Installiere $pkg..."
                if eval "sudo $PM_INSTALL $pkg"; then
                    log "INFO" "Paket $pkg erfolgreich installiert."
                else
                    log "ERROR" "Konnte Paket $pkg nicht installieren."
                    installation_failures=$((installation_failures + 1))
                fi
            done
            
            if [ $installation_failures -gt 0 ]; then
                log "WARN" "$installation_failures Pakete konnten nicht installiert werden."
                log "WARN" "Einige Tests könnten eingeschränkt funktionieren."
            fi
        fi
    fi
    
    # Installation optionaler Pakete
    if [ -f "$TEMP_DIR/missing_optional.txt" ] && [ "$INTERACTIVE" = true ]; then
        local missing_optional=$(cat "$TEMP_DIR/missing_optional.txt")
        
        if [ -n "$missing_optional" ]; then
            log "STEP" "Möchten Sie optionale Abhängigkeiten installieren?"
            log "INFO" "Optionale Pakete erhöhen die Testqualität: $missing_optional"
            
            read -p "Optionale Pakete installieren? (j/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Jj]$ ]]; then
                log "INFO" "Installiere optionale Pakete..."
                
                for pkg in $missing_optional; do
                    log "INFO" "Installiere optionales Paket $pkg..."
                    if eval "sudo $PM_INSTALL $pkg"; then
                        log "INFO" "Optionales Paket $pkg erfolgreich installiert."
                    else
                        log "WARN" "Konnte optionales Paket $pkg nicht installieren."
                    fi
                done
            else
                log "INFO" "Überspringe optionale Pakete."
            fi
        fi
    fi
    
    # Prüfe, ob erforderliche Anwendungen installiert sind
    if [ -f "$TEMP_DIR/missing_apps.txt" ]; then
        local missing_apps=$(cat "$TEMP_DIR/missing_apps.txt")
        
        if [ -n "$missing_apps" ]; then
            log "STEP" "Erforderliche Anwendungen fehlen: $missing_apps"
            
            if [ "$INTERACTIVE" = true ]; then
                log "WARN" "Ohne diese Anwendungen werden einige Tests fehlschlagen."
                
                read -p "Möchten Sie Installationsanweisungen für die fehlenden Anwendungen sehen? (j/n): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Jj]$ ]]; then
                    if [[ "$missing_apps" == *"code-server"* ]]; then
                        log "INFO" "Installation von code-server:"
                        log "INFO" "1. Besuchen Sie https://github.com/coder/code-server#installation"
                        log "INFO" "2. Folgen Sie den Anweisungen für Ihr Betriebssystem"
                        log "INFO" "3. Alternativ: curl -fsSL https://code-server.dev/install.sh | sh"
                    fi
                    
                    if [[ "$missing_apps" == *"tailscale"* ]]; then
                        log "INFO" "Installation von Tailscale:"
                        log "INFO" "1. Besuchen Sie https://tailscale.com/download"
                        log "INFO" "2. Folgen Sie den Anweisungen für Ihr Betriebssystem"
                        log "INFO" "3. Alternativ für Linux: curl -fsSL https://tailscale.com/install.sh | sh"
                    fi
                    
                    # Frage, ob automatisch installiert werden soll
                    log "STEP" "Möchten Sie versuchen, diese Anwendungen automatisch zu installieren?"
                    read -p "Automatische Installation versuchen? (j/n): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Jj]$ ]]; then
                        # Versuche, die Anwendungen zu installieren
                        if [[ "$missing_apps" == *"code-server"* ]]; then
                            log "INFO" "Versuche code-server zu installieren..."
                            if curl -fsSL https://code-server.dev/install.sh | sudo sh; then
                                log "INFO" "code-server erfolgreich installiert."
                            else
                                log "ERROR" "Automatische Installation von code-server fehlgeschlagen."
                            fi
                        fi
                        
                        if [[ "$missing_apps" == *"tailscale"* ]]; then
                            log "INFO" "Versuche Tailscale zu installieren..."
                            if curl -fsSL https://tailscale.com/install.sh | sudo sh; then
                                log "INFO" "Tailscale erfolgreich installiert."
                            else
                                log "ERROR" "Automatische Installation von Tailscale fehlgeschlagen."
                            fi
                        fi
                    else
                        log "INFO" "Überspringe automatische Installation."
                    fi
                fi
            fi
        fi
    fi
    
    # Prüfe erneut, ob alle Abhängigkeiten installiert wurden
    log "STEP" "Prüfe erneut auf Abhängigkeiten nach der Installation..."
    if check_dependencies; then
        log "INFO" "Alle erforderlichen Abhängigkeiten wurden erfolgreich installiert."
        return 0
    else
        log "WARN" "Einige Abhängigkeiten konnten nicht installiert werden."
        log "WARN" "Tests werden möglicherweise mit eingeschränkter Funktionalität ausgeführt."
        return 1
    fi
}

# Konfiguriere automatischen Testlauf
configure_automated_tests() {
    log "STEP" "Konfiguriere automatisierten Testlauf..."
    
    # Erstelle systemd-Service für automatische Tests (falls root)
    if [ "$(id -u)" -eq 0 ] || [ "$SUDO_USER" != "" ]; then
        if command -v systemctl &> /dev/null; then
            log "STEP" "Erstelle systemd-Service für automatisierte Tests..."
            
            local service_file="/etc/systemd/system/code-server-e2e-tests.service"
            local timer_file="/etc/systemd/system/code-server-e2e-tests.timer"
            
            # Erstelle Service-Datei
            cat <<EOF > "$TEMP_DIR/code-server-e2e-tests.service"
[Unit]
Description=Code-Server E2E Tests
After=network.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_DIR/run-code-server-tests.sh --non-interactive
User=root
StandardOutput=append:$LOGS_DIR/automated-e2e-tests.log
StandardError=append:$LOGS_DIR/automated-e2e-tests.log

[Install]
WantedBy=multi-user.target
EOF
            
            # Erstelle Timer-Datei
            cat <<EOF > "$TEMP_DIR/code-server-e2e-tests.timer"
[Unit]
Description=Run Code-Server E2E Tests regularly
Requires=code-server-e2e-tests.service

[Timer]
Unit=code-server-e2e-tests.service
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF
            
            # Installiere Service und Timer
            if [ "$INTERACTIVE" = true ]; then
                log "INFO" "Möchten Sie den systemd-Service für automatische Tests installieren?"
                log "INFO" "Dies wird tägliche automatische Tests einrichten."
                
                read -p "Systemd-Service installieren? (j/n): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Jj]$ ]]; then
                    log "INFO" "Installiere systemd-Service..."
                else
                    log "INFO" "Überspringe systemd-Service-Installation."
                    return 0
                fi
            fi
            
            sudo cp "$TEMP_DIR/code-server-e2e-tests.service" "$service_file" || {
                log "ERROR" "Konnte Service-Datei nicht installieren."
                return 1
            }
            
            sudo cp "$TEMP_DIR/code-server-e2e-tests.timer" "$timer_file" || {
                log "ERROR" "Konnte Timer-Datei nicht installieren."
                return 1
            }
            
            log "INFO" "Aktiviere und starte Timer..."
            sudo systemctl daemon-reload
            sudo systemctl enable code-server-e2e-tests.timer
            sudo systemctl start code-server-e2e-tests.timer
            
            log "INFO" "Status des Timers:"
            sudo systemctl status code-server-e2e-tests.timer --no-pager -l || true
            
            log "INFO" "Automatisierte Tests wurden erfolgreich konfiguriert."
        else
            log "WARN" "systemd ist nicht verfügbar. Automatischer Testlauf muss manuell oder via cron eingerichtet werden."
            
            # Erstelle cron-Job als Alternative
            if command -v crontab &> /dev/null; then
                log "STEP" "Erstelle cron-Job für automatisierte Tests..."
                
                if [ "$INTERACTIVE" = true ]; then
                    log "INFO" "Möchten Sie einen cron-Job für tägliche Tests einrichten?"
                    
                    read -p "Cron-Job erstellen? (j/n): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Jj]$ ]]; then
                        log "INFO" "Erstelle cron-Job..."
                    else
                        log "INFO" "Überspringe cron-Job-Erstellung."
                        return 0
                    fi
                fi
                
                # Erstelle temporäre crontab-Datei
                crontab -l > "$TEMP_DIR/current_crontab" 2>/dev/null || echo "" > "$TEMP_DIR/current_crontab"
                
                # Füge cron-Job hinzu, wenn er noch nicht existiert
                if ! grep -q "run-code-server-tests.sh" "$TEMP_DIR/current_crontab"; then
                    echo "0 2 * * * $SCRIPT_DIR/run-code-server-tests.sh --non-interactive >> $LOGS_DIR/automated-e2e-tests.log 2>&1" >> "$TEMP_DIR/current_crontab"
                    crontab "$TEMP_DIR/current_crontab"
                    log "INFO" "Cron-Job für tägliche Tests um 2:00 Uhr wurde erstellt."
                else
                    log "INFO" "Cron-Job existiert bereits."
                fi
            else
                log "WARN" "Weder systemd noch cron sind verfügbar. Automatisierte Tests müssen manuell ausgeführt werden."
            fi
        fi
    else
        log "WARN" "Root-Rechte erforderlich, um automatische Tests via systemd oder cron einzurichten."
        log "INFO" "Bitte führen Sie dieses Skript als Root aus, um automatische Tests einzurichten."
    fi
}

# Erstelle Benutzerfreundliches Testskript
create_user_script() {
    log "STEP" "Erstelle benutzerfreundliches Testskript..."
    
    local user_script="$SCRIPT_DIR/run-tests.sh"
    
    cat <<EOF > "$user_script"
#!/bin/bash
#
# run-tests.sh - Benutzerfreundliches Skript zum Ausführen der E2E-Tests
#
# Dieses Skript bietet eine interaktive Oberfläche für die Ausführung
# verschiedener E2E-Tests für code-server.
#
# Version: 1.1 (erweitert für Testumgebungsintegration)
# Autor: DevSystem Team
# Datum: 2026-04-12
#

SCRIPT_DIR="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"
VERBOSE=true
SETUP_ENV=false
HTML_REPORT=false
PARALLEL_TESTS=false
NO_CLEANUP=false

# Farben für die Ausgabe
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funktionen
show_banner() {
    echo -e "\${BLUE}========================================\${NC}"
    echo -e "\${BLUE}===   Code-Server E2E-Test-Utility   ===\${NC}"
    echo -e "\${BLUE}========================================\${NC}"
    echo
}

setup_test_environment() {
    local setup_script="\$SCRIPT_DIR/setup-test-environment.sh"
    
    if [ ! -f "\$setup_script" ]; then
        echo -e "\${RED}Fehler: Test-Environment-Setup-Skript nicht gefunden: \$setup_script\${NC}"
        return 1
    fi
    
    local setup_args=""
    [ "\$VERBOSE" = true ] && setup_args="\$setup_args --verbose"
    [ "\$NO_CLEANUP" = true ] && setup_args="\$setup_args --no-cleanup"
    
    echo -e "\${YELLOW}Bereite Testumgebung vor...\${NC}"
    
    if ! "\$setup_script" \$setup_args; then
        echo -e "\${RED}Fehler bei der Einrichtung der Testumgebung!\${NC}"
        echo -e "\${YELLOW}Einige Tests könnten fehlschlagen.\${NC}"
        return 1
    fi
    
    echo -e "\${GREEN}Testumgebung erfolgreich eingerichtet.\${NC}"
    return 0
}

run_test() {
    local test_name=\$1
    local extra_args=\$2
    
    local run_args="--verbose"
    [ "\$HTML_REPORT" = true ] && run_args="\$run_args --html-report"
    [ "\$PARALLEL_TESTS" = true ] && run_args="\$run_args --parallel"
    
    if [ -n "\$test_name" ] && [ "\$test_name" != "all" ]; then
        run_args="\$run_args --test=\$test_name"
    fi
    
    if [ -n "\$extra_args" ]; then
        run_args="\$run_args \$extra_args"
    fi
    
    echo -e "\${YELLOW}Starte Tests mit Optionen: \$run_args\${NC}"
    
    if "\$SCRIPT_DIR/run-code-server-tests.sh" \$run_args; then
        echo -e "\${GREEN}Tests erfolgreich abgeschlossen!\${NC}"
        return 0
    else
        echo -e "\${RED}Tests fehlgeschlagen. Siehe Log für Details.\${NC}"
        return 1
    fi
}

show_main_menu() {
    echo -e "\${BLUE}Wählen Sie die auszuführenden Tests:\${NC}"
    echo -e "  \${GREEN}1) Alle Tests\${NC}"
    echo -e "  \${GREEN}2) Nur Tailscale-Tests\${NC}"
    echo -e "  \${GREEN}3) Nur PWA-Tests\${NC}"
    echo -e "  \${GREEN}4) Nur Log-Tests\${NC}"
    echo
    echo -e "  \${YELLOW}5) Optionen konfigurieren\${NC}"
    echo -e "  \${YELLOW}6) Test-Umgebung einrichten\${NC}"
    echo -e "  \${YELLOW}7) Hilfe und Info\${NC}"
    echo
    echo -e "  \${RED}q) Beenden\${NC}"
    echo
}

show_options_menu() {
    echo -e "\${BLUE}Test-Optionen:\${NC}"
    echo -e "  \${GREEN}1) Ausführliche Ausgabe: [\$VERBOSE]\${NC}"
    echo -e "  \${GREEN}2) HTML-Bericht erstellen: [\$HTML_REPORT]\${NC}"
    echo -e "  \${GREEN}3) Tests parallel ausführen: [\$PARALLEL_TESTS]\${NC}"
    echo -e "  \${GREEN}4) Testumgebung nach Tests behalten: [\$NO_CLEANUP]\${NC}"
    echo
    echo -e "  \${BLUE}r) Zurück zum Hauptmenü\${NC}"
    echo
}

show_help() {
    echo -e "\${YELLOW}=== Hilfe und Informationen ===\${NC}"
    echo
    echo -e "Dieses Tool führt End-to-End-Tests für code-server durch."
    echo -e "Es integriert sich mit dem Testumgebungs-Setup und dem Haupt-Testframework."
    echo
    echo -e "\${BLUE}Verfügbare Tests:\${NC}"
    echo -e "  - \${GREEN}Tailscale-Tests:\${NC} Überprüfung der Tailscale-Integration"
    echo -e "  - \${GREEN}PWA-Tests:\${NC} Überprüfung der Progressive Web App Funktionalität"
    echo -e "  - \${GREEN}Log-Tests:\${NC} Überprüfung des Logging-Systems"
    echo
    echo -e "\${BLUE}Log-Dateien:\${NC}"
    echo -e "  - Hauptlog: /var/log/devsystem-e2e-tests.log"
    echo -e "  - Testergebnisse: /tmp/code-server-e2e-test-results/"
    echo
    echo -e "\${BLUE}Entwickelt von:\${NC} DevSystem Team (GitHub Issue #18)"
    echo
    echo -e "Drücken Sie Enter, um zum Hauptmenü zurückzukehren..."
    read
}

toggle_option() {
    local option_var=\$1
    
    if [ "\${!option_var}" = true ]; then
        eval "\$option_var=false"
    else
        eval "\$option_var=true"
    fi
}

# Hauptprogramm
show_banner

while true; do
    show_main_menu
    read -p "Auswahl: " choice
    echo
    
    case \$choice in
        1)
            echo -e "\${YELLOW}Führe alle Tests aus...\${NC}"
            [ "\$SETUP_ENV" = true ] && setup_test_environment
            run_test "all"
            ;;
        2)
            echo -e "\${YELLOW}Führe nur Tailscale-Tests aus...\${NC}"
            [ "\$SETUP_ENV" = true ] && setup_test_environment
            run_test "tailscale"
            ;;
        3)
            echo -e "\${YELLOW}Führe nur PWA-Tests aus...\${NC}"
            [ "\$SETUP_ENV" = true ] && setup_test_environment
            run_test "pwa"
            ;;
        4)
            echo -e "\${YELLOW}Führe nur Log-Tests aus...\${NC}"
            [ "\$SETUP_ENV" = true ] && setup_test_environment
            run_test "logs"
            ;;
        5)
            while true; do
                show_options_menu
                read -p "Option auswählen: " opt_choice
                echo
                
                case \$opt_choice in
                    1)
                        toggle_option "VERBOSE"
                        echo -e "\${GREEN}Ausführliche Ausgabe: \$VERBOSE\${NC}"
                        ;;
                    2)
                        toggle_option "HTML_REPORT"
                        echo -e "\${GREEN}HTML-Bericht erstellen: \$HTML_REPORT\${NC}"
                        ;;
                    3)
                        toggle_option "PARALLEL_TESTS"
                        echo -e "\${GREEN}Tests parallel ausführen: \$PARALLEL_TESTS\${NC}"
                        ;;
                    4)
                        toggle_option "NO_CLEANUP"
                        echo -e "\${GREEN}Testumgebung nach Tests behalten: \$NO_CLEANUP\${NC}"
                        ;;
                    r|R)
                        break
                        ;;
                    *)
                        echo -e "\${RED}Ungültige Auswahl!\${NC}"
                        ;;
                esac
                
                echo
            done
            ;;
        6)
            echo -e "\${YELLOW}Richte Testumgebung ein...\${NC}"
            SETUP_ENV=true
            setup_test_environment
            echo -e "\${GREEN}Testumgebung ist für die nächsten Tests bereit.\${NC}"
            echo
            ;;
        7)
            show_help
            ;;
        q|Q)
            echo -e "\${BLUE}Programm wird beendet.\${NC}"
            exit 0
            ;;
        *)
            echo -e "\${RED}Ungültige Auswahl. Bitte versuchen Sie es erneut.\${NC}"
            ;;
    esac
    
    echo
done
EOF
    
    chmod +x "$user_script" || {
        log "WARN" "Konnte Ausführrechte für Benutzer-Skript nicht setzen: $user_script"
        sudo chmod +x "$user_script" 2>/dev/null || log "ERROR" "Konnte Benutzer-Skript nicht ausführbar machen."
    }
    
    log "INFO" "Erweitertes benutzerfreundliches Testskript erstellt: $user_script"
    
    # Erstelle auch ein Skript für schnelle automatisierte Tests
    local quick_script="$SCRIPT_DIR/quick-test.sh"
    
    cat <<EOF > "$quick_script"
#!/bin/bash
#
# quick-test.sh - Schnelles Testskript für automatisierte Tests
#
# Dieses Skript führt die grundlegendsten Tests aus, ohne Benutzerinteraktion.
# Perfekt für CI/CD-Pipelines oder schnelle Überprüfungen.
#

SCRIPT_DIR="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"

# Standardmäßig PWA-Tests ausführen, da diese am schnellsten und zuverlässigsten sind
"\$SCRIPT_DIR/run-code-server-tests.sh" --test=pwa --verbose

# Exit-Code des Tests zurückgeben
exit \$?
EOF

    chmod +x "$quick_script" || {
        log "WARN" "Konnte Ausführrechte für Quick-Test-Skript nicht setzen: $quick_script"
        sudo chmod +x "$quick_script" 2>/dev/null || log "ERROR" "Konnte Quick-Test-Skript nicht ausführbar machen."
    }
    
    log "INFO" "Quick-Test-Skript für CI/CD erstellt: $quick_script"
    
    # Erstelle ein README für die Testskripte
    local readme_file="$SCRIPT_DIR/README-TESTS.md"
    
    cat <<EOF > "$readme_file"
# Code-Server E2E-Tests

Dieses Verzeichnis enthält verschiedene Skripte zur Durchführung von End-to-End-Tests für code-server.

## Verfügbare Skripte

- \`run-tests.sh\` - Interaktives Menü für die Ausführung verschiedener Tests
- \`quick-test.sh\` - Schneller Test für CI/CD-Pipelines
- \`run-code-server-tests.sh\` - Haupttestframework mit verschiedenen Optionen
- \`setup-test-environment.sh\` - Einrichtung einer isolierten Testumgebung
- \`setup-automated-tests.sh\` - Konfiguration automatisierter Tests

## Test-Kategorien

- **Tailscale-Tests**: Integration mit Tailscale und Netzwerkfunktionalität
- **PWA-Tests**: Progressive Web App Funktionalität und Offline-Modus
- **Log-Tests**: Logging-System und Log-Rotation

## Schnelle Verwendung

```bash
# Interaktive Testausführung
./run-tests.sh

# Schneller automatischer Test (gut für CI/CD)
./quick-test.sh

# Manuelle Ausführung mit Optionen
./run-code-server-tests.sh --verbose --test=all
```

## Konfiguration

Die Tests verwenden standardmäßig folgende Verzeichnisse:

- **Log-Verzeichnis**: \`/var/log/devsystem-e2e-tests\`
- **Testergebnisse**: \`/tmp/code-server-e2e-test-results\`
- **Testumgebung**: \`/tmp/code-server-test-env\`

## Testautomatisierung

Automatisierte Tests werden je nach Konfiguration über systemd-Timer oder cron-Jobs ausgeführt.
Siehe \`README-AUTOMATED-TESTS.md\` für weitere Details.

---

Erstellt von: DevSystem Team (GitHub Issue #18)
Stand: $(date '+%Y-%m-%d')
EOF

    log "INFO" "README für Testskripte erstellt: $readme_file"
}

# Funktion zum Abschluss des Setups
finalize_setup() {
    log "STEP" "Schließe Setup ab..."
    
    # Setze Ausführrechte für alle Skripte
    log "INFO" "Setze Ausführrechte für alle Testskripte..."
    
    for script in "$SCRIPT_DIR"/*.sh; do
        chmod +x "$script" 2>/dev/null || sudo chmod +x "$script" 2>/dev/null || {
            log "WARN" "Konnte Ausführrechte nicht setzen für: $script"
        }
    done
    
    # Kopiere Setup-Log ins Log-Verzeichnis
    if [ -d "$LOGS_DIR" ]; then
        cp "$TEMP_DIR/setup.log" "$LOGS_DIR/setup.log" 2>/dev/null || sudo cp "$TEMP_DIR/setup.log" "$LOGS_DIR/setup.log" 2>/dev/null || {
            log "WARN" "Konnte Setup-Log nicht ins Log-Verzeichnis kopieren."
        }
    fi
    
    log "INFO" "Setup abgeschlossen."
    log "INFO" "Log-Datei: $TEMP_DIR/setup.log"
    
    if [ -f "$SCRIPT_DIR/run-tests.sh" ]; then
        log "INFO" "Sie können Tests manuell ausführen mit: $SCRIPT_DIR/run-tests.sh"
    else
        log "INFO" "Sie können Tests manuell ausführen mit: $SCRIPT_DIR/run-code-server-tests.sh"
    fi
}

#######################################
# Hauptfunktion
#######################################

main() {
    log "SETUP" "==== Starte Einrichtung der automatisierten E2E-Testumgebung ===="
    
    init_setup
    parse_args "$@"
    
    detect_package_manager
    
    check_dependencies
    install_dependencies
    
    configure_automated_tests
    create_user_script
    
    finalize_setup
    
    log "SETUP" "==== Einrichtung der automatisierten E2E-Testumgebung abgeschlossen ===="
}

main "$@"