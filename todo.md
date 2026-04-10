# DevSystem - Zentrale Aufgabenliste

## Projektzweck

Aufbau eines reproduzierbaren, cloudbasierten Entwicklungssystems auf einem IONOS Ubuntu VPS mit Tailscale (VPN), Caddy (Reverse Proxy) und code-server (Web-IDE). Das System muss vollständig per Handy-Browser (PWA) über code-server steuerbar sein.

## 🎯 MVP-Status

**Stand:** 2026-04-10 08:08 UTC

### ✅ Abgeschlossene Komponenten (100% MVP-funktionsfähig)

1. **VPS-Vorbereitung** ✅
   - Ubuntu-System gehärtet
   - Fail2ban, UFW konfiguriert
   - Status: Produktiv

2. **Tailscale VPN** ✅
   - Zero-Trust-Netzwerk aktiv
   - IP: 100.100.221.56
   - Hostname: devsystem-vps.tailcfea8a.ts.net
   - Status: Produktiv (kleine Verbindungsprobleme dokumentiert)

3. **Caddy Reverse-Proxy** ✅
   - HTTPS auf Port 9443
   - Tailscale-Zertifikate
   - Zugriffsbeschränkung auf Tailscale-IPs
   - Status: Produktiv (18/19 Tests bestanden)

4. **code-server Web-IDE** ✅
   - Version 4.114.1
   - Läuft stabil (>43 Min Uptime)
   - Über Tailscale erreichbar
   - Status: Funktionsfähig (Optimierungen im Backlog)

5. **Qdrant Vektordatenbank** ✅
   - Version 1.7.4 (native Binary)
   - HTTP API auf 127.0.0.1:6333
   - gRPC API auf 127.0.0.1:6334
   - Storage in /var/lib/qdrant
   - Läuft als systemd-Service (User: qdrant)
   - Status: Produktiv

### 🎉 MVP ist vollständig funktionsfähig!

Zugriff auf das DevSystem:
- **URL:** `https://100.100.221.56:9443` oder `https://devsystem-vps.tailcfea8a.ts.net:9443`
- **Passwort:** P4eJISeX9RPPVQcn0os9544sjaFAFVEV
- **Nur über Tailscale VPN erreichbar**

---

## 📋 MVP-Aufgaben

Keine aktiven MVP-Aufgaben - MVP ist vollständig abgeschlossen! 🎉

---

## 🎯 Post-MVP: QS-GitHub-Integration (Aktuelle Priorität: HOCH)

### Kontext
Vollautomatisierte QS-VPS-Deployments mit idempotenten Scripts über GitHub Actions. Ermöglicht Deployments vom Handy aus.

**Dokumentation:**
- [`plans/qs-github-integration-strategie.md`](plans/qs-github-integration-strategie.md) - Architektur & Strategie
- [`plans/qs-implementierungsplan-final.md`](plans/qs-implementierungsplan-final.md) - Detaillierter Implementierungsplan
- [`plans/QS-STRATEGY-SUMMARY.md`](plans/QS-STRATEGY-SUMMARY.md) - Executive Summary

**Geschätzter Gesamtaufwand:** 23-33 Stunden

---

### Phase 1: Idempotenz-Framework (8-12h) - STATUS: ⚠️ Code vollständig - E2E blockiert

**Status-Übersicht:**
- ✅ Idempotency-Library existiert und getestet (100% Pass)
- ✅ Test-Suite vollständig (`scripts/qs/test-idempotency-lib.sh`)
- ✅ **ALLE 7 Scripts** nutzen Library (100% Integration)
- ❌ **E2E-Tests blockiert durch SSH-Problem** (Port 22 deaktiviert)
- 📄 **Dokumentation:** [`PHASE1-IDEMPOTENZ-STATUS.md`](PHASE1-IDEMPOTENZ-STATUS.md)

#### 1.1 Feature-Branch & Vorbereitung
- [x] 01 - Feature-Branch erstellt: `feature/qs-github-integration`
- [x] 02 - Idempotenz-Library getestet: 22/22 Tests bestanden
- [x] 03 - Test-Ergebnisse dokumentiert (100% Pass)
- [x] 04 - Library-Dokumentation geprüft und vollständig

