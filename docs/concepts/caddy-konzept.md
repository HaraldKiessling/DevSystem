# Caddy-Konfigurationskonzept für DevSystem

Dieses Dokument beschreibt die Installation, Konfiguration und Integration von Caddy als Reverse Proxy für das DevSystem-Projekt. Caddy wird als primäre Komponente für die HTTPS-Terminierung und das Routing von Anfragen an die verschiedenen Dienste des DevSystem eingesetzt.

## 1. Installation und Einrichtung von Caddy auf dem Ubuntu VPS

### 1.1 Installationsschritte

Caddy kann auf verschiedene Arten auf einem Ubuntu-System installiert werden. Die empfohlene Methode ist die Installation über das offizielle Paket-Repository:

```bash
# Abhängigkeiten installieren
sudo apt update
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl

# Caddy GPG-Schlüssel und Repository hinzufügen
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list

# Paketlisten aktualisieren und Caddy installieren
sudo apt update
sudo apt install caddy
```

Alternativ kann Caddy auch direkt von der offiziellen Website heruntergeladen werden:

```bash
# Caddy herunterladen
curl -o caddy.tar.gz -L "https://github.com/caddyserver/caddy/releases/latest/download/caddy_2.7.5_linux_amd64.tar.gz"

# Entpacken und installieren
sudo tar -xzf caddy.tar.gz -C /usr/local/bin caddy
sudo chmod +x /usr/local/bin/caddy

# Benutzer und Gruppe für Caddy erstellen
sudo groupadd --system caddy
sudo useradd --system \
    --gid caddy \
    --create-home \
    --home-dir /var/lib/caddy \
    --shell /usr/sbin/nologin \
    --comment "Caddy web server" \
    caddy
```

### 1.2 Verzeichnisstruktur

Nach der Installation von Caddy wird folgende Verzeichnisstruktur empfohlen:

```
/etc/caddy/
├── Caddyfile                 # Hauptkonfigurationsdatei
├── sites/                    # Verzeichnis für Site-Konfigurationen
│   ├── code-server.caddy     # Konfiguration für code-server
│   └── api.caddy             # Konfiguration für API-Dienste
├── snippets/                 # Wiederverwendbare Konfigurationsschnipsel
│   ├── security-headers.caddy # Sicherheits-Header
│   └── tailscale-auth.caddy   # Tailscale-Authentifizierung
└── tls/                      # TLS-Zertifikate und -Schlüssel
    ├── tailscale/            # Tailscale-Zertifikate
    └── local/                # Lokale selbstsignierte Zertifikate

/var/lib/caddy/               # Datenverzeichnis
├── data/                     # Persistente Daten
└── config/                   # Laufzeitkonfiguration

/var/log/caddy/               # Log-Verzeichnis
```

### 1.3 Konfiguration für automatischen Start

Wenn Caddy über das Paket-Repository installiert wurde, wird automatisch ein systemd-Service eingerichtet. Andernfalls kann ein eigener systemd-Service erstellt werden:

```bash
# Systemd-Service-Datei erstellen
sudo cat > /etc/systemd/system/caddy.service << EOF
[Unit]
Description=Caddy Web Server
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
ExecStart=/usr/local/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/local/bin/caddy reload --config /etc/caddy/Caddyfile
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

# Systemd neu laden und Caddy-Service aktivieren
sudo systemctl daemon-reload
sudo systemctl enable caddy
sudo systemctl start caddy
```

Überprüfen des Service-Status:

```bash
sudo systemctl status caddy
```

## 2. Reverse Proxy Konfiguration

### 2.1 Grundlegende Caddyfile-Struktur

Die Hauptkonfigurationsdatei für Caddy ist die `Caddyfile`. Hier ist eine grundlegende Struktur für das DevSystem-Projekt:

```
# Globale Optionen
{
    # Admin-API deaktivieren (Sicherheitsmaßnahme)
    admin off
    
    # Standardprotokoll auf HTTP/2 setzen
    servers {
        protocol {
            experimental_http3
            strict_sni_host
        }
    }
    
    # Log-Einstellungen
    log {
        output file /var/log/caddy/access.log
        format json
    }
}

# Gemeinsame Snippets importieren
import /etc/caddy/snippets/*.caddy

# Site-Konfigurationen importieren
import /etc/caddy/sites/*.caddy
```

### 2.2 Routing-Regeln für code-server

Die Konfiguration für den code-server-Dienst wird in einer separaten Datei definiert:

```bash
# /etc/caddy/sites/code-server.caddy
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
    respond 403 {
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
```

### 2.3 Header-Manipulation für Sicherheit

Die Sicherheits-Header werden in einem wiederverwendbaren Snippet definiert:

```bash
# /etc/caddy/snippets/security-headers.caddy
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
```

## 3. HTTPS-Konfiguration

### 3.1 Integration mit Tailscale-Zertifikaten

Tailscale bietet eine integrierte PKI (Public Key Infrastructure), die für die sichere Kommunikation zwischen Geräten im Tailnet verwendet werden kann. Für die Integration mit Caddy gibt es zwei Hauptansätze:

#### Option 1: Tailscale-Zertifikate direkt verwenden

```bash
# Tailscale-Zertifikate generieren
sudo tailscale cert devsystem-vps.ts.net

# Zertifikate für Caddy verfügbar machen
sudo mkdir -p /etc/caddy/tls/tailscale
sudo cp /var/lib/tailscale/certs/devsystem-vps.ts.net.* /etc/caddy/tls/tailscale/
sudo chown -R caddy:caddy /etc/caddy/tls/tailscale
```

In der Caddy-Konfiguration:

```
code.devsystem.ts.net {
    tls /etc/caddy/tls/tailscale/devsystem-vps.ts.net.crt /etc/caddy/tls/tailscale/devsystem-vps.ts.net.key
    
    reverse_proxy localhost:8080
}
```

#### Option 2: Automatische Zertifikatserneuerung mit Tailscale

Ein Skript zur automatischen Erneuerung der Tailscale-Zertifikate:

```bash
#!/bin/bash
# /usr/local/bin/tailscale-cert-renew.sh

# Zertifikate erneuern
sudo tailscale cert devsystem-vps.ts.net

# Zertifikate für Caddy kopieren
sudo cp /var/lib/tailscale/certs/devsystem-vps.ts.net.* /etc/caddy/tls/tailscale/
sudo chown -R caddy:caddy /etc/caddy/tls/tailscale

# Caddy neu laden
sudo systemctl reload caddy
```

Dieses Skript als Cron-Job einrichten:

```bash
# Jeden Monat ausführen
echo "0 0 1 * * /usr/local/bin/tailscale-cert-renew.sh >> /var/log/tailscale-cert-renew.log 2>&1" | sudo tee -a /etc/crontab
```

### 3.2 Alternativen mit selbstsignierten Zertifikaten

Wenn Tailscale-Zertifikate nicht verwendet werden können, bietet Caddy die Möglichkeit, selbstsignierte Zertifikate zu generieren:

```
code.devsystem.internal {
    # Selbstsigniertes Zertifikat generieren
    tls internal
    
    reverse_proxy localhost:8080
}
```

Alternativ können auch manuell erstellte selbstsignierte Zertifikate verwendet werden:

```bash
# Selbstsigniertes Zertifikat erstellen
sudo mkdir -p /etc/caddy/tls/local
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/caddy/tls/local/devsystem.key \
    -out /etc/caddy/tls/local/devsystem.crt \
    -subj "/CN=*.devsystem.internal"
sudo chown -R caddy:caddy /etc/caddy/tls/local
```

In der Caddy-Konfiguration:

```
code.devsystem.internal {
    tls /etc/caddy/tls/local/devsystem.crt /etc/caddy/tls/local/devsystem.key
    
    reverse_proxy localhost:8080
}
```

### 3.3 TLS-Einstellungen und Best Practices

Für optimale Sicherheit sollten moderne TLS-Einstellungen verwendet werden:

```
{
    servers {
        protocol {
            # Nur TLS 1.2 und 1.3 erlauben
            min_tls_version 1.2
            
            # Moderne Cipher-Suites bevorzugen
            cipher_suites TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384 TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256 TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256
            
            # OCSP Stapling aktivieren
            ocsp_stapling on
            
            # HTTP/3 experimentell aktivieren
            experimental_http3
        }
    }
}
```

## 4. Sicherheitsaspekte

### 4.1 Zugriffsbeschränkungen

Die Zugriffsbeschränkung über Tailscale-IP-Bereiche:

```
# Nur Zugriff über Tailscale erlauben
@tailscale {
    remote_ip 100.64.0.0/10
}

# Zugriff auf bestimmte Pfade beschränken
@restricted_paths {
    path /admin/* /api/admin/*
}

# Zugriff auf bestimmte Pfade nur für bestimmte IPs erlauben
@admin_access {
    remote_ip 100.100.100.100 100.100.100.101
    path /admin/* /api/admin/*
}

# Zugriff verweigern für nicht autorisierte Anfragen
respond @restricted_paths&!@admin_access 403 {
    body "Zugriff verweigert"
}
```

### 4.2 Rate Limiting

Rate Limiting zum Schutz vor Brute-Force-Angriffen und DoS-Attacken:

```
# Rate Limiting für Login-Anfragen
@login {
    path /login /api/auth/*
}

rate_limit @login 10r/m

# Globales Rate Limiting
@all {
    not remote_ip 100.64.0.0/10
}

rate_limit @all 100r/m
```

### 4.3 Schutz vor gängigen Angriffen

Zusätzliche Sicherheitsmaßnahmen zum Schutz vor gängigen Angriffen:

```
# Schutz vor SQL-Injection und XSS-Angriffen
@malicious_patterns {
    path_regexp sql_injection "(?i)(union|select|insert|update|delete|drop|alter).*from"
    path_regexp xss "(?i)(<script|javascript:)"
}

respond @malicious_patterns 403 {
    body "Potenziell schädliche Anfrage blockiert"
}

# Schutz vor Verzeichnisauflistung
@directory_listing {
    path_regexp listing "/$"
    not path /api/* /assets/*
}

handle @directory_listing {
    rewrite * /index.html
}

# Schutz vor Datei-Uploads
@file_uploads {
    path /upload/*
}

handle @file_uploads {
    # Nur bestimmte Dateitypen erlauben
    @allowed_types {
        path_regexp allowed "\.(jpg|jpeg|png|gif|pdf|doc|docx)$"
    }
    
    respond @file_uploads&!@allowed_types 403 {
        body "Nur bestimmte Dateitypen sind erlaubt"
    }
    
    # Maximale Dateigröße begrenzen
    request_body_limit 10MB
}
```

## 5. Monitoring und Logging

### 5.1 Log-Formate und -Speicherorte

Caddy unterstützt verschiedene Log-Formate und -Speicherorte:

```
# Globale Log-Einstellungen
{
    log {
        output file /var/log/caddy/access.log {
            roll_size 100MB
            roll_keep 10
            roll_keep_for 720h
        }
        format json
    }
}

# Spezifische Log-Einstellungen für bestimmte Sites
code.devsystem.internal {
    log {
        output file /var/log/caddy/code-server.log {
            roll_size 50MB
            roll_keep 5
            roll_keep_for 168h
        }
        format json {
            time_format iso8601
            time_local
        }
    }
    
    # Zusätzliches Logging für bestimmte Pfade
    @api_paths {
        path /api/*
    }
    
    log @api_paths {
        output file /var/log/caddy/api.log
        format json
    }
}
```

### 5.2 Überwachung der Proxy-Funktionalität

Für die Überwachung der Proxy-Funktionalität kann ein Monitoring-Skript erstellt werden:

