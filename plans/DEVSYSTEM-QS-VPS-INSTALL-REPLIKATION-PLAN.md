# DevSystem QS-VPS Installations- und Replikationsplan

**Ziel:** 1:1 Replikation der Quellsystem-Konfiguration (Zoo/Roo Code, LLM-Anbindung, Agents) auf den Zielserver `devsystem-qs-vps`.

## 1. Inventar des aktuellen Zoo-Setups (Quellsystem)

### 1.1 Custom Modes

Definiert in: `/root/.local/share/code-server/User/globalStorage/zoocodeorganization.zoo-code/settings/custom_modes.yaml`

- **🦙 Ollama Local (`ollama-local`)**
  - Rolle: Datenschutzfreundlicher lokaler Assistent.
  - Modelle: `qwen2.5-coder:7b` (Code), `qwen2.5:3b` (Allgemein), `nomic-embed-text` (Embeddings).
  - Endpunkt: `http://localhost:11434`
- **🔀 Hybrid (Ollama + OpenRouter) (`hybrid-ollama-openrouter`)**
  - Rolle: Intelligente Kombination aus lokalen und Cloud-Modellen.
  - Lokale Modelle: `qwen2.5-coder:7b`, `qwen2.5:3b`.
  - Cloud Modell: Claude Sonnet 4.6 (via OpenRouter).
  - Endpunkte: `http://localhost:11434` (Ollama), OpenRouter API.

### 1.2 LLM-Konfiguration & Modelle

- **Ollama Endpunkt:** `http://localhost:11434` (lokal auf dem VPS).
- **Benötigte lokale Ollama-Modelle:**
  - `qwen2.5-coder:7b` (Zoo Code)
  - `qwen2.5:3b` (Zoo Allgemein)
  - `nomic-embed-text` (Zoo Embeddings / GitLens)
  - `phi3.5:3.8b` (Standard-Modell laut `install-ollama-qs.sh`)
- **OpenRouter:** Konfiguration erfolgt über die Zoo-Extension-Settings (API-Key wird im Secret-Store der Extension gehalten).

### 1.3 Workspace-Regeln

- Verzeichnis: `.Roo/` im Workspace `/root/work/DevSystem`.
- Enthält: `rules.md`, `context.md`, `mode-rules/`, `project-rules/`.

### 1.4 VS Code / code-server Settings

- Definiert in: `/root/.local/share/code-server/User/settings.json`
- Relevante Keys: `zoo-code.allowedCommands`, `gitlens.ai.ollama.url` (`http://localhost:11434`), `gitlens.ai.model` (`ollama:nomic-embed-text:latest`).

---

## 2. Installationsreihenfolge der Basiskomponenten

Basierend auf `scripts/QS-DEVSERVER-WORKFLOW.md` und `scripts/qs/setup-qs-master.sh`:

1.  **Tailscale & Basis-Setup:** Erfolgt automatisch via Cloud-Init bei der VPS-Erstellung.
2.  **Caddy Reverse Proxy:**
    - Skript: `scripts/qs/install-caddy-qs.sh`
    - Konfiguration: `scripts/qs/configure-caddy-qs.sh` (benötigt `QS_TAILSCALE_IP`)
3.  **code-server (Web-IDE):**
    - Skript: `scripts/qs/install-code-server-qs.sh`
    - Konfiguration: `scripts/qs/configure-code-server-qs.sh`
4.  **Qdrant (Vektordatenbank):**
    - Skript: `scripts/qs/deploy-qdrant-qs.sh`
5.  **Ollama (LLM-Server):**
    - Skript: `scripts/qs/install-ollama-qs.sh` (installiert standardmäßig `phi3.5:3.8b`)

_Hinweis: Die Skripte nutzen die Idempotenz-Library (`scripts/qs/lib/idempotency.sh`), sodass sie sicher mehrfach ausgeführt werden können._

---

## 3. Replikations-Schritte für die Zoo-Konfiguration

### 3.1 Liste der zu replizierenden Dateien (Quelle → Ziel)

| Quellpfad (Quellsystem)                                                                                     | Zielpfad (`devsystem-qs-vps`)                                                                                             | Beschreibung                             |
| :---------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------ | :--------------------------------------- |
| `/root/.local/share/code-server/User/globalStorage/zoocodeorganization.zoo-code/settings/custom_modes.yaml` | `/home/codeserver-qs/.local/share/code-server/User/globalStorage/zoocodeorganization.zoo-code/settings/custom_modes.yaml` | Custom Modes Definitionen                |
| `/root/.local/share/code-server/User/settings.json`                                                         | `/home/codeserver-qs/.local/share/code-server/User/settings.json`                                                         | VS Code Settings (inkl. allowedCommands) |
| `/root/.local/share/code-server/User/globalStorage/zoocodeorganization.zoo-code/settings/mcp_settings.json` | `/home/codeserver-qs/.local/share/code-server/User/globalStorage/zoocodeorganization.zoo-code/settings/mcp_settings.json` | MCP Settings                             |
| `/root/work/DevSystem/.Roo/`                                                                                | `/home/codeserver-qs/workspaces/DevSystem-QS/.Roo/`                                                                       | Workspace-spezifische Regeln             |