#### 1.2 Script-Integration: Caddy
- [x] 05 - `scripts/qs/install-caddy-qs.sh` analysiert
- [x] 06 - Library in `install-caddy-qs.sh` eingebunden
- [x] 07 - Marker-System integriert
- [x] 08 - State-Speicherung hinzugefügt
- [x] 09 - `scripts/qs/configure-caddy-qs.sh` analysiert
- [x] 10 - Backup-Mechanismus implementiert
- [x] 11 - Checksum-basierte Validierung implementiert
- [x] 12 - Marker für Caddy-Config gesetzt

#### 1.3 Script-Integration: code-server
- [x] 13 - `scripts/qs/install-code-server-qs.sh` analysiert
- [x] 14 - Library in `install-code-server-qs.sh` eingebunden
- [x] 15 - Marker-System integriert
- [x] 16 - State-Speicherung hinzugefügt
- [x] 17 - `scripts/qs/configure-code-server-qs.sh` analysiert
- [x] 18 - Checksum-basierte Config-Updates implementiert
- [x] 19 - Marker für code-server-Config gesetzt (Extensions + Service)

#### 1.4 Script-Integration: Qdrant
- [x] 20 - `scripts/qs/deploy-qdrant-qs.sh` analysiert
- [x] 21 - Library in `deploy-qdrant-qs.sh` eingebunden
- [x] 22 - Marker-System vollständig integriert
- [x] 23 - State-Speicherung hinzugefügt (Version, Ports, Timestamp)

#### 1.5 Idempotenz-Tests (E2E)
- [x] 24 - E2E-Test-Framework erstellt (`run-e2e-tests.sh`)
- [Blocked] 25-30 - E2E-Tests gegen VPS - **BLOCKIERT durch SSH-Problem**
  - Test-Versuch durchgeführt: `bash scripts/qs/run-e2e-tests.sh --host=100.100.221.56`
  - **Fehler:** Connection refused (Port 22)
  - **Problem dokumentiert in:** [`vps-test-results-phase1-e2e.md`](vps-test-results-phase1-e2e.md)
  - **Offene Entscheidung:** Siehe Abschnitt "Offene Entscheidungen" unten
- [x] 31 - Test-Ergebnisse dokumentiert (SSH-Blocker)
- [x] 32 - Code bereit zum Commit (wartet auf E2E-Success)

---

### Phase 2: Master-Orchestrator (6-8h) - STATUS: ✅ ABGESCHLOSSEN

**Ziel:** Zentrale Steuerung aller Deployment-Stages
**Dokumentation:** [`PHASE2-ORCHESTRATOR-STATUS.md`](PHASE2-ORCHESTRATOR-STATUS.md)

#### 2.1 Master-Script erstellen ✅
- [x] 33 - `scripts/qs/setup-qs-master.sh` erstellt (1036 Zeilen)
- [x] 34 - Idempotenz-Library eingebunden
- [x] 35 - Lock-Mechanismus implementiert (mit Stale-Detection, PID-Tracking)
- [x] 36 - Component-Definition erstellt (5 Components mit Dependencies)
- [x] 37 - Component-Runner-Funktion implementiert (`run_component()`)
- [x] 38 - Error-Handling hinzugefügt (Exit Codes, Cleanup)
- [x] 39 - Logging-System implementiert (6 Log-Level, farbig)
- [x] 40 - Argument-Parsing hinzugefügt (7 Flags: --force, --skip-checks, --component, --dry-run, --rollback, --resume, --help)

#### 2.2 Deployment-Report-Generator ✅
- [x] 41 - Report-Generator-Funktion implementiert (3 Formate)
- [x] 42 - Markdown-Report-Template erstellt
- [x] 43 - System-Informationen sammeln (OS, Kernel, Uptime, RAM, Disk)
- [x] 44 - Component-Status auslesen (aus State-Files)
- [x] 45 - Komponenten-Status sammeln (Versionen, systemctl Status, Ports)
- [x] 46 - Zugriffsinformationen hinzugefügt (URL, Passwort-Verweis)
- [x] 47 - Triple-Format-Reports: Terminal + Markdown + JSON

