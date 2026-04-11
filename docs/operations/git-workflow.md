# Git-Workflow für das DevSystem-Projekt

Dieses Dokument beschreibt den Git-Workflow für das DevSystem-Projekt. Es definiert die Branch-Strategie, Commit-Richtlinien, den Merge-Prozess sowie Test- und Dokumentationsanforderungen.

## 1. Branch-Strategie

### 1.1 Branch-Typen

- **main**: Der Hauptbranch enthält die stabile Produktionsversion des Projekts. Dieser Branch sollte immer in einem funktionsfähigen Zustand sein.
- **feature**: Feature-Branches werden für die Entwicklung neuer Funktionen und Komponenten verwendet. Sie werden vom main-Branch abgezweigt und nach Fertigstellung wieder in diesen zurückgeführt.

### 1.2 Namenskonventionen für Branches

Feature-Branches sollten nach folgendem Schema benannt werden:

```
feature/<komponente>-<beschreibung>
```

Beispiele:
- `feature/tailscale-setup`
- `feature/caddy-config`
- `feature/code-server-installation`
- `feature/ollama-integration`

### 1.3 Besonderheiten

- **Konzeptentwicklung**: Konzepte werden direkt im main-Branch entwickelt und committet.
- **Feature-Entwicklung**: Echter Code und Setup-Skripte für Features werden ausschließlich in separaten Feature-Branches entwickelt.

## 2. Commit-Richtlinien

### 2.1 Aussagekräftige Commit-Nachrichten

Commit-Nachrichten sollten klar und präzise sein und folgendem Format entsprechen:

```
<typ>: <kurze beschreibung>

<detaillierte beschreibung (optional)>
```

Typen:
- `feat`: Neue Funktionalität
- `fix`: Fehlerbehebung
- `docs`: Dokumentationsänderungen
- `test`: Hinzufügen oder Ändern von Tests
- `config`: Konfigurationsänderungen
- `refactor`: Code-Refactoring ohne Funktionsänderung

Beispiele:
- `feat: Tailscale-Installation und Konfiguration hinzugefügt`
- `docs: Installationsanleitung für Caddy aktualisiert`
- `test: E2E-Tests für code-server-Zugriff implementiert`

### 2.2 Atomare Commits

- Jeder Commit sollte eine logische, in sich abgeschlossene Änderung enthalten.
- Vermeiden Sie mehrere unabhängige Änderungen in einem einzigen Commit.
- Teilen Sie große Änderungen in mehrere kleinere, logisch zusammenhängende Commits auf.

### 2.3 Referenzierung von Aufgaben

Commit-Nachrichten sollten auf die entsprechenden Aufgaben in der todo.md verweisen:

```
feat: Tailscale-Installation und Konfiguration hinzugefügt

Implementiert die Aufgabe "Tailscale VPN installieren und konfigurieren" aus todo.md
```

## 3. Merge-Prozess

### 3.1 Voraussetzungen für Merges in den main-Branch

Ein Feature-Branch darf nur unter folgenden Bedingungen in den main-Branch gemergt werden:

1. Alle E2E-Tests wurden erfolgreich durchgeführt und bestanden.
2. Die Log-Validierung wurde durchgeführt und zeigt keine Fehler.
3. Der Code wurde einem Review unterzogen und genehmigt.
4. Die Dokumentation wurde aktualisiert.

### 3.2 Code-Review-Prozess

1. Der Entwickler erstellt einen Pull Request vom Feature-Branch in den main-Branch.
2. Ein oder mehrere Teammitglieder überprüfen den Code auf:
   - Funktionalität
   - Codequalität
   - Einhaltung der Projektstandards
   - Vollständigkeit der Tests
   - Vollständigkeit der Dokumentation
3. Feedback wird gegeben und ggf. Änderungen angefordert.
4. Nach Genehmigung kann der Merge durchgeführt werden.

### 3.3 Konfliktlösung

Bei Merge-Konflikten:

