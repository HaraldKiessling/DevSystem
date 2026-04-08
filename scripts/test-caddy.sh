#!/bin/bash
#
# DevSystem - E2E Test für Caddy
# Autor: DevSystem Team
# Datum: 2026-04-08
#
# Beschreibung: 
# Dieses Skript führt End-to-End-Tests für die Caddy-Installation und -Konfiguration durch.
# Es überprüft:
# - Ob Caddy installiert ist und läuft
# - Ob alle Konfigurationsdateien korrekt erstellt wurden
# - Ob die TLS-Zertifikate vorhanden sind
# - Ob der Reverse Proxy für code-server korrekt funktioniert
# - Ob die Zugriffseinschränkung auf Tailscale-IPs funktioniert
# - Ob die Monitoring-Skripte und Cron-Jobs eingerichtet sind

set -e # Script beenden, wenn ein Befehl fehlschlägt

# Farbige Ausgabe für bessere Lesbarkeit
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Standardwerte für Konfigurationsparameter
DOMAIN=$(hostname).tailcfea8a.ts.net
TS_DOMAIN="code.devsystem.internal"
CODE_SERVER_PORT="8080"
CADDY_DIR="/etc/caddy"
CADDY_LOG_DIR="/var/log/caddy"

# Parameter-Verarbeitung
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --domain=*) DOMAIN="${1#*=}"; shift ;;
        --ts-domain=*) TS_DOMAIN="${1#*=}"; shift ;;
        --code-server-port=*) CODE_SERVER_PORT="${1#*=}"; shift ;;
        --help) 
            echo "Verwendung: $0 [Optionen]"
            echo "Optionen:"
            echo "  --domain=DOMAIN           Tailscale-Domain (Standard: hostname.tailcfea8a.ts.net)"
            echo "  --ts-domain=DOMAIN        Interne Domain (Standard: code.devsystem.internal)"
            echo "  --code-server-port=PORT   Port für code-server (Standard: 8080)"
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

# Funktion zur Prüfung der Caddy-Konfiguration
check_caddy_config() {
    echo -e "${BLUE}[TEST]${NC} Überprüfe Caddy-Konfiguration..."
    
    if caddy validate --config "$CADDY_DIR/Caddyfile" &>/dev/null; then
        echo -e "${GREEN}[ERFOLG]${NC} Caddy-Konfiguration ist gültig"
        return 0
    else
        echo -e "${RED}[FEHLGESCHLAGEN]${NC} Caddy-Konfiguration ist ungültig"
        echo -e "${YELLOW}Konfigurationsfehler:${NC}"
        caddy validate --config "$CADDY_DIR/Caddyfile"
        return 1
    fi
}

# Header für Tests ausgeben
echo -e "${BLUE}=======================================================${NC}"
echo -e "${BLUE}     DevSystem E2E Test: Caddy${NC}"
echo -e "${BLUE}=======================================================${NC}"
echo -e "${BLUE}Domain: $DOMAIN${NC}"
echo -e "${BLUE}Interne Domain: $TS_DOMAIN${NC}"
echo -e "${BLUE}Code-Server Port: $CODE_SERVER_PORT${NC}"
echo -e "${BLUE}=======================================================${NC}"

# Zähler für Tests
total_tests=0
failed_tests=0

# TEIL 1: Installation prüfen
echo -e "\n${BLUE}=== TEIL 1: Installation prüfen ===${NC}"

# 1.1: Prüfen, ob Caddy installiert ist
total_tests=$((total_tests+1))
if ! check "Caddy ist installiert" "command -v caddy" "caddy"; then
    failed_tests=$((failed_tests+1))
fi

# 1.2: Prüfen, ob Caddy-Service läuft
total_tests=$((total_tests+1))
if ! check_service_running "caddy"; then
    failed_tests=$((failed_tests+1))
fi

# TEIL 2: Verzeichnisstruktur prüfen
echo -e "\n${BLUE}=== TEIL 2: Verzeichnisstruktur prüfen ===${NC}"

# 2.1: Caddy-Verzeichnisstruktur prüfen
total_tests=$((total_tests+1))
if ! check_dir_exists "$CADDY_DIR"; then
    failed_tests=$((failed_tests+1))
