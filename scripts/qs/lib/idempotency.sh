#!/bin/bash
#
# Idempotency Library für QS-Scripts
# 
# Zweck:
#   Wiederverwendbare Funktionen für idempotente Script-Ausführung
#   Marker-basiertes System zur Vermeidung von Doppel-Ausführungen
#
# Verwendung:
#   source scripts/qs/lib/idempotency.sh
#
# Funktionen:
#   - marker_exists(name)         Prüft ob Marker existiert
#   - set_marker(name, metadata)  Setzt Marker mit Metadaten
#   - clear_marker(name)          Löscht einzelnen Marker
#   - clear_all_markers()         Löscht alle Marker
#   - save_state(component, key, value)  Speichert State
#   - get_state(component, key)   Liest State
#   - run_idempotent(name, desc, cmd...)  Führt Command idempotent aus
#

set -euo pipefail

# ============================================================================
# KONFIGURATION
# ============================================================================

# Verzeichnisse für Marker und State
readonly MARKER_DIR="/var/lib/qs-deployment/markers"
readonly STATE_DIR="/var/lib/qs-deployment/state"
readonly LOCK_DIR="/var/lock/qs-deployment"

# ============================================================================
# FARBEN - Zentralisierte Definition für alle QS-Scripts
# ============================================================================

# Standard-Farben (kompatibel mit allen Terminals)
# Nur definieren wenn noch nicht gesetzt (für Re-Sourcing)
if [ -z "${RED:-}" ]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly CYAN='\033[0;36m'
    readonly MAGENTA='\033[0;35m'
    readonly WHITE='\033[1;37m'
    readonly BOLD='\033[1m'
    readonly NC='\033[0m'  # No Color / Reset
    
    # Aliases für Backward-Compatibility
    readonly LIB_GREEN="$GREEN"
    readonly LIB_RED="$RED"
    readonly LIB_YELLOW="$YELLOW"
    readonly LIB_BLUE="$BLUE"
    readonly LIB_CYAN="$CYAN"
    readonly LIB_NC="$NC"
    
    # Alternative Namen (für setup-qs-master.sh Kompatibilität)
    readonly COLOR_GREEN="$GREEN"
    readonly COLOR_RED="$RED"
    readonly COLOR_YELLOW="$YELLOW"
    readonly COLOR_BLUE="$BLUE"
    readonly COLOR_CYAN="$CYAN"
    readonly COLOR_MAGENTA="$MAGENTA"
    readonly COLOR_BOLD="$BOLD"
    readonly COLOR_RESET="$NC"
    readonly RESET="$NC"
fi

# ============================================================================
# MARKER-FUNKTIONEN
# ============================================================================

# Prüft ob ein Marker existiert
# Usage: marker_exists "marker-name"
# Returns: 0 wenn Marker existiert, 1 wenn nicht
marker_exists() {
    local marker_name=$1
    [ -f "${MARKER_DIR}/${marker_name}.complete" ]
}

# Setzt einen Marker mit Metadaten
# Usage: set_marker "marker-name" "optional metadata"
set_marker() {
    local marker_name=$1
    local metadata=${2:-""}
    
    mkdir -p "$MARKER_DIR"
    
    cat > "${MARKER_DIR}/${marker_name}.complete" << EOF
timestamp: $(date -Iseconds)
hostname: $(hostname)
user: $(whoami)
pid: $$
metadata: $metadata
EOF
    
    return 0
}

# Löscht einen einzelnen Marker
# Usage: clear_marker "marker-name"
clear_marker() {
    local marker_name=$1
    rm -f "${MARKER_DIR}/${marker_name}.complete"
    return 0
}

# Löscht alle Marker (für Force-Redeploy)
# Usage: clear_all_markers
clear_all_markers() {
    if [ -d "$MARKER_DIR" ]; then
        rm -rf "$MARKER_DIR"
    fi
    mkdir -p "$MARKER_DIR"
    echo "$(date -Iseconds): All markers cleared" > "${MARKER_DIR}/.cleared"
    return 0
}

# Liste alle vorhandenen Marker
# Usage: list_markers
list_markers() {
    if [ -d "$MARKER_DIR" ]; then
        find "$MARKER_DIR" -name "*.complete" -type f -exec basename {} .complete \;
    fi
}

