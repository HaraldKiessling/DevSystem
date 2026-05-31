# OpenRouter API-Key – Manuelle Konfiguration erforderlich

## Hintergrund

Der Zoo-Extension-Hybrid-Modus ("🔀 Hybrid (Ollama + OpenRouter)") benötigt einen OpenRouter-API-Key, um Cloud-Modelle wie Claude Sonnet nutzen zu können. Dieser API-Key wird **nicht** in Klartext-Dateien gespeichert, sondern im sicheren Secret-Store der VS-Code-Extension (`vscode.SecretStorage`). Eine dateibasierte Replikation ist daher **nicht möglich**.

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

## Wichtige Hinweise

- Der API-Key ist **privat** und sollte niemals in Chat-Nachrichten, Logs oder Konfigurationsdateien geteilt werden.
- Ohne diesen Key funktioniert der Hybrid-Modus **nur mit lokalen Ollama-Modellen** – Cloud-Modelle stehen dann nicht zur Verfügung.
- Der Modus "🦙 Ollama Local" funktioniert **ohne** OpenRouter-Key (rein lokal über Ollama).

## Verifikation

Nach erfolgreicher Key-Eingabe sollte im Hybrid-Modus eine Antwort von Claude Sonnet (via OpenRouter) erscheinen. Prüfe in den OpenRouter-Dashboard-Logs, ob der Request verarbeitet wurde.

---

**Erstellt:** 2026-05-30 – Zoo-Konfiguration-Replikation  
**Status:** Manueller Schritt ausstehend  
**Zielserver:** devsystem-qs-vps
