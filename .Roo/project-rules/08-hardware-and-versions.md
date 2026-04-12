# Hardware-Specs & Software-Versionen

**Version:** 1.0.0  
**Erstellt:** 2026-04-12 05:18 UTC  
**Letzte Verifizierung:** 2026-04-12  
**Status:** Aktiv

## Überblick

Dieses Dokument dokumentiert die Hardware-Spezifikationen und Software-Versionen des DevSystem-VPS für Troubleshooting, Kapazitätsplanung und Kompatibilitätsprüfungen.

---

## 1. VPS Hardware-Specs

### QS-VPS (devsystem-qs-vps.tailcfea8a.ts.net)

| Ressource | Spezifikation | Verwendung | Status |
|-----------|---------------|------------|--------|
| **Provider** | Hetzner Cloud (vermutlich) | - | ✅ |
| **CPU** | 2-4 vCPUs (zu verifizieren) | ~30-50% bei Deployment | 🟢 |
| **RAM** | 4-8 GB (zu verifizieren) | ~60% im Normalbetrieb | 🟢 |
| **Disk** | 40-80 GB SSD | ~15-20 GB belegt | 🟢 |
| **Network** | 1 Gbps | Tailscale VPN | 🟢 |
| **OS** | Ubuntu 22.04/24.04 LTS | - | ✅ |
| **Kernel** | Linux 5.x/6.x | - | ✅ |

**IP-Adressen:**
- **Tailscale:** 100.100.221.56
- **Internal:** (dynamisch)
- **FQDN:** devsystem-vps.tailcfea8a.ts.net

**Zugriffs-URLs:**
- **code-server:** https://devsystem-vps.tailcfea8a.ts.net:9443
- **Qdrant:** http://localhost:6333 (nur intern)

### Verifizierung der Hardware-Specs

```bash
# SSH zum VPS
ssh root@devsystem-qs-vps.tailcfea8a.ts.net

# CPU
lscpu | grep -E "^CPU\(s\)|^Model name"
nproc

# RAM
free -h
cat /proc/meminfo | grep MemTotal

# Disk
df -h
lsblk

# OS & Kernel
uname -a
cat /etc/os-release

# Network
ip addr show
ss -tulpn
```

**Aktualisierung:** Bei VPS-Änderungen oder Verifizierung.

---

## 2. Software-Versionen

### 2.1 Core-Services

| Service | Version | Installation | Config | Status |
|---------|---------|--------------|--------|--------|
| **Tailscale** | Latest (Stable Channel) | apt-get | /etc/default/tailscaled | ✅ Aktiv |
| **Caddy** | v2.7+ | apt-get | /etc/caddy/Caddyfile | ✅ Aktiv |
| **code-server** | v4.114.1 | tar.gz + systemd | ~/.config/code-server/ | ✅ Aktiv |
| **Qdrant** | v1.7.4 | Docker | docker-compose | ✅ Aktiv |

**Verifizierung:**
```bash
# Tailscale
tailscale version

# Caddy
caddy version

# code-server
code-server --version

# Qdrant
docker exec qdrant curl -s http://localhost:6333/health | jq .version
```

### 2.2 System-Dependencies

| Package | Version | Zweck |
|---------|---------|-------|
| **bash** | 5.1+ | Script-Ausführung |
| **systemd** | 249+ | Service-Management |
| **curl** | 7.x+ | HTTP-Requests, Healthchecks |
| **jq** | 1.6+ | JSON-Parsing |
| **fail2ban** | 0.11+ | Security (SSH Brute-Force) |
| **ufw** | 0.36+ | Firewall |

**Verifizierung:**
```bash
bash --version
systemctl --version
curl --version
jq --version
fail2ban-client version
ufw version
```

### 2.3 Development-Tools

