#!/bin/bash
#
# DevSystem Code-Server PWA-Funktionalität E2E-Test
# Dieses Skript führt Tests für die Progressive Web App (PWA) Funktionalität von Code-Server durch
#
# Version: 1.0
# Autor: DevSystem Team
# Datum: 2026-04-11
#

# Fehler bei der Ausführung beenden das Skript
set -e

# Konfigurationsoptionen
VERBOSE=${VERBOSE:-false}
TEST_RESULTS_DIR=${TEST_RESULTS_DIR:-"/tmp/code-server-test-results"}
TEST_LOG_FILE="${TEST_RESULTS_DIR}/pwa-test-results.log"

# code-server-Konfiguration
CODE_SERVER_PORT="8080"
CADDY_PORT="9443"
TAILSCALE_IP=${TAILSCALE_IP:-""}

# Farbdefinitionen für Terminal-Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Testzähler
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

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
        "TEST") color=$BLUE ;;
        "STEP") color=$CYAN ;;
    esac
    
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message${NC}" | tee -a "$TEST_LOG_FILE"
}

# ============================================================================
# INITIALISIERUNG
# ============================================================================

# Initialisierung der Testumgebung
init_test_env() {
    mkdir -p "$TEST_RESULTS_DIR"
    > "$TEST_LOG_FILE"
    
    log "INFO" "Initialisiere PWA-Funktionalität-Tests..."
    
    if [ "$(id -u)" -ne 0 ]; then
        log "ERROR" "Dieses Skript muss als Root ausgeführt werden. Bitte verwenden Sie 'sudo'."
        exit 1
    fi
}

# Funktion zum Parsen der Kommandozeilenargumente
parse_args() {
    for arg in "$@"; do
        case $arg in
            --verbose)
                VERBOSE=true
                ;;
            --help)
                echo "Verwendung: sudo $0 [--verbose]"
                echo ""
                echo "Optionen:"
                echo "  --verbose             Ausführliche Ausgabe aktivieren"
                echo "  --help                Diese Hilfe anzeigen"
                echo ""
                exit 0
                ;;
        esac
    done
    
    if [ "$VERBOSE" = true ]; then
        log "INFO" "Ausführliche Ausgabe aktiviert."
    fi
}