# ============================================================================
# STATE-MANAGEMENT-FUNKTIONEN
# ============================================================================

# Speichert einen State-Wert
# Usage: save_state "component" "key" "value"
save_state() {
    local component=$1
    local key=$2
    local value=$3
    
    mkdir -p "$STATE_DIR"
    local state_file="${STATE_DIR}/${component}.state"
    
    # Atomisches Schreiben via Temp-File
    local temp_file="${state_file}.tmp.$$"
    
    # Bestehende Einträge kopieren (außer der zu aktualisierenden Key)
    if [ -f "$state_file" ]; then
        grep -v "^${key}=" "$state_file" > "$temp_file" 2>/dev/null || true
    fi
    
    # Neuen Eintrag hinzufügen
    echo "${key}=${value}" >> "$temp_file"
    
    # Atomisch verschieben
    mv "$temp_file" "$state_file"
    
    return 0
}

# Liest einen State-Wert
# Usage: get_state "component" "key"
# Returns: State-Value oder leerer String
get_state() {
    local component=$1
    local key=$2
    local state_file="${STATE_DIR}/${component}.state"
    
    if [ -f "$state_file" ]; then
        grep "^${key}=" "$state_file" 2>/dev/null | cut -d'=' -f2- | tail -n1
    fi
}

# Löscht alle States für eine Komponente
# Usage: clear_state "component"
clear_state() {
    local component=$1
    rm -f "${STATE_DIR}/${component}.state"
    return 0
}

# Liste alle States für eine Komponente
# Usage: list_state "component"
list_state() {
    local component=$1
    local state_file="${STATE_DIR}/${component}.state"
    
    if [ -f "$state_file" ]; then
        cat "$state_file"
    fi
}

# ============================================================================
# IDEMPOTENZ-WRAPPER
# ============================================================================

# Führt einen Command idempotent aus
# Usage: run_idempotent "marker-name" "description" command [args...]
# Returns: 0 bei Erfolg, 1 bei Fehler
run_idempotent() {
    local marker_name=$1
    local description=$2
    shift 2
    local command=("$@")
    
    # Prüfe ob bereits ausgeführt
    if marker_exists "$marker_name" && [ "${FORCE_REDEPLOY:-false}" != "true" ]; then
        echo -e "${CYAN}⏭️  Überspringe:${NC} $description (bereits abgeschlossen)"
        return 0
    fi
    
    echo -e "${BLUE}🔄 Führe aus:${NC} $description"
    
    # Command ausführen
    if "${command[@]}"; then
        set_marker "$marker_name" "$description"
        echo -e "${GREEN}✅ Abgeschlossen:${NC} $description"
        return 0
    else
        local exit_code=$?
        echo -e "${RED}❌ Fehlgeschlagen:${NC} $description (Exit Code: $exit_code)"
        return 1
    fi
}

# ============================================================================
# LOCK-FUNKTIONEN (für gegenseitigen Ausschluss)
# ============================================================================

# Erwirbt einen Lock
# Usage: acquire_lock "lock-name"
# Returns: 0 bei Erfolg, 1 wenn Lock bereits existiert
acquire_lock() {
    local lock_name=$1
    local lock_file="${LOCK_DIR}/${lock_name}.lock"
    
    mkdir -p "$LOCK_DIR"
    
    if [ -f "$lock_file" ]; then
        local lock_pid
        lock_pid=$(cat "$lock_file" 2>/dev/null || echo "unknown")
        
        # Prüfe ob Prozess noch läuft
        if [ "$lock_pid" != "unknown" ] && kill -0 "$lock_pid" 2>/dev/null; then
            echo -e "${RED}❌ Lock bereits aktiv:${NC} $lock_name (PID: $lock_pid)"
            return 1
        else
            # Stale Lock - entfernen
            echo -e "${YELLOW}⚠️  Stale Lock entfernt:${NC} $lock_name"
            rm -f "$lock_file"
        fi
    fi
    
    # Lock erstellen
    echo $$ > "$lock_file"
    echo -e "${GREEN}🔒 Lock erworben:${NC} $lock_name (PID: $$)"
    return 0
}

