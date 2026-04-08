#!/bin/bash
#
# Caddy Installationsskript für DevSystem
# Dieses Skript automatisiert die Installation und Konfiguration von Caddy
# als Reverse Proxy auf einem Ubuntu VPS für das DevSystem Projekt.
#
# Version: 1.0
# Autor: DevSystem Team
# Datum: $(date +%Y-%m-%d)
#
# Funktionen:
# - Installation von Caddy auf dem Ubuntu VPS
# - Konfiguration für automatischen Start
# - Erstellung der grundlegenden Verzeichnisstruktur
# - Grundlegende Konfiguration als Reverse Proxy
# - Integration mit Tailscale für HTTPS-Zertifikate
# - Sicherheitskonfiguration gemäß dem Sicherheitskonzept
#
# Verwendung: sudo bash install-caddy.sh [--hostname=NAME] [--config-only]

# Fehler bei der Ausführung beenden das Skript
set -e

# Farbdefinitionen für Terminal-Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging-Funktion
log() {
    local level=$1
    local message=$2
    local color=$NC
    
    case $level in
        "INFO") color=$GREEN ;;
        "WARN") color=$YELLOW ;;
        "ERROR") color=$RED ;;
        "STEP") color=$BLUE ;;
    esac
    
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message${NC}"
}

# Fehlermeldung und Exit-Funktion
error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Root-Berechtigungen prüfen
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error_exit "Dieses Skript muss als Root ausgeführt werden. Bitte verwenden Sie 'sudo'."
    fi
}

# Kommandozeilenargumente parsen
parse_args() {
    CONFIG_ONLY=false
    
    for arg in "$@"; do
        case $arg in
            --hostname=*)
                HOSTNAME="${arg#*=}"
                ;;
            --config-only)
                CONFIG_ONLY=true
                ;;
            --help)
                echo "Verwendung: sudo bash install-caddy.sh [--hostname=NAME] [--config-only]"
                echo ""
                echo "Optionen:"
                echo "  --hostname=NAME     Spezifiziert den Hostnamen des VPS im Tailscale-Netzwerk"
                echo "  --config-only       Nur Konfiguration durchführen, keine Installation"
                echo ""
                exit 0
                ;;
        esac
    done
    
    # Standardwerte setzen, falls nicht angegeben
    HOSTNAME=${HOSTNAME:-"devsystem-vps"}
}

# Systemvoraussetzungen prüfen
check_prerequisites() {
    log "STEP" "Prüfe Systemvoraussetzungen..."
    
    # Prüfen, ob Ubuntu verwendet wird
    if [ ! -f /etc/lsb-release ] || ! grep -q "Ubuntu" /etc/lsb-release; then
        error_exit "Dieses Skript ist für Ubuntu-Systeme ausgelegt. Ihre Distribution wird nicht unterstützt."
    fi
    
    # Prüfen, ob Tailscale installiert ist
    if ! command -v tailscale &> /dev/null; then
        log "WARN" "Tailscale scheint nicht installiert zu sein. Es wird für die HTTPS-Zertifikate benötigt."
        log "WARN" "Bitte installieren Sie Tailscale zuerst mit dem install-tailscale.sh Skript."
    fi
    
    # Prüfen, ob die erforderlichen Befehle installiert sind
    for cmd in apt-get curl systemctl; do
        if ! command -v $cmd &> /dev/null; then
            error_exit "Der Befehl '$cmd' wird benötigt, ist aber nicht installiert."
        fi
    done
    
    log "INFO" "Systemvoraussetzungen erfüllt."
}

# Prüfen, ob Caddy bereits installiert ist
check_caddy() {
    if command -v caddy &> /dev/null; then
        log "WARN" "Caddy ist bereits installiert. Überspringe die Installation."
        return 0
    else
        return 1
    fi
}

