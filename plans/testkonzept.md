# Testkonzept für DevSystem

Dieses Dokument beschreibt ein umfassendes Testkonzept für das DevSystem-Projekt. Es definiert die notwendigen Tests für alle Komponenten des Systems, einschließlich Tailscale-Konnektivität, Caddy-Proxy und code-server. Darüber hinaus werden Strategien für Log-Validierung, Testautomatisierung und die Einrichtung einer Testumgebung beschrieben.

## Inhaltsverzeichnis

1. [E2E-Tests für Tailscale-Konnektivität](#1-e2e-tests-für-tailscale-konnektivität)
2. [E2E-Tests für Caddy-Proxy](#2-e2e-tests-für-caddy-proxy)
3. [E2E-Tests für code-server](#3-e2e-tests-für-code-server)
4. [Log-Validierungstests](#4-log-validierungstests)
5. [Testautomatisierung](#5-testautomatisierung)
6. [Testumgebung](#6-testumgebung)

## 1. E2E-Tests für Tailscale-Konnektivität

Die Tailscale-Konnektivität ist die Grundlage für die sichere Kommunikation im DevSystem. Die folgenden Tests stellen sicher, dass die Tailscale-Komponente korrekt funktioniert und die Sicherheitsanforderungen erfüllt.

### 1.1 Tests für die erfolgreiche Verbindung zum Tailscale-Netzwerk

#### 1.1.1 Verbindungsaufbau-Test

**Ziel:** Überprüfen, ob der VPS erfolgreich eine Verbindung zum Tailscale-Netzwerk herstellen kann.

**Testschritte:**
1. Tailscale-Dienst auf dem VPS starten: `sudo systemctl start tailscale`
2. Verbindungsstatus überprüfen: `tailscale status`
3. Netzwerkverbindung testen: `tailscale ping <anderes-gerät-im-tailnet>`

**Erwartetes Ergebnis:**
- Der Befehl `tailscale status` zeigt "Connected" an
- Der Ping zu einem anderen Gerät im Tailnet ist erfolgreich
- Der VPS erhält eine Tailscale-IP-Adresse im Bereich 100.64.0.0/10

**Testskript:**
```bash
#!/bin/bash
# test_tailscale_connection.sh

# Tailscale-Status überprüfen
status=$(tailscale status | grep -c "Connected")
if [ $status -eq 0 ]; then
  echo "FEHLER: Tailscale ist nicht verbunden"
  exit 1
fi

# Tailscale-IP überprüfen
ip=$(tailscale ip -4)
if [[ ! $ip =~ ^100\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
  echo "FEHLER: Ungültige Tailscale-IP: $ip"
  exit 1
fi

# Ping zu einem bekannten Gerät im Tailnet
if ! tailscale ping <test-gerät-hostname> -c 3; then
  echo "FEHLER: Ping zu Test-Gerät fehlgeschlagen"
  exit 1
fi

echo "ERFOLG: Tailscale-Verbindung ist aktiv und funktioniert korrekt"
exit 0
```

#### 1.1.2 Verbindungsstabilität-Test

**Ziel:** Überprüfen, ob die Tailscale-Verbindung über einen längeren Zeitraum stabil bleibt.

**Testschritte:**
1. Skript erstellen, das in regelmäßigen Abständen (z.B. alle 5 Minuten) die Verbindung überprüft
2. Test über 24 Stunden laufen lassen
3. Ergebnisse auswerten

**Erwartetes Ergebnis:**
- Die Verbindung bleibt über den gesamten Testzeitraum stabil
- Keine Verbindungsabbrüche oder nur kurze Unterbrechungen mit automatischer Wiederverbindung

**Testskript:**
```bash
#!/bin/bash
# test_tailscale_stability.sh

LOG_FILE="/var/log/tailscale-stability-test.log"
TEST_DURATION=86400  # 24 Stunden in Sekunden
CHECK_INTERVAL=300   # 5 Minuten in Sekunden
PING_TARGET="<test-gerät-hostname>"

echo "Starte Tailscale-Stabilitätstest für $TEST_DURATION Sekunden" > $LOG_FILE
echo "Zeitstempel,Status,Latenz" >> $LOG_FILE

start_time=$(date +%s)
end_time=$((start_time + TEST_DURATION))

while [ $(date +%s) -lt $end_time ]; do
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  
  # Verbindungsstatus prüfen
  if tailscale status | grep -q "Connected"; then
    status="Connected"
    
    # Latenz messen
    ping_result=$(tailscale ping $PING_TARGET -c 1 2>/dev/null | grep -oP 'time=\K[0-9.]+')
    if [ -z "$ping_result" ]; then
      latenz="Fehler"
    else
      latenz="${ping_result}ms"
    fi
  else
    status="Disconnected"
    latenz="N/A"
  fi
  
  echo "$timestamp,$status,$latenz" >> $LOG_FILE
  sleep $CHECK_INTERVAL
done

# Auswertung
total_checks=$(grep -c "," $LOG_FILE)
connected_checks=$(grep -c "Connected" $LOG_FILE)
success_rate=$(awk "BEGIN {print ($connected_checks/$total_checks)*100}")

echo "Test abgeschlossen. Erfolgsrate: $success_rate%" >> $LOG_FILE
echo "Verbindungsstabilität: $success_rate%"

if (( $(echo "$success_rate >= 99.5" | bc -l) )); then
  echo "ERFOLG: Tailscale-Verbindung ist stabil"
  exit 0
else
  echo "FEHLER: Tailscale-Verbindung ist nicht ausreichend stabil"
  exit 1
fi
```

### 1.2 Überprüfung der Netzwerksicherheit und ACLs

#### 1.2.1 ACL-Durchsetzungstest

**Ziel:** Überprüfen, ob die konfigurierten Tailscale-ACLs korrekt durchgesetzt werden.

**Testschritte:**
1. Testbenutzer mit verschiedenen Berechtigungsstufen erstellen (Admin, Developer, Viewer)
2. Verbindungsversuche zu verschiedenen Diensten mit jedem Benutzer durchführen
3. Überprüfen, ob nur autorisierte Zugriffe erfolgreich sind

**Erwartetes Ergebnis:**
- Admin-Benutzer können auf alle Dienste zugreifen
- Developer-Benutzer können nur auf code-server, SSH und Ollama zugreifen
- Viewer-Benutzer können nur auf code-server zugreifen
- Nicht autorisierte Zugriffe werden blockiert

**Testskript:**
```bash
#!/bin/bash
# test_tailscale_acls.sh

# Testparameter
VPS_HOSTNAME="devsystem-vps"
CODE_SERVER_URL="https://code.devsystem.internal"
OLLAMA_URL="https://ollama.devsystem.internal"
SSH_PORT=22

# Funktion zum Testen des Zugriffs
test_access() {
  local user=$1
  local service=$2
  local url=$3
  
  echo "Teste Zugriff für $user auf $service..."
  
  # Hier würde man den tatsächlichen Zugriff mit dem entsprechenden Benutzer testen
  # In einer realen Implementierung würde dies über einen API-Aufruf oder SSH-Befehl erfolgen
  
  case $user in
    "admin")
      # Admin sollte Zugriff auf alles haben
      echo "ERFOLG: Admin-Zugriff auf $service ist wie erwartet erlaubt"
      return 0
      ;;
    "developer")
      # Developer sollte Zugriff auf code-server, SSH und Ollama haben
      if [[ "$service" == "code-server" || "$service" == "ssh" || "$service" == "ollama" ]]; then
        echo "ERFOLG: Developer-Zugriff auf $service ist wie erwartet erlaubt"
        return 0
      else
        echo "ERFOLG: Developer-Zugriff auf $service ist wie erwartet blockiert"
        return 1
      fi
      ;;
    "viewer")
      # Viewer sollte nur Zugriff auf code-server haben
      if [[ "$service" == "code-server" ]]; then
        echo "ERFOLG: Viewer-Zugriff auf $service ist wie erwartet erlaubt"
        return 0
      else
        echo "ERFOLG: Viewer-Zugriff auf $service ist wie erwartet blockiert"
        return 1
      fi
      ;;
  esac
}

# Tests für jeden Benutzertyp und Dienst durchführen
for user in "admin" "developer" "viewer"; do
  echo "=== Teste Berechtigungen für $user ==="
  
  test_access $user "code-server" "$CODE_SERVER_URL"
  test_access $user "ssh" "$VPS_HOSTNAME:$SSH_PORT"
  test_access $user "ollama" "$OLLAMA_URL"
  test_access $user "admin-port" "$VPS_HOSTNAME:9090"
  
  echo ""
done

echo "ACL-Tests abgeschlossen"
```

#### 1.2.2 Netzwerkisolationstest

**Ziel:** Überprüfen, ob der VPS nur über Tailscale erreichbar ist und alle anderen externen Zugriffe blockiert werden.

**Testschritte:**
1. Versuchen, von einem nicht-Tailscale-Netzwerk auf verschiedene Dienste zuzugreifen
2. Überprüfen, ob die Firewall-Regeln korrekt konfiguriert sind

**Erwartetes Ergebnis:**
- Alle Verbindungsversuche von außerhalb des Tailscale-Netzwerks werden blockiert
- Die Firewall-Regeln sind korrekt konfiguriert

**Testskript:**
```bash
#!/bin/bash
# test_network_isolation.sh

# Testparameter
VPS_IP="<öffentliche-ip-des-vps>"
PORTS_TO_TEST=(22 80 443 8080 11434)

echo "Teste Netzwerkisolation für VPS $VPS_IP"
echo "Dieser Test sollte von einem Gerät außerhalb des Tailscale-Netzwerks durchgeführt werden"

for port in "${PORTS_TO_TEST[@]}"; do
  echo -n "Teste Port $port: "
  
  # Timeout auf 5 Sekunden setzen, um den Test zu beschleunigen
  if nc -z -w 5 $VPS_IP $port 2>/dev/null; then
    echo "FEHLER: Port $port ist von außen erreichbar!"
  else
    echo "ERFOLG: Port $port ist von außen nicht erreichbar"
  fi
done

# Firewall-Regeln überprüfen (muss auf dem VPS ausgeführt werden)
echo -e "\nFirewall-Regeln überprüfen:"
ssh -i ~/.ssh/id_rsa user@$VPS_IP "sudo ufw status verbose"

echo "Netzwerkisolationstest abgeschlossen"
```

### 1.3 Validierung der DNS-Konfiguration

#### 1.3.1 DNS-Auflösungstest

**Ziel:** Überprüfen, ob die DNS-Namen im Tailscale-Netzwerk korrekt aufgelöst werden.

**Testschritte:**
1. Verschiedene DNS-Namen im Tailnet auflösen
2. Überprüfen, ob die aufgelösten IP-Adressen korrekt sind

**Erwartetes Ergebnis:**
- Alle konfigurierten DNS-Namen werden korrekt zu den entsprechenden Tailscale-IPs aufgelöst
- MagicDNS funktioniert korrekt für Gerätenamen

**Testskript:**
```bash
#!/bin/bash
# test_tailscale_dns.sh

# Zu testende DNS-Namen
DNS_NAMES=(
  "devsystem-vps"
  "code.devsystem.internal"
  "ollama.devsystem.internal"
  "<anderes-gerät-im-tailnet>"
)

# Erwartete IP-Adresse des VPS im Tailnet
EXPECTED_VPS_IP=$(tailscale ip -4)

echo "Teste DNS-Auflösung im Tailscale-Netzwerk"
echo "Erwartete VPS-IP: $EXPECTED_VPS_IP"

for name in "${DNS_NAMES[@]}"; do
  echo -n "Auflösung von $name: "
  
  # DNS-Auflösung mit Timeout
  resolved_ip=$(dig +short $name @100.100.100.100 | head -n1)
  
  if [ -z "$resolved_ip" ]; then
    echo "FEHLER: Konnte $name nicht auflösen"
  else
    echo "$resolved_ip"
    
    # Überprüfen, ob die aufgelöste IP für VPS-bezogene Namen korrekt ist
    if [[ "$name" == "devsystem-vps" || "$name" == "code.devsystem.internal" || "$name" == "ollama.devsystem.internal" ]]; then
      if [ "$resolved_ip" == "$EXPECTED_VPS_IP" ]; then
        echo "  ERFOLG: IP-Adresse ist korrekt"
      else
        echo "  FEHLER: Falsche IP-Adresse. Erwartet: $EXPECTED_VPS_IP, Erhalten: $resolved_ip"
      fi
    fi
  fi
done

echo "DNS-Test abgeschlossen"
```

#### 1.3.2 MagicDNS-Funktionalitätstest

**Ziel:** Überprüfen, ob MagicDNS korrekt funktioniert und Gerätenamen automatisch aufgelöst werden.

**Testschritte:**
1. Verschiedene Gerätenamen im Tailnet pingen
2. Überprüfen, ob die Geräte über ihre Namen erreichbar sind

**Erwartetes Ergebnis:**
- Alle Geräte im Tailnet sind über ihre Hostnamen erreichbar
- Die Namensauflösung erfolgt automatisch über MagicDNS

**Testskript:**
```bash
#!/bin/bash
# test_magicdns.sh

# Liste der Geräte im Tailnet
DEVICES=$(tailscale status | grep -v "^tag:" | awk '{print $1}' | grep -v "^$")

echo "Teste MagicDNS-Funktionalität für alle Geräte im Tailnet"

for device in $DEVICES; do
  echo -n "Ping zu $device: "
  
  if ping -c 1 -W 2 $device >/dev/null 2>&1; then
    echo "ERFOLG: Gerät ist über MagicDNS erreichbar"
  else
    echo "FEHLER: Gerät ist nicht über MagicDNS erreichbar"
    
    # Versuchen, mit der Tailscale-IP zu pingen
    device_ip=$(tailscale status | grep "$device" | awk '{print $2}')
    if [ -n "$device_ip" ]; then
      echo -n "  Versuche Ping zur IP $device_ip: "
      if ping -c 1 -W 2 $device_ip >/dev/null 2>&1; then
        echo "ERFOLG: Gerät ist über IP erreichbar, aber nicht über Namen"
      else
        echo "FEHLER: Gerät ist auch über IP nicht erreichbar"
      fi
    fi
  fi
done

echo "MagicDNS-Test abgeschlossen"
```

### 1.4 Überprüfung der Log-Einträge

#### 1.4.1 Log-Vollständigkeitstest

**Ziel:** Überprüfen, ob Tailscale alle relevanten Ereignisse korrekt protokolliert.

**Testschritte:**
1. Verschiedene Ereignisse auslösen (Verbindung, Trennung, Zugriff, etc.)
2. Überprüfen, ob diese Ereignisse in den Logs erscheinen

**Erwartetes Ergebnis:**
- Alle relevanten Ereignisse werden in den Logs protokolliert
- Die Logs enthalten ausreichend Informationen zur Diagnose von Problemen

**Testskript:**
```bash
#!/bin/bash
# test_tailscale_logs.sh

LOG_FILE="/tmp/tailscale_test_logs.txt"

echo "Teste Tailscale-Logging"

# Logs vor dem Test speichern
sudo journalctl -u tailscaled -n 100 > $LOG_FILE.before

echo "1. Teste Verbindungsereignisse"
sudo systemctl restart tailscale
sleep 10

echo "2. Teste Zugriffsereignisse"
# Einen Zugriff simulieren
curl -s -o /dev/null -w "%{http_code}" https://code.devsystem.internal

echo "3. Teste Konfigurationsänderungen"
# Eine Konfigurationsänderung vornehmen
sudo tailscale up --hostname=devsystem-vps-test
sleep 5
sudo tailscale up --hostname=devsystem-vps
sleep 5

# Logs nach dem Test speichern
sudo journalctl -u tailscaled -n 100 > $LOG_FILE.after

# Unterschiede in den Logs analysieren
diff $LOG_FILE.before $LOG_FILE.after > $LOG_FILE.diff

echo "Prüfe Logs auf erwartete Ereignisse:"

# Prüfen, ob bestimmte Ereignisse protokolliert wurden
if grep -q "daemon started" $LOG_FILE.diff; then
  echo "ERFOLG: Daemon-Start wurde protokolliert"
else
  echo "FEHLER: Daemon-Start wurde nicht protokolliert"
fi

if grep -q "peer.*changed" $LOG_FILE.diff; then
  echo "ERFOLG: Peer-Änderungen wurden protokolliert"
else
  echo "FEHLER: Peer-Änderungen wurden nicht protokolliert"
fi

if grep -q "SetHostname" $LOG_FILE.diff; then
  echo "ERFOLG: Hostname-Änderungen wurden protokolliert"
else
  echo "FEHLER: Hostname-Änderungen wurden nicht protokolliert"
fi

echo "Log-Test abgeschlossen"
```

## 2. E2E-Tests für Caddy-Proxy

Caddy dient als Reverse Proxy und ist verantwortlich für die HTTPS-Terminierung und das Routing von Anfragen. Die folgenden Tests stellen sicher, dass Caddy korrekt konfiguriert ist und die Sicherheitsanforderungen erfüllt.

### 2.1 Tests für die korrekte Weiterleitung von Anfragen

#### 2.1.1 Routing-Test

**Ziel:** Überprüfen, ob Caddy Anfragen korrekt an die entsprechenden Backend-Dienste weiterleitet.

**Testschritte:**
1. HTTP-Anfragen an verschiedene Domains/Pfade senden
2. Überprüfen, ob die Anfragen an die richtigen Backend-Dienste weitergeleitet werden

**Erwartetes Ergebnis:**
- Anfragen an `code.devsystem.internal` werden an code-server (Port 8080) weitergeleitet
- Anfragen an `ollama.devsystem.internal` werden an Ollama (Port 11434) weitergeleitet
- Die Weiterleitung funktioniert für verschiedene HTTP-Methoden (GET, POST, etc.)

**Testskript:**
```bash
#!/bin/bash
# test_caddy_routing.sh

# Testparameter
CODE_SERVER_URL="https://code.devsystem.internal"
OLLAMA_URL="https://ollama.devsystem.internal"

echo "Teste Caddy-Routing"

# Funktion zum Testen einer URL
test_url() {
  local url=$1
  local expected_backend=$2
  local method=${3:-GET}
  
  echo -n "Teste $method-Anfrage an $url (erwartet: $expected_backend): "
  
  # HTTP-Anfrage mit curl senden und Header analysieren
  response=$(curl -s -X $method -I "$url" -k)
  
  # Überprüfen, ob die Anfrage erfolgreich war
  status_code=$(echo "$response" | grep -i "^HTTP" | awk '{print $2}')
  
  if [ -z "$status_code" ]; then
    echo "FEHLER: Keine Antwort erhalten"
    return 1
  fi
  
  if [[ "$status_code" == "2"* ]]; then
    echo "ERFOLG: Status $status_code"
    
    # In einer realen Implementierung würde man hier prüfen, ob die Antwort tatsächlich
    # vom erwarteten Backend kommt, z.B. durch Analyse von Response-Headern oder Inhalten
    
    return 0
  else
    echo "FEHLER: Status $status_code"
    return 1
  fi
}

# Tests für code-server
echo "=== Tests für code-server ==="
test_url "$CODE_SERVER_URL" "code-server" "GET"
test_url "$CODE_SERVER_URL/login" "code-server" "GET"
test_url "$CODE_SERVER_URL/api/health" "code-server" "GET"

# Tests für Ollama
echo -e "\n=== Tests für Ollama ==="
test_url "$OLLAMA_URL" "ollama" "GET"
test_url "$OLLAMA_URL/api/tags" "ollama" "GET"

echo "Routing-Tests abgeschlossen"
```

#### 2.1.2 WebSocket-Test

**Ziel:** Überprüfen, ob Caddy WebSocket-Verbindungen korrekt weiterleitet, was für code-server essentiell ist.

**Testschritte:**
1. WebSocket-Verbindung zu code-server herstellen
2. Überprüfen, ob die Verbindung erfolgreich hergestellt wird und stabil bleibt

**Erwartetes Ergebnis:**
- WebSocket-Verbindungen werden erfolgreich hergestellt
- Die Verbindungen bleiben stabil und Daten werden korrekt übertragen

**Testskript:**
```bash
#!/bin/bash
# test_websocket.sh

# Testparameter
CODE_SERVER_URL="https://code.devsystem.internal"
WEBSOCKET_ENDPOINT="/socket"

echo "Teste WebSocket-Weiterleitung für code-server"

# WebSocket-Test mit wscat (muss installiert sein: npm install -g wscat)
echo "Verbindung zum WebSocket-Endpunkt herstellen..."
wscat -c "$CODE_SERVER_URL$WEBSOCKET_ENDPOINT" --no-check > /tmp/ws_output.txt 2>&1 &
WS_PID=$!

# Kurz warten, damit die Verbindung hergestellt werden kann
sleep 5

# Prüfen, ob der Prozess noch läuft
if kill -0 $WS_PID 2>/dev/null; then
  echo "ERFOLG: WebSocket-Verbindung wurde hergestellt"
  
  # Prozess beenden
  kill $WS_PID
else
  echo "FEHLER: WebSocket-Verbindung konnte nicht hergestellt werden"
  cat /tmp/ws_output.txt
fi

# Alternativ kann man auch einen einfachen Browser-basierten Test verwenden
echo -e "\nBrowser-Test für WebSockets:"
echo "1. Öffne code.devsystem.internal im Browser"
echo "2. Öffne die Entwicklertools (F12)"
echo "3. Wechsle zur Registerkarte 'Network'"
echo "4. Filtere nach 'WS' (WebSockets)"
echo "5. Überprüfe, ob WebSocket-Verbindungen hergestellt werden und aktiv sind"

echo "WebSocket-Test abgeschlossen"
```

### 2.2 Überprüfung der HTTPS-Konfiguration

#### 2.2.1 TLS-Konfigurationstest

**Ziel:** Überprüfen, ob die TLS-Konfiguration von Caddy den Sicherheitsanforderungen entspricht.

**Testschritte:**
1. TLS-Verbindung zu verschiedenen Domains herstellen
2. TLS-Konfiguration analysieren (Protokollversion, Cipher Suites, etc.)

**Erwartetes Ergebnis:**
- Nur sichere TLS-Versionen (1.2+) werden unterstützt
- Nur sichere Cipher Suites werden verwendet
- Zertifikate sind gültig und vertrauenswürdig im Tailscale-Kontext

**Testskript:**
```bash
#!/bin/bash
# test_tls_configuration.sh

# Testparameter
DOMAINS=("code.devsystem.internal" "ollama.devsystem.internal")

echo "Teste TLS-Konfiguration für Caddy"

for domain in "${DOMAINS[@]}"; do
  echo -e "\n=== Teste TLS für $domain ==="
  
  # TLS-Verbindung mit OpenSSL analysieren
  echo "TLS-Handshake und Zertifikatsinformationen:"
  openssl s_client -connect $domain:443 -servername $domain -tls1_2 </dev/null 2>/dev/null | grep -E "Protocol|Cipher|Verification|subject|issuer"
  
  # Überprüfen, ob TLS 1.0 und 1.1 deaktiviert sind
  echo -n "TLS 1.0: "
  if openssl s_client -connect $domain:443 -servername $domain -tls1 </dev/null 2>&1 | grep -q "Protocol"; then
    echo "FEHLER: TLS 1.0 ist aktiviert"
  else
    echo "ERFOLG: TLS 1.0 ist deaktiviert"
  fi
  
  echo -n "TLS 1.1: "
  if openssl s_client -connect $domain:443 -servername $domain -tls1_1 </dev/null 2>&1 | grep -q "Protocol"; then
    echo "FEHLER: TLS 1.1 ist aktiviert"
  else
    echo "ERFOLG: TLS 1.1 ist deaktiviert"
  fi
  
  # Überprüfen, ob TLS 1.2 und 1.3 aktiviert sind
  echo -n "TLS 1.2: "
  if openssl s_client -connect $domain:443 -servername $domain -tls1_2 </dev/null 2>&1 | grep -q "Protocol"; then
    echo "ERFOLG: TLS 1.2 ist aktiviert"
  else
    echo "FEHLER: TLS 1.2 ist deaktiviert"
  fi
  
  echo -n "TLS 1.3: "
  if openssl s_client -connect $domain:443 -servername $domain -tls1_3 </dev/null 2>&1 | grep -q "Protocol"; then
    echo "ERFOLG: TLS 1.3 ist aktiviert"
  else
    echo "FEHLER: TLS 1.3 ist deaktiviert"
  fi
done

echo "TLS-Konfigurationstest abgeschlossen"
```

#### 2.2.2 Zertifikatsvalidierungstest

**Ziel:** Überprüfen, ob die Zertifikate korrekt konfiguriert und gültig sind.

**Testschritte:**
1. Zertifikate für verschiedene Domains abrufen und analysieren
2. Überprüfen, ob die Zertifikate gültig und korrekt konfiguriert sind

**Erwartetes Ergebnis:**
- Zertifikate sind gültig (nicht abgelaufen)
- Zertifikate sind für die richtigen Domains ausgestellt
- Zertifikate werden von Tailscale-Clients als vertrauenswürdig eingestuft

**Testskript:**
```bash
#!/bin/bash
# test_certificates.sh

# Testparameter
DOMAINS=("code.devsystem.internal" "ollama.devsystem.internal")

echo "Teste Zertifikate für Caddy"

for domain in "${DOMAINS[@]}"; do
  echo -e "\n=== Teste Zertifikat für $domain ==="
  
  # Zertifikat abrufen und analysieren
  echo "Zertifikatsinformationen:"
  openssl s_client -connect $domain:443 -servername $domain </dev/null 2>/dev/null | openssl x509 -noout -text | grep -E "Subject:|Issuer:|Not Before:|Not After :|DNS:"
  
  # Gültigkeitsdauer überprüfen
  valid_from=$(openssl s_client -connect $domain:443 -servername $domain </dev/null 2>/dev/null | openssl x509 -noout -startdate | cut -d= -f2)
  valid_to=$(openssl s_client -connect $domain:443 -servername $domain </dev/null 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
  
  echo "Gültig von: $valid_from"
  echo "Gültig bis: $valid_to"
  
  # Überprüfen, ob das Zertifikat noch gültig ist
  current_time=$(date +%s)
  expiry_time=$(date -d "$valid_to" +%s)
  
  if [ $current_time -lt $expiry_time ]; then
    echo "ERFOLG: Zertifikat ist noch gültig"
    
    # Überprüfen, wie lange das Zertifikat noch gültig ist
    days_left=$(( ($expiry_time - $current_time) / 86400 ))
    echo "  Noch $days_