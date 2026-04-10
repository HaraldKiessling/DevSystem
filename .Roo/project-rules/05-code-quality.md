# 05. Code-Quality-Standards

**Version:** 1.0  
**Erstellt:** 2026-04-10  
**Gilt für:** Alle DevSystem Bash-Scripts und Shell-Code

---

## 🎯 Ziel dieses Dokuments

Sicherstellung konsistenter, wartbarer und robuster Code-Qualität in allen DevSystem-Komponenten. Diese Standards basieren auf Best Practices aus der Production-Implementierung des Idempotenz-Frameworks und des Master-Orchestrators.

---

## 🔧 Bash-Script-Standards

### Pflicht-Header

**JEDES Script MUSS mit folgendem Header beginnen:**

```bash
#!/usr/bin/env bash
set -euo pipefail
# set -x  # Debug-Modus (bei Bedarf aktivieren)

# Script: <script-name>.sh
# Purpose: <Kurzbeschreibung>
# Author: DevSystem Team
# Date: YYYY-MM-DD
# Version: 1.0
```

**Erklärung:**
- `set -e`: Script bei Fehler sofort beenden
- `set -u`: Fehler bei undefinierter Variable
- `set -o pipefail`: Pipe schlägt fehl wenn ein Kommando fehlschlägt
- `set -x`: Debug-Ausgabe (optional, für Entwicklung)

---

## 🔄 Idempotenz-Prinzipien

**Referenz-Implementierung:** [`scripts/qs/lib/idempotency.sh`](scripts/qs/lib/idempotency.sh)

### Marker-basierte Checks

Vor JEDER Operation prüfen ob bereits ausgeführt:

```bash
# Marker-Verzeichnis
readonly MARKER_DIR="/var/lib/devsystem/markers"

# Prüfe ob Operation bereits durchgeführt
if [[ -f "${MARKER_DIR}/service-installed.marker" ]]; then
    echo "INFO: Service bereits installiert (Marker existiert)"
    return 0
fi

# ... Operation durchführen ...

# Marker setzen bei Erfolg
mkdir -p "${MARKER_DIR}"
echo "installed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${MARKER_DIR}/service-installed.marker"
```

### State-Persistence

Kritische Zustände persistent speichern:

```bash
readonly STATE_FILE="/var/lib/devsystem/state/service.state"

# State speichern
save_state() {
    local version="$1"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    mkdir -p "$(dirname "${STATE_FILE}")"
    cat > "${STATE_FILE}" <<EOF
VERSION=${version}
INSTALLED_AT=${timestamp}
CHECKSUM=$(sha256sum /path/to/config | cut -d' ' -f1)
EOF
}

# State laden
load_state() {
    [[ -f "${STATE_FILE}" ]] && source "${STATE_FILE}" || return 1
}
```

### Checksum-basierte Updates

Nur bei Änderungen Konfiguration erneuern:

```bash
update_config_if_changed() {
    local config_file="$1"
    local new_content="$2"
    
    local current_checksum=""
    [[ -f "${config_file}" ]] && current_checksum=$(sha256sum "${config_file}" | cut -d' ' -f1)
    
    local new_checksum=$(echo "${new_content}" | sha256sum | cut -d' ' -f1)
    
    if [[ "${current_checksum}" == "${new_checksum}" ]]; then
        echo "INFO: Config unverändert (Checksum: ${current_checksum})"
        return 0
    fi
    
    # Backup vor Änderung
    [[ -f "${config_file}" ]] && cp "${config_file}" "${config_file}.bak.$(date +%s)"
    
    # Neue Config schreiben
    echo "${new_content}" > "${config_file}"
    echo "INFO: Config aktualisiert (Checksum: ${new_checksum})"
}
```

### Rollback-Fähigkeit

Backups vor kritischen Änderungen:

```bash
backup_before_change() {
    local file="$1"
    local backup_dir="/var/backups/devsystem"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    if [[ -f "${file}" ]]; then
        mkdir -p "${backup_dir}"
        cp -p "${file}" "${backup_dir}/$(basename ${file}).${timestamp}.bak"
        echo "INFO: Backup erstellt: ${backup_dir}/$(basename ${file}).${timestamp}.bak"
    fi
}
```

---

## 🚨 Fehlerbehandlung

### Cleanup-Trap

**Pflicht für alle Scripts mit temporären Ressourcen:**

```bash
# Globale Variablen für Cleanup
TEMP_FILES=()
TEMP_DIRS=()

# Cleanup-Funktion
cleanup() {
    local exit_code=$?
    echo "INFO: Cleanup wird durchgeführt (Exit-Code: ${exit_code})"
    
    # Temp-Files löschen
    for file in "${TEMP_FILES[@]}"; do
        [[ -f "${file}" ]] && rm -f "${file}" && echo "Removed: ${file}"
    done
    
    # Temp-Dirs löschen
    for dir in "${TEMP_DIRS[@]}"; do
        [[ -d "${dir}" ]] && rm -rf "${dir}" && echo "Removed: ${dir}"
    done
    
    exit "${exit_code}"
}

# Trap registrieren
trap cleanup EXIT ERR INT TERM

# Temp-Ressource registrieren
register_temp_file() {
    TEMP_FILES+=("$1")
}
```

