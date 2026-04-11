# E2E-Tests für DevSystem Code-Server

## Übersicht

Dieses Verzeichnis enthält End-to-End-Testskripte für den DevSystem Code-Server. Die Skripte sind dazu konzipiert, eine umfassende Validierung der Code-Server-Installation, -Konfiguration und -Integration durchzuführen.

## Teststruktur

Die Tests sind modular aufgebaut und können individuell oder als vollständige Test-Suite ausgeführt werden:

1. **[run-code-server-tests.sh](./run-code-server-tests.sh)**: Hauptskript zum Ausführen aller Tests
2. **[test-code-server-tailscale.sh](./test-code-server-tailscale.sh)**: Tests für die Tailscale-Integration
3. **[test-code-server-pwa.sh](./test-code-server-pwa.sh)**: Tests für die PWA-Funktionalität
4. **[test-code-server-logs.sh](./test-code-server-logs.sh)**: Tests für die Log-Analyse
5. **[setup-automated-tests.sh](./setup-automated-tests.sh)**: Skript zur Einrichtung automatisierter Tests
6. **[setup-test-environment.sh](./setup-test-environment.sh)**: Skript zur Einrichtung der Testumgebung

## Testfunktionen

Die Testskripte umfassen folgende Funktionen:

- **Service-Status-Tests**: Überprüfung von systemctl, Prozess-Status und User-Kontext
- **Konfigurationstests**: Validierung der config.yaml, Passwort-Einstellungen und Berechtigungen
- **Netzwerk-Tests**: Überprüfung der Ports, HTTP-Verbindungen und WebSocket-Funktionalität
- **Extension-Tests**: Validierung der installierten und aktivierten Extensions
- **Workspace-Tests**: Überprüfung der Verzeichnisse und settings.json
- **Tailscale-Integration**: Tests für die Integration mit Tailscale
- **PWA-Funktionalität**: Tests für Progressive Web App Features
- **Log-Analyse**: Validierung der Logfiles und -inhalte

## Verwendung

### Ausführung aller Tests

```bash
sudo ./run-code-server-tests.sh
```

### Ausführung spezifischer Tests

```bash
# Nur Tailscale-Integration testen
sudo ./run-code-server-tests.sh --test=tailscale

# Nur PWA-Funktionalität testen
sudo ./run-code-server-tests.sh --test=pwa

# Nur Log-Analyse durchführen
sudo ./run-code-server-tests.sh --test=logs
```

### Ausführliche Ausgabe aktivieren

```bash
sudo ./run-code-server-tests.sh --verbose
```

### Automatisierte Tests einrichten

```bash
sudo ./setup-automated-tests.sh
```

## Testumgebung einrichten

Bevor Tests ausgeführt werden, kann optional die Testumgebung eingerichtet werden:

```bash
sudo ./setup-test-environment.sh
```

## Log-Dateien

Die Testergebnisse werden in folgenden Verzeichnissen gespeichert:

- Temporäre Logs: `/tmp/code-server-test-results/`
- Persistente Logs: `/var/log/devsystem-test-code-server.log`

## Integration mit CI/CD

Die Tests können in CI/CD-Pipelines integriert werden. Beispiel:

```yaml
test-code-server:
  script:
    - sudo ./scripts/e2e-tests/setup-test-environment.sh
    - sudo ./scripts/e2e-tests/run-code-server-tests.sh
  artifacts:
    paths:
      - /var/log/devsystem-test-code-server.log
```

## Hinweise zur Erweiterung

- Neue Tests können durch Hinzufügen von Funktionen in die bestehenden Skripte integriert werden
- Für komplexere Tests können neue Skriptdateien erstellt und in run-code-server-tests.sh eingebunden werden
- Verwenden Sie die vorhandenen Logging-Funktionen für konsistente Ausgaben

## Abhängigkeiten

- Bash
- curl
- systemctl
- jq (optional, für JSON-Validierung)
- yamllint (optional, für YAML-Validierung)

## Version

- Version: 1.0
- Autor: DevSystem Team
- Datum: 2026-04-11