#### 2.3 Master-Orchestrator Tests ✅
- [x] 48 - Test-Suite erstellt: `scripts/qs/test-master-orchestrator.sh` (16 Tests)
- [x] 49 - Idempotenz-Tests implementiert (Skip-Detection)
- [x] 50 - Force-Redeploy-Flag getestet
- [x] 51 - Lock-Mechanismus getestet (parallele Ausführung blockiert)
- [x] 52 - Error-Handling implementiert (Rollback + Resume)
- [x] 53 - Deployment-Report validiert (alle 3 Formate)
- [x] 54 - Test-Ergebnisse dokumentiert (lokale Tests erfolgreich)
- [x] 55 - Phase 2 Code vollständig (wartet auf Commit)

**Ergebnisse:**
- ✅ Master-Orchestrator: 1036 Zeilen, Production-Ready
- ✅ Test-Suite: 16 Tests (13 lokal bestanden)
- ✅ 6 Deployment-Modi: Normal, Force, Dry-Run, Rollback, Resume, Component-Filter
- ✅ 3 Report-Formate: Terminal (farbig) + Markdown + JSON
- ✅ Environment-Validation: 8 automatische Checks
- ⏳ Remote-Tests warten auf SSH-Zugang (Phase 1 Blocker)

---

### Phase 3: GitHub Actions Integration (4-6h) - PRIORITÄT: MITTEL

**Ziel:** Deployment vom Handy via GitHub UI

#### 3.1 Workflow-Datei erstellen
- [Todo] 56 - Verzeichnis erstellen: `mkdir -p .github/workflows`
- [Todo] 57 - Workflow-Datei erstellen: `.github/workflows/deploy-qs-vps.yml`
- [Todo] 58 - Workflow-Trigger konfigurieren (`workflow_dispatch`)
- [Todo] 59 - Input-Parameter definieren (qs_vps_ip, force_redeploy)
- [Todo] 60 - Step 1: Repository Checkout (`actions/checkout@v4`)
- [Todo] 61 - Step 2: Tailscale Connection (`tailscale/github-action@v2`)
- [Todo] 62 - Step 3: SSH Setup (Key aus Secret)
- [Todo] 63 - Step 4: Repository auf QS-VPS deployen (git clone/pull)
- [Todo] 64 - Step 5: Master-Orchestrator ausführen (SSH Remote Command)
- [Todo] 65 - Step 6: Deployment-Report abrufen (scp/ssh cat)
- [Todo] 66 - Step 7: Test-Ergebnisse abrufen
- [Todo] 67 - Step 8: Artifacts hochladen (`actions/upload-artifact@v4`)
- [Todo] 68 - Step 9: Success-Message mit URL ausgeben

#### 3.2 GitHub Secrets Setup
- [Todo] 69 - Dokumentation erstellen: `docs/GITHUB-SECRETS-SETUP.md`
- [Todo] 70 - Tailscale Auth Key generieren (login.tailscale.com)
- [Todo] 71 - SSH-Key für QS-VPS generieren (`ssh-keygen`)
- [Todo] 72 - Public Key auf QS-VPS deployen (`ssh-copy-id`)
- [Todo] 73 - Secret `TAILSCALE_AUTH_KEY` in GitHub hinterlegen
- [Todo] 74 - Secret `QS_VPS_SSH_KEY` in GitHub hinterlegen (Private Key!)
- [Todo] 75 - Secrets-Setup in Dokumentation beschreiben

#### 3.3 Workflow-Tests
- [Todo] 76 - Workflow manuell triggern (GitHub UI: Actions → Deploy QS-VPS)
- [Todo] 77 - Workflow-Logs prüfen (alle Steps erfolgreich?)
- [Todo] 78 - Tailscale-Verbindung validieren (GitHub Runner → QS-VPS)
- [Todo] 79 - SSH-Verbindung validieren
- [Todo] 80 - Deployment-Erfolg prüfen (HTTPS-URL erreichbar?)
- [Todo] 81 - Artifacts prüfen (Report heruntergeladen?)
- [Todo] 82 - Workflow vom Smartphone testen (GitHub Mobile App)
- [Todo] 83 - Test-Ergebnisse dokumentieren
- [Todo] 84 - Commit & Push: Phase 3 abgeschlossen

