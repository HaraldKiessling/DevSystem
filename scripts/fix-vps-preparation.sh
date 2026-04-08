#!/bin/bash
#
# DevSystem - VPS Preparation Fix Script
# Autor: DevSystem Team
# Datum: 2026-04-08
#
# Beschreibung: 
# Dieses Script behebt die bei den E2E-Tests identifizierten Probleme bei der VPS-Vorbereitung:
# 1. Fail2Ban-Konfiguration: Die benutzerdefinierte Konfigurationsdatei existiert nicht
# 2. Kernel-Sicherheitseinstellungen: RP-Filter-Parameter sind nicht ausreichend restriktiv (2 statt 1)
# 3. Logging und Audit: Audit-Dienst ist nicht aktiv und Konfigurationsdateien fehlen
#
# Voraussetzungen:
# - Ubuntu 22.04 LTS oder höher
# - Root-Zugriff
# - Internetverbindung

set -e # Script beenden, wenn ein Befehl fehlschlägt
set -u # Script beenden, wenn eine Variable nicht definiert ist

# Farbige Ausgabe für bessere Lesbarkeit
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logs in einer Datei speichern
LOG_FILE="/var/log/devsystem-fix-vps-preparation.log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

# Funktion zur Ausgabe von Nachrichten
log_message() {
  echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Funktion zur Ausgabe von Erfolgsmeldungen
log_success() {
  echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓ $1${NC}"
}

# Funktion zur Ausgabe von Warnungen
log_warning() {
  echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠ $1${NC}"
}

# Funktion zur Ausgabe von Fehlermeldungen
log_error() {
  echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗ $1${NC}"
}

# Prüfen, ob das Script mit Root-Rechten ausgeführt wird
if [ "$(id -u)" != "0" ]; then
   log_error "Dieses Script muss mit Root-Rechten ausgeführt werden."
   exit 1
fi

# Willkommensnachricht
log_message "===== DevSystem VPS Preparation Fix Script ====="
log_message "Behebung der bei den E2E-Tests identifizierten Probleme wird gestartet..."

# 1. Fail2Ban-Konfiguration
log_message "1. Fail2Ban-Konfiguration wird korrigiert..."

# Prüfen, ob Fail2Ban installiert ist
if ! dpkg -l | grep -q ' fail2ban '; then
    log_warning "Fail2Ban ist nicht installiert. Installation wird durchgeführt..."
    apt update -q
    apt install -yq fail2ban
fi

# Benutzerdefinierte Konfigurationsdatei erstellen
log_message "Erstelle die benutzerdefinierte Konfigurationsdatei /etc/fail2ban/jail.local..."
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
EOF

# Fail2Ban neu starten
log_message "Fail2Ban wird neu gestartet..."
systemctl enable fail2ban
systemctl restart fail2ban
log_success "Fail2Ban-Konfiguration korrigiert."

# 2. Kernel-Sicherheitseinstellungen
log_message "2. Kernel-Sicherheitseinstellungen werden korrigiert..."

# Überprüfen, ob die Datei /etc/sysctl.d/99-security.conf existiert
if [ -f "/etc/sysctl.d/99-security.conf" ]; then
    # RP-Filter-Parameter auf 1 setzen
    log_message "Aktualisiere die RP-Filter-Parameter in /etc/sysctl.d/99-security.conf..."
    sed -i 's/net.ipv4.conf.all.rp_filter = 2/net.ipv4.conf.all.rp_filter = 1/g' /etc/sysctl.d/99-security.conf
    sed -i 's/net.ipv4.conf.default.rp_filter = 2/net.ipv4.conf.default.rp_filter = 1/g' /etc/sysctl.d/99-security.conf
else
    # Datei erstellen, wenn sie nicht existiert
    log_message "Erstelle die Datei /etc/sysctl.d/99-security.conf..."
    cat > /etc/sysctl.d/99-security.conf << EOF
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Block SYN attacks
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Log Martians
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Increase system file descriptor limit
fs.file-max = 65535
EOF
fi

# RP-Filter-Parameter direkt setzen
log_message "Setze die RP-Filter-Parameter direkt..."
sysctl -w net.ipv4.conf.all.rp_filter=1
sysctl -w net.ipv4.conf.default.rp_filter=1

# Alle Kernel-Parameter anwenden
log_message "Wende alle Kernel-Parameter an..."
sysctl -p /etc/sysctl.d/99-security.conf
log_success "Kernel-Sicherheitseinstellungen korrigiert."

# 3. Logging und Audit
log_message "3. Logging und Audit werden korrigiert..."

# Prüfen, ob auditd installiert ist
if ! dpkg -l | grep -q ' auditd '; then
    log_warning "Auditd ist nicht installiert. Installation wird durchgeführt..."
    apt update -q
    apt install -yq auditd
fi

# Prüfen, ob das Verzeichnis für Audit-Regeln existiert
if [ ! -d "/etc/audit/rules.d" ]; then
    log_message "Erstelle Verzeichnis /etc/audit/rules.d..."
    mkdir -p /etc/audit/rules.d
fi

# Basis-Audit-Regeln für Systemaufrufe erstellen
log_message "Erstelle die Audit-Regeldatei /etc/audit/rules.d/audit.rules..."
cat > /etc/audit/rules.d/audit.rules << EOF
# Prüfung von Dateizugriffen
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k identity

# Überwachung von Systemaufrufen
-a exit,always -F arch=b64 -S sethostname -S setdomainname -k system-locale
-a exit,always -F arch=b32 -S sethostname -S setdomainname -k system-locale
-w /etc/issue -p wa -k system-locale
-w /etc/hostname -p wa -k system-locale

# Überwachung von Benutzer- und Gruppenverwaltung
-w /usr/bin/passwd -p x -k passwd_modification
-w /usr/bin/groupadd -p x -k group_modification
-w /usr/bin/groupmod -p x -k group_modification
-w /usr/bin/groupdel -p x -k group_modification
-w /usr/bin/useradd -p x -k user_modification
-w /usr/bin/usermod -p x -k user_modification
-w /usr/bin/userdel -p x -k user_modification
EOF

# Audit-Dienst aktivieren und starten
log_message "Aktiviere und starte den Audit-Dienst..."
systemctl enable auditd
systemctl start auditd

# Audit-Dienst neu starten um neue Regeln zu laden
log_message "Starte den Audit-Dienst neu um die neuen Regeln zu laden..."
systemctl restart auditd
log_success "Logging und Audit korrigiert."

# Überprüfen, ob alle Korrekturen erfolgreich waren
log_message "4. Überprüfung der durchgeführten Korrekturen..."

# Überprüfen, ob die Fail2Ban-Konfigurationsdatei existiert
if [ -f "/etc/fail2ban/jail.local" ]; then
    log_success "Fail2Ban-Konfigurationsdatei existiert."
else
    log_error "Fail2Ban-Konfigurationsdatei konnte nicht erstellt werden."
fi

# Überprüfen, ob die RP-Filter-Parameter korrekt gesetzt sind
if [ "$(sysctl -n net.ipv4.conf.all.rp_filter)" = "1" ] && [ "$(sysctl -n net.ipv4.conf.default.rp_filter)" = "1" ]; then
    log_success "RP-Filter-Parameter sind korrekt gesetzt."
else
    log_error "RP-Filter-Parameter konnten nicht korrekt gesetzt werden."
fi

# Überprüfen, ob der Audit-Dienst aktiv ist
if systemctl is-active --quiet auditd; then
    log_success "Audit-Dienst ist aktiv."
else
    log_error "Audit-Dienst konnte nicht aktiviert werden."
fi

# Überprüfen, ob die Audit-Regeldatei existiert
if [ -f "/etc/audit/rules.d/audit.rules" ]; then
    log_success "Audit-Regeldatei existiert."
else
    log_error "Audit-Regeldatei konnte nicht erstellt werden."
fi

# Zusammenfassung
log_success "===== VPS-Vorbereitung Korrekturen abgeschlossen ====="
log_message "Die bei den E2E-Tests identifizierten Probleme wurden behoben."
log_message "Logdatei: $LOG_FILE"
log_message ""
log_message "Bitte führen Sie die E2E-Tests erneut durch, um zu überprüfen, ob alle Probleme behoben wurden."

exit 0