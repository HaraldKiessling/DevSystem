#!/bin/bash
# ============================================================================
# Zoo Code IaC Deployment – Provider & Modes auf den VPS ausrollen
# ============================================================================
# Version: 1.0 | Datum: 2026-05-31
#
# Dieses Skript wird vom GitHub Actions Workflow deploy-zoo-config.yml
# auf dem Ziel-VPS ausgeführt. Es deployt:
#   1. custom_modes.yaml → Zoo Code GlobalStorage
#   2. providers.json    → VS Code settings.json (gemerged)
#   3. mcp_settings.json → Zoo Code GlobalStorage (falls vorhanden)
#   4. API-Keys          → aus /etc/devsystem/llm.env geladen
#
# Idempotent: Mehrfaches Ausführen erzeugt keine Duplikate.
# ============================================================================
set -euo pipefail

# ----------------------------------------------------------------------------
# Konfiguration
# ----------------------------------------------------------------------------
ZOOGLOBAL="$HOME/.local/share/code-server/User/globalStorage/zoocodeorganization.zoo-code/settings"
REPO_CONFIG="/root/work/DevSystem/config/zoo"
LLM_ENV_FILE="/etc/devsystem/llm.env"
SETTINGS_FILE="$HOME/.local/share/code-server/User/settings.json"

# Farben (falls nicht definiert)
: "${GREEN:=\033[0;32m}"
: "${YELLOW:=\033[1;33m}"
: "${RED:=\033[0;31m}"
: "${CYAN:=\033[0;36m}"
: "${NC:=\033[0m}"

echo ""
echo -e "${CYAN}============================================================================${NC}"
echo -e "${CYAN}  Zoo Code IaC Deployment – Provider & Modes${NC}"
echo -e "${CYAN}  $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${CYAN}============================================================================${NC}"
echo ""

# ----------------------------------------------------------------------------
# Schritt 1: Custom Modes deployen
# ----------------------------------------------------------------------------
echo -e "${CYAN}[1/5] Deploye Custom Modes...${NC}"

if [ -f "${REPO_CONFIG}/custom_modes.yaml" ]; then
    mkdir -p "${ZOOGLOBAL}"

    # Backup falls vorhanden
    if [ -f "${ZOOGLOBAL}/custom_modes.yaml" ]; then
        cp "${ZOOGLOBAL}/custom_modes.yaml" "${ZOOGLOBAL}/custom_modes.yaml.bak-$(date +%Y%m%d-%H%M%S)"
        echo -e "  ${YELLOW}→ Backup erstellt: custom_modes.yaml.bak-*${NC}"
    fi

    cp "${REPO_CONFIG}/custom_modes.yaml" "${ZOOGLOBAL}/custom_modes.yaml"
    chmod 644 "${ZOOGLOBAL}/custom_modes.yaml"

    # Validiere: Zähle Modes
    MODE_COUNT=$(grep -c 'slug:' "${ZOOGLOBAL}/custom_modes.yaml" || echo "0")
    echo -e "  ${GREEN}✓ custom_modes.yaml → ${ZOOGLOBAL}/ (${MODE_COUNT} Modes)${NC}"
else
    echo -e "  ${RED}✗ custom_modes.yaml nicht gefunden in ${REPO_CONFIG}${NC}"
fi

# ----------------------------------------------------------------------------
# Schritt 2: Provider-Konfiguration in VS Code settings.json mergen
# ----------------------------------------------------------------------------
echo -e "${CYAN}[2/5] Merge Provider-Konfiguration in settings.json...${NC}"

if [ -f "${REPO_CONFIG}/providers.json" ]; then
    python3 -c "
import json, os, sys

# Lade Provider-Konfiguration
with open('${REPO_CONFIG}/providers.json') as f:
    providers = json.load(f)

# Lade bestehende settings.json (oder erstelle leeres dict)
settings = {}
if os.path.exists('${SETTINGS_FILE}'):
    with open('${SETTINGS_FILE}') as f:
        try:
            settings = json.load(f)
        except json.JSONDecodeError:
            print('WARNING: settings.json ist kein gültiges JSON – beginne mit leerem Dict', file=sys.stderr)
            settings = {}

# --- OpenRouter Provider ---
if 'openrouter' in providers.get('providers', {}):
    p = providers['providers']['openrouter']
    settings['zoo.openRouterApiKey'] = '\${OPENROUTER_API_KEY}'
    settings['zoo.openRouterBaseUrl'] = p['apiBase']
    settings['zoo.openRouterDefaultModel'] = p['defaultModel']
    print(f'  → OpenRouter: {p[\"defaultModel\"]} @ {p[\"apiBase\"]}')