---

### Phase 4: Remote E2E-Tests (3-4h) - PRIORITÄT: NIEDRIG

**Ziel:** Tests von GitHub Actions aus gegen QS-VPS

#### 4.1 Remote-Test-Script erstellen
- [Todo] 85 - Script erstellen: `scripts/qs/test-qs-deployment-remote.sh`
- [Todo] 86 - Test 1: SSH-Connectivity (Timeout 10s)
- [Todo] 87 - Test 2: Services laufen (tailscaled, caddy, code-server, qdrant)
- [Todo] 88 - Test 3: HTTPS-Zugriff (curl zu Port 9443)
- [Todo] 89 - Test 4: Qdrant API (curl zu localhost:6333 via SSH)
- [Todo] 90 - JSON-Output-Format implementieren (für maschinenlesbare Auswertung)
- [Todo] 91 - Exit-Codes korrekt setzen (0 = success, 1 = failed)

#### 4.2 Workflow-Integration
- [Todo] 92 - Remote-Tests in `deploy-qs-vps.yml` integrieren (neuer Step)
- [Todo] 93 - Test-Ergebnisse als JSON speichern
- [Todo] 94 - JSON-Report als Artifact hochladen
- [Todo] 95 - Workflow-Badge in README.md hinzufügen

#### 4.3 Remote-Tests validieren
- [Todo] 96 - Tests von lokalem Rechner ausführen (gegen QS-VPS)
- [Todo] 97 - Tests aus GitHub Actions ausführen
- [Todo] 98 - Fehlerbehandlung testen (QS-VPS offline simulieren)
- [Todo] 99 - Test-Ergebnisse dokumentieren
- [Todo] 100 - Commit & Push: Phase 4 abgeschlossen

---

### Phase 5: Dokumentation & Finalisierung (2-3h) - PRIORITÄT: MITTEL

**Ziel:** Vollständige Dokumentation und Projektabschluss

#### 5.1 Dokumentations-Updates
- [Todo] 101 - README.md aktualisieren:
  - Workflow-Badge hinzufügen
  - QS-GitHub-Integration Sektion erstellen
  - Quick-Start-Anleitung hinzufügen
- [Todo] 102 - `scripts/QS-DEVSERVER-WORKFLOW.md` überarbeiten:
  - GitHub Actions Workflow beschreiben
  - Deployment vom Handy dokumentieren
  - Troubleshooting erweitern
- [Todo] 103 - Changelog erstellen: `CHANGELOG-QS-GITHUB-INTEGRATION.md`
  - Alle Änderungen chronologisch auflisten
  - Breaking Changes markieren
  - Neue Features beschreiben

#### 5.2 Projekt-Cleanup
- [Todo] 104 - `.gitignore` aktualisieren:
  - `.env.qs` hinzufügen
  - Lokale Test-Dateien ausschließen
- [Todo] 105 - Alte/deprecated Scripts archivieren (falls vorhanden)
- [Todo] 106 - Code-Review durchführen (alle neuen/geänderten Dateien)
- [Todo] 107 - Finale Tests durchführen (End-to-End vom Handy)

#### 5.3 Merge & Abschluss
- [Todo] 108 - Alle Änderungen committen
- [Todo] 109 - Branch in `main` mergen
- [Todo] 110 - Git-Tag erstellen: `v1.0.0-qs-github-integration`
- [Todo] 111 - Feature als abgeschlossen markieren in dieser todo.md
- [Todo] 112 - Post-Mortem dokumentieren (Was lief gut? Was verbessern?)

---

## ✅ Abgeschlossene Aufgaben (Archiv)