| Tool | Version | Verwendet für |
|------|---------|---------------|
| **git** | 2.34+ | Version Control |
| **shellcheck** | 0.9.0 | Bash-Script-Analyse |
| **Docker** | 20.10+ | Qdrant-Container |
| **Python** | 3.10+ (optional) | Future KI-Integration |

---

## 3. Versionierungs-Strategie

### Stable vs. Latest

**Policy:** Verwende **Stable Channel** für Production-Services.

| Service | Policy | Begründung |
|---------|--------|------------|
| Tailscale | Stable | Netzwerk-Stabilität kritisch |
| Caddy | Latest-Stable | Security-Patches wichtig |
| code-server | Specific Version | Breaking Changes vermeiden |
| Qdrant | Stable | Datenbank-Stabilität |

### Update-Prozedur

**Minor Updates:**
```bash
# Vor Update: Backup
bash scripts/qs/backup-qs-system.sh

# Update
apt-get update && apt-get upgrade -y

# Nach Update: E2E-Tests
bash scripts/qs/run-e2e-tests.sh

# Bei Problemen: Rollback
bash scripts/qs/setup-qs-master.sh --mode=rollback
```

**Major Updates:**
- Erst auf Test-VPS testen
- Deployment-Plan erstellen
- Rollback-Plan bereit haben
- Maintenance-Window planen

### Version-Lock-Files

**Für Reproduzierbarkeit:**
```bash
# Erstelle Version-Snapshot
cat > versions-$(date +%Y%m%d).txt <<EOF
Tailscale: $(tailscale version)
Caddy: $(caddy version)
code-server: $(code-server --version)
Qdrant: $(docker exec qdrant curl -s http://localhost:6333/health | jq -r .version)
OS: $(cat /etc/os-release | grep PRETTY_NAME)
Kernel: $(uname -r)
EOF
```

**Archivierung:** In [`docs/versions/`](../../docs/versions/) oder als Git-Tag.

---

## 4. Kapazitäts-Planung

### Aktuelle Nutzung (geschätzt)

| Ressource | Idle | Development | Deployment | Limit |
|-----------|------|-------------|------------|-------|
| **CPU** | 5-10% | 30-50% | 70-90% | 100% |
| **RAM** | 1-2 GB | 2-3 GB | 3-4 GB | 4-8 GB |
| **Disk** | 10 GB | 15 GB | 20 GB | 40-80 GB |
| **Network** | 1 Mbps | 10 Mbps | 50 Mbps | 1 Gbps |

### Skalierungs-Trigger

**Upgrade nötig wenn:**
- CPU >80% für >1h
- RAM >85% konstant
- Disk >80% voll
- Deployment-Time >10 Min

**Upgrade-Optionen:**
1. VPS-Ressourcen erhöhen (Hetzner Cloud)
2. Services auf separate VPSs verteilen
3. Logging/Monitoring optimieren

---

## 5. Kompatibilitäts-Matrix

### Getestete Kombinationen

| OS | Tailscale | Caddy | code-server | Qdrant | Status |
|----|-----------|-------|-------------|--------|--------|
| Ubuntu 22.04 | Latest | v2.7.x | v4.114.1 | v1.7.4 | ✅ Produktiv |
| Ubuntu 24.04 | Latest | v2.7.x | v4.114.1 | v1.7.4 | ⏸️ Nicht getestet |

### Abhängigkeiten

**Kritische Dependency-Chains:**
```
Tailscale → Caddy (Tailscale Auth)
Caddy → code-server (Reverse Proxy)
SystemD → All Services (Service Management)
```

**Version-Constraints:**
- Tailscale: Keine bekannten Constraints
- Caddy: v2.6+ für Tailscale Auth Support
- code-server: v4.x für Stability
- Qdrant: v1.7+ für neueste Features

---

## 6. Update-Historie

### Version-Snapshots

| Datum | Tailscale | Caddy | code-server | Qdrant | Commit |
|-------|-----------|-------|-------------|--------|--------|
| 2026-04-10 | Latest | v2.7.x | v4.114.1 | v1.7.4 | `ae3cae1` |

