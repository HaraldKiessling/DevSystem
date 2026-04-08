#!/bin/bash
#
# DevSystem - E2E Test für code-server
# Autor: DevSystem Team
# Datum: 2026-04-08
#
# Beschreibung: 
# Dieses Skript führt End-to-End-Tests für die code-server-Installation und -Konfiguration durch.
# Es überprüft:
# - Ob code-server installiert ist und läuft
# - Ob code-server auf dem richtigen Port lauscht
# - Ob die Benutzereinstellungen korrekt konfiguriert sind
# - Ob Git konfiguriert ist
# - Ob die VS Code Extensions installiert sind
# - Ob die Integration mit Caddy funktioniert

set -e # Script beenden, wenn ein Befehl fehlschlägt

# Farbige Ausgabe für bessere Lesbarkeit
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Standardwerte für Konfigurationsparameter
CODE_SERVER_USER="coder"
CODE_SERVER_PORT="8080"
CADDY_HTTPS_PORT="9443"
CODE_SERVER_URL="code.devsystem.internal"

# Parameter-Verarbeitung
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --user=*) CODE_SERVER_USER="${1#*=}"; shift ;;
        --port=*) CODE_SERVER_PORT="${1#*=}"; shift ;;
        --caddy-port=*) CADDY_HTTPS_PORT="${1#*=}"; shift ;;
        --url=*) CODE_SERVER_URL="${1#*=}"; shift ;;
        --help) 
            echo "Verwendung: $0 [Optionen]"
            echo "Optionen:"
            echo "  --user=USER             Benutzername für code-server (Standard: $CODE_SERVER_USER)"
            echo "  --port=PORT             Port für code-server (Standard: $CODE_SERVER_PORT)"
            echo "  --caddy-port=PORT       Port für Caddy HTTPS (Standard: $CADDY_HTTPS_PORT)"
            echo "  --url=URL               code-server URL für Caddy (Standard: $CODE_SERVER_URL)"
            exit 0
            ;;
        *) echo -e "${RED}Unbekannter Parameter: $1${NC}"; exit 1 ;;
    esac
done

# Prüfen, ob das Script mit Root-Rechten ausgeführt wird
if [ "$(id -u)" != "0" ]; then
   echo -e "${RED}Dieses Script muss mit Root-Rechten ausgeführt werden.${NC}"
   exit 1
fi

# Funktion zur Überprüfung mit schöner Ausgabe
check() {
    local test_name="$1"
    local test_cmd="$2"
    local test_expect="$3"
    
    echo -e "${BLUE}[TEST]${NC} $test_name..."
    
    # Ausgabe des Befehls in Variable speichern
    local test_result
    test_result=$(eval "$test_cmd" 2>&1) || true
    
    # Prüfen, ob das Ergebnis der Erwartung entspricht
    if [[ $test_result == *"$test_expect"* ]]; then
        echo -e "${GREEN}[ERFOLG]${NC} $test_name"
        return 0
    else
        echo -e "${RED}[FEHLGESCHLAGEN]${NC} $test_name"
        echo -e "${YELLOW}Erwartete Ausgabe: $test_expect${NC}"
        echo -e "${YELLOW}Erhaltene Ausgabe: $test_result${NC}"
        return 1
    fi
}

# Funktion zur Überprüfung, ob eine Datei existiert
check_file_exists() {
    local file_path="$1"
    local file_name="$(basename "$file_path")"
    
    echo -e "${BLUE}[TEST]${NC} Überprüfe, ob $file_name existiert..."
    
    if [[ -f "$file_path" ]]; then
        echo -e "${GREEN}[ERFOLG]${NC} $file_name existiert"
        return 0
    else
        echo -e "${RED}[FEHLGESCHLAGEN]${NC} $file_name existiert nicht"
        return 1
    fi
}