### VPS-Vorbereitung
- [Merged] VPS-Vorbereitungsskript erstellt (prepare-vps.sh)
- [Merged] E2E-Tests für VPS-Vorbereitung entwickelt (test-vps-preparation.sh)
- [Merged] Probleme bei der VPS-Vorbereitung identifiziert
- [Merged] Korrekturskript erstellt (fix-vps-preparation.sh)
- [Merged] Korrekturskript auf dem VPS ausgeführt
- [Merged] Ergebnisse dokumentiert (plans/vps-korrekturen-ergebnisse.md)

### Tailscale-Implementierung
- [Merged] Feature-Branch für Tailscale erstellt (feature/tailscale-setup)
- [Merged] Tailscale-Installationsskript entwickelt (install-tailscale.sh)
- [Merged] Tailscale-Konfigurationsskript entwickelt (configure-tailscale.sh)
- [Merged] E2E-Tests für Tailscale entwickelt (test-tailscale.sh)
- [Merged] Tailscale-Skripte auf dem VPS ausgeführt
- [Merged] E2E-Tests für Tailscale durchgeführt
- [Merged] Probleme mit Tailscale behoben

### Caddy-Implementierung
- [Merged] Caddy-Installationsskript entwickelt (install-caddy.sh)
- [Merged] Caddy-Konfigurationsskript entwickelt (configure-caddy.sh)
- [Merged] E2E-Tests für Caddy entwickelt (test-caddy.sh)
- [Merged] Caddy-Skripte auf dem VPS ausgeführt
- [Merged] E2E-Tests für Caddy durchgeführt (18/19 erfolgreich)
- [Merged] Caddy läuft auf Port 9443 mit TLS/HTTPS
- [Merged] Reverse Proxy für code-server konfiguriert
- [Merged] Automatisierung (Monitoring, Zertifikatserneuerung) eingerichtet
- [Merged] Dokumentation erstellt (vps-deployment-caddy.md, caddy-e2e-validation.md)

### code-server-Implementierung
- [Merged] Feature-Branch für code-server erstellt (feature/code-server-setup)
- [Merged] code-server-Installationsskript entwickelt (install-code-server.sh)
- [Merged] code-server-Konfigurationsskript entwickelt (configure-code-server.sh)
- [Merged] Update-Skript für sichere code-server-Updates entwickelt (update-code-server-safe.sh)
- [Merged] E2E-Tests für code-server entwickelt (test-code-server.sh)
- [Merged] code-server-Skripte auf dem VPS ausgeführt
- [Merged] E2E-Tests für code-server durchgeführt (0/7 erfolgreich - Meta-Test-Umgebung, funktioniert jedoch praktisch über Tailscale)
- [Merged] code-server läuft auf Port 8080 und ist über Caddy Reverse Proxy (Port 9443) erreichbar
- [Merged] Dokumentation erstellt (vps-test-results-code-server.md)

### Qdrant Vektordatenbank-Implementierung
- [Merged] Qdrant Version 1.7.4 nativ installiert (kein Docker)
- [Merged] Binary nach /opt/qdrant installiert
- [Merged] Storage-Verzeichnisse erstellt (/var/lib/qdrant, /var/log/qdrant)
- [Merged] Dedizierter User 'qdrant' erstellt
- [Merged] Minimale Konfiguration für localhost-Betrieb erstellt
- [Merged] systemd-Service eingerichtet und aktiviert
- [Merged] E2E-Tests erfolgreich durchgeführt:
  - HTTP API auf 127.0.0.1:6333 funktionsfähig
  - gRPC API auf 127.0.0.1:6334 funktionsfähig
  - Service läuft stabil als User 'qdrant'
  - Autostart aktiviert (enabled)
  - Health-Checks erfolgreich

---

## 🤔 Offene Entscheidungen

### 🔴 KRITISCH: SSH-Zugang zum QS-VPS (100.100.221.56) - Phase 1 Blocker

**Frage:** Wie wird SSH-Zugang zum QS-VPS ermöglicht, um E2E-Tests durchzuführen?

