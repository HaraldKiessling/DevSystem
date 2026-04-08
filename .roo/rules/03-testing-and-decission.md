# Testing & Entscheidungsfindung

## Entscheidungs-Zwang bei offenen Fragen
- **Nicht raten:** Bei Unklarheiten, Architektur-Entscheidungen oder fehlenden Parametern darfst du NIEMALS raten oder einfach etwas annehmen.
- **Dokumentationspflicht:** Trage jede offene Frage sofort in die `todo.md` unter "Offene Entscheidungen" ein.
- **Striktes Format:** Du MUSST die Frage exakt so in die Liste eintragen:
  - **Frage:** [Die genaue Problemstellung]
  - **Alternativen:** [Mindestens 2 machbare technische Optionen]
  - **Empfehlung:** [Deine klare Empfehlung als DevOps-Experte mit Begründung]
- **Entscheidungsfindung:** Ich werde die Entscheidung per Chat treffen oder direkt in der `todo.md` anpassen. Warte nur dann meine Freigabe wenn du nicht sicher bist, bevor du fortfährst.
## E2E-Testkonzept
- Alle Tests werden live gegen den Ubuntu VPS ausgeführt (via SSH/Curl/Skripte).
- **Log-Validierung:** Ein Test gilt nur dann als bestanden, wenn die entsprechenden System-Logs (z.B. `journalctl`, Caddy-Logs, Docker-Logs) die korrekte Funktion bestätigen.
- Roo muss die Logs aktiv auslesen und interpretieren.
