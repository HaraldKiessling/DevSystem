#!/bin/bash
#
# DevSystem Code-Server Test-Umgebung Setup
# Dieses Skript richtet die Testumgebung für Code-Server E2E-Tests ein
#
# Version: 1.0
# Autor: DevSystem Team
# Datum: 2026-04-11
#

# Fehler bei der Ausführung beenden das Skript
set -e

# Konfigurationsoptionen
VERBOSE=false
INSTALL_DEPENDENCIES=true
CONFIGURE_TEST_USER=true
TEST_RESULTS_DIR="/tmp/code-server-test-results"
CODE_SERVER_USER="codeserver"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Farbdefinitionen für Terminal-Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================================================
# LOGGING-FUNKTIONEN
# ============================================================================

# Log-Funktion
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
    esac
    
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message${NC}"
}

# ============================================================================
# INITIALISIERUNG
# ============================================================================

# Funktion zum Parsen der Kommandozeilenargumente
parse_args() {
    for arg in "$@"; do
        case $arg in
            --verbose)
                VERBOSE=true
                ;;
            --no-deps)
                INSTALL_DEPENDENCIES=false
                ;;
            --no-user)
                CONFIGURE_TEST_USER=false
                ;;
            --help)
                echo "Verwendung: sudo $0 [--verbose] [--no-deps] [--no-user]"
                echo ""
                echo "Optionen:"
                echo "  --verbose     Ausführliche Ausgabe aktivieren"
                echo "  --no-deps     Keine Abhängigkeiten installieren"
                echo "  --no-user     Keinen Testbenutzer konfigurieren"
                echo "  --help        Diese Hilfe anzeigen"
                echo ""
                exit 0
                ;;
        esac
    done
    
    if [ "$VERBOSE" = true ]; then
        log "INFO" "Ausführliche Ausgabe aktiviert."
    fi
}

# Root-Berechtigungen prüfen
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log "ERROR" "Dieses Skript muss als Root ausgeführt werden. Bitte verwenden Sie 'sudo'."
        exit 1
    fi
}

#######################################
# Installiere notwendige Abhängigkeiten
#######################################

install_dependencies() {
    if [ "$INSTALL_DEPENDENCIES" = false ]; then
        log "INFO" "Abhängigkeitsinstallation übersprungen."
        return 0
    fi
    
    log "STEP" "Installiere notwendige Abhängigkeiten für Tests..."
    
    # Aktualisiere Paketliste
    log "INFO" "Aktualisiere Paketliste..."
    apt-get update
    
    # Installiere erforderliche Pakete
    log "INFO" "Installiere erforderliche Pakete..."
    
    # Grundlegende Werkzeuge für die Tests
    local packages=(
        curl
        wget
        dnsutils
        net-tools
        jq
        bc
        yamllint
        sysstat
    )
    
    for pkg in "${packages[@]}"; do
        if ! dpkg -l | grep -q " $pkg "; then
            log "INFO" "Installiere $pkg..."
            apt-get install -y "$pkg"
        else
            log "INFO" "$pkg ist bereits installiert."
        fi
    done
    
    log "INFO" "Prüfe auf optionale Abhängigkeiten..."
    
    # Optional für erweiterte Tests
    local optional_pkgs=(
        lsof          # für Portprüfungen
        traceroute    # für Netzwerktests
        mtr           # für Netzwerkdiagnostik
        iotop         # für I/O-Überwachung
    )
    
    for pkg in "${optional_pkgs[@]}"; do
        if ! dpkg -l | grep -q " $pkg "; then
            log "INFO" "Installiere optionales Paket $pkg..."
            apt-get install -y "$pkg" || log "WARN" "Konnte $pkg nicht installieren."
        else
            log "INFO" "Optionales Paket $pkg ist bereits installiert."
        fi
    done
    
    return 0
}

#######################################
# Konfiguriere Code-Server-Testbenutzer
#######################################

