# DevSystem Projektregeln

## Projektübersicht
Cloud-basierte Entwicklungsumgebung auf Ubuntu VPS mit Tailscale, Caddy und code-server für sichere, mobile KI-gestützte Entwicklung.

## Unverrückbare Kernregeln

### 1. To-Do-Management
- Zentrale todo.md ist die Single Source of Truth
- Große Aufgaben MÜSSEN rekursiv aufgeteilt werden
- Jede Aufgabe durchläuft: plan → Konzeption → Entwicklung → qs → e2e → fertig
- Statusänderungen werden in Commits dokumentiert

### 2. Git-Workflow
- **Konzepte**: Direkt in main committen
- **Code/Setup-Skripte**: Nur in Feature-Branches (feature/<komponente>-<beschreibung>)
- **Merge-Bedingung**: Nur nach erfolgreichem E2E-Test
- Commit-Format: `<typ>: <beschreibung>` (feat, fix, docs, test, config, refactor)
es muss alles aus den branch nach main. Dann branch löschen 

### 3. Entwicklungsprinzipien
- **MVP-First**: Schnellster Weg zum Minimum Viable Product
- **Iterativ**: Schrittweise Verbesserung statt Big Bang
- **Test-Driven**: E2E-Tests vor Merge zwingend erforderlich
- **Log-Validierung**: Tests müssen Log-Ausgaben explizit prüfen

### 4. Entscheidungsfindung
- Offene Fragen in todo.md mit Alternativen + Empfehlung dokumentieren
- Benutzer entscheidet per Chat oder Datei-Anpassung
- Keine Blockierung durch fehlende Entscheidungen

### 5. Sicherheit
- **Zero-Trust**: Kein öffentlicher Internet-Zugang
- **VPN-Only**: Zugriff ausschließlich über Tailscale
- **HTTPS-Pflicht**: Alle Verbindungen SSL-verschlüsselt
- **Secrets**: Niemals in Git committen (.env, *.key, *.pem)

## Technologie-Stack
- **OS**: Ubuntu Linux (IONOS VPS)
- **VPN**: Tailscale
- **Reverse Proxy**: Caddy (HTTPS/SSL)
- **IDE**: code-server (VS Code im Browser)
- **KI-Agent**: Roo Code Extension
- **Cloud-KI**: OpenRouter (Claude 3.5 Sonnet)
- **Lokale KI**: Ollama (Llama 3, DeepSeek)

## Dokumentationsstandards
- Konzeptdokumente in /plans/
- Alle Änderungen müssen dokumentiert werden
- Mermaid-Diagramme für komplexe Workflows
- Deutsche Sprache für Dokumentation