# Funktion zur Überprüfung, ob ein Verzeichnis existiert
check_dir_exists() {
    local dir_path="$1"
    local dir_name="$(basename "$dir_path")"
    
    echo -e "${BLUE}[TEST]${NC} Überprüfe, ob Verzeichnis $dir_name existiert..."
    
    if [[ -d "$dir_path" ]]; then
        echo -e "${GREEN}[ERFOLG]${NC} Verzeichnis $dir_name existiert"
        return 0
    else
        echo -e "${RED}[FEHLGESCHLAGEN]${NC} Verzeichnis $dir_name existiert nicht"
        return 1
    fi
}

# Funktion zur Überprüfung, ob ein Service läuft
check_service_running() {
    local service_name="$1"
    
    echo -e "${BLUE}[TEST]${NC} Überprüfe, ob $service_name läuft..."
    
    if systemctl is-active --quiet "$service_name"; then
        echo -e "${GREEN}[ERFOLG]${NC} $service_name läuft"
        return 0
    else
        echo -e "${RED}[FEHLGESCHLAGEN]${NC} $service_name läuft nicht"
        echo -e "${YELLOW}Details zum Status:${NC}"
        systemctl status "$service_name" --no-pager
        return 1
    fi
}

# Funktion zur Überprüfung von JSON-Dateien
check_json_value() {
    local file_path="$1"
    local json_key="$2"
    local expected_value="$3"
    local file_name="$(basename "$file_path")"
    
    echo -e "${BLUE}[TEST]${NC} Überprüfe $json_key in $file_name..."
    
    if [[ ! -f "$file_path" ]]; then
        echo -e "${RED}[FEHLGESCHLAGEN]${NC} Datei $file_name existiert nicht"
        return 1
    fi
    
    if command -v jq &> /dev/null; then
        # jq ist installiert
        local actual_value=$(jq -r ".$json_key" "$file_path")
        
        if [[ "$actual_value" == *"$expected_value"* ]]; then
            echo -e "${GREEN}[ERFOLG]${NC} $json_key in $file_name ist korrekt"
            return 0
        else
            echo -e "${RED}[FEHLGESCHLAGEN]${NC} $json_key in $file_name ist nicht korrekt"
            echo -e "${YELLOW}Erwarteter Wert: $expected_value${NC}"
            echo -e "${YELLOW}Aktueller Wert: $actual_value${NC}"
            return 1
        fi
    else
        # Fallback wenn jq nicht installiert ist
        if grep -q "\"$json_key\"" "$file_path" && grep -q "$expected_value" "$file_path"; then
            echo -e "${GREEN}[ERFOLG]${NC} $json_key scheint in $file_name korrekt zu sein"
            return 0
        else
            echo -e "${RED}[FEHLGESCHLAGEN]${NC} $json_key in $file_name scheint nicht korrekt zu sein"
            echo -e "${YELLOW}Erwarteter Wert: $expected_value${NC}"
            echo -e "${YELLOW}Dateiinhalt:${NC}"
            cat "$file_path" | grep "$json_key" -A 1 -B 1
            return 1
        fi
    fi
}

# Funktion zur Überprüfung von VS Code Extensions
check_extension_installed() {
    local extension_id="$1"
    
    echo -e "${BLUE}[TEST]${NC} Überprüfe, ob VS Code Extension $extension_id installiert ist..."
    
    if sudo -u "$CODE_SERVER_USER" code-server --list-extensions | grep -q "$extension_id"; then
        echo -e "${GREEN}[ERFOLG]${NC} Extension $extension_id ist installiert"
        return 0
    else
        echo -e "${RED}[FEHLGESCHLAGEN]${NC} Extension $extension_id ist nicht installiert"
        return 1
    fi
}

# Header für Tests ausgeben
echo -e "${BLUE}=======================================================${NC}"
echo -e "${BLUE}     DevSystem E2E Test: code-server${NC}"
echo -e "${BLUE}=======================================================${NC}"
echo -e "${BLUE}Benutzer: $CODE_SERVER_USER${NC}"
echo -e "${BLUE}code-server Port: $CODE_SERVER_PORT${NC}"
echo -e "${BLUE}Caddy HTTPS Port: $CADDY_HTTPS_PORT${NC}"
echo -e "${BLUE}code-server URL: $CODE_SERVER_URL${NC}"
echo -e "${BLUE}=======================================================${NC}"