# --- Ollama Local Provider ---
if 'ollama-local' in providers.get('providers', {}):
    p = providers['providers']['ollama-local']
    settings['zoo.ollamaEnabled'] = True
    settings['zoo.ollamaHost'] = p['apiBase']
    settings['zoo.ollamaDefaultModel'] = p['defaultModel']
    print(f'  → Ollama Local: {p[\"defaultModel\"]} @ {p[\"apiBase\"]}')

# --- Ollama Cloud Provider ---
if 'ollama-cloud' in providers.get('providers', {}):
    p = providers['providers']['ollama-cloud']
    settings['zoo.ollamaCloudEnabled'] = True
    settings['zoo.ollamaCloudBaseUrl'] = p['apiBase']
    settings['zoo.ollamaCloudDefaultModel'] = p['defaultModel']
    print(f'  → Ollama Cloud: {p[\"defaultModel\"]} @ {p[\"apiBase\"]}')

# Schreibe aktualisierte settings.json
os.makedirs(os.path.dirname('${SETTINGS_FILE}'), exist_ok=True)
with open('${SETTINGS_FILE}', 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
print(f'  ✓ settings.json aktualisiert ({len(settings)} keys)')
"
    echo -e "  ${GREEN}✓ providers.json → ${SETTINGS_FILE} (gemerged)${NC}"
else
    echo -e "  ${YELLOW}⚠ providers.json nicht gefunden – überspringe Provider-Merge${NC}"
fi

# ----------------------------------------------------------------------------
# Schritt 3: MCP Settings deployen (falls vorhanden)
# ----------------------------------------------------------------------------
echo -e "${CYAN}[3/5] Deploye MCP Settings...${NC}"

if [ -f "${REPO_CONFIG}/mcp_settings.json" ]; then
    cp "${REPO_CONFIG}/mcp_settings.json" "${ZOOGLOBAL}/mcp_settings.json"
    chmod 644 "${ZOOGLOBAL}/mcp_settings.json"
    echo -e "  ${GREEN}✓ mcp_settings.json → ${ZOOGLOBAL}/${NC}"
else
    echo -e "  ${YELLOW}⚠ mcp_settings.json nicht vorhanden – überspringe${NC}"
fi

# ----------------------------------------------------------------------------
# Schritt 4: API-Keys aus /etc/devsystem/llm.env laden
# ----------------------------------------------------------------------------
echo -e "${CYAN}[4/5] Lade API-Keys...${NC}"

if [ -f "${LLM_ENV_FILE}" ]; then
    # Lese Keys ohne sie in Logs auszugeben
    set -a
    source "${LLM_ENV_FILE}"
    set +a

    # Validiere ohne Werte preiszugeben
    if [ -n "${OPENROUTER_API_KEY:-}" ]; then
        echo -e "  ${GREEN}✓ OPENROUTER_API_KEY geladen (${#OPENROUTER_API_KEY} Zeichen)${NC}"
    else
        echo -e "  ${YELLOW}⚠ OPENROUTER_API_KEY nicht gesetzt${NC}"
    fi

    if [ -n "${OLLAMA_API_KEY:-}" ]; then
        echo -e "  ${GREEN}✓ OLLAMA_API_KEY geladen (${#OLLAMA_API_KEY} Zeichen)${NC}"
    else
        echo -e "  ${YELLOW}⚠ OLLAMA_API_KEY nicht gesetzt${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠ ${LLM_ENV_FILE} nicht gefunden – API-Keys fehlen${NC}"
    echo -e "  ${YELLOW}  → Deploy-Workflow sollte diese Datei vor diesem Skript erstellen${NC}"
fi

# ----------------------------------------------------------------------------
# Schritt 5: code-server neu starten
# ----------------------------------------------------------------------------
echo -e "${CYAN}[5/5] Starte code-server neu...${NC}"

# Versuche beide Service-Namen (QS und Standard)
if systemctl is-active --quiet code-server-qs 2>/dev/null; then
    systemctl restart code-server-qs
    echo -e "  ${GREEN}✓ code-server-qs neu gestartet${NC}"
elif systemctl is-active --quiet code-server 2>/dev/null; then
    systemctl restart code-server
    echo -e "  ${GREEN}✓ code-server neu gestartet${NC}"
else
    echo -e "  ${YELLOW}⚠ Weder code-server-qs noch code-server laufen – kein Neustart${NC}"
fi

# ----------------------------------------------------------------------------
# Abschluss
# ----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}  Zoo Code IaC Deployment abgeschlossen${NC}"
echo -e "${GREEN}  $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${GREEN}============================================================================${NC}"
echo ""

exit 0