fi

# 2.2: Caddy-Unterverzeichnisse prüfen
for dir in "$CADDY_DIR/sites" "$CADDY_DIR/snippets" "$CADDY_DIR/tls" "$CADDY_LOG_DIR"; do
    total_tests=$((total_tests+1))
    if ! check_dir_exists "$dir"; then
        failed_tests=$((failed_tests+1))
    fi
done

# TEIL 3: Konfigurationsdateien prüfen
echo -e "\n${BLUE}=== TEIL 3: Konfigurationsdateien prüfen ===${NC}"

# 3.1: Caddyfile prüfen
total_tests=$((total_tests+1))
if ! check_file_exists "$CADDY_DIR/Caddyfile"; then
    failed_tests=$((failed_tests+1))
fi

# 3.2: Snippet-Dateien prüfen
for file in "$CADDY_DIR/snippets/security-headers.caddy" "$CADDY_DIR/snippets/tailscale-auth.caddy"; do
    total_tests=$((total_tests+1))
    if ! check_file_exists "$file"; then
        failed_tests=$((failed_tests+1))
    fi
done

# 3.3: Site-Konfiguration prüfen
total_tests=$((total_tests+1))
if ! check_file_exists "$CADDY_DIR/sites/code-server.caddy"; then
    failed_tests=$((failed_tests+1))
fi

# 3.4: Monitoring-Skript prüfen
total_tests=$((total_tests+1))
if ! check_file_exists "/usr/local/bin/caddy-monitor.sh"; then
    failed_tests=$((failed_tests+1))
fi

# 3.5: Zertifikatserneuerungsskript prüfen
if [[ -f "$CADDY_DIR/tls/tailscale/$DOMAIN.crt" ]]; then
    total_tests=$((total_tests+1))
    if ! check_file_exists "/usr/local/bin/tailscale-cert-renew.sh"; then
        failed_tests=$((failed_tests+1))
    fi
fi

# TEIL 4: TLS-Zertifikate prüfen
echo -e "\n${BLUE}=== TEIL 4: TLS-Zertifikate prüfen ===${NC}"

# 4.1: Prüfen, ob Zertifikate vorhanden sind
total_tests=$((total_tests+1))
if [[ -f "$CADDY_DIR/tls/tailscale/$DOMAIN.crt" ]]; then
    echo -e "${GREEN}[ERFOLG]${NC} Tailscale-Zertifikat für $DOMAIN gefunden"
else
    if [[ -f "$CADDY_DIR/tls/local/$DOMAIN.crt" ]]; then
        echo -e "${YELLOW}[INFO]${NC} Selbstsigniertes Zertifikat für $DOMAIN gefunden (Tailscale-Fallback)"
    else
        echo -e "${RED}[FEHLGESCHLAGEN]${NC} Keine Zertifikate für $DOMAIN gefunden"
        failed_tests=$((failed_tests+1))
    fi
fi

# 4.2: Prüfen, ob die Zertifikate gültig sind
if [[ -f "$CADDY_DIR/tls/tailscale/$DOMAIN.crt" ]]; then
    total_tests=$((total_tests+1))
    if ! check "Tailscale-Zertifikat ist gültig" "openssl x509 -noout -text -in \"$CADDY_DIR/tls/tailscale/$DOMAIN.crt\" | grep \"Subject:\"" "$DOMAIN"; then
        failed_tests=$((failed_tests+1))
    fi
elif [[ -f "$CADDY_DIR/tls/local/$DOMAIN.crt" ]]; then
    total_tests=$((total_tests+1))
    if ! check "Selbstsigniertes Zertifikat ist gültig" "openssl x509 -noout -text -in \"$CADDY_DIR/tls/local/$DOMAIN.crt\" | grep \"Subject:\"" "$DOMAIN"; then
        failed_tests=$((failed_tests+1))
    fi
fi

# TEIL 5: Konfiguration validieren
echo -e "\n${BLUE}=== TEIL 5: Konfiguration validieren ===${NC}"

# 5.1: Caddy-Konfiguration validieren
total_tests=$((total_tests+1))
if ! check_caddy_config; then
    failed_tests=$((failed_tests+1))
