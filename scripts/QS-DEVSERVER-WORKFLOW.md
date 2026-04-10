# QS-DevServer Workflow - Komplette Anleitung

**Version:** 1.0  
**Stand:** 2026-04-10  
**Ziel:** Vollautomatisierter Setup eines Quality-Servers (QS-VPS) von Tailscale-Key bis HTTPS-URL

---

## 📋 Workflow-Übersicht

```mermaid
graph TD
    A[1. Tailscale-Script generieren] --> B[2. Script bei Ubuntu einfügen]
    B --> C[3. IP aus Tailscale Admin kopieren]
    C --> D[4. IP im Chat übergeben]
    D --> E[5. Automatisches Setup per SSH]
    E --> F[6. Ergebnis protokollieren]
    F --> G[7. GitHub Commit + HTTPS-URL]
    
    style A fill:#f9f,stroke:#333
    style B fill:#f9f,stroke:#333
    style C fill:#f9f,stroke:#333
    style D fill:#f9f,stroke:#333
    style E fill:#9ff,stroke:#333
    style F fill:#9ff,stroke:#333
    style G fill:#9ff,stroke:#333
```

**Legende:**
- 🟪 **Pink (Schritte 1-4):** User-Aktionen (manuell)
- 🟦 **Blau (Schritte 5-7):** Automatisiert (Roo Code übernimmt)

---

## 🟪 Teil 1: User-Schritte (Manuell)

### ✅ Schritt 1: Tailscale-Script generieren

**Ziel:** Authentifizierungs-Key für Tailscale VPN erstellen

#### 1.1 Tailscale Admin öffnen

```
URL: https://login.tailscale.com/admin/settings/keys
```

**Screenshot-Hinweis:** Du solltest die Seite "Settings > Keys" sehen

#### 1.2 Auth Key generieren

Klicke auf **"Generate auth key"** und konfiguriere:

| Option | Einstellung | Begründung |
|--------|-------------|------------|
| **Reusable** | ✅ aktiviert | Key kann mehrfach verwendet werden (für Re-Deployments) |
| **Ephemeral** | ✅ aktiviert | Server wird automatisch entfernt wenn offline (QS-Charakter) |
| **Expiration** | 90 Tage | Ausreichend Zeit für QS-Tests |
| **Tags** | `tag:qs-server` (optional) | Ermöglicht ACL-basierte Trennung |

#### 1.3 Key kopieren

Nach **"Generate key"** wird ein Key angezeigt:

```
Format: tskey-auth-XXXXXXXXXXXXX-YYYYYYYYYYYYYYYYYYY
```

**⚠️ Wichtig:**
- Kopiere den Key in deine Zwischenablage
- Notiere ihn NICHT in öffentlichen Dokumenten
- Nutze einen Password-Manager zur sicheren Aufbewahrung

---

### ✅ Schritt 2: Script bei Ubuntu-Installation einfügen

**Ziel:** IONOS VPS mit vorinstalliertem Tailscale erstellen

#### 2.1 IONOS Cloud Panel öffnen

Gehe zu deinem IONOS Account und wähle **"VPS erstellen"**

#### 2.2 VPS-Konfiguration

| Parameter | Empfohlener Wert | Notizen |
|-----------|------------------|---------|
| **OS** | Ubuntu 24.04 LTS | Identisch zu Produktiv-VPS |
| **CPU** | 4 Cores | Für realistische Performance-Tests |
| **RAM** | 8 GB | Ausreichend für alle Komponenten |
| **Storage** | 200 GB SSD | Identisch zu Produktiv |
| **Datacenter** | Gleicher Standort wie Produktiv | Niedrige Latenz |

#### 2.3 Cloud-Init Script einfügen

Im Abschnitt **"Cloud-Init / User Data"** füge folgendes Script ein:

