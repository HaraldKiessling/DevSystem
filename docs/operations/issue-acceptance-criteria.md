# Acceptance Criteria Guidelines

## 📚 Related Documentation
- [Issue Guidelines](issue-guidelines.md) - Kernkonzepte & Prozesse
- [Issue Examples](issue-examples.md) - Templates & Beispiele
- [Feature Workflow](./feature-workflow.md) - Gesamter Feature-Workflow

## Übersicht

Dieses Dokument beschreibt das Framework für die Erstellung von qualitativ hochwertigen Acceptance Criteria (AC). Gute AC sind der Schlüssel zu erfolgreichen Feature-Implementierungen und effizientem Testing.

Für vollständige Issue-Beispiele siehe [issue-examples.md](issue-examples.md).

---

## ✅ Was sind gute Acceptance Criteria?

### Definition

Acceptance Criteria definieren die Bedingungen, unter denen ein Feature als "fertig" gilt. Sie sind die Basis für:
- **Testing:** Was muss getestet werden?
- **Code-Review:** Ist alles implementiert?
- **Definition of Done:** Wann ist das Issue abgeschlossen?

### Eigenschaften guter AC

**INVEST-Prinzipien angewendet auf AC:**

| Eigenschaft | Bedeutung | Beispiel |
|-------------|-----------|----------|
| **Independent** | Unabhängig testbar | Jedes AC kann separat geprüft werden |
| **Negotiable** | Diskutierbar | Details können verfeinert werden |
| **Valuable** | Wertorientiert | Aus User-Perspektive formuliert |
| **Estimable** | Schätzbar | Effort ist erkennbar |
| **Small** | Kompakt | 2-15 AC pro Issue |
| **Testable** | Testbar | Pass/Fail eindeutig prüfbar |

**Kern-Eigenschaften:**
- ✅ **Testbar:** Klar prüfbar (Pass/Fail)
- ✅ **Specific:** Konkret, nicht vage
- ✅ **Measurable:** Messbare Kriterien
- ✅ **User-Focused:** Aus User-Perspektive
- ✅ **Complete:** Alle wichtigen Aspekte abdecken

---

## 📝 AC-Format & Schreibstil

### Empfohlenes Format

**Option 1: User-Story-Format**
```markdown
- [ ] AC1: [Aktor] kann [Aktion] durchführen und [Ergebnis] sehen
```

**Option 2: Conditional-Format**
```markdown
- [ ] AC2: Wenn [Bedingung], dann [Verhalten]
```

**Option 3: Quality-Format**
```markdown
- [ ] AC3: [Feature] erfüllt [Qualitätskriterium]
```

### Schreibregeln

**DO's ✅:**
- Imperativ verwenden: "User kann...", nicht "User könnte..."
- Konkrete Werte angeben: "< 3 Sekunden", nicht "schnell"
- Messbare Kriterien: "4.5:1 Kontrast", nicht "gut lesbar"
- Alle Edge Cases abdecken
- Verhalten beschreiben, nicht Implementation
- Nummerieren für Tracking: AC1, AC2, AC3...

**DON'Ts ❌:**
- Vage Begriffe: "gut", "schön", "schnell"
- Implementation Details: "Redis-Cache verwenden"
- Nicht-testbare Aussagen: "User sind zufrieden"
- Redundanz vermeiden
- Zu technisch formulieren

---

## 🎯 AC nach Issue-Typ

### Feature-AC

**Fokus:** Funktionalität, User-Experience, Business-Value

**Struktur:**
```markdown
## ✅ Acceptance Criteria

### Funktionale Anforderungen
- [ ] AC1-ACN: Core-Funktionalität

### User Experience
- [ ] ACN+1: UI/UX-Anforderungen

### Performance & Quality
- [ ] ACN+2: Non-funktionale Anforderungen
```

**Beispiel:**
```markdown
- [ ] AC1: User kann in Settings zwischen Light/Dark/Auto Mode wählen
- [ ] AC2: Gewählter Mode wird persistent gespeichert
- [ ] AC3: UI-Komponenten passen Farben korrekt an
- [ ] AC4: Transition erfolgt smooth (max. 300ms)
- [ ] AC5: Farbkontrast erfüllt WCAG 2.1 AA (min. 4.5:1)
```

### Bug-AC

**Fokus:** Fehlerbehebung, Reproduktion verhindert, keine Regression

**Struktur:**
```markdown
## ✅ Acceptance Criteria

### Bug-Fix
- [ ] AC1: Original-Problem ist behoben

### Verification
- [ ] AC2: Reproduktionsschritte schlagen fehl (Bug nicht mehr vorhanden)

### Regression Prevention
- [ ] AC3: Keine neuen Probleme entstanden
```