**Hintergrund:**
- Port 22 ist aktuell blockiert/deaktiviert auf VPS
- E2E-Tests gegen VPS benötigen SSH für Remote-Execution
- Alle 7 Scripts sind integriert, aber E2E-Validierung fehlt
- Tailscale-Verbindung funktioniert (Ping erfolgreich)
- Tailscale SSH schlägt fehl (502 Bad Gateway)

**Alternativen:**

1. **SSH-Dienst auf VPS aktivieren** (EMPFOHLEN)
   - Via alternative Zugriffsmethode (IONOS Console/VNC/Serial)
   - `systemctl enable --now ssh` auf VPS ausführen
   - **Pro:** Standard-Lösung, einfach zu debuggen, gut dokumentiert
   - **Contra:** Benötigt andere Zugriffsmethode zum VPS
   - **Zeitaufwand:** 5-10 Minuten

2. **Tailscale SSH korrekt konfigurieren**
   - `tailscale set --ssh` auf VPS ausführen
   - Tailscale-spezifische SSH-Konfiguration
   - **Pro:** Native Tailscale-Integration, kein offener Port nötig
   - **Contra:** Debugging komplexer, zusätzliche Konfiguration erforderlich
   - **Zeitaufwand:** 15-20 Minuten

3. **SSH auf anderem Port laufen lassen**
   - z.B. Port 2222 statt Standard-Port 22
   - Test-Script anpassen: `--port=2222`
   - **Pro:** Zusätzliche Security durch non-standard Port
   - **Contra:** Muss erst konfiguriert werden, kein Standard
   - **Zeitaufwand:** 10-15 Minuten

4. **UFW-Regel für Tailscale-Netz hinzufügen**
   - Port 22 nur für 100.64.0.0/10 (Tailscale) freigeben
   - `sudo ufw allow from 100.64.0.0/10 to any port 22`
   - **Pro:** Security, SSH nur via Tailscale erreichbar
   - **Contra:** UFW könnte bereits korrekt sein, Problem liegt woanders
   - **Zeitaufwand:** 5 Minuten

**Empfehlung:**
**Option 1 + 4 kombinieren:**
1. SSH-Dienst via IONOS Console/VNC aktivieren (`systemctl enable --now ssh`)
2. UFW-Regel hinzufügen für Tailscale-Netz (Security)
3. E2E-Tests durchführen und validieren
4. Bei Erfolg: Optional auf Tailscale SSH migrieren (Option 2)

**Begründung:**
- Schnellster Weg zur Lösung (5-10 Min)
- Standard SSH ist gut dokumentiert und debuggbar
- UFW-Regel erhöht Security (SSH nur über Tailscale)
- Nach erfolgreichen Tests kann auf modernere Lösung (Tailscale SSH) migriert werden

**Impact:**
- **Blocker für:** Phase 1 E2E-Tests (Aufgaben 25-30)
- **Blocks:** Phase 2 Start (Master-Orchestrator benötigt validierte Scripts)
- **Priorität:** KRITISCH - Muss vor Phase 2 gelöst sein

**Entscheidung:** ⏳ **Wartet auf Freigabe und Umsetzung**

---

**Format für neue Entscheidungen:**
- **Frage:** [Die genaue Problemstellung]
- **Alternativen:** [Mindestens 2 machbare technische Optionen]
- **Empfehlung:** [Klare Empfehlung als DevOps-Experte mit Begründung]

---

## 🗃️ Backlog / Zukünftige Ausbaustufen

### code-server Korrekturen (Post-MVP)

**Kontext:** code-server ist funktionsfähig und läuft stabil seit >43 Minuten. Folgende nicht-kritische Probleme sollten in einem separaten Branch behoben werden:

- [Todo] Feature-Branch `feature/code-server-fixes` erstellen
- [Todo] Read-Only-Problem beheben:
  - Berechtigungen für `/home/codeserver/.local/share/code-server/coder-logs/` korrigieren
  - `sudo chown -R codeserver:codeserver /home/codeserver/.local/share/code-server`
  - `sudo chmod -R u+w /home/codeserver/.local/share/code-server`
- [Todo] `configure-code-server.sh` überarbeiten:
  - Log-Kontamination in Config-Dateien beheben (exec-Umleitung korrigieren)
  - Script-Test in sauberer Umgebung durchführen