```yaml
#cloud-config

hostname: devsystem-qs-vps

# System Updates
package_update: true
package_upgrade: true

# Basis-Pakete
packages:
  - ufw
  - fail2ban
  - curl
  - git

runcmd:
  # Tailscale installieren
  - curl -fsSL https://tailscale.com/install.sh | sh
  
  # Tailscale mit deinem Auth Key starten (ERSETZE DEN KEY!)
  - tailscale up --authkey=DEIN_TAILSCALE_AUTH_KEY_HIER --hostname=devsystem-qs-vps --ssh
  
  # Tailscale-IP speichern
  - tailscale ip -4 > /root/tailscale-ip.txt
  
  # UFW Firewall konfigurieren
  - ufw --force reset
  - ufw default deny incoming
  - ufw default allow outgoing
  - ufw allow in on tailscale0 to any port 22 comment 'SSH via Tailscale'
  - ufw allow 41641/udp comment 'Tailscale VPN'
  - ufw --force enable
  
  # Fail2ban aktivieren
  - systemctl enable fail2ban
  - systemctl start fail2ban
  
  # Fertig-Info
  - echo "QS-VPS Setup Stage 1 Complete" > /root/setup-stage1-complete.txt
  - date >> /root/setup-stage1-complete.txt
  - cat /root/tailscale-ip.txt >> /root/setup-stage1-complete.txt
```

**⚠️ KRITISCH:** Ersetze `DEIN_TAILSCALE_AUTH_KEY_HIER` mit dem Key aus Schritt 1!

#### 2.4 VPS erstellen

- Klicke **"VPS erstellen"**
- Warte ca. 5-10 Minuten bis der VPS bereitsteht
- Der Bereitstellungsprozess läuft automatisch

**Screenshot-Hinweis:** IONOS zeigt Status "Provisioning" → "Running"

---

### ✅ Schritt 3: IP aus Tailscale Admin kopieren

**Ziel:** Tailscale-IP des neuen QS-VPS ermitteln

#### 3.1 Tailscale Admin öffnen

```
URL: https://login.tailscale.com/admin/machines
```

#### 3.2 QS-VPS finden

Suche nach dem Hostname: **`devsystem-qs-vps`**

Du solltest einen neuen Eintrag sehen:

| Spalte | Erwarteter Wert |
|--------|-----------------|
| **Name** | `devsystem-qs-vps` |
| **IP Address** | `100.x.y.z` (z.B. `100.100.221.78`) |
| **Status** | 🟢 Online |
| **Tags** | `tag:qs-server` (falls gesetzt) |
| **Expires** | Ephemeral (entfernt sich automatisch) |

#### 3.3 IP kopieren

Klicke auf den Server und kopiere die **IPv4-Adresse**:

```
Beispiel: 100.100.221.78
```

**Hinweis:** Die IP liegt immer im Bereich `100.64.0.0/10` (Tailscale CGNAT-Range)

---

### ✅ Schritt 4: IP im Chat übergeben

**Ziel:** Automatisches Setup triggern

#### 4.1 Chat-Nachricht an Roo Code

Öffne Roo Code im code-server und sende folgende Nachricht:

```
QS-VPS Setup initiieren mit IP: 100.100.221.78
```

**Oder ausführlicher:**

```
Bitte führe das komplette QS-DevServer Setup für folgende Tailscale-IP durch:

IP: 100.100.221.78
Hostname: devsystem-qs-vps
Branch: feature/qs-vps-setup

Komponenten:
- Caddy Reverse Proxy (Port 9443)
- code-server Web-IDE (Port 8080 → via Caddy)
- Qdrant Vektordatenbank (Port 6333/6334)

Bitte protokolliere alle Ergebnisse und pushe nach GitHub main.
```

#### 4.2 Was passiert jetzt?

Ab diesem Punkt übernimmt **Roo Code** die Kontrolle und führt automatisch aus:

1. ✅ SSH-Verbindung zum QS-VPS herstellen
2. ✅ Alle Installations-Scripts ausführen
3. ✅ E2E-Tests durchführen
4. ✅ Ergebnisse dokumentieren
5. ✅ GitHub Commit + Push
6. ✅ HTTPS-URL ausgeben

