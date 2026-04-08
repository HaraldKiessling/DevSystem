# Sicherheitskonzept für DevSystem

Dieses Dokument beschreibt ein umfassendes Sicherheitskonzept für das DevSystem-Projekt. Es deckt alle relevanten Sicherheitsaspekte ab, von der Netzwerksicherheit über Authentifizierung und Autorisierung bis hin zu Datensicherheit, Systemhärtung, Überwachung und Incident Response.

## Inhaltsverzeichnis

1. [Netzwerksicherheit](#1-netzwerksicherheit)
   - [Zero-Trust-Architektur mit Tailscale](#11-zero-trust-architektur-mit-tailscale)
   - [Firewall-Konfiguration](#12-firewall-konfiguration)
   - [Netzwerksegmentierung](#13-netzwerksegmentierung)

2. [Authentifizierung und Autorisierung](#2-authentifizierung-und-autorisierung)
   - [Zugriffskontrollen für alle Komponenten](#21-zugriffskontrollen-für-alle-komponenten)
   - [Multi-Faktor-Authentifizierung](#22-multi-faktor-authentifizierung)
   - [Berechtigungsmanagement](#23-berechtigungsmanagement)

3. [Datensicherheit](#3-datensicherheit)
   - [Verschlüsselung im Ruhezustand](#31-verschlüsselung-im-ruhezustand)
   - [Verschlüsselung bei der Übertragung](#32-verschlüsselung-bei-der-übertragung)
   - [Sichere Speicherung von Secrets](#33-sichere-speicherung-von-secrets)

4. [Systemhärtung](#4-systemhärtung)
   - [OS-Härtung für Ubuntu](#41-os-härtung-für-ubuntu)
   - [Minimierung der Angriffsfläche](#42-minimierung-der-angriffsfläche)
   - [Regelmäßige Updates und Patches](#43-regelmäßige-updates-und-patches)

5. [Überwachung und Logging](#5-überwachung-und-logging)
   - [Zentrale Protokollierung](#51-zentrale-protokollierung)
   - [Intrusion Detection](#52-intrusion-detection)
   - [Anomalieerkennung](#53-anomalieerkennung)

6. [Incident Response](#6-incident-response)
   - [Notfallplan bei Sicherheitsvorfällen](#61-notfallplan-bei-sicherheitsvorfällen)
   - [Wiederherstellungsprozesse](#62-wiederherstellungsprozesse)
   - [Kommunikationsplan](#63-kommunikationsplan)

7. [Compliance und Best Practices](#7-compliance-und-best-practices)
   - [Einhaltung von Industriestandards](#71-einhaltung-von-industriestandards)
   - [Regelmäßige Sicherheitsaudits](#72-regelmäßige-sicherheitsaudits)
   - [Dokumentation von Sicherheitsmaßnahmen](#73-dokumentation-von-sicherheitsmaßnahmen)

## 1. Netzwerksicherheit

### 1.1 Zero-Trust-Architektur mit Tailscale

Die Netzwerksicherheit des DevSystem basiert auf dem Zero-Trust-Prinzip, bei dem jeder Zugriff explizit autorisiert werden muss, unabhängig davon, ob er von innerhalb oder außerhalb des Netzwerks erfolgt. Tailscale wird als primäre VPN-Lösung eingesetzt, um dieses Prinzip umzusetzen.

#### Implementierungsdetails:

1. **Identitätsbasierte Authentifizierung**:
   - Jeder Benutzer und jedes Gerät wird eindeutig identifiziert und authentifiziert.
   - Integration mit Identity Providern (Google, Microsoft, GitHub) für die Benutzerauthentifizierung.
   - Gerätebasierte Authentifizierung mit eindeutigen Schlüsseln für jedes Gerät.

2. **Least-Privilege-Prinzip**:
   - Standardmäßig hat kein Gerät Zugriff auf andere Geräte im Tailnet.
   - Zugriffe werden explizit über Access Control Lists (ACLs) definiert.
   - Temporäre Zugriffsrechte können bei Bedarf gewährt und automatisch entzogen werden.

3. **Ende-zu-Ende-Verschlüsselung**:
   - Sämtlicher Datenverkehr zwischen Geräten im Tailnet wird Ende-zu-Ende verschlüsselt.
   - Verwendung von WireGuard als Basis-Protokoll mit moderner Kryptographie.
   - Perfect Forward Secrecy für alle Verbindungen.

4. **Tailscale-Konfiguration**:
```json
{
  "acls": [
    {
      "action": "accept",
      "users": ["admin@example.com"],
      "ports": ["*:*"]
    },
    {
      "action": "accept",
      "users": ["developer@example.com"],
      "ports": ["devsystem-vps:22", "code.devsystem.internal:443", "ollama.devsystem.internal:443"]
    },
    {
      "action": "accept",
      "users": ["monitoring@example.com"],
      "ports": ["devsystem-vps:9100", "devsystem-vps:9090"]
    }
  ],
  "tagOwners": {
    "tag:server": ["admin@example.com"],
    "tag:developer": ["admin@example.com"],
    "tag:monitoring": ["admin@example.com"]
  },
  "hosts": {
    "devsystem-vps": "100.x.y.z",
    "code.devsystem.internal": "100.x.y.z",
    "ollama.devsystem.internal": "100.x.y.z"
  }
}
```

### 1.2 Firewall-Konfiguration

Die Ubuntu-Firewall (UFW) wird so konfiguriert, dass sie nur Verbindungen über Tailscale und lokale Verbindungen zulässt. Alle anderen eingehenden Verbindungen werden standardmäßig blockiert.

#### Implementierungsdetails:

1. **Basis-Konfiguration**:
```bash
# Firewall zurücksetzen und standardmäßig eingehende Verbindungen blockieren
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Lokale Verbindungen erlauben
sudo ufw allow from 127.0.0.1
```

2. **Tailscale-Konfiguration**:
```bash
# Tailscale-Schnittstelle erlauben
sudo ufw allow in on tailscale0

# Tailscale UDP-Port für die Verbindung zum Koordinationsserver
sudo ufw allow 41641/udp
```

3. **Notfall-Zugriff** (optional, nur für Administratoren):
```bash
# SSH-Zugriff von bestimmten vertrauenswürdigen IP-Adressen erlauben
sudo ufw allow from 203.0.113.1 to any port 22 proto tcp
```

4. **Aktivierung der Firewall**:
```bash
# Firewall aktivieren
sudo ufw enable

# Firewall-Status überprüfen
sudo ufw status verbose
```

5. **Automatische Firewall-Regeln bei Systemstart**:
```bash
# Skript zur Wiederherstellung der Firewall-Regeln
cat > /usr/local/bin/restore-firewall.sh << EOF
#!/bin/bash
# Warten auf Tailscale-Initialisierung
sleep 30
# Tailscale-Schnittstelle erlauben
sudo ufw allow in on tailscale0
EOF

# Skript ausführbar machen
chmod +x /usr/local/bin/restore-firewall.sh

# Cron-Job für Systemstart einrichten
echo "@reboot root /usr/local/bin/restore-firewall.sh" | sudo tee -a /etc/crontab
```

### 1.3 Netzwerksegmentierung

Die Netzwerksegmentierung wird durch die Kombination von Tailscale ACLs und lokalen Firewall-Regeln erreicht. Dies ermöglicht eine granulare Kontrolle darüber, welche Dienste für welche Benutzer zugänglich sind.

#### Implementierungsdetails:

1. **Dienst-Segmentierung**:
   - Jeder Dienst (code-server, Ollama, etc.) wird auf einem eigenen Port betrieben.
   - Zugriff auf diese Ports wird über Tailscale ACLs und lokale Firewall-Regeln kontrolliert.

2. **Benutzergruppen**:
   - **Administratoren**: Vollzugriff auf alle Dienste und Ports.
   - **Entwickler**: Zugriff auf code-server, SSH und Ollama.
   - **Monitoring**: Zugriff auf Monitoring-Ports und -Dienste.

3. **Netzwerk-Isolation**:
```bash
# Lokale Firewall-Regeln für Dienst-Isolation
# Nur localhost und Tailscale dürfen auf code-server zugreifen
sudo iptables -A INPUT -p tcp --dport 8080 -i lo -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 8080 -i tailscale0 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 8080 -j DROP

# Nur localhost und Tailscale dürfen auf Ollama zugreifen
sudo iptables -A INPUT -p tcp --dport 11434 -i lo -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 11434 -i tailscale0 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 11434 -j DROP
```

4. **Persistente iptables-Regeln**:
```bash
# iptables-Regeln speichern
sudo apt install -y iptables-persistent
sudo netfilter-persistent save
```

## 2. Authentifizierung und Autorisierung

### 2.1 Zugriffskontrollen für alle Komponenten

Jede Komponente des DevSystem wird mit spezifischen Zugriffskontrollen konfiguriert, um sicherzustellen, dass nur autorisierte Benutzer Zugriff haben.

#### Implementierungsdetails:

1. **Tailscale**:
   - Authentifizierung über Identity Provider (Google, Microsoft, GitHub).
   - Autorisierung über ACLs auf Basis von Benutzeridentitäten und Geräten.
   - Automatische Schlüsselrotation für erhöhte Sicherheit.

2. **Caddy (Reverse Proxy)**:
```
# Nur Zugriff über Tailscale erlauben
@tailscale {
    remote_ip 100.64.0.0/10
}

# Zugriff verweigern, wenn nicht über Tailscale
respond !@tailscale 403 {
    body "Zugriff nur über Tailscale erlaubt"
}
```

3. **code-server**:
```yaml
# ~/.config/code-server/config.yaml
bind-addr: 127.0.0.1:8080
auth: none  # Authentifizierung wird durch Tailscale übernommen
cert: false # SSL-Terminierung erfolgt durch Caddy
```

4. **SSH-Zugriff**:
```bash
# SSH nur über Tailscale erlauben
echo "AllowUsers *@100.64.0.0/10" | sudo tee -a /etc/ssh/sshd_config
echo "PasswordAuthentication no" | sudo tee -a /etc/ssh/sshd_config
echo "PubkeyAuthentication yes" | sudo tee -a /etc/ssh/sshd_config
sudo systemctl restart sshd
```

5. **Ollama**:
```
# Caddy-Konfiguration für Ollama
ollama.devsystem.internal {
    # Nur Zugriff über Tailscale erlauben
    @tailscale {
        remote_ip 100.64.0.0/10
    }
    
    # Reverse Proxy zu Ollama
    reverse_proxy @tailscale localhost:11434
    
    # Zugriff verweigern, wenn nicht über Tailscale
    respond !@tailscale 403
}
```

### 2.2 Multi-Faktor-Authentifizierung

Multi-Faktor-Authentifizierung (MFA) wird für alle kritischen Zugangspunkte implementiert, um die Sicherheit zu erhöhen.

#### Implementierungsdetails:

1. **Tailscale MFA**:
   - Aktivierung von MFA über den Identity Provider (Google, Microsoft, GitHub).
   - Unterstützung für TOTP-basierte Authenticator-Apps.
   - Unterstützung für Hardware-Sicherheitsschlüssel (FIDO2/WebAuthn).

2. **SSH-MFA** (optional für zusätzliche Sicherheit):
```bash
# Installation von libpam-google-authenticator
sudo apt install -y libpam-google-authenticator

# Konfiguration von PAM für SSH
echo "auth required pam_google_authenticator.so" | sudo tee -a /etc/pam.d/sshd

# Aktivierung von Challenge-Response-Authentifizierung in SSH
sudo sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl restart sshd

# Einrichtung für Benutzer
google-authenticator
```

3. **Notfallzugriff**:
   - Generierung von Wiederherstellungscodes für den Notfall.
   - Sichere Speicherung dieser Codes an einem physisch sicheren Ort.
   - Dokumentierter Prozess für die Verwendung von Wiederherstellungscodes.

### 2.3 Berechtigungsmanagement

Ein detailliertes Berechtigungsmanagement wird implementiert, um sicherzustellen, dass Benutzer nur auf die Ressourcen zugreifen können, die sie für ihre Arbeit benötigen.

#### Implementierungsdetails:

1. **Benutzergruppen und Rollen**:
   - **Admin**: Vollzugriff auf alle Systeme und Dienste.
   - **Developer**: Zugriff auf code-server, SSH und Ollama.
   - **Viewer**: Nur-Lese-Zugriff auf bestimmte Ressourcen.

2. **Tailscale ACLs für Rollenbasierte Zugriffskontrolle**:
```json
{
  "acls": [
    {
      "action": "accept",
      "users": ["group:admin"],
      "ports": ["*:*"]
    },
    {
      "action": "accept",
      "users": ["group:developer"],
      "ports": ["devsystem-vps:22", "code.devsystem.internal:443", "ollama.devsystem.internal:443"]
    },
    {
      "action": "accept",
      "users": ["group:viewer"],
      "ports": ["code.devsystem.internal:443"]
    }
  ],
  "groups": {
    "group:admin": ["admin1@example.com", "admin2@example.com"],
    "group:developer": ["dev1@example.com", "dev2@example.com"],
    "group:viewer": ["viewer1@example.com", "viewer2@example.com"]
  }
}
```

3. **Berechtigungen innerhalb von code-server**:
   - Verwendung von Git-Hooks zur Durchsetzung von Code-Review-Prozessen.
   - Konfiguration von Workspace-Berechtigungen für verschiedene Benutzergruppen.

4. **Regelmäßige Überprüfung der Berechtigungen**:
```bash
#!/bin/bash
# /usr/local/bin/audit-permissions.sh

# Tailscale-ACLs überprüfen
tailscale acl status

# Lokale Benutzer und Gruppen überprüfen
echo "Lokale Benutzer mit sudo-Rechten:"
grep -Po '^sudo.+:\K.*$' /etc/group | tr ',' '\n'

# SSH-Autorisierte Schlüssel überprüfen
for user in $(ls /home); do
  if [ -f "/home/$user/.ssh/authorized_keys" ]; then
    echo "Autorisierte SSH-Schlüssel für $user:"
    cat "/home/$user/.ssh/authorized_keys"
  fi
done
```

5. **Automatisierte Berechtigungsprüfung**:
```bash
# Monatliche Ausführung des Audit-Skripts
echo "0 0 1 * * root /usr/local/bin/audit-permissions.sh > /var/log/permissions-audit-$(date +\%Y\%m).log" | sudo tee -a /etc/crontab
```

## 3. Datensicherheit

### 3.1 Verschlüsselung im Ruhezustand

Alle sensiblen Daten werden im Ruhezustand verschlüsselt, um sie vor unbefugtem Zugriff zu schützen, selbst wenn physischer Zugriff auf die Speichermedien besteht.

#### Implementierungsdetails:

1. **Festplattenverschlüsselung**:
```bash
# Installation von cryptsetup
sudo apt install -y cryptsetup

# Verschlüsselung einer zusätzlichen Datenpartition (falls vorhanden)
sudo cryptsetup luksFormat /dev/sdXY
sudo cryptsetup luksOpen /dev/sdXY encrypted_data
sudo mkfs.ext4 /dev/mapper/encrypted_data
sudo mkdir -p /mnt/encrypted_data
sudo mount /dev/mapper/encrypted_data /mnt/encrypted_data

# Automatisches Einbinden beim Systemstart (erfordert Passphrase-Eingabe)
echo "/dev/sdXY /mnt/encrypted_data ext4 defaults 0 2" | sudo tee -a /etc/fstab
```

2. **Verschlüsselung sensibler Dateien**:
```bash
# Installation von GnuPG
sudo apt install -y gnupg

# Generierung eines GPG-Schlüsselpaars
gpg --full-generate-key

# Verschlüsselung sensibler Dateien
gpg --encrypt --recipient user@example.com sensitive_file.txt

# Automatisierte Verschlüsselung von Backup-Dateien
cat > /usr/local/bin/encrypt-backup.sh << EOF
#!/bin/bash
# Verschlüsselung des Backup-Verzeichnisses
tar -czf - /var/backups | gpg --encrypt --recipient admin@example.com > /var/backups/encrypted_backup_$(date +%Y%m%d).tar.gz.gpg
EOF
chmod +x /usr/local/bin/encrypt-backup.sh
```

3. **Sichere Speicherung von Anmeldeinformationen**:
```bash
# Installation von pass (Password Store)
sudo apt install -y pass

# Initialisierung des Password Store
pass init user@example.com

# Speicherung von Anmeldeinformationen
pass insert DevSystem/code-server
pass insert DevSystem/tailscale
pass insert DevSystem/ssh

# Abrufen von Anmeldeinformationen
pass DevSystem/code-server
```

### 3.2 Verschlüsselung bei der Übertragung

Alle Datenübertragungen werden verschlüsselt, um die Vertraulichkeit und Integrität der Daten während der Übertragung zu gewährleisten.

#### Implementierungsdetails:

1. **HTTPS für alle Webdienste**:
   - Verwendung von Tailscale-Zertifikaten oder selbstsignierten Zertifikaten für interne Dienste.
   - Konfiguration von Caddy für HTTPS-Terminierung.
   - Strikte Sicherheitsheader für alle HTTP-Antworten.

2. **Caddy-Konfiguration für HTTPS**:
```
# Globale TLS-Einstellungen
{
    servers {
        protocol {
            min_tls_version 1.2
            cipher_suites TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384 TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256 TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256
        }
    }
}

# Domainspezifische TLS-Einstellungen
code.devsystem.internal {
    tls /etc/caddy/tls/tailscale/code.devsystem.internal.crt /etc/caddy/tls/tailscale/code.devsystem.internal.key
    
    # HSTS und andere Sicherheitsheader
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-XSS-Protection "1; mode=block"
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "strict-origin-when-cross-origin"
        Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' wss:; frame-ancestors 'self';"
    }
}
```

3. **SSH-Konfiguration für sichere Übertragung**:
```bash
# Sichere SSH-Konfiguration
sudo tee /etc/ssh/sshd_config.d/secure.conf << EOF
# Nur sichere Protokolle und Cipher erlauben
Protocol 2
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com

# Andere Sicherheitseinstellungen
PermitRootLogin no
MaxAuthTries 3
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
X11Forwarding no
EOF

sudo systemctl restart sshd
```

4. **Tailscale für Ende-zu-Ende-Verschlüsselung**:
   - Tailscale verwendet WireGuard für die Verschlüsselung aller Datenübertragungen.
   - Jede Verbindung ist Ende-zu-Ende verschlüsselt mit Perfect Forward Secrecy.
   - Regelmäßige Schlüsselrotation für erhöhte Sicherheit.

### 3.3 Sichere Speicherung von Secrets

Secrets wie API-Schlüssel, Passwörter und Zertifikate werden sicher gespeichert und verwaltet, um unbefugten Zugriff zu verhindern.

#### Implementierungsdetails:

1. **Verwendung von HashiCorp Vault** (für fortgeschrittene Setups):
```bash
# Installation von HashiCorp Vault
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt update && sudo apt install -y vault

# Konfiguration von Vault
sudo mkdir -p /etc/vault.d
sudo tee /etc/vault.d/vault.hcl << EOF
storage "file" {
  path = "/var/lib/vault"
}

listener "tcp" {
  address = "127.0.0.1:8200"
  tls_disable = 1
}

api_addr = "http://127.0.0.1:8200"
ui = true
EOF

# Starten von Vault
sudo systemctl enable vault
sudo systemctl start vault

# Initialisierung von Vault
export VAULT_ADDR='http://127.0.0.1:8200'
vault operator init
```

2. **Verwendung von systemd-creds** (für einfachere Setups):
```bash
# Speichern eines Secrets
echo "mein_geheimes_passwort" | sudo systemd-creds encrypt --name=code-server-password - /etc/systemd/system/code-server.service.d/credentials/

# Verwendung des Secrets in einem systemd-Service
sudo mkdir -p /etc/systemd/system/code-server.service.d
sudo tee /etc/systemd/system/code-server.service.d/credentials.conf << EOF
[Service]
LoadCredential=code-server-password:/etc/systemd/system/code-server.service.d/credentials/code-server-password
Environment=PASSWORD=%d/code-server-password
EOF

sudo systemctl daemon-reload
sudo systemctl restart code-server@$USER
```

3. **Verwendung von .env-Dateien mit eingeschränkten Berechtigungen**:
```bash
# Erstellen einer .env-Datei für Umgebungsvariablen
sudo tee /etc/devsystem.env << EOF
OPENROUTER_API_KEY=your_api_key_here
OLLAMA_HOST=http://localhost:11434
EOF

# Berechtigungen einschränken
sudo chmod 600 /etc/devsystem.env
sudo chown root:root /etc/devsystem.env

# Verwendung in einem Service
sudo tee /etc/systemd/system/code-server.service.d/env.conf << EOF
[Service]
EnvironmentFile=/etc/devsystem.env
EOF

sudo systemctl daemon-reload
sudo systemctl restart code-server@$USER
```

4. **Sichere Speicherung von SSH-Schlüsseln**:
```bash
# Berechtigungen für SSH-Verzeichnis und Schlüssel
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
chmod 600 ~/.ssh/authorized_keys
```

## 4. Systemhärtung

### 4.1 OS-Härtung für Ubuntu

Das Ubuntu-Betriebssystem wird gehärtet, um die Sicherheit zu erhöhen und die Angriffsfläche zu reduzieren.

#### Implementierungsdetails:

1. **Basis-Härtung**:
```bash
# Installation von Sicherheitstools
sudo apt update
sudo apt install -y unattended-upgrades apt-listchanges fail2ban rkhunter lynis

# Konfiguration von automatischen Sicherheitsupdates
sudo dpkg-reconfigure -plow unattended-upgrades

# Konfiguration von fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo tee -a /etc/fail2ban/jail.local << EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF

sudo systemctl enable fail2ban
sudo systemctl restart fail2ban
```

2. **Kernel-Härtung**:
```bash
# Sysctl-Einstellungen für erhöhte Sicherheit
sudo tee /etc/sysctl.d/99-security.conf << EOF
# IP-Spoofing-Schutz
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# TCP SYN Flood-Schutz
net.ipv4.tcp_syncookies = 1

# IP-Forwarding deaktivieren (falls nicht benötigt)
net.ipv4.ip_forward = 0

# ICMP-Redirects ignorieren
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Protokollierung von Martian-Paketen
net.ipv4.conf.all.log_martians = 1

# Schutz vor Time-Wait-Assassination
net.ipv4.tcp_rfc1337 = 1

# Kernel-Pointer-Schutz
kernel.kptr_restrict = 1

# Speicherzugriffsbeschränkungen
kernel.yama.ptrace_scope = 1

# ASLR aktivieren
kernel.randomize_va_space = 2
EOF

# Sysctl-Einstellungen anwenden
sudo sysctl -p /etc/sysctl.d/99-security.conf
```

3. **Benutzer- und Gruppensicherheit**:
```bash
# Sichere Passwortrichtlinien
sudo apt install -y libpam-pwquality
sudo tee -a /etc/security/pwquality.conf << EOF
minlen = 12
minclass = 3
maxrepeat = 2
gecoscheck = 1
dictcheck = 1
EOF

# Passwort-Aging-Richtlinien
sudo tee /etc/login.defs << EOF
PASS_MAX_DAYS   90
PASS_MIN_DAYS   1
PASS_WARN_AGE   7
EOF

# Berechtigungen für sensible Dateien
sudo chmod 640 /etc/shadow
sudo chmod 644 /etc/passwd
```

4. **Deaktivierung nicht benötigter Dienste**:
```bash
# Liste der laufenden Dienste anzeigen
systemctl list-units --type=service --state=running

# Nicht benötigte Dienste deaktivieren (