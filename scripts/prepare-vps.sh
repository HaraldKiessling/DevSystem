#!/bin/bash
#
# DevSystem - VPS Preparation Script
# Autor: DevSystem Team
# Datum: 2026-04-08
#
# Beschreibung: 
# Dieses Script bereitet einen Ubuntu VPS für die Installation von DevSystem vor.
# Es führt folgende Aktionen aus:
# - Systemaktualisierung
# - Installation notwendiger Pakete
# - Konfiguration der Firewall (UFW)
# - Grundlegende Systemhärtung
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
LOG_FILE="/var/log/devsystem-prepare-vps.log"
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

# Prüfen, ob es sich um ein Ubuntu-System handelt
if [ ! -f /etc/lsb-release ]; then
    log_error "Dieses Script wurde für Ubuntu-Systeme entwickelt. Andere Distributionen werden nicht unterstützt."
    exit 1
fi

# Willkommensnachricht
log_message "===== DevSystem VPS Preparation ====="
log_message "Vorbereitung des Ubuntu VPS für DevSystem wird gestartet..."

# 1. System aktualisieren
log_message "1. Systemaktualisierung wird durchgeführt..."
apt update -q
apt upgrade -yq
log_success "Systemaktualisierung abgeschlossen."

# 2. Notwendige Pakete installieren
log_message "2. Notwendige Pakete werden installiert..."
PACKAGES="curl wget git unzip apt-transport-https ca-certificates gnupg lsb-release software-properties-common ufw fail2ban"
apt install -yq $PACKAGES
log_success "Paketinstallation abgeschlossen."

# 3. Firewall (UFW) konfigurieren
log_message "3. Firewall (UFW) wird konfiguriert..."
# Standardregeln setzen
ufw default deny incoming
ufw default allow outgoing

# SSH-Port erlauben
ufw allow 22/tcp

# UFW aktivieren, wenn es nicht bereits aktiv ist
if ! ufw status | grep -q "Status: active"; then
    log_message "Aktiviere UFW Firewall..."
    echo "y" | ufw enable
fi
log_success "Firewall-Konfiguration abgeschlossen."

# 4. Grundlegende Systemhärtung
log_message "4. Grundlegende Systemhärtung wird durchgeführt..."

# 4.1 SSH-Sicherung
log_message "4.1 SSH-Konfiguration wird gesichert..."
SSH_CONFIG="/etc/ssh/sshd_config"

# Backup der SSH-Konfiguration
cp $SSH_CONFIG "${SSH_CONFIG}.backup.$(date '+%Y-%m-%d')"

# SSH-Einstellungen sichern
sed -i 's/#PermitRootLogin yes/PermitRootLogin prohibit-password/' $SSH_CONFIG
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' $SSH_CONFIG
sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/' $SSH_CONFIG
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' $SSH_CONFIG

# SSH-Dienst neu starten
systemctl restart sshd
log_success "SSH-Konfiguration gesichert."

# 4.2 Fail2Ban konfigurieren
log_message "4.2 Fail2Ban wird konfiguriert..."
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
EOF
systemctl enable fail2ban
systemctl restart fail2ban
log_success "Fail2Ban konfiguriert."

# 4.3 Systemhärtung: Kernel-Parameter
log_message "4.3 Kernel-Parameter werden für erhöhte Sicherheit angepasst..."
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

# Kernel-Parameter anwenden
sysctl -p /etc/sysctl.d/99-security.conf
log_success "Kernel-Parameter angepasst."

# 4.4 Automatische Sicherheitsupdates konfigurieren
log_message "4.4 Automatische Sicherheitsupdates werden konfiguriert..."
apt install -yq unattended-upgrades
cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}";
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
};
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
log_success "Automatische Sicherheitsupdates konfiguriert."

# 4.5 Logging und Audit verbessern
log_message "4.5 Logging und Audit werden verbessert..."
apt install -yq auditd
systemctl enable auditd
systemctl start auditd

# Basis-Audit-Regeln für Systemaufrufe
cat > /etc/audit/rules.d/audit.rules << EOF
# Prüfung von Dateizugriffen
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k sudoers

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
systemctl restart auditd
log_success "Logging und Audit verbessert."

# 5. Überprüfen, ob alle Schritte erfolgreich waren
log_message "5. Überprüfung der durchgeführten Maßnahmen..."

# Überprüfen, ob die Firewall aktiv ist
if ufw status | grep -q "Status: active"; then
    log_success "Firewall ist aktiv."
else
    log_error "Firewall konnte nicht aktiviert werden."
    exit 1
fi

# Überprüfen, ob Fail2Ban aktiv ist
if systemctl is-active --quiet fail2ban; then
    log_success "Fail2Ban ist aktiv."
else
    log_error "Fail2Ban konnte nicht aktiviert werden."
    exit 1
fi

# Zusammenfassung
log_success "===== VPS-Vorbereitung abgeschlossen ====="
log_message "Der Ubuntu VPS wurde erfolgreich für DevSystem vorbereitet."
log_message "Das System wurde aktualisiert, notwendige Pakete installiert,"
log_message "die Firewall konfiguriert und grundlegende Sicherheitsmaßnahmen implementiert."
log_message ""
log_message "Logdatei: $LOG_FILE"
log_message ""
log_message "Als Nächstes können Sie mit der Installation von Tailscale fortfahren."

exit 0