# Zähler für Tests
total_tests=0
failed_tests=0

# TEIL 1: Installation prüfen
echo -e "\n${BLUE}=== TEIL 1: Installation prüfen ===${NC}"

# 1.1: Prüfen, ob code-server installiert ist
total_tests=$((total_tests+1))
if ! check "code-server ist installiert" "command -v code-server" "code-server"; then
    failed_tests=$((failed_tests+1))
fi

# 1.2: Prüfen, ob code-server-Service läuft
total_tests=$((total_tests+1))
if ! check_service_running "code-server"; then
    failed_tests=$((failed_tests+1))
fi

# 1.3: Prüfen, ob code-server-Benutzer existiert
total_tests=$((total_tests+1))
if ! check "code-server-Benutzer existiert" "id -u $CODE_SERVER_USER" "$CODE_SERVER_USER"; then
    failed_tests=$((failed_tests+1))
fi

# TEIL 2: Port-Prüfung
echo -e "\n${BLUE}=== TEIL 2: Port-Prüfung ===${NC}"

# 2.1: Prüfen, ob code-server auf dem richtigen Port lauscht
total_tests=$((total_tests+1))
if ! check "code-server lauscht auf Port $CODE_SERVER_PORT" "ss -tulpn | grep LISTEN | grep :$CODE_SERVER_PORT" "$CODE_SERVER_PORT"; then
    failed_tests=$((failed_tests+1))
fi

# TEIL 3: Konfiguration prüfen
echo -e "\n${BLUE}=== TEIL 3: Konfiguration prüfen ===${NC}"

USER_HOME=$(eval echo ~${CODE_SERVER_USER})
SETTINGS_DIR="${USER_HOME}/.local/share/code-server/User"

# 3.1: Prüfen, ob settings.json existiert
total_tests=$((total_tests+1))
if ! check_file_exists "$SETTINGS_DIR/settings.json"; then
    failed_tests=$((failed_tests+1))
fi

# 3.2: Prüfen, ob keybindings.json existiert
total_tests=$((total_tests+1))
if ! check_file_exists "$SETTINGS_DIR/keybindings.json"; then
    failed_tests=$((failed_tests+1))
fi

# 3.3: Prüfen, ob settings.json korrekte Einstellungen enthält
if [[ -f "$SETTINGS_DIR/settings.json" ]]; then
    # Stichprobenartige Überprüfung einiger Einstellungen
    total_tests=$((total_tests+1))
    if ! check_json_value "$SETTINGS_DIR/settings.json" "editor.fontFamily" "JetBrains Mono"; then
        failed_tests=$((failed_tests+1))
    fi
    
    total_tests=$((total_tests+1))
    if ! check_json_value "$SETTINGS_DIR/settings.json" "workbench.colorTheme" "Default Dark+"; then
        failed_tests=$((failed_tests+1))
    fi
fi

# TEIL 4: Git-Konfiguration prüfen
echo -e "\n${BLUE}=== TEIL 4: Git-Konfiguration prüfen ===${NC}"

# 4.1: Prüfen, ob .gitconfig existiert
total_tests=$((total_tests+1))
if ! check_file_exists "${USER_HOME}/.gitconfig"; then
    failed_tests=$((failed_tests+1))
fi

# 4.2: Prüfen, ob Git-Benutzer konfiguriert ist
if [[ -f "${USER_HOME}/.gitconfig" ]]; then
    total_tests=$((total_tests+1))
    if ! check "Git-Benutzer ist konfiguriert" "sudo -u $CODE_SERVER_USER git config --get user.name" "DevSystem"; then
        failed_tests=$((failed_tests+1))
    fi
fi

# TEIL 5: VS Code Extensions prüfen
echo -e "\n${BLUE}=== TEIL 5: VS Code Extensions prüfen ===${NC}"

# 5.1: Prüfen, ob einige wichtige Extensions installiert sind
# Da die genauen Extensions je nach Installation variieren können, prüfen wir nur eine Auswahl
CORE_EXTENSIONS=(
    "ms-python.python" 
    "ms-azuretools.vscode-docker" 
)