# Caddy installieren
install_caddy() {
    log "STEP" "Installiere Caddy..."
    
    # Aktualisieren der Paketlisten
    log "INFO" "Aktualisiere Paketlisten..."
    apt-get update -y || error_exit "Fehler beim Aktualisieren der Paketlisten."
    
    # Installation der erforderlichen Abhängigkeiten
    log "INFO" "Installiere erforderliche Abhängigkeiten..."
    apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl || error_exit "Fehler bei der Installation von Abhängigkeiten."
    
    # Hinzufügen des Caddy-Repositorys
    log "INFO" "Füge Caddy-Repository hinzu..."
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg || error_exit "Fehler beim Hinzufügen des Caddy-GPG-Schlüssels."
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list || error_exit "Fehler beim Hinzufügen des Caddy-Repositorys."
    
    # Aktualisieren der Paketlisten mit dem neuen Repository
    log "INFO" "Aktualisiere Paketlisten mit neuem Repository..."
    apt-get update -y || error_exit "Fehler beim Aktualisieren der Paketlisten nach Hinzufügen des Repositorys."
    
    # Installation von Caddy
    log "INFO" "Installiere Caddy-Paket..."
    apt-get install -y caddy || error_exit "Fehler bei der Installation von Caddy."
    
    log "INFO" "Caddy erfolgreich installiert."
}

# Caddy Verzeichnisstruktur erstellen
create_directory_structure() {
    log "STEP" "Erstelle Caddy-Verzeichnisstruktur..."
    
    # Erstelle Hauptverzeichnisse
    mkdir -p /etc/caddy/sites
    mkdir -p /etc/caddy/snippets
    mkdir -p /etc/caddy/tls/tailscale
    mkdir -p /etc/caddy/tls/local
    mkdir -p /var/log/caddy
    
    # Setze Berechtigungen
    chown -R caddy:caddy /etc/caddy
    chown -R caddy:caddy /var/log/caddy
    
    log "INFO" "Verzeichnisstruktur erfolgreich erstellt."
}

# Konfiguration für automatischen Start
configure_autostart() {
    log "STEP" "Konfiguriere automatischen Start..."
    
    # Wenn Caddy über das Paket-Repository installiert wurde, ist der Service bereits eingerichtet
    if systemctl list-unit-files | grep -q caddy.service; then
        log "INFO" "Caddy-Service ist bereits eingerichtet."
    else
        log "INFO" "Erstelle Systemd-Service für Caddy..."
        
        # Systemd-Service-Datei erstellen
        cat > /etc/systemd/system/caddy.service << EOF
[Unit]
Description=Caddy Web Server
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
    fi
    
    # Aktivieren des Caddy-Dienstes beim Systemstart
    systemctl enable caddy || error_exit "Fehler beim Aktivieren des Caddy-Dienstes für den Systemstart."
    
    # Überprüfen des Dienststatus
    if systemctl is-active caddy > /dev/null 2>&1; then
        log "INFO" "Caddy-Dienst läuft."
    else
        log "WARN" "Caddy-Dienst scheint nicht zu laufen. Starte Dienst..."
        systemctl start caddy
    fi
    
    log "INFO" "Automatischer Start erfolgreich konfiguriert."
}

