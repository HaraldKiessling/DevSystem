# Tailscale Authentifizierungsmethoden - Vergleich

Detaillierter Vergleich der beiden Authentifizierungsmethoden für Tailscale in GitHub Actions.

## 📊 Schnellvergleich

| Kriterium | Auth Key ⭐ | OAuth Client |
|-----------|------------|--------------|
| **Setup-Zeit** | ~5 Minuten | ~10 Minuten |
| **Anzahl Secrets** | 1 | 2 |
| **Browser-Schritte** | 1 | 1 |
| **Ablaufdatum** | Ja (konfigurierbar) | Nein |
| **Wartungsaufwand** | Mittel (periodisch) | Niedrig (einmalig) |
| **Empfohlen für** | Entwicklung, QS, Testing | Produktion, Langzeit |
| **Automatisierbar** | ✅ Vollständig | ✅ Vollständig |

## 🔑 Methode 1: Auth Key (Empfohlen für QS)

### Vorteile

✅ **Einfacher Setup**
- Nur ein Secret erforderlich (`TAILSCALE_OAUTH_SECRET`)
- Ein Schritt im Browser
- Schneller konfiguriert

✅ **Automatische Bereinigung**
- Ephemeral Keys entfernen Nodes automatisch
- Keine dauerhaften Geräte im Tailnet
- Ideal für CI/CD Runner

✅ **Feingranulare Kontrolle**
- Ablaufdatum selbst bestimmen (z.B. 90 Tage)
- Tags für ACL-Zuordnung
- Preauthorization möglich

✅ **Sicherheit**
- Keys können jederzeit widerrufen werden
- Automatische Rotation möglich
- Ephemeral = keine Überbleibsel

### Nachteile

⚠️ **Periodische Wartung**
- Auth Keys laufen nach konfigurierter Zeit ab
- Erneuerung erforderlich (z.B. alle 90 Tage)
- Muss vor Ablauf erfolgen

⚠️ **Manuelle Rotation**
- Key-Erneuerung erfordert manuelle Schritte
- Secret muss manuell aktualisiert werden

### Setup-Prozess

1. **Generieren** (Browser): `https://login.tailscale.com/admin/settings/keys`
2. **Konfigurieren**:
   - Reusable: JA
   - Ephemeral: JA
   - Preauthorized: JA
   - Expiry: 90 days
3. **Secret setzen**: `gh secret set TAILSCALE_OAUTH_SECRET`

### Verwendung in GitHub Actions

```yaml
- name: Setup Tailscale
  uses: tailscale/github-action@v2
  with:
    oauth-secret: ${{ secrets.TAILSCALE_OAUTH_SECRET }}
    tags: tag:ci
```

Die Action erkennt automatisch, dass es ein Auth Key ist (beginnt mit `tskey-auth-`).

### Wartung

```bash
# Alle 90 Tage (oder vor Ablauf)
# 1. Neuen Key generieren
# 2. Secret updaten
gh secret set TAILSCALE_OAUTH_SECRET --repo HaraldKiessling/DevSystem

# 3. Testen
gh workflow run deploy-qs-vps.yml
```

## 🔐 Methode 2: OAuth Client

### Vorteile

✅ **Permanente Lösung**
- Kein Ablaufdatum
- Einmaliges Setup
- Keine periodische Wartung

✅ **Professionell**
- OAuth-Standard
- Empfohlen von Tailscale
- Bessere Auditierung

✅ **Feingranulare Berechtigungen**
- Scopes definierbar
- Zugriff auf Tailscale API
- Erweiterte Funktionen

### Nachteile

⚠️ **Komplexerer Setup**
- Zwei Secrets erforderlich
- Mehr Konfigurationsschritte
- OAuth-Verständnis hilfreich

⚠️ **Mehr Secrets zu verwalten**
- `TAILSCALE_OAUTH_CLIENT_ID`
- `TAILSCALE_OAUTH_SECRET`
- Beide müssen synchron gehalten werden

⚠️ **Keine automatische Bereinigung**
- Nodes bleiben im Tailnet
- Manuelle Bereinigung erforderlich
- Kann zu vielen inaktiven Nodes führen

### Setup-Prozess

1. **Generieren** (Browser): `https://login.tailscale.com/admin/settings/oauth`
2. **Konfigurieren**:
   - Name: GitHub Actions - DevSystem
   - Scopes: devices:write
3. **Secrets setzen**:
   ```bash
   gh secret set TAILSCALE_OAUTH_CLIENT_ID
   gh secret set TAILSCALE_OAUTH_SECRET
   ```

### Verwendung in GitHub Actions

```yaml
- name: Setup Tailscale
  uses: tailscale/github-action@v2
  with:
    oauth-client-id: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID }}
    oauth-secret: ${{ secrets.TAILSCALE_OAUTH_SECRET }}
    tags: tag:ci
```

### Wartung

```bash
# Optional: OAuth Client erneuern
# (normalerweise nicht erforderlich)

# Alte Nodes bereinigen (manuell)
# https://login.tailscale.com/admin/machines
# Inaktive GitHub Actions Runner entfernen
```

