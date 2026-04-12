# Code-Quality-Standards

**Version:** 1.0.0  
**Erstellt:** 2026-04-12  
**Gilt für:** Alle Bash-Scripts, zukünftig erweiterbar für andere Sprachen  
**Status:** Aktiv

## 1. Bash-Script-Standards

### 1.1 Script-Header (PFLICHT)

**Template:**
```bash
#!/bin/bash
#
# Kurzbeschreibung des Scripts (1-2 Zeilen)
#
# Usage: script-name.sh [OPTIONS]
# 
# Options:
#   --option1    Beschreibung
#   --help       Zeige diese Hilfe
#
# Author: DevSystem Team
# Created: YYYY-MM-DD
# Last Modified: YYYY-MM-DD

set -euo pipefail  # PFLICHT für Fehler-Erkennung
```

**Erklärung:**
- `set -e`: Exit bei Fehler
- `set -u`: Exit bei unbound variables
- `set -o pipefail`: Exit bei Pipe-Fehlern

### 1.2 Fehlerbehandlung

**DO:**
```bash
# Fehler-Check bei kritischen Operationen
if ! systemctl start service; then
    echo "ERROR: Failed to start service" >&2
    exit 1
fi

# Trap für Cleanup
cleanup() {
    rm -f /tmp/tempfile-*
}
trap cleanup EXIT
```

**DON'T:**
```bash
# Ohne Fehler-Check
systemctl start service  # Fehler wird ignoriert

# Exit-Code ignorieren
command || true  # OK nur wenn Fehler erwartet
```

### 1.3 Variablen-Standards

**Naming:**
```bash
# Constants: UPPER_CASE
INSTALL_DIR="/opt/application"

# Variables: lower_case
deployment_mode="normal"

# Functions: lowercase_with_underscores
check_service_status() {
    ...
}
```

**Quoting:**
```bash
# DO: Immer quoten
echo "$variable"
command="$binary_path/$command_name"

# DON'T: Unquoted (Shellcheck SC2086)
echo $variable
```

### 1.4 Idempotenz-Requirements

**Alle Deployment-Scripts MÜSSEN idempotent sein:**

```bash
# Marker-basierte Idempotenz
MARKER="/var/lib/deployment/component.done"

if [ -f "$MARKER" ]; then
    echo "Component bereits deployed, überspringe"
    exit 0
fi

# ... Installation ...

touch "$MARKER"
```

**Testing:** Jedes Script 2-3x hintereinander ausführen → gleiches Ergebnis.

### 1.5 Logging-Standards

**Log-Levels:**
```bash
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $*"
}

log_warning() {
    echo "[WARNING] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}

# Verwendung
log_info "Starting deployment"
log_warning "Service not running, starting now"
log_error "Failed to connect to database"
```

## 2. Shellcheck-Integration

### 2.1 Shellcheck-Policy

**Regel:** Alle neuen Scripts MÜSSEN shellcheck-clean sein.

**Akzeptierte Warnings:**
- SC2317 (Unreachable code) - bei Funktions-Definitionen oft false positive
- SC2155 (Declare/assign separately) - bei unkritischen Variablen OK

**Nicht akzeptierte Warnings:**
- SC2086 (Unquoted variables) - Sicherheitsrisiko
- SC2046 (Quote command substitutions) - Sicherheitsrisiko
- SC2068 (Quote array expansions) - Bug-Risiko

### 2.2 Pre-Commit Shellcheck

**Empfehlung:** Shellcheck in Pre-Commit-Hook:

```bash
# .git/hooks/pre-commit (Template in scripts/docs/)
#!/bin/bash
for file in $(git diff --cached --name-only --diff-filter=ACM | grep '\.sh$'); do
    if ! shellcheck "$file"; then
        echo "❌ Shellcheck failed for $file"
        echo "   Fix errors or add disable-comments"
        exit 1
    fi
done
```

### 2.3 Shellcheck-Directives

**Benutze sparsam:**
```bash
# Disable specific warning (mit Begründung!)
# shellcheck disable=SC2317  # Function is called via dispatch table
function_name() {
    ...
}
```

## 3. Testing-Standards

### 3.1 Test-Level

**Level 1: Syntax-Check** (immer)
```bash
bash -n script.sh  # Syntax-Check ohne Ausführung
shellcheck script.sh
```

**Level 2: Unit-Test** (bei Logic-Scripts)
```bash
# scripts/tests/test-idempotency-lib.sh bereits vorhanden
bash scripts/qs/test-idempotency-lib.sh
```

**Level 3: Integration-Test** (bei Deployment-Scripts)
```bash
# Lokal mit Mocks
bash script.sh --dry-run

# Remote gegen Test-System
bash script.sh --host=test-vps.example.com
```

**Level 4: E2E-Test** (nach Deployment)
```bash
bash scripts/qs/run-e2e-tests.sh
```

### 3.2 Test-Coverage Ziel

| Script-Typ | Minimum Test-Level | Coverage-Ziel |
|------------|-------------------|---------------|
| Deployment-Scripts | Level 3 (Integration) | 100% |
| Utility-Scripts | Level 1 (Syntax) | 80% |
| Test-Scripts | Level 2 (Unit) | 100% |
| Config-Scripts | Level 3 (Integration) | 100% |