# Erstellen der Grundkonfiguration (Caddyfile)
create_base_config() {
    log "STEP" "Erstelle grundlegende Caddyfile-Konfiguration..."
    
    # Erstellen der Hauptkonfigurationsdatei
    cat > /etc/caddy/Caddyfile << EOF
# Globale Optionen
{
    # Admin-API deaktivieren (Sicherheitsmaßnahme)
    admin off
    
    # Standardprotokoll auf HTTP/2 setzen
    servers {
        protocol {
            experimental_http3
            strict_sni_host
            min_tls_version 1.2
            cipher_suites TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384 TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256 TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256
        }
        
        # Verbindungs-Timeouts und Limits
        timeouts {
            read_body 30s
            read_header 10s
            write 60s
            idle 5m
        }
    }
    
    # Log-Einstellungen
    log {
        output file /var/log/caddy/access.log {
            roll_size 100MB
            roll_keep 10
            roll_keep_for 720h
        }
        format json
    }
}

# Gemeinsame Snippets importieren
import /etc/caddy/snippets/*.caddy

# Site-Konfigurationen importieren
import /etc/caddy/sites/*.caddy
EOF
    
    log "INFO" "Grundlegende Caddyfile-Konfiguration erstellt."
}

# Erstellen der Site-Konfigurationen
create_site_configs() {
    log "STEP" "Erstelle Site-Konfigurationen..."
    
    # code-server Konfiguration erstellen
    cat > /etc/caddy/sites/code-server.caddy << EOF
code.devsystem.internal {
    # Nur Zugriff über Tailscale erlauben
    @tailscale {
        remote_ip 100.64.0.0/10
    }
    
    # Reverse Proxy zu code-server
    reverse_proxy @tailscale localhost:8080 {
        # Header für WebSocket-Unterstützung
        header_up Connection {http.request.header.Connection}
        header_up Upgrade {http.request.header.Upgrade}
        
        # Timeouts erhöhen für lange Entwicklungssitzungen
        transport http {
            keepalive 30m
            keepalive_idle_conns 10
        }
    }
    
    # Zugriff verweigern, wenn nicht über Tailscale
    respond !@tailscale 403 {
        body "Zugriff nur über Tailscale erlaubt"
    }
    
    # Sicherheits-Header hinzufügen
    import /etc/caddy/snippets/security-headers.caddy
    
    # Logging
    log {
        output file /var/log/caddy/code-server.log {
            roll_size 10MB
            roll_keep 5
            roll_keep_for 720h
        }
    }
}
EOF
    
    # Ollama API Konfiguration erstellen
    cat > /etc/caddy/sites/ollama.caddy << EOF
ollama.devsystem.internal {
    # Nur Zugriff über Tailscale erlauben
    @tailscale {
        remote_ip 100.64.0.0/10
    }
    
    # Reverse Proxy zu Ollama
    reverse_proxy @tailscale localhost:11434 {
        # Timeouts erhöhen für lange Inferenz-Anfragen
        transport http {
            keepalive 5m
            keepalive_idle_conns 5
        }
    }
    
    # Zugriff verweigern, wenn nicht über Tailscale
    respond !@tailscale 403 {
        body "Zugriff nur über Tailscale erlaubt"
    }
    
    # Sicherheits-Header hinzufügen
    import /etc/caddy/snippets/security-headers.caddy
    
    # Rate Limiting für API-Anfragen
    rate_limit {
        zone ollama_api {
            key {remote_ip}
            events 100
            window 1m
        }
    }
    
    # Logging
    log {
        output file /var/log/caddy/ollama.log {
            roll_size 50MB
            roll_keep 5
            roll_keep_for 168h
        }
    }
}
EOF
    
    log "INFO" "Site-Konfigurationen erstellt."
}

# Erstellen der Sicherheitskonfiguration
create_security_config() {
    log "STEP" "Erstelle Sicherheitskonfiguration..."
    
    # Sicherheits-Header-Snippet erstellen
    cat > /etc/caddy/snippets/security-headers.caddy << EOF
header {
    # Strict-Transport-Security aktivieren
    Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    
    # XSS-Schutz aktivieren
    X-XSS-Protection "1; mode=block"
    
    # Clickjacking-Schutz
    X-Frame-Options "SAMEORIGIN"
    
    # MIME-Sniffing verhindern
    X-Content-Type-Options "nosniff"
    
    # Referrer-Policy einschränken
    Referrer-Policy "strict-origin-when-cross-origin"
    
    # Content-Security-Policy für erhöhte Sicherheit
    Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' wss:; frame-ancestors 'self';"
    
    # Entfernen von Server-Header
    -Server
}
EOF
    
    log "INFO" "Sicherheitskonfiguration erfolgreich erstellt."
}

# Firewall-Konfiguration für Caddy
configure_firewall() {
    log "STEP" "Konfiguriere Firewall für Caddy..."
    
    # Prüfen, ob UFW installiert ist
    if ! command -v ufw &> /dev/null; then
        log "INFO" "UFW (Uncomplicated Firewall) ist nicht installiert. Installiere UFW..."
        apt-get install -y ufw || error_exit "Fehler bei der Installation von UFW."
    fi
    
    log "INFO" "Konfiguriere UFW-Regeln für Caddy..."
    
    # Prüfen, ob UFW bereits aktiviert ist
    UFW_ENABLED=$(ufw status | grep -c "Status: active" || echo 0)
    
    # HTTP und HTTPS Ports freigeben für lokalen Zugriff
    ufw allow from 127.0.0.1 to any port 80
    ufw allow from 127.0.0.1 to any port 443
    
    # Tailscale Zugriff erlauben auf HTTP und HTTPS
    ufw allow in on tailscale0 to any port 80
    ufw allow in on tailscale0 to any port 443
    
    # Wenn UFW noch nicht aktiviert ist, aktivieren wir es
    if [ "$UFW_ENABLED" -eq 0 ]; then
        log "WARN" "UFW ist nicht aktiv. Aktivierung kann bestehende SSH-Verbindungen beeinträchtigen."
        log "WARN" "Stellen Sie sicher, dass SSH-Zugriff erlaubt ist, bevor Sie fortfahren."
        log "WARN" "Aktivieren Sie UFW manuell mit 'sudo ufw enable', wenn Sie sicher sind."
    else
        # UFW-Regeln neu laden
        ufw reload
        log "INFO" "Firewall-Regeln aktualisiert."
    fi
    
    log "INFO" "Firewall-Konfiguration für Caddy abgeschlossen."
}

# Tailscale-Zertifikate für HTTPS einrichten
setup_tailscale_certificates() {
    log "STEP" "Richte Tailscale-Zertifikate für HTTPS ein..."
    
    if ! command -v tailscale &> /dev/null; then
        log "ERROR" "Tailscale ist nicht installiert. Bitte installieren Sie Tailscale zuerst."
        return 1
    fi
    
    # Verzeichnis für Tailscale-Zertifikate
    CERT_DIR="/etc/caddy/tls/tailscale"
    
    # Tailscale-Zertifikate generieren
    log "INFO" "Generiere Tailscale-Zertifikate für $HOSTNAME..."
    if ! tailscale cert "$HOSTNAME.ts.net"; then
        log "WARN" "Konnte Tailscale-Zertifikat nicht generieren. Bitte prüfen Sie den Tailscale-Status."
        return 1
    fi
    
    # Zertifikate für Caddy verfügbar machen
    if [ -f "/var/lib/tailscale/certs/$HOSTNAME.ts.net.crt" ] && [ -f "/var/lib/tailscale/certs/$HOSTNAME.ts.net.key" ]; then
        cp "/var/lib/tailscale/certs/$HOSTNAME.ts.net.crt" "$CERT_DIR/"
        cp "/var/lib/tailscale/certs/$HOSTNAME.ts.net.key" "$CERT_DIR/"
        chown -R caddy:caddy "$CERT_DIR"
        chmod 600 "$CERT_DIR/$HOSTNAME.ts.net.key"
        log "INFO" "Tailscale-Zertifikate erfolgreich kopiert und Berechtigungen gesetzt."
    else
        log "WARN" "Tailscale-Zertifikate wurden nicht gefunden."
        return 1
    fi
    
    # Aktualisiere Site-Konfigurationen mit den Zertifikaten
    for site_file in /etc/caddy/sites/*.caddy; do
        domain=$(basename "$site_file" .caddy)
        
        # Aktualisiere die TLS-Einstellungen in den Konfigurationen
        sed -i "/^$domain\.devsystem\.internal {/a\\
    tls $CERT_DIR/$HOSTNAME.ts.net.crt $CERT_DIR/$HOSTNAME.ts.net.key" "$site_file"
    done
    
    log "INFO" "Tailscale-Zertifikate für HTTPS erfolgreich eingerichtet."
    
    # Skript zur automatischen Erneuerung der Tailscale-Zertifikate erstellen
    create_cert_renewal_script
}

# Skript zur automatischen Erneuerung der Tailscale-Zertifikate erstellen
create_cert_renewal_script() {
    log "STEP" "Erstelle Skript zur automatischen Erneuerung der Tailscale-Zertifikate..."
    
    # Erneuerungsskript erstellen
    cat > /usr/local/bin/tailscale-cert-renew.sh << EOF
#!/bin/bash
#
# Skript zur automatischen Erneuerung der Tailscale-Zertifikate für Caddy
#

# Hostname vom System ermitteln
HOSTNAME=\$(hostname)

# Zertifikate erneuern
tailscale cert "\$HOSTNAME.ts.net"

# Zertifikate für Caddy kopieren
mkdir -p /etc/caddy/tls/tailscale
cp /var/lib/tailscale/certs/\$HOSTNAME.ts.net.* /etc/caddy/tls/tailscale/
chown -R caddy:caddy /etc/caddy/tls/tailscale
chmod 600 /etc/caddy/tls/tailscale/\$HOSTNAME.ts.net.key

# Caddy neu laden
systemctl reload caddy

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Tailscale-Zertifikate erneuert und Caddy neu geladen."
EOF
    
    # Skript ausführbar machen
    chmod +x /usr/local/bin/tailscale-cert-renew.sh
    
    # Cron-Job für monatliche Erneuerung einrichten
    echo "0 0 1 * * root /usr/local/bin/tailscale-cert-renew.sh >> /var/log/tailscale-cert-renew.log 2>&1" > /etc/cron.d/tailscale-cert-renew
    
    log "INFO" "Skript und Cron-Job zur automatischen Erneuerung der Tailscale-Zertifikate erstellt."
}

# Monitoring-Skript für Caddy erstellen
create_monitoring_script() {
    log "STEP" "Erstelle Monitoring-Skript für Caddy..."
    
    cat > /usr/local/bin/caddy-monitor.sh << EOF
#!/bin/bash
#
# Monitoring-Skript für Caddy
#

# Überprüfen, ob Caddy läuft
if ! systemctl is-active --quiet caddy; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Caddy ist nicht aktiv - Versuche Neustart"
    systemctl restart caddy
    
    # Benachrichtigung senden (kann angepasst werden)
    # curl -X POST -H "Content-Type: application/json" \\
    #     -d '{"text":"Caddy-Dienst auf \$(hostname) wurde neu gestartet"}' \\
    #     https://hooks.example.com/services/XXX/YYY/ZZZ
fi

# Überprüfen, ob der Proxy korrekt funktioniert
for service in "code-server:8080" "ollama:11434"; do
    service_name=\$(echo \$service | cut -d':' -f1)
    port=\$(echo \$service | cut -d':' -f2)
    
    if ! curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:\$port > /dev/null 2>&1; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] \$service_name auf \$(hostname) ist nicht erreichbar (Port \$port)"
        
        # Benachrichtigung senden (kann angepasst werden)
        # curl -X POST -H "Content-Type: application/json" \\
        #     -d '{"text":"\$service_name auf \$(hostname) ist nicht erreichbar"}' \\
        #     https://hooks.example.com/services/XXX/YYY/ZZZ
    fi
done

# Überprüfen der HTTP-Status-Codes von Diensten über Caddy
for domain in "code.devsystem.internal" "ollama.devsystem.internal"; do
    status_code=\$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 -H "Host: \$domain" http://localhost > /dev/null 2>&1 || echo "000")
    
    if [ "\$status_code" != "200" ] && [ "\$status_code" != "403" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Caddy liefert ungültigen Status-Code \$status_code für \$domain"
        
        # Benachrichtigung senden (kann angepasst werden)
        # curl -X POST -H "Content-Type: application/json" \\
        #     -d '{"text":"Caddy liefert ungültigen Status-Code \$status_code für \$domain auf \$(hostname)"}' \\
        #     https://hooks.example.com/services/XXX/YYY/ZZZ
    fi
done
EOF
    
    # Skript ausführbar machen
    chmod +x /usr/local/bin/caddy-monitor.sh
    
    # Cron-Job für alle 5 Minuten einrichten
    echo "*/5 * * * * root /usr/local/bin/caddy-monitor.sh >> /var/log/caddy-monitor.log 2>&1" > /etc/cron.d/caddy-monitor
    
    # Log-Rotation für Monitoring-Logs konfigurieren
    cat > /etc/logrotate.d/caddy-monitor << EOF
/var/log/caddy-monitor.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
EOF
    
    log "INFO" "Monitoring-Skript und Cron-Job für Caddy erstellt."
}