for ext in "${CORE_EXTENSIONS[@]}"; do
    total_tests=$((total_tests+1))
    if ! check_extension_installed "$ext"; then
        failed_tests=$((failed_tests+1))
    fi
done

# TEIL 6: Beispielprojekt prüfen
echo -e "\n${BLUE}=== TEIL 6: Beispielprojekt prüfen ===${NC}"

# 6.1: Prüfen, ob das Beispielprojektverzeichnis existiert
total_tests=$((total_tests+1))
if ! check_dir_exists "${USER_HOME}/projects/devsystem-demo"; then
    failed_tests=$((failed_tests+1))
fi

# 6.2: Prüfen, ob die README.md im Beispielprojekt existiert
total_tests=$((total_tests+1))
if ! check_file_exists "${USER_HOME}/projects/devsystem-demo/README.md"; then
    failed_tests=$((failed_tests+1))
fi

# TEIL 7: Integration mit Caddy prüfen
echo -e "\n${BLUE}=== TEIL 7: Integration mit Caddy prüfen ===${NC}"

# 7.1: Prüfen, ob Caddy läuft
total_tests=$((total_tests+1))
if ! check_service_running "caddy"; then
    failed_tests=$((failed_tests+1))
fi

# 7.2: Prüfen, ob Caddy auf dem richtigen Port lauscht
total_tests=$((total_tests+1))
if ! check "Caddy lauscht auf Port $CADDY_HTTPS_PORT" "ss -tulpn | grep LISTEN | grep caddy" "$CADDY_HTTPS_PORT"; then
    failed_tests=$((failed_tests+1))
fi

# 7.3: Prüfen, ob die Caddy-Konfiguration auf code-server verweist
total_tests=$((total_tests+1))
if ! check "Caddy-Konfiguration verweist auf code-server" "grep -r \"localhost:$CODE_SERVER_PORT\" /etc/caddy" "$CODE_SERVER_PORT"; then
    failed_tests=$((failed_tests+1))
fi

# 7.4: Zugriff über Caddy testen (nur mit curl, da wir keinen Browser haben)
total_tests=$((total_tests+1))
if ip a | grep -q "tailscale"; then
    # Ermittle Tailscale IP
    TAILSCALE_IP=$(ip -4 addr show tailscale0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    if [[ -n "$TAILSCALE_IP" ]]; then
        if ! check "Zugriff über Caddy funktioniert" "curl -s -I --resolve \"$CODE_SERVER_URL:${CADDY_HTTPS_PORT}:$TAILSCALE_IP\" \"https://$CODE_SERVER_URL:${CADDY_HTTPS_PORT}/\" -k" "HTTP"; then
            echo -e "${YELLOW}[INFO]${NC} Dieser Test benötigt einen funktionierenden Browser für eine vollständige Validierung"
            failed_tests=$((failed_tests+1))
        fi
    else
        echo -e "${YELLOW}[INFO]${NC} Konnte keine Tailscale-IP ermitteln. Test übersprungen."
    fi
else
    echo -e "${YELLOW}[INFO]${NC} Kein Tailscale-Interface gefunden. Test übersprungen."
fi

# 7.5: Direkter Zugriff auf code-server testen
total_tests=$((total_tests+1))
if ! check "Direkter Zugriff auf code-server funktioniert" "curl -s -I \"http://localhost:$CODE_SERVER_PORT/\"" "HTTP"; then
    failed_tests=$((failed_tests+1))
fi

# Zusammenfassung ausgeben
echo -e "\n${BLUE}=======================================================${NC}"
echo -e "${BLUE}                   Zusammenfassung${NC}"
echo -e "${BLUE}=======================================================${NC}"
echo -e "Durchgeführte Tests: $total_tests"
if [[ $failed_tests -eq 0 ]]; then
    echo -e "${GREEN}Alle Tests bestanden!${NC}"
    exit 0
else
    echo -e "${RED}Fehlgeschlagene Tests: $failed_tests${NC}"
    exit 1
fi