```bash
#!/bin/bash
# /usr/local/bin/caddy-monitor.sh

# Überprüfen, ob Caddy läuft
if ! systemctl is-active --quiet caddy; then
    echo "Caddy ist nicht aktiv - Versuche Neustart"
    sudo systemctl restart caddy
    
    # Benachrichtigung senden
    curl -X POST -H "Content-Type: application/json" \
        -d '{"text":"Caddy-Dienst auf devsystem-vps wurde neu gestartet"}' \
        https://hooks.example.com/services/XXX/YYY/ZZZ
fi

# Überprüfen, ob die Proxy-Verbindungen funktionieren
if ! curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:8080; then
    echo "code-server ist nicht erreichbar"
    
    # Benachrichtigung senden
    curl -X POST -H "Content-Type: application/json" \
        -d '{"text":"code-server auf devsystem-vps ist nicht erreichbar"}' \
        https://hooks.example.com/services/XXX/YYY/ZZZ
fi
```

Dieses Skript als Cron-Job einrichten:

```bash
# Alle 5 Minuten ausführen
*/5 * * * * /usr/local/bin/caddy-monitor.sh >> /var/log/caddy-monitor.log 2>&1
```

### 5.3 Integration mit Monitoring-Tools

Caddy kann mit verschiedenen Monitoring-Tools integriert werden:

#### Prometheus-Integration

```
{
    servers {
        metrics
    }
}

:2019 {
    metrics /metrics
}
```

#### Grafana-Dashboard

Ein Grafana-Dashboard kann erstellt werden, um die Caddy-Metriken zu visualisieren. Hier ist ein Beispiel für die Prometheus-Konfiguration:

```yaml
# /etc/prometheus/prometheus.yml
scrape_configs:
  - job_name: 'caddy'
    scrape_interval: 15s
    static_configs:
      - targets: ['localhost:2019']
```

## 6. Performance-Optimierung

### 6.1 Caching-Strategien

Caddy bietet verschiedene Caching-Strategien zur Verbesserung der Performance:

```
# Statische Dateien cachen
@static {
    path *.css *.js *.jpg *.jpeg *.png *.gif *.ico *.svg *.woff *.woff2
}

handle @static {
    header Cache-Control "public, max-age=31536000"
    header ETag "{http.response.body.size}-{http.response.body.mod_time}"
}

# API-Antworten cachen
@api_cacheable {
    path /api/public/* /api/data/*
    not path /api/auth/* /api/user/*
}

cache @api_cacheable {
    ttl 5m
    match_path
}
```

### 6.2 Kompression

Kompression zur Reduzierung der Übertragungsgröße:

```
# Kompression für alle Textdateien aktivieren
encode gzip zstd
```

Für spezifischere Kontrolle:

```
@compressible {
    header Content-Type text/* application/json application/javascript application/xml
}

encode @compressible gzip zstd
```

### 6.3 Verbindungs-Handling

Optimierungen für das Verbindungs-Handling:

```
# Verbindungs-Timeouts und Limits
{
    servers {
        timeouts {
            read_body 10s
            read_header 5s
            write 30s
            idle 120s
        }
        
        max_header_size 10KB
        
        # Verbindungslimits
        max_concurrent_requests 1000
    }
}

# Keepalive-Einstellungen für Reverse Proxy
reverse_proxy localhost:8080 {
    transport http {
        keepalive 30s
        keepalive_idle_conns 10
    }
}
```

## 7. Zusammenfassung und nächste Schritte

Dieses Konzept beschreibt die Installation, Konfiguration und Integration von Caddy als Reverse Proxy für das DevSystem-Projekt. Die wichtigsten Aspekte sind:

1. **Installation und Einrichtung**: Schritte zur Installation und Konfiguration von Caddy auf dem Ubuntu VPS
2. **Reverse Proxy Konfiguration**: Grundlegende Caddyfile-Struktur, Routing-Regeln und Header-Manipulation
3. **HTTPS-Konfiguration**: Integration mit Tailscale-Zertifikaten, Alternativen und TLS-Einstellungen
4. **Sicherheitsaspekte**: Zugriffsbeschränkungen, Rate Limiting und Schutz vor gängigen Angriffen
5. **Monitoring und Logging**: Log-Formate, Überwachung und Integration mit Monitoring-Tools
6. **Performance-Optimierung**: Caching-Strategien, Kompression und Verbindungs-Handling

