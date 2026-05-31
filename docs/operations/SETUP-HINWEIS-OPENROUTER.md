# OpenRouter API-Key – Manuelle Konfiguration erforderlich

## Hintergrund

Der Zoo-Extension-Hybrid-Modus ("🔀 Hybrid (Ollama + OpenRouter)") benötigt einen OpenRouter-API-Key, um Cloud-Modelle wie Claude Sonnet nutzen zu können. Dieser API-Key wird **nicht** in Klartext-Dateien gespeichert, sondern im sicheren Secret-Store der VS-Code-Extension (`vscode.SecretStorage`). Eine dateibasierte Replikation ist daher **nicht möglich**.

## Ziel

- Cloud-Modelle via OpenRouter im Hybrid-Modus aktivieren.
- API-Key ausschließlich über den Secret-Store hinterlegen.
- Funktion per Testanfrage und Logs verifizieren.

## Voraussetzungen (QS-VPS)

- Zugriff auf code-server über Tailscale.
- Zoo-Extension installiert und aktiviert.
- OpenRouter-Account mit gültigem API-Key (niemals in Dateien/Chat posten).

## Schritt-für-Schritt-Anleitung

1. **code-server im Browser öffnen**: `https://devsystem-qs-vps.tailcfea8a.ts.net:9443`
2. **Zoo-Extension öffnen**: Klicke auf das Zoo/Roo-Code-Icon in der Activity Bar (linke Seitenleiste).
3. **Modus "🔀 Hybrid (Ollama + OpenRouter)" auswählen**: Oben im Chat-Panel das Mode-Dropdown öffnen und den Hybrid-Modus wählen.
4. **API-Provider-Einstellungen öffnen**: In den Zoo-Extension-Settings den OpenRouter-Provider auswählen.
5. **API-Key eingeben**:
   - Besorge den OpenRouter-API-Key von [https://openrouter.ai/keys](https://openrouter.ai/keys)
   - Trage ihn in das dafür vorgesehene Feld ein
   - Der Key wird automatisch im Secret-Store gesichert
6. **Test**: Sende eine einfache Anfrage im Hybrid-Modus, um die Verbindung zu verifizieren.

## UI-Navigation im Detail (code-server)

1. **Activity Bar** → Zoo/Roo-Icon auswählen.
2. **Chat-Panel** → oben rechts das Mode-Dropdown öffnen.
3. **Mode** → "🔀 Hybrid (Ollama + OpenRouter)" wählen.
4. **Settings/Provider** → OpenRouter als Provider aktivieren.
5. **Secret Store** → Feld für API-Key ausfüllen.
6. **Speichern/Bestätigen** → Secret wird in `vscode.SecretStorage` abgelegt.

## Wo der Secret-Store sitzt (Konzept)

- `vscode.SecretStorage` ist ein geschützter Speicher, der nicht als Datei in diesem Repo erscheint.
- Secrets sind **nicht** per `git` sichtbar und sollen **nicht** exportiert werden.
- Eine Replikation über Konfig-Dateien ist deshalb nicht möglich.

## Validierungs-Checkliste

- [ ] Hybrid-Modus ausgewählt.
- [ ] OpenRouter als Provider gesetzt.
- [ ] API-Key eingegeben (keine Klartext-Datei!).
- [ ] Test-Request im Chat abgesetzt.
- [ ] OpenRouter Dashboard zeigt Request.

## Verifikation

Nach erfolgreicher Key-Eingabe sollte im Hybrid-Modus eine Antwort von Claude Sonnet (via OpenRouter) erscheinen. Prüfe in den OpenRouter-Dashboard-Logs, ob der Request verarbeitet wurde.

## Test-Request (Hybrid Mode)

- Beispiel: „Bitte antworte mit dem Wort OK.“
- Erwartung: Antwort von Cloud-Modell (z. B. Claude Sonnet) erscheint ohne Fehler.
- Bei Fehlern siehe Troubleshooting unten.

## Typische Fehlerbilder

- **401/403**: Key fehlt, abgelaufen oder falscher Provider.
- **Timeout**: Netzwerk/Provider nicht erreichbar oder Proxy-Problem.
- **Fallback auf Ollama**: Hybrid aktiv, aber Cloud nicht autorisiert.

## Troubleshooting

### Fehler: „No API key configured“

- Prüfe, ob der Key wirklich im OpenRouter-Provider gesetzt ist.
- Wechsel kurz zu einem anderen Provider und zurück.

### Fehler: „Unauthorized / Forbidden“

- Key rotieren (OpenRouter Dashboard).
- Provider im UI erneut auswählen.

### Fehler: „Network error“

- Prüfe Tailscale-Konnektivität.
- Prüfe, ob Caddy/Proxy den Traffic blockiert.

### Fehler: „Model not available“

- Modell-Auswahl im Provider prüfen.
- Bei Hybrid: Cloud-Modell explizit auswählen.

## Wichtige Hinweise

- Der API-Key ist **privat** und sollte niemals in Chat-Nachrichten, Logs oder Konfigurationsdateien geteilt werden.
- Ohne diesen Key funktioniert der Hybrid-Modus **nur mit lokalen Ollama-Modellen** – Cloud-Modelle stehen dann nicht zur Verfügung.
- Der Modus "🦙 Ollama Local" funktioniert **ohne** OpenRouter-Key (rein lokal über Ollama).

## Betrieb & Pflege

- Key-Rotation regelmäßig prüfen.
- Bei Problemen: zuerst Provider-Einstellungen kontrollieren, dann Netzwerk prüfen.
- Keine Secrets in Screenshots oder Logs.

## Diagnose-Schnellcheck

- Hybrid-Mode ausgewählt?
- OpenRouter Provider aktiv?
- Key in Secret Store gesetzt?
- Tailscale erreichbar?
- OpenRouter Dashboard zeigt Requests?

---

**Erstellt:** 2026-05-30 – Zoo-Konfiguration-Replikation  
**Status:** Manueller Schritt ausstehend  
**Zielserver:** devsystem-qs-vps