**⏱️ Geschätzte Dauer:** 15-30 Minuten (ohne Benutzerinteraktion)

---

## 🟦 Teil 2: Automatisierter Setup (Roo Code)

### ⚙️ Schritt 5: Gesamter QS-Prozess per SSH

**Automatisch durchgeführt von Roo Code**

#### 5.1 SSH-Verbindung etablieren

```bash
# Roo Code führt aus:
ssh root@100.100.221.78 "echo 'SSH connection established'"
```

**Validierung:**
- SSH-Key-basierte Authentifizierung (via Tailscale SSH)
- Keine Passwort-Abfrage nötig

#### 5.2 Repository klonen

```bash
# Auf QS-VPS:
cd /root
git clone https://github.com/HaraldKiessling/DevSystem.git
cd DevSystem
git checkout feature/qs-vps-setup  # Oder main, je nach Branch
```

#### 5.3 Komponenten installieren

**Phase A: Caddy Reverse Proxy**

```bash
# Caddy installieren
bash scripts/qs/install-caddy-qs.sh

# Caddy konfigurieren für QS-VPS
bash scripts/qs/configure-caddy-qs.sh

# Test-Output:
# ✅ Caddy installiert: /usr/bin/caddy
# ✅ Service läuft: active (running)
# ✅ Port 9443 lauscht auf Tailscale-IP
```

**Phase B: code-server Web-IDE**

```bash
# code-server installieren
bash scripts/qs/install-code-server-qs.sh

# code-server konfigurieren
bash scripts/qs/configure-code-server-qs.sh

# Test-Output:
# ✅ code-server installiert: v4.114.1+
# ✅ Service läuft: active (running)
# ✅ Lauscht auf localhost:8080
# ✅ Passwort generiert: P4eJISeX9RPPVQcn0os9544sjaFAFVEV
```

**Phase C: Qdrant Vektordatenbank**

```bash
# Qdrant deployen
bash scripts/qs/deploy-qdrant-qs.sh

# Test-Output:
# ✅ Qdrant Binary heruntergeladen: v1.7.4
# ✅ Config erstellt: /opt/qdrant/config.yaml
# ✅ Service läuft: active (running)
# ✅ HTTP API: localhost:6333 OK
# ✅ gRPC API: localhost:6334 OK
```

#### 5.4 End-to-End Tests

```bash
# Vollständige Test-Suite ausführen
bash scripts/qs/test-qs-deployment.sh

# Erwartete Test-Ergebnisse:
#
# Test 1: Tailscale Connectivity ✅
#   - Tailscale Status: Connected
#   - IP: 100.100.221.78
#   - MagicDNS: devsystem-qs-vps.tailcfea8a.ts.net
#
# Test 2: Caddy HTTPS (Port 9443) ✅
#   - HTTPS Listener: ACTIVE
#   - TLS Zertifikat: Valid (Tailscale-signed)
#   - Proxy to code-server: OK
#
# Test 3: code-server Login ✅
#   - HTTP Status: 200 OK
#   - Login Page: Rendered
#   - WebSocket: Connection OK
#
# Test 4: Qdrant API ✅
#   - HTTP API (6333): Responding
#   - gRPC API (6334): Healthy
#   - Collections: [] (leer wie erwartet)
#
# Test 5: Firewall Rules ✅
#   - UFW Status: active
#   - SSH on tailscale0: ALLOW
#   - Port 9443: ALLOW IN (via Tailscale)
#
# Test 6: Service Health ✅
#   - caddy.service: active (running)
#   - code-server@codeserver.service: active (running)
#   - qdrant.service: active (running)
#   - fail2ban.service: active (running)
#
# OVERALL: 6/6 Tests PASSED ✅
```

#### 5.5 Log-Validierung

