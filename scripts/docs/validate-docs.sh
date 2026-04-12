#!/bin/bash
# Pre-commit Hook: Dokumentationsvalidierung
# Prüft Dokumentengrößen und ungültige Referenzen

set -e

DOCS_DIR="docs"
MIN_LINES=100
MAX_LINES=500

# TODO: Diese Ausnahmen sind temporär. Siehe Issue #XX für vollständige Migration.
# Ausnahmen für zu große Dokumente (temporär bis Migration)
MAX_LINES_EXCEPTIONS="issue-examples.md|feature-issues-batch-1.md|feature-workflow.md|documentation-governance.md|QS-SYSTEM-OPTIMIZATION-STEP1.md|QS-SYSTEM-OPTIMIZATION-SUMMARY.md|CODE-REVIEW-REPORT-STEP3.md|DOCUMENTATION-CHANGELOG.md|qs-implementierungsplan-final.md|qs-github-integration-strategie.md|deployment-prozess.md|sicherheitskonzept.md|code-server-konzept.md|caddy-konzept.md|qs-vps-konzept.md|ki-integration-konzept.md|testkonzept.md"

# Ausnahmen für zu kleine Dokumente (temporär bis Migration)
MIN_LINES_EXCEPTIONS="VISION.md|github-automation-summary.md"

echo "🔍 Validiere Dokumentation..."

# Zähler für Verstöße
violations=0

# 1. Prüfe Dokumentengrößen (ohne Archive)
for file in $(find "$DOCS_DIR" -name "*.md" -not -path "*/archive/*" -type f); do
    lines=$(wc -l < "$file")
    filename=$(basename "$file")
    
    # Überspringe READMEs und Index-Dateien
    if [[ "$filename" == "README.md" ]] || [[ "$filename" == "CHANGELOG.md" ]]; then
        continue
    fi
    
    # Überspringe MAX_LINES Ausnahmen
    if [[ "$MAX_LINES_EXCEPTIONS" =~ "$filename" ]]; then
        continue
    fi
    
    # Prüfe Mindestgröße
    if [ "$lines" -lt "$MIN_LINES" ]; then
        # Überspringe MIN_LINES Ausnahmen
        if [[ "$MIN_LINES_EXCEPTIONS" =~ "$filename" ]]; then
            continue
        fi
        echo "❌ $file: Nur $lines Zeilen (Minimum: $MIN_LINES)"
        violations=$((violations + 1))
    fi
    
    # Prüfe Maximalgröße
    if [ "$lines" -gt "$MAX_LINES" ]; then
        echo "❌ $file: $lines Zeilen (Maximum: $MAX_LINES)"
        violations=$((violations + 1))
    fi
done

# 2. Prüfe auf ungültige todo.md-Links (außer in Archive und operational Reports)
# Erlaubt historische Erwähnungen in Reports, aber keine aktiven Links in Konzepten/Guides
todo_files=$(find "$DOCS_DIR" -name "*.md" -not -path "*/archive/*" -not -path "*/reports/*" -type f \
    ! -name "QUICK-START-ISSUE-*.md" ! -name "*-report.md" ! -name "*REPORT*.md" ! -name "DOCUMENTATION-CHANGELOG.md" \
    -exec grep -l '\[.*\](.*todo\.md)' {} \; 2>/dev/null)

if [ -n "$todo_files" ]; then
    echo "❌ Ungültige todo.md-Links gefunden:"
    echo "$todo_files" | while read -r file; do
        grep -Hn '\[.*\](.*todo\.md)' "$file" 2>/dev/null
    done
    violations=$((violations + 1))
fi

# 3. Ergebnis
if [ "$violations" -gt 0 ]; then
    echo ""
    echo "❌ $violations Dokumentationsregel-Verstöße gefunden!"
    echo "Siehe docs/operations/documentation-governance.md für Details"
    exit 1
else
    echo "✅ Dokumentation valide"
fi
