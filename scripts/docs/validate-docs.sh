#!/bin/bash
# Pre-commit Hook: Dokumentationsvalidierung
# Prüft Dokumentengrößen und ungültige Referenzen

set -e

DOCS_DIR="docs"
MIN_LINES=100
MAX_LINES=500
MAX_LINES_EXCEPTIONS="issue-examples.md"  # Erlaubte Ausnahmen

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
    
    # Überspringe erlaubte Ausnahmen
    if [[ "$MAX_LINES_EXCEPTIONS" == *"$filename"* ]]; then
        continue
    fi
    
    # Prüfe Mindestgröße
    if [ "$lines" -lt "$MIN_LINES" ]; then
        echo "❌ $file: Nur $lines Zeilen (Minimum: $MIN_LINES)"
        violations=$((violations + 1))
    fi
    
    # Prüfe Maximalgröße
    if [ "$lines" -gt "$MAX_LINES" ]; then
        echo "❌ $file: $lines Zeilen (Maximum: $MAX_LINES)"
        violations=$((violations + 1))
    fi
done

# 2. Prüfe auf ungültige todo.md-Referenzen (außer in Archive)
if grep -r "todo\.md" "$DOCS_DIR" --exclude-dir=archive --include="*.md" > /dev/null 2>&1; then
    echo "❌ Ungültige todo.md-Referenzen gefunden:"
    grep -n "todo\.md" "$DOCS_DIR" --exclude-dir=archive --include="*.md"
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