```bash
# Logs prüfen für kritische Fehler
journalctl -u caddy --since "10 minutes ago" --no-pager
journalctl -u code-server@codeserver --since "10 minutes ago" --no-pager
journalctl -u qdrant --since "10 minutes ago" --no-pager

# Erwartung: Keine ERROR oder CRITICAL Level Messages
```

---

### 📝 Schritt 6: Ergebnis protokollieren

**Automatisch durchgeführt von Roo Code**

#### 6.1 Test-Ergebnisse dokumentieren

Roo Code erstellt automatisch: `vps-test-results-qs.md`

```markdown
# QS-VPS Test Results

**Datum:** 2026-04-10 05:30:00 UTC
**Tailscale-IP:** 100.100.221.78
**Hostname:** devsystem-qs-vps
**Branch:** feature/qs-vps-setup

## System-Informationen

- OS: Ubuntu 24.04.1 LTS
- Kernel: 6.8.0-58-generic
- RAM: 8GB
- CPU: 4 Cores
- Storage: 200GB SSD

## Komponenten-Status

| Komponente | Version | Status | Port | Bemerkungen |
|------------|---------|--------|------|-------------|
| Tailscale | 1.76.6 | ✅ Online | 41641/udp | MagicDNS aktiv |
| Caddy | 2.8.4 | ✅ Running | 9443 | HTTPS mit Tailscale-Cert |
| code-server | 4.114.1 | ✅ Running | 8080 | Via Caddy Proxy |
| Qdrant | 1.7.4 | ✅ Running | 6333/6334 | Leere DB |

## E2E-Tests

✅ Alle 6 Tests erfolgreich bestanden

## Zugriffsdaten

### HTTPS-URL (Primär)
https://100.100.221.78:9443

### HTTPS-URL (MagicDNS)
https://devsystem-qs-vps.tailcfea8a.ts.net:9443

### code-server Credentials
Passwort: P4eJISeX9RPPVQcn0os9544sjaFAFVEV

## Logs (Auszüge)

[Relevante Log-Snippets werden hier eingefügt]

## Offene Punkte

Keine kritischen Issues

---

**Setup abgeschlossen:** ✅
```

#### 6.2 Screenshot-Evidenz (optional)

Falls möglich, macht Roo Code Screenshots:
- code-server Login-Page
- Tailscale Admin Panel mit QS-VPS
- Caddy Status-Page

---

### 🚀 Schritt 7: GitHub Commit/Push + HTTPS-URL ausgeben

**Automatisch durchgeführt von Roo Code**

#### 7.1 Git Commit

```bash
# Auf lokalem System (nicht auf QS-VPS)
cd /root/work/DevSystem

git add vps-test-results-qs.md
git add scripts/qs/*.sh  # Falls neue Scripts erstellt wurden

git commit -m "✅ QS-VPS Setup abgeschlossen

- Tailscale-IP: 100.100.221.78
- Hostname: devsystem-qs-vps
- Alle Komponenten installiert (Caddy, code-server, Qdrant)
- E2E-Tests: 6/6 PASSED
- HTTPS-URL: https://devsystem-qs-vps.tailcfea8a.ts.net:9443
"
```

#### 7.2 Push zu GitHub

```bash
git push origin main
```

**Validierung:**
- Commit erscheint auf GitHub: https://github.com/HaraldKiessling/DevSystem
- Test-Ergebnisse sind öffentlich einsehbar

#### 7.3 Finale Ausgabe im Chat

Roo Code gibt aus:

```
✅ QS-DevServer Setup erfolgreich abgeschlossen!

═══════════════════════════════════════════════════════
  🎉 QS-VPS ist bereit für Qualitätssicherung
═══════════════════════════════════════════════════════

📍 Zugriff via HTTPS:

  Primär (IP-basiert):
  https://100.100.221.78:9443

  Alternativ (MagicDNS):
  https://devsystem-qs-vps.tailcfea8a.ts.net:9443

🔐 code-server Credentials:

  Passwort: P4eJISeX9RPPVQcn0os9544sjaFAFVEV

📊 Komponenten-Status:

  ✅ Tailscale VPN    (100.100.221.78)
  ✅ Caddy Proxy      (Port 9443)
  ✅ code-server IDE  (Port 8080 → via Caddy)
  ✅ Qdrant DB        (Port 6333/6334)

🧪 Test-Ergebnisse:

  6/6 E2E-Tests bestanden
  0 kritische Fehler in Logs
  
  Details: vps-test-results-qs.md

📦 GitHub:

  ✅ Committed to main
  ✅ https://github.com/HaraldKiessling/DevSystem/blob/main/vps-test-results-qs.md

🚀 Nächste Schritte:

  1. Öffne die HTTPS-URL in deinem Browser
  2. Login mit dem code-server Passwort
  3. Beginne mit QS-Tests

═══════════════════════════════════════════════════════
```

---

## 📦 Teil 3: Minimal-Script für Ubuntu-Installation

### Copy-Paste-Ready Cloud-Init Script

```yaml
#cloud-config

hostname: devsystem-qs-vps

package_update: true
package_upgrade: true

packages:
  - ufw
  - fail2ban
  - curl
  - git

runcmd:
  # Tailscale installieren
  - curl -fsSL https://tailscale.com/install.sh | sh
  
  # Tailscale starten - ERSETZE DEN AUTH KEY!
  - tailscale up --authkey=DEIN_TAILSCALE_AUTH_KEY_HIER --hostname=devsystem-qs-vps --ssh
  
  # IP speichern
  - tailscale ip -4 > /root/tailscale-ip.txt
  
  # Firewall
  - ufw --force reset
  - ufw default deny incoming
  - ufw default allow outgoing
  - ufw allow in on tailscale0 to any port 22
  - ufw allow 41641/udp
  - ufw --force enable
  
  # Fail2ban
  - systemctl enable fail2ban
  - systemctl start fail2ban
  
  # Fertig-Marker
  - echo "Ready for QS-Setup" > /root/stage1-complete.txt
```

**Platzhalter ersetzen:**
- `DEIN_TAILSCALE_AUTH_KEY_HIER` → Dein Key aus Schritt 1

**Dieses Script:**
- ✅ Installiert Tailscale
- ✅ Konfiguriert UFW Firewall
- ✅ Aktiviert Fail2ban
- ✅ Speichert Tailscale-IP nach `/root/tailscale-ip.txt`
- ⏱️ Läuft automatisch beim ersten Boot (~5 Min)

---

## ✅ Teil 4: Erwartetes Ergebnis

### 🎯 Success Criteria

Nach Abschluss des kompletten Workflows hast du:

#### 1. Funktionsfähigen QS-VPS

| Service | Status | Erreichbar unter |
|---------|--------|------------------|
| **Tailscale VPN** | 🟢 Online | IP: `100.x.y.z` |
| **HTTPS Zugang** | 🟢 Aktiv | `https://devsystem-qs-vps.tailcfea8a.ts.net:9443` |
| **code-server IDE** | 🟢 Running | Via HTTPS-URL (Port 9443) |
| **Qdrant DB** | 🟢 Ready | Localhost only (6333/6334) |

#### 2. MagicDNS-Zugriff

```bash
# Von jedem Gerät in deinem Tailscale-Netzwerk:
curl -k https://devsystem-qs-vps.tailcfea8a.ts.net:9443

# Response: code-server Login-Page
```

#### 3. Dokumentierte Ergebnisse

- ✅ `vps-test-results-qs.md` auf GitHub
- ✅ Alle Logs archiviert
- ✅ Zugriffsdaten gesichert
- ✅ E2E-Test-Ergebnisse vollständig

#### 4. Produktionsreife QS-Umgebung

Der QS-VPS ist nun bereit für:
- 🧪 Feature-Tests vor Produktiv-Deployment
- 🔬 Experimente ohne Risiko
- 📊 Performance-Benchmarks
- 🚨 Disaster-Recovery-Übungen
- 🎓 Schulungen und Demos

