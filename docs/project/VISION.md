# DevSystem - Project Vision

## Fachliche Anforderungen an das Cloud-Entwicklungssystem

Das Zielsystem ist eine vollständig remote nutzbare, KI-gestützte Entwicklungsumgebung. Folgende fachliche Kernanforderungen müssen erfüllt sein:

1. **Mobiler und geräteunabhängiger Zugriff:** - Die gesamte Entwicklungsumgebung muss als Web-Anwendung (PWA-fähig) im Browser bedienbar sein.
   - Eine Nutzung über mobile Endgeräte (Smartphones/Tablets) zur Steuerung von KI-Agenten und zum Ausführen von Skripten muss reibungslos möglich sein.

2. **Autonome Multi-Agent-KI-Unterstützung:**
   - Das System muss KI-Agenten unterstützen, die direkt in der IDE agieren, den Projektkontext (Dateisystem) lesen, Code schreiben und Terminal-Befehle ausführen können.
   - Der Benutzer fungiert primär als Reviewer (Approve/Reject von Dateiänderungen oder Terminal-Befehlen).

3. **Hybride KI-Strategie (Cloud & Lokal):**
   - **Cloud-Modelle:** Nahtlose Integration von High-End-Modellen (z. B. Claude 3.5 Sonnet) über externe APIs für komplexe Aufgaben.
   - **Lokale Modelle:** Das System muss auf dem VPS eine lokale KI-Infrastruktur bereitstellen, um einfache oder datenschutzkritische Aufgaben ohne externe API-Kosten abzuarbeiten.

4. **Sicherheit und Zero-Trust-Zugriff:**
   - Die Entwicklungsumgebung darf **nicht** öffentlich über das Internet erreichbar sein.
   - Der Zugriff erfolgt ausschließlich über ein privates VPN.
   - Der Datenverkehr zwischen Client (Browser) und Server muss zwingend über HTTPS (SSL-verschlüsselt) laufen.

---

## Technische Komponenten (Technologie-Stack)

Um die fachlichen Anforderungen zu erfüllen, sind exakt diese Komponenten auf dem Zielsystem (IONOS Ubuntu VPS) zu installieren und zu konfigurieren:

* **Betriebssystem:** Ubuntu Linux (bereits via IONOS bereitgestellt).
* **Netzwerksicherheit & VPN:** `Tailscale` 
  - *Zweck:* Sichert den Zugang zum Server ab. Nur authentifizierte Geräte im Tailnet erhalten Zugriff auf die IDE.
* **Reverse Proxy & SSL:** `Caddy`
  - *Zweck:* Nimmt den internen Traffic entgegen und stellt die HTTPS-Verschlüsselung sicher (Integration mit Tailscale-Zertifikaten oder internem HTTPS bevorzugt).
* **Web-IDE:** `code-server` (von Coder)
  - *Zweck:* Stellt die VS Code Oberfläche direkt über den Browser bereit.
* **KI-Agent / IDE-Erweiterung:** `Roo Code` (VS Code Extension)
  - *Zweck:* Übernimmt die Rolle des autonomen Multi-Agenten innerhalb des `code-server`.
* **API-Gateway für Cloud-KI:** `OpenRouter`
  - *Zweck:* Dient in den Roo Code Einstellungen als Provider für Cloud-Modelle.
* **Lokale KI-Engine:** `Ollama`
  - *Zweck:* Hostet lokale Modelle (z. B. Llama 3, DeepSeek) direkt auf dem VPS als kostenlose, private Alternative, die von Roo Code angesteuert werden kann.

