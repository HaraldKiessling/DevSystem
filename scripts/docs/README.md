# Dokumentations-Tools

## Setup pre-commit Hook

```bash
cp validate-docs.sh ../../.git/hooks/pre-commit
chmod +x ../../.git/hooks/pre-commit
```

## Manuelle Validierung

```bash
./validate-docs.sh
```

## Was wird geprüft?

1. **Dokumentengröße:** 100-500 Zeilen (außer READMEs)
2. **todo.md-Referenzen:** Keine in aktiven Dokumenten
3. **Broken Links:** Alle internen Links gültig
4. **Markdown-Syntax:** Korrekte Formatierung

## Ausnahmen

Folgende Dateien sind von der Größenprüfung ausgenommen:
- `README.md` (alle Verzeichnisse)
- `CHANGELOG.md`
- `issue-examples.md` (enthält viele Beispiele)

## Fehlerbehandlung

Bei Verstößen:
- Exit-Code: 1
- Fehlermeldungen zeigen betroffene Dateien
- Siehe [`documentation-governance.md`](../../docs/operations/documentation-governance.md) für Details

## CI/CD Integration

Die Validierung läuft automatisch bei:
- Jedem Pull Request mit Dokumentationsänderungen
- Push zu `main` Branch

Siehe [`.github/workflows/docs-validation.yml`](../../.github/workflows/docs-validation.yml)