## 4. Code-Review-Checkliste

### Vor Merge prüfen:

**Funktionalität:**
- [ ] Script erfüllt beschriebene Funktion
- [ ] Edge-Cases behandelt
- [ ] Error-Handling korrekt

**Code-Quality:**
- [ ] Shellcheck clean (oder akzeptierte Warnings mit Begründung)
- [ ] `set -euo pipefail` gesetzt
- [ ] Variablen quoted (`"$var"` nicht `$var`)
- [ ] Idempotent (bei Deployment-Scripts)
- [ ] Logging konsistent

**Dokumentation:**
- [ ] Script-Header vollständig
- [ ] Usage-Beschreibung klar
- [ ] Komplexe Logik kommentiert
- [ ] README.md aktualisiert (falls neues Tool)

**Testing:**
- [ ] Mindestens Syntax-Check durchgeführt
- [ ] Bei Deployment: Integration-Test
- [ ] Bei Critical: E2E-Test

**Sicherheit:**
- [ ] Keine hardcoded Secrets
- [ ] Keine sudo-Befehle ohne Validierung
- [ ] User-Input validiert (bei interaktiven Scripts)

## 5. Performance-Standards

### 5.1 Deployment-Zeit

**Targets:**
- Einzelner Service: <3 Min
- Full-Deployment: <10 Min
- Rollback: <5 Min

**Bei Überschreitung:** Performance-Analyse durchführen.

### 5.2 Script-Optimierung

**DO:**
```bash
# Parallele Ausführung wo möglich
install_service_a & 
install_service_b &
wait

# Caching von API-Calls
if [ -f "/tmp/cache.txt" ]; then
    data=$(cat /tmp/cache.txt)
else
    data=$(curl api.example.com)
    echo "$data" > /tmp/cache.txt
fi
```

**DON'T:**
```bash
# Sequential wenn parallel möglich
install_service_a
install_service_b

# Unnötige API-Calls
for i in {1..10}; do
    curl api.example.com  # 10x gleicher Call!
done
```

## 6. Sicherheits-Standards

### 6.1 Secrets-Management

**DO:**
```bash
# Aus Dateien lesen
AUTHKEY=$(cat /path/to/secret-file)

# Aus Environment
API_KEY="${API_KEY:-}"
if [ -z "$API_KEY" ]; then
    echo "ERROR: API_KEY not set"
    exit 1
fi
```

**DON'T:**
```bash
# Hardcoded Secrets
AUTHKEY="tskey-abc123..."  # NIEMALS!

# In Git committen
echo "secret123" > config.txt
git add config.txt  # NIEMALS!
```

### 6.2 Input-Validierung

```bash
# User-Input IMMER validieren
read -r user_input

# Whitelist-Ansatz
if [[ "$user_input" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    process "$user_input"
else
    echo "ERROR: Invalid input"
    exit 1
fi
```

## 7. Dokumentations-Standards (Code)

### 7.1 Kommentare

**Wann kommentieren:**
- Complex Logik (wenn nicht self-explanatory)
- Workarounds (mit Ticket-Referenz)
- Security-relevante Entscheidungen
- Performance-Optimierungen

**Wann NICHT:**
```bash
# DON'T: Offensichtliches kommentieren
echo "Hello"  # Prints Hello

# DO: Komplexes erklären
# Retry-Logic mit exponential backoff (max 5 Versuche)
for i in {1..5}; do
    ...
done
```

### 7.2 Function-Dokumentation

```bash
# Kurze Beschreibung
# Args:
#   $1 - deployment_mode (normal|force|rollback)
#   $2 - component_name
# Returns:
#   0 - Success
#   1 - Error
deploy_component() {
    local mode="$1"
    local component="$2"
    ...
}
```

## 8. Legacy-Code-Umgang

### 8.1 Altlasten-Identifikation

**Kandidaten für Refactoring:**
- Scripts ohne `set -euo pipefail`
- Unquoted variables (Shellcheck SC2086)
- Keine Fehlerbehandlung
- Kein Logging

**Vorgehen:**
1. Shellcheck-Report prüfen (reports/shellcheck/)
2. Top-5-Probleme identifizieren
3. Refactoring-Tickets erstellen
4. Schrittweise abarbeiten

### 8.2 Deprecation-Policy

```bash
# Deprecated-Scripts markieren
cat > DEPRECATED-SCRIPT.sh <<'EOF'
#!/bin/bash
echo "⚠️  WARNING: This script is deprecated!"
echo "   Use NEW-SCRIPT.sh instead"
echo "   This script will be removed in v2.0.0"
exit 1
EOF
```

**Timeline:**
- Deprecation-Notice: v1.x
- Removal: v2.0.0 (6+ Monate später)

## 9. CI/CD-Integration

### 9.1 Automated Quality-Checks

**GitHub Actions (bereits vorhanden):**
- Shellcheck für geänderte Scripts
- Syntax-Check vor Merge
- E2E-Tests nach Deployment