---

## 🔧 Troubleshooting

### Problem 1: Tailscale-IP wird nicht angezeigt

**Symptom:**
- Tailscale Admin zeigt keinen `devsystem-qs-vps`
- VPS ist bereitgestellt, aber nicht sichtbar

**Diagnose:**

```bash
# SSH via IONOS Web-Konsole (nicht Tailscale)
# Prüfe Cloud-Init Status:
cloud-init status

# Erwartung: status: done
# Falls status: error → siehe Logs:
cat /var/log/cloud-init-output.log
```

**Häufige Ursachen:**

| Ursache | Lösung |
|---------|--------|
| **Auth Key falsch** | Neuen Key generieren, Script anpassen |
| **Cloud-Init nicht abgeschlossen** | 5-10 Minuten warten, dann neu prüfen |
| **Tailscale Installation fehlgeschlagen** | Manuell installieren: `curl -fsSL https://tailscale.com/install.sh \| sh` |

**Manuelle Lösung:**

```bash
# Falls Cloud-Init fehlgeschlagen:
sudo tailscale up --authkey=NEUER_KEY_HIER --hostname=devsystem-qs-vps --ssh
sudo tailscale ip -4 > /root/tailscale-ip.txt
cat /root/tailscale-ip.txt  # IP anzeigen
```

---

### Problem 2: SSH-Verbindung schlägt fehl

**Symptom:**
```
ssh root@100.100.221.78
Connection timed out
```

**Diagnose:**

```bash
# Lokale Tailscale-Verbindung prüfen:
tailscale status

# Erwartung: devsystem-qs-vps sollte gelistet sein
# Falls nicht sichtbar → VPS ist offline oder Tailscale nicht gestartet
```

**Lösungen:**

| Problem | Lösung |
|---------|--------|
| **VPS offline** | Prüfe IONOS Cloud Panel, ggf. VPS neu starten |
| **Lokales Tailscale offline** | `tailscale up` auf deinem System |
| **Firewall blockiert** | Prüfe UFW auf QS-VPS via IONOS Web-Konsole |
| **Falscher SSH-Key** | Nutze Tailscale SSH: `ssh -o "ProxyCommand=tailscale nc %h %p" root@100.100.221.78` |

**Alternative via IONOS Web-Konsole:**

```
1. IONOS Cloud Panel öffnen
2. QS-VPS auswählen
3. "Remote Console" oder "VNC" öffnen
4. Direct-Login als root (mit IONOS-initialen Credentials)
5. Tailscale manuell starten:
   sudo systemctl start tailscaled
   sudo tailscale up --authkey=KEY
```

---

### Problem 3: Caddy liefert 403 Forbidden

**Symptom:**
```bash
curl https://100.100.221.78:9443
403 Forbidden: Zugriff nur über Tailscale erlaubt
```

**Ursache:**
Du greifst NICHT über Tailscale zu, sondern über die öffentliche IONOS-IP.

**Lösung:**

```bash
# 1. Stelle sicher, dass dein System in Tailscale ist:
tailscale status

# 2. Nutze die TAILSCALE-IP (100.x.y.z), nicht die IONOS-IP
curl -k https://100.100.221.78:9443  # ✅ Richtig (Tailscale-IP)
curl https://185.x.y.z:9443          # ❌ Falsch (IONOS Public-IP)

# 3. Oder nutze MagicDNS:
curl -k https://devsystem-qs-vps.tailcfea8a.ts.net:9443
```

**Caddy Caddyfile-Check:**

```bash
# Auf QS-VPS:
cat /etc/caddy/Caddyfile

# Sollte enthalten:
#   @tailscale {
#       remote_ip 100.64.0.0/10
#   }
```

---

### Problem 4: code-server lädt nicht (Blank Page)

**Symptom:**
- HTTPS-URL öffnet sich
- Browser zeigt leere Seite oder Loading-Spinner
- Keine Login-Maske

