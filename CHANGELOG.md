# Changelog

Alle wichtigen Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/),
und dieses Projekt folgt [Semantic Versioning](https://semver.org/lang/de/).

---

## [Unreleased]

### In Planung
- Ollama-Integration für lokale KI-Models
- Monitoring & Observability
- Multi-Region Deployment

---

## [1.1.0] - 2026-04-11

### Added
- README.md mit vollständiger Projekt-Übersicht
- LICENSE (MIT) für rechtliche Klarheit
- Generalisiertes PR-Template in .github/
- VISION.md (umbenannt von DevSystem.md für Klarheit)
- PROJECT-RULES.md (umbenannt von SystemProject.md für Klarheit)

### Changed
- Archiviert temporäre/historische Dateien (InitPrompt, PR-Instructions, QS-Reset-Report)
- DOCUMENTATION-CHANGELOG.md nach docs/ verschoben
- Root-Verzeichnis von 13 auf 9 Dokumente reduziert (-31%)
- Verbesserte GitHub-Konformität (Best-Practice-Score: 86% → 90%+)
- PULL_REQUEST_TEMPLATE.md von Root nach .github/ verschoben (GitHub Best Practice)

### Removed
- Temporäre Workaround-Dokumentation aus Root
- Spezifisches PR-Template aus Root (ersetzt durch generalisiertes)
- Historische Setup-Dateien aus Root (ins Archiv verschoben)

### Documentation
- Post-Konsolidierungs-Cleanup abgeschlossen
- Root-Verzeichnis optimiert für bessere Übersichtlichkeit
- Alle temporären Dateien systematisch archiviert
- Referenzen zu umbenannten Dateien aktualisiert

---

## [1.0.0] - 2026-04-11

### Added - Neue Features
- **MVP Deployment**: Produktiv-VPS und QS-VPS erfolgreich deployed
- **code-server**: Browserbasierte VS Code-Umgebung mit Tailscale-Zugang
- **Caddy Reverse Proxy**: Automatisches HTTPS auf Port 9443
- **Tailscale VPN**: Zero-Trust Netzwerk für sichere Verbindungen
- **Qdrant Vector Database**: Integration für KI-Workloads
- **Master-Orchestrator**: Idempotentes Deployment-Framework für QS-VPS
- **E2E-Testing**: Umfassende Test-Suite mit Idempotenz-Checks

### Changed - Änderungen
- Umstellung auf idempotentes Deployment-Framework
- Konsolidierung der Dokumentation (46 → ~25 aktive Dokumente)
- Strukturierte Archivierung historischer Dokumente

### Deprecated - Veraltet
- Alte manuelle Deployment-Scripts (vor Idempotenz-Framework)
- Fragmentierte Dokumentations-Struktur

### Removed - Entfernt
- Legacy Setup-Scripts ohne State-Management
- Duplikate in Dokumentation (6 Dateien konsolidiert)

### Fixed - Behobene Fehler
- SSH-Verbindungsprobleme auf QS-VPS
- Caddy Port 9443 Konfigurationsprobleme
- code-server Extension-Loop bei Updates
- Git Branch-Cleanup (87.5% Branches bereinigt)

### Security - Sicherheit
- Tailscale-Authentifizierung für Caddy aktiviert
- TLS-Ende-zu-Ende-Verschlüsselung via Tailscale
- Firewall-Konfiguration gehärtet

---

## [0.2.0] - 2026-04-10

### Added
- QS-VPS Setup und Testing
- Phase 1 & 2 Deployment erfolgreich
- E2E-Validation-Reports
- Refactoring und Code-Review

---

## [0.1.0] - 2026-04-09

### Added
- Initiale Projekt-Struktur
- Basis-Konzepte dokumentiert
- Deployment-Scripts (erste Versionen)

---

## Upgrade-Guides

### Von 0.x zu 1.0.0

**Wichtige Änderungen:**
- Neue idempotente Deployment-Scripts verwenden
- State-Marker-System beachten
- Dokumentations-Referenzen aktualisieren (neue Struktur)

**Schritte:**
1. TODO: Detaillierte Migration-Steps
2. Backup erstellen: `bash scripts/qs/backup-qs-system.sh`
3. Neue Scripts verwenden: `bash scripts/qs/setup-qs-master.sh`

---

## Links

- [Dokumentation](docs/)
- [Deployment-Guides](docs/deployment/)
- [ARCHITECTURE.md](ARCHITECTURE.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)

---

**Hinweis**: Detaillierte Dokumentations-Änderungen siehe [DOCUMENTATION-CHANGELOG.md](docs/DOCUMENTATION-CHANGELOG.md)