1. Den main-Branch in den Feature-Branch mergen, um die Konflikte lokal zu lösen.
2. Konflikte manuell auflösen und sicherstellen, dass die Funktionalität erhalten bleibt.
3. Nach der Konfliktlösung erneut alle Tests durchführen.
4. Den aktualisierten Feature-Branch pushen und den Merge-Prozess fortsetzen.

## 4. Testanforderungen

### 4.1 Tests vor einem Merge

Vor einem Merge in den main-Branch müssen folgende Tests erfolgreich durchgeführt werden:

1. **E2E-Tests**: Live-Tests gegen den Ubuntu VPS, die die Funktionalität der implementierten Features überprüfen.
2. **Integrationstests**: Tests, die die Interaktion zwischen verschiedenen Komponenten überprüfen.
3. **Sicherheitstests**: Überprüfung auf potenzielle Sicherheitslücken.

### 4.2 Validierung von Log-Einträgen

- Alle Tests müssen explizit auf korrekte Log-Ausgaben der jeweiligen Dienste prüfen.
- Log-Einträge sollten auf Fehler, Warnungen und unerwartetes Verhalten überprüft werden.
- Die Log-Validierung muss dokumentiert werden.

## 5. Dokumentationsanforderungen

### 5.1 Aktualisierung der todo.md

- Nach Abschluss einer Aufgabe muss der Status in der todo.md aktualisiert werden.
- Neue Aufgaben, die während der Entwicklung identifiziert werden, müssen in die todo.md aufgenommen werden.
- Die Statusänderung einer Aufgabe muss im Commit dokumentiert werden.

### 5.2 Aktualisierung von Konzeptdokumenten

- Konzeptdokumente müssen aktuell gehalten werden und die tatsächliche Implementierung widerspiegeln.
- Bei Änderungen an der Architektur oder dem Design müssen die entsprechenden Dokumente aktualisiert werden.
- Neue Erkenntnisse oder Entscheidungen müssen dokumentiert werden.

## 6. Workflow-Diagramm

```mermaid
graph TD
    A[Start: Neue Aufgabe] --> B{Konzept oder Code?}
    B -->|Konzept| C[Direkt in main entwickeln]
    B -->|Code/Setup| D[Feature-Branch erstellen]
    D --> E[Implementierung]
    E --> F[Tests schreiben]
    F --> G[E2E-Tests durchführen]
    G --> H[Log-Validierung]
    H --> I[Code-Review]
    I --> J{Review bestanden?}
    J -->|Nein| E
    J -->|Ja| K[In main mergen]
    C --> L[Dokumentation aktualisieren]
    K --> L
    L --> M[Aufgabenstatus aktualisieren]
    M --> N[Ende]

---

## 7. Branch-Management & Cleanup

### 7.1 Wann sollte ein Branch gelöscht werden?

Ein Feature-Branch sollte **sofort nach erfolgreichem Merge** gelöscht werden:

**Lokal löschen:**
```bash
git branch -d feature/name    # Safe delete (nur wenn gemergt)
git branch -D feature/name    # Force delete
```

**Remote löschen:**
```bash
git push origin --delete feature/name
```

### 7.2 Periodischer Branch-Cleanup

**Empfehlung:** Monatlicher oder quartalsweiser Cleanup aller gemergter Branches.

**Cleanup-Workflow:**

1. **Analysiere verbleibende Branches:**
   ```bash
   git branch -a
   git log main..feature/branch-name --oneline
   ```

2. **Prüfe ob vollständig gemergt:**
   ```bash
   git diff main..feature/branch-name
   ```

3. **Lösche lokale Branches:**
   ```bash
   git branch -d feature/branch-1
   git branch -d feature/branch-2
   ```

4. **Lösche Remote-Branches:**
   ```bash
   git push origin --delete feature/branch-1
   git push origin --delete feature/branch-2
   ```

5. **Räume Remote-Referenzen auf:**
   ```bash
   git remote prune origin
   git fetch --prune
   ```

6. **Verifiziere Ergebnis:**
   ```bash
   git branch -a
   ```
   Erwartetes Ergebnis: Nur `main` Branch (lokal + remote)

### 7.3 GitHub Branch Protection & Automatisierung

**Empfohlene GitHub Settings:**

1. **Branch Protection Rules für `main`:**
   - Settings → Branches → Add rule
   - Pattern: `main`
   - ✅ Require pull request reviews before merging
   - ✅ Require status checks to pass before merging
   - ✅ Require branches to be up to date before merging

2. **Automatisches Branch-Cleanup:**
   - Settings → General → "Pull Requests"
   - ✅ Automatically delete head branches
   - Löscht Feature-Branches automatisch nach Merge

3. **Default Branch korrekt setzen:**
   - Settings → General → "Default branch"
   - Muss immer `main` sein
   - **NIEMALS** ein Feature-Branch als Default

### 7.4 Troubleshooting: Branch kann nicht gelöscht werden

**Problem:** `refusing to delete the current branch`

**Ursache:** Branch ist noch als Default-Branch auf GitHub konfiguriert.

**Lösung:**
1. Öffne: `https://github.com/USER/REPO/settings`
2. Navigiere zu "Default branch"
3. Ändere zu `main`
4. Versuche Löschung erneut

