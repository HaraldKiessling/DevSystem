#!/bin/bash
#
# Post-Merge Hook Template - Dokumentations-Reminder
#
# Installation:
#   bash scripts/docs/setup-git-hooks.sh
#
# Dieser Hook wird nach jedem 'git merge' ausgeführt und erinnert
# den Entwickler daran, die Dokumentation zu aktualisieren.

# Farben für Output
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║  📝 DOKUMENTATIONS-UPDATE ERFORDERLICH!           ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
echo -e "${YELLOW}Nach einem Merge sollten folgende Dokumente aktualisiert werden:${NC}"
echo ""
echo "  1. 📋 docs/project/todo.md"
echo "     - [ ] Tasks als [x] markieren"
echo "     - [ ] Zeitstempel aktualisieren"
echo "     - [ ] Branch-Referenzen entfernen"
echo ""
echo "  2. 📝 CHANGELOG.md"
echo "     - [ ] Änderungen in [Unreleased] oder [Version] dokumentieren"
echo "     - [ ] Korrekte Kategorie wählen (Added/Changed/Fixed/Removed)"
echo ""
echo "  3. 📊 docs/reports/DevSystem-Implementation-Status.md"
echo "     - [ ] Bei relevanten Änderungen aktualisieren"
echo ""
echo -e "${BLUE}Siehe Definition of Done:${NC}"
echo "  docs/operations/git-workflow.md#definition-of-done-dod"
echo ""
echo -e "${BLUE}Quick-Check ausführen:${NC}"
echo "  bash scripts/docs/pre-merge-check.sh"
echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║  Diese Nachricht kommt vom Post-Merge Git-Hook    ║"
echo "║  Deaktivieren: rm .git/hooks/post-merge           ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
