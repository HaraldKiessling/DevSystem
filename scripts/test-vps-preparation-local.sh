#!/bin/bash
#
# DevSystem - VPS Preparation Local Test Script
# Autor: DevSystem Team
# Datum: 2026-04-08
#
# Beschreibung: 
# Dieses Script testet, ob die VPS-Vorbereitungen erfolgreich durchgeführt wurden (lokale Version).
# Es überprüft:
# - Systemupdates
# - Installation notwendiger Pakete
# - Firewall-Konfiguration
# - SSH-Sicherheitseinstellungen
# - Fail2Ban-Konfiguration
# - Kernel-Sicherheitseinstellungen
# - Logging und Audit

set -e # Script beenden, wenn ein Befehl fehlschlägt

# Farbige Ausgabe für bessere Lesbarkeit
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variablen für Tests
TEST_LOG="vps-preparation-test-local.log"

# Funktion zur Ausgabe von Nachrichten
log_message() {
  echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$TEST_LOG"
}

# Funktion zur Ausgabe von Erfolgsmeldungen
log_success() {
  echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓ $1${NC}" | tee -a "$TEST_LOG"
}

# Funktion zur Ausgabe von Warnungen
log_warning() {
  echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠ $1${NC}" | tee -a "$TEST_LOG"
}

# Funktion zur Ausgabe von Fehlermeldungen
log_error() {
  echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗ $1${NC}" | tee -a "$TEST_LOG"
}

# Testfunktion: Prüfen, ob ein Paket installiert ist
test_package_installed() {
  local package="$1"
  if dpkg -l | grep -q " $package " >/dev/null 2>&1; then
    log_success "Paket '$package' ist installiert"
    return 0
  else
    log_error "Paket '$package' ist NICHT installiert"
    return 1
  fi
}

# Testfunktion: SSH-Konfiguration überprüfen
test_ssh_config() {
  local setting="$1"
  local expected="$2"
  local actual=$(grep "^$setting" /etc/ssh/sshd_config | awk '{print $2}')
  
  if [ "$actual" = "$expected" ]; then
    log_success "SSH-Einstellung '$setting' ist korrekt konfiguriert ($expected)"
    return 0
  else
    log_error "SSH-Einstellung '$setting' ist falsch konfiguriert. Erwartet: '$expected', Tatsächlich: '$actual'"
    return 1
  fi
}

# Testfunktion: Kernel-Parameter überprüfen
test_kernel_parameter() {
  local parameter="$1"
  local expected="$2"
  local actual=$(sysctl $parameter | awk '{print $3}')
  
  if [ "$actual" = "$expected" ]; then
    log_success "Kernel-Parameter '$parameter' ist korrekt konfiguriert ($expected)"
    return 0
  else
    log_error "Kernel-Parameter '$parameter' ist falsch konfiguriert. Erwartet: '$expected', Tatsächlich: '$actual'"
    return 1
  fi
}

# Testfunktion: Firewall-Regel überprüfen
test_firewall_rule() {
  local rule="$1"
  if ufw status | grep -q "$rule" >/dev/null 2>&1; then
    log_success "Firewall-Regel '$rule' existiert"
    return 0
  else
    log_error "Firewall-Regel '$rule' existiert NICHT"
    return 1
  fi
}

# Testfunktion: Dienst-Status überprüfen
test_service_active() {
  local service="$1"
  if systemctl is-active --quiet $service; then
    log_success "Dienst '$service' ist aktiv"
    return 0
  else
    log_error "Dienst '$service' ist NICHT aktiv"
    return 1
  fi
}

# Testfunktion: Datei existiert
test_file_exists() {
  local file="$1"
  if [ -f $file ]; then
    log_success "Datei '$file' existiert"
    return 0
  else
    log_error "Datei '$file' existiert NICHT"
    return 1
  fi
}

