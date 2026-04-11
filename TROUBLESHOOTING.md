# DevSystem - Troubleshooting Guide

**Version:** 1.0 (Draft)  
**Status:** 🚧 Work in Progress  
**Letzte Aktualisierung:** 2026-04-11

---

## 🛠️ Häufige Probleme (FAQ)

### SSH-Verbindung fehlgeschlagen

**Problem**: Kann keine SSH-Verbindung zum VPS herstellen

**Lösungen**:
1. TODO: Detaillierte Schritte hinzufügen
2. Siehe [`docs/operations/VPS-SSH-FIX-GUIDE.md`](docs/operations/VPS-SSH-FIX-GUIDE.md) für umfassende Anleitung

### Tailscale nicht erreichbar

**Problem**: VPS ist nicht im Tailscale-Netzwerk sichtbar

**TODO**: Diagnose-Schritte dokumentieren

### Caddy nicht erreichbar (Port 9443)

**Problem**: HTTPS-Zugriff über Port 9443 funktioniert nicht

**TODO**: Port-Check und Firewall-Diagnose

### code-server Login-Probleme

**Problem**: Kann mich nicht bei code-server anmelden

**TODO**: Authentifizierungs-Troubleshooting

### Qdrant nicht verfügbar

**Problem**: Qdrant API antwortet nicht

**TODO**: Service-Diagnose

---

## 🔧 Service-Management

### Service-Status prüfen

```bash
# TODO: Vollständige Befehle hinzufügen
systemctl status caddy
systemctl status code-server
systemctl status tailscaled
systemctl status qdrant
```

### Logs inspizieren

```bash
# TODO: Log-Analyse-Befehle
journalctl -u caddy -n 50
journalctl -u code-server --since "1 hour ago"
```

### Service neu starten

```bash
# TODO: Restart-Prozeduren
sudo systemctl restart caddy
```

### Port-Checks

```bash
# TODO: Netzwerk-Diagnose
ss -tulpn | grep 9443
netstat -tulpn | grep LISTEN
```

---

## 🔄 Rollback-Prozeduren

### Automatischer Rollback mit Master-Orchestrator

```bash
# TODO: Rollback-Dokumentation
bash scripts/qs/setup-qs-master.sh --rollback
```

### Manuelle Rollback-Schritte

TODO: Schritt-für-Schritt-Anleitung

### State-Marker-System zurücksetzen

TODO: State-Management-Dokumentation

---

## 💾 Disaster Recovery

### Backup-Restore

```bash
# TODO: Backup-Restore-Prozedur
bash scripts/qs/backup-qs-system.sh
```

### VPS-Neuaufbau

TODO: Kompletter Rebuild-Guide

### Datenbank-Recovery (Qdrant)

TODO: Qdrant-Backup und -Restore

---

## 🔍 Debugging-Tools

### Diagnose-Scripts

- `scripts/qs/diagnose-qdrant-qs.sh`
- `scripts/qs/diagnose-ssh-vps.sh`
- TODO: Weitere Diagnose-Tools dokumentieren

### Log-Analyse

TODO: Log-Analyse-Best-Practices

### Network-Debugging

TODO: Netzwerk-Troubleshooting-Tools

---

## 📚 Weitere Ressourcen

### Archivierte Troubleshooting-Reports

- [`docs/archive/troubleshooting/`](docs/archive/troubleshooting/) - Gelöste Probleme
  - CADDY-SCRIPT-DEBUG-REPORT.md
  - EXTENSION-LOOP-FIX-REPORT.md
  - vps-korrekturen-ergebnisse.md

### Deployment-Guides

- [`docs/deployment/`](docs/deployment/) - Deployment-Anleitungen mit Troubleshooting-Tipps

### Operations-Dokumentation

- [`docs/operations/VPS-SSH-FIX-GUIDE.md`](docs/operations/VPS-SSH-FIX-GUIDE.md) - SSH-Troubleshooting

---

## 🆘 Support

### Community-Support

TODO: Support-Kanäle dokumentieren

### Bug-Reports

TODO: Issue-Tracking-Prozess

---

**Status**: Dieser Stub wird iterativ erweitert mit konkreten Problem-Lösungen. Priorität: HOCH

**Konsolidiert aus**:
- VPS-SSH-FIX-GUIDE.md
- CADDY-SCRIPT-DEBUG-REPORT.md (Learnings)
- EXTENSION-LOOP-FIX-REPORT.md (Learnings)
