# Code-Server Auth auf QS-VPS deaktiviert (Tailscale-only)

## Kontext

Auf dem QS-VPS wird code-server hinter Caddy betrieben und ist ausschließlich über Tailscale erreichbar. Das direkte Binding bleibt lokal (`127.0.0.1:8080`). Der Login-Screen stammt von code-server selbst.

## Zielbild (Security-by-Design)

- **Kein öffentlicher Zugriff**: nur via Tailscale erreichbar.
- **Localhost-Bind**: code-server lauscht nur auf `127.0.0.1:8080`.
- **Reverse-Proxy**: Caddy terminates TLS und proxyiert lokal.
- **Zusätzliche Kontrollschicht**: Tailscale ACLs/Tags begrenzen Zugriff.

## Änderung

In der code-server Konfiguration wurde Auth deaktiviert, damit kein Passwort mehr abgefragt wird:

- `auth: none`
- `bind-addr: 127.0.0.1:8080` (unverändert, localhost-only)

## Sicherheitsmodell (erforderliche Maßnahmen)

1. **Tailscale-only**
   - Zugriff ausschließlich über Tailnet.
   - Keine öffentliche DNS/Ingress-Expose.
2. **Localhost-Bind**
   - code-server ist nicht direkt aus dem Netzwerk erreichbar.
3. **Caddy als Gatekeeper**
   - TLS-Termination + Reverse-Proxy nur auf Tailscale-Interface.
4. **Audit & Threat Model**
   - Bedrohung: kompromittierte Tailnet-Identity.
   - Gegenmaßnahme: ACLs, Tags, Device-Posture, Log-Review.

## Risiko-Hinweis

`auth: none` ist nur dann vertretbar, wenn **alle** folgenden Bedingungen erfüllt sind:

- [ ] Tailscale enforced (keine Public IP/Ingress).
- [ ] code-server bindet ausschließlich auf `127.0.0.1`.
- [ ] Caddy ist nur via Tailscale erreichbar.
- [ ] Tailnet-ACLs begrenzen Zugriffe auf bekannte Devices/Users.

## Sicherheits-Hinweis

Diese Einstellung ist nur zulässig, weil der Zugriff ausschließlich über Tailscale erfolgt und der Dienst nicht öffentlich bindet. **Keinen** externen Bind (`0.0.0.0`) verwenden und keine Caddy-Änderung vornehmen, die den Dienst ohne Tailscale erreichbar macht.

## Rollback-Anleitung (zurück zu `auth: password`)

1. `code-server`-Config öffnen (z. B. `~/.config/code-server/config.yaml`).
2. Werte setzen:
   - `auth: password`
   - `password: <starkes-passwort>` (nie im Repo speichern)
3. Service neu starten:
   - `sudo systemctl restart code-server`
4. Zugriff testen (Login-Screen sichtbar).

## Betrieb & Monitoring

- **Access-Logs** in Caddy prüfen (verdächtige Quellen).
- **Tailscale Admin Console**: Device-Liste und ACLs regelmäßig prüfen.
- **Change-Log**: Änderungen an auth/bind dokumentieren.

## Troubleshooting

### Problem: code-server ist öffentlich erreichbar

- Prüfe Caddy-Listener (sollte nur Tailscale-Interface binden).
- Prüfe Firewall/UFW-Regeln.
- Prüfe DNS/Ingress-Konfiguration.

### Problem: Login-Screen erscheint trotz `auth: none`

- Config-Datei verifizieren (aktive Instanz prüfen).
- `systemctl status code-server` auf die richtige Unit prüfen.
- Cache/alte Konfiguration ausschließen.

### Problem: Zugriff ohne Tailscale möglich

- Prüfe, ob ein zusätzlicher Reverse-Proxy existiert.
- Prüfe öffentliche Ports mit `ss -tulpen`.

## Audit/Threat-Model Checkliste

- [ ] Tailnet-Identities geprüft (keine unbekannten Geräte).
- [ ] ACLs für QS-VPS restriktiv (Least Privilege).
- [ ] Caddy TLS & Host-Policy geprüft.
- [ ] Keine Secrets in Doku/Logs.

## Notfall-Plan (wenn Zugriff kompromittiert)

1. **Tailscale-Access entziehen** (Device deaktivieren, ACLs anpassen).
2. **Caddy/Firewall prüfen** (Public Exposure ausschließen).
3. **Rollback zu `auth: password`** (siehe oben).
4. **Passwort rotieren** (starkes Passwort, nicht im Repo speichern).
5. **Logs sichern** (Caddy + code-server + Tailscale Audit).

## Change-Management Hinweise

- Änderungen an `auth` oder `bind-addr` immer dokumentieren.
- Vor Deploy: kurze Risikoabschätzung (Threat Model) durchführen.
- Nach Deploy: Zugriffstest nur über Tailscale durchführen.
