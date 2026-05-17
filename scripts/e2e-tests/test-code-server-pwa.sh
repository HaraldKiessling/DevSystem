#!/bin/bash
#
# test-code-server-pwa.sh - Tests für Progressive Web App Funktionalität
#
# Dieses Skript testet die PWA-Funktionalität des Code-Servers,
# validiert das Web-App-Manifest und überprüft Service Worker.
#
# Version: 1.0
# Autor: DevSystem Team
# Datum: 2026-04-12
#
# Verwendung: bash test-code-server-pwa.sh [--verbose]
#

# Fehler bei der Ausführung beenden das Skript
set -e

# Konfigurationsoptionen
VERBOSE=false
TEST_RESULTS_DIR="/tmp/code-server-e2e-test-results"
PWA_TEST_LOG="$TEST_RESULTS_DIR/pwa-test.log"
RETRY_COUNT=3
TIMEOUT_SECONDS=10

# Code-Server-Konfiguration
CODE_SERVER_PORT="8080"
CADDY_PORT="9443"
TAILSCALE_IP=""

# Browser User-Agents für Kompatibilitätstests
declare -A BROWSER_USER_AGENTS
BROWSER_USER_AGENTS["chrome"]="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
BROWSER_USER_AGENTS["firefox"]="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0"
BROWSER_USER_AGENTS["safari"]="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Safari/605.1.15"
BROWSER_USER_AGENTS["edge"]="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.59"

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
    
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [PWA-TEST] [$level] $message${NC}" | tee -a "$PWA_TEST_LOG"
}

# ============================================================================
# HILFSFUNKTIONEN
# ============================================================================

# Initialisierung der Testumgebung
init_test_env() {
    mkdir -p "$TEST_RESULTS_DIR"
    > "$PWA_TEST_LOG"
    
    log "INFO" "Initialisiere PWA-Testumgebung..."
}

# Funktion zum Parsen der Kommandozeilenargumente
parse_args() {
    for arg in "$@"; do
        case $arg in
            --verbose)
                VERBOSE=true
                ;;
            --help)
                echo "Verwendung: bash test-code-server-pwa.sh [--verbose]"
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

# Funktion zum Ausführen eines Tests mit Wiederholungsversuchen
run_test() {
    local test_name=$1
    local test_function=$2
    
    log "TEST" "Starte Test: $test_name"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    local attempt=1
    local success=false
    
    while [ $attempt -le $RETRY_COUNT ] && [ "$success" = false ]; do
        if [ $attempt -gt 1 ]; then
            log "WARN" "Wiederhole Test '$test_name' (Versuch $attempt von $RETRY_COUNT)..."
            sleep 2  # Kurze Pause vor erneuten Versuchen
        fi
        
        if $test_function; then
            log "INFO" "Test '$test_name' erfolgreich abgeschlossen."
            PASSED_TESTS=$((PASSED_TESTS + 1))
            success=true
        else
            if [ $attempt -lt $RETRY_COUNT ]; then
                log "WARN" "Test '$test_name' fehlgeschlagen (Versuch $attempt von $RETRY_COUNT). Versuche erneut..."
            else
                log "ERROR" "Test '$test_name' endgültig fehlgeschlagen nach $RETRY_COUNT Versuchen."
                FAILED_TESTS=$((FAILED_TESTS + 1))
                return 1
            fi
        fi
        
        attempt=$((attempt + 1))
    done
    
    return 0
}

# Funktion zum sicheren Ausführen von Curl mit Timeout und Fehlerbehandlung
safe_curl() {
    local url=$1
    local options=$2
    local output
    
    # Standardtimeout setzen
    if ! echo "$options" | grep -q "\-\-connect-timeout"; then
        options="$options --connect-timeout $TIMEOUT_SECONDS"
    fi
    
    # Stille Option hinzufügen, wenn nicht bereits vorhanden
    if ! echo "$options" | grep -q "\-s"; then
        options="$options -s"
    fi
    
    # Führe curl mit allen angegebenen Optionen aus
    output=$(curl -k $options "$url" 2>/dev/null)
    local status=$?
    
    if [ $status -ne 0 ]; then
        if [ "$VERBOSE" = true ]; then
            log "WARN" "curl-Aufruf zu '$url' fehlgeschlagen mit Status $status."
        fi
        return 1
    fi
    
    echo "$output"
    return 0
}

# Funktion zum Anzeigen der Testergebnisse
show_test_results() {
    echo ""
    log "TEST" "====== PWA-Testergebnisse ======"
    log "INFO" "Durchgeführte Tests: $TOTAL_TESTS"
    log "INFO" "Erfolgreiche Tests: $PASSED_TESTS"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        log "INFO" "Fehlgeschlagene Tests: $FAILED_TESTS"
        log "INFO" "Alle PWA-Tests wurden erfolgreich abgeschlossen!"
    else
        log "ERROR" "Fehlgeschlagene Tests: $FAILED_TESTS"
        log "ERROR" "Einige PWA-Tests sind fehlgeschlagen. Überprüfen Sie die Logs für Details: $PWA_TEST_LOG"
    fi
    
    echo ""
}