**Beispiel:**
```markdown
- [ ] AC1: Token-Lebensdauer wird von 5min auf 30min erhöht
- [ ] AC2: Token-Refresh erfolgt automatisch 5min vor Ablauf
- [ ] AC3: User wird bei Inaktivität > 24h ausgeloggt (Security)
- [ ] AC4: Reproduktionsschritte aus Bug-Report schlagen fehl
- [ ] AC5: Bestehende Auth-Tests bleiben grün
```

### Documentation-AC

**Fokus:** Vollständigkeit, Klarheit, Wartbarkeit

**Struktur:**
```markdown
## ✅ Acceptance Criteria

- [ ] AC1: Alle Abschnitte sind korrekt und vollständig
- [ ] AC2: Code-Beispiele funktionieren
- [ ] AC3: Links sind valide
- [ ] AC4: Bilder/Diagramme sind aktuell
```

### Refactoring-AC

**Fokus:** Code-Qualität, keine funktionalen Änderungen, Tests bleiben grün

**Struktur:**
```markdown
## ✅ Acceptance Criteria

- [ ] AC1: Code-Qualität verbessert (messbare Metriken)
- [ ] AC2: Keine funktionalen Änderungen
- [ ] AC3: Alle bestehenden Tests bleiben grün
- [ ] AC4: Performance gleich oder besser
```

---

## 📊 Anzahl & Umfang

### Richtwerte

| Issue-Größe | Effort | AC-Anzahl | Hinweis |
|-------------|--------|-----------|---------|
| **Klein** | 1-3 | 2-4 AC | Quick wins |
| **Mittel** | 4-6 | 4-8 AC | Standard-Features |
| **Groß** | 7-10 | 8-15 AC | Ggf. aufteilen! |

### Zu wenige AC

**Problem:** Feature zu vage definiert

**Symptome:**
- Nur 1-2 AC für komplexes Feature
- AC wie "Feature funktioniert"
- Wichtige Aspekte fehlen (Error-Handling, Edge Cases)

**Lösung:**
- User-Journey durchdenken
- Edge Cases identifizieren
- Non-funktionale Anforderungen ergänzen

### Zu viele AC

**Problem:** Feature zu groß

**Symptome:**
- >15 AC für ein Issue
- AC überschneiden sich
- Mehrere logische Feature-Bereiche vermischt

**Lösung:**
- Issue in kleinere Teile aufteilen
- Phase 1, Phase 2, Phase 3 erstellen
- Core vs. Enhancement trennen

---

## 🎭 AC vs. Implementation Details

### Was gehört in AC?

**AC beschreiben WAS, nicht WIE:**

| ✅ Richtig (AC) | ❌ Falsch (Implementation) |
|-----------------|----------------------------|
| User kann Passwort zurücksetzen | SendGrid API mit Template ID 123 aufrufen |
| Email wird in < 5 Sekunden versendet | Redis-Cache für Queue verwenden |
| Daten werden persistent gespeichert | PostgreSQL-Tabelle `users` anlegen |
| Validierung erfolgt clientseitig | Yup-Schema verwenden |

### Wo gehören Implementation Details hin?

**Im Issue-Body, nicht in AC:**

```markdown
## Implementation Notes

Technical approach:
- Use SendGrid API for email delivery
- Redis queue for async processing
- PostgreSQL for user data
- Yup for validation schema

## Technical Constraints

- Must support 1000 concurrent users
- Database migration required
- API backward-compatibility needed
```

---

## 🧪 Testability Requirements

### AC müssen testbar sein

**Jedes AC sollte beantworten:**
1. **Wer** testet? (User, QA, Developer, Automated)
2. **Was** wird getestet? (Funktion, Verhalten, Quality)
3. **Wie** wird Pass/Fail bestimmt? (Messbare Kriterien)

### Test-Kategorien

**Functional Testing:**
```markdown
- [ ] AC1: User kann Feature X ausführen
  → Manual Test: Click-Through-Test
  → Automated: E2E-Test erstellen
```

**Performance Testing:**
```markdown
- [ ] AC2: API antwortet in < 200ms (p95)
  → Automated: Load-Test mit k6
```

**Accessibility Testing:**
```markdown
- [ ] AC3: Kontrast erfüllt WCAG 2.1 AA (min. 4.5:1)
  → Automated: Lighthouse-Test
```

**Security Testing:**
```markdown
- [ ] AC4: XSS-Injection wird verhindert
  → Manual: Penetration-Test
  → Automated: Security-Scan
```

---

## 🚦 Definition of Done

### AC als Teil der DoD

**Ein Issue ist "Done", wenn:**
1. ✅ **Alle AC erfüllt** (Pass-Status)
2. ✅ **Tests geschrieben & grün** (Coverage)
3. ✅ **Code-Review approved** (Quality)
4. ✅ **Docs aktualisiert** (Completeness)
5. ✅ **Deployed & verifiziert** (Production-ready)

### AC-Tracking