### Error-Exit-Funktion

```bash
error_exit() {
    local message="$1"
    local exit_code="${2:-1}"
    
    echo "ERROR: ${message}" >&2
    echo "TIMESTAMP: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >&2
    echo "SCRIPT: ${BASH_SOURCE[1]:-unknown}" >&2
    echo "LINE: ${BASH_LINENO[0]:-unknown}" >&2
    
    exit "${exit_code}"
}

# Verwendung
[[ -z "${REQUIRED_VAR}" ]] && error_exit "REQUIRED_VAR nicht gesetzt" 2
```

### Exit-Codes dokumentieren

Am Ende jedes Scripts dokumentieren:

```bash
# Exit-Codes:
# 0  - Erfolg
# 1  - Allgemeiner Fehler
# 2  - Fehlende Parameter/Variablen
# 3  - Service-Fehler (systemd)
# 4  - Netzwerk-Fehler
# 10 - Bereits ausgeführt (Idempotenz-Skip)
```

---

## 📝 Logging

### Log-Funktion

```bash
# Log-Level
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3

# Aktuelles Log-Level (aus ENV oder Default)
CURRENT_LOG_LEVEL="${LOG_LEVEL:-${LOG_LEVEL_INFO}}"

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    case "${level}" in
        DEBUG) [[ ${CURRENT_LOG_LEVEL} -le ${LOG_LEVEL_DEBUG} ]] && echo "[${timestamp}] DEBUG: ${message}" ;;
        INFO)  [[ ${CURRENT_LOG_LEVEL} -le ${LOG_LEVEL_INFO} ]]  && echo "[${timestamp}] INFO:  ${message}" ;;
        WARN)  [[ ${CURRENT_LOG_LEVEL} -le ${LOG_LEVEL_WARN} ]]  && echo "[${timestamp}] WARN:  ${message}" >&2 ;;
        ERROR) [[ ${CURRENT_LOG_LEVEL} -le ${LOG_LEVEL_ERROR} ]] && echo "[${timestamp}] ERROR: ${message}" >&2 ;;
    esac
}

# Verwendung
log INFO "Service wird gestartet"
log ERROR "Service konnte nicht gestartet werden"
```

### Structured Logging (für Parsing)

```bash
log_json() {
    local level="$1"
    local message="$2"
    local extra="${3:-{}}"
    
    cat <<EOF
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","level":"${level}","message":"${message}","extra":${extra}}
EOF
}

# Verwendung
log_json INFO "Deployment gestartet" '{"component":"caddy","version":"2.7.6"}'
```

---

## 🔤 Variablen-Konventionen

### Naming

```bash
# UPPERCASE für globale/exported Variablen
export DEVSYSTEM_VERSION="1.0.0"
readonly CONFIG_DIR="/etc/devsystem"

# lowercase für lokale Funktions-Variablen
install_service() {
    local service_name="$1"
    local install_dir="/opt/${service_name}"
    # ...
}

# Präfix für Script-spezifische Globals (Kollision vermeiden)
CADDY_VERSION="2.7.6"
CADDY_INSTALL_DIR="/opt/caddy"
```

### Readonly für Konstanten

```bash
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly MARKER_DIR="/var/lib/devsystem/markers"
```

### Parameter-Expansion nutzen

```bash
# Default-Werte
SERVICE_NAME="${1:-caddy}"
CONFIG_FILE="${CONFIG_FILE:-/etc/caddy/Caddyfile}"

# Fehler bei ungesetzter Variable
: "${REQUIRED_VAR:?REQUIRED_VAR muss gesetzt sein}"
```

---

## 📋 Funktions-Docstrings

**Jede Funktion > 5 Zeilen MUSS dokumentiert sein:**

```bash
# install_service - Installiert einen systemd Service
#
# Parameter:
#   $1 - service_name: Name des Service (z.B. "caddy")
#   $2 - binary_path: Pfad zur Binary (z.B. "/usr/local/bin/caddy")
#
# Return:
#   0 - Service erfolgreich installiert
#   3 - systemd-Fehler
#
# Beispiel:
#   install_service "caddy" "/usr/local/bin/caddy"
install_service() {
    local service_name="$1"
    local binary_path="$2"
    
    # Implementation...
}
```

---

## 💬 Kommentierung

### Inline-Kommentare

