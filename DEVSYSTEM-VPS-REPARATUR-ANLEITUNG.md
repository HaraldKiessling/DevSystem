# 🔴 devsystem-vps REPARATUR - Schnellanleitung

**Status:** VPS über Tailscale offline  
**Datum:** 2026-05-31

---

## ⚡ Schnellzugriff

### 1. IONOS Console öffnen

**Login:** https://my.ionos.de/ oder https://cloud.ionos.de/

**Navigation:**
1. "Server & Cloud" → "Cloud Server"
2. Server "devsystem-vps" auswählen
3. **"Remote Console"** öffnen (VNC/KVM-Zugriff)

### 2. Im Console-Fenster einloggen

```bash
# Login als root (Passwort eingeben)
```

### 3. Reparatur-Skript ausführen

```bash
cd /root/work/DevSystem
bash scripts/prod/diagnose-and-fix-devsystem-vps.sh
```

**Das Skript fragt:** "Möchten Sie eine automatische Reparatur durchführen? (j/n)"  
→ **Eingeben: `j`** (für Ja)

---

## 🎯 Was das Skript macht

✅ **Diagnose:**
- System-Status (RAM, CPU, Uptime)
- OOM-Killer Events prüfen
- Tailscale-Status
- Caddy-Status
- Code-Server-Status
- Ollama/Docker-Status
- Netzwerk-Konnektivität

✅ **Automatische Reparatur:**
- Startet Tailscale neu
- Startet Caddy neu
- Startet Code-Server neu
- Startet Ollama Container neu

---

## 🔍 Manuelle Verifikation (nach Reparatur)

**Auf deinem lokalen PC:**

```powershell
# 1. Tailscale-Status prüfen
tailscale status

# Erwartung: devsystem-vps sollte "active" sein (nicht mehr "offline")

# 2. SSH-Test
ssh root@devsystem-vps.tailcfea8a.ts.net "echo 'SSH OK'"

# 3. Web-Interface testen
# Browser öffnen: https://devsystem-vps.tailcfea8a.ts.net:9443
```

---

## 🚨 Alternative: Server-Neustart

Falls das Skript nicht hilft:

**Im IONOS Cloud Panel:**
1. Server "devsystem-vps" auswählen
2. "Aktionen" → **"Neustart"** klicken
3. 2-3 Minuten warten
4. Tailscale-Status prüfen: `tailscale status`

---

## 📋 Häufige Ursachen

| Problem | Lösung |
|---------|--------|
| **OOM-Killer** | Ollama Container verbraucht zu viel RAM → Skript startet mit Memory-Limits neu |
| **Tailscale crashed** | Skript startet tailscaled Service neu |
| **Services gestoppt** | Skript startet alle Services neu |
| **Server offline** | Neustart über IONOS Panel |

---

## 📚 Detaillierte Dokumentation

- **Vollständiger Troubleshooting-Guide:** [`docs/troubleshooting/DEVSYSTEM-VPS-OFFLINE-2026-05-31.md`](docs/troubleshooting/DEVSYSTEM-VPS-OFFLINE-2026-05-31.md)
- **Reparatur-Skript:** [`scripts/prod/diagnose-and-fix-devsystem-vps.sh`](scripts/prod/diagnose-and-fix-devsystem-vps.sh)
- **OOM-Problem-Historie:** [`docs/operations/OLLAMA-PROD-DEPLOYMENT-2026-05-24.md`](docs/operations/OLLAMA-PROD-DEPLOYMENT-2026-05-24.md)

---

## ✅ Erfolgs-Kriterien

Nach erfolgreicher Reparatur sollte gelten:

- ✅ `tailscale status` zeigt devsystem-vps als "active"
- ✅ SSH funktioniert: `ssh root@devsystem-vps.tailcfea8a.ts.net`
- ✅ Web-Interface erreichbar: https://devsystem-vps.tailcfea8a.ts.net:9443
- ✅ Alle Services laufen: tailscaled, caddy, code-server, ollama

---

**Erstellt:** 2026-05-31  
**Nächster Schritt:** IONOS Console öffnen und Reparatur-Skript ausführen
