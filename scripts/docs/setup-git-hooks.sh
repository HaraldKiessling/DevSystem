#!/bin/bash
#
# Setup Git Hooks für Dokumentations-Synchronisation
#
# Dieses Script installiert Git-Hooks für:
# - Post-Merge: Dokumentations-Reminder nach jedem Merge
# - (Zukünftig) Pre-Commit: Validierung vor Commits
#
# Verwendung: bash scripts/docs/setup-git-hooks.sh

set -euo pipefail

# Farben
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🔧 Git Hooks Setup für Dokumentations-Sync"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Prüfe ob wir in einem Git-Repository sind
if [ ! -d ".git" ]; then
    echo -e "${RED}❌ ERROR:${NC} Kein Git-Repository gefunden!"
    echo "   Bitte dieses Script vom Repository-Root ausführen."
    exit 1
fi

# Prüfe ob Hook-Templates existieren
if [ ! -f "scripts/docs/post-merge-hook-template.sh" ]; then
    echo -e "${RED}❌ ERROR:${NC} Hook-Template nicht gefunden!"
    echo "   Erwarteter Pfad: scripts/docs/post-merge-hook-template.sh"
    exit 1
fi

# Installiere Post-Merge Hook
echo -e "${BLUE}📝 Installiere Post-Merge Hook...${NC}"

HOOK_PATH=".git/hooks/post-merge"

if [ -f "$HOOK_PATH" ]; then
    echo -e "${YELLOW}⚠️  WARNING:${NC} Existierender Post-Merge Hook gefunden"
    echo "   Backup erstellen? (y/N)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        cp "$HOOK_PATH" "$HOOK_PATH.backup-$(date +%Y%m%d-%H%M%S)"
        echo -e "${GREEN}✅${NC} Backup erstellt: $HOOK_PATH.backup-*"
    fi
fi

# Kopiere Template und mache ausführbar
cp scripts/docs/post-merge-hook-template.sh "$HOOK_PATH"
chmod +x "$HOOK_PATH"

echo -e "${GREEN}✅ Post-Merge Hook installiert${NC}"
echo ""

# Teste Hook
echo -e "${BLUE}🧪 Teste Hook-Installation...${NC}"
if [ -x "$HOOK_PATH" ]; then
    echo -e "${GREEN}✅ Hook ist ausführbar${NC}"
else
    echo -e "${RED}❌ Hook ist nicht ausführbar!${NC}"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Setup abgeschlossen!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}Installierte Hooks:${NC}"
echo "  - Post-Merge: $HOOK_PATH"
echo ""
echo -e "${BLUE}Test-Ausführung:${NC}"
echo "  Der Hook wird automatisch nach jedem 'git merge' ausgeführt."
echo "  Manueller Test:"
echo "    $HOOK_PATH"
echo ""
echo -e "${BLUE}Deaktivierung:${NC}"
echo "  rm .git/hooks/post-merge"
echo ""
echo -e "${BLUE}Re-Installation:${NC}"
echo "  bash scripts/docs/setup-git-hooks.sh"
echo ""