# Gibt einen Lock frei
# Usage: release_lock "lock-name"
release_lock() {
    local lock_name=$1
    local lock_file="${LOCK_DIR}/${lock_name}.lock"
    
    if [ -f "$lock_file" ]; then
        rm -f "$lock_file"
        echo -e "${GREEN}🔓 Lock freigegeben:${NC} $lock_name"
    fi
    
    return 0
}

# ============================================================================
# HILFSFUNKTIONEN
# ============================================================================

# Prüft ob Script als Root läuft
# Usage: require_root
require_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}❌ Fehler:${NC} Dieses Script benötigt Root-Rechte"
        echo "Bitte mit 'sudo' ausführen"
        exit 1
    fi
}

# Alias für Kompatibilität
# Usage: check_root
check_root() {
    require_root
}

# Fehler-Exit mit Nachricht
# Usage: error_exit "Error message" [exit_code]
error_exit() {
    local message=$1
    local exit_code=${2:-1}
    
    echo -e "${RED}❌ FEHLER:${NC} $message" >&2
    exit "$exit_code"
}

# Erstellt ein Backup einer Datei
# Usage: backup_file "/path/to/file.txt"
# Returns: Backup-Pfad
backup_file() {
    local file_path=$1
    local backup_dir
    backup_dir="/var/backups/qs-deployment/$(date +%Y%m%d-%H%M%S)"
    
    if [ -f "$file_path" ]; then
        mkdir -p "$backup_dir"
        local file_name
        local backup_path
        file_name=$(basename "$file_path")
        backup_path="${backup_dir}/${file_name}"
        
        cp -a "$file_path" "$backup_path"
        echo "$backup_path"
        return 0
    else
        return 1
    fi
}

# Berechnet Checksum einer Datei
# Usage: file_checksum "/path/to/file"
file_checksum() {
    local file_path=$1
    
    if [ -f "$file_path" ]; then
        md5sum "$file_path" | cut -d' ' -f1
    else
        echo "none"
    fi
}

# Prüft ob eine Datei sich geändert hat
# Usage: file_changed "/path/to/file" "component"
# Returns: 0 wenn geändert, 1 wenn unverändert
file_changed() {
    local file_path=$1
    local component=$2
    
    local current_checksum
    local stored_checksum
    current_checksum=$(file_checksum "$file_path")
    stored_checksum=$(get_state "$component" "checksum_$(basename "$file_path")")
    
    if [ "$current_checksum" != "$stored_checksum" ]; then
        return 0  # Geändert
    else
        return 1  # Unverändert
    fi
}

# Speichert Checksum einer Datei
# Usage: save_file_checksum "/path/to/file" "component"
save_file_checksum() {
    local file_path=$1
    local component=$2
    
    local checksum
    checksum=$(file_checksum "$file_path")
    save_state "$component" "checksum_$(basename "$file_path")" "$checksum"
}

# ============================================================================
# LOGGING-FUNKTIONEN - Standardisiertes Interface für alle Scripts
# ============================================================================

# Haupt-Logging-Funktion mit Levels
# Usage: log "LEVEL" "message"
log() {
    local level=$1
    shift
    local message="$*"
    local color=$NC
    local symbol=""
    
    case $level in
        SUCCESS|success) color=$GREEN; symbol="✅" ;;
        ERROR|error)     color=$RED; symbol="❌" ;;
        WARNING|warning|WARN|warn) color=$YELLOW; symbol="⚠️ " ;;
        INFO|info)       color=$BLUE; symbol="ℹ️ " ;;
        DEBUG|debug)     color=$CYAN; symbol="🔍" ;;
        PROGRESS|progress) color=$MAGENTA; symbol="⏳" ;;
        STEP|step)       color=$CYAN; symbol="▶️ " ;;
        SECTION|section) color=$BOLD; symbol="━━" ;;
        *)               color=$NC; symbol="  " ;;
    esac
    
    # Mit Timestamp
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] ${symbol} ${message}${NC}"
}

# Legacy-Support: Alte idempotency_log Funktion
idempotency_log() {
    log "$@"
}

# Convenience-Funktionen für häufige Log-Levels
log_success() {
    log SUCCESS "$@"
}

log_error() {
    log ERROR "$@"
}

log_warning() {
    log WARNING "$@"
}

log_info() {
    log INFO "$@"
}

log_debug() {
    log DEBUG "$@"
}

log_step() {
    log STEP "$@"
}

log_section() {
    log SECTION "$@"
}