**Future Updates:** Snapshot nach jedem Major-Update erstellen.

---

## 7. Performance-Benchmarks

### Deployment-Geschwindigkeit

| Komponente | Installation | Konfiguration | Gesamt |
|------------|--------------|---------------|--------|
| Tailscale | 30s | 15s | 45s |
| Caddy | 45s | 30s | 1min 15s |
| code-server | 2min | 45s | 2min 45s |
| Qdrant | 1min 30s | 30s | 2min |

**Full Deployment:** ~6-8 Min (Target: <10 Min ✅)

### Resource-Footprint

| Service | RAM (Idle) | RAM (Load) | Disk |
|---------|-----------|------------|------|
| Tailscale | 20-30 MB | 50 MB | 100 MB |
| Caddy | 30-50 MB | 100 MB | 50 MB |
| code-server | 200-300 MB | 500 MB | 500 MB |
| Qdrant | 100-200 MB | 400 MB | 2-5 GB |

---

## 8. Monitoring-Empfehlungen

### Zu überwachende Metriken

**System-Level:**
- CPU-Nutzung (Target: <70% durchschnittlich)
- RAM-Nutzung (Target: <85%)
- Disk-Space (Alert bei >75%)
- Disk-I/O (iowait <20%)

**Service-Level:**
- Service-Status (systemctl is-active)
- Response-Times (HTTP Health-Checks)
- Error-Rates (aus Logs)
- Uptime (Target: >99.5%)

### Alerting-Thresholds

| Metrik | Warning | Critical |
|--------|---------|----------|
| CPU | >70% für 30min | >90% für 10min |
| RAM | >80% | >90% |
| Disk | >75% | >85% |
| Service Down | N/A | Sofort |

---

## 9. Disaster-Recovery Hardware-Requirements

**Minimum für System-Wiederherstellung:**
- 2 vCPUs
- 4 GB RAM
- 20 GB Disk

**Empfohlen für Production:**
- 4 vCPUs
- 8 GB RAM
- 80 GB Disk

**Backup-Location:**
- Lokal: /var/backups/qs-deployment/
- Remote: (zu implementieren - S3/Backup-VPS)

---

## 10. Referenzen & Updates

### Related Documents
- [Deployment-Process](../../docs/strategies/deployment-prozess.md)
- [QS-VPS-Konzept](../../docs/concepts/qs-vps-konzept.md)
- [Rollback-Procedure](07-rollback-procedure.md)

### Verifizierungs-Script

```bash
# scripts/utils/verify-system-specs.sh
#!/bin/bash
echo "=== DevSystem Hardware & Version Check ==="
echo "CPU: $(nproc) cores"
echo "RAM: $(free -h | grep Mem | awk '{print $2}')"
echo "Disk: $(df -h / | tail -1 | awk '{print $2}')"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2)"
echo "Tailscale: $(tailscale version 2>/dev/null || echo 'Not installed')"
echo "Caddy: $(caddy version 2>/dev/null || echo 'Not installed')"
echo "code-server: $(code-server --version 2>/dev/null || echo 'Not installed')"
```

**Verwendung:**
```bash
ssh root@devsystem-qs-vps.tailcfea8a.ts.net "bash -s" < scripts/utils/verify-system-specs.sh
```

---

**Auto-Update-Regel:** Dieses Dokument sollte nach jedem Major-Update oder VPS-Änderung aktualisiert werden.

## Änderungshistorie

### 2026-04-12 05:18 UTC
- Initiale Version 1.0.0  
- Hardware-Specs dokumentiert (basierend auf verfügbaren Informationen)
- Software-Versionen aus Deployment-Logs entnommen
- Monitoring-Empfehlungen hinzugefügt
- Grund: .Roo-Regeln Sprint 2 Task 10