configure_test_user() {
    if [ "$CONFIGURE_TEST_USER" = false ]; then
        log "INFO" "Benutzerkonfiguration übersprungen."
        return 0
    fi
    
    log "STEP" "Konfiguriere Code-Server-Testbenutzer..."
    
    # Prüfe ob Benutzer existiert
    if id "$CODE_SERVER_USER" &>/dev/null; then
        log "INFO" "Benutzer '$CODE_SERVER_USER' existiert bereits."
    else
        log "WARN" "Benutzer '$CODE_SERVER_USER' existiert nicht. Überspringe Benutzerkonfiguration."
        return 0
    fi
    
    # Erstelle Test-Workspace-Verzeichnis
    local test_workspace="/home/$CODE_SERVER_USER/test-workspace"
    if [ ! -d "$test_workspace" ]; then
        log "INFO" "Erstelle Test-Workspace-Verzeichnis: $test_workspace"
        mkdir -p "$test_workspace"
        chown "$CODE_SERVER_USER:$CODE_SERVER_USER" "$test_workspace"
    else
        log "INFO" "Test-Workspace-Verzeichnis existiert bereits: $test_workspace"
    fi
    
    # Erstelle einfache Testdateien
    log "INFO" "Erstelle Testdateien im Workspace..."
    cat > "$test_workspace/test-file.txt" << EOF
Dies ist eine Testdatei für Code-Server E2E-Tests.
Erstellt am $(date).
EOF
    
    cat > "$test_workspace/test-script.sh" << EOF
#!/bin/bash
# Test-Skript für Code-Server E2E-Tests
echo "Code-Server Test ausgeführt am \$(date)"
echo "Erfolg"
exit 0
EOF
    
    chmod +x "$test_workspace/test-script.sh"
    chown "$CODE_SERVER_USER:$CODE_SERVER_USER" "$test_workspace/test-file.txt"
    chown "$CODE_SERVER_USER:$CODE_SERVER_USER" "$test_workspace/test-script.sh"
    
    # Erstelle HTML-Test für PWA
    local html_test_dir="$test_workspace/pwa-test"
    mkdir -p "$html_test_dir"
    
    cat > "$html_test_dir/index.html" << EOF
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PWA-Test für Code-Server</title>
    <meta name="theme-color" content="#4285f4">
    <meta name="description" content="Test-Webseite für Code-Server PWA-Tests">
    <link rel="manifest" href="manifest.json">
    <style>
        body { font-family: Arial, sans-serif; padding: 20px; }
        .container { max-width: 800px; margin: 0 auto; }
        h1 { color: #4285f4; }
    </style>
</head>
<body>
    <div class="container">
        <h1>PWA-Test für Code-Server</h1>
        <p>Diese Seite dient zum Testen der PWA-Funktionalität von Code-Server.</p>
        <p>Erstellt am: $(date)</p>
        <button id="installApp">Als App installieren</button>
    </div>
    <script>
        // Einfache Service Worker Registrierung
        if ('serviceWorker' in navigator) {
            navigator.serviceWorker.register('sw.js')
                .then(reg => console.log('Service Worker registriert:', reg))
                .catch(err => console.error('Service Worker Fehler:', err));
        }
        
        // Installation als App
        let deferredPrompt;
        window.addEventListener('beforeinstallprompt', (e) => {
            e.preventDefault();
            deferredPrompt = e;
            document.getElementById('installApp').style.display = 'block';
        });
        
        document.getElementById('installApp').addEventListener('click', (e) => {
            if (deferredPrompt) {
                deferredPrompt.prompt();
                deferredPrompt.userChoice.then((choiceResult) => {
                    if (choiceResult.outcome === 'accepted') {
                        console.log('Benutzer hat App installiert');
                    }
                    deferredPrompt = null;
                });
            }
        });
    </script>
</body>
</html>
EOF
    
    # Erstelle Manifest und Service Worker
    cat > "$html_test_dir/manifest.json" << EOF
{
    "name": "Code-Server PWA Test",
    "short_name": "CodeTest",
    "start_url": ".",
    "display": "standalone",
    "background_color": "#ffffff",
    "theme_color": "#4285f4",
    "description": "PWA Test für Code-Server",
    "icons": [
        {
            "src": "icon-192x192.png",
            "sizes": "192x192",
            "type": "image/png"
        },
        {
            "src": "icon-512x512.png",
            "sizes": "512x512",
            "type": "image/png"
        }
    ]
}
EOF
    
    cat > "$html_test_dir/sw.js" << EOF
const CACHE_NAME = 'code-server-pwa-test-v1';
const urlsToCache = [
    './',
    './index.html',
    './manifest.json'
];

// Service Worker Installation
self.addEventListener('install', event => {
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then(cache => {
                return cache.addAll(urlsToCache);
            })
    );
});

// Fetch-Ereignis abfangen
self.addEventListener('fetch', event => {
    event.respondWith(
        caches.match(event.request)
            .then(response => {
                if (response) {
                    return response;
                }
                return fetch(event.request);
            })
    );
});
EOF
    
    # Setze Berechtigungen für PWA-Test-Verzeichnis
    chown -R "$CODE_SERVER_USER:$CODE_SERVER_USER" "$html_test_dir"
    
    log "INFO" "Code-Server-Testbenutzer erfolgreich konfiguriert."
    return 0
}

