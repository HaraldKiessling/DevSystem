#!/bin/bash
#
# Pre-Merge Documentation Check
# 
# Dieses Script prüft, ob alle Dokumentations-Anforderungen vor einem Merge erfüllt sind.
# Verwendung: bash scripts/docs/pre-merge-check.sh
#
# Exit Codes:
#   0 - Alle Checks bestanden
#   1 - Ein oder mehrere Checks fehlgeschlagen

set -euo pipefail

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Zähler für Errors und Warnings
ERRORS=0
WARNINGS=0

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📋 Pre-Merge Dokumentations-Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Funktion: Error ausgeben
error() {
    echo -e "${RED}❌ ERROR:${NC} $1"
    ((ERRORS++))
}

# Funktion: Warning ausgeben
warning() {
    echo -e "${YELLOW}⚠️  WARNING:${NC} $1"
    ((WARNINGS++))
}

# Funktion: Success ausgeben
success() {
    echo -e "${GREEN}✅ OK:${NC} $1"
}

# Funktion: Info ausgeben
info() {
    echo -e "${BLUE}ℹ️  INFO:${NC} $1"
}

# Check 1: Aktueller Branch
echo "━━━ Check 1: Branch-Information"
CURRENT_BRANCH=$(git branch --show-current)
if [ -z "$CURRENT_BRANCH" ]; then
    error "Kein Branch ausgecheckt (detached HEAD?)"
else
    info "Aktueller Branch: ${CURRENT_BRANCH}"
    
    # Prüfe ob Branch in Dokumentation erwähnt wird
    if grep -rq "$CURRENT_BRANCH" docs/ 2>/dev/null; then
        warning "Branch-Name '$CURRENT_BRANCH' gefunden in Dokumentation"
        echo "     Bitte Branch-Referenzen aus folgenden Dateien entfernen:"
        grep -rl "$CURRENT_BRANCH" docs/ | sed 's/^/     - /'
    else
        success "Keine Branch-Referenzen in Dokumentation"
    fi
fi
echo ""

# Check 2: todo.md Timestamp
echo "━━━ Check 2: todo.md Zeitstempel"
if [ ! -f "docs/project/todo.md" ]; then
    error "docs/project/todo.md nicht gefunden!"