### Nächste Schritte

1. **Implementierung**: Umsetzung der in diesem Konzept beschriebenen Konfiguration auf dem Ubuntu VPS
2. **Testing**: Durchführung von Tests zur Überprüfung der Funktionalität und Sicherheit
3. **Integration mit Tailscale**: Sicherstellen, dass Caddy korrekt mit der Tailscale-Konfiguration zusammenarbeitet
4. **Monitoring-Setup**: Einrichtung des Monitorings und der Alarmierung
5. **Dokumentation**: Erstellung einer Benutzeranleitung für die Verwaltung des Caddy-Servers

## 8. Anhang

### 8.1 Vollständige Beispielkonfiguration

Hier ist eine vollständige Beispielkonfiguration für das DevSystem-Projekt:

```
# Globale Optionen
{
    admin off
    
    servers {
        protocol {
            min_tls_version 1.2
            experimental_http3
            strict_sni_host
        }
        
        timeouts {
            read_body 30s
            read_header 10s
            write 60s
            idle 5m
        }
    }
    
    log {
        output file /var/log/caddy/access.log {
            roll_size 100MB
            roll_keep 10
            roll_keep_for 720h
        }
        format json
    }
    
    # Metriken für Prometheus
    metrics
}

# Metriken-Endpunkt
:2019 {
    metrics /metrics
}

# code-server
code.devsystem.internal {
    # Nur Zugriff über Tailscale erlauben
    @tailscale {
        remote_ip 100.64.0.0/10
    }
    
    # TLS mit Tailscale-Zertifikaten
    tls /etc/caddy/tls/tailscale/devsystem-vps.ts.net.crt /etc/caddy/tls/tailscale/devsystem-vps.ts.net.key
    
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
    
    # Sicherheits-Header
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-XSS-Protection "1; mode=block"
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "strict-origin-when-cross-origin"
        Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' wss:; frame-ancestors 'self';"
        -Server
    }
    
    # Kompression
    encode gzip zstd
    
    # Logging
    log {
        output file /var/log/caddy/code-server.log {
            roll_size 50MB
            roll_keep 5
            roll_keep_for 168h
        }
        format json
    }
}

# Ollama API
ollama.devsystem.internal {
    # Nur Zugriff über Tailscale erlauben
    @tailscale {
        remote_ip 100.64.0.0/10
    }
    
    # TLS mit Tailscale-Zertifikaten
    tls /etc/caddy/tls/tailscale/devsystem-vps.ts.net.crt /etc/caddy/tls/tailscale/devsystem-vps.ts.net.key
    
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
    
    # Sicherheits-Header
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-XSS-Protection "1; mode=block"
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "strict-origin-when-cross-origin"
        -Server
    }
    
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
        format json
    }
}
```

### 8.2 Nützliche Caddy-Befehle

```bash
# Caddy-Version anzeigen
caddy version

# Konfiguration validieren
caddy validate --config /etc/caddy/Caddyfile

# Konfiguration neu laden
caddy reload --config /etc/caddy/Caddyfile

# Caddy-Status anzeigen
caddy status

# Caddy-Dienst neu starten
sudo systemctl restart caddy

# Caddy-Logs anzeigen
sudo journalctl -u caddy -f

# Caddy-Konfiguration formatieren
caddy fmt --overwrite /etc/caddy/Caddyfile
```

### 8.3 Referenzen

- [Offizielle Caddy-Dokumentation](https://caddyserver.com/docs/)
- [Caddy Reverse Proxy Dokumentation](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy)
- [Caddy TLS-Dokumentation](https://caddyserver.com/docs/caddyfile/directives/tls)
- [Caddy Security Best Practices](https://caddyserver.com/docs/security)
- [Tailscale und Caddy Integration](https://tailscale.com/kb/1153/enabling-https/)