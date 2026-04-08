# DevSystem - Zentrale Aufgabenliste

## Projektzweck

Dieses Projekt zielt auf den Aufbau einer cloudbasierten Entwicklungsumgebung auf einem Ubuntu VPS mit Tailscale (VPN), Caddy (Reverse Proxy) und code-server (Web-IDE). Das System ermöglicht eine sichere, skalierbare und von überall zugängliche Entwicklungsumgebung für verteilte Teams.

## Aufgabenstatus

Im Projekt werden folgende Status für Aufgaben verwendet:

- **plan**: Aufgabe ist identifiziert, aber noch nicht begonnen
- **Konzeption**: Aufgabe befindet sich in der Planungs- und Entwurfsphase
- **Entwicklung**: Aktive Implementierung der Aufgabe
- **qs**: Qualitätssicherung und interne Tests
- **e2e**: End-to-End Tests und Integrationsvalidierung
- **fertig**: Aufgabe vollständig abgeschlossen und abgenommen

## MVP Aufgabenliste

### 1. Projektinitialisierung

- [plan] [2026-04-07] Projekt-Repository erstellen
- [plan] [2026-04-07] Initiale Dokumentation aufsetzen
- [plan] [2026-04-07] Projektmeilensteine definieren
- [plan] [2026-04-07] Team-Rollen und Verantwortlichkeiten festlegen
- [plan] [2026-04-07] Kickoff-Meeting organisieren

### 2. Infrastruktur-Setup

- [fertig] [2026-04-07] VPS-Provider auswählen und Server provisionieren
- [fertig] [2026-04-08] Grundlegende Ubuntu-Konfiguration vornehmen
- [fertig] [2026-04-08] Firewall-Regeln festlegen und implementieren
- [plan] [2026-04-07] Monitoring-Lösung einrichten
- [plan] [2026-04-07] Backup-Strategie entwickeln und implementieren
- [fertig] [2026-04-08] SSH-Schlüssel und Zugriffsverwaltung konfigurieren

#### 2.1 VPS-Vorbereitung

- [fertig] [2026-04-08] Initiales VPS-Vorbereitungsskript erstellen (prepare-vps.sh)
- [fertig] [2026-04-08] E2E-Tests für VPS-Vorbereitung entwickeln (test-vps-preparation.sh)
- [fertig] [2026-04-08] Probleme bei der VPS-Vorbereitung identifizieren
- [fertig] [2026-04-08] Korrekturskript erstellen (fix-vps-preparation.sh)
- [fertig] [2026-04-08] Korrekturskript auf dem VPS ausführen
- [fertig] [2026-04-08] Ergebnisse dokumentieren (plans/vps-korrekturen-ergebnisse.md)

### 3. Komponenten-Konfiguration

- [plan] [2026-04-07] Tailscale VPN installieren und konfigurieren
- [plan] [2026-04-07] Caddy als Reverse Proxy einrichten
- [plan] [2026-04-07] SSL/TLS-Zertifikate konfigurieren
- [plan] [2026-04-07] code-server installieren und anpassen
- [plan] [2026-04-07] Docker/Containerumgebung einrichten
- [plan] [2026-04-07] Entwicklungstools und Dependencies installieren
- [plan] [2026-04-07] Authentifizierungssystem implementieren

### 4. Testkonzept

- [plan] [2026-04-07] Testplan für Komponenten erstellen
- [plan] [2026-04-07] Integrationstests definieren
- [plan] [2026-04-07] Lasttests konzipieren und implementieren
- [plan] [2026-04-07] Security-Audit durchführen
- [plan] [2026-04-07] Dokumentation der Testfälle erstellen

### 5. Offene Entscheidungen

- [plan] [2026-04-07] CI/CD-Pipeline-Strategie festlegen
- [plan] [2026-04-07] Storage-Lösung für Entwicklungsdaten auswählen
- [plan] [2026-04-07] Multi-User-Konzept entwickeln
- [plan] [2026-04-07] Kosten- und Skalierungsmodell definieren
- [plan] [2026-04-07] Disaster-Recovery-Plan erstellen


## Backlog / Zukünftige Ausbaustufen
