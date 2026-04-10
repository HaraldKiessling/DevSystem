#!/usr/bin/env bash
#
# QS-VPS Master Orchestrator
# Vollautomatisches Deployment aller Komponenten mit Orchestrierung
#
# Zweck:
#   Zentrale Steuerung aller QS-Deployment-Scripts mit:
#   - Dependency-Management
#   - Lock-Mechanismus
#   - Progress-Tracking
#   - Error-Recovery & Rollback
#   - Environment-Validation
#   - Deployment-Reports
#
# Verwendung:
#   sudo bash scripts/qs/setup-qs-master.sh [OPTIONS]
#
# Optionen:
#   --force                Ignoriere Lock, Force Redeployment
#   --skip-checks         Überspringe Environment-Validation
#   --component=NAME      Nur ein bestimmtes Script ausführen
#   --dry-run             Simuliere Deployment ohne Änderungen
#   --rollback            Stelle vorherigen Zustand wieder her
#   --resume              Setze unterbrochenes Deployment fort
#   --help                Diese Hilfe anzeigen
#

set -euo pipefail

# ============================================================================
# GLOBALE KONFIGURATION
# ============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly VERSION="1.0.0"

# Lock und State
readonly LOCK_FILE="/var/lock/qs-deployment.lock"
readonly LOCK_TIMEOUT=7200  # 2 Stunden
readonly STATE_FILE="/var/lib/qs-deployment/master-deployment"
readonly LOG_DIR="/var/log/qs-deployment"
readonly LOG_FILE="${LOG_DIR}/master-orchestrator.log"

# Reports
readonly REPORT_DIR="/var/log/qs-deployment"
readonly REPORT_PREFIX="deployment-report"

# Farben für Terminal-Output
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_MAGENTA='\033[0;35m'
readonly COLOR_BOLD='\033[1m'
readonly COLOR_RESET='\033[0m'

# Exit-Codes
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1
readonly EXIT_PARTIAL=2
readonly EXIT_LOCKED=3

# Komponenten in Deploy-Reihenfolge (ID:Description:Script:Dependencies)
declare -a COMPONENTS=(
    "install-caddy:Caddy installieren:${SCRIPT_DIR}/install-caddy-qs.sh:"
    "configure-caddy:Caddy konfigurieren:${SCRIPT_DIR}/configure-caddy-qs.sh:install-caddy"
    "install-code-server:code-server installieren:${SCRIPT_DIR}/install-code-server-qs.sh:"
    "configure-code-server:code-server konfigurieren:${SCRIPT_DIR}/configure-code-server-qs.sh:install-code-server"
    "deploy-qdrant:Qdrant deployen:${SCRIPT_DIR}/deploy-qdrant-qs.sh:"
)

# Globale Variablen
FORCE_MODE=false
SKIP_CHECKS=false
COMPONENT_FILTER=""
DRY_RUN=false
ROLLBACK_MODE=false
RESUME_MODE=false
START_TIME=""
DEPLOYMENT_ID=""

# Zähler
TOTAL_COMPONENTS=0
SUCCESSFUL_COMPONENTS=0
FAILED_COMPONENTS=0
SKIPPED_COMPONENTS=0

# ============================================================================
# IDEMPOTENZ-LIBRARY LADEN
# ============================================================================

if [ ! -f "${SCRIPT_DIR}/lib/idempotency.sh" ]; then
    echo "❌ FEHLER: Idempotenz-Library nicht gefunden: ${SCRIPT_DIR}/lib/idempotency.sh"
    exit $EXIT_ERROR
fi

source "${SCRIPT_DIR}/lib/idempotency.sh"

# ============================================================================
# LOGGING-FUNKTIONEN
# ============================================================================