#######################################
# Bereite Testverzeichnisse vor
#######################################

prepare_test_directories() {
    log "STEP" "Bereite Testverzeichnisse vor..."
    
    # Erstelle Hauptverzeichnis für Testergebnisse
    mkdir -p "$TEST_RESULTS_DIR"
    log "INFO" "Testergebnisse-Verzeichnis erstellt: $TEST_RESULTS_DIR"
    
    # Setze Berechtigungen
    chmod 755 "$TEST_RESULTS_DIR"
    
    # Erstelle spezifische Unterverzeichnisse
    mkdir -p "$TEST_RESULTS_DIR/screenshots"
    mkdir -p "$TEST_RESULTS_DIR/logs"
    mkdir -p "$TEST_RESULTS_DIR/reports"
    
    # Erstelle Datei zum signalisieren fertiger Testumgebung
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    cat > "$TEST_RESULTS_DIR/.environment-ready" << EOF
Test-Umgebung eingerichtet am: $timestamp
Von: $0
EOF
    
    log "INFO" "Testverzeichnisse vorbereitet."
    return 0
}

#######################################
# Konfiguriere Test-Simulationsdaten
#######################################

configure_test_data() {
    log "STEP" "Konfiguriere Test-Simulationsdaten..."
    
    # Erstelle Testdatenverzeichnis
    local test_data_dir="$TEST_RESULTS_DIR/test-data"
    mkdir -p "$test_data_dir"
    
    # Simuliere wichtige Konfigurationsdateien für Tests
    # 1. Beispiel code-server Konfiguration
    cat > "$test_data_dir/sample-config.yaml" << EOF
bind-addr: 127.0.0.1:8080
auth: password
password: abcdef123456
cert: false
user-data-dir: ./data
extensions-dir: ./extensions
EOF
    
    # 2. Beispiel Caddy Konfiguration
    cat > "$test_data_dir/sample-Caddyfile" << EOF
{
    http_port 80
    https_port 9443
}

code.example.com {
    reverse_proxy localhost:8080
}

:9443 {
    reverse_proxy localhost:8080
    tls internal
}
EOF
    
    # 3. Beispiel Tailscale Konfiguration
    cat > "$test_data_dir/sample-tailscale-status.json" << EOF
{
  "Self": {
    "ID": "12345",
    "User": "user@example.com",
    "HostName": "code-server",
    "DNSName": "code-server.example.com",
    "OS": "linux",
    "IPAddresses": ["100.100.100.100"]
  },
  "MagicDNSSuffix": "example.com",
  "TailscaleIPs": ["100.100.100.100"]
}
EOF
    
    log "INFO" "Test-Simulationsdaten konfiguriert."
    return 0
}

#######################################
# Prüfe Test-Skripte auf Ausführbarkeit
#######################################

