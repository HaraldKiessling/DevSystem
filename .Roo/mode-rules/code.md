# Code-Modus Regeln

## Branch-Strategie
- Prüfe IMMER aktuellen Branch vor Code-Änderungen
- Konzepte → main
- Code/Skripte → feature/<komponente>-<beschreibung>
- Bei Unsicherheit: Frage nach

## Code-Standards

### Shell-Skripte
- Bash mit `set -euo pipefail` am Anfang
- Explizite Fehlerbehandlung
- Strukturierte Logging-Ausgaben für Test-Validierung
- Idempotenz: Skripte müssen mehrfach ausführbar sein

### Beispiel-Struktur
```bash
#!/bin/bash
set -euo pipefail

# Logging-Funktion
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Fehlerbehandlung
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Hauptlogik
main() {
    log "Starting setup..."
    # Implementation
    log "Setup completed successfully"
}

main "$@"
```

## Vor jedem Commit

1. **Atomare Commits**: Eine logische Änderung pro Commit
2. **Aussagekräftige Commit-Message**: 
   - Format: `<typ>: <beschreibung>`
   - Typen: feat, fix, docs, test, config, refactor
3. **Referenz zur todo.md**: Welche Aufgabe wird bearbeitet?
4. **Status aktualisieren**: todo.md-Status anpassen

### Commit-Beispiel
```
feat: Tailscale-Installation und Konfiguration hinzugefügt

Implementiert die Aufgabe "Tailscale VPN installieren und konfigurieren" aus todo.md
- Installationsskript erstellt
- Authentifizierung konfiguriert
- Systemd-Service eingerichtet
```

## Testing-Pflicht

- **Unit-Tests**: Für kritische Funktionen
- **E2E-Tests**: Für Systemintegration (live gegen VPS)
- **Log-Validierung**: Tests müssen Log-Ausgaben explizit prüfen
- **Vor Merge**: Alle Tests müssen erfolgreich sein

### Test-Beispiel
```bash
# E2E-Test für Tailscale
test_tailscale_running() {
    log "Testing Tailscale service..."
    if systemctl is-active --quiet tailscaled; then
        log "✓ Tailscale service is running"
    else
        error_exit "Tailscale service is not running"
    fi
}
```

## Sicherheit

- **Keine Hardcoded Secrets**: Verwende Umgebungsvariablen
- **Input-Validierung**: Bei User-Input immer validieren
- **Principle of Least Privilege**: Minimale Berechtigungen
- **Secrets-Management**: .env-Dateien, niemals in Git

### Secrets-Handling
```bash
# Gut: Umgebungsvariable
API_KEY="${OPENROUTER_API_KEY:-}"
if [[ -z "$API_KEY" ]]; then
    error_exit "OPENROUTER_API_KEY not set"
fi

# Schlecht: Hardcoded
# API_KEY="sk-or-v1-abc123..."  # NIEMALS!
```

## Dateiorganisation

- **Scripts**: `/scripts/` - Setup- und Deployment-Skripte
- **Konzepte**: `/plans/` - Architektur und Konzeptdokumente
- **Tests**: `/scripts/test-*.sh` - Test-Skripte
- **Dokumentation**: Root-Level `.md`-Dateien

## Code-Review-Checkliste

- [ ] Code folgt Projektstandards
- [ ] Tests sind vorhanden und erfolgreich
- [ ] Dokumentation ist aktualisiert
- [ ] Keine Secrets im Code
- [ ] Fehlerbehandlung implementiert
- [ ] Logging für Debugging vorhanden
- [ ] Idempotenz gewährleistet
