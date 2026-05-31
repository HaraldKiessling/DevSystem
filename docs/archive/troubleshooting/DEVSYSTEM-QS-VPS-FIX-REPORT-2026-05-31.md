# DEVSYSTEM-QS-VPS Fix-Report (2026-05-31)

## Ursache

- **Qdrant-Verifikation**: Qdrant ist bereits als systemd-Service `qdrant-qs` aktiv und lauscht lokal; der Health-Endpoint `GET /health` liefert auf dieser Version **HTTP 404** (Root-Endpoint antwortet korrekt). Dadurch wirkt der Health-Check fälschlich als „nicht vorhanden“.
- **Caddy 421 (Misdirected Request)**: TLS/SNI-Mismatch bei Zugriff über die Tailscale-IP. Der IP-Host-Header passt nicht zu einem gültigen Zertifikat/SNI der bisherigen Site-Konfiguration, was zu 421 bzw. TLS-Handshake-Fehlern führte.

## Änderungen

- **Caddy Site für IP-Zugriff** umgestellt auf `tls internal` (damit wird bei Zugriff auf die IP ein passendes Zertifikat für die IP verwendet).
- **Caddy Servers-Block**: `strict_sni_host` auf `insecure_off` gesetzt, damit SNI-Mismatch nicht zum 421 führt.
- **Reload**: Caddy wurde neu geladen/neu gestartet, da Reload über Admin-API nicht verfügbar ist.

## Tests (via SSH)

- `curl -s -o /dev/null -w "%{http_code}" http://localhost:6333/health` → `404` (Qdrant läuft, Health-Endpoint nicht verfügbar)
- `curl -sk -o /dev/null -w "%{http_code}" https://100.82.171.88:9443/` → `302`
- `curl -sk -o /dev/null -w "%{http_code}" https://devsystem-qs-vps.tailcfea8a.ts.net:9443/` → `302`

## Hinweis

- Keine Repo-Skripte geändert.
- Änderungen wurden **nur** auf dem Zielserver vorgenommen (Caddy-Konfiguration).

## Repo-Notiz (lokale Skriptänderungen bereinigt)

- **Status**: Änderungen in `scripts/qs/*` übernommen und committed.
- **Änderungstyp**: Idempotenz-Fix für Farbcodes (Guard gegen erneute `readonly`-Definition bei mehrfacher Nutzung/Sourcing).
- **Betroffene Dateien**: `configure-caddy-qs.sh`, `deploy-qdrant-qs.sh`, `install-caddy-qs.sh`, `install-code-server-qs.sh`.
