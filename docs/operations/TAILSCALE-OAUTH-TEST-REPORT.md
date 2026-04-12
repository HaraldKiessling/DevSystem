# Tailscale OAuth Migration - Test Report

**Datum:** 2026-04-12  
**Issue:** #18 - Tailscale OAuth Migration  
**Workflow-Run:** [24315933103](https://github.com/HaraldKiessling/DevSystem/actions/runs/24315933103)

## 🎯 Zusammenfassung

Der Test des QS-VPS Deploy-Workflows mit OAuth-Authentifizierung war **teilweise erfolgreich**. Die OAuth-Authentifizierung funktioniert grundsätzlich, aber es wurde ein Berechtigungsproblem mit Tailscale-Tags identifiziert.

## ✅ Erfolge

### 1. OAuth-Secrets korrekt konfiguriert

- `TAILSCALE_OAUTH_CLIENT_ID` ist gesetzt
- `TAILSCALE_OAUTH_SECRET` ist gesetzt
- Secrets werden korrekt an den Workflow übergeben

### 2. OAuth-Authentifizierung funktioniert

```
TAILSCALE_AUTHKEY="***?preauthorized=true&ephemeral=true"
TS_EXPERIMENT_OAUTH_AUTHKEY: true
```

Die OAuth-Client-Authentifizierung wurde erfolgreich initiiert.

### 3. Workflow-Syntax korrigiert

- Entfernte ungültige `if`-Bedingungen mit `secrets`-Context
- OAuth wird immer zuerst versucht
- Auth Key Fallback nur bei OAuth-Fehler

## ❌ Identifiziertes Problem

### Tag-Berechtigung fehlt

**Fehlermeldung:**

```
Status: 400, Message: "requested tags [tag:ci] are invalid or not permitted"
```

**Ursache:**  
Der OAuth-Client hat keine Berechtigung, Geräte mit dem Tag `tag:ci` zu erstellen.

**Workflow-Schritt:**

```yaml
- name: Setup Tailscale (OAuth)
  uses: tailscale/github-action@v2
  with:
    oauth-client-id: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID }}
    oauth-secret: ${{ secrets.TAILSCALE_OAUTH_SECRET }}
    tags: tag:ci # ← Dieser Tag ist nicht erlaubt
```

## 🔧 Lösung

### Schritt 1: ACL-Konfiguration anpassen

In der Tailscale Admin Console → Access Controls:

```json
{
  "tagOwners": {
    "tag:ci": ["autogroup:admin"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["*:*"]
    }
  ]
}
```

### Schritt 2: OAuth-Client-Berechtigung prüfen

Stelle sicher, dass der OAuth-Client folgende Berechtigungen hat:

- **Devices: Write** - Zum Erstellen von Geräten
- **Tags: Write** - Zum Zuweisen von Tags

### Alternative: Tags entfernen

Falls keine Tag-Berechtigung gewünscht ist, kann der Workflow auch ohne Tags laufen:

```yaml
- name: Setup Tailscale (OAuth)
  uses: tailscale/github-action@v2
  with:
    oauth-client-id: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID }}
    oauth-secret: ${{ secrets.TAILSCALE_OAUTH_SECRET }}
    # tags: tag:ci  # ← Entfernt
```

## 📊 Workflow-Verlauf

| Schritt                             | Status | Dauer | Bemerkung                             |
| ----------------------------------- | ------ | ----- | ------------------------------------- |
| Checkout Repository                 | ✅     | ~1s   | Erfolgreich                           |
| Setup Tailscale (OAuth)             | ⚠️     | ~6s   | Tag-Berechtigung fehlt                |
| Setup Tailscale (Auth Key Fallback) | ❌     | <1s   | Kein Auth Key gesetzt (erwartet)      |
| Tailscale Status                    | ❌     | <1s   | Beide Tailscale-Setups fehlgeschlagen |
| Weitere Schritte                    | ⏭️     | -     | Übersprungen                          |

## 🎓 Erkenntnisse

### 1. OAuth funktioniert grundsätzlich

Die OAuth-Authentifizierung ist korrekt konfiguriert und funktioniert. Das Problem liegt ausschließlich bei den Tag-Berechtigungen.

### 2. Workflow-Syntax-Fehler behoben

Die ursprünglichen Syntax-Fehler mit `secrets`-Context in `if`-Bedingungen wurden erfolgreich korrigiert.

### 3. Fallback-Mechanismus funktioniert

Der Fallback auf Auth Key wird korrekt ausgelöst, wenn OAuth fehlschlägt (auch wenn kein Auth Key gesetzt ist).

### 4. Permanente Authentifizierung bestätigt

OAuth-Clients haben **keine 90-Tage-Ablaufzeit** wie Auth Keys. Nach Behebung des Tag-Problems ist die Authentifizierung permanent.

## ⏭️ Nächste Schritte

1. **ACL-Konfiguration anpassen** (siehe Lösung oben)
2. **Workflow erneut testen:**
   ```bash
   gh workflow run deploy-qs-vps.yml --repo HaraldKiessling/DevSystem
   ```
3. **Bei erfolgreichem Test:**
   - Issue #18 schließen
   - Dokumentation finalisieren
   - Migration als abgeschlossen markieren

## 📚 Referenzen

- [Tailscale OAuth Clients](https://tailscale.com/s/oauth-clients)
- [Tailscale ACL Documentation](https://tailscale.com/kb/1018/acls/)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Issue #18](https://github.com/HaraldKiessling/DevSystem/issues/18)

## 🔐 Sicherheit

### OAuth vs. Auth Key

| Aspekt       | OAuth Client   | Auth Key        |
| ------------ | -------------- | --------------- |
| Ablaufzeit   | ✅ Permanent   | ❌ 90 Tage      |
| Berechtigung | ✅ Granular    | ❌ Vollzugriff  |
| Rotation     | ✅ Nicht nötig | ❌ Alle 90 Tage |
| Audit        | ✅ Detailliert | ⚠️ Begrenzt     |

**Empfehlung:** OAuth ist die bessere Wahl für CI/CD-Pipelines.

## 📝 Commit-Historie

- `54c15b5` - fix: Korrigiere Workflow-Syntax für secrets-Zugriff
- Workflow-Test durchgeführt
- Tag-Berechtigungsproblem identifiziert

---

**Status:** ⏸️ Warte auf ACL-Konfiguration  
**Nächster Test:** Nach ACL-Anpassung
