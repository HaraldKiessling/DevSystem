# VPS SSH Fix Guide

**Problem:** SSH-Zugang zum QS-VPS über `devsystem-qs-vps.tailcfea8a.ts.net` war nicht möglich.

**Status:** ✅ **GELÖST** - SSH funktioniert vollständig über Tailscale

---

## Diagnose-Ergebnisse

### Ausgeführte Diagnose

```bash
bash scripts/qs/diagnose-ssh-vps.sh --host=devsystem-qs-vps.tailcfea8a.ts.net
```

### Diagnose-Report (2026-04-10 11:12:50 UTC)

| Component | Status | Details |
|-----------|--------|---------|
| **Tailscale** | ✅ Funktionsfähig | Ping erfolgreich (12.8ms RTT) |
| **Port 22** | ✅ Offen | SSH-Port erreichbar |
| **SSH-Verbindung** | ✅ Erfolgreich | Remote-Command-Execution funktioniert |
| **Tailscale SSH** | ⚠️ Nicht aktiviert | Optional, standard SSH funktioniert |

---

## Lösung

### Der korrekte VPS-Host

❌ **Falsch:** `100.100.221.56` (devsystem-vps - **Produktions-VPS**)  
✅ **Richtig:** `devsystem-qs-vps.tailcfea8a.ts.net` (100.82.171.88 - **QS-VPS**)

### SSH-Zugang konfigurieren

Der SSH-Zugang funktioniert mit dem korrekten Hostnamen automatisch:

```bash
# SSH-Test
ssh -i ~/.ssh/id_ed25519 root@devsystem-qs-vps.tailcfea8a.ts.net "echo 'SSH OK'"

# Repository synchronisieren
rsync -avz --exclude='.git' -e "ssh -i ~/.ssh/id_ed25519" \
  /root/work/DevSystem/ \
  root@devsystem-qs-vps.tailcfea8a.ts.net:/root/work/DevSystem/
```

---

## Verwendete SSH-Keys

- **Private Key:** `/root/.ssh/id_ed25519`
- **Public Key:** `/root/.ssh/id_ed25519.pub`
- **Typ:** Ed25519 (modern, sicher, schnell)

Der Public Key ist bereits auf dem QS-VPS in `~/.ssh/authorized_keys` eingetragen.

---

## Tailscale-Netzwerk-Topologie

```
Tailscale-Netzwerk (tailcfea8a.ts.net)
│
├── 100.100.221.56 (devsystem-vps)         # Produktions-VPS
│   └── Services: Caddy, code-server, Qdrant
│
├── 100.82.171.88 (devsystem-qs-vps)       # Quality Server (QS-VPS)
│   └── Services: Caddy, Qdrant, (code-server geplant)
│
├── 100.101.234.39 (desktop-3fdt7rr)       # Windows Desktop
├── 100.78.144.54 (ha1)                    # Home Assistant 1
├── 100.120.55.60 (ha3)                    # Home Assistant 3
└── 100.95.118.18 (oneplus-12)             # Android Phone
```

---

## E2E-Tests ausführen

Nach erfolgreicher SSH-Konfiguration können die E2E-Tests ausgeführt werden:

```bash
# Phase 1: Idempotenz-Framework E2E-Tests
bash scripts/qs/run-e2e-tests.sh \
  --host=devsystem-qs-vps.tailcfea8a.ts.net \
  --user=root \
  --ssh-key=/root/.ssh/id_ed25519

# Phase 2: Master-Orchestrator Tests
bash scripts/qs/test-master-orchestrator.sh \
  --host=devsystem-qs-vps.tailcfea8a.ts.net \
  --user=root \
  --mode=remote
```

---

## Troubleshooting

### Problem: "Connection refused"

**Ursache:** Falscher Hostname verwendet  
**Lösung:** Verwende `devsystem-qs-vps.tailcfea8a.ts.net` statt IP

### Problem: "Permission denied (publickey)"

**Ursache:** SSH-Key nicht korrekt  
**Lösung:**
```bash
# Key-Berechtigunen prüfen
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub

# Public Key auf VPS kopieren (falls nötig)
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@devsystem-qs-vps.tailcfea8a.ts.net
```

### Problem: "No such device or address"

**Ursache:** Tailscale nicht verbunden  
**Lösung:**
```bash
# Tailscale-Status prüfen
tailscale status

# Falls nicht verbunden
tailscale up
```

---

## Sicherheitshinweise

### Nur über Tailscale erreichbar

Der QS-VPS ist **ausschließlich über Tailscale VPN** erreichbar:
- ✅ Kein offener SSH-Port im Internet
- ✅ Zero-Trust-Netzwerk
- ✅ End-to-End verschlüsselt
- ✅ Nur autorisierte Geräte

### SSH-Key-Verwaltung

- Ed25519-Keys sind modern und sicher
- Private Keys **niemals** committen oder teilen
- Public Keys können frei verteilt werden
- Keys regelmäßig rotieren (alle 1-2 Jahre)

---

## Alternative: Tailscale SSH (Optional)

Tailscale bietet ein natives SSH-Feature, das zusätzliche Sicherheit bietet:

### Aktivierung auf dem VPS

```bash
# Auf dem VPS
tailscale set --ssh
```

### Verwendung

```bash
# Via Tailscale SSH
tailscale ssh root@devsystem-qs-vps

# Oder mit --ssh Flag
ssh root@devsystem-qs-vps.tailcfea8a.ts.net
```

### Vorteile

- **Keine SSH-Keys nötig** - Tailscale kümmert sich um die Authentifizierung
- **ACL-basierte Zugriffskontrolle** - Feingranulare Berechtigungen
- **Audit-Logs** - Alle SSH-Sessions werden geloggt
- **MFA-Integration** - Multi-Faktor-Authentifizierung möglich

---

## Zusammenfassung

✅ **SSH-Zugang funktioniert vollständig**  
✅ **Korrekter Host: `devsystem-qs-vps.tailcfea8a.ts.net`**  
✅ **Ed25519-Key-Authentifizierung aktiv**  
✅ **Tailscale-VPN schützt die Verbindung**  
✅ **E2E-Tests können durchgeführt werden**

---

**Erstellt:** 2026-04-10 11:20 UTC  
**Status:** SSH vollständig funktionsfähig  
**Nächste Schritte:** E2E-Tests und Deployment-Validierung
