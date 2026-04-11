# DevSystem Dokumentation

Willkommen zur DevSystem-Dokumentation. Dieses Verzeichnis enthält die gesamte technische und strategische Dokumentation des Projekts.

## 📚 Dokumentations-Index

### 🏗️ Architektur

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System-Architektur und Komponenten-Übersicht

### 📋 Projektmanagement

Siehe [`project/`](project/) für Projekt-Planung und -Management:

- **[VISION.md](project/VISION.md)** - Projekt-Vision, fachliche Anforderungen und Tech-Stack
- **[PROJECT-RULES.md](project/PROJECT-RULES.md)** - Projekt-Regeln, Workflows und Anforderungen
- **[todo.md](project/todo.md)** - Zentrale Aufgabenliste (wird zu GitHub Issues migriert)

### 🔧 Support & Troubleshooting

- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Häufige Probleme und Lösungen

### 💡 Konzepte
Technische Konzepte für Systemkomponenten:
- [`code-server-konzept.md`](concepts/code-server-konzept.md) - code-server Integration
- [`testkonzept.md`](concepts/testkonzept.md) - Test-Strategie und Idempotenz
- [`caddy-konzept.md`](concepts/caddy-konzept.md) - Caddy Reverse Proxy
- [`tailscale-konzept.md`](concepts/tailscale-konzept.md) - Tailscale VPN
- [`qs-vps-konzept.md`](concepts/qs-vps-konzept.md) - QS-VPS-System
- [`sicherheitskonzept.md`](concepts/sicherheitskonzept.md) - Sicherheitsarchitektur
- [`ki-integration-konzept.md`](concepts/ki-integration-konzept.md) - KI-Integration (Ollama)
- [`implementierungsplan.md`](concepts/implementierungsplan.md) - Implementierungs-Roadmap

### 🚀 Deployment
Praktische Deployment-Anleitungen:
- [`deployment-prozess.md`](deployment/deployment-prozess.md) - Gesamt-Deployment-Workflow
- [`vps-deployment-caddy.md`](deployment/vps-deployment-caddy.md) - Caddy-Deployment auf VPS
- [`vps-deployment-qdrant-complete.md`](deployment/vps-deployment-qdrant-complete.md) - Qdrant-Deployment
- [`vps-ssh-fix-guide.md`](deployment/vps-ssh-fix-guide.md) - SSH-Troubleshooting

### ⚙️ Operations
Betrieb, Wartung und Workflows:
- [`git-workflow.md`](operations/git-workflow.md) - Git-Best-Practices
- [`branch-strategie.md`](operations/branch-strategie.md) - Branch-Management
- [`qs-github-integration-strategie.md`](operations/qs-github-integration-strategie.md) - QS-GitHub-Automation

### 📊 Strategien
Strategische Planung und Lessons Learned:
- [`qs-implementierungsplan-final.md`](strategies/qs-implementierungsplan-final.md) - QS-System Implementierung
- [`qs-strategy-summary.md`](strategies/qs-strategy-summary.md) - QS-Strategie Executive Summary
- [`roo-rules-improvements.md`](strategies/roo-rules-improvements.md) - Lessons Learned

### 📈 Reports
Aktive Status-Reports und Optimierungen:
- [`optimization/`](reports/optimization/) - QS-System-Optimierungen
- Weitere aktuelle Reports im Hauptverzeichnis

### 🗄️ Archiv
- [`archive/`](archive/) - Historische Dokumentation (siehe [Archive-README](archive/README.md))

## 🎯 Einstiegspunkte

### Für neue Entwickler
1. [`README.md`](../README.md) - Projekt-Übersicht
2. [`ARCHITECTURE.md`](ARCHITECTURE.md) - System-Architektur (Phase 4)
3. [`CONTRIBUTING.md`](../CONTRIBUTING.md) - Contribution-Guidelines (Phase 4)
4. [`concepts/`](concepts/) - Technische Konzepte durchlesen

### Für Operations/DevOps
1. [`deployment/`](deployment/) - Deployment-Guides
2. [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) - Problem-Lösungen (Phase 4)
3. [`operations/`](operations/) - Git-Workflow und Branch-Strategie
4. [`../scripts/`](../scripts/) - Deployment-Scripts

### Für Management/Product Owner
1. [`VISION.md`](project/VISION.md) - Fachliche Anforderungen und Projekt-Vision
2. [`PROJECT-RULES.md`](project/PROJECT-RULES.md) - System-Anforderungen und Projektregeln
3. [`strategies/`](strategies/) - Strategische Planung
4. [`reports/`](reports/) - Status-Reports

## 📝 Dokumentations-Konventionen

### Namensgebung
- **Technische Dokumente**: lowercase-kebab-case (z.B. `git-workflow.md`)
- **Root-Level Kern-Docs**: UPPERCASE (z.B. `ARCHITECTURE.md`)
- **Fachliche Anforderungen**: CamelCase (z.B. `DevSystem.md`)

### Versionen
- Alte Versionen werden nach `docs/archive/concepts/` verschoben
- Aktive Dokumente sind immer die neueste Version
- Archivierte Versionen: `[name]-v[nummer].md` (z.B. `testkonzept-v1.md`)

### Updates
Dokumentations-Updates werden in [`DOCUMENTATION-CHANGELOG.md`](DOCUMENTATION-CHANGELOG.md) erfasst.

## 🔗 Weitere Ressourcen

- [`CHANGELOG.md`](../CHANGELOG.md) - Projekt-Changelog (Phase 4)
- [`todo.md`](project/todo.md) - Aktive Tasks
- [`DOCUMENTATION-CHANGELOG.md`](DOCUMENTATION-CHANGELOG.md) - Dokumentations-Historie

## 📅 Letzte Aktualisierung

**2026-04-11** - Dokumentations-Konsolidierung v1.0