**Diagnose:**

```bash
# Auf QS-VPS:
systemctl status code-server@codeserver

# Erwartung: active (running)
# Falls failed → siehe spezifische Logs:
journalctl -u code-server@codeserver -n 50
```

**Häufige Ursachen:**

| Ursache | Lösung |
|---------|--------|
| **code-server nicht gestartet** | `sudo systemctl start code-server@codeserver` |
| **Port 8080 belegt** | `sudo lsof -i :8080` → anderen Process stoppen |
| **WebSocket-Probleme** | Browser-DevTools → Console → Prüfe WebSocket Errors |
| **Caddy Proxy-Config falsch** | Caddyfile prüfen: `reverse_proxy localhost:8080` vorhanden? |

**Manueller Test:**

```bash
# Auf QS-VPS (direkt, ohne Caddy):
curl http://localhost:8080

# Sollte HTML zurückgeben (code-server Login-Page)
# Falls nicht → code-server ist das Problem, nicht Caddy
```

---

### Problem 5: Qdrant API antwortet nicht

**Symptom:**
```bash
curl http://localhost:6333/collections
curl: (7) Failed to connect to localhost port 6333
```

**Diagnose:**

```bash
# Auf QS-VPS:
systemctl status qdrant

# Falls not running:
journalctl -u qdrant -n 50
```

**Lösungen:**

| Problem | Lösung |
|---------|--------|
| **Binary nicht gefunden** | Prüfe `/opt/qdrant/qdrant` existiert, führe rebuild aus |
| **Config-Fehler** | Validiere `/opt/qdrant/config.yaml` (YAML-Syntax) |
| **Port bereits belegt** | `sudo lsof -i :6333` → anderen Process stoppen |
| **Permission-Problem** | `sudo chown -R qdrant:qdrant /var/lib/qdrant` |

**Manueller Start:**

```bash
# Zum Debuggen:
sudo -u qdrant /opt/qdrant/qdrant --config-path /opt/qdrant/config.yaml

# Output sollte zeigen:
#   Qdrant is listening on: 127.0.0.1:6333
```

---

### Problem 6: Roo Code meldet "SSH authentifiziert nicht"

**Symptom:**
```
Error: Permission denied (publickey)
```

**Ursache:**
- Tailscale SSH ist nicht aktiviert
- SSH-Keys fehlen

**Lösung:**

```bash
# Auf QS-VPS (via IONOS Web-Konsole):
# 1. Tailscale SSH aktivieren:
sudo tailscale up --ssh

# 2. Oder: SSH-Key manuell hinzufügen:
mkdir -p /root/.ssh
echo "DEIN_SSH_PUBLIC_KEY" >> /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

# 3. SSH-Config auf lokalem System:
cat >> ~/.ssh/config << EOF
Host devsystem-qs-vps
    Hostname 100.100.221.78
    User root
    ProxyCommand tailscale nc %h %p
    StrictHostKeyChecking no
EOF
```

---

## 📚 Referenzen und weiterführende Dokumentationen

### Verwandte Dokumente

| Dokument | Beschreibung |
|----------|--------------|
| [`scripts/QS-VPS-SETUP.md`](QS-VPS-SETUP.md) | Detaillierte manuelle Setup-Anleitung |
| [`plans/qs-vps-konzept.md`](../plans/qs-vps-konzept.md) | Vollständiges Architektur-Konzept |
| [`vps-deployment-caddy.md`](../vps-deployment-caddy.md) | Caddy-Deployment Details |
| [`vps-deployment-qdrant.md`](../vps-deployment-qdrant.md) | Qdrant-Deployment Details |

### Externe Ressourcen

- **Tailscale Dokumentation:** https://tailscale.com/kb/
- **Caddy Dokumentation:** https://caddyserver.com/docs/
- **code-server Dokumentation:** https://coder.com/docs/code-server/
- **Qdrant Dokumentation:** https://qdrant.tech/documentation/

---

