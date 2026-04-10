# Deployment & Operations

## Deployment-Prozess

### Pre-Deployment-Checks
Vor jedem Deployment MÜSSEN folgende Checks durchgeführt werden:
1. **Git-Status:** Alle Änderungen committed und gepusht
2. **Branch-Status:** Feature-Branch ist in `main` gemerged
3. **Backup:** VPS-Snapshot erstellt (optional, empfohlen)
4. **Test-Status:** Alle relevanten Tests bestanden
5. **Dokumentation:** Deployment dokumentiert in `todo.md`

### Deployment-Execution
- **Master-Orchestrator verwenden:** `bash scripts/qs/setup-qs-master.sh`
- **Logging aktivieren:** Alle Deployment-Logs nach `/var/log/qs-deployment/` schreiben
- **Idempotenz prüfen:** Zweiter Durchlauf darf < 10 Sekunden dauern

### Post-Deployment-Checks (PFLICHT)
Nach JEDEM Deployment MÜSSEN folgende Checks durchgeführt werden:

1. **Service-Status validieren:**
   ```bash
   systemctl status tailscale
   systemctl status caddy
   systemctl status code-server
   systemctl status qdrant
   ```
   Alle Services müssen "active (running)" sein.

2. **Port-Verfügbarkeit prüfen:**
   ```bash
   ss -tulpn | grep -E ':(443|9443|8080|6333)'
   ```
   Alle erforderlichen Ports müssen LISTEN sein.

3. **HTTPS-Zugriff testen:**
   ```bash
   curl -I https://$(tailscale ip -4):9443
   ```
   Muss HTTP 200 oder 302 zurückgeben.

4. **Log-Validation (keine Fehler):**
   ```bash
   journalctl -u caddy --since "5 minutes ago" | grep -i error
   journalctl -u code-server --since "5 minutes ago" | grep -i error
   ```
   Darf KEINE kritischen Fehler enthalten.

5. **Idempotenz-Check:**
   ```bash
   time bash scripts/qs/setup-qs-master.sh
   ```
   Zweiter Durchlauf MUSS < 10 Sekunden dauern und "Already configured" melden.

**Dokumentation:** Alle Check-Ergebnisse MÜSSEN in `vps-test-results-*.md` dokumentiert werden.

## Rollback-Prozedur
Bei fehlgeschlagenen Deployments:

1. **Sofort-Maßnahme:** Master-Orchestrator Rollback ausführen
   ```bash
   bash scripts/qs/setup-qs-master.sh --rollback
   ```
2. **Logs sichern:** Fehler-Logs nach `/var/log/qs-deployment/failures/` kopieren
3. **Root-Cause-Analysis:** Fehlerursache dokumentieren in `ROLLBACK-REPORT-*.md`
4. **Service-Validation:** Services manuell prüfen (systemctl status)
5. **Fix entwickeln:** In separatem Branch mit zusätzlichen Tests
6. **Re-Deploy:** Nur nach erfolgreichem lokalem Testing
