System- und Projektanforderungen
1. Infrastruktur & Zielsystem
Host: Ubuntu VPS bei IONOS.
Netzwerkzugang: Initialer Root-Zugriff per SSH erfolgt ausschließlich über Tailscale.
Kernkomponenten:
Tailscale: Für VPN und Netzwerksicherheit.
Caddy: Als Reverse Proxy (SSL/HTTPS).
code-server: Als Web-IDE für die Steuerung per Handy und Multi-Agent-Nutzung.
2. Projektmanagement & To-Do-Liste
Zentrale Steuerung: Alle Aufgaben, Ausbaustufen und Abhängigkeiten werden in einer zentralen To-Do-Liste (z. B. todo.md) gepflegt.
Rekursive Aufteilung: Zu große Aufgaben müssen zwingend aufgeteilt werden. Sind die Teilaufgaben noch immer zu groß, werden sie weiter unterteilt, bis sie granular abarbeitbar sind.
Status-Tracking: Jede Aufgabe durchläuft strikt folgende Phasen, die in der Liste sichtbar sein müssen: plan -> Konzeption -> Entwicklung -> qs -> e2e -> fertig.
Offene Fragen (Entscheidungsmatrix): Unklare Punkte werden in der To-Do-Liste mit Alternativen und einer klaren Empfehlung dokumentiert. Der Benutzer trifft die Entscheidung per Chat oder durch direkte Anpassung der Datei.
3. Entwicklungs- und Test-Workflow
Iterativer Ansatz: Fokus liegt auf der schnellstmöglichen Erreichung eines MVP (Minimum Viable Product).
Live E2E-Tests: Es gibt ein Testkonzept mit E2E-Tests, die live gegen den Ubuntu VPS ausgeführt werden.
Log-Validierung: Alle Tests müssen explizit auf korrekte Log-Ausgaben der jeweiligen Dienste prüfen.
Git-Regeln:
Konzept-Ergebnisse werden direkt in den main-Branch committet.
Feature-Entwicklungen finden zwingend auf separaten Feature-Branches statt.
Ein Merge in den main-Branch erfolgt ausschließlich nach einem nachweislich erfolgreichen E2E-Test.
4. Globale Systemregel für die KI
Roo Code muss diese Regeln als Systemanweisungen verinnerlichen und darf sie während des gesamten Projektverlaufs nicht vergessen.