## 🎓 Best Practices

### ✅ Empfohlene Vorgehensweise

1. **Testdurchläufe:** Führe zuerst einen kompletten Workflow manuell durch, bevor du Roo Code automatisch laufen lässt
2. **Dokumentation:** Speichere alle Tailscale Auth Keys sicher (Password-Manager)
3. **Naming:** Nutze konsistente Hostnamen (`devsystem-qs-vps`, nicht `test123`)
4. **Cleanup:** Lösche alte QS-VPS nach Tests, um Kosten zu sparen
5. **Logs:** Archiviere Test-Ergebnisse auf GitHub main (nicht nur lokal)

### ❌ Häufige Fehler vermeiden

- ❌ **NICHT:** Auth Keys in Git committen
- ❌ **NICHT:** Produktiv-Passwörter auf QS-VPS verwenden
- ❌ **NICHT:** QS-VPS mit Produktionsdaten befüllen
- ❌ **NICHT:** QS-VPS langfristig laufen lassen (Ephemeral nutzen)
- ❌ **NICHT:** Direkt auf Produktiv-VPS testen (immer erst QS)

---

## 📊 Workflow-Checkliste

### Vor dem Start

- [ ] Tailscale Account aktiv
- [ ] IONOS VPS Budget verfügbar
- [ ] GitHub Repository zugänglich
- [ ] Lokales Tailscale läuft

### User-Schritte (manuell)

- [ ] **Schritt 1:** Tailscale Auth Key generiert
- [ ] **Schritt 2:** Cloud-Init Script mit Key erstellt
- [ ] **Schritt 3:** VPS bei IONOS bereitgestellt
- [ ] **Schritt 4:** Tailscale-IP aus Admin-Panel kopiert
- [ ] **Schritt 5:** IP im Roo Code Chat übergeben

### Automatisierte Schritte (Roo Code)

- [ ] **Schritt 6:** SSH-Verbindung erfolgreich
- [ ] **Schritt 7:** Alle Komponenten installiert
- [ ] **Schritt 8:** E2E-Tests bestanden (6/6)
- [ ] **Schritt 9:** Ergebnisse dokumentiert
- [ ] **Schritt 10:** GitHub Commit + Push erfolgreich
- [ ] **Schritt 11:** HTTPS-URL funktioniert

### Nach dem Setup

- [ ] code-server Login erfolgreich
- [ ] Qdrant API erreichbar
- [ ] MagicDNS funktioniert
- [ ] Alle Credentials gesichert
- [ ] Test-Ergebnisse auf GitHub verfügbar

---

## 🚀 Nächste Schritte nach erfolgreichem Setup

### Sofort nutzbar

1. **Code-Editor öffnen:** Navigiere zur HTTPS-URL, logge dich ein
2. **Repository klonen:** Clone dein Dev-Repository ins code-server Workspace
3. **Erste QS-Tests:** Teste neue Features auf dem QS-VPS

### Erweiterte Nutzung

4. **Ollama installieren:** Lokale KI-Modelle für erweiterte Tests
5. **Roo Code Extension:** Multi-Agent-System auf QS-VPS aktivieren
6. **Custom Tests:** Eigene E2E-Test-Suites entwickeln
7. **Performance-Benchmarks:** Lasttests gegen QS-VPS durchführen

### Wartung

8. **Regelmäßige Updates:** `apt update && apt upgrade` wöchentlich
9. **Log-Rotation:** Prüfe `/var/log` Größe monatlich
10. **VPS-Cleanup:** Lösche QS-VPS nach Abschluss der Tests (Ephemeral wird automatisch entfernt)

---

**🎉 Workflow-Anleitung abgeschlossen!**

Bei Fragen oder Problemen: Siehe Troubleshooting-Sektion oder öffne ein GitHub Issue.

---

**Version:** 1.0  
**Letztes Update:** 2026-04-10  
**Maintainer:** DevSystem Team  
**Lizenz:** Interne Dokumentation
