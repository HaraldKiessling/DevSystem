# DevSystem

[![Status](https://img.shields.io/badge/Status-MVP-yellow)](https://github.com)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Ubuntu%20VPS-orange)](https://www.ionos.de)

> **Cloud-basierte Entwicklungsumgebung mit KI-Unterstützung und Zero-Trust-Zugriff**

DevSystem ist eine vollständig remote nutzbare, KI-gestützte Entwicklungsumgebung, die als Web-Anwendung im Browser läuft. Das System ermöglicht mobilen, geräteunabhängigen Zugriff auf eine komplette VS Code-Umgebung mit autonomen Multi-Agent-KI-Assistenten.

---

## 🌟 Kernmerkmale

- **🌐 Mobiler Zugriff**: Vollständige Entwicklungsumgebung im Browser (PWA-fähig), nutzbar von Smartphone, Tablet oder Desktop
- **🤖 KI-Integration**: Autonome Multi-Agent-KI-Unterstützung über Roo Code mit Cloud- und lokalen Modellen
- **🔐 Zero-Trust-Sicherheit**: Zugriff ausschließlich über privates VPN (Tailscale), kein öffentliches Internet-Exposure
- **🚀 Idempotente Deployments**: Master-Orchestrator-Scripts für reproduzierbare, fehlertolerante Installationen
- **📦 Vector Database**: Integrierte Qdrant-Instanz für KI-Embeddings und Semantic Search

---

## 🚀 Quick Start

### Voraussetzungen

- Ubuntu VPS (20.04 LTS oder neuer) bei IONOS oder anderem Provider
- Tailscale-Account (kostenlos)
- Root- oder sudo-Zugriff auf den VPS

### Installation (QS-VPS)

```bash
# 1. Tailscale auf lokalem Rechner installieren (falls nicht vorhanden)
# Siehe: https://tailscale.com/download

# 2. Repository klonen
git clone https://github.com/[YOUR-USERNAME]/DevSystem.git
cd DevSystem

# 3. QS-VPS Setup ausführen (idempotent)
cd scripts/qs
./setup-qs-master.sh

# 4. Browser-Zugriff über Tailscale
# Nach Installation öffne: https://[TAILSCALE-IP]:9443
# (Tailscale-IP findest du mit: tailscale ip -4)
```

### Zugriff auf code-server

Nach erfolgreicher Installation ist die Web-IDE erreichbar über:

```
https://[TAILSCALE-VPS-IP]:9443
```

Die Tailscale-IP deines VPS findest du mit:
```bash
tailscale ip -4
```

**Standard-Login**: Das Passwort wird während der Installation automatisch generiert und in `~/.config/code-server/config.yaml` gespeichert.

---

## 🏗️ Systemkomponenten

DevSystem besteht aus folgenden Kernkomponenten:

| Komponente | Zweck | Port | Status |
|------------|-------|------|--------|
| **[code-server](https://github.com/coder/code-server)** | Browserbasierte VS Code-Umgebung | 8080 (intern) | ✅ Produktiv |
| **[Caddy](https://caddyserver.com/)** | Reverse Proxy mit automatischem HTTPS | 9443 | ✅ Produktiv |
| **[Tailscale](https://tailscale.com/)** | Zero-Trust VPN-Netzwerk | - | ✅ Produktiv |
| **[Qdrant](https://qdrant.tech/)** | Vector Database für KI-Anwendungen | 6333/6334 | ✅ Produktiv |
| **[Ollama](https://ollama.ai/)** | Lokale KI-Model-Inferenz | 11434 | 🚧 Geplant |

### Weitere Komponenten

- **Roo Code**: VS Code Extension für autonome KI-Agenten (installiert in code-server)
- **OpenRouter**: API-Gateway für Cloud-KI-Modelle (externe Integration)

---

## 📚 Dokumentation

### Übersichtsdokumente

- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - System-Architektur und Komponenten-Übersicht
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Contribution-Guidelines und Entwicklungs-Workflow
- **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Häufige Probleme und Lösungen
- **[CHANGELOG.md](CHANGELOG.md)** - Versions-Historie und Änderungen

### Detaillierte Dokumentation

```
docs/
├── concepts/           # Konzepte und Designs der Kernkomponenten
├── deployment/         # Deployment-Anleitungen und Cloud-Init-Scripts
├── operations/         # Betriebs-Dokumentation (Git-Workflow, SSH-Fixes)
├── strategies/         # Strategische Dokumente (Branch-Strategie, QS-Prozess)
└── reports/            # Status-Reports und Optimierungs-Analysen
```

**Empfohlene Lesereihenfolge:**
1. [docs/concepts/qs-vps-konzept.md](docs/concepts/qs-vps-konzept.md) - QS-System-Übersicht
2. [docs/deployment/vps-deployment-qdrant-complete.md](docs/deployment/vps-deployment-qdrant-complete.md) - Qdrant-Deployment
3. [docs/operations/git-workflow.md](docs/operations/git-workflow.md) - Git-Workflow
4. [docs/strategies/deployment-prozess.md](docs/strategies/deployment-prozess.md) - Deployment-Prozess

Vollständige Übersicht: [docs/README.md](docs/README.md)

---

## 🔧 Technology Stack

- **Backend**: Bash Scripts, Node.js (code-server)
- **Frontend**: VS Code Web (via code-server)
- **Infrastructure**: Ubuntu Linux, systemd
- **Networking**: Tailscale (WireGuard-basiert), Caddy (Go)
- **AI/ML**: Qdrant (Rust), Ollama (geplant)
- **Orchestration**: Custom Bash-basierte Idempotenz-Library

---

## 🗺️ Roadmap

### ✅ Phase 1: Core Infrastructure (Abgeschlossen)
- [x] Tailscale VPN-Integration
- [x] Caddy Reverse Proxy mit HTTPS
- [x] code-server Browser-IDE
- [x] Idempotente Deployment-Scripts

### ✅ Phase 2: AI Infrastructure (Abgeschlossen)
- [x] Qdrant Vector Database Deployment
- [x] QS-VPS Test-Environment
- [x] E2E-Test-Framework

### 🚧 Phase 3: AI Integration (In Arbeit)
- [ ] Ollama Integration für lokale Modelle
- [ ] Roo Code MCP-Server
- [ ] Semantic Code Search via Qdrant

### 📋 Phase 4: Monitoring & Operations (Geplant)
- [ ] Prometheus/Grafana Monitoring
- [ ] Automated Backup-System
- [ ] Multi-VPS Orchestration

---

## 🤝 Contributing

Wir freuen uns über Contributions! Bitte lies zunächst [CONTRIBUTING.md](CONTRIBUTING.md) für:

- Entwicklungs-Workflow und Branch-Strategie
- Code-Style-Guidelines
- Test-Anforderungen
- PR-Submission-Prozess

**Wichtige Regeln:**
- Feature-Branches für alle Entwicklungen
- Merge in `main` nur nach erfolgreichem E2E-Test
- Konzept-Dokumente dürfen direkt in `main` committed werden

---

## 📄 License

Dieses Projekt ist lizenziert unter der MIT License - siehe [LICENSE](LICENSE) für Details.

---

## 🙏 Acknowledgments

- [Coder Team](https://github.com/coder/code-server) für code-server
- [Caddy Team](https://caddyserver.com/) für den modernsten Webserver
- [Tailscale](https://tailscale.com/) für das beste Zero-Trust-Netzwerk
- [Qdrant Team](https://qdrant.tech/) für die Vector Database
- Alle Contributors und Tester

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/[YOUR-USERNAME]/DevSystem/issues)
- **Dokumentation**: [docs/](docs/)
- **Troubleshooting**: [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

---

**Status**: MVP - Core-Funktionalität ist produktionsreif, AI-Integration in Arbeit