# Funktion zum Ausführen eines Tests
run_test() {
    local test_name=$1
    local test_function=$2
    
    log "TEST" "Starte PWA-Test: $test_name"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if $test_function; then
        log "INFO" "Test '$test_name' erfolgreich abgeschlossen."
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        log "ERROR" "Test '$test_name' fehlgeschlagen."
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Funktion zum Anzeigen der Testergebnisse
show_test_results() {
    echo ""
    log "TEST" "====== PWA-Funktionalität Testergebnisse ======"
    log "INFO" "Durchgeführte Tests: $TOTAL_TESTS"
    log "INFO" "Erfolgreiche Tests: $PASSED_TESTS"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        log "INFO" "Fehlgeschlagene Tests: $FAILED_TESTS"
        log "INFO" "Alle PWA-Tests wurden erfolgreich abgeschlossen!"
    else
        log "ERROR" "Fehlgeschlagene Tests: $FAILED_TESTS"
        log "ERROR" "Einige PWA-Tests sind fehlgeschlagen. Überprüfen Sie die Logs für Details."
    fi
    
    echo ""
}

# Bestimme Test-URL
get_test_url() {
    log "STEP" "Bestimme Test-URL für PWA-Tests..."
    
    TEST_URL=""
    
    # Verwende Tailscale-URL wenn verfügbar
    if [ -n "$TAILSCALE_IP" ]; then
        TEST_URL="https://$TAILSCALE_IP:$CADDY_PORT"
        log "INFO" "Verwende Tailscale-URL für Tests: $TEST_URL"
        return 0
    fi
    
    # Fallback auf localhost
    TEST_URL="http://localhost:$CODE_SERVER_PORT"
    log "INFO" "Verwende localhost-URL für Tests: $TEST_URL"
    
    return 0
}

#######################################
# Test: Manifest-Datei
#######################################

test_manifest() {
    log "TEST" "Überprüfe Web App Manifest..."
    
    local test_failed=false
    
    if [ -z "$TEST_URL" ]; then
        log "ERROR" "Test-URL ist nicht verfügbar."
        return 1
    fi
    
    log "STEP" "Lade Webseite und prüfe manifest.json-Verweis..."
    local index_html=$(curl -k -s "$TEST_URL" 2>/dev/null || echo "")
    
    if [ -z "$index_html" ]; then
        log "ERROR" "Konnte Webseite nicht laden."
        return 1
    fi
    
    echo "$index_html" > "$TEST_RESULTS_DIR/code_server_index.html"
    
    # Prüfe ob ein Manifest-Link in der Seite existiert
    if grep -q '<link[^>]*rel="manifest"' "$TEST_RESULTS_DIR/code_server_index.html"; then
        log "INFO" "Manifest-Link in der Webseite gefunden."
        
        # Extrahiere den Pfad zum Manifest
        local manifest_path=$(grep -o '<link[^>]*rel="manifest"[^>]*href="[^"]*"' "$TEST_RESULTS_DIR/code_server_index.html" | grep -o 'href="[^"]*"' | cut -d'"' -f2)
        
        if [ -n "$manifest_path" ]; then
            log "INFO" "Manifest-Pfad: $manifest_path"
            
            # Lade das Manifest
            local manifest_url=""
            if [[ "$manifest_path" == /* ]]; then
                # Absoluter Pfad
                manifest_url="$TEST_URL$manifest_path"
            elif [[ "$manifest_path" == http* ]]; then
                # Vollständige URL
                manifest_url="$manifest_path"
            else
                # Relativer Pfad
                manifest_url="$TEST_URL/$manifest_path"
            fi
            
            log "STEP" "Lade Manifest von: $manifest_url"
            local manifest_content=$(curl -k -s "$manifest_url" 2>/dev/null || echo "")
            
            if [ -n "$manifest_content" ]; then
                echo "$manifest_content" > "$TEST_RESULTS_DIR/manifest.json"
                log "INFO" "Manifest erfolgreich geladen."
                
                # Prüfe ob die JSON-Syntax gültig ist
                if command -v jq &> /dev/null; then
                    if jq empty "$TEST_RESULTS_DIR/manifest.json" 2>/dev/null; then
                        log "INFO" "Manifest hat gültige JSON-Syntax."
                        
                        # Prüfe erforderliche Manifest-Felder
                        local has_name=$(jq 'has("name")' "$TEST_RESULTS_DIR/manifest.json")
                        local has_icons=$(jq 'has("icons")' "$TEST_RESULTS_DIR/manifest.json")
                        local has_start_url=$(jq 'has("start_url")' "$TEST_RESULTS_DIR/manifest.json")
                        local has_display=$(jq 'has("display")' "$TEST_RESULTS_DIR/manifest.json")
                        
                        [ "$has_name" = "true" ] && log "INFO" "Manifest enthält 'name'-Feld." || { log "WARN" "Manifest fehlt 'name'-Feld."; test_failed=true; }
                        [ "$has_icons" = "true" ] && log "INFO" "Manifest enthält 'icons'-Feld." || { log "WARN" "Manifest fehlt 'icons'-Feld."; test_failed=true; }
                        [ "$has_start_url" = "true" ] && log "INFO" "Manifest enthält 'start_url'-Feld." || { log "WARN" "Manifest fehlt 'start_url'-Feld."; test_failed=true; }
                        [ "$has_display" = "true" ] && log "INFO" "Manifest enthält 'display'-Feld." || { log "WARN" "Manifest fehlt 'display'-Feld."; test_failed=true; }
                        
                        # Detaillierte Manifest-Informationen im Verbose-Modus
                        if [ "$VERBOSE" = true ]; then
                            log "INFO" "Manifest-Inhalt:"
                            jq . "$TEST_RESULTS_DIR/manifest.json" | tee -a "$TEST_LOG_FILE"
                        fi
                    else
                        log "ERROR" "Manifest hat ungültige JSON-Syntax."
                        test_failed=true
                    fi
                else
                    log "WARN" "jq nicht installiert. Überspringe JSON-Validierung."
                fi
            else
                log "ERROR" "Konnte Manifest nicht laden."
                test_failed=true
            fi
        else
            log "ERROR" "Konnte Manifest-Pfad nicht extrahieren."
            test_failed=true
        fi
    else
        log "ERROR" "Kein Manifest-Link in der Webseite gefunden."
        test_failed=true
    fi
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# Test: Service Worker
#######################################

test_service_worker() {
    log "TEST" "Überprüfe Service Worker..."
    
    local test_failed=false
    
    if [ -z "$TEST_URL" ]; then
        log "ERROR" "Test-URL ist nicht verfügbar."
        return 1
    fi
    
    log "STEP" "Prüfe ob Service Worker in der Webseite registriert wird..."
    
    if [ ! -f "$TEST_RESULTS_DIR/code_server_index.html" ]; then
        local index_html=$(curl -k -s "$TEST_URL" 2>/dev/null || echo "")
        
        if [ -z "$index_html" ]; then
            log "ERROR" "Konnte Webseite nicht laden."
            return 1
        fi
        
        echo "$index_html" > "$TEST_RESULTS_DIR/code_server_index.html"
    fi
    
    # Prüfe auf Service Worker Registrierung in Scripts
    if grep -q "navigator\.serviceWorker\.register" "$TEST_RESULTS_DIR/code_server_index.html"; then
        log "INFO" "Service Worker Registrierung in der Webseite gefunden."
        
        # Extrahiere Service Worker Pfad
        local sw_path=$(grep -o "navigator\.serviceWorker\.register(['\"][^'\"]*['\"]" "$TEST_RESULTS_DIR/code_server_index.html" | grep -o "['\"][^'\"]*['\"]" | tr -d "\"'" || echo "")
        
        if [ -n "$sw_path" ]; then
            log "INFO" "Service Worker Pfad: $sw_path"
            
            # Lade den Service Worker
            local sw_url=""
            if [[ "$sw_path" == /* ]]; then
                # Absoluter Pfad
                sw_url="$TEST_URL$sw_path"
            elif [[ "$sw_path" == http* ]]; then
                # Vollständige URL
                sw_url="$sw_path"
            else
                # Relativer Pfad
                sw_url="$TEST_URL/$sw_path"
            fi
            
            log "STEP" "Lade Service Worker von: $sw_url"
            local sw_content=$(curl -k -s "$sw_url" 2>/dev/null || echo "")
            
            if [ -n "$sw_content" ]; then
                echo "$sw_content" > "$TEST_RESULTS_DIR/service-worker.js"
                log "INFO" "Service Worker erfolgreich geladen."
                
                # Prüfe typische Service Worker Funktionen
                if grep -q "cache\|fetch\|addEventListener" "$TEST_RESULTS_DIR/service-worker.js"; then
                    log "INFO" "Service Worker enthält typische Cache/Fetch Funktionalitäten."
                else
                    log "WARN" "Service Worker enthält möglicherweise keine Cache/Fetch Funktionalitäten."
                fi
            else
                log "ERROR" "Konnte Service Worker nicht laden."
                test_failed=true
            fi
        else
            log "WARN" "Konnte Service Worker Pfad nicht extrahieren."
            test_failed=true
        fi
    else
        log "WARN" "Keine Service Worker Registrierung in der Webseite gefunden."
        
        # Prüfe auf typische Service Worker Dateipfade
        for sw_path in "/service-worker.js" "/sw.js" "/js/service-worker.js" "/js/sw.js"; do
            local sw_url="$TEST_URL$sw_path"
            log "STEP" "Prüfe üblichen Service Worker Pfad: $sw_path"
            
            local sw_code=$(curl -k -s -o /dev/null -w "%{http_code}" "$sw_url" 2>/dev/null || echo "000")
            
            if [ "$sw_code" = "200" ]; then
                log "INFO" "Service Worker unter $sw_url gefunden."
                test_failed=false
                
                # Lade den Service Worker
                local sw_content=$(curl -k -s "$sw_url" 2>/dev/null || echo "")
                echo "$sw_content" > "$TEST_RESULTS_DIR/service-worker.js"
                
                if grep -q "cache\|fetch\|addEventListener" "$TEST_RESULTS_DIR/service-worker.js"; then
                    log "INFO" "Service Worker enthält typische Cache/Fetch Funktionalitäten."
                else
                    log "WARN" "Service Worker enthält möglicherweise keine Cache/Fetch Funktionalitäten."
                fi
                
                break
            elif [ "$sw_code" = "404" ]; then
                log "INFO" "Service Worker nicht unter $sw_url gefunden."
            else
                log "WARN" "Konnte Service Worker unter $sw_url nicht prüfen (HTTP-Code: $sw_code)."
            fi
        done
    fi
    
    [ "$test_failed" = true ] && log "ERROR" "Service Worker Tests fehlgeschlagen."
    
    return $test_failed
}

#######################################
# Test: PWA-Installierbarkeit
#######################################

test_pwa_installability() {
    log "TEST" "Überprüfe PWA-Installierbarkeit..."
    
    local test_failed=false
    
    if [ -z "$TEST_URL" ]; then
        log "ERROR" "Test-URL ist nicht verfügbar."
        return 1
    fi
    
    log "STEP" "Prüfe PWA-Installationsanforderungen..."
    
    # Prüfe ob Manifest vorhanden und gültig ist
    local manifest_valid=false
    if [ -f "$TEST_RESULTS_DIR/manifest.json" ]; then
        if command -v jq &> /dev/null && jq empty "$TEST_RESULTS_DIR/manifest.json" 2>/dev/null; then
            manifest_valid=true
            log "INFO" "Gültiges Web-Manifest vorhanden."
        else
            log "WARN" "Web-Manifest ist möglicherweise nicht gültig."
        fi
    else
        log "WARN" "Kein Web-Manifest gefunden."
    fi
    
    # Prüfe ob Service Worker vorhanden ist
    local sw_valid=false
    if [ -f "$TEST_RESULTS_DIR/service-worker.js" ]; then
        sw_valid=true
        log "INFO" "Service Worker vorhanden."
    else
        log "WARN" "Kein Service Worker gefunden."
    fi
    
    # Prüfe ob HTTPS verwendet wird
    local is_https=false
    if [[ "$TEST_URL" == https://* ]]; then
        is_https=true
        log "INFO" "HTTPS wird verwendet."
    else
        log "WARN" "HTTPS wird nicht verwendet (erforderlich für PWA-Installation)."
    fi
    
    # Prüfe auf erforderliche Icons im Manifest
    local has_required_icons=false
    if [ "$manifest_valid" = true ] && [ -f "$TEST_RESULTS_DIR/manifest.json" ]; then
        local icon_count=$(jq '.icons | length' "$TEST_RESULTS_DIR/manifest.json" 2>/dev/null || echo "0")
        
        if [ "$icon_count" -gt 0 ]; then
            log "INFO" "Manifest enthält $icon_count Icons."
            
            # Prüfe nach 192px und 512px Icons (für PWA installierbar)
            local has_192px=$(jq '.icons[] | select(.sizes == "192x192")' "$TEST_RESULTS_DIR/manifest.json" 2>/dev/null)
            local has_512px=$(jq '.icons[] | select(.sizes == "512x512")' "$TEST_RESULTS_DIR/manifest.json" 2>/dev/null)
            
            if [ -n "$has_192px" ] && [ -n "$has_512px" ]; then
                log "INFO" "Manifest enthält erforderliche Icon-Größen (192x192 und 512x512)."
                has_required_icons=true
            else
                log "WARN" "Manifest fehlen erforderliche Icon-Größen für PWA-Installation."
            fi
        else
            log "WARN" "Keine Icons im Manifest gefunden."
        fi
    fi
    
    # Gesamte PWA-Installierbarkeit bewerten
    if [ "$manifest_valid" = true ] && [ "$sw_valid" = true ] && [ "$is_https" = true ] && [ "$has_required_icons" = true ]; then
        log "INFO" "Anwendung erfüllt alle grundlegenden Anforderungen für PWA-Installation."
    else
        log "WARN" "Anwendung erfüllt nicht alle Anforderungen für PWA-Installation."
        
        # Übersicht der fehlenden Anforderungen
        [ "$manifest_valid" = false ] && log "INFO" "  - Fehlt: Gültiges Web-Manifest"
        [ "$sw_valid" = false ] && log "INFO" "  - Fehlt: Funktionierender Service Worker"
        [ "$is_https" = false ] && log "INFO" "  - Fehlt: HTTPS-Verbindung"
        [ "$has_required_icons" = false ] && log "INFO" "  - Fehlt: Erforderliche Icon-Größen (192x192, 512x512)"
        
        test_failed=true
    fi
    
    return $test_failed
}

#######################################
# Test: Meta-Tags und PWA-Header
#######################################

test_pwa_meta_tags() {
    log "TEST" "Überprüfe PWA Meta-Tags und Header..."
    
    local test_failed=false
    
    if [ -z "$TEST_URL" ]; then
        log "ERROR" "Test-URL ist nicht verfügbar."
        return 1
    fi
    
    log "STEP" "Prüfe PWA-spezifische Meta-Tags..."
    
    if [ ! -f "$TEST_RESULTS_DIR/code_server_index.html" ]; then
        local index_html=$(curl -k -s "$TEST_URL" 2>/dev/null || echo "")
        
        if [ -z "$index_html" ]; then
            log "ERROR" "Konnte Webseite nicht laden."
            return 1
        fi
        
        echo "$index_html" > "$TEST_RESULTS_DIR/code_server_index.html"
    fi
    
    # Prüfe auf theme-color Meta-Tag
    if grep -q '<meta[^>]*name="theme-color"' "$TEST_RESULTS_DIR/code_server_index.html"; then
        log "INFO" "theme-color Meta-Tag vorhanden."
        local theme_color=$(grep -o '<meta[^>]*name="theme-color"[^>]*content="[^"]*"' "$TEST_RESULTS_DIR/code_server_index.html" | grep -o 'content="[^"]*"' | cut -d'"' -f2)
        [ -n "$theme_color" ] && log "INFO" "Theme-Color: $theme_color"
    else
        log "WARN" "Kein theme-color Meta-Tag gefunden."
    fi
    
    # Prüfe auf viewport Meta-Tag
    if grep -q '<meta[^>]*name="viewport"' "$TEST_RESULTS_DIR/code_server_index.html"; then
        log "INFO" "viewport Meta-Tag vorhanden."
    else
        log "WARN" "Kein viewport Meta-Tag gefunden."
        test_failed=true
    fi
    
    # Prüfe auf mobile-web-app-capable Meta-Tag (für iOS)
    if grep -q '<meta[^>]*name="apple-mobile-web-app-capable"' "$TEST_RESULTS_DIR/code_server_index.html"; then
        log "INFO" "apple-mobile-web-app-capable Meta-Tag vorhanden."
    else
        log "WARN" "Kein apple-mobile-web-app-capable Meta-Tag gefunden."
    fi
    
    # Prüfe auf application-name Meta-Tag
    if grep -q '<meta[^>]*name="application-name"' "$TEST_RESULTS_DIR/code_server_index.html"; then
        log "INFO" "application-name Meta-Tag vorhanden."
        local app_name=$(grep -o '<meta[^>]*name="application-name"[^>]*content="[^"]*"' "$TEST_RESULTS_DIR/code_server_index.html" | grep -o 'content="[^"]*"' | cut -d'"' -f2)
        [ -n "$app_name" ] && log "INFO" "Application-Name: $app_name"
    else
        log "WARN" "Kein application-name Meta-Tag gefunden."
    fi
    
    # Prüfe auf Apple Touch Icon
    if grep -q '<link[^>]*rel="apple-touch-icon"' "$TEST_RESULTS_DIR/code_server_index.html"; then
        log "INFO" "Apple Touch Icon vorhanden."
    else
        log "WARN" "Kein Apple Touch Icon gefunden."
    fi
    
    # Header der Webseite prüfen
    log "STEP" "Prüfe Response-Header auf PWA-Unterstützung..."
    
    local headers_file="$TEST_RESULTS_DIR/response_headers.txt"
    curl -k -s -I "$TEST_URL" > "$headers_file" 2>/dev/null || true
    
    # Prüfe auf Service-Worker-Allowed Header
    if grep -qi "Service-Worker-Allowed:" "$headers_file"; then
        log "INFO" "Service-Worker-Allowed Header vorhanden."
        local sw_allowed=$(grep -i "Service-Worker-Allowed:" "$headers_file" | cut -d':' -f2 | tr -d ' \r\n')
        [ -n "$sw_allowed" ] && log "INFO" "Service-Worker-Allowed: $sw_allowed"
    else
        log "INFO" "Kein Service-Worker-Allowed Header gefunden."
    fi
    
    # Prüfe auf Cache-Control Header (für PWA-Ressourcen wichtig)
    if grep -qi "Cache-Control:" "$headers_file"; then
        log "INFO" "Cache-Control Header vorhanden."
    else
        log "WARN" "Kein Cache-Control Header gefunden."
    fi
    
    # Überprüfe grundlegende Header für eine Web-Anwendung
    [ "$VERBOSE" = true ] && log "INFO" "Response-Header:" && cat "$headers_file" | tee -a "$TEST_LOG_FILE"
    
    return $test_failed
}

#######################################
# Hauptfunktion
#######################################

main() {
    log "TEST" "==== Starte PWA-Funktionalität Tests für Code-Server ===="
    
    init_test_env
    parse_args "$@"
    get_test_url
    
    run_test "manifest" test_manifest
    run_test "service_worker" test_service_worker
    run_test "pwa_installability" test_pwa_installability
    run_test "pwa_meta_tags" test_pwa_meta_tags
    
    show_test_results
    
    log "TEST" "==== PWA-Funktionalität Tests abgeschlossen ===="
    
    if [ $FAILED_TESTS -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"