### 7.5 Best Practices

✅ **DOs:**
- Feature-Branches sofort nach Merge löschen
- Kurze Lebensdauer von Feature-Branches (Tage, nicht Wochen)
- Regelmäßiger Branch-Cleanup (monatlich/quartalsweise)
- Klare Namenskonventionen einhalten
- Automatisches Branch-Cleanup auf GitHub aktivieren

❌ **DON'Ts:**
- Branches "vergessen" nach Merge
- Lange lebende Feature-Branches (>2 Wochen)
- Feature-Branch als Default-Branch verwenden
- Branches ohne Analyse löschen
- Branches löschen die noch ungemergte Commits haben

### 7.6 Branch-Cleanup Checklist

Bei jedem Cleanup:

- [ ] Alle Branches mit `git branch -a` listen
- [ ] Für jeden Branch: Commits mit main vergleichen
- [ ] Für jeden Branch: Änderungen mit `git diff` prüfen
- [ ] Unfertige Aufgaben in `todo.md` dokumentieren
- [ ] Lokale Branches löschen (`git branch -d`)
- [ ] Remote-Branches löschen (`git push origin --delete`)
- [ ] Remote-Referenzen aufräumen (`git remote prune origin`)
- [ ] Ergebnis verifizieren (`git branch -a`)
- [ ] Cleanup-Report erstellen
- [ ] GitHub Default-Branch auf `main` prüfen

---

## 8. Lessons Learned aus Branch-Cleanup (2026-04-10)

**Situation:** 8 Branches (1 main + 7 feature) aufgeräumt

**Erkenntnisse:**
1. ✅ Alle Feature-Branches waren vollständig gemergt
2. ✅ Keine Datenverluste durch systematische Analyse
3. ⚠️ GitHub Default-Branch war fälschlicherweise auf Feature-Branch gesetzt
4. ⚠️ Branches wurden nicht zeitnah nach Merge gelöscht

**Empfehlungen für die Zukunft:**
1. **Sofortige Löschung:** Branches direkt nach erfolgreichem Merge löschen
2. **GitHub Automation:** "Automatically delete head branches" aktivieren
3. **Default Branch:** Regelmäßig prüfen dass Default auf `main` steht
4. **Dokumentation:** Cleanup-Prozess im Workflow verankern
5. **Prävention:** Single-Purpose-Branches mit kurzer Lebensdauer

**Erfolgsrate:** 87,5% (7 von 8 Branches gelöscht, 1 manueller Schritt nötig)

Siehe vollständigen Report: [`GIT-BRANCH-CLEANUP-REPORT.md`](GIT-BRANCH-CLEANUP-REPORT.md)