# Verifiziere die Installation
verify_installation() {
    log "STEP" "Verifiziere die Caddy-Installation..."
    
    # Prüfen, ob der Caddy-Dienst läuft
    if ! systemctl is-active --quiet caddy; then
        log "WARN" "Caddy-Dienst läuft nicht. Versuche neu zu starten..."
        systemctl restart caddy
        
        if ! systemctl is-active --quiet caddy; then
            log "ERROR" "Caddy-Dienst konnte nicht gestartet werden. Bitte überprüfen Sie das System-Log mit 'journalctl -u caddy'."
            return 1
        fi
    fi
    
    # Caddy-Version prüfen
    log "INFO" "Caddy-Version:"
    caddy version
    
    # Caddyfile validieren
    log "INFO" "Validiere Caddyfile..."
    if caddy validate --config /etc/caddy/Caddyfile; then
        log "INFO" "Caddyfile ist gültig."
    else
        log "ERROR" "Caddyfile enthält Fehler. Bitte überprüfen und korrigieren."
        return 1
    fi
    
    log "INFO" "Verifizierung abgeschlossen."
    return 0
}

# Zusätzliche hilfreiche Informationen anzeigen
show_info() {
    echo ""
    log "STEP" "Installation abgeschlossen!"
    echo ""
    echo -e "${GREEN}Caddy wurde erfolgreich installiert und konfiguriert.${NC}"
    echo ""
    echo "Nützliche Befehle:"
    echo "  - Status anzeigen:              sudo systemctl status caddy"
    echo "  - Neu starten:                  sudo systemctl restart caddy"
    echo "  - Konfiguration validieren:     sudo caddy validate --config /etc/caddy/Caddyfile"
    echo "  - Konfiguration neu laden:      sudo caddy reload --config /etc/caddy/Caddyfile"
    echo "  - Logs anzeigen:                sudo journalctl -u caddy -f"
    echo "  - Tailscale-Zertifikate erneuern: sudo /usr/local/bin/tailscale-cert-renew.sh"
    echo ""
    echo "Konfigurationsdateien:"
    echo "  - Hauptkonfiguration:           /etc/caddy/Caddyfile"
    echo "  - Site-Konfigurationen:         /etc/caddy/sites/"
    echo "  - Sicherheits-Snippets:         /etc/caddy/snippets/"
    echo "  - Tailscale-Zertifikate:        /etc/caddy/tls/tailscale/"
    echo ""
    echo "Weitere Informationen finden Sie in der offiziellen Dokumentation:"
    echo "  https://caddyserver.com/docs/"
    echo ""
}

# Hauptfunktion
main() {
    log "STEP" "Starte Caddy-Installation für DevSystem..."
    
    # Prüfungen
    check_root
    parse_args "$@"
    check_prerequisites
    
    # Installation, wenn Caddy noch nicht installiert ist
    if [ "$CONFIG_ONLY" != "true" ]; then
        if ! check_caddy; then
            install_caddy
        fi
    else
        log "INFO" "Überspringe Installation, nur Konfiguration wird durchgeführt."
    fi
    
    # Konfigurationen
    create_directory_structure
    configure_autostart
    create_base_config
    create_site_configs
    create_security_config
    configure_firewall
    setup_tailscale_certificates
    create_monitoring_script
    
    # Verifizieren und abschließen
    verify_installation
    show_info
    
    log "INFO" "Caddy-Installation und -Konfiguration erfolgreich abgeschlossen."
}

# Skript ausführen
main "$@"