## 🎯 Empfehlungen nach Use Case

### Entwicklung & Testing
**→ Auth Key** ⭐
- Schneller Setup
- Automatische Bereinigung
- Einfache Key-Rotation

### QS-Umgebung
**→ Auth Key** ⭐
- Periodische Rotation ist akzeptabel
- Ephemeral Nodes ideal für Tests
- Weniger Wartung der Node-Liste

### Produktion
**→ OAuth Client**
- Keine Ausfallzeiten durch abgelaufene Keys
- Permanente Lösung
- Professioneller Ansatz

### Persönliche Projekte
**→ Auth Key** ⭐
- Minimaler Aufwand
- Ausreichende Sicherheit
- Einfache Verwaltung

### Enterprise/Team
**→ OAuth Client**
- Zentrale Verwaltung
- Audit-Trail
- Langfristige Stabilität

## 🔄 Migration zwischen Methoden

### Von OAuth zu Auth Key

```bash
# 1. Auth Key generieren
# 2. TAILSCALE_OAUTH_CLIENT_ID löschen
gh secret delete TAILSCALE_OAUTH_CLIENT_ID --repo HaraldKiessling/DevSystem

# 3. TAILSCALE_OAUTH_SECRET mit Auth Key überschreiben
gh secret set TAILSCALE_OAUTH_SECRET --repo HaraldKiessling/DevSystem
```

### Von Auth Key zu OAuth

```bash
# 1. OAuth Client erstellen
# 2. TAILSCALE_OAUTH_CLIENT_ID setzen
gh secret set TAILSCALE_OAUTH_CLIENT_ID --repo HaraldKiessling/DevSystem

# 3. TAILSCALE_OAUTH_SECRET mit OAuth Secret überschreiben
gh secret set TAILSCALE_OAUTH_SECRET --repo HaraldKiessling/DevSystem
```

## 📈 Kosten-Nutzen-Analyse

### Auth Key

| Aspekt | Wert |
|--------|------|
| Setup-Zeit | 5 Minuten |
| Wartung/Jahr | ~30 Minuten (4x Rotation) |
| Komplexität | Niedrig |
| Fehleranfälligkeit | Mittel (Ablauf vergessen) |
| **Gesamt/Jahr** | ~35 Minuten |

### OAuth Client

| Aspekt | Wert |
|--------|------|
| Setup-Zeit | 10 Minuten |
| Wartung/Jahr | ~5 Minuten (Node-Cleanup) |
| Komplexität | Mittel |
| Fehleranfälligkeit | Niedrig |
| **Gesamt/Jahr** | ~15 Minuten |

## 🔒 Sicherheitsaspekte

### Auth Key

- ✅ Automatische Ablaufdaten
- ✅ Ephemeral Nodes (keine Spuren)
- ✅ Einfache Rotation
- ⚠️ Key kann kompromittiert werden (bis Ablauf)

### OAuth Client

- ✅ Permanente Credentials (bei guter Verwaltung)
- ✅ Feingranulare Scopes
- ✅ OAuth-Standard
- ⚠️ Permanente Credentials (bei schlechter Verwaltung)
- ⚠️ Nodes bleiben im Tailnet

## 📚 Best Practices

### Auth Key

1. **Ablaufdatum kalendarisieren**
   - Reminder setzen (z.B. 80 Tage)
   - Vor Ablauf erneuern

2. **Rotation automatisieren**
   - Skript für Erneuerung
   - CI/CD für Secret-Update

3. **Ephemeral bevorzugen**
   - Automatische Bereinigung
   - Weniger Node-Clutter

### OAuth Client

1. **Secrets sicher speichern**
   - Niemals in Code committen
   - Password Manager verwenden

2. **Regelmäßig Nodes bereinigen**
   - Monatliches Cleanup
   - Inaktive Runner entfernen

3. **Scopes minimal halten**
   - Nur erforderliche Berechtigungen
   - Principle of Least Privilege

## 🎓 Fazit

**Für DevSystem QS-Umgebung:**
→ **Auth Key Methode empfohlen** ⭐

**Gründe:**
- Schneller Setup (5 Minuten)
- Nur ein Secret
- Automatische Node-Bereinigung
- Periodische Rotation ist akzeptabel
- Einfacher zu verstehen und zu warten

**Ausnahme:**
Falls Workflow täglich läuft und manuelle Wartung vermieden werden soll, ist OAuth Client die bessere Wahl.

## 📖 Weitere Ressourcen

- [Tailscale Auth Keys Dokumentation](https://tailscale.com/kb/1085/auth-keys/)
- [Tailscale OAuth Clients Dokumentation](https://tailscale.com/kb/1215/oauth-clients/)
- [Tailscale GitHub Action](https://github.com/tailscale/github-action)
- [Quick Start Guide](QUICK-START-TAILSCALE-GITHUB.md)
- [Vereinfachter Setup](TAILSCALE-GITHUB-SETUP-SIMPLIFIED.md)