# ============================================================================
# VALIDATION-FUNKTIONEN - Wiederverwendbare Checks
# ============================================================================

# Prüft ob ein Command verfügbar ist
# Usage: validate_command_available "command_name"
# Returns: 0 wenn verfügbar, 1 wenn nicht
validate_command_available() {
    local cmd=$1
    command -v "$cmd" >/dev/null 2>&1
}

# Prüft ob eine Datei existiert
# Usage: validate_file_exists "/path/to/file"
# Returns: 0 wenn existiert, 1 wenn nicht
validate_file_exists() {
    local file=$1
    [ -f "$file" ]
}

# Prüft ob ein Verzeichnis existiert und beschreibbar ist
# Usage: validate_directory_writable "/path/to/dir"
# Returns: 0 wenn beschreibbar, 1 wenn nicht
validate_directory_writable() {
    local dir=$1
    [ -d "$dir" ] && [ -w "$dir" ]
}

# Prüft ob ein Port verfügbar ist (nicht in Benutzung)
# Usage: validate_port_available 8080
# Returns: 0 wenn verfügbar, 1 wenn belegt
validate_port_available() {
    local port=$1
    ! netstat -tuln 2>/dev/null | grep -q ":${port} " && \
    ! ss -tuln 2>/dev/null | grep -q ":${port} "
}

# Prüft ob ein Service läuft
# Usage: validate_service_status "service_name"
# Returns: 0 wenn läuft, 1 wenn nicht
validate_service_status() {
    local service=$1
    systemctl is-active --quiet "$service" 2>/dev/null
}

# Prüft Netzwerk-Konnektivität zu einem Host
# Usage: validate_network_connectivity "hostname" [port]
# Returns: 0 wenn erreichbar, 1 wenn nicht
validate_network_connectivity() {
    local host=$1
    local port=${2:-443}
    
    # Versuche mit timeout
    timeout 5 bash -c "cat < /dev/null > /dev/tcp/${host}/${port}" 2>/dev/null
}

# Prüft ob ein Prozess läuft
# Usage: validate_process_running "process_name"
# Returns: 0 wenn läuft, 1 wenn nicht
validate_process_running() {
    local process=$1
    pgrep -x "$process" >/dev/null 2>&1
}

# ============================================================================
# INITIALISIERUNG
# ============================================================================

# Verzeichnisse erstellen falls nicht vorhanden
_init_idempotency() {
    mkdir -p "$MARKER_DIR" "$STATE_DIR" "$LOCK_DIR" 2>/dev/null || true
}

# Auto-Init beim Source
_init_idempotency

# ============================================================================
# EXPORT FUNKTIONEN
# ============================================================================

# Exportiere alle Funktionen für Sub-Shells

# Marker-Funktionen
export -f marker_exists
export -f set_marker
export -f clear_marker
export -f clear_all_markers
export -f list_markers

# State-Funktionen
export -f save_state
export -f get_state
export -f clear_state
export -f list_state

# Idempotenz & Lock
export -f run_idempotent
export -f acquire_lock
export -f release_lock

# Helper-Funktionen
export -f require_root
export -f check_root
export -f error_exit
export -f backup_file
export -f file_checksum
export -f file_changed
export -f save_file_checksum

# Logging-Funktionen
export -f log
export -f idempotency_log
export -f log_success
export -f log_error
export -f log_warning
export -f log_info
export -f log_debug
export -f log_step
export -f log_section

# Validation-Funktionen
export -f validate_command_available
export -f validate_file_exists
export -f validate_directory_writable
export -f validate_port_available
export -f validate_service_status
export -f validate_network_connectivity
export -f validate_process_running

# Exportiere Verzeichnisse
export MARKER_DIR
export STATE_DIR
export LOCK_DIR

# Exportiere Farben
export RED GREEN YELLOW BLUE CYAN MAGENTA WHITE BOLD NC
export LIB_RED LIB_GREEN LIB_YELLOW LIB_BLUE LIB_CYAN LIB_NC
export COLOR_RED COLOR_GREEN COLOR_YELLOW COLOR_BLUE COLOR_CYAN COLOR_MAGENTA COLOR_BOLD COLOR_RESET RESET

# Success-Message
log INFO "Idempotency Library v2.0 geladen (erweitert: Farben/Logging/Validation)"
