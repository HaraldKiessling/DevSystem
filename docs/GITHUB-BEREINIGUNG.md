# GitHub-Repository Bereinigung

Dieses Dokument enthält Anweisungen zur Bereinigung des GitHub-Repositories.

## Problem: Falscher Default-Branch

Aktuell zeigt der Default-Branch (HEAD) auf `feature/vps-preparation` statt auf `main`:
```
origin/HEAD -> origin/feature/vps-preparation
```

Dies sollte korrigiert werden, damit der Default-Branch `main` ist.

## Anleitung zur Korrektur des Default-Branches

1. Gehe auf GitHub zur Repository-Hauptseite (https://github.com/HaraldKiessling/DevSystem)
2. Klicke auf "Settings" (Zahnradsymbol)
3. Scrolle runter zum Abschnitt "Default branch"
4. Ändere den Default-Branch von `feature/vps-preparation` zu `main`
5. Bestätige die Änderung im Dialog-Fenster

## Bereinigung alter Feature-Branches

Nach der Änderung des Default-Branches können die folgenden Branches bereinigt werden, da sie bereits in `main` gemergt wurden:

### Lokal zu löschende Branches:
```
git branch -d feature/caddy-setup
git branch -d feature/code-server
git branch -d feature/code-server-implementation
git branch -d feature/tailscale-setup
git branch -d feature/vps-preparation
```

### Remote zu löschende Branches:
```
git push origin --delete feature/code-server
git push origin --delete feature/code-server-setup
git push origin --delete feature/vps-preparation
```

## E2E-Tests als separaten PR einreichen

Die neuen E2E-Tests für code-server sollten als separater Pull Request eingereicht werden:

1. Stelle sicher, dass der Branch `feature/code-server-e2e-tests` aktuell ist
2. Push den Branch zum Remote-Repository:
   ```
   git push -u origin feature/code-server-e2e-tests
   ```
3. Erstelle auf GitHub einen Pull Request von `feature/code-server-e2e-tests` nach `main`
4. Füge im PR eine Beschreibung der neuen Tests und Funktionalität hinzu

## Merge-Bewertung für QS-Branches

Die folgenden Branches sollten evaluiert werden, bevor sie gelöscht werden:
- `origin/feature/qs-github-integration`
- `origin/feature/qs-system-optimization`
- `origin/feature/qs-vps-cloud-init`

## Zusammenfassung der Bereinigung

Nach Abschluss der Bereinigung sollte die Struktur wie folgt aussehen:

- `main` ist der Default-Branch
- Alte Feature-Branches wurden gelöscht
- Nur die aktiven Branches bleiben erhalten
- Neue Features werden über PRs in `main` gemergt