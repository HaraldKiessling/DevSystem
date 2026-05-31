# Produktions-VPS Scripts

Dieses Verzeichnis enthält Scripts für den Produktions-VPS (`devsystem-vps`).

---

## Verfügbare Scripts

### [`diagnose-and-fix-devsystem-vps.sh`](diagnose-and-fix-devsystem-vps.sh)

**Zweck:** Vollständige Diagnose und Reparatur des devsystem-vps

**Verwendung:**

```bash
# Interaktiv (mit Reparatur-Option)
bash scripts/prod/diagnose-and-fix-devsystem-vps.sh

# Automatische Reparatur (non-interactive)
bash scripts/prod/diagnose-and-fix-devsystem-vps.sh <<< "j"
```

**Features:**
- ✅ System-Status (Uptime, Load, Memory)
- ✅ OOM-Killer Detection
- ✅ Tailscale-Diagnose
- ✅ Caddy-Status
- ✅ Code-Server-Status
- ✅ Docker & Ollama-Status
- ✅ Netzwerk-Konnektivität
- ✅ Automatische Service-Reparatur

**Wann verwenden:**
- VPS über Tailscale nicht erreichbar
- Services laufen nicht
- Nach Server-Neustart
- Bei OOM-Problemen
- Regelmäßige Health-Checks

---

### [`install-ollama-prod.sh`](install-ollama-prod.sh)

**Zweck:** Ollama Installation auf dem Produktions-VPS

**Siehe:** [OLLAMA-PROD-DEPLOYMENT-2026-05-24.md](../../docs/operations/OLLAMA-PROD-DEPLOYMENT-2026-05-24.md)

---

### [`index-codebase.py`](index-codebase.py)

**Zweck:** Codebase-Indexierung für Qdrant/RAG

---

## Zugriff auf devsystem-vps

### Normal (über Tailscale)

```bash
ssh root@devsystem-vps.tailcfea8a.ts.net
```

### Notfall (über IONOS Console)

1. Login: https://my.ionos.de/ oder https://cloud.ionos.de/
2. "Server & Cloud" → "Cloud Server" auswählen
3. Server "devsystem-vps" auswählen
4. "Remote Console" öffnen (VNC/KVM-Zugriff)

---

## Troubleshooting

**VPS offline?**  
→ Siehe: [DEVSYSTEM-VPS-OFFLINE-2026-05-31.md](../../docs/troubleshooting/DEVSYSTEM-VPS-OFFLINE-2026-05-31.md)

**OOM-Probleme?**  
→ Siehe: [OLLAMA-PROD-DEPLOYMENT-2026-05-24.md](../../docs/operations/OLLAMA-PROD-DEPLOYMENT-2026-05-24.md)

---

## System-Informationen

**VPS:** devsystem-vps  
**Tailscale IP:** 100.100.221.56  
**Hostname:** devsystem-vps.tailcfea8a.ts.net  
**URL:** https://devsystem-vps.tailcfea8a.ts.net:9443

**Services:**
- Tailscale (Port: 41641)
- Caddy (Port: 9443)
- Code-Server (Port: 8080, via Caddy)
- Ollama (Port: 11434, Docker)
- Qdrant (Port: 6333, Docker)

**Ressourcen:**
- RAM: 8 GB (7.7 GB nutzbar)
- Swap: 3 GB
- Disk: ~80 GB

---

**Erstellt:** 2026-05-31  
**Letztes Update:** 2026-05-31