check_test_scripts() {
    log "STEP" "Prüfe Test-Skripte auf Ausführbarkeit..."
    
    local test_scripts=(
        "$SCRIPTS_DIR/run-code-server-tests.sh"
        "$SCRIPTS_DIR/test-code-server-tailscale.sh"
        "$SCRIPTS_DIR/test-code-server-pwa.sh"
        "$SCRIPTS_DIR/test-code-server-logs.sh"
        "$SCRIPTS_DIR/setup-automated-tests.sh"
    )
    
    for script in "${test_scripts[@]}"; do
        if [ ! -f "$script" ]; then
            log "WARN" "Skript nicht gefunden: $script"
            continue
        fi
        
        if [ ! -x "$script" ]; then
            log "INFO" "Mache Skript ausführbar: $script"
            chmod +x "$script"
        else
            log "INFO" "Skript ist bereits ausführbar: $script"
        fi
    done
    
    log "INFO" "Alle Test-Skripte geprüft und ausführbar gemacht."
    return 0
}

#######################################
# Konfiguriere Netzwerktest-Umgebung
#######################################

configure_network_tests() {
    log "STEP" "Konfiguriere Netzwerktest-Umgebung..."
    
    # Erstelle Beispiel-Antwortdateien für HTTP-Tests
    local network_test_dir="$TEST_RESULTS_DIR/network-tests"
    mkdir -p "$network_test_dir"
    
    # Beispiel HTTP-Antwort Header
    cat > "$network_test_dir/sample-http-headers.txt" << EOF
HTTP/1.1 200 OK
Date: $(date -R)
Server: Caddy
Content-Type: text/html; charset=utf-8
Content-Length: 2854
Connection: keep-alive
X-Frame-Options: SAMEORIGIN
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
Referrer-Policy: no-referrer
Content-Security-Policy: frame-ancestors 'self'
EOF
    
    # Beispiel WebSocket Test Antwort
    cat > "$network_test_dir/sample-websocket-response.txt" << EOF
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: abcdef1234567890abcdef1234567890=
EOF
    
    log "INFO" "Netzwerktest-Umgebung konfiguriert."
    return 0
}

#######################################
# Exportiere Testvariablen
#######################################

export_test_variables() {
    log "STEP" "Exportiere Testvariablen für Tests..."
    
    # Erstelle exports.sh mit Umgebungsvariablen für Tests
    local exports_file="$TEST_RESULTS_DIR/exports.sh"
    
    cat > "$exports_file" << EOF
#!/bin/bash
# Automatisch generierte Testvariablen für Code-Server E2E-Tests
# Erstellt am: $(date)

# Grundlegende Konfiguration
export CODE_SERVER_USER="$CODE_SERVER_USER"
export CODE_SERVER_PORT="8080"
export CODE_SERVER_CONFIG_DIR="/home/$CODE_SERVER_USER/.config/code-server"
export CODE_SERVER_DATA_DIR="/home/$CODE_SERVER_USER/.local/share/code-server"

# Verzeichnisse
export TEST_RESULTS_DIR="$TEST_RESULTS_DIR"
export TEST_LOG_FILE="$TEST_RESULTS_DIR/test-results.log"
export SCRIPTS_DIR="$SCRIPTS_DIR"

# Zeitstempel
export TEST_ENVIRONMENT_TIMESTAMP="$(date +%s)"
export TEST_ENVIRONMENT_DATE="$(date)"

# Test-Features
export TAILSCALE_TESTING="true"
export PWA_TESTING="true"
export LOG_TESTING="true"

# Generiere zufälligen Testnamen
export TEST_RUN_ID="\$(date +%Y%m%d%H%M%S)-\$(head /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)"
EOF
    
    chmod +x "$exports_file"
    log "INFO" "Testvariablen exportiert nach: $exports_file"
    
    return 0
}

#######################################
# Hauptfunktion
#######################################

main() {
    log "SETUP" "==== Starte Einrichtung der Test-Umgebung für Code-Server E2E-Tests ===="
    
    check_root
    parse_args "$@"
    prepare_test_directories
    install_dependencies
    configure_test_user
    configure_test_data
    configure_network_tests
    check_test_scripts
    export_test_variables
    
    log "SETUP" "==== Test-Umgebung für Code-Server E2E-Tests erfolgreich eingerichtet ===="
    
    log "INFO" "Testergebnisse werden in '$TEST_RESULTS_DIR' gespeichert."
    log "INFO" "Test-Umgebung ist bereit für die Ausführung von E2E-Tests."
    
    exit 0
}

main "$@"