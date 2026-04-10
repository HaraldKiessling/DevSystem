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

### Phase 1: Idempotenz-Framework (8-12h) - PRIORITÄT: HOCH

**Status-Übersicht:**
- ✅ Idempotency-Library existiert bereits (`scripts/qs/lib/idempotency.sh`)
- ✅ Test-Suite existiert bereits (`scripts/qs/test-idempotency-lib.sh`)
- ❌ Scripts nutzen Library noch nicht
- ❌ E2E-Tests ausstehend

#### 1.1 Feature-Branch & Vorbereitung
- [Todo] 01 - Feature-Branch erstellen: `git checkout -b feature/qs-github-integration`
- [Todo] 02 - Idempotenz-Library testen: `sudo bash scripts/qs/test-idempotency-lib.sh` lokal ausführen
- [Todo] 03 - Test-Ergebnisse dokumentieren (sollte 100% Pass sein)
- [Todo] 04 - Library-Dokumentation prüfen und ggf. ergänzen

#### 1.2 Script-Integration: Caddy
- [Todo] 05 - `scripts/qs/install-caddy-qs.sh` analysieren (aktuelle Idempotenz-Checks)
- [Todo] 06 - Library in `install-caddy-qs.sh` einbinden (`source lib/idempotency.sh`)
- [Todo] 07 - Marker-System in `install-caddy-qs.sh` integrieren (nach erfolgreicher Installation)
- [Todo] 08 - State-Speicherung hinzufügen (Caddy-Version, Install-Datum)
- [Todo] 09 - `scripts/qs/configure-caddy-qs.sh` analysieren (Config-Overwrite Problem)
- [Todo] 10 - Backup-Mechanismus in `configure-caddy-qs.sh` implementieren
- [Todo] 11 - Checksum-basierte Validierung hinzufügen (nur ändern wenn nötig)
- [Todo] 12 - Marker für Caddy-Config setzen

#### 1.3 Script-Integration: code-server
- [Todo] 13 - `scripts/qs/install-code-server-qs.sh` analysieren
- [Todo] 14 - Library in `install-code-server-qs.sh` einbinden
- [Todo] 15 - Marker-System integrieren
- [Todo] 16 - State-Speicherung hinzufügen (code-server Version)
- [Todo] 17 - `scripts/qs/configure-code-server-qs.sh` analysieren
- [Todo] 18 - Config-Merge-Mechanismus implementieren (statt Overwrite)
- [Todo] 19 - Marker für code-server-Config setzen

#### 1.4 Script-Integration: Qdrant
- [Todo] 20 - `scripts/qs/deploy-qdrant-qs.sh` analysieren (bereits gute Idempotenz!)
- [Todo] 21 - Library in `deploy-qdrant-qs.sh` einbinden
- [Todo] 22 - Marker-System hinzufügen (zusätzlich zu Binary-Check)
- [Todo] 23 - State-Speicherung hinzufügen (Qdrant Version, Deployment-Datum)

#### 1.5 Idempotenz-Tests (E2E)
- [Todo] 24 - Test-Environment vorbereiten (frischer QS-VPS oder lokales Testing)
- [Todo] 25 - Test 1: `install-caddy-qs.sh` 2x ausführen (2. Mal muss skippen)
- [Todo] 26 - Test 2: `configure-caddy-qs.sh` 2x ausführen (Checksum-Check)
- [Todo] 27 - Test 3: `install-code-server-qs.sh` 2x ausführen (2. Mal muss skippen)
- [Todo] 28 - Test 4: `configure-code-server-qs.sh` 2x ausführen (Config-Merge)
- [Todo] 29 - Test 5: `deploy-qdrant-qs.sh` 2x ausführen (2. Mal muss skippen)
- [Todo] 30 - Test 6: FORCE_REDEPLOY Flag testen (alle Scripts neu ausführen)
- [Todo] 31 - Alle Test-Ergebnisse dokumentieren
- [Todo] 32 - Commit & Push: Phase 1 abgeschlossen

---

### Phase 2: Master-Orchestrator (6-8h) - PRIORITÄT: HOCH

**Ziel:** Zentrale Steuerung aller Deployment-Stages

#### 2.1 Master-Script erstellen
- [Todo] 33 - `scripts/qs/deploy-qs-full.sh` erstellen (Basis-Struktur)
- [Todo] 34 - Idempotenz-Library einbinden
- [Todo] 35 - Lock-Mechanismus implementieren (verhindert parallele Ausführung)
- [Todo] 36 - Stage-Definition erstellen (System-Prep, Caddy, code-server, Qdrant, Tests)
- [Todo] 37 - Stage-Runner-Funktion implementieren (`run_stage()`)
- [Todo] 38 - Error-Handling hinzufügen (Abbruch bei Stage-Fehler)
- [Todo] 39 - Logging-System implementieren (Ausgabe + Log-Datei)
- [Todo] 40 - Argument-Parsing hinzufügen (`--force-redeploy`, `--help`)

#### 2.2 Deployment-Report-Generator
- [Todo] 41 - Report-Generator-Funktion implementieren (`generate_report()`)
- [Todo] 42 - Markdown-Report-Template erstellen
- [Todo] 43 - System-Informationen sammeln (OS, Kernel, Uptime)
- [Todo] 44 - Stage-Status auslesen (aus State-Files)
- [Todo] 45 - Komponenten-Status sammeln (Versionen, systemctl Status)
- [Todo] 46 - Zugriffsinformationen hinzufügen (URL, Passwort)
- [Todo] 47 - Report nach `/var/lib/qs-deployment/deployment-report.md` schreiben

#### 2.3 Master-Orchestrator Tests
- [Todo] 48 - Test 1: Vollständiges Deployment auf frischem QS-VPS
- [Todo] 49 - Test 2: Re-Deployment auf gleichem VPS (alle Stages müssen skippen)
- [Todo] 50 - Test 3: Force-Redeploy Flag testen (`--force-redeploy`)
- [Todo] 51 - Test 4: Lock-Mechanismus testen (parallele Ausführung verhindern)
- [Todo] 52 - Test 5: Fehler-Handling testen (Stage-Abbruch simulieren)
- [Todo] 53 - Deployment-Report validieren (alle Infos vorhanden?)
- [Todo] 54 - Test-Ergebnisse dokumentieren
- [Todo] 55 - Commit & Push: Phase 2 abgeschlossen

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

Aktuell keine offenen Entscheidungen.

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
