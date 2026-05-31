# Code-Server Auth auf QS-VPS deaktiviert (Tailscale-only)

## Kontext

Auf dem QS-VPS wird code-server hinter Caddy betrieben und ist ausschließlich über Tailscale erreichbar. Das direkte Binding bleibt lokal (`127.0.0.1:8080`). Der Login-Screen stammt von code-server selbst.

## Änderung

In der code-server Konfiguration wurde Auth deaktiviert, damit kein Passwort mehr abgefragt wird:

- `auth: none`
- `bind-addr: 127.0.0.1:8080` (unverändert, localhost-only)

## Sicherheits-Hinweis

Diese Einstellung ist nur zulässig, weil der Zugriff ausschließlich über Tailscale erfolgt und der Dienst nicht öffentlich bindet. **Keinen** externen Bind (`0.0.0.0`) verwenden und keine Caddy-Änderung vornehmen, die den Dienst ohne Tailscale erreichbar macht.
