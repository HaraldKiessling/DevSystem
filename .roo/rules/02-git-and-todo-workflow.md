# Projektmanagement & Git-Workflow

## MVP-Fokus (Minimum Viable Product)
- **Die MVP-Schranke:** Bevor du eine neue Aufgabe planst oder startest, musst du zwingend prüfen: "Ist das für die Kernfunktion (MVP) absolut notwendig?"
- **Backlog-Pflicht:** Wenn die Antwort "Nein" ist oder es sich um ein "Nice-to-have"-Feature handelt, verschiebst du die Aufgabe sofort und unaufgefordert in den Bereich "Backlog / Zukünftige Ausbaustufen" der `todo.md`. Arbeite nur an MVP-Aufgaben!

## Zentrale To-Do Liste (`todo.md`)
- Jede Aufgabe muss in der `todo.md` dokumentiert sein.
- **Granularität:** Große Aufgaben MÜSSEN rekursiv in Teilaufgaben zerlegt werden, bis sie einzeln umsetzbar sind.
- **Status-Workflow:** Jede Aufgabe darf nur einen dieser Stati haben:
  1. `Todo`: Aufgabe ist definiert, aber noch nicht gestartet.
  2. `Branch Open`: Ein Feature-Branch wurde erstellt und die Entwicklung läuft.
  3. `E2E Check`: Der Code ist fertig, E2E-Tests gegen den VPS laufen gerade.
  4. `Merged`: E2E-Tests waren erfolgreich, der Branch wurde in `main` integriert.

## Git-Regeln
- **Main-Branch:** Enthält nur fertigen, getesteten Code und Architektur-Konzepte.
- **Feature-Branches:** Jede technische Umsetzung findet auf einem eigenen Branch statt.
- **Merge-Bedingung:** Ein Merge in den `main` passiert NUR nach erfolgreichem E2E-Test inkl. Log-Prüfung.