```bash
# Komplexe Logik kommentieren
# Prüfe ob Service läuft UND Port gebunden ist
if systemctl is-active --quiet "${service_name}" && \
   netstat -tulpn | grep -q ":${port}.*LISTEN"; then
    return 0
fi

# Magic Numbers erklären
sleep 5  # Warte auf Service-Start (systemd notification)
```

### TODOs/FIXMEs

```bash
# TODO(#123): Implementiere Retry-Logik für Netzwerk-Fehler
# FIXME(#456): Race-Condition bei parallelem Zugriff
# HACK: Temporärer Workaround bis upstream-fix verfügbar
```

---

## ✅ Code-Review-Checkliste

**Vor jedem Merge MÜSSEN alle Punkte geprüft sein:**

### Funktionalität
- [ ] Script läuft erfolgreich (manuelle Ausführung)
- [ ] Idempotenz verifiziert (2. Durchlauf = Skip)
- [ ] Fehlerbehandlung vollständig (alle Failure-Modes getestet)
- [ ] Exit-Codes korrekt (0=Erfolg, sonst spezifischer Code)

### Idempotenz
- [ ] Marker-Checks vor jeder Operation
- [ ] State-Persistence implementiert
- [ ] Checksum-basierte Updates (keine unnötigen Änderungen)
- [ ] Backups vor kritischen Änderungen

### Logging & Error-Handling
- [ ] Strukturiertes Logging implementiert (INFO, WARN, ERROR)
- [ ] `cleanup()` Funktion mit trap registriert
- [ ] Fehler mit `error_exit()` oder ähnlich behandelt
- [ ] Timestamps in ISO-8601 (UTC)

### Code-Style
- [ ] Pflicht-Header vorhanden (`#!/usr/bin/env bash`, `set -euo pipefail`)
- [ ] Variablen-Naming korrekt (UPPERCASE global, lowercase lokal)
- [ ] `readonly` für Konstanten
- [ ] Funktions-Docstrings vorhanden (>5 Zeilen)

### Testing
- [ ] Unit-Tests vorhanden (wenn Library-Funktion)
- [ ] Manuelle Tests dokumentiert (in vps-test-results-*.md)
- [ ] Shellcheck warnings behoben
- [ ] Idempotenz-Test durchgeführt (2. Run = Skip)

### Dokumentation
- [ ] README.md aktualisiert (wenn neues Script)
- [ ] Inline-Kommentare für komplexe Logik
- [ ] Exit-Codes dokumentiert
- [ ] TODOs mit Issue-Referenz

### Integration
- [ ] Integration in Master-Orchestrator (wenn Component)
- [ ] Marker/State-Paths konsistent mit anderen Scripts
- [ ] Keine Kollisionen mit bestehenden Funktionen/Variablen

---

## 🛠️ Shellcheck Integration

**Empfohlen (aber nicht Pflicht für MVP):**

```bash
# Alle Scripts prüfen
find scripts/ -name "*.sh" -exec shellcheck {} \;

# Spezifische Warnungen deaktivieren (mit Begründung)
# shellcheck disable=SC2034  # Unused variable (wird in sourced script genutzt)
EXPORTED_VAR="value"
```

**Häufige Warnungen:**
- `SC2086`: Quote variables to prevent word splitting
- `SC2155`: Declare and assign separately to avoid masking return values
- `SC2164`: Use `cd ... || exit` to handle errors

---

## 📚 Referenz-Implementierungen

### Exzellente Scripts im Projekt

1. **[`scripts/qs/lib/idempotency.sh`](scripts/qs/lib/idempotency.sh)**
   - 379 Zeilen, 100% Test-Coverage
   - Vollständige Error-Handling
   - Perfekte Dokumentation
   - **Nutze als Template für Library-Code**

2. **[`scripts/qs/setup-qs-master.sh`](scripts/qs/setup-qs-master.sh)**
   - 1036 Zeilen Production-Code
   - Lock-Mechanismus
   - Triple-Format-Reports
   - **Nutze als Template für Orchestrator-Logic**

3. **[`scripts/qs/install-caddy-qs.sh`](scripts/qs/install-caddy-qs.sh)**
   - Idempotenz-Integration
   - Service-Installation
   - **Nutze als Template für Component-Installation**

---

## 🎓 Best Practices Zusammenfassung

1. **Idempotenz first:** Jede Operation muss wiederholbar sein
2. **Fail fast:** `set -euo pipefail` + Error-Exit
3. **Cleanup always:** `trap cleanup EXIT ERR`
4. **Log structured:** Timestamps + Levels
5. **Backup before change:** Rollback-Fähigkeit
6. **Document early:** Docstrings + Inline-Comments
7. **Test twice:** 1. Run = Install, 2. Run = Skip
8. **Review thoroughly:** Code-Review-Checkliste komplett

---

**Version History:**

- **v1.0 (2026-04-10):** Initial Version basierend auf Production-Code-Analyse