# Logging mit Level und Farbe
log() {
    local level=$1
    shift
    local message="$*"
    local color=$COLOR_RESET
    local symbol=""
    
    case $level in
        SUCCESS) color=$COLOR_GREEN; symbol="✅" ;;
        ERROR)   color=$COLOR_RED; symbol="❌" ;;
        WARNING) color=$COLOR_YELLOW; symbol="⚠️ " ;;
        INFO)    color=$COLOR_BLUE; symbol="ℹ️ " ;;
        DEBUG)   color=$COLOR_CYAN; symbol="🔍" ;;
        PROGRESS) color=$COLOR_MAGENTA; symbol="⏳" ;;
        *)       color=$COLOR_RESET; symbol="  " ;;
    esac
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_line="[${timestamp}] [${level}] ${message}"
    local display_line="${color}[${timestamp}] ${symbol} ${message}${COLOR_RESET}"
    
    # Terminal-Ausgabe
    echo -e "$display_line"
    
    # Log-Datei (ohne Farben)
    echo "$log_line" >> "$LOG_FILE" 2>/dev/null || true
}

# ============================================================================
# LOCK-MECHANISMUS
# ============================================================================

# Lock erwerben mit Stale-Detection
acquire_lock() {
    log "INFO" "Versuche Lock zu erwerben..."
    
    if [ -f "$LOCK_FILE" ]; then
        local lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "unknown")
        local lock_time=$(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo "0")
        local current_time=$(date +%s)
        local lock_age=$((current_time - lock_time))
        
        # Prüfe ob Prozess noch läuft
        if [ "$lock_pid" != "unknown" ] && kill -0 "$lock_pid" 2>/dev/null; then
            # Lock ist aktiv
            if [ "$FORCE_MODE" = true ]; then
                log "WARNING" "Force-Mode: Überschreibe aktiven Lock (PID: $lock_pid)"
                rm -f "$LOCK_FILE"
            else
                log "ERROR" "Deployment läuft bereits (PID: $lock_pid)"
                log "INFO" "Verwende --force zum Überschreiben oder warte bis Deployment abgeschlossen ist"
                return $EXIT_LOCKED
            fi
        else
            # Stale Lock - prüfe Alter
            if [ $lock_age -gt $LOCK_TIMEOUT ]; then
                log "WARNING" "Stale Lock entfernt (Alter: ${lock_age}s, Timeout: ${LOCK_TIMEOUT}s)"
                rm -f "$LOCK_FILE"
            else
                log "ERROR" "Lock-File existiert, Prozess läuft nicht (PID: $lock_pid)"
                if [ "$FORCE_MODE" = true ]; then
                    log "WARNING" "Force-Mode: Entferne Lock"
                    rm -f "$LOCK_FILE"
                else
                    log "INFO" "Verwende --force zum Überschreiben"
                    return $EXIT_LOCKED
                fi
            fi
        fi
    fi
    
    # Lock erstellen
    echo $$ > "$LOCK_FILE"
    echo "$START_TIME" >> "$LOCK_FILE"
    
    log "SUCCESS" "Lock erworben (PID: $$)"
    return 0
}

# Lock freigeben
release_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local lock_pid=$(head -n1 "$LOCK_FILE" 2>/dev/null || echo "unknown")
        if [ "$lock_pid" = "$$" ]; then
            rm -f "$LOCK_FILE"
            log "SUCCESS" "Lock freigegeben"
        else
            log "WARNING" "Lock gehört zu anderem Prozess (PID: $lock_pid)"
        fi
    fi
}

# ============================================================================
# ENVIRONMENT-VALIDATION
# ============================================================================