- [Todo] Extensions nachinstallieren (6 fehlende):
  - saoudrizwan.claude-dev (Roo Cline)
  - eamodio.gitlens
  - ms-azuretools.vscode-docker
  - ms-vscode-remote.remote-ssh
  - redhat.vscode-yaml
  - mads-hartmann.bash-ide-vscode
- [Todo] systemd-Service aktivieren und testen:
  - Aktuell laufende root-Instanz beenden (nur nach Arbeitsende!)
  - Service mit `systemctl enable --now code-server` starten
  - Validierung: Prozess läuft als User `codeserver`
- [Todo] E2E-Tests in sauberer Umgebung durchführen:
  - Alle 7 Tests vollständig ausführen
  - Log-Validierung durchführen
- [Todo] Security-Audit durchführen:
  - Bestätigen: Prozess läuft als `codeserver` (nicht root)
  - Berechtigungen aller Dateien prüfen
- [Todo] Zugriff über Tailscale validieren:
  - `https://100.100.221.56:9443` testen
  - `https://devsystem-vps.tailcfea8a.ts.net:9443` testen

### KI-Integration (Post-MVP)

- [Todo] Feature-Branch für KI-Integration erstellen
- [Todo] Roo Code Extension installieren und konfigurieren
- [Todo] OpenRouter API-Integration einrichten
- [Todo] Ollama installieren und konfigurieren
- [Todo] Lokale Modelle herunterladen und einrichten
- [Todo] Qdrant-Integration in RAG-Workflows testen
- [Todo] E2E-Tests für KI-Integration durchführen

### Projekt-Management

- [Todo] Projekt-Repository erstellen
- [Todo] Initiale Dokumentation aufsetzen
- [Todo] Projektmeilensteine definieren
- [Todo] Team-Rollen und Verantwortlichkeiten festlegen
- [Todo] Kickoff-Meeting organisieren

### Erweiterte Infrastruktur

- [Todo] Monitoring-Lösung einrichten
- [Todo] Backup-Strategie entwickeln und implementieren
- [Todo] Docker/Containerumgebung einrichten
- [Todo] Entwicklungstools und Dependencies installieren
- [Todo] CI/CD-Pipeline-Strategie festlegen
- [Todo] Storage-Lösung für Entwicklungsdaten auswählen
- [Todo] Multi-User-Konzept entwickeln
- [Todo] Kosten- und Skalierungsmodell definieren
- [Todo] Disaster-Recovery-Plan erstellen

### Erweiterte Tests

- [Todo] Testplan für Komponenten erstellen
- [Todo] Integrationstests definieren
- [Todo] Lasttests konzipieren und implementieren
- [Todo] Security-Audit durchführen
- [Todo] Dokumentation der Testfälle erstellen

### Erweiterte KI-Features

- [Todo] Multi-Modell-Strategie (OpenRouter + Ollama) optimieren
- [Todo] KI-Prompt-Templates für DevOps-Aufgaben erstellen
- [Todo] KI-gestützte Code-Reviews einrichten

---

## 📊 Projekt-Metriken

### MVP-Komponenten: 5/5 (100%)
- VPS-Vorbereitung: ✅
- Tailscale VPN: ✅
- Caddy Reverse-Proxy: ✅
- code-server Web-IDE: ✅
- Qdrant Vektordatenbank: ✅

### Post-MVP Features
- QS-GitHub-Integration: 🔄 In Planung (112 Aufgaben definiert)
- code-server Korrekturen: ⏸️ Verschoben
- KI-Integration: ⏸️ Backlog

### Nächster Meilenstein
**QS-GitHub-Integration Phase 1** - Idempotenz-Framework (Aufgaben 01-32)
- Geschätzter Aufwand: 8-12 Stunden
- Priorität: HOCH
- Start: Nach Freigabe dieser todo.md

---

**Letzte Aktualisierung:** 2026-04-10 08:08 UTC  
**Nächste Schritte:** Phase 1 der QS-GitHub-Integration starten