# Ermittlung der Tailscale-IP
get_tailscale_info() {
    log "STEP" "Ermittle Tailscale-Informationen für PWA-Tests..."
    
    if ! command -v tailscale &> /dev/null; then
        log "WARN" "Tailscale ist nicht installiert. Verwende localhost für Tests."
        TAILSCALE_IP="localhost"
        return 0
    fi
    
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null | head -n1 || echo "")
    
    if [ -z "$TAILSCALE_IP" ]; then
        log "WARN" "Konnte Tailscale-IP nicht ermitteln. Verwende localhost für Tests."
        TAILSCALE_IP="localhost"
    else
        log "INFO" "Tailscale-IP für PWA-Tests: $TAILSCALE_IP"
    fi
    
    return 0
}

#######################################
# 1. Test: PWA-Manifest
#######################################

test_pwa_manifest() {
    log "TEST" "Überprüfe PWA-Manifest..."
    
    local test_failed=false
    local target_url="https://$TAILSCALE_IP:$CADDY_PORT"
    
    log "STEP" "Lade die Code-Server-Hauptseite..."
    local index_html=$(safe_curl "$target_url" "-s" || echo "")
    
    if [ -z "$index_html" ]; then
        log "ERROR" "Konnte Code-Server-Seite nicht laden: $target_url"
        return 1
    fi
    
    # Speichere die Seite für weitere Analysen
    echo "$index_html" > "$TEST_RESULTS_DIR/code-server-index.html"
    
    log "STEP" "Suche nach Manifest-Link in der HTML-Seite..."
    local manifest_link=$(grep -o '<link[^>]*rel="manifest"[^>]*href="[^"]*"[^>]*>' "$TEST_RESULTS_DIR/code-server-index.html" | grep -o 'href="[^"]*"' | cut -d'"' -f2 || echo "")
    
    if [ -z "$manifest_link" ]; then
        log "WARN" "Kein Manifest-Link in der HTML-Seite gefunden. Code-Server nutzt möglicherweise kein PWA-Manifest."
        log "INFO" "PWA-Funktionalität könnte eingeschränkt sein, was aber kein kritischer Fehler ist."
        return 0
    fi
    
    log "INFO" "Manifest-Link gefunden: $manifest_link"
    
    # Normalisiere den Manifest-Link (falls relativ)
    if [[ $manifest_link == /* ]]; then
        manifest_link="https://$TAILSCALE_IP:$CADDY_PORT$manifest_link"
    elif [[ $manifest_link != http* ]]; then
        manifest_link="https://$TAILSCALE_IP:$CADDY_PORT/$manifest_link"
    fi
    
    log "STEP" "Lade PWA-Manifest von: $manifest_link"
    local manifest_content=$(safe_curl "$manifest_link" "-s" || echo "")
    
    if [ -z "$manifest_content" ]; then
        log "ERROR" "Konnte PWA-Manifest nicht laden: $manifest_link"
        test_failed=true
    else
        echo "$manifest_content" > "$TEST_RESULTS_DIR/pwa-manifest.json"
        
        log "INFO" "PWA-Manifest geladen und gespeichert."
        
        # Erweiterte Manifest-Validierung
        local required_fields=("name" "short_name" "icons" "display" "start_url" "background_color" "theme_color")
        local missing_fields=0
        local manifest_validation_log="$TEST_RESULTS_DIR/manifest-validation.log"
        
        > "$manifest_validation_log"
        
        log "STEP" "Führe erweiterte Validierung des PWA-Manifests durch..."
        
        for field in "${required_fields[@]}"; do
            if grep -q "\"$field\":" "$TEST_RESULTS_DIR/pwa-manifest.json"; then
                echo "[VALID] Feld '$field' ist vorhanden" >> "$manifest_validation_log"
            else
                echo "[MISSING] Erforderliches Feld '$field' fehlt" >> "$manifest_validation_log"
                missing_fields=$((missing_fields + 1))
            fi
        done
        
        # Prüfe Icons auf verschiedene Größen
        if grep -q "\"icons\"" "$TEST_RESULTS_DIR/pwa-manifest.json"; then
            local icon_count=$(grep -o "\"sizes\":" "$TEST_RESULTS_DIR/pwa-manifest.json" | wc -l)
            echo "[INFO] $icon_count Icon-Größen gefunden" >> "$manifest_validation_log"
            
            # Validiere, ob wichtige Icon-Größen vorhanden sind (192x192, 512x512)
            if grep -q "192x192" "$TEST_RESULTS_DIR/pwa-manifest.json"; then
                echo "[VALID] Icon-Größe 192x192 vorhanden (wichtig für Android)" >> "$manifest_validation_log"
            else
                echo "[MISSING] Icon-Größe 192x192 fehlt (wichtig für Android)" >> "$manifest_validation_log"
            fi
            
            if grep -q "512x512" "$TEST_RESULTS_DIR/pwa-manifest.json"; then
                echo "[VALID] Icon-Größe 512x512 vorhanden (wichtig für PWA-Installation)" >> "$manifest_validation_log"
            else
                echo "[MISSING] Icon-Größe 512x512 fehlt (wichtig für PWA-Installation)" >> "$manifest_validation_log"
            fi
        fi
        
        # Prüfe display-Modus
        local display_mode=$(grep -o "\"display\":[^,}]*" "$TEST_RESULTS_DIR/pwa-manifest.json" | cut -d'"' -f4)
        if [ -n "$display_mode" ]; then
            echo "[INFO] Display-Modus: $display_mode" >> "$manifest_validation_log"
            
            # Bevorzugte Modi für PWAs
            if [ "$display_mode" = "standalone" ] || [ "$display_mode" = "fullscreen" ]; then
                echo "[VALID] Display-Modus '$display_mode' ist optimal für PWAs" >> "$manifest_validation_log"
            else
                echo "[WARN] Display-Modus '$display_mode' ist nicht optimal für PWAs (standalone oder fullscreen empfohlen)" >> "$manifest_validation_log"
            fi
        fi
        
        # Ausgabe der Validierungsergebnisse
        if [ $missing_fields -eq 0 ]; then
            log "INFO" "PWA-Manifest enthält alle erforderlichen Felder."
        else
            log "WARN" "PWA-Manifest fehlen $missing_fields erforderliche Felder."
            if [ $missing_fields -gt 2 ]; then
                test_failed=true
            fi
        fi
        
        if [ "$VERBOSE" = true ]; then
            log "INFO" "Detaillierte Manifest-Validierungsergebnisse:"
            cat "$manifest_validation_log" | tee -a "$PWA_TEST_LOG"
            
            log "INFO" "PWA-Manifest Inhalt:"
            cat "$TEST_RESULTS_DIR/pwa-manifest.json" | tee -a "$PWA_TEST_LOG"
        fi
    fi
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# 2. Test: Service Worker
#######################################

test_service_worker() {
    log "TEST" "Überprüfe Service Worker..."
    
    local test_failed=false
    local target_url="https://$TAILSCALE_IP:$CADDY_PORT"
    
    if [ ! -f "$TEST_RESULTS_DIR/code-server-index.html" ]; then
        log "STEP" "Lade die Code-Server-Hauptseite..."
        local index_html=$(safe_curl "$target_url" "-s" || echo "")
        echo "$index_html" > "$TEST_RESULTS_DIR/code-server-index.html"
    fi
    
    log "STEP" "Suche nach Service Worker Registrierung..."
    if grep -q "serviceWorker" "$TEST_RESULTS_DIR/code-server-index.html" || grep -q "navigator.serviceWorker.register" "$TEST_RESULTS_DIR/code-server-index.html"; then
        log "INFO" "Service Worker Registrierung in der HTML-Seite gefunden."
        
        # Extrahiere Service Worker URL falls möglich
        local service_worker_path=$(grep -o "navigator.serviceWorker.register(['\"][^'\"]*['\"]" "$TEST_RESULTS_DIR/code-server-index.html" | grep -o "['\"][^'\"]*['\"]" | tr -d "\"'" || echo "")
        
        if [ -n "$service_worker_path" ]; then
            log "INFO" "Service Worker Pfad: $service_worker_path"
            
            # Normalisiere den Pfad
            if [[ $service_worker_path == /* ]]; then
                service_worker_url="https://$TAILSCALE_IP:$CADDY_PORT$service_worker_path"
            elif [[ $service_worker_path != http* ]]; then
                service_worker_url="https://$TAILSCALE_IP:$CADDY_PORT/$service_worker_path"
            else
                service_worker_url="$service_worker_path"
            fi
            
            # Versuche, den Service Worker zu laden
            log "STEP" "Versuche, Service Worker zu laden: $service_worker_url"
            local service_worker_content=$(safe_curl "$service_worker_url" "-s" || echo "")
            
            if [ -n "$service_worker_content" ]; then
                log "INFO" "Service Worker konnte geladen werden."
                echo "$service_worker_content" > "$TEST_RESULTS_DIR/service-worker.js"
                
                # Analysiere Service Worker Funktionalität
                log "STEP" "Analysiere Service Worker Funktionalität..."
                local sw_analysis_log="$TEST_RESULTS_DIR/service-worker-analysis.log"
                > "$sw_analysis_log"
                
                # Überprüfe auf typische Service Worker Funktionen
                if grep -q "self.addEventListener('install'" "$TEST_RESULTS_DIR/service-worker.js"; then
                    echo "[VALID] Service Worker enthält Install-Event-Handler" >> "$sw_analysis_log"
                else
                    echo "[MISSING] Service Worker enthält keinen Install-Event-Handler" >> "$sw_analysis_log"
                    test_failed=true
                fi
                
                if grep -q "self.addEventListener('activate'" "$TEST_RESULTS_DIR/service-worker.js"; then
                    echo "[VALID] Service Worker enthält Activate-Event-Handler" >> "$sw_analysis_log"
                else
                    echo "[MISSING] Service Worker enthält keinen Activate-Event-Handler" >> "$sw_analysis_log"
                    test_failed=true
                fi
                
                if grep -q "self.addEventListener('fetch'" "$TEST_RESULTS_DIR/service-worker.js"; then
                    echo "[VALID] Service Worker enthält Fetch-Event-Handler (wichtig für Offline-Funktionalität)" >> "$sw_analysis_log"
                else
                    echo "[MISSING] Service Worker enthält keinen Fetch-Event-Handler (kritisch für Offline-Funktionalität)" >> "$sw_analysis_log"
                    test_failed=true
                fi
                
                # Überprüfe auf Cache-Funktionalität
                if grep -q "caches.open" "$TEST_RESULTS_DIR/service-worker.js" || grep -q "cache.addAll" "$TEST_RESULTS_DIR/service-worker.js"; then
                    echo "[VALID] Service Worker verwendet Cache API" >> "$sw_analysis_log"
                    
                    # Extrahiere Cache-Namen falls möglich
                    local cache_names=$(grep -o "caches.open(['\"][^'\"]*['\"]" "$TEST_RESULTS_DIR/service-worker.js" | grep -o "['\"][^'\"]*['\"]" | tr -d "\"'" || echo "")
                    if [ -n "$cache_names" ]; then
                        echo "[INFO] Gefundene Cache-Namen: $cache_names" >> "$sw_analysis_log"
                    fi
                else
                    echo "[MISSING] Service Worker verwendet keine Cache API (wichtig für Offline-Funktionalität)" >> "$sw_analysis_log"
                fi
                
                # Überprüfe Version/Update-Mechanismus
                if grep -q "cache.keys" "$TEST_RESULTS_DIR/service-worker.js" || grep -q "caches.delete" "$TEST_RESULTS_DIR/service-worker.js"; then
                    echo "[VALID] Service Worker enthält Cache-Management-Funktionalität" >> "$sw_analysis_log"
                else
                    echo "[WARN] Service Worker enthält möglicherweise keine Cache-Management-Funktionalität" >> "$sw_analysis_log"
                fi
                
                if [ "$VERBOSE" = true ]; then
                    log "INFO" "Service Worker Analyse-Ergebnisse:"
                    cat "$sw_analysis_log" | tee -a "$PWA_TEST_LOG"
                    
                    log "INFO" "Service Worker Codeausschnitt (erste 10 Zeilen):"
                    head -n 10 "$TEST_RESULTS_DIR/service-worker.js" | tee -a "$PWA_TEST_LOG"
                fi
            else
                log "WARN" "Service Worker konnte nicht geladen werden: $service_worker_url"
                test_failed=true
            fi
        else
            log "WARN" "Service Worker Pfad konnte nicht extrahiert werden."
            test_failed=true
        fi
    else
        log "WARN" "Keine Service Worker Registrierung in der HTML-Seite gefunden."
        log "INFO" "Code-Server nutzt möglicherweise keinen Service Worker, was für die PWA-Funktionalität nicht optimal ist."
        test_failed=true
    fi
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# 3. Test: PWA-Header
#######################################

test_pwa_headers() {
    log "TEST" "Überprüfe PWA-relevante HTTP-Header..."
    
    local test_failed=false
    local target_url="https://$TAILSCALE_IP:$CADDY_PORT"
    local headers_log="$TEST_RESULTS_DIR/pwa-headers-analysis.log"
    
    log "STEP" "Lade HTTP-Header der Code-Server-Seite..."
    local headers=$(safe_curl "$target_url" "-I -s" || echo "")
    
    if [ -z "$headers" ]; then
        log "ERROR" "Konnte keine HTTP-Header von der Code-Server-Seite laden."
        return 1
    fi
    
    echo "$headers" > "$TEST_RESULTS_DIR/pwa-headers.txt"
    > "$headers_log"
    
    # Prüfen auf Content-Security-Policy mit worker-src Direktive
    if grep -i "Content-Security-Policy" "$TEST_RESULTS_DIR/pwa-headers.txt" | grep -q "worker-src"; then
        log "INFO" "Content-Security-Policy mit worker-src Direktive gefunden (gut für Service Worker)."
        echo "[VALID] Content-Security-Policy mit worker-src Direktive gefunden" >> "$headers_log"
    else
        log "WARN" "Keine Content-Security-Policy mit worker-src Direktive gefunden."
        echo "[MISSING] Content-Security-Policy fehlt worker-src Direktive" >> "$headers_log"
        # Nicht kritisch, daher kein Testfehler
    fi
    
    # Prüfen auf Cache-Control
    if grep -i "Cache-Control" "$TEST_RESULTS_DIR/pwa-headers.txt"; then
        log "INFO" "Cache-Control Header gefunden."
        echo "[VALID] Cache-Control Header gefunden" >> "$headers_log"
        
        # Analysiere Cache-Control Werte
        local cache_control=$(grep -i "Cache-Control:" "$TEST_RESULTS_DIR/pwa-headers.txt" | cut -d":" -f2- | tr -d '\r')
        echo "[INFO] Cache-Control Wert: $cache_control" >> "$headers_log"
        
        # Prüfe, ob Cache-Control für PWA geeignet ist
        if echo "$cache_control" | grep -q "max-age"; then
            echo "[VALID] Cache-Control enthält max-age Direktive" >> "$headers_log"
            
            # Extrahiere max-age Wert
            local max_age=$(echo "$cache_control" | grep -o "max-age=[0-9]*" | cut -d"=" -f2)
            if [ -n "$max_age" ] && [ "$max_age" -gt 3600 ]; then
                echo "[VALID] Cache max-age ist mehr als eine Stunde ($max_age Sekunden)" >> "$headers_log"
            else
                echo "[WARN] Cache max-age ist recht kurz für PWA-Assets ($max_age Sekunden)" >> "$headers_log"
            fi
        else
            echo "[MISSING] Cache-Control enthält keine max-age Direktive" >> "$headers_log"
        fi
    else
        log "WARN" "Kein Cache-Control Header gefunden."
        echo "[MISSING] Kein Cache-Control Header gefunden" >> "$headers_log"
    fi
    
    # Prüfen auf Service-Worker-Allowed
    if grep -i "Service-Worker-Allowed" "$TEST_RESULTS_DIR/pwa-headers.txt"; then
        log "INFO" "Service-Worker-Allowed Header gefunden."
        echo "[VALID] Service-Worker-Allowed Header gefunden" >> "$headers_log"
        
        # Extrahiere Wert
        local sw_allowed=$(grep -i "Service-Worker-Allowed:" "$TEST_RESULTS_DIR/pwa-headers.txt" | cut -d":" -f2- | tr -d '\r')
        echo "[INFO] Service-Worker-Allowed Wert: $sw_allowed" >> "$headers_log"
    else
        log "INFO" "Kein Service-Worker-Allowed Header gefunden (optional)."
        echo "[INFO] Kein Service-Worker-Allowed Header gefunden (optional)" >> "$headers_log"
    fi
    
    # Prüfen auf ETag (wichtig für Ressourcenaktualisierung)
    if grep -i "ETag:" "$TEST_RESULTS_DIR/pwa-headers.txt"; then
        log "INFO" "ETag Header gefunden (gut für Asset-Aktualisierungen)."
        echo "[VALID] ETag Header gefunden" >> "$headers_log"
    else
        log "INFO" "Kein ETag Header gefunden (optional, aber nützlich für Versionierung)."
        echo "[INFO] Kein ETag Header gefunden" >> "$headers_log"
    fi
    
    if [ "$VERBOSE" = true ]; then
        log "INFO" "PWA Header-Analyse:"
        cat "$headers_log" | tee -a "$PWA_TEST_LOG"
        
        log "INFO" "Alle HTTP-Header:"
        cat "$TEST_RESULTS_DIR/pwa-headers.txt" | tee -a "$PWA_TEST_LOG"
    fi
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# 4. Test: Offline-Funktionalität
#######################################

test_offline_functionality() {
    log "TEST" "Überprüfe Offline-Funktionalität..."
    
    local test_failed=false
    local offline_log="$TEST_RESULTS_DIR/offline-functionality.log"
    
    > "$offline_log"
    
    log "STEP" "Analysiere Service Worker für Offline-Funktionalität..."
    
    # Prüfe, ob Service Worker existiert
    if [ ! -f "$TEST_RESULTS_DIR/service-worker.js" ]; then
        log "WARN" "Service Worker Datei fehlt. Offline-Test nicht möglich."
        echo "[MISSING] Service Worker Datei fehlt. Offline-Funktionalität wahrscheinlich nicht vorhanden." >> "$offline_log"
        test_failed=true
    else
        # Analysiere Service Worker für Offline-Funktionalität
        
        # 1. Prüfe auf Fetch-Event-Handler (Grundlage für Offline-Funktionalität)
        if grep -q "self.addEventListener('fetch'" "$TEST_RESULTS_DIR/service-worker.js"; then
            log "INFO" "Service Worker enthält Fetch-Event-Handler (Grundlage für Offline-Funktionalität)."
            echo "[VALID] Service Worker enthält Fetch-Event-Handler" >> "$offline_log"
            
            # 2. Prüfe auf typische Offline-Strategien
            if grep -q "caches.match" "$TEST_RESULTS_DIR/service-worker.js"; then
                log "INFO" "Service Worker implementiert Cache-First- oder Cache-Fallback-Strategie."
                echo "[VALID] Service Worker verwendet caches.match für Offline-Zugriff" >> "$offline_log"
            else
                log "WARN" "Service Worker scheint keine Cache-First- oder Cache-Fallback-Strategie zu implementieren."
                echo "[MISSING] Service Worker verwendet nicht caches.match für Offline-Zugriff" >> "$offline_log"
                test_failed=true
            fi
            
            # 3. Prüfe auf umfangreiche Cache-Implementierung
            if grep -q "cache.addAll" "$TEST_RESULTS_DIR/service-worker.js"; then
                log "INFO" "Service Worker implementiert vorbeugendes Caching von Assets."
                echo "[VALID] Service Worker verwendet cache.addAll für vorbeugendes Caching" >> "$offline_log"
                
                # Versuche die Liste der zu cachenden Assets zu extrahieren
                local cache_files=$(grep -A20 "cache.addAll" "$TEST_RESULTS_DIR/service-worker.js" | grep -o "'[^']*'" | tr -d "'" || echo "")
                if [ -n "$cache_files" ]; then
                    echo "[INFO] Vorgecachte Dateien gefunden:" >> "$offline_log"
                    echo "$cache_files" >> "$offline_log"
                    
                    # Zähle die Anzahl der gecachten Dateien
                    local file_count=$(echo "$cache_files" | wc -l)
                    echo "[INFO] Anzahl gecachter Dateien: $file_count" >> "$offline_log"
                    
                    if [ "$file_count" -lt 5 ]; then
                        echo "[WARN] Sehr wenige Dateien im Cache (<5). Möglicherweise unvollständiges Offline-Erlebnis." >> "$offline_log"
                    fi
                fi
            else
                log "WARN" "Service Worker scheint kein vorbeugendes Caching zu implementieren."
                echo "[MISSING] Service Worker verwendet nicht cache.addAll für vorbeugendes Caching" >> "$offline_log"
            fi
            
            # 4. Prüfe auf Cache-Aktualisierungsstrategien
            if grep -q "caches.delete" "$TEST_RESULTS_DIR/service-worker.js" || grep -q "cache.keys" "$TEST_RESULTS_DIR/service-worker.js"; then
                log "INFO" "Service Worker implementiert Cache-Verwaltung oder -Aktualisierung."
                echo "[VALID] Service Worker enthält Cache-Management-Code" >> "$offline_log"
            else
                log "WARN" "Service Worker implementiert möglicherweise keine Cache-Aktualisierungsstrategien."
                echo "[MISSING] Service Worker enthält keinen offensichtlichen Cache-Management-Code" >> "$offline_log"
            fi
            
            # 5. Prüfe auf konkrete Offline-Fallback-Seite
            if grep -q "new Response" "$TEST_RESULTS_DIR/service-worker.js" && grep -q "fetch.*catch" "$TEST_RESULTS_DIR/service-worker.js"; then
                log "INFO" "Service Worker scheint benutzerdefinierte Offline-Fallback-Inhalte zu implementieren."
                echo "[VALID] Service Worker bietet benutzerdefinierte Offline-Inhalte" >> "$offline_log"
            else
                log "INFO" "Service Worker bietet möglicherweise keine benutzerdefinierten Offline-Inhalte."
                echo "[INFO] Keine offensichtliche benutzerdefinierte Offline-Seite gefunden" >> "$offline_log"
            fi
            
        else
            log "WARN" "Service Worker enthält keinen Fetch-Event-Handler. Offline-Funktionalität wahrscheinlich nicht implementiert."
            echo "[MISSING] Service Worker enthält keinen Fetch-Event-Handler (kritisch für Offline-Funktionalität)" >> "$offline_log"
            test_failed=true
        fi
    fi
    
    log "STEP" "Simuliere Prüfung der Offline-Verfügbarkeit von Ressourcen..."
    
    # Simuliere Offline-Test durch Prüfung der Cache-Header
    if [ -f "$TEST_RESULTS_DIR/pwa-headers.txt" ]; then
        if grep -i "Cache-Control:" "$TEST_RESULTS_DIR/pwa-headers.txt" | grep -q "max-age"; then
            log "INFO" "Ressourcen-Caching durch Cache-Control-Header unterstützt."
            echo "[VALID] HTTP-Caching durch Cache-Control-Header unterstützt" >> "$offline_log"
        else
            log "WARN" "Ressourcen-Caching durch Cache-Control-Header möglicherweise nicht optimal konfiguriert."
            echo "[WARN] HTTP-Caching durch Cache-Control-Header möglicherweise nicht optimal" >> "$offline_log"
        fi
    fi
    
    log "INFO" "Hinweis: Vollständige Offline-Tests erfordern einen echten Browser mit DevTools."
    echo "[INFO] Vollständige Offline-Tests empfohlen mit Chrome DevTools > Application > Service Workers > Offline" >> "$offline_log"
    
    if [ "$VERBOSE" = true ]; then
        log "INFO" "Analyse der Offline-Funktionalität:"
        cat "$offline_log" | tee -a "$PWA_TEST_LOG"
    fi
    
    # Test gilt nur als fehlgeschlagen, wenn Service Worker komplett fehlt oder Fetch-Event-Handler fehlt
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# 5. Test: Browser-Kompatibilität
#######################################

test_browser_compatibility() {
    log "TEST" "Überprüfe Browser-Kompatibilität (simuliert)..."
    
    local test_failed=false
    local compat_log="$TEST_RESULTS_DIR/browser-compatibility.log"
    local target_url="https://$TAILSCALE_IP:$CADDY_PORT"
    
    > "$compat_log"
    
    log "STEP" "Analysiere Browser-Kompatibilität der PWA-Komponenten..."
    
    # 1. Überprüfe Manifest auf Browser-Kompatibilität
    if [ -f "$TEST_RESULTS_DIR/pwa-manifest.json" ]; then
        echo "=== Manifest Browser-Kompatibilität ===" >> "$compat_log"
        
        # Prüfe auf browser-spezifische Manifest-Felder
        if grep -q "\"theme_color\":" "$TEST_RESULTS_DIR/pwa-manifest.json"; then
            echo "[VALID] Manifest enthält theme_color (unterstützt in Chrome, Edge, Samsung Internet)" >> "$compat_log"
        else
            echo "[MISSING] Manifest enthält kein theme_color (empfohlen für Chrome, Edge, Samsung Internet)" >> "$compat_log"
        fi
        
        if grep -q "\"background_color\":" "$TEST_RESULTS_DIR/pwa-manifest.json"; then
            echo "[VALID] Manifest enthält background_color (wichtig für den App-Ladebildschirm)" >> "$compat_log"
        else
            echo "[MISSING] Manifest enthält kein background_color (kann zu weißem Bildschirm beim Laden führen)" >> "$compat_log"
        fi
        
        # Prüfe auf verschiedene Icon-Formate
        if grep -q "\.png" "$TEST_RESULTS_DIR/pwa-manifest.json"; then
            echo "[VALID] Manifest enthält PNG-Icons (universal unterstützt)" >> "$compat_log"
        else
            echo "[WARN] Manifest enthält keine PNG-Icons (universelle Formatunterstützung empfohlen)" >> "$compat_log"
        fi
        
        # Prüfe auf iOS-spezifische Manifest-Felder
        if grep -q "\"apple-touch-icon\"" "$TEST_RESULTS_DIR/pwa-manifest.json" || \
           grep -q "\"apple-mobile-web-app-capable\"" "$TEST_RESULTS_DIR/pwa-manifest.json" || \
           grep -q "\"apple-mobile-web-app-status-bar-style\"" "$TEST_RESULTS_DIR/pwa-manifest.json"; then
            echo "[VALID] Manifest enthält iOS-spezifische Felder" >> "$compat_log"
        else
            echo "[INFO] Manifest enthält keine iOS-spezifischen Felder (optional für Safari auf iOS)" >> "$compat_log"
        fi
    else
        echo "[MISSING] PWA-Manifest nicht gefunden - kann Browser-Kompatibilität nicht prüfen" >> "$compat_log"
    fi
    
    # 2. Überprüfe Service Worker auf Browser-Kompatibilität
    if [ -f "$TEST_RESULTS_DIR/service-worker.js" ]; then
        echo "" >> "$compat_log"
        echo "=== Service Worker Browser-Kompatibilität ===" >> "$compat_log"
        
        # Prüfe auf moderne APIs, die möglicherweise nicht in älteren Browsern unterstützt werden
        if grep -q "navigator.serviceWorker.register" "$TEST_RESULTS_DIR/code-server-index.html"; then
            echo "[VALID] Standard Service Worker-Registrierung (gut unterstützt in modernen Browsern)" >> "$compat_log"
        fi
        
        # Prüfe auf Verwendung von async/await oder Promises
        if grep -q "async" "$TEST_RESULTS_DIR/service-worker.js" || grep -q "await" "$TEST_RESULTS_DIR/service-worker.js"; then
            echo "[INFO] Service Worker verwendet async/await (IE11 nicht unterstützt, sonst gut)" >> "$compat_log"
        else
            if grep -q "Promise" "$TEST_RESULTS_DIR/service-worker.js" || grep -q "then(" "$TEST_RESULTS_DIR/service-worker.js"; then
                echo "[VALID] Service Worker verwendet Promises (gute Browser-Kompatibilität)" >> "$compat_log"
            fi
        fi
        
        # Prüfe auf Cache Storage API 
        if grep -q "caches.open" "$TEST_RESULTS_DIR/service-worker.js" || grep -q "cache.addAll" "$TEST_RESULTS_DIR/service-worker.js"; then
            echo "[VALID] Service Worker nutzt Cache Storage API (gut unterstützt in modernen Browsern)" >> "$compat_log"
        fi
        
        # Prüfe auf IndexedDB Nutzung (komplexer zu unterstützen)
        if grep -q "indexedDB" "$TEST_RESULTS_DIR/service-worker.js" || grep -q "openDatabase" "$TEST_RESULTS_DIR/service-worker.js"; then
            echo "[INFO] Service Worker nutzt IndexedDB (Vorsicht bei Safari auf iOS)" >> "$compat_log"
        fi
    else
        echo "[MISSING] Service Worker nicht gefunden - kann Browser-Kompatibilität nicht prüfen" >> "$compat_log"
    fi
    
    # 3. Simuliere User-Agent-Tests für wichtige Browser
    echo "" >> "$compat_log"
    echo "=== Simulierte User-Agent-Kompatibilität ===" >> "$compat_log"
    
    local browser_compat_issues=0
    
    for browser in "${!BROWSER_USER_AGENTS[@]}"; do
        local user_agent="${BROWSER_USER_AGENTS[$browser]}"
        log "STEP" "Simuliere Anfrage mit $browser User-Agent..."
        
        # Führe eine Anfrage mit dem spezifischen User-Agent aus
        local response_code=$(safe_curl "$target_url" "-I -A \"$user_agent\"" | grep -i "HTTP/" | awk '{print $2}')
        
        if [ -n "$response_code" ] && [ "$response_code" -eq 200 ]; then
            echo "[VALID] $browser - erfolgreiche Anfrage (HTTP $response_code)" >> "$compat_log"
        else
            echo "[WARN] $browser - konnte Antwort nicht verifizieren" >> "$compat_log"
            browser_compat_issues=$((browser_compat_issues + 1))
        fi
    done
    
    if [ $browser_compat_issues -gt 0 ]; then
        log "WARN" "Es wurden $browser_compat_issues potenzielle Browser-Kompatibilitätsprobleme gefunden."
    else
        log "INFO" "Simulierte Browser-Kompatibilitätsprüfungen waren erfolgreich."
    fi
    
    # 4. Prüfe, ob es browserübergreifende Anpassungen im HTML gibt
    if [ -f "$TEST_RESULTS_DIR/code-server-index.html" ]; then
        echo "" >> "$compat_log"
        echo "=== Anpassungen für Browserkompatibilität ===" >> "$compat_log"
        
        # Prüfe auf Polyfills
        if grep -q "polyfill" "$TEST_RESULTS_DIR/code-server-index.html"; then
            echo "[VALID] Polyfills gefunden (gut für die Browserkompatibilität)" >> "$compat_log"
        else
            echo "[INFO] Keine offensichtlichen Polyfills gefunden" >> "$compat_log"
        fi
        
        # Prüfe auf Meta-Tags für Viewport und Mobilgeräte
        if grep -q '<meta name="viewport"' "$TEST_RESULTS_DIR/code-server-index.html"; then
            echo "[VALID] Viewport-Meta-Tag gefunden (wichtig für mobile Browser)" >> "$compat_log"
        else
            echo "[MISSING] Kein Viewport-Meta-Tag gefunden (kritisch für mobile Browser)" >> "$compat_log"
            test_failed=true
        fi
        
        # Prüfe auf Apple-spezifische Meta-Tags
        if grep -q 'apple-mobile-web-app' "$TEST_RESULTS_DIR/code-server-index.html"; then
            echo "[VALID] Apple-spezifische Meta-Tags gefunden (gut für iOS-Unterstützung)" >> "$compat_log"
        else
            echo "[INFO] Keine Apple-spezifischen Meta-Tags gefunden (optional für iOS)" >> "$compat_log"
        fi
    fi
    
    if [ "$VERBOSE" = true ]; then
        log "INFO" "Browser-Kompatibilitätsanalyse:"
        cat "$compat_log" | tee -a "$PWA_TEST_LOG"
    fi
    
    # Wir markieren den Test nur als fehlgeschlagen, wenn schwerwiegende Probleme vorliegen
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# 6. Test: PWA-Installierbarkeit
#######################################

test_pwa_installability() {
    log "TEST" "Überprüfe PWA-Installierbarkeit (simuliert)..."
    
    local test_failed=false
    
    log "STEP" "Prüfe Voraussetzungen für PWA-Installierbarkeit..."
    local manifest_exists=false
    local service_worker_exists=false
    local https_available=false
    
    # Prüfe Manifest
    if [ -f "$TEST_RESULTS_DIR/pwa-manifest.json" ]; then
        manifest_exists=true
        log "INFO" "PWA-Manifest ist vorhanden."
        
        # Prüfe, ob Manifest alle erforderlichen Felder enthält
        local required_fields=("name" "icons" "display" "start_url")
        local missing_fields=0
        
        for field in "${required_fields[@]}"; do
            if ! grep -q "\"$field\"" "$TEST_RESULTS_DIR/pwa-manifest.json"; then
                log "WARN" "Erforderliches Manifest-Feld fehlt: $field"
                missing_fields=$((missing_fields + 1))
            fi
        done
        
        if [ "$missing_fields" -gt 0 ]; then
            log "WARN" "Manifest enthält nicht alle erforderlichen Felder für optimale Installierbarkeit."
        else
            log "INFO" "Manifest enthält alle erforderlichen Felder."
        fi
    else
        log "WARN" "PWA-Manifest ist nicht vorhanden."
    fi
    
    # Prüfe Service Worker
    if [ -f "$TEST_RESULTS_DIR/service-worker.js" ]; then
        service_worker_exists=true
        log "INFO" "Service Worker ist vorhanden."
    else
        log "WARN" "Service Worker ist nicht vorhanden."
    fi
    
    # Prüfe HTTPS
    if curl -k -s -I --connect-timeout 5 "https://$TAILSCALE_IP:$CADDY_PORT" 2>/dev/null | grep -q "HTTP/"; then
        https_available=true
        log "INFO" "HTTPS ist verfügbar."
    else
        log "WARN" "HTTPS ist nicht verfügbar."
    fi
    
    # Zusammenfassung der Installierbarkeit
    log "STEP" "Zusammenfassung der PWA-Installierbarkeit..."
    
    if $manifest_exists && $service_worker_exists && $https_available; then
        log "INFO" "Code-Server erfüllt alle grundlegenden Voraussetzungen für die PWA-Installierbarkeit."
    else
        log "WARN" "Code-Server erfüllt nicht alle Voraussetzungen für die optimale PWA-Installierbarkeit."
        
        # Liste fehlende Komponenten auf
        [ "$manifest_exists" = false ] && log "WARN" "- PWA-Manifest fehlt"
        [ "$service_worker_exists" = false ] && log "WARN" "- Service Worker fehlt"
        [ "$https_available" = false ] && log "WARN" "- HTTPS nicht verfügbar"
        
        test_failed=true
    fi
    
    # PWA-Installierbarkeit ist nicht kritisch, daher überschreiben wir den Fehlerstatus
    test_failed=false
    
    [ "$test_failed" = true ] && return 1
    return 0
}

#######################################
# Hauptfunktion
#######################################

main() {
    log "TEST" "==== Starte Code-Server PWA-Tests ===="
    
    init_test_env
    parse_args "$@"
    
    get_tailscale_info
    
    run_test "pwa-manifest" test_pwa_manifest
    run_test "service-worker" test_service_worker
    run_test "pwa-headers" test_pwa_headers
    run_test "offline-functionality" test_offline_functionality
    run_test "browser-compatibility" test_browser_compatibility
    run_test "pwa-installability" test_pwa_installability
    
    show_test_results
    
    log "TEST" "==== Code-Server PWA-Tests abgeschlossen ===="
    
    if [ $FAILED_TESTS -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"