validate_environment() {
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "INFO" "Environment-Validation"
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local errors=0
    
    # 1. OS-Check
    log "INFO" "Prüfe Betriebssystem..."
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        if [[ "$ID" == "ubuntu" ]] || [[ "$ID_LIKE" == *"ubuntu"* ]] || [[ "$ID_LIKE" == *"debian"* ]]; then
            log "SUCCESS" "OS: $PRETTY_NAME"
        else
            log "WARNING" "Nicht-Ubuntu-System erkannt: $PRETTY_NAME"
            log "WARNING" "Scripts sind für Ubuntu optimiert, fortfahren auf eigene Gefahr"
        fi
    else
        log "ERROR" "/etc/os-release nicht gefunden"
        ((errors++))
    fi
    
    # 2. Root-Rechte
    log "INFO" "Prüfe Root-Rechte..."
    if [ "$(id -u)" -eq 0 ]; then
        log "SUCCESS" "Root-Rechte vorhanden"
    else
        log "ERROR" "Script benötigt Root-Rechte (sudo)"
        ((errors++))
    fi
    
    # 3. Disk-Space
    log "INFO" "Prüfe Speicherplatz..."
    local available_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_space" -gt 5 ]; then
        log "SUCCESS" "Verfügbarer Speicherplatz: ${available_space}GB"
    else
        log "WARNING" "Wenig Speicherplatz: ${available_space}GB (empfohlen: >5GB)"
    fi
    
    # 4. RAM
    log "INFO" "Prüfe RAM..."
    local total_ram=$(free -g | awk 'NR==2 {print $2}')
    if [ "$total_ram" -ge 2 ]; then
        log "SUCCESS" "RAM: ${total_ram}GB"
    else
        log "WARNING" "Wenig RAM: ${total_ram}GB (empfohlen: >=2GB)"
    fi
    
    # 5. Internet-Verbindung
    log "INFO" "Prüfe Internet-Verbindung..."
    if ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
        log "SUCCESS" "Internet-Verbindung OK"
    else
        log "ERROR" "Keine Internet-Verbindung"
        ((errors++))
    fi
    
    # 6. DNS-Resolution
    log "INFO" "Prüfe DNS-Resolution..."
    if nslookup github.com &>/dev/null; then
        log "SUCCESS" "DNS-Resolution OK"
    else
        log "WARNING" "DNS-Resolution fehlgeschlagen"
    fi
    
    # 7. Tailscale-IP
    log "INFO" "Prüfe Tailscale-IP..."
    if command -v tailscale &>/dev/null; then
        local ts_ip=$(tailscale ip -4 2>/dev/null | head -n1)
        if [ -n "$ts_ip" ]; then
            log "SUCCESS" "Tailscale-IP: $ts_ip"
            export QS_TAILSCALE_IP="$ts_ip"
        else
            log "WARNING" "Tailscale installiert, aber keine IP"
        fi
    else
        log "WARNING" "Tailscale nicht installiert"
    fi
    
    # 8. Verzeichnisse und Berechtigungen
    log "INFO" "Prüfe Verzeichnisse..."
    mkdir -p /var/lib/qs-deployment/{markers,state} /var/log/qs-deployment /var/lock/qs-deployment 2>/dev/null || {
        log "ERROR" "Kann Deployment-Verzeichnisse nicht erstellen"
        ((errors++))
    }
    
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ $errors -gt 0 ]; then
        log "ERROR" "Environment-Validation fehlgeschlagen ($errors Fehler)"
        return 1
    else
        log "SUCCESS" "Environment-Validation erfolgreich"
        return 0
    fi
}

# ============================================================================
# DEPENDENCY-CHECK
# ============================================================================

check_dependencies() {
    local component_id=$1
    local dependencies=$2
    
    if [ -z "$dependencies" ]; then
        return 0
    fi
    
    IFS=',' read -ra deps <<< "$dependencies"
    for dep in "${deps[@]}"; do
        if ! marker_exists "${dep}"; then
            log "ERROR" "Dependency nicht erfüllt: $dep muss vor $component_id ausgeführt werden"
            return 1
        fi
    done
    
    return 0
}

# ============================================================================
# COMPONENT-RUNNER
# ============================================================================

