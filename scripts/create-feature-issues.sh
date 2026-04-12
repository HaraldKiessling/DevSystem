#!/bin/bash
# Script zum Erstellen der 15 Feature-Issues für DevSystem
# Quelle: docs/operations/feature-issues-batch-1.md

set -e

REPO="HaraldKiessling/DevSystem"
ISSUES_CREATED=()

echo "=================================="
echo "DevSystem Feature-Issues Creator"
echo "=================================="
echo ""

# Issue #1: Git-Branch-Cleanup
echo "Erstelle Issue #1: Git-Branch-Cleanup..."
ISSUE_1=$(gh issue create \
  --repo "$REPO" \
  --title "Git-Branch-Cleanup abschließen" \
  --label "quick-win,housekeeping,priority-medium" \
  --milestone "Phase 5 - Finalisierung" \
  --body '## 🎯 Value Statement

### User Need
**Als** Projektmaintainer  
**möchte ich** einen sauberen Git-Branch-Status  
**damit** das Repository übersichtlich bleibt und keine verwaisten Branches existieren

### Problem
Aktuell existiert noch 1 verwaister Branch (`qs-optimization`) nach dem großen Branch-Cleanup. Dies ist primär kosmetisch, aber für Projekt-Hygiene sollte er entfernt werden.

### Business Value
- **Impact:** Niedrig (kosmetisch)
- **Urgency:** Niedrig
- **User Benefit:** Sauberes Repository, einfachere Navigation

## ✅ Acceptance Criteria

- [ ] AC1: Status des Branch `qs-optimization` analysiert (remote & lokal)
- [ ] AC2: Branch sicher gelöscht via GitHub UI oder CLI
- [ ] AC3: Verifiziert: Nur `main` Branch existiert
- [ ] AC4: Dokumentation aktualisiert falls nötig

## 📊 Value/Effort Ratio

**Value Score:** 3/10  
**Effort Score:** 1/10  
**Ratio:** 3.0 (Quick Win)

**Justification:** Sehr schnell erledigbar (10 Min), minimaler aber existierender Wert für Projekt-Sauberkeit.

**Estimated:** 10 Min

## 🔗 References
- [Git-Branch-Cleanup Report](docs/archive/git-branch-cleanup/GIT-BRANCH-CLEANUP-REPORT.md)
- [STATUS.md](STATUS.md)' \
  2>&1)
ISSUES_CREATED+=("$ISSUE_1")
echo "✅ Issue #1 erstellt: $ISSUE_1"
echo ""

# Issue #2: Remote E2E-Tests Batch 1
echo "Erstelle Issue #2: Remote E2E-Tests Batch 1..."
ISSUE_2=$(gh issue create \
  --repo "$REPO" \
  --title "Remote E2E-Tests - Phase 4 (Batch 1)" \
  --label "enhancement,testing,priority-high,qs-integration" \
  --milestone "Phase 4 - Remote E2E-Tests" \
  --body '## 🎯 Value Statement

### User Need
**Als** DevOps Engineer  
**möchte ich** automatisierte E2E-Tests auf dem VPS ausführen  
**damit** ich Deployments vom Smartphone verifizieren kann ohne manuelles Testing

### Problem
Aktuell sind nur 3/16 geplante E2E-Tests implementiert. Vollständige Test-Coverage fehlt für:
- Tailscale VPN Connectivity
- Caddy Reverse-Proxy (HTTPS, Auth)
- code-server Zugriff
- Qdrant API & Web-UI

### Business Value
- **Impact:** Hoch
- **Urgency:** Mittel
- **User Benefit:** Vollständige Automatisierung des Deployments, Confidence in Production

## ✅ Acceptance Criteria

- [ ] AC1: Test-Script für Tailscale-Connectivity (Check IP 100.100.221.56)
- [ ] AC2: Test-Script für Caddy-HTTPS (Port 9443, SSL-Cert)
- [ ] AC3: Test-Script für Caddy-Auth (Tailscale-based)
- [ ] AC4: Test-Script für code-server (Login, IDE lädt)
- [ ] AC5: Alle Tests in `scripts/qs/run-e2e-tests.sh` integriert
- [ ] AC6: Tests via GitHub Actions ausführbar

## 📊 Value/Effort Ratio

**Value Score:** 8/10  
**Effort Score:** 4/10  
**Ratio:** 2.0 (High Priority Quick Win)

**Justification:** Hoher Wert für vollständige CI/CD-Pipeline, moderater Aufwand (2h für Batch 1 von 2).

**Estimated:** 2h

## 🔗 References
- [STATUS.md](STATUS.md)
- [E2E Test Script](scripts/qs/run-e2e-tests.sh)' \
  2>&1)
ISSUES_CREATED+=("$ISSUE_2")
echo "✅ Issue #2 erstellt: $ISSUE_2"
echo ""

# Issue #3: Dokumentation & Finalisierung
echo "Erstelle Issue #3: Dokumentation & Finalisierung..."
ISSUE_3=$(gh issue create \
  --repo "$REPO" \
  --title "Dokumentation & Finalisierung - Phase 5" \
  --label "documentation,priority-high,qs-integration" \
  --milestone "Phase 5 - Finalisierung" \
  --body '## 🎯 Value Statement

### User Need
**Als** zukünftiger Maintainer oder Nutzer  
**möchte ich** vollständige, aktuelle Projekt-Dokumentation  
**damit** ich das System verstehen, warten und erweitern kann

### Problem
Phase 5 der QS-Integration ist noch nicht abgeschlossen:
- Projekt-Cleanup durchführen
- Abschluss-Dokumentation schreiben
- Final README-Updates
- Migration auf GitHub Projects dokumentieren

### Business Value
- **Impact:** Hoch
- **Urgency:** Mittel
- **User Benefit:** Wartbarkeit, Onboarding, Wissenstransfer

## ✅ Acceptance Criteria

- [ ] AC1: README.md vollständig aktualisiert (Links zu Projects Board)
- [ ] AC2: CHANGELOG.md mit Phase 4-5 Änderungen
- [ ] AC3: STATUS.md finalisiert (QS-Integration 100%)
- [ ] AC4: Migration-Dokumentation (todo.md → GitHub Projects)
- [ ] AC5: Alle Archive-Links validiert
- [ ] AC6: Quick-Start-Guide getestet

## 📊 Value/Effort Ratio

**Value Score:** 8/10  
**Effort Score:** 5/10  
**Ratio:** 1.6 (High Priority)

**Justification:** Hoher langfristiger Wert für Maintainability, moderater Aufwand (2-3h).

**Estimated:** 2-3h

## 🔗 References
- [STATUS.md](STATUS.md)
- [Documentation Governance](docs/operations/documentation-governance.md)' \
  2>&1)
ISSUES_CREATED+=("$ISSUE_3")
echo "✅ Issue #3 erstellt: $ISSUE_3"
echo ""

# Issue #4: Monitoring-System
echo "Erstelle Issue #4: Monitoring-System..."
ISSUE_4=$(gh issue create \
  --repo "$REPO" \
  --title "Monitoring-System mit Grafana/Prometheus" \
  --label "enhancement,monitoring,priority-medium,epic" \
  --milestone "Post-MVP Features" \
  --body '## 🎯 Value Statement

### User Need
**Als** DevOps Engineer  
**möchte ich** proaktives Monitoring aller System-Komponenten  
**damit** ich Probleme erkennen kann, bevor sie kritisch werden

### Problem
Aktuell keine Monitoring-Lösung implementiert. Probleme werden erst bei manuellem Access oder Alerts bemerkt:
- Keine Metriken für CPU, RAM, Disk
- Keine Service-Health-Checks
- Keine Alert-Notifications
- Keine historischen Daten

### Business Value
- **Impact:** Hoch
- **Urgency:** Mittel
- **User Benefit:** Proaktive Fehlererkennung, Performance-Insights, Uptime-Verbesserung

## ✅ Acceptance Criteria

- [ ] AC1: Prometheus installiert und konfiguriert
- [ ] AC2: Grafana installiert mit DevSystem-Dashboard
- [ ] AC3: Exporters für: node_exporter, cadvisor (falls Docker)
- [ ] AC4: Metriken für: Tailscale, Caddy, code-server, Qdrant
- [ ] AC5: Alerting konfiguriert (Email oder Webhook)
- [ ] AC6: Mobile-Access zu Grafana über Tailscale
- [ ] AC7: Dokumentation: Setup & Dashboard-Nutzung

## 📊 Value/Effort Ratio

**Value Score:** 8/10  
**Effort Score:** 7/10  
**Ratio:** 1.14 (Medium-High Priority)

**Justification:** Hoher Wert für Stabilität und Betrieb, aber signifikanter Aufwand (4-6h).

**Estimated:** 4-6h

## 🔗 References
- [STATUS.md](STATUS.md)' \
  2>&1)
ISSUES_CREATED+=("$ISSUE_4")
echo "✅ Issue #4 erstellt: $ISSUE_4"
echo ""

# Issue #5: Disaster Recovery Plan
echo "Erstelle Issue #5: Disaster Recovery Plan..."
ISSUE_5=$(gh issue create \
  --repo "$REPO" \
  --title "Disaster Recovery Plan & Backup-Strategie" \
  --label "documentation,backup,priority-medium" \
  --milestone "Post-MVP Features" \
  --body '## 🎯 Value Statement

### User Need
**Als** Systemverantwortlicher  
**möchte ich** einen dokumentierten Disaster-Recovery-Plan  
**damit** ich im Notfall (Datenverlust, Hardware-Ausfall) schnell wiederherstellen kann

### Problem
Kein dokumentierter DR-Plan existiert:
- Keine Backup-Strategie für Qdrant-Daten
- Keine Backup-Strategie für code-server-Konfiguration
- Kein Recovery-Zeitplan (RTO/RPO)
- Keine getesteten Restore-Prozeduren

### Business Value
- **Impact:** Hoch (bei Katastrophe)
- **Urgency:** Mittel (solange kein Incident)
- **User Benefit:** Business Continuity, Datensicherheit, Compliance

## ✅ Acceptance Criteria

- [ ] AC1: Backup-Strategie dokumentiert (Was, Wann, Wohin)
- [ ] AC2: Automatische Backups für Qdrant-Datenbank
- [ ] AC3: Backup-Script für kritische Konfigurationen
- [ ] AC4: Restore-Prozedur dokumentiert und getestet
- [ ] AC5: RTO/RPO definiert (z.B. RTO < 4h, RPO < 24h)
- [ ] AC6: DR-Plan in `docs/operations/disaster-recovery.md`

## 📊 Value/Effort Ratio

**Value Score:** 7/10  
**Effort Score:** 5/10  
**Ratio:** 1.4 (Medium-High Priority)

**Justification:** Hoher Wert für Risikomanagement, moderater Aufwand (2-3h).

**Estimated:** 2-3h

## 🔗 References
- [STATUS.md](STATUS.md)
- [Backup Script](scripts/qs/backup-qs-system.sh)' \
  2>&1)
ISSUES_CREATED+=("$ISSUE_5")
echo "✅ Issue #5 erstellt: $ISSUE_5"
echo ""

# Issue #6: code-server Performance
echo "Erstelle Issue #6: code-server Performance..."
ISSUE_6=$(gh issue create \
  --repo "$REPO" \
  --title "code-server Performance-Optimierungen" \
  --label "enhancement,code-server,priority-medium" \
  --milestone "Post-MVP Features" \
  --body '## 🎯 Value Statement

### User Need
**Als** code-server Nutzer  
**möchte ich** eine schnelle, responsive IDE-Erfahrung  
**damit** ich produktiv von jedem Gerät entwickeln kann

### Problem
Bekannte Performance-Issues:
- Extension-Installation kann langsam sein
- Teilweise hohe CPU-Last bei großen Workspaces
- Memory-Leaks bei langem Betrieb (potenziell)
- Kein Tuning für Remote-Use-Case

### Business Value
- **Impact:** Mittel-Hoch
- **Urgency:** Niedrig-Mittel
- **User Benefit:** Bessere UX, schnellere Entwicklung, Stabilität

## ✅ Acceptance Criteria

- [ ] AC1: Performance-Profiling durchgeführt (CPU, RAM, Disk I/O)
- [ ] AC2: code-server Konfiguration optimiert (memory-limits, cache)
- [ ] AC3: Extension-Management verbessert (lazy loading)
- [ ] AC4: Workspace-Settings für große Projekte optimiert
- [ ] AC5: Monitoring-Alerts für hohe Ressourcen-Nutzung
- [ ] AC6: Dokumentation: Performance-Best-Practices

## 📊 Value/Effort Ratio

**Value Score:** 6/10  
**Effort Score:** 5/10  
**Ratio:** 1.2 (Medium Priority)

**Justification:** Guter Wert für User-Experience, moderater Aufwand (2-3h).

**Estimated:** 2-3h

## 🔗 References
- [STATUS.md](STATUS.md)
- [code-server Konzept](docs/concepts/code-server-konzept.md)' \
  2>&1)
ISSUES_CREATED+=("$ISSUE_6")
echo "✅ Issue #6 erstellt: $ISSUE_6"
echo ""

# Issue #7: KI-Integration
echo "Erstelle Issue #7: KI-Integration..."
ISSUE_7=$(gh issue create \
  --repo "$REPO" \
  --title "KI-Integration - Ollama + Enhanced Roo" \
  --label "enhancement,ai,priority-medium,epic" \
  --milestone "Post-MVP Features" \
  --body '## 🎯 Value Statement

### User Need
**Als** Entwickler  
**möchte ich** lokale KI-Unterstützung im DevSystem  
**damit** ich Code-Completion, Chat und Refactoring ohne externe API-Calls nutzen kann

### Problem
Aktuell keine lokale KI-Integration:
- Keine Code-Completion via LLM
- Keine Chat-basierte Assistenz
- Abhängigkeit von externen KI-Services
- Privacy-Concerns bei Cloud-KI

### Business Value
- **Impact:** Hoch (für KI-nutzende Entwickler)
- **Urgency:** Niedrig (Nice-to-have)
- **User Benefit:** Privacy, Offline-Capability, Enhanced Productivity

## ✅ Acceptance Criteria

- [ ] AC1: Ollama auf VPS installiert und konfiguriert
- [ ] AC2: Mindestens 1 Code-Modell deployed (z.B. codellama, deepseek-coder)
- [ ] AC3: Roo Code Extension konfiguriert mit Ollama
- [ ] AC4: code-server Extensions integriert (Continue.dev oder ähnlich)
- [ ] AC5: Performance akzeptabel (Inferenz < 5s für typische Anfragen)
- [ ] AC6: Dokumentation: KI-Setup & Nutzung
- [ ] AC7: Mobile-Workflow getestet

## 📊 Value/Effort Ratio

**Value Score:** 7/10  
**Effort Score:** 7/10  
**Ratio:** 1.0 (Medium Priority)

**Justification:** Hoher Wert für moderne Dev-Workflows, aber signifikanter Aufwand (4-6h).

**Estimated:** 4-6h

## 🔗 References
- [STATUS.md](STATUS.md)
- [KI-Integration Konzept](docs/concepts/ki-integration-konzept.md)' \
  2>&1)
ISSUES_CREATED+=("$ISSUE_7")
echo "✅ Issue #7 erstellt: $ISSUE_7"
echo ""

# Issue #8: Deployment Performance-Profiling
echo "Erstelle Issue #8: Deployment Performance-Profiling..."
ISSUE_8=$(gh issue create \
  --repo "$REPO" \
  --title "Deployment Performance-Profiling" \
  --label "enhancement,performance,priority-medium" \
  --milestone "Post-MVP Features" \
  --body '## 🎯 Value Statement

### User Need
**Als** DevOps Engineer  
**möchte ich** wissen, wo Deployment-Zeit verloren geht  
**damit** ich Optimierungen priorisieren kann

### Problem
Aktuelle Deployment-Zeit unbekannt:
- Keine Metriken für einzelne Setup-Phasen
- Potenzielle Optimierungen nicht identifiziert
- GitHub Actions Runtime könnte optimiert werden

### Business Value
- **Impact:** Mittel
- **Urgency:** Niedrig
- **User Benefit:** Schnellere Deployments, Kostenoptimierung (CI/CD-Minuten)

## ✅ Acceptance Criteria

- [ ] AC1: Benchmark-Script für alle Setup-Phasen
- [ ] AC2: Zeitmessungen dokumentiert (pro Phase)
- [ ] AC3: Top 3 Bottlenecks identifiziert
- [ ] AC4: Optimierungsvorschläge dokumentiert
- [ ] AC5: Quick-Wins implementiert (falls < 30 Min Aufwand)
- [ ] AC6: Report in `docs/reports/deployment-performance-analysis.md`

## 📊 Value/Effort Ratio

**Value Score:** 5/10  
**Effort Score:** 4/10  
**Ratio:** 1.25 (Medium Priority)

**Justification:** Moderater Wert für Effizienz, geringer Aufwand (2h).

**Estimated:** 2h

## 🔗 References
- [STATUS.md](STATUS.md)' \
  2>&1)
ISSUES_CREATED+=("$ISSUE_8")
echo "✅ Issue #8 erstellt: $ISSUE_8"
echo ""

# Issue #9: Remote E2E-Tests Batch 2
echo "Erstelle Issue #9: Remote E2E-Tests Batch 2..."
ISSUE_9=$(gh issue create \
  --repo "$REPO" \
  --title "Remote E2E-Tests - Phase 4 (Batch 2)" \
  --label "enhancement,testing,priority-medium,qs-integration" \
  --milestone "Phase 4 - Remote E2E-Tests" \
  --body '## 🎯 Value Statement

### User Need
**Als** DevOps Engineer  
**möchte ich** vollständige E2E-Test-Coverage für alle Services  
**damit** ich bei Deployments 100% Confidence habe

### Problem
Nach Batch 1 fehlen noch Tests für:
- Qdrant-Service (API + Web-UI)
- Integration-Tests zwischen Services
- Performance/Load-Tests
- Rollback-Szenarien

### Business Value
- **Impact:** Mittel-Hoch
- **Urgency:** Mittel
- **User Benefit:** Vollständige Test-Coverage, Regression-Prevention

## ✅ Acceptance Criteria

- [ ] AC1: Test-Script für Qdrant API (Health, Collection-Create)
- [ ] AC2: Test-Script für Qdrant Web-UI (HTTP 200, Login)
- [ ] AC3: Integration-Test: code-server ↔ Qdrant (API-Call)
- [ ] AC4: Smoke-Test für alle Services parallel
- [ ] AC5: Tests in `scripts/qs/run-e2e-tests.sh` integriert
- [ ] AC6: Alle 16/16 Tests implementiert und dokumentiert

## 📊 Value/Effort Ratio

**Value Score:** 7/10  
**Effort Score:** 4/10  
**Ratio:** 1.75 (Medium-High Priority)

**Justification:** Guter Wert für vollständige Coverage, moderater Aufwand (2h).

**Estimated:** 2h

## 🚫 Out of Scope
- Load-Testing mit hohen Concurrent-Users
- Chaos-Engineering (Service-Kill-Tests)

## 🔗 References
- [E2E Test Script](scripts/qs/run-e2e-tests.sh)' \
  2>&1)
ISSUES_CREATED+=("$ISSUE_9")
echo "✅ Issue #9 erstellt: $ISSUE_9"
echo ""

# Issue #10: GitHub Actions Maintenance
echo "Erstelle Issue #10: GitHub Actions Maintenance..."
ISSUE_10=$(gh issue create \
  --repo "$REPO" \
  --title "GitHub Actions - Scheduled Maintenance-Jobs" \
  --label "enhancement,ci-cd,priority-medium" \
  --milestone "Post-MVP Features" \
  --body '## 🎯 Value Statement

### User Need
**Als** Projektmaintainer  
**möchte ich** automatisierte Wartungsaufgaben  
**damit** das System ohne manuelle Intervention gesund bleibt

### Problem
Keine automatisierten Maintenance-Jobs:
- Kein automatisches Dependency-Update
- Keine automatische Link-Validierung (außer docs)
- Keine Security-Scans
- Keine automatische Backup-Validierung

### Business Value
- **Impact:** Mittel
- **Urgency:** Niedrig
- **User Benefit:** Reduzierte manuelle Arbeit, proaktive Wartung

## ✅ Acceptance Criteria

- [ ] AC1: GitHub Action für wöchentliche Dependency-Updates (Dependabot)
- [ ] AC2: GitHub Action für tägliche Broken-Link-Checks
- [ ] AC3: GitHub Action für Security-Scan (npm audit, shellcheck)
- [ ] AC4: GitHub Action für monatliche Backup-Validierung
- [ ] AC5: Notifications bei Failures (GitHub Issues oder Email)
- [ ] AC6: Dokumentation in `.github/workflows/README.md`

## 📊 Value/Effort Ratio

**Value Score:** 6/10  
**Effort Score:** 5/10  
**Ratio:** 1.2 (Medium Priority)

**Justification:** Guter langfristiger Wert für Wartung, moderater Aufwand (2-3h).

**Estimated:** 2-3h

## 🔗 References
- [Existing Workflows](.github/workflows/)
- [Documentation Validation](.github/workflows/docs-validation.yml)' \
  2>&1)
ISSUES_CREATED+=("$ISSUE_10")
echo "✅ Issue #10 erstellt: $ISSUE_10"
echo ""

# Issue #11: Custom Domain
echo "Erstelle Issue #11: Custom Domain..."
ISSUE_11=$(gh issue create \
  --repo "$REPO" \
  --title "Custom Domain für DevSystem (HTTPS)" \
  --label "enhancement,nice-to-have,dns" \
  --milestone "Future" \
  --body '## 🎯 Value Statement

### User Need
**Als** Nutzer  
**möchte ich** eine merkbare Custom-Domain statt Tailscale-Hostname  
**damit** der Zugriff einfacher und professioneller wirkt

### Problem
Aktuell: `https://devsystem-vps.tailcfea8a.ts.net:9443`
- Langer, komplexer Hostname
- Nicht merkbar
- Nicht "branding-friendly"

### Business Value
- **Impact:** Niedrig (kosmetisch)
- **Urgency:** Niedrig
- **User Benefit:** Besserer First-Impression, einfachere Weitergabe

## ✅ Acceptance Criteria

- [ ] AC1: Domain registriert (z.B. devsystem.dev)
- [ ] AC2: DNS konfiguriert mit Tailscale MagicDNS oder CNAME
- [ ] AC3: Caddy konfiguriert für Custom-Domain
- [ ] AC4: SSL-Zertifikat via Let'\''s Encrypt oder Tailscale-Cert
- [ ] AC5: Redirect von alter URL zur neuen Domain
- [ ] AC6: Dokumentation aktualisiert

## 📊 Value/Effort Ratio

**Value Score:** 3/10  
**Effort Score:** 6/10  
**Ratio:** 0.5 (Low Priority - Icebox)

**Justification:** Niedriger praktischer Wert, moderater bis hoher Aufwand (3-4h + Kosten).

**Estimated:** 3-4h

## 🔗 References
- [Caddy Konzept](docs/concepts/caddy-konzept.md)' \
  2>&1)
ISSUES_CREATED+=("$ISSUE_11")
echo "✅ Issue #11 erstellt: $ISSUE_11"
echo ""

# Issue #12: Multi-User Support
echo "Erstelle Issue #12: Multi-User Support..."
ISSUE_12=$(gh issue create \
  --repo "$REPO" \
  --title "Multi-User Support für code-server" \
  --label "enhancement,epic,nice-to-have" \
  --milestone "Future" \
  --body '## 🎯 Value Statement

### User Need
**Als** Team-Lead  
**möchte ich** mehreren Entwicklern Zugriff geben  
**damit** das DevSystem als Team-IDE genutzt werden kann

### Problem
Aktuell Single-User-Setup:
- Nur ein Login möglich
- Keine User-Isolation
- Keine Permission-Management
- Konflikte bei paralleler Nutzung

### Business Value
- **Impact:** Hoch (bei Multi-User-Nutzung)
- **Urgency:** Niedrig (nicht geplant)
- **User Benefit:** Team-Kollaboration, zentrale Dev-Umgebung

## ✅ Acceptance Criteria

- [ ] AC1: User-Management-System implementiert
- [ ] AC2: Separate Workspaces pro User
- [ ] AC3: Authentication via Tailscale oder OAuth
- [ ] AC4: Permission-System (Read/Write/Admin)
- [ ] AC5: Resource-Limits pro User (CPU, RAM)
- [ ] AC6: Dokumentation: Multi-User-Setup

## 📊 Value/Effort Ratio

**Value Score:** 5/10  
**Effort Score:** 10/10  
**Ratio:** 0.5 (Low Priority - Icebox)

**Justification:** Hoher Aufwand (8-12h), unsicherer Bedarf → Icebox bis Nachfrage existiert.

**Estimated:** 8-12h

## 🚫 Out of Scope
- Real-time-Collaboration (Live Share)
- Video/Audio-Chat-Integration' \
  2>&1)
ISSUES_CREATED+=("$ISSUE_12")
echo "✅ Issue #12 erstellt: $ISSUE_12"
echo ""

# Issue #13: Mobile PWA
echo "Erstelle Issue #13: Mobile PWA..."
ISSUE_13=$(gh issue create \
  --repo "$REPO" \
  --title "Mobile App (PWA) für DevSystem-Management" \
  --label "enhancement,mobile,nice-to-have,epic" \
  --milestone "Future" \
  --body '## 🎯 Value Statement

### User Need
**Als** Mobile-User  
**möchte ich** eine dedizierte Mobile-App für System-Management  
**damit** ich native Features (Notifications, Offline) nutzen kann

### Problem
Aktuell nur Browser-Access:
- Keine Push-Notifications bei Alerts
- Keine Offline-Capability
- Keine native Mobile-UX

### Business Value
- **Impact:** Mittel (für Power-User)
- **Urgency:** Sehr Niedrig
- **User Benefit:** Native Mobile-Experience, Push-Notifications

## ✅ Acceptance Criteria

- [ ] AC1: PWA mit Manifest und Service-Worker
- [ ] AC2: Dashboard für System-Status (CPU, RAM, Services)
- [ ] AC3: Push-Notifications bei Alerts
- [ ] AC4: Quick-Actions (Restart Services, View Logs)
- [ ] AC5: Offline-Mode für Status-View
- [ ] AC6: Installierbar auf iOS/Android
- [ ] AC7: Responsive Design für alle Bildschirmgrößen

## 📊 Value/Effort Ratio

**Value Score:** 4/10  
**Effort Score:** 10/10  
**Ratio:** 0.4 (Low Priority - Icebox)

**Justification:** Sehr hoher Aufwand (12-20h), fraglich ob Mehrwert über Web-UI hinausgeht.

**Estimated:** 12-20h' \
  2>&1)
ISSUES_CREATED+=("$ISSUE_13")
echo "✅ Issue #13 erstellt: $ISSUE_13"
echo ""

# Issue #14: Qdrant Cloud Sync
echo "Erstelle Issue #14: Qdrant Cloud Sync..."
ISSUE_14=$(gh issue create \
  --repo "$REPO" \
  --title "Integration mit Qdrant Cloud (Sync)" \
  --label "enhancement,qdrant,nice-to-have" \
  --milestone "Future" \
  --body '## 🎯 Value Statement

### User Need
**Als** Datenbank-Nutzer  
**möchte ich** meine lokale Qdrant-Instanz mit Qdrant Cloud synchronisieren  
**damit** ich Backups in der Cloud habe und von mehreren Devices zugreifen kann

### Problem
Aktuell nur lokale Qdrant-Instanz:
- Keine Cloud-Backups
- Kein Multi-Device-Sync
- Vendor-locked auf VPS

### Business Value
- **Impact:** Niedrig-Mittel
- **Urgency:** Niedrig
- **User Benefit:** Cloud-Backup, Multi-Device-Access, Vendor-Flexibility

## ✅ Acceptance Criteria

- [ ] AC1: Qdrant Cloud Account Setup
- [ ] AC2: Sync-Script für Collection-Export/Import
- [ ] AC3: Automatische Sync-Jobs (täglich oder on-demand)
- [ ] AC4: Conflict-Resolution-Strategie dokumentiert
- [ ] AC5: Rollback-Mechanismus bei Sync-Fehlern
- [ ] AC6: Dokumentation: Cloud-Sync-Setup

## 📊 Value/Effort Ratio

**Value Score:** 3/10  
**Effort Score:** 6/10  
**Ratio:** 0.5 (Low Priority - Icebox)

**Justification:** Niedriger Wert (lokal funktioniert bereits), moderater Aufwand (4-6h).

**Estimated:** 4-6h' \
  2>&1)
ISSUES_CREATED+=("$ISSUE_14")
echo "✅ Issue #14 erstellt: $ISSUE_14"
echo ""

# Issue #15: Advanced Logging
echo "Erstelle Issue #15: Advanced Logging..."
ISSUE_15=$(gh issue create \
  --repo "$REPO" \
  --title "Advanced Logging & Log-Aggregation" \
  --label "enhancement,logging,nice-to-have" \
  --milestone "Future" \
  --body '## 🎯 Value Statement

### User Need
**Als** DevOps Engineer  
**möchte ich** zentrale Log-Aggregation (z.B. Loki + Grafana)  
**damit** ich Logs durchsuchen und analysieren kann ohne SSH-Access

### Problem
Aktuell dezentrale Logs:
- Logs in verschiedenen Dateien/Services
- Keine zentrale Suche
- SSH-Zugriff nötig für Log-Analyse
- Keine Log-Retention-Policy

### Business Value
- **Impact:** Mittel
- **Urgency:** Niedrig
- **User Benefit:** Einfachere Debugging, historische Log-Analyse

## ✅ Acceptance Criteria

- [ ] AC1: Loki installiert und konfiguriert
- [ ] AC2: Log-Forwarder für alle Services (Promtail)
- [ ] AC3: Grafana-Integration für Log-Viewing
- [ ] AC4: Log-Retention-Policy (z.B. 30 Tage)
- [ ] AC5: Queries für häufige Log-Analysen vorbereitet
- [ ] AC6: Dokumentation: Logging-Setup & Nutzung

## 📊 Value/Effort Ratio

**Value Score:** 4/10  
**Effort Score:** 6/10  
**Ratio:** 0.67 (Low Priority - Icebox)

**Justification:** Moderater Wert für Log-Analyse, moderater Aufwand (3-5h). Nice-to-have.

**Estimated:** 3-5h' \
  2>&1)
ISSUES_CREATED+=("$ISSUE_15")
echo "✅ Issue #15 erstellt: $ISSUE_15"
echo ""

# Summary ausgeben
echo "=================================="
echo "✅ Alle 15 Issues erstellt!"
echo "=================================="
echo ""
echo "Erstellte Issues:"
for i in "${!ISSUES_CREATED[@]}"; do
  echo "  Issue #$((i+1)): ${ISSUES_CREATED[$i]}"
done
echo ""
echo "Nächste Schritte:"
echo "1. Gehe zu: https://github.com/$REPO/issues"
echo "2. Verifiziere alle Issues"
echo "3. Erstelle Project Board manuell unter: https://github.com/$REPO/projects"
echo "   - Name: 'DevSystem Features'"
echo "   - Layout: Board"
echo "4. Füge Issues dem Board hinzu"
echo ""