# Haupttestfunktion
run_tests() {
  local errors=0
  local tests=0
  
  echo "" > "$TEST_LOG" # Testlog zurücksetzen
  
  log_message "===== DevSystem VPS Preparation Tests ====="
  log_message "Host: Lokales System"
  log_message "Datum: $(date '+%Y-%m-%d %H:%M:%S')"
  log_message ""
  
  # Test 2: Systemupdates
  log_message "Test 2: Überprüfung der Systemupdates"
  if apt list --upgradable | grep -q "upgradable"; then
    log_warning "Es sind Systemupdates verfügbar. Das System sollte aktualisiert werden."
    ((errors++))
  else
    log_success "System ist auf dem neuesten Stand"
  fi
  ((tests++))
  
  # Test 3: Notwendige Pakete
  log_message "Test 3: Überprüfung der installierten Pakete"
  local required_packages="curl wget git unzip apt-transport-https ca-certificates gnupg lsb-release software-properties-common ufw fail2ban"
  for package in $required_packages; do
    if ! test_package_installed "$package"; then
      ((errors++))
    fi
  done
  ((tests++))
  
  # Test 4: Firewall-Konfiguration
  log_message "Test 4: Überprüfung der Firewall-Konfiguration"
  if ! ufw status | grep -q "Status: active"; then
    log_error "Firewall ist NICHT aktiv"
    ((errors++))
  else
    log_success "Firewall ist aktiv"
    # Überprüfung der Standardregeln
    test_firewall_rule "22/tcp"
  fi
  ((tests++))
  
  # Test 5: SSH-Sicherheitseinstellungen
  log_message "Test 5: Überprüfung der SSH-Sicherheitseinstellungen"
  test_ssh_config "PasswordAuthentication" "no"
  test_ssh_config "PermitEmptyPasswords" "no"
  test_ssh_config "PubkeyAuthentication" "yes"
  ((tests++))
  
  # Test 6: Fail2Ban-Konfiguration
  log_message "Test 6: Überprüfung der Fail2Ban-Konfiguration"
  test_service_active "fail2ban"
  test_file_exists "/etc/fail2ban/jail.local"
  ((tests++))
  
  # Test 7: Kernel-Sicherheitseinstellungen
  log_message "Test 7: Überprüfung der Kernel-Sicherheitseinstellungen"
  test_kernel_parameter "net.ipv4.conf.all.rp_filter" "1"
  test_kernel_parameter "net.ipv4.conf.default.rp_filter" "1"
  test_kernel_parameter "net.ipv4.icmp_echo_ignore_broadcasts" "1"
  test_kernel_parameter "net.ipv4.conf.all.accept_source_route" "0"
  ((tests++))
  
  # Test 8: Logging und Audit
  log_message "Test 8: Überprüfung der Logging- und Audit-Konfiguration"
  test_service_active "auditd"
  test_file_exists "/etc/audit/rules.d/audit.rules"
  ((tests++))
  
  # Test 9: Automatische Updates
  log_message "Test 9: Überprüfung der automatischen Updates"
  test_file_exists "/etc/apt/apt.conf.d/50unattended-upgrades"
  ((tests++))
  
  # Test 10: Logdatei
  log_message "Test 10: Überprüfung der Log-Datei"
  test_file_exists "/var/log/devsystem-prepare-vps.log"
  ((tests++))
  
  # Zusammenfassung
  log_message ""
  log_message "===== Testzusammenfassung ====="
  log_message "Durchgeführte Tests: $tests"
  log_message "Fehler: $errors"
  
  if [ $errors -eq 0 ]; then
    log_success "Alle Tests wurden erfolgreich bestanden!"
    return 0
  else
    log_error "Es wurden $errors Fehler gefunden. Bitte überprüfen Sie die Log-Dateien."
    return 1
  fi
}

# Hauptprogramm
log_message "===== DevSystem VPS Preparation Local Test ====="
log_message "Überprüfung der VPS-Vorbereitungen auf dem lokalen System..."

# Prüfen, ob das Script mit Root-Rechten ausgeführt wird
if [ "$(id -u)" != "0" ]; then
   log_error "Dieses Script muss mit Root-Rechten ausgeführt werden."
   exit 1
fi

run_tests
exit_code=$?

if [ $exit_code -eq 0 ]; then
  log_success "VPS-Vorbereitung Test erfolgreich abgeschlossen."
  log_message "Der VPS ist bereit für die Installation von Tailscale."
else
  log_error "VPS-Vorbereitung Test fehlgeschlagen."
  log_message "Bitte überprüfen Sie die Fehlermeldungen und führen Sie die notwendigen Korrekturen durch."
fi