**Geplant:**
- Performance-Regression-Tests
- Security-Scanning (hardcoded secrets)

### 9.2 Pre-Merge-Requirements

**Aus git-workflow.md:**
- [ ] Shellcheck clean (oder begründete Exceptions)
- [ ] Tests passed
- [ ] Code-Review durch 1+ Person (oder AI-Self-Review)
- [ ] Dokumentation aktualisiert

## 10. Metriken & KPIs

### Code-Quality-Score

**Formel:**
```
Quality-Score = (Shellcheck-Clean × 0.4) + 
                (Test-Coverage × 0.3) + 
                (Documentation × 0.2) + 
                (Idempotency × 0.1)
```

**Ziel:** Score > 80%

**Aktueller Stand (2026-04-12):**
- Shellcheck-Clean: 25.6% (10/39 Scripts) → 26 Punkte
- Test-Coverage: ~50% (geschätzt) → 15 Punkte  
- Documentation: ~80% (Header vorhanden) → 16 Punkte
- Idempotency: 100% (bei Deployment-Scripts) → 10 Punkte

**Gesamt:** ~67% → **Ziel nicht erreicht**

**Verbesserungs-Maßnahmen:**
1. Shellcheck-Warnings reduzieren (SC2155, SC2086)
2. Test-Coverage erhöhen (fehlende Unit-Tests)
3. Script-Header vervollständigen

---

## 11. Best Practices

### DO:
- ✅ `set -euo pipefail` in JEDEM Script
- ✅ Variablen quoten: `"$variable"`
- ✅ Funktionen für wiederholte Logik
- ✅ Logging für wichtige Aktionen
- ✅ Idempotenz bei Deployments
- ✅ Marker für State-Tracking
- ✅ Error-Messages auf stderr: `>&2`
- ✅ Exit-Codes dokumentieren (0=success, 1=error, 2=usage-error)

### DON'T:
- ❌ Hardcoded Secrets
- ❌ sudo ohne Validierung
- ❌ Unquoted variables
- ❌ Fehlende Fehlerbehandlung
- ❌ Scripts ohne Header
- ❌ Magic Numbers ohne Kommentar
- ❌ Globbing ohne quote (`*.txt` → `"*.txt"`)

---

## 12. Tool-Empfehlungen

### Development
- **shellcheck** - Statische Analyse (PFLICHT)
- **shfmt** - Formatierung (optional)
- **bats** - Unit-Testing-Framework (für umfangreiche Tests)

### CI/CD
- GitHub Actions Shellcheck-Integration (see `.github/workflows/`)
- Pre-Commit-Hooks (see `scripts/docs/setup-git-hooks.sh`)

---

## 13. Refactoring-Roadmap

**Shellcheck-basiertes Refactoring:**

**Phase 1 (diese Woche):**
1. Top-5 Scripts mit meisten Warnings
2. SC2155 (Declare/assign separately) fixen
3. SC2086 (Quote variables) fixen

**Phase 2 (nächsten Monat):**
4. Alle Scripts: Header-Template anwenden
5. Logging standardisieren
6. Remaining Warnings addressieren

**Phase 3 (Q2 2026):**
7. Test-Coverage auf 80%+
8. Quality-Score auf 85%+

---

## 14. Exemptions & Exceptions

### Wann sind Shellcheck-Warnings OK?

1. **SC2317 (Unreachable code):**
   - Bei Funktions-Definitionen oft false positive
   - Kommentieren: `# shellcheck disable=SC2317`

2. **Legacy-Scripts:**
   - Bis Refactoring: Warnings dokumentieren
   - Nicht in neuem Code wiederholen

3. **External-Dependencies:**
   - Wenn externe Tools spezifisches Format erfordern
   - Dokumentieren warum Standard nicht gilt

---

## 15. Enforcement

### Code-Review
Reviewer MÜSSEN diese Standards durchsetzen.

**Bei Verstößen:**
- Comments im PR mit Link zu diesem Dokument
- Request Changes bis Standards erfüllt

### CI/CD
- Shellcheck-Failures blockieren Merge (außer bei begründeten Exceptions)
- Tests müssen grün sein

### Ausnahmen
- Hotfixes: Dürfen Standards verletzen, aber **MÜSSEN** nachgebessert werden innerhalb 48h

---

## Referenzen

- [Shellcheck-Report](../../reports/shellcheck/SHELLCHECK-REPORT.md)
- [Git-Workflow](../../docs/operations/git-workflow.md)
- [Idempotenz-Library](../../scripts/qs/lib/idempotency.sh)
- [Bug-Fixing-Workflow](06-bug-fixing-workflow.md)

---

**Änderungshistorie:**

### 2026-04-12 05:22 UTC
- Version 1.0.0 erstellt
- Bash-Standards basierend auf 39 Scripts definiert
- Shellcheck-Integration dokumentiert
- Code-Review-Checkliste erstellt
- Metriken & KPIs definiert (Quality-Score)
- Refactoring-Roadmap für Verbesserung
- Grund: Housekeeping Sprint Task 3 - Langfristige Code-Quality sichern