run_component() {
    local component_info=$1
    IFS=':' read -r comp_id comp_desc comp_script comp_deps <<< "$component_info"
    
    ((TOTAL_COMPONENTS++))
    
    log "INFO" ""
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "PROGRESS" "Component: $comp_desc ($comp_id)"
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Component-Filter prüfen
    if [ -n "$COMPONENT_FILTER" ] && [ "$COMPONENT_FILTER" != "$comp_id" ]; then
        log "INFO" "Überspringe (nicht im Filter)"
        ((SKIPPED_COMPONENTS++))
        return 0
    fi
    
    # Dependencies prüfen
    if ! check_dependencies "$comp_id" "$comp_deps"; then
        log "ERROR" "Dependency-Check fehlgeschlagen"
        ((FAILED_COMPONENTS++))
        return 1
    fi
    
    # Prüfe ob bereits deployed (außer im Force-Mode)
    if marker_exists "$comp_id" && [ "$FORCE_MODE" = false ]; then
        log "INFO" "Component bereits deployed - überspringe"
        ((SKIPPED_COMPONENTS++))
        return 0
    fi
    
    # Dry-Run-Mode
    if [ "$DRY_RUN" = true ]; then
        log "INFO" "[DRY-RUN] Würde ausführen: $comp_script"
        # Setze Marker auch im Dry-Run für Dependency-Chain-Simulation
        set_marker "$comp_id" "[DRY-RUN] $comp_desc"
        ((SKIPPED_COMPONENTS++))
        return 0
    fi
    
    # Script existiert?
    if [ ! -f "$comp_script" ]; then
        log "ERROR" "Script nicht gefunden: $comp_script"
        ((FAILED_COMPONENTS++))
        return 1
    fi
    
    # Script ausführen
    local start_time=$(date +%s)
    log "PROGRESS" "Starte Deployment..."
    
    # Exportiere QS_TAILSCALE_IP explizit für Sub-Scripts (IMMER, auch wenn leer)
    export QS_TAILSCALE_IP="${QS_TAILSCALE_IP:-}"
    
    if bash "$comp_script" >> "$LOG_FILE" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log "SUCCESS" "Component erfolgreich deployed (${duration}s)"
        save_state "master" "component_${comp_id}_status" "success"
        save_state "master" "component_${comp_id}_duration" "$duration"
        save_state "master" "component_${comp_id}_timestamp" "$(date -Iseconds)"
        
        # Setze Top-Level-Marker für Dependency-Checks
        set_marker "$comp_id" "$comp_desc"
        
        ((SUCCESSFUL_COMPONENTS++))
        return 0
    else
        local exit_code=$?
        log "ERROR" "Component fehlgeschlagen (Exit Code: $exit_code)"
        save_state "master" "component_${comp_id}_status" "failed"
        save_state "master" "component_${comp_id}_error_code" "$exit_code"
        
        ((FAILED_COMPONENTS++))
        return 1
    fi
}

# ============================================================================
# PROGRESS-TRACKING
# ============================================================================

show_progress() {
    local completed=$1
    local total=$2
    local percentage=$((completed * 100 / total))
    local bar_length=40
    local filled=$((percentage * bar_length / 100))
    
    printf "\r${COLOR_CYAN}Progress: [${COLOR_RESET}"
    
    for ((i=0; i<bar_length; i++)); do
        if [ $i -lt $filled ]; then
            printf "${COLOR_GREEN}█${COLOR_RESET}"
        else
            printf "░"
        fi
    done
    
    printf "] ${percentage}%% (${completed}/${total})${COLOR_RESET}"
}

# ============================================================================
# ROLLBACK-FUNKTION
# ============================================================================