_Anmerkung: Der Ziel-User ist `codeserver-qs` (laut `install-code-server-qs.sh`), daher liegen die Settings in dessen Home-Verzeichnis._

### 3.2 Zusätzliche Replikations-Befehle (Ollama Modelle)

Nach der Installation von Ollama müssen die für Zoo benötigten Modelle auf dem Zielserver gepullt werden:

```bash
ssh root@devsystem-qs-vps "ollama pull qwen2.5-coder:7b && ollama pull qwen2.5:3b && ollama pull nomic-embed-text"
```

### 3.3 Behandlung von Secrets / API-Keys

- **OpenRouter API-Key:** Dieser ist nicht in Klartext-Dateien gespeichert, sondern im sicheren Secret-Store der VS Code Extension. Er muss auf dem Zielserver nach der Installation der Zoo-Extension manuell über die UI eingegeben werden.
- **Qdrant API-Key:** Wird über die Variable `QS_QDRANT_API_KEY` im Deployment-Skript gesteuert.
- **Tailscale Auth-Key:** Wird im Cloud-Init-Skript verwendet.

---

## 4. Verifikationskriterien

1.  **Infrastruktur:**
    - `systemctl is-active caddy code-server-qs qdrant-qs ollama` liefert für alle Services `active`.
    - Zugriff auf code-server via `https://devsystem-qs-vps.tailcfea8a.ts.net:9443` funktioniert.
2.  **Ollama & Modelle:**
    - `ollama list` auf dem Zielserver zeigt `phi3.5:3.8b`, `qwen2.5-coder:7b`, `qwen2.5:3b` und `nomic-embed-text`.
    - `curl http://localhost:11434/api/version` antwortet erfolgreich.
3.  **Zoo-Konfiguration:**
    - In der code-server UI sind die Modi "🦙 Ollama Local" und "🔀 Hybrid (Ollama + OpenRouter)" auswählbar.
    - Ein Test-Prompt im "Ollama Local" Modus wird erfolgreich lokal verarbeitet (prüfbar via `journalctl -u ollama -f`).

---

## 5. Offene Punkte / Risiken / Abweichungen

- **Ressourcen-Limitierung:** Das Skript `install-ollama-qs.sh` konfiguriert Ollama restriktiv (`MemoryMax=6G`, `OLLAMA_MAX_LOADED_MODELS=1`). Die Zoo-Modi benötigen jedoch potenziell andere Modelle (`qwen2.5-coder:7b`). Es muss sichergestellt werden, dass der QS-VPS (8GB RAM) beim Modellwechsel nicht in OOM (Out of Memory) läuft. Ggf. muss die `ollama.service` Konfiguration auf dem Zielserver angepasst werden, um Modellwechsel flüssiger zu gestalten oder das Memory-Limit leicht anzuheben.
- **User-Mapping:** Auf dem Quellsystem läuft code-server als `root` (Pfade unter `/root/.local/...`). Auf dem Zielserver wird laut Skript der User `codeserver-qs` verwendet. Die Replikationspfade müssen entsprechend auf `/home/codeserver-qs/...` gemappt werden.
- **Extension-Installation:** Die Zoo-Extension wird über `configure-code-server-qs.sh` idempotent nachinstalliert, falls sie fehlt. Dadurch bleiben die Zoo-Settings nach Deploy/Update verfügbar.
- **OpenRouter Secret:** Muss manuell nachgepflegt werden, da es nicht dateibasiert repliziert werden kann.

### 3.4 Zoo-Extension Installation (idempotent, QS)

Die Zoo-Extension wird auf dem QS-VPS über das bestehende Konfigurationsskript installiert. Dieses Vorgehen ist idempotent: fehlende Extensions werden nachinstalliert, vorhandene bleiben unverändert.

```bash
# Als root auf dem QS-VPS
sudo bash /root/work/DevSystem/scripts/qs/configure-code-server-qs.sh

# Optional: nur Zoo-Extension prüfen/installieren (läuft trotzdem idempotent)
sudo -u codeserver-qs code-server --list-extensions | grep -q '^zoocodeorganization\.zoo-code$' \
  || sudo -u codeserver-qs code-server --install-extension zoocodeorganization.zoo-code

# Service neu starten, damit die UI die Extension lädt
sudo systemctl restart code-server-qs
```