else
    # Extrahiere Timestamp
    TODO_TIMESTAMP=$(grep -oP '(?<=\*\*Stand:\*\* )\d{4}-\d{2}-\d{2} \d{2}:\d{2}' docs/project/todo.md || echo "")
    
    if [ -z "$TODO_TIMESTAMP" ]; then
        error "Kein Zeitstempel in todo.md gefunden (Format: **Stand:** YYYY-MM-DD HH:MM)"
    else
        info "todo.md Timestamp: $TODO_TIMESTAMP UTC"
        
        # Berechne Alter (vereinfacht - nur für Linux/macOS mit GNU date)
        if command -v date >/dev/null 2>&1; then
            TODO_EPOCH=$(date -d "$TODO_TIMESTAMP UTC" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M" "$TODO_TIMESTAMP" +%s 2>/dev/null || echo "0")
            CURRENT_EPOCH=$(date +%s)
            
            if [ "$TODO_EPOCH" != "0" ]; then
                DIFF_HOURS=$(( (CURRENT_EPOCH - TODO_EPOCH) / 3600 ))
                
                if [ $DIFF_HOURS -gt 24 ]; then
                    error "todo.md ist $DIFF_HOURS Stunden alt (>24h threshold)"
                elif [ $DIFF_HOURS -gt 4 ]; then
                    warning "todo.md ist $DIFF_HOURS Stunden alt (>4h - sollte aktualisiert werden)"
                else
                    success "todo.md ist aktuell ($DIFF_HOURS Stunden alt)"
                fi
            else
                warning "Konnte Timestamp-Alter nicht berechnen (date-Format-Problem)"
            fi
        else
            warning "date-Command nicht verfügbar - kann Timestamp-Alter nicht prüfen"
        fi
    fi
fi
echo ""

# Check 3: CHANGELOG Update
echo "━━━ Check 3: CHANGELOG.md Änderungen"
if [ ! -f "CHANGELOG.md" ]; then
    warning "CHANGELOG.md nicht gefunden"
else
    # Prüfe ob CHANGELOG in current branch geändert wurde vs. main
    if git rev-parse --verify origin/main >/dev/null 2>&1; then
        CHANGELOG_DIFF=$(git diff origin/main...HEAD -- CHANGELOG.md | grep -c "^+" || echo "0")
        
        if [ "$CHANGELOG_DIFF" -eq 0 ]; then
            warning "Keine Änderungen in CHANGELOG.md gefunden"
            echo "     Wenn dieser Branch Code-Änderungen enthält, sollte CHANGELOG aktualisiert werden"
        else
            success "CHANGELOG.md wurde aktualisiert ($CHANGELOG_DIFF neue Zeilen)"
        fi
    else
        warning "origin/main Branch nicht gefunden - kann CHANGELOG-Diff nicht prüfen"
    fi
fi
echo ""

# Check 4: Offene TODOs im Code
echo "━━━ Check 4: TODOs/FIXMEs im Code"
TODO_COUNT=$(git diff origin/main...HEAD -- scripts/ | grep -c "TODO\|FIXME" || echo "0")
if [ "$TODO_COUNT" -gt 0 ]; then
    warning "Branch enthält $TODO_COUNT neue TODO/FIXME Kommentare"
    echo "     Bitte vor Merge addressieren oder als Known Issue dokumentieren"
else
    success "Keine neuen TODO/FIXME Kommentare"
fi
echo ""

# Check 5: Dokumentations-Dateien geändert?
echo "━━━ Check 5: Dokumentations-Updates"
if git rev-parse --verify origin/main >/dev/null 2>&1; then
    DOCS_CHANGED=$(git diff origin/main...HEAD --name-only -- docs/ | wc -l)
    CODE_CHANGED=$(git diff origin/main...HEAD --name-only -- scripts/ | wc -l)
    
    if [ "$CODE_CHANGED" -gt 0 ] && [ "$DOCS_CHANGED" -eq 0 ]; then
        warning "Code wurde geändert ($CODE_CHANGED Dateien) aber keine Dokumentation"
        echo "     Prüfe ob Dokumentations-Updates nötig sind"
    else
        success "Dokumentation wurde aktualisiert ($DOCS_CHANGED Dateien)"
    fi
else
    info "Kann Dokumentations-Changes nicht prüfen (origin/main fehlt)"
fi
echo ""

# Check 6: Git Status (uncommitted changes)
echo "━━━ Check 6: Git Working Directory Status"
if [ -n "$(git status --porcelain)" ]; then
    error "Uncommitted Änderungen gefunden!"
    echo ""
    git status --short
    echo ""
    echo "     Bitte alle Änderungen committen vor Merge"
else
    success "Keine uncommitted Änderungen"
fi
echo ""

# Check 7: Merge-Konflikte mit main
echo "━━━ Check 7: Merge-Konflikte mit main"
if git rev-parse --verify origin/main >/dev/null 2>&1; then
    # Teste Merge (dry-run)
    git merge-tree $(git merge-base HEAD origin/main) HEAD origin/main > /tmp/merge-test.txt 2>&1
    
    if grep -q "<<<<<<" /tmp/merge-test.txt; then
        error "Merge-Konflikte mit origin/main gefunden!"
        echo "     Bitte zuerst 'git merge origin/main' oder 'git rebase origin/main' ausführen"
    else
        success "Keine Merge-Konflikte mit main"
    fi
    rm -f /tmp/merge-test.txt
else
    warning "origin/main nicht gefunden - kann Konflikte nicht prüfen"
fi
echo ""

# Zusammenfassung
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📊 Zusammenfassung"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ Alle Pre-Merge-Checks bestanden!${NC}"
    echo ""
    echo "Bereit für Merge nach main."
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  $WARNINGS Warning(s) gefunden${NC}"
    echo ""
    echo "Merge ist möglich, aber bitte Warnings überprüfen."
    echo ""
    echo "Trotzdem fortfahren? (y/N)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        exit 0
    else
        exit 1
    fi
else
    echo -e "${RED}❌ $ERRORS Error(s) und $WARNINGS Warning(s) gefunden${NC}"
    echo ""
    echo "Bitte Errors beheben vor Merge!"
    echo ""
    echo "Siehe Definition of Done:"
    echo "  docs/operations/git-workflow.md#definition-of-done-dod"
    exit 1
fi