rollback_deployment() {
    log "WARNING" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "WARNING" "ROLLBACK-MODUS"
    log "WARNING" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    log "INFO" "Stelle vorherigen Zustand wieder her..."
    
    # Backup-Verzeichnis finden
    local backup_dir=$(find /var/backups/qs-deployment -type d -name "20*" | sort -r | head -n1)
    
    if [ -z "$backup_dir" ]; then
        log "ERROR" "Kein Backup gefunden"
        return 1
    fi
    
    log "INFO" "Verwende Backup: $backup_dir"
    
    # Configs wiederherstellen
    local rollback_count=0
    while IFS= read -r backup_file; do
        local file_name=$(basename "$backup_file")
        local restore_target=""
        
        # Ziel-Pfad bestimmen
        case $file_name in
            Caddyfile) restore_target="/etc/caddy/Caddyfile" ;;
            config.yaml) restore_target="/home/codeserver-qs/.config/code-server/config.yaml" ;;
            *.service) restore_target="/etc/systemd/system/$file_name" ;;
        esac
        
        if [ -n "$restore_target" ] && [ -f "$backup_file" ]; then
            cp -a "$backup_file" "$restore_target"
            log "SUCCESS" "Wiederhergestellt: $file_name"
            ((rollback_count++))
        fi
    done < <(find "$backup_dir" -type f)
    
    # Services neu laden
    systemctl daemon-reload
    
    log "SUCCESS" "Rollback abgeschlossen: $rollback_count Dateien wiederhergestellt"
    return 0
}

# ============================================================================
# RESUME-FUNKTION
# ============================================================================

resume_deployment() {
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "INFO" "RESUME-MODUS"
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    log "INFO" "Ermittle letzten erfolgreichen Component..."
    
    local last_successful=""
    for comp_info in "${COMPONENTS[@]}"; do
        IFS=':' read -r comp_id _ _ _ <<< "$comp_info"
        if marker_exists "$comp_id"; then
            last_successful="$comp_id"
        else
            break
        fi
    done
    
    if [ -z "$last_successful" ]; then
        log "INFO" "Kein vorheriges Deployment gefunden - starte von Anfang"
        return 0
    fi
    
    log "INFO" "Letzter erfolgreicher Component: $last_successful"
    log "INFO" "Fortsetzen mit nächstem Component..."
    
    return 0
}

# ============================================================================
# REPORT-GENERATOR
# ============================================================================

