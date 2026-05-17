# Dokumentation: Automatisierte E2E-Tests für code-server

Diese Dokumentation beschreibt die automatisierten End-to-End-Tests (E2E-Tests) für code-server, die im Rahmen von GitHub Issue #18 implementiert wurden. Die Tests dienen der Validierung der Funktionalität von code-server in einer realen Umgebung und stellen sicher, dass alle Komponenten korrekt zusammenarbeiten.

## Inhaltsverzeichnis

1. [Übersicht des Testsystems](#1-übersicht-des-testsystems)
   - [Architektur](#11-architektur)
   - [Komponenten](#12-komponenten)
   - [Testabdeckung](#13-testabdeckung)
   - [Workflow](#14-workflow)

2. [Installationsanleitung](#2-installationsanleitung)
   - [Voraussetzungen](#21-voraussetzungen)
   - [Installation der Testumgebung](#22-installation-der-testumgebung)
   - [Konfiguration](#23-konfiguration)
   - [Verifizierung der Installation](#24-verifizierung-der-installation)

3. [Benutzerhandbuch zur Ausführung der Tests](#3-benutzerhandbuch-zur-ausführung-der-tests)
   - [Grundlegende Testausführung](#31-grundlegende-testausführung)
   - [Ausführung spezifischer Tests](#32-ausführung-spezifischer-tests)
   - [Erweiterte Optionen](#33-erweiterte-optionen)
   - [Interpretation der Testergebnisse](#34-interpretation-der-testergebnisse)
   - [HTML-Berichte](#35-html-berichte)

4. [Entwicklerhandbuch zum Hinzufügen neuer Tests](#4-entwicklerhandbuch-zum-hinzufügen-neuer-tests)
   - [Testarchitektur verstehen](#41-testarchitektur-verstehen)
   - [Erstellen eines neuen Testskripts](#42-erstellen-eines-neuen-testskripts)
   - [Integration in das Testsystem](#43-integration-in-das-testsystem)
   - [Best Practices](#44-best-practices)
   - [Code-Beispiele](#45-code-beispiele)

5. [Troubleshooting-Guide](#5-troubleshooting-guide)
   - [Häufige Probleme und Lösungen](#51-häufige-probleme-und-lösungen)
   - [Diagnose-Tools](#52-diagnose-tools)
   - [Log-Analyse](#53-log-analyse)
   - [Bekannte Einschränkungen](#54-bekannte-einschränkungen)

## 1. Übersicht des Testsystems

### 1.1 Architektur

Das E2E-Testsystem für code-server basiert auf einer modularen Architektur, die aus mehreren Bash-Skripten besteht. Die Architektur folgt einem hierarchischen Aufbau:

```
                  +-------------------+
                  | run-code-server-  |
                  |      tests.sh     | (Zentrales Test-Framework)
                  +-------------------+
                           |
                           v
          +----------------+----------------+
          |                |                |
+-----------------+ +-----------------+ +-----------------+
| test-code-      | | test-code-      | | test-code-      |
| server-         | | server-         | | server-         |
| tailscale.sh    | | pwa.sh          | | logs.sh         |
+-----------------+ +-----------------+ +-----------------+
          ^                ^                ^
          |                |                |
          +----------------+----------------+
                           |
                           v
                  +-------------------+
                  | setup-test-       |
                  | environment.sh    | (Testumgebung)
                  +-------------------+
```

Diese Architektur ermöglicht:
- Zentrale Steuerung und Berichterstattung
- Modulare Testentwicklung
- Parallele oder sequentielle Testausführung
- Isolierte Testumgebung für reproduzierbare Ergebnisse

### 1.2 Komponenten

Das Testsystem besteht aus folgenden Hauptkomponenten:

1. **Zentrales Test-Framework** ([`run-code-server-tests.sh`](../scripts/e2e-tests/run-code-server-tests.sh))
   - Koordiniert die Ausführung aller Tests
   - Sammelt und aggregiert Testergebnisse
   - Generiert Berichte und Logs
   - Bietet Optionen für parallele Testausführung

2. **Testumgebungs-Setup** ([`setup-test-environment.sh`](../scripts/e2e-tests/setup-test-environment.sh))
   - Erstellt eine isolierte Testumgebung
   - Konfiguriert code-server für Testzwecke
   - Richtet Tailscale für Tests ein
   - Implementiert Cleanup-Funktionen

3. **Spezifische Testmodule**
   - **Tailscale-Tests** ([`test-code-server-tailscale.sh`](../scripts/e2e-tests/test-code-server-tailscale.sh))
     - Testet die Integration zwischen code-server und Tailscale
     - Überprüft Netzwerkverbindungen und Zugänglichkeit
     - Validiert Authentifizierung über Tailscale
   
   - **PWA-Tests** ([`test-code-server-pwa.sh`](../scripts/e2e-tests/test-code-server-pwa.sh))
     - Testet die Progressive Web App Funktionalität
     - Validiert das Web-App-Manifest
     - Überprüft Service Worker und Offline-Funktionalität
   
   - **Log-Tests** ([`test-code-server-logs.sh`](../scripts/e2e-tests/test-code-server-logs.sh))
     - Analysiert code-server Logs auf Fehler und Warnungen
     - Überprüft Log-Rotation und -Konfiguration
     - Unterstützt verschiedene Log-Formate

4. **Automatisiertes Setup** ([`setup-automated-tests.sh`](../scripts/e2e-tests/setup-automated-tests.sh))
   - Installiert alle erforderlichen Abhängigkeiten
   - Konfiguriert die Umgebung für automatisierte Tests
   - Erkennt das Betriebssystem und passt die Installation an

5. **Git-Workflow-Integration** ([`implement-git-workflow.sh`](../scripts/e2e-tests/implement-git-workflow.sh))
   - Implementiert den Git-Workflow für die Testentwicklung
   - Automatisiert Branch-Erstellung, Commits und Merges
   - Stellt sicher, dass der Workflow den Projektrichtlinien entspricht

### 1.3 Testabdeckung

Die E2E-Tests decken folgende Bereiche der code-server-Funktionalität ab:

#### Tailscale-Integration
- Tailscale-Konnektivität und Netzwerkkonfiguration
- Zugriff auf code-server über Tailscale-Netzwerk
- Authentifizierung über Tailscale
- MagicDNS-Funktionalität
- Robustheit bei verschiedenen Netzwerkkonfigurationen

#### Progressive Web App (PWA) Funktionalität
- Web-App-Manifest-Validierung
- Service Worker Funktionalität
- Offline-Fähigkeiten
- Cache-Verhalten
- Kompatibilität mit verschiedenen Browsern

#### Logging-System
- Log-Dateistruktur und -Format
- Fehler- und Warnungserkennung
- Log-Rotation und -Archivierung
- Kompatibilität mit verschiedenen Log-Konfigurationen

### 1.4 Workflow

Der typische Workflow für die Ausführung der E2E-Tests umfasst folgende Schritte:

1. **Vorbereitung der Testumgebung**
   - Installation der erforderlichen Abhängigkeiten
   - Konfiguration von code-server und Tailscale
   - Erstellung einer isolierten Testumgebung

2. **Testausführung**
   - Ausführung aller Tests oder spezifischer Testmodule
   - Sammlung von Testergebnissen und Metriken
   - Generierung von Logs und Berichten

3. **Ergebnisanalyse**
   - Überprüfung der Testergebnisse
   - Analyse von Fehlern und Warnungen
   - Identifikation von Verbesserungsmöglichkeiten

4. **Integration in CI/CD**
   - Automatisierte Testausführung nach Deployments
   - Regelmäßige geplante Tests
   - Benachrichtigungen bei Testfehlern

## 2. Installationsanleitung

### 2.1 Voraussetzungen

Für die Installation und Ausführung der E2E-Tests werden folgende Komponenten benötigt:

#### Erforderliche Software
- Bash (Version 4.0 oder höher)
- Git
- code-server (installiert und konfiguriert)
- Tailscale (installiert und konfiguriert)

#### Erforderliche Pakete
Die folgenden Pakete werden vom Setup-Skript automatisch installiert, können aber auch manuell installiert werden:

**Grundlegende Tools:**
- curl
- jq
- net-tools
- procps
- grep
- findutils
- coreutils

**Für Tailscale-Tests:**
- ca-certificates
- iproute2

**Für PWA-Tests:**
- wget
- sed

**Für Log-Tests:**
- gawk
- diffutils

**Für HTML-Berichte:**
- xsltproc

#### Optionale Pakete
Diese Pakete verbessern die Funktionalität, sind aber nicht zwingend erforderlich:
- yamllint (Validierung von YAML-Konfigurationen)
- logrotate (Log-Rotation-Tests)
- htmldoc (Erweiterte HTML-Berichterstellung)
- vim (Einfache Textbearbeitung für Tests)
- htop (Prozessmonitoring während Tests)
- rsync (Für Backup-Tests)
- parallel (Für parallele Testausführung)

#### Systemanforderungen
- Mindestens 1 GB freier Arbeitsspeicher
- Mindestens 1 GB freier Festplattenspeicher
- Internetverbindung für Tailscale-Tests
- Root- oder sudo-Zugriff für bestimmte Tests

### 2.2 Installation der Testumgebung

Die Installation der Testumgebung erfolgt über das `setup-automated-tests.sh`-Skript, das alle erforderlichen Abhängigkeiten installiert und die Umgebung konfiguriert.

#### Automatische Installation

1. Klonen Sie das Repository (falls noch nicht geschehen):
   ```bash
   git clone <repository-url>
   cd <repository-directory>
   ```

2. Führen Sie das Setup-Skript aus:
   ```bash
   bash scripts/e2e-tests/setup-automated-tests.sh
   ```

   Für eine nicht-interaktive Installation:
   ```bash
   bash scripts/e2e-tests/setup-automated-tests.sh --non-interactive
   ```

3. Das Skript erkennt automatisch das Betriebssystem und installiert die erforderlichen Abhängigkeiten.

#### Manuelle Installation

Falls die automatische Installation nicht funktioniert, können Sie die erforderlichen Komponenten manuell installieren:

1. Installieren Sie die erforderlichen Pakete:
   
   **Für Debian/Ubuntu:**
   ```bash
   sudo apt-get update
   sudo apt-get install -y curl jq net-tools procps grep findutils coreutils ca-certificates iproute2 wget sed gawk diffutils xsltproc
   ```

   **Für Red Hat/CentOS:**
   ```bash
   sudo yum install -y curl jq net-tools procps-ng grep findutils coreutils ca-certificates iproute wget sed gawk diffutils libxslt
   ```

   **Für macOS (mit Homebrew):**
   ```bash
   brew install curl jq gnu-sed gawk diffutils libxslt
   ```

2. Stellen Sie sicher, dass code-server und Tailscale installiert und konfiguriert sind.

3. Erstellen Sie die erforderlichen Verzeichnisse:
   ```bash
   mkdir -p /tmp/code-server-e2e-test-results
   mkdir -p /tmp/code-server-test-env
   ```

### 2.3 Konfiguration

Nach der Installation können Sie die Testumgebung an Ihre Bedürfnisse anpassen.

#### Konfigurationsdateien

Die Hauptkonfiguration erfolgt über Umgebungsvariablen in den Testskripten. Die wichtigsten Konfigurationsdateien sind:

- **Zentrale Konfiguration**: Jedes Testskript enthält Konfigurationsvariablen am Anfang der Datei.
- **Temporäre Konfiguration**: Während der Testausführung werden temporäre Konfigurationsdateien in `/tmp/code-server-test-env/` erstellt.

#### Anpassung der Konfiguration

Um die Konfiguration anzupassen, können Sie die Skripte direkt bearbeiten oder Umgebungsvariablen setzen:

1. **Anpassung der Ports**:
   Bearbeiten Sie die `CODE_SERVER_PORT`- und `CADDY_PORT`-Variablen in den Testskripten.

2. **Anpassung der Testumgebung**:
   Bearbeiten Sie die Variablen in `setup-test-environment.sh`, um den Pfad der Testumgebung zu ändern.

3. **Anpassung der Tailscale-Konfiguration**:
   Wenn Sie einen eigenen Tailscale-Authkey verwenden möchten, kopieren Sie die Vorlage und fügen Sie Ihren Schlüssel ein:
   ```bash
   cp scripts/tailscale-authkey.txt.template /tmp/code-server-test-env/tailscale-authkey.txt
   # Bearbeiten Sie die Datei und fügen Sie Ihren Authkey ein
   ```

### 2.4 Verifizierung der Installation

Nach der Installation sollten Sie überprüfen, ob die Testumgebung korrekt eingerichtet ist:

1. Führen Sie das Testumgebungs-Setup-Skript aus:
   ```bash
   bash scripts/e2e-tests/setup-test-environment.sh --verbose
   ```

2. Überprüfen Sie die Ausgabe auf Fehler oder Warnungen.

3. Führen Sie einen einfachen Test aus, um die Funktionalität zu überprüfen:
   ```bash
   bash scripts/e2e-tests/run-code-server-tests.sh --test=logs --verbose
   ```

4. Überprüfen Sie, ob die Testergebnisse korrekt generiert wurden:
   ```bash
   ls -la /tmp/code-server-e2e-test-results/
   ```

Wenn alle Schritte erfolgreich waren, ist die Testumgebung korrekt eingerichtet und bereit für die Ausführung der E2E-Tests.

## 3. Benutzerhandbuch zur Ausführung der Tests

### 3.1 Grundlegende Testausführung

Die E2E-Tests können mit dem zentralen Test-Framework `run-code-server-tests.sh` ausgeführt werden. Dieses Skript koordiniert die Ausführung aller Testmodule und sammelt die Ergebnisse.

#### Ausführung aller Tests

Um alle verfügbaren Tests auszuführen:

```bash
bash scripts/e2e-tests/run-code-server-tests.sh
```

Dies führt sequentiell alle Testmodule aus und gibt eine Zusammenfassung der Ergebnisse aus.

#### Ausführung mit ausführlicher Ausgabe

Für detailliertere Informationen während der Testausführung:

```bash
bash scripts/e2e-tests/run-code-server-tests.sh --verbose
```

#### Parallele Testausführung

Für eine schnellere Ausführung können Tests parallel ausgeführt werden:

```bash
bash scripts/e2e-tests/run-code-server-tests.sh --parallel
```

### 3.2 Ausführung spezifischer Tests

Sie können auch spezifische Testmodule ausführen, wenn Sie nur bestimmte Aspekte von code-server testen möchten.

#### Tailscale-Tests

Um nur die Tailscale-Integrationstests auszuführen:

```bash
bash scripts/e2e-tests/run-code-server-tests.sh --test=tailscale
```

Oder direkt das Testskript:

```bash
bash scripts/e2e-tests/test-code-server-tailscale.sh
```

Mit spezifischen Authentifizierungsoptionen:

```bash
bash scripts/e2e-tests/test-code-server-tailscale.sh --auth-mode=sso
```

#### PWA-Tests

Um nur die Progressive Web App Tests auszuführen:

```bash
bash scripts/e2e-tests/run-code-server-tests.sh --test=pwa
```

Oder direkt das Testskript:

```bash
bash scripts/e2e-tests/test-code-server-pwa.sh
```

#### Log-Tests

Um nur die Log-Analysetests auszuführen:

```bash
bash scripts/e2e-tests/run-code-server-tests.sh --test=logs
```

Oder direkt das Testskript:

```bash
bash scripts/e2e-tests/test-code-server-logs.sh
```

Mit angepassten Wiederholungsversuchen:

```bash
bash scripts/e2e-tests/test-code-server-logs.sh --retry-count=5
```

### 3.3 Erweiterte Optionen

Das Testsystem bietet verschiedene erweiterte Optionen für spezifische Anwendungsfälle.

#### HTML-Berichterstellung

Um einen HTML-Bericht der Testergebnisse zu generieren:

```bash
bash scripts/e2e-tests/run-code-server-tests.sh --html-report
```

Der Bericht wird in `/tmp/code-server-e2e-test-results/e2e-test-report.html` gespeichert.

#### Anpassung der Testumgebung

Um die Testumgebung anzupassen, können Sie das Setup-Skript mit verschiedenen Optionen ausführen:

```bash
bash scripts/e2e-tests/setup-test-environment.sh --verbose --no-cleanup
```

Die Option `--no-cleanup` behält die Testumgebung nach Abschluss der Tests bei, was für die Fehlersuche nützlich sein kann.

#### Timeout-Einstellungen

Für Tests, die mehr Zeit benötigen:

```bash
bash scripts/e2e-tests/test-code-server-tailscale.sh --timeout=30
```

### 3.4 Interpretation der Testergebnisse

Nach der Ausführung der Tests gibt das System eine Zusammenfassung der Ergebnisse aus. Diese enthält:

- Gesamtanzahl der durchgeführten Tests
- Anzahl der erfolgreichen Tests
- Anzahl der fehlgeschlagenen Tests
- Dauer der Testausführung

#### Erfolgreiche Tests

Ein erfolgreicher Test wird mit einer Meldung wie folgt angezeigt:

```
[2026-04-12 20:15:30] [E2E-TEST] [INFO] Test 'tailscale' erfolgreich abgeschlossen (Dauer: 5s).
```

#### Fehlgeschlagene Tests

Ein fehlgeschlagener Test wird mit einer Fehlermeldung und einem Exit-Code angezeigt:

```
[2026-04-12 20:15:35] [E2E-TEST] [ERROR] Test 'pwa' fehlgeschlagen mit Exit-Code 1 (Dauer: 3s).
```

#### Log-Dateien

Detaillierte Informationen zu den Tests finden Sie in den Log-Dateien:

- Zentrale Log-Datei: `/tmp/code-server-e2e-test-results/e2e-test-results.log`
- Tailscale-Test-Log: `/tmp/code-server-e2e-test-results/tailscale-test.log`
- PWA-Test-Log: `/tmp/code-server-e2e-test-results/pwa-test.log`
- Log-Test-Log: `/tmp/code-server-e2e-test-results/logs-test.log`

Eine permanente Kopie der Log-Dateien wird auch in `/var/log/devsystem-e2e-tests.log` gespeichert.

### 3.5 HTML-Berichte

Die HTML-Berichte bieten eine übersichtliche Darstellung der Testergebnisse und sind besonders für die Präsentation und Dokumentation nützlich.

#### Inhalt der HTML-Berichte

Die HTML-Berichte enthalten:

- Eine Zusammenfassung der Testergebnisse
- Detaillierte Informationen zu jedem Test
- Dauer der einzelnen Tests
- Exit-Codes für fehlgeschlagene Tests

#### Zugriff auf HTML-Berichte

Die HTML-Berichte werden standardmäßig in `/tmp/code-server-e2e-test-results/e2e-test-report.html` gespeichert. Sie können mit einem Webbrowser geöffnet werden:

```bash
xdg-open /tmp/code-server-e2e-test-results/e2e-test-report.html  # Linux
open /tmp/code-server-e2e-test-results/e2e-test-report.html      # macOS
```

## 4. Entwicklerhandbuch zum Hinzufügen neuer Tests

### 4.1 Testarchitektur verstehen

Bevor Sie neue Tests hinzufügen, ist es wichtig, die Architektur des Testsystems zu verstehen:

- **Modularer Aufbau**: Jedes Testmodul ist ein eigenständiges Bash-Skript, das spezifische Aspekte von code-server testet.
- **Gemeinsame Funktionen**: Alle Testmodule verwenden ähnliche Funktionen für Logging, Fehlerbehandlung und Berichterstattung.
- **Zentrale Koordination**: Das `run-code-server-tests.sh`-Skript koordiniert die Ausführung aller Testmodule.

### 4.2 Erstellen eines neuen Testskripts

Um ein neues Testmodul zu erstellen, folgen Sie diesen Schritten:

1. **Erstellen Sie eine neue Skriptdatei** in `scripts/e2e-tests/`:
   ```bash
   touch scripts/e2e-tests/test-code-server-newfeature.sh
   chmod +x scripts/e2e-tests/test-code-server-newfeature.sh
   ```

2. **Fügen Sie die grundlegende Skriptstruktur hinzu**:
   ```bash
   #!/bin/bash
   #
   # test-code-server-newfeature.sh - Tests für neue Feature-Funktionalität
   #
   # Dieses Skript testet [Beschreibung der Funktionalität]
   #
   # Version: 1.0
   # Autor: [Ihr Name]
   # Datum: [Aktuelles Datum]
   #
   # Verwendung: bash test-code-server-newfeature.sh [--verbose]
   #

   # Fehler bei der Ausführung beenden das Skript
   set -e

   # Konfigurationsoptionen
   VERBOSE=false
   TEST_RESULTS_DIR="/tmp/code-server-e2e-test-results"
   NEWFEATURE_TEST_LOG="$TEST_RESULTS_DIR/newfeature-test.log"

   # Testzähler
   TOTAL_TESTS=0
   PASSED_TESTS=0
   FAILED_TESTS=0

   # Farbdefinitionen für Terminal-Ausgabe
   RED='\033[0;31m'
   GREEN='\033[0;32m'
   YELLOW='\033[0;33m'
   BLUE='\033[0;34m'
   CYAN='\033[0;36m'
   NC='\033[0m' # No Color

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
       
       echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [NEWFEATURE] [$level] $message${NC}" | tee -a "$NEWFEATURE_TEST_LOG"
   }

   # Funktion zum Ausführen eines Tests
   run_test() {
       local test_name=$1
       local test_function=$2
       
       log "TEST" "Starte Test: $test_name"
       
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

   # Initialisierung
   init_test_env() {
       mkdir -p "$TEST_RESULTS_DIR"
       > "$NEWFEATURE_TEST_LOG"
       
       log "INFO" "Initialisiere NewFeature-Testumgebung..."
   }

   # Funktion zum Parsen der Kommandozeilenargumente
   parse_args() {
       for arg in "$@"; do
           case $arg in
               --verbose)
                   VERBOSE=true
                   ;;
               --help)
                   echo "Verwendung: bash test-code-server-newfeature.sh [--verbose]"
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

   # Funktion zum Anzeigen der Testergebnisse
   show_test_results() {
       echo ""
       log "TEST" "====== NewFeature-Testergebnisse ======"
       log "INFO" "Durchgeführte Tests: $TOTAL_TESTS"
       log "INFO" "Erfolgreiche Tests: $PASSED_TESTS"
       
       if [ $FAILED_TESTS -eq 0 ]; then
           log "INFO" "Fehlgeschlagene Tests: $FAILED_TESTS"
           log "INFO" "Alle NewFeature-Tests wurden erfolgreich abgeschlossen!"
       else
           log "ERROR" "Fehlgeschlagene Tests: $FAILED_TESTS"
           log "ERROR" "Einige NewFeature-Tests sind fehlgeschlagen. Überprüfen Sie die Logs für Details: $NEWFEATURE_TEST_LOG"
       fi
       
       echo ""
   }

   # Hier kommen Ihre spezifischen Testfunktionen
   test_example() {
       log "STEP" "Führe Beispieltest aus..."
       # Implementieren Sie hier Ihren Test
       return 0  # 0 = Erfolg, 1 = Fehler
   }

   # Hauptfunktion
   main() {
       log "TEST" "==== Starte NewFeature-Tests ===="
       
       init_test_env
       parse_args "$@"
       
       # Führe Tests aus
       run_test "Beispieltest" test_example
       
       show_test_results
       
       if [ $FAILED_TESTS -eq 0 ]; then
           exit 0
       else
           exit 1
       fi
   }

   # Starte die Hauptfunktion mit allen übergebenen Argumenten
   main "$@"
   ```

3. **Implementieren Sie Ihre spezifischen Testfunktionen** im Skript.

### 4.3 Integration in das Testsystem

Um Ihr neues Testmodul in das zentrale Test-Framework zu integrieren:

1. **Bearbeiten Sie `run-code-server-tests.sh`** und fügen Sie Ihr Testmodul hinzu:

   Suchen Sie den Abschnitt mit dem Array `tests` und fügen Sie Ihr Modul hinzu:
   ```bash
   local tests=(
       "tailscale" "$SCRIPT_DIR/test-code-server-tailscale.sh"
       "pwa" "$SCRIPT_DIR/test-code-server-pwa.sh"
       "logs" "$SCRIPT_DIR/test-code-server-logs.sh"
       "newfeature" "$SCRIPT_DIR/test-code-server-newfeature.sh"  # Neue Zeile
   )
   ```

2. **Aktualisieren Sie die Hilfetexte** im zentralen Test-Framework:
   ```bash
   echo "  --test=TESTNAME            Nur bestimmte Tests ausführen"
   echo "                             Gültige Testnamen: tailscale, pwa, logs, newfeature, all"
   ```

3. **Aktualisieren Sie die Funktion `check_test_scripts`** im zentralen Test-Framework:
   ```bash
   local required_scripts=(
       "$SCRIPT_DIR/test-code-server-tailscale.sh"
       "$SCRIPT_DIR/test-code-server-pwa.sh"
       "$SCRIPT_DIR/test-code-server-logs.sh"
       "$SCRIPT_DIR/test-code-server-newfeature.sh"  # Neue Zeile
   )
   ```

### 4.4 Best Practices

Bei der Entwicklung neuer Tests sollten Sie folgende Best Practices beachten:

#### Allgemeine Richtlinien

1. **Modularität**: Jeder Test sollte eine spezifische Funktionalität prüfen und unabhängig ausführbar sein.
2. **Robustheit**: Tests sollten robust gegenüber temporären Fehlern sein und Wiederhol