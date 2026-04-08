# DevSystem - Zentrale Aufgabenliste

## Projektzweck

Aufbau eines reproduzierbaren, cloudbasierten Entwicklungssystems auf einem IONOS Ubuntu VPS mit Tailscale (VPN), Caddy (Reverse Proxy) und code-server (Web-IDE). Das System muss vollständig per Handy-Browser (PWA) über code-server steuerbar sein.

## Aktive Aufgaben (MVP)

### Caddy-Implementierung

- [Branch Open] Feature-Branch für Caddy erstellt (feature/caddy-setup)
- [Branch Open] Caddy-Installationsskript entwickelt (install-caddy.sh)
- [Todo] Caddy-Konfigurationsskript entwickeln
- [Todo] E2E-Tests für Caddy entwickeln
- [Todo] Caddy-Skripte auf dem VPS ausführen
- [Todo] E2E-Tests für Caddy durchführen

### code-server-Implementierung

- [Todo] Feature-Branch für code-server erstellen
- [Todo] code-server-Installationsskript entwickeln
- [Todo] code-server-Konfigurationsskript entwickeln
- [Todo] E2E-Tests für code-server entwickeln
- [Todo] code-server-Skripte auf dem VPS ausführen
- [Todo] E2E-Tests für code-server durchführen

## Abgeschlossene Aufgaben (MVP)

### VPS-Vorbereitung

- [Merged] VPS-Vorbereitungsskript erstellt (prepare-vps.sh)
- [Merged] E2E-Tests für VPS-Vorbereitung entwickelt (test-vps-preparation.sh)
- [Merged] Probleme bei der VPS-Vorbereitung identifiziert
- [Merged] Korrekturskript erstellt (fix-vps-preparation.sh)
- [Merged] Korrekturskript auf dem VPS ausgeführt
- [Merged] Ergebnisse dokumentiert (plans/vps-korrekturen-ergebnisse.md)

### Tailscale-Implementierung

- [Merged] Feature-Branch für Tailscale erstellt (feature/tailscale-setup)
- [Merged] Tailscale-Installationsskript entwickelt (install-tailscale.sh)
- [Merged] Tailscale-Konfigurationsskript entwickelt (configure-tailscale.sh)
- [Merged] E2E-Tests für Tailscale entwickelt (test-tailscale.sh)
- [Merged] Tailscale-Skripte auf dem VPS ausgeführt
- [Merged] E2E-Tests für Tailscale durchgeführt
- [Merged] Probleme mit Tailscale behoben

## Offene Entscheidungen

Aktuell keine offenen Entscheidungen.

## Backlog / Zukünftige Ausbaustufen

### Projekt-Management

- [Todo] Projekt-Repository erstellen
- [Todo] Initiale Dokumentation aufsetzen
- [Todo] Projektmeilensteine definieren
- [Todo] Team-Rollen und Verantwortlichkeiten festlegen
- [Todo] Kickoff-Meeting organisieren

### Erweiterte Infrastruktur

- [Todo] Monitoring-Lösung einrichten
- [Todo] Backup-Strategie entwickeln und implementieren
- [Todo] Docker/Containerumgebung einrichten
- [Todo] Entwicklungstools und Dependencies installieren
- [Todo] CI/CD-Pipeline-Strategie festlegen
- [Todo] Storage-Lösung für Entwicklungsdaten auswählen
- [Todo] Multi-User-Konzept entwickeln
- [Todo] Kosten- und Skalierungsmodell definieren
- [Todo] Disaster-Recovery-Plan erstellen

### Erweiterte Tests

- [Todo] Testplan für Komponenten erstellen
- [Todo] Integrationstests definieren
- [Todo] Lasttests konzipieren und implementieren
- [Todo] Security-Audit durchführen
- [Todo] Dokumentation der Testfälle erstellen

### KI-Integration

- [Todo] Roo Code Extension installieren und konfigurieren
- [Todo] OpenRouter API-Integration einrichten
- [Todo] Ollama installieren und konfigurieren
- [Todo] Lokale Modelle herunterladen und einrichten