generate_report() {
    local exit_status=$1
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local timestamp=$(date '+%Y%m%d-%H%M%S')
    
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "INFO" "Erstelle Deployment-Report..."
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Terminal-Report
    generate_terminal_report "$exit_status" "$duration"
    
    # Markdown-Report
    local markdown_file="${REPORT_DIR}/${REPORT_PREFIX}-${timestamp}.md"
    generate_markdown_report "$exit_status" "$duration" > "$markdown_file"
    log "SUCCESS" "Markdown-Report: $markdown_file"
    
    # JSON-Report
    local json_file="${REPORT_DIR}/${REPORT_PREFIX}-${timestamp}.json"
    generate_json_report "$exit_status" "$duration" > "$json_file"
    log "SUCCESS" "JSON-Report: $json_file"
    
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

generate_terminal_report() {
    local exit_status=$1
    local duration=$2
    
    echo ""
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "INFO" "${COLOR_BOLD}DEPLOYMENT SUMMARY${COLOR_RESET}"
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Status
    if [ $exit_status -eq $EXIT_SUCCESS ]; then
        log "SUCCESS" "Status: SUCCESS"
    elif [ $exit_status -eq $EXIT_PARTIAL ]; then
        log "WARNING" "Status: PARTIAL SUCCESS"
    else
        log "ERROR" "Status: FAILED"
    fi
    
    # Metriken
    echo ""
    log "INFO" "Komponenten:"
    log "SUCCESS" "  Erfolgreich: $SUCCESSFUL_COMPONENTS"
    log "ERROR" "  Fehlgeschlagen: $FAILED_COMPONENTS"
    log "INFO" "  Übersprungen: $SKIPPED_COMPONENTS"
    log "INFO" "  Gesamt: $TOTAL_COMPONENTS"
    
    echo ""
    log "INFO" "Zeit:"
    log "INFO" "  Start: $(date -d @$START_TIME '+%Y-%m-%d %H:%M:%S')"
    log "INFO" "  Ende: $(date '+%Y-%m-%d %H:%M:%S')"
    log "INFO" "  Dauer: ${duration}s ($((duration / 60)) Minuten)"
    
    # Service-Status
    echo ""
    log "INFO" "Service-Status:"
    for service in caddy code-server@codeserver-qs qdrant-qs; do
        if systemctl is-active "$service" &>/dev/null; then
            log "SUCCESS" "  $service: active"
        else
            log "WARNING" "  $service: inactive"
        fi
    done
    
    # Zugriff
    if [ -n "${QS_TAILSCALE_IP:-}" ]; then
        echo ""
        log "INFO" "Zugriff:"
        log "INFO" "  HTTPS-URL: https://${QS_TAILSCALE_IP}:9443"
    fi
    
    echo ""
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

generate_markdown_report() {
    local exit_status=$1
    local duration=$2
    
    cat << EOF
# QS-VPS Deployment Report

**Deployment-ID:** ${DEPLOYMENT_ID}  
**Datum:** $(date -Iseconds)  
**Hostname:** $(hostname)  
**Tailscale-IP:** ${QS_TAILSCALE_IP:-N/A}  
**Force-Mode:** ${FORCE_MODE}  
**Dauer:** ${duration}s

## Status

EOF

    if [ $exit_status -eq $EXIT_SUCCESS ]; then
        echo "✅ **SUCCESS** - Alle Komponenten erfolgreich deployed"
    elif [ $exit_status -eq $EXIT_PARTIAL ]; then
        echo "⚠️ **PARTIAL** - Einige Komponenten fehlgeschlagen"
    else
        echo "❌ **FAILED** - Deployment fehlgeschlagen"
    fi

    cat << EOF

## System-Informationen

- **OS:** $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
- **Kernel:** $(uname -r)
- **Uptime:** $(uptime -p)
- **RAM:** $(free -h | awk 'NR==2 {print $2}')
- **Disk:** $(df -h / | awk 'NR==2 {print $4}') verfügbar

## Komponenten-Status

| Komponente | Status | Dauer | Timestamp |
|------------|--------|-------|-----------|
EOF

    for comp_info in "${COMPONENTS[@]}"; do
        IFS=':' read -r comp_id comp_desc _ _ <<< "$comp_info"
        local status=$(get_state "master" "component_${comp_id}_status")
        local duration=$(get_state "master" "component_${comp_id}_duration")
        local timestamp=$(get_state "master" "component_${comp_id}_timestamp")
        
        if [ "$status" = "success" ]; then
            echo "| $comp_desc | ✅ Success | ${duration:-0}s | ${timestamp:-N/A} |"
        elif [ "$status" = "failed" ]; then
            echo "| $comp_desc | ❌ Failed | N/A | N/A |"
        else
            echo "| $comp_desc | ⏭️ Skipped | N/A | N/A |"
        fi
    done

    cat << EOF

## Service-Health

| Service | Status | Ports |
|---------|--------|-------|
| Caddy | $(systemctl is-active caddy 2>/dev/null || echo "inactive") | 9443 |
| code-server | $(systemctl is-active code-server@codeserver-qs 2>/dev/null || echo "inactive") | 8080 |
| Qdrant | $(systemctl is-active qdrant-qs 2>/dev/null || echo "inactive") | 6333, 6334 |

## Idempotenz-State

**Marker:**
\`\`\`
$(list_markers | wc -l) Marker gesetzt
\`\`\`

**State-Files:**
\`\`\`
$(find /var/lib/qs-deployment/state -type f 2>/dev/null | wc -l) State-Files vorhanden
\`\`\`

## Zugriff

- **HTTPS-URL:** https://${QS_TAILSCALE_IP:-<tailscale-ip>}:9443
- **code-server Passwort:** Siehe \`~/.config/code-server/config.yaml\`

## Logs

- **Master-Log:** \`$LOG_FILE\`
- **Component-Logs:** \`$LOG_DIR/\`

---

**Report erstellt:** $(date)  
**Version:** $VERSION
EOF
}

generate_json_report() {
    local exit_status=$1
    local duration=$2
    
    # Status-String
    local status_str="failed"
    if [ $exit_status -eq $EXIT_SUCCESS ]; then
        status_str="success"
    elif [ $exit_status -eq $EXIT_PARTIAL ]; then
        status_str="partial"
    fi
    
    cat << EOF
{
  "deployment_id": "${DEPLOYMENT_ID}",
  "timestamp": "$(date -Iseconds)",
  "hostname": "$(hostname)",
  "tailscale_ip": "${QS_TAILSCALE_IP:-null}",
  "version": "$VERSION",
  "duration_seconds": $duration,
  "status": "$status_str",
  "exit_code": $exit_status,
  "force_mode": $FORCE_MODE,
  "dry_run": $DRY_RUN,
  "metrics": {
    "total_components": $TOTAL_COMPONENTS,
    "successful": $SUCCESSFUL_COMPONENTS,
    "failed": $FAILED_COMPONENTS,
    "skipped": $SKIPPED_COMPONENTS
  },
  "components": [
EOF

    local first=true
    for comp_info in "${COMPONENTS[@]}"; do
        IFS=':' read -r comp_id comp_desc _ _ <<< "$comp_info"
        local comp_status=$(get_state "master" "component_${comp_id}_status")
        local comp_duration=$(get_state "master" "component_${comp_id}_duration")
        local comp_timestamp=$(get_state "master" "component_${comp_id}_timestamp")
        
        if [ "$first" = false ]; then
            echo ","
        fi
        first=false
        
        cat << COMP
    {
      "id": "$comp_id",
      "description": "$comp_desc",
      "status": "${comp_status:-unknown}",
      "duration": ${comp_duration:-0},
      "timestamp": "${comp_timestamp:-null}"
    }
COMP
    done

    cat << EOF

  ],
  "services": {
    "caddy": "$(systemctl is-active caddy 2>/dev/null || echo "inactive")",
    "code_server": "$(systemctl is-active code-server@codeserver-qs 2>/dev/null || echo "inactive")",
    "qdrant": "$(systemctl is-active qdrant-qs 2>/dev/null || echo "inactive")"
  },
  "system": {
    "os": "$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)",
    "kernel": "$(uname -r)",
    "uptime": "$(uptime -p)"
  }
}
EOF
}

# ============================================================================
# ERROR-HANDLER
# ============================================================================

handle_error() {
    local exit_code=$?
    local line_no=$1
    
    log "ERROR" "Fehler in Zeile $line_no (Exit Code: $exit_code)"
    release_lock
    
    # Report auch bei Fehler
    generate_report $EXIT_ERROR
    
    exit $exit_code
}

# ============================================================================
# ARGUMENT-PARSING
# ============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE_MODE=true
                export FORCE_REDEPLOY=true
                log "WARNING" "Force-Mode aktiviert"
                shift
                ;;
            --skip-checks)
                SKIP_CHECKS=true
                log "WARNING" "Environment-Checks werden übersprungen"
                shift
                ;;
            --component=*)
                COMPONENT_FILTER="${1#*=}"
                log "INFO" "Component-Filter: $COMPONENT_FILTER"
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                log "INFO" "Dry-Run-Modus aktiviert"
                shift
                ;;
            --rollback)
                ROLLBACK_MODE=true
                log "WARNING" "Rollback-Modus aktiviert"
                shift
                ;;
            --resume)
                RESUME_MODE=true
                log "INFO" "Resume-Modus aktiviert"
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log "ERROR" "Unbekannte Option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
${COLOR_BOLD}QS-VPS Master Orchestrator${COLOR_RESET}
Version: $VERSION

${COLOR_BOLD}Verwendung:${COLOR_RESET}
  sudo bash $SCRIPT_NAME [OPTIONEN]

${COLOR_BOLD}Optionen:${COLOR_RESET}
  --force              Ignoriere Lock, erzwinge Redeployment
  --skip-checks        Überspringe Environment-Validation
  --component=NAME     Nur ein bestimmtes Component deployen
  --dry-run            Simuliere Deployment ohne Änderungen
  --rollback           Stelle vorherigen Zustand wieder her
  --resume             Setze unterbrochenes Deployment fort
  --help               Diese Hilfe anzeigen

${COLOR_BOLD}Komponenten:${COLOR_RESET}
EOF

    for comp_info in "${COMPONENTS[@]}"; do
        IFS=':' read -r comp_id comp_desc _ _ <<< "$comp_info"
        echo "  - $comp_id: $comp_desc"
    done

    cat << EOF

${COLOR_BOLD}Beispiele:${COLOR_RESET}
  # Vollständiges Deployment
  sudo bash $SCRIPT_NAME

  # Nur Caddy deployen
  sudo bash $SCRIPT_NAME --component=install-caddy

  # Force-Redeploy
  sudo bash $SCRIPT_NAME --force

  # Dry-Run (Simulation)
  sudo bash $SCRIPT_NAME --dry-run

  # Rollback
  sudo bash $SCRIPT_NAME --rollback

${COLOR_BOLD}Exit-Codes:${COLOR_RESET}
  0 - Success
  1 - Error
  2 - Partial Success
  3 - Locked (Deployment läuft bereits)

${COLOR_BOLD}Logs & Reports:${COLOR_RESET}
  - Log-File: $LOG_FILE
  - Reports: $REPORT_DIR/

EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    # Initialisierung
    START_TIME=$(date +%s)
    DEPLOYMENT_ID="deploy-$(date +%Y%m%d-%H%M%S)-$$"
    
    mkdir -p "$LOG_DIR" "$REPORT_DIR" 2>/dev/null || true
    
    # Banner
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║      QS-VPS Master Orchestrator - DevSystem Quality         ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    
    log "INFO" "Deployment-ID: $DEPLOYMENT_ID"
    log "INFO" "Version: $VERSION"
    log "INFO" "Start: $(date)"
    echo ""
    
    # Argumente parsen
    parse_arguments "$@"
    
    # Rollback-Mode
    if [ "$ROLLBACK_MODE" = true ]; then
        rollback_deployment
        exit $?
    fi
    
    # Resume-Mode
    if [ "$RESUME_MODE" = true ]; then
        resume_deployment
    fi
    
    # Environment-Validation (außer bei --skip-checks)
    if [ "$SKIP_CHECKS" = false ]; then
        if ! validate_environment; then
            log "ERROR" "Environment-Validation fehlgeschlagen"
            log "INFO" "Verwende --skip-checks zum Überspringen (nicht empfohlen)"
            exit $EXIT_ERROR
        fi
        echo ""
    fi
    
    # Lock erwerben
    if ! acquire_lock; then
        exit $EXIT_LOCKED
    fi
    
    echo ""
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "INFO" "${COLOR_BOLD}DEPLOYMENT START${COLOR_RESET}"
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Komponenten deployen
    local deployment_failed=false
    for comp_info in "${COMPONENTS[@]}"; do
        if ! run_component "$comp_info"; then
            deployment_failed=true
            log "ERROR" "Component fehlgeschlagen - breche Deployment ab"
            break
        fi
    done
    
    echo ""
    
    # Exit-Status bestimmen
    local exit_status=$EXIT_SUCCESS
    if [ "$deployment_failed" = true ]; then
        exit_status=$EXIT_ERROR
    elif [ $FAILED_COMPONENTS -gt 0 ]; then
        exit_status=$EXIT_PARTIAL
    fi
    
    # Report generieren
    generate_report $exit_status
    
    # Lock freigeben
    release_lock
    
    # Finale Ausgabe
    echo ""
    if [ $exit_status -eq $EXIT_SUCCESS ]; then
        log "SUCCESS" "🎉 Deployment erfolgreich abgeschlossen!"
    elif [ $exit_status -eq $EXIT_PARTIAL ]; then
        log "WARNING" "⚠️  Deployment teilweise erfolgreich"
    else
        log "ERROR" "❌ Deployment fehlgeschlagen"
    fi
    
    exit $exit_status
}

# Trap für Error-Handling
trap 'handle_error $LINENO' ERR
trap 'release_lock' EXIT INT TERM

# Script ausführen
main "$@"
