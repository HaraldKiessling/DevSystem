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

# Farben für Ausgabe
readonly LIB_GREEN='\033[0;32m'
readonly LIB_RED='\033[0;31m'
readonly LIB_YELLOW='\033[1;33m'
readonly LIB_BLUE='\033[0;34m'
readonly LIB_CYAN='\033[0;36m'
readonly LIB_NC='\033[0m'

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
        echo -e "${LIB_CYAN}⏭️  Überspringe:${LIB_NC} $description (bereits abgeschlossen)"
        return 0
    fi
    
    echo -e "${LIB_BLUE}🔄 Führe aus:${LIB_NC} $description"
    
    # Command ausführen
    if "${command[@]}"; then
        set_marker "$marker_name" "$description"
        echo -e "${LIB_GREEN}✅ Abgeschlossen:${LIB_NC} $description"
        return 0
    else
        local exit_code=$?
        echo -e "${LIB_RED}❌ Fehlgeschlagen:${LIB_NC} $description (Exit Code: $exit_code)"
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
        local lock_pid=$(cat "$lock_file" 2>/dev/null || echo "unknown")
        
        # Prüfe ob Prozess noch läuft
        if [ "$lock_pid" != "unknown" ] && kill -0 "$lock_pid" 2>/dev/null; then
            echo -e "${LIB_RED}❌ Lock bereits aktiv:${LIB_NC} $lock_name (PID: $lock_pid)"
            return 1
        else
            # Stale Lock - entfernen
            echo -e "${LIB_YELLOW}⚠️  Stale Lock entfernt:${LIB_NC} $lock_name"
            rm -f "$lock_file"
        fi
    fi
    
    # Lock erstellen
    echo $$ > "$lock_file"
    echo -e "${LIB_GREEN}🔒 Lock erworben:${LIB_NC} $lock_name (PID: $$)"
    return 0
}

# Gibt einen Lock frei
# Usage: release_lock "lock-name"
release_lock() {
    local lock_name=$1
    local lock_file="${LOCK_DIR}/${lock_name}.lock"
    
    if [ -f "$lock_file" ]; then
        rm -f "$lock_file"
        echo -e "${LIB_GREEN}🔓 Lock freigegeben:${LIB_NC} $lock_name"
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
        echo -e "${LIB_RED}❌ Fehler:${LIB_NC} Dieses Script benötigt Root-Rechte"
        echo "Bitte mit 'sudo' ausführen"
        exit 1
    fi
}

# Erstellt ein Backup einer Datei
# Usage: backup_file "/path/to/file.txt"
# Returns: Backup-Pfad
backup_file() {
    local file_path=$1
    local backup_dir="/var/backups/qs-deployment/$(date +%Y%m%d-%H%M%S)"
    
    if [ -f "$file_path" ]; then
        mkdir -p "$backup_dir"
        local file_name=$(basename "$file_path")
        local backup_path="${backup_dir}/${file_name}"
        
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
    
    local current_checksum=$(file_checksum "$file_path")
    local stored_checksum=$(get_state "$component" "checksum_$(basename "$file_path")")
    
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
    
    local checksum=$(file_checksum "$file_path")
    save_state "$component" "checksum_$(basename "$file_path")" "$checksum"
}

# ============================================================================
# LOGGING-FUNKTIONEN
# ============================================================================

# Logging-Level
idempotency_log() {
    local level=$1
    local message=$2
    local color=$LIB_NC
    
    case $level in
        "INFO") color=$LIB_GREEN; symbol="ℹ️ " ;;
        "WARN") color=$LIB_YELLOW; symbol="⚠️ " ;;
        "ERROR") color=$LIB_RED; symbol="❌" ;;
        "DEBUG") color=$LIB_CYAN; symbol="🔍" ;;
        *) symbol="  " ;;
    esac
    
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [IDEMPOTENCY] ${symbol} ${message}${LIB_NC}"
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
export -f marker_exists
export -f set_marker
export -f clear_marker
export -f clear_all_markers
export -f list_markers
export -f save_state
export -f get_state
export -f clear_state
export -f list_state
export -f run_idempotent
export -f acquire_lock
export -f release_lock
export -f require_root
export -f backup_file
export -f file_checksum
export -f file_changed
export -f save_file_checksum
export -f idempotency_log

# Exportiere Verzeichnisse
export MARKER_DIR
export STATE_DIR
export LOCK_DIR

# Success-Message
idempotency_log "INFO" "Idempotency Library geladen"