**GitHub-Checkboxen nutzen:**
```markdown
## ✅ Acceptance Criteria

- [x] AC1: Feature X funktioniert ← Completed
- [x] AC2: Performance < 200ms ← Completed
- [ ] AC3: Accessibility WCAG AA ← In Progress
- [ ] AC4: Docs aktualisiert ← Pending
```

**Issue-Progress sichtbar machen:**
- GitHub zeigt "2 of 4 tasks completed"
- Stakeholder können Fortschritt tracken
- Pull Request kann AC referenzieren

---

## 🎓 Best Practices

### 1. User-Perspektive einnehmen

❌ **Technisch:**
```markdown
- [ ] POST /api/users Endpoint erstellt
```

✅ **User-Focused:**
```markdown
- [ ] User kann Account erstellen und erhält Bestätigungs-Email
```

### 2. Messbare Kriterien verwenden

❌ **Vage:**
```markdown
- [ ] Seite lädt schnell
```

✅ **Messbar:**
```markdown
- [ ] Seite lädt in < 2 Sekunden (p95, 3G-Netzwerk)
```

### 3. Edge Cases nicht vergessen

❌ **Nur Happy Path:**
```markdown
- [ ] User kann sich einloggen
```

✅ **Mit Edge Cases:**
```markdown
- [ ] AC1: User kann sich mit validen Credentials einloggen
- [ ] AC2: Invalid Credentials zeigen Fehlermeldung
- [ ] AC3: Nach 3 Fehlversuchen wird Account für 15min gesperrt
- [ ] AC4: Passwort-Vergessen-Link ist sichtbar
```

### 4. Dependency-AC kennzeichnen

```markdown
- [ ] AC1: Feature X funktioniert (depends on #42)
- [ ] AC2: Integration mit Service Y (blocked by external API)
```

### 5. AC priorisieren

**Must-Have vs. Nice-to-Have:**
```markdown
## ✅ Acceptance Criteria (Must-Have)
- [ ] AC1: Core-Funktionalität
- [ ] AC2: Error-Handling

## 🎁 Enhancement Criteria (Nice-to-Have)
- [ ] EC1: Animation polish
- [ ] EC2: Advanced filters
```

---

## 🔍 Häufige Fehler vermeiden

### ❌ Fehler 1: Vage Formulierungen

**Problem:**
```markdown
- [ ] Feature funktioniert gut
- [ ] UI ist schön
- [ ] User sind zufrieden
```

**Lösung:**
```markdown
- [ ] User kann Feature X in ≤3 Klicks erreichen
- [ ] UI erfüllt WCAG 2.1 AA Standard (Kontrast min. 4.5:1)
- [ ] User-Satisfaction-Score ≥4.5/5 im Beta-Testing
```

### ❌ Fehler 2: Implementation statt Verhalten

**Problem:**
```markdown
- [ ] Redis-Cache implementiert
- [ ] PostgreSQL-Migration erstellt
```

**Lösung:**
```markdown
- [ ] Daten werden persistent gespeichert und nach Reload verfügbar
- [ ] Performance ist < 200ms auch bei 1000 concurrent users
```

### ❌ Fehler 3: Nicht testbare AC

**Problem:**
```markdown
- [ ] Code ist wartbar
- [ ] Architektur ist sauber
```

**Lösung:**
```markdown
- [ ] Code-Coverage ≥80% (gemessen mit Jest)
- [ ] Cyclomatic Complexity ≤10 (gemessen mit ESLint)
- [ ] Keine Code-Duplication >10 LOC (gemessen mit SonarQube)
```

### ❌ Fehler 4: AC ohne Kontext

**Problem:**
```markdown
- [ ] Button funktioniert
- [ ] Validation ist implementiert
```

**Lösung:**
```markdown
- [ ] "Submit"-Button sendet Formular und zeigt Success-Message
- [ ] Email-Validation verhindert Submit bei invalider Email und zeigt Fehler
```

---

## 📖 Weiterführende Ressourcen

**Projekt-Dokumentation:**
- [Issue Guidelines](issue-guidelines.md) - Issue-Erstellung & Management
- [Issue Examples](issue-examples.md) - Vollständige Issue-Templates
- [Feature Workflow](./feature-workflow.md) - End-to-End-Prozess

**Externe Referenzen:**
- [INVEST Criteria](https://en.wikipedia.org/wiki/INVEST_(mnemonic)) - User Story Best Practices
- [Behavior-Driven Development (BDD)](https://cucumber.io/docs/bdd/) - Given-When-Then Format
- [WCAG Guidelines](https://www.w3.org/WAI/WCAG21/quickref/) - Accessibility Standards
- [User Story Mapping](https://www.jpattonassociates.com/user-story-mapping/) - Feature-Dekomposition

---

**Version:** 1.0  
**Letzte Aktualisierung:** 2026-04-12  
**Maintainer:** DevSystem Team