fi

# 5.2: Prüfen, ob Caddy auf Port 443 lauscht
total_tests=$((total_tests+1))
if ! check "Caddy lauscht auf HTTPS-Port (443)" "ss -tulpn | grep LISTEN | grep caddy" "443"; then
    failed_tests=$((failed_tests+1))
fi

# TEIL 6: Cron-Jobs prüfen
echo -e "\n${BLUE}=== TEIL 6: Cron-Jobs prüfen ===${NC}"

# 6.1: Prüfen, ob Monitoring-Cron-Job eingerichtet ist
total_tests=$((total_tests+1))
if ! check "Monitoring-Cron-Job ist eingerichtet" "crontab -l" "caddy-monitor.sh"; then
    failed_tests=$((failed_tests+1))
fi

# 6.2: Prüfen, ob Zertifikatserneuerung-Cron-Job eingerichtet ist (nur bei Tailscale-Zertifikaten)
if [[ -f "$CADDY_DIR/tls/tailscale/$DOMAIN.crt" ]]; then
    total_tests=$((total_tests+1))
    if ! check "Zertifikatserneuerung-Cron-Job ist eingerichtet" "crontab -l" "tailscale-cert-renew.sh"; then
        failed_tests=$((failed_tests+1))
    fi
fi

# TEIL 7: Funktionalitätstest (nur wenn code-server bereits läuft)
echo -e "\n${BLUE}=== TEIL 7: Funktionalitätstest ===${NC}"

# 7.1: Prüfen, ob ein Dummy-Dienst für code-server auf dem konfigurierten Port läuft
if ! ss -tulpn | grep -q ":$CODE_SERVER_PORT "; then
    echo -e "${YELLOW}[INFO]${NC} Kein Dienst auf Port $CODE_SERVER_PORT gefunden. Starte temporären Dummy-HTTP-Server für Tests..."
    # Starte einen temporären HTTP-Server für den Test
    echo "Test Caddy Reverse Proxy" > /tmp/index.html
    python3 -m http.server "$CODE_SERVER_PORT" --directory /tmp > /dev/null 2>&1 &
    DUMMY_PID=$!
    sleep 2
fi

# 7.2: Prüfen, ob der Reverse Proxy richtig funktioniert (über tailscale IP)
total_tests=$((total_tests+1))
if ip a | grep -q "tailscale"; then
    # Ermittle Tailscale IP
    TAILSCALE_IP=$(ip -4 addr show tailscale0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    if [[ -n "$TAILSCALE_IP" ]]; then
        if ! check "Zugriff über Tailscale funktioniert" "curl -s --resolve \"$TS_DOMAIN:443:$TAILSCALE_IP\" \"https://$TS_DOMAIN/\" -k" "Test Caddy Reverse Proxy"; then
            echo -e "${YELLOW}[INFO]${NC} Dies könnte fehlschlagen, wenn code-server noch nicht läuft oder nicht auf Port $CODE_SERVER_PORT lauscht"
            failed_tests=$((failed_tests+1))
        fi
    else
        echo -e "${YELLOW}[INFO]${NC} Konnte keine Tailscale-IP ermitteln. Test übersprungen."
    fi
else
    echo -e "${YELLOW}[INFO]${NC} Kein Tailscale-Interface gefunden. Test übersprungen."
fi

# 7.3: Prüfen, ob die Zugriffseinschränkung funktioniert (Zugriff sollte von nicht-Tailscale-IP verweigert werden)
total_tests=$((total_tests+1))
if ! check "Zugriffseinschränkung funktioniert" "curl -s -H 'X-Forwarded-For: 1.2.3.4' \"http://localhost:443/\" -k" "Zugriff nur über Tailscale erlaubt"; then
    failed_tests=$((failed_tests+1))
fi

# Dummy-Server beenden, falls wir ihn gestartet haben
if [[ -n "${DUMMY_PID:-}" ]]; then
    kill $DUMMY_PID
    rm -f /tmp/index.html
    echo -e "${YELLOW}[INFO]${NC} Temporärer HTTP-Server beendet."
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