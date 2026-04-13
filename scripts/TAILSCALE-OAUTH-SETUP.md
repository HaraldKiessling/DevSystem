# Tailscale OAuth Setup mit ACL-Konfiguration für GitHub Actions

**Version:** 2.0  
**Stand:** 2026-04-13  
**Kontext:** Issue #18 - Tailscale OAuth Migration für CI/CD-Workflows

---

## Inhaltsverzeichnis

1. [Einleitung und Kontext](#1-einleitung-und-kontext)
2. [OAuth-Client-Erstellung in Tailscale](#2-oauth-client-erstellung-in-tailscale)
3. [ACL-Policy-Struktur und Grundlagen](#3-acl-policy-struktur-und-grundlagen)
4. [Tag-basierte Berechtigungen (tag:ci)](#4-tag-basierte-berechtigungen-tagci)
5. [Vollständige ACL-Konfiguration mit Beispielen](#5-vollständige-acl-konfiguration-mit-beispielen)
6. [Netzwerk-ACLs vs. SSH-ACLs](#6-netzwerk-acls-vs-ssh-acls)
7. [OAuth Client Berechtigungen](#7-oauth-client-berechtigungen)
8. [Häufige Fehlerquellen und Troubleshooting](#8-häufige-fehlerquellen-und-troubleshooting)
9. [Vollständiger Setup-Prozess](#9-vollständiger-setup-prozess)
10. [Spezifisch für deploy-qs-vps.yml](#10-spezifisch-für-deploy-qs-vpsyml)
11. [Sicherheitsaspekte](#11-sicherheitsaspekte)
12. [Referenzen und weitere Ressourcen](#12-referenzen-und-weitere-ressourcen)

---

## 1. Einleitung und Kontext

### 1.1 Warum OAuth statt Auth Keys?

Tailscale bietet zwei Hauptmethoden für die Authentifizierung in CI/CD-Umgebungen:

| Aspekt | Auth Keys | OAuth Client |
|--------|-----------|--------------|
| **Ablaufzeit** | ❌ 90 Tage (Standard) | ✅ Permanent |
| **Wartung** | ❌ Regelmäßige Erneuerung | ✅ Einmalig |
| **Berechtigungen** | ⚠️ Vollzugriff | ✅ Granular (Scopes) |
| **Audit-Trail** | ⚠️ Begrenzt | ✅ Detailliert |
| **Best Practice** | Entwicklung/Testing | Produktion |

**OAuth ist die empfohlene Methode für:**
- ✅ Produktionsumgebungen
- ✅ Langfristige CI/CD-Pipelines
- ✅ Automatisierte Deployments ohne manuelle Wartung
- ✅ Unternehmen mit Compliance-Anforderungen

### 1.2 Verwendung im deploy-qs-vps.yml Workflow

Der [`deploy-qs-vps.yml`](.github/workflows/deploy-qs-vps.yml) Workflow nutzt OAuth für:
- Sichere Verbindung vom GitHub Actions Runner zum Tailscale-Netzwerk
- SSH-Zugriff auf den QS-VPS über das Tailnet
- Deployment von Code und Konfigurationen
- Service-Management und Health Checks

### 1.3 Kontext zu Issue #18

**Problem:** Der initiale Workflow-Test schlug fehl mit:
```
Status: 400, Message: "requested tags [tag:ci] are invalid or not permitted"
```

**Ursache:** Der OAuth-Client hatte keine Berechtigung, Geräte mit dem Tag `tag:ci` zu erstellen, da die Tailscale ACL-Policy nicht korrekt konfiguriert war.

**Lösung:** Diese Dokumentation erklärt die vollständige Konfiguration von OAuth-Clients mit ACL-Policies für CI/CD-Workflows.

**Referenz:** [`docs/operations/TAILSCALE-OAUTH-TEST-REPORT.md`](../docs/operations/TAILSCALE-OAUTH-TEST-REPORT.md)

---

## 2. OAuth-Client-Erstellung in Tailscale

### 2.1 Schritt-für-Schritt Anleitung

#### Schritt 1: OAuth-Einstellungen öffnen

1. Navigiere zu: https://login.tailscale.com/admin/settings/oauth
2. Melde dich mit deinem Tailscale-Account an
3. Wähle das richtige Tailnet (falls mehrere vorhanden)

#### Schritt 2: OAuth Client erstellen

1. Klicke auf **"Generate OAuth Client"**
2. Gebe einen aussagekräftigen Namen ein:
   ```
   GitHub Actions - DevSystem
   ```
   oder allgemeiner:
   ```
   GitHub Actions - CI/CD
   ```

#### Schritt 3: Scopes auswählen

Wähle die erforderlichen Berechtigungen:

```
✅ devices:write
```

**Wichtig:** Der Scope `devices:write` ist **zwingend erforderlich**, um neue Geräte im Tailnet zu registrieren.

#### Schritt 4: Credentials sichern

Nach der Erstellung werden zwei Werte angezeigt:

- **OAuth Client ID** (beginnt mit `k...`)
  ```
  k1234567890abcdef1234567890abcdef
  ```

- **OAuth Client Secret** (beginnt mit `tskey-client-...`)
  ```
  tskey-client-k1234567890abcdef-1234567890abcdef1234567890abcdef
  ```

**⚠️ WICHTIG:** Das Secret wird nur **einmal** angezeigt! Speichere es sicher:
```bash
# In einem Password Manager ODER sofort als GitHub Secret
gh secret set TAILSCALE_OAUTH_CLIENT_ID --body "k..."
gh secret set TAILSCALE_OAUTH_SECRET --body "tskey-client-k..."
```

### 2.2 Erforderliche Scopes

| Scope | Zweck | Erforderlich für |
|-------|-------|------------------|
| `devices:write` | Geräte registrieren/verwalten | ✅ Ja - Ephemeral Nodes erstellen |
| `routes:write` | Routen verwalten | Nur für Subnet-Routing |
| `acl:read` | ACL-Policies lesen | Nur für Audit/Monitoring |

**Minimalkonfiguration:** Nur `devices:write` ist erforderlich.

### 2.3 Client ID und Secret Management

**Speicherung:**
```bash
# GitHub Repository Secrets (empfohlen)
gh secret set TAILSCALE_OAUTH_CLIENT_ID --repo HaraldKiessling/DevSystem
gh secret set TAILSCALE_OAUTH_SECRET --repo HaraldKiessling/DevSystem

# Organisation Secrets (für mehrere Repositories)
gh secret set TAILSCALE_OAUTH_CLIENT_ID --org YOUR_ORG
gh secret set TAILSCALE_OAUTH_SECRET --org YOUR_ORG

# Environment Secrets (für verschiedene Umgebungen)
gh secret set TAILSCALE_OAUTH_CLIENT_ID --env production
gh secret set TAILSCALE_OAUTH_SECRET --env production
```

**Sicherheitshinweise:**
- ❌ Niemals in Code committen
- ❌ Nicht in Logs ausgeben
- ✅ Nur als GitHub Secrets speichern
- ✅ In Password Manager sichern
- ✅ Rotation bei Verdacht auf Kompromittierung

---

## 3. ACL-Policy-Struktur und Grundlagen

### 3.1 Was sind ACL-Policies?

Tailscale Access Control Lists (ACLs) definieren:
- Wer auf welche Geräte zugreifen kann
- Welche Ports/Protokolle erlaubt sind
- Wer SSH-Zugriff hat
- Wer Tags verwenden darf

### 3.2 Aufbau der ACL-JSON-Datei

Die ACL-Policy ist eine JSON-Datei mit folgender Grundstruktur:

```json
{
  // Definiert, wer welche Tags verwenden darf
  "tagOwners": {
    "tag:name": ["user@example.com", "autogroup:admin"]
  },
  
  // Definiert Netzwerk-Zugriffskontrolle
  "acls": [
    {
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["*:*"]
    }
  ],
  
  // Definiert SSH-Zugriffskontrolle (optional)
  "ssh": [
    {
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["tag:server"],
      "users": ["root", "autogroup:nonroot"]
    }
  ],
  
  // Definiert Gruppen (optional)
  "groups": {
    "group:devops": ["user1@example.com", "user2@example.com"]
  },
  
  // Definiert Hosts (optional)
  "hosts": {
    "qs-vps": "100.x.x.x"
  }
}
```

### 3.3 Unterschied zwischen acls, ssh, tagOwners

#### tagOwners
**Zweck:** Definiert, wer Tags vergeben darf  
**Wichtig für:** OAuth-Clients, die getaggte Geräte erstellen

```json
"tagOwners": {
  "tag:ci": ["autogroup:admin"]
}
```
- Erlaubt Admins, den Tag `tag:ci` zu verwenden
- OAuth-Clients benötigen diese Berechtigung implizit

#### acls
**Zweck:** Definiert Netzwerk-Zugriffskontrolle  
**Wichtig für:** TCP/UDP-Verbindungen zwischen Geräten

```json
"acls": [
  {
    "action": "accept",
    "src": ["tag:ci"],
    "dst": ["*:22"]  // SSH-Port
  }
]
```

#### ssh
**Zweck:** Definiert SSH-spezifische Berechtigungen  
**Wichtig für:** SSH-Verbindungen mit Tailscale SSH

```json
"ssh": [
  {
    "action": "accept",
    "src": ["tag:ci"],
    "dst": ["tag:server"],
    "users": ["root"]
  }
]
```

### 3.4 Beziehung zu OAuth Clients

**Wichtig:** OAuth-Clients agieren im Namen des Tag-Owners!

```
OAuth Client (devices:write)
    ↓
Erstellt Gerät mit tag:ci
    ↓
tagOwners prüft: Ist autogroup:admin berechtigt?
    ↓
ACL prüft: Darf tag:ci auf Ziel zugreifen?
    ↓
SSH prüft: Darf tag:ci SSH-Zugriff auf Ziel?
```

---

## 4. Tag-basierte Berechtigungen (tag:ci)

### 4.1 Was sind Tags in Tailscale?

Tags sind Label, die Geräten zugewiesen werden, um Gruppen zu bilden:

```
Beispiel-Tailnet:
├── tag:server    → Produktionsserver
├── tag:ci        → CI/CD Runner
├── tag:dev       → Entwicklungsmaschinen
└── tag:database  → Datenbank-Server
```

**Vorteile:**
- ✅ Geräte logisch gruppieren
- ✅ Einheitliche ACL-Regeln pro Gruppe
- ✅ Keine individuellen Benutzer-Zuordnungen
- ✅ Automatische Rechtevergabe bei Tag-Zuweisung

### 4.2 Warum tag:ci für CI/CD?

| Grund | Erklärung |
|-------|-----------|
| **Isolation** | CI-Runner haben nur notwendige Berechtigungen |
| **Sicherheit** | Kein vollständiger Netzwerkzugriff |
| **Audit** | Alle CI-Zugriffe sind nachvollziehbar |
| **Skalierung** | Beliebig viele Runner mit gleichen Rechten |
| **Ephemeral** | Runner kommen und gehen, Tag bleibt gleich |

**Use Cases:**
```
GitHub Actions Runner mit tag:ci
├── Darf auf tag:server zugreifen (Deployment)
├── Darf SSH als root nutzen (Scripts ausführen)
├── Darf NICHT auf tag:database zugreifen (Least Privilege)
└── Darf NICHT auf tag:dev zugreifen (Isolation)
```

### 4.3 Tag-Owner-Konfiguration

**Minimal (nur Admins):**
```json
{
  "tagOwners": {
    "tag:ci": ["autogroup:admin"]
  }
}
```

**Mit spezifischen Benutzern:**
```json
{
  "tagOwners": {
    "tag:ci": [
      "autogroup:admin",
      "devops@example.com",
      "ci-automation@example.com"
    ]
  }
}
```

**Mit Gruppen:**
```json
{
  "groups": {
    "group:devops": ["user1@example.com", "user2@example.com"]
  },
  "tagOwners": {
    "tag:ci": ["autogroup:admin", "group:devops"]
  }
}
```

**⚠️ Häufiger Fehler:**
```json
// ❌ FALSCH - OAuth-Client kann tag:ci nicht verwenden
{
  "tagOwners": {
    "tag:ci": ["specific-user@example.com"]
  }
}

// ✅ RICHTIG - autogroup:admin erlaubt OAuth-Clients
{
  "tagOwners": {
    "tag:ci": ["autogroup:admin"]
  }
}
```

---

## 5. Vollständige ACL-Konfiguration mit Beispielen

### 5.1 Minimale ACL für GitHub Actions

**Zweck:** GitHub Actions Runner mit SSH-Zugriff auf einen Server

```json
{
  "tagOwners": {
    "tag:ci": ["autogroup:admin"]
  },
  "acls": [
    {
      // CI-Runner darf auf alle Ports des Servers zugreifen
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["tag:server:*"]
    }
  ],
  "ssh": [
    {
      // CI-Runner darf SSH als root auf Server
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["tag:server"],
      "users": ["root"]
    }
  ]
}
```

**Anwendung:** Markiere deinen VPS mit `tag:server` in der Tailscale Admin Console.

### 5.2 Empfohlene Produktions-ACL

**Zweck:** Sichere Konfiguration mit mehreren Umgebungen

```json
{
  // Gruppen definieren
  "groups": {
    "group:admins": [
      "admin@example.com"
    ],
    "group:devops": [
      "devops1@example.com",
      "devops2@example.com"
    ]
  },
  
  // Tag-Besitzer
  "tagOwners": {
    "tag:ci": ["autogroup:admin", "group:devops"],
    "tag:server": ["autogroup:admin", "group:devops"],
    "tag:database": ["autogroup:admin"],
    "tag:dev": ["autogroup:admin", "group:devops"]
  },
  
  // Netzwerk-Zugriffskontrolle
  "acls": [
    {
      // CI → Server (nur SSH und HTTP/HTTPS)
      "action": "accept",
      "src": ["tag:ci"],
      "dst": [
        "tag:server:22",    // SSH
        "tag:server:80",    // HTTP
        "tag:server:443",   // HTTPS
        "tag:server:9443"   // Caddy Admin
      ]
    },
    {
      // CI → Kein Zugriff auf Datenbanken (Security)
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["tag:database:0"]  // Explizit kein Zugriff
    },
    {
      // Server → Database
      "action": "accept",
      "src": ["tag:server"],
      "dst": ["tag:database:5432", "tag:database:6333"]
    },
    {
      // Admins → Alles
      "action": "accept",
      "src": ["group:admins"],
      "dst": ["*:*"]
    },
    {
      // DevOps → Server und Dev
      "action": "accept",
      "src": ["group:devops"],
      "dst": ["tag:server:*", "tag:dev:*"]
    }
  ],
  
  // SSH-Zugriffskontrolle
  "ssh": [
    {
      // CI → Server als root
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["tag:server"],
      "users": ["root"]
    },
    {
      // Admins → Alles als root
      "action": "accept",
      "src": ["group:admins"],
      "dst": ["*"],
      "users": ["root", "autogroup:nonroot"]
    },
    {
      // DevOps → Server als spezifische User
      "action": "accept",
      "src": ["group:devops"],
      "dst": ["tag:server", "tag:dev"],
      "users": ["deploy", "autogroup:nonroot"]
    },
    {
      // Explizit: CI darf NICHT auf Datenbanken per SSH
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["tag:database"],
      "users": []  // Leere User-Liste = kein SSH-Zugriff
    }
  ]
}
```

**Features:**
- ✅ Least-Privilege-Prinzip
- ✅ Rollenbasierte Zugriffskontrolle
- ✅ Explizite Deny-Rules für CI
- ✅ Separate SSH-Berechtigungen

### 5.3 ACL für das DevSystem-Projekt (qs-vps Zugriff)

**Zweck:** Spezifische Konfiguration für das DevSystem-Projekt mit QS-VPS

```json
{
  "tagOwners": {
    "tag:ci": ["autogroup:admin"],
    "tag:qs-vps": ["autogroup:admin"]
  },
  
  // Optionale Host-Definition für bessere Lesbarkeit
  "hosts": {
    "qs-vps": "100.x.x.x"  // Ersetze mit tatsächlicher Tailscale IP
  },
  
  "acls": [
    {
      // GitHub Actions (tag:ci) → QS-VPS
      "action": "accept",
      "src": ["tag:ci"],
      "dst": [
        "tag:qs-vps:22",    // SSH
        "tag:qs-vps:80",    // HTTP (Caddy)
        "tag:qs-vps:443",   // HTTPS (Caddy)
        "tag:qs-vps:9443",  // Caddy Admin API
        "tag:qs-vps:6333",  // Qdrant HTTP API
        "tag:qs-vps:6334"   // Qdrant gRPC
      ]
    },
    {
      // Admin → Vollzugriff auf QS-VPS
      "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["tag:qs-vps:*"]
    },
    {
      // QS-VPS → Internet (für Updates, Downloads)
      "action": "accept",
      "src": ["tag:qs-vps"],
      "dst": ["autogroup:internet:*"]
    }
  ],
  
  "ssh": [
    {
      // GitHub Actions → QS-VPS als root (für Deployments)
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["tag:qs-vps"],
      "users": ["root"]
    },
    {
      // Admin → QS-VPS als jeder User
      "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["tag:qs-vps"],
      "users": ["root", "autogroup:nonroot"]
    }
  ]
}
```

**Setup-Schritte:**

1. **ACL in Tailscale konfigurieren:**
   - Gehe zu: https://login.tailscale.com/admin/acls
   - Kopiere obige JSON (ersetze Tailscale IP)
   - Klicke "Save"

2. **QS-VPS taggen:**
   - Gehe zu: https://login.tailscale.com/admin/machines
   - Finde deinen QS-VPS
   - Bearbeite Tags → Füge `tag:qs-vps` hinzu

3. **Test:**
   ```bash
   gh workflow run deploy-qs-vps.yml --repo HaraldKiessling/DevSystem
   ```

---

## 6. Netzwerk-ACLs vs. SSH-ACLs

### 6.1 Unterschied zwischen Netzwerkzugriff und SSH-Zugriff

| Aspekt | Netzwerk-ACL (`acls`) | SSH-ACL (`ssh`) |
|--------|----------------------|-----------------|
| **Zweck** | TCP/UDP Port-Zugriff | SSH-Verbindungen |
| **Granularität** | IP:Port | User@Host |
| **Beispiel** | `tag:ci → 100.x.x.x:22` | `tag:ci → root@qs-vps` |
| **Erforderlich für** | Jede Netzwerkverbindung | Nur Tailscale SSH |
| **Standard** | Deny All | Deny All |

### 6.2 Warum beide separat konfiguriert werden müssen

**Szenario:** GitHub Actions soll SSH auf QS-VPS ausführen

```
1. Netzwerk-Ebene (acls):
   ├── Erlaubt: tag:ci → tag:qs-vps:22
   └── → TCP-Verbindung zu Port 22 möglich

2. SSH-Ebene (ssh):
   ├── Erlaubt: tag:ci → tag:qs-vps als root
   └── → SSH-Login als root möglich

❌ Nur ACL ohne SSH: Verbindung kommt an, aber Login wird verweigert
❌ Nur SSH ohne ACL: Verbindung wird auf IP-Ebene blockiert
✅ Beide konfiguriert: Voller SSH-Zugriff funktioniert
```

**Praktisches Beispiel:**

```json
{
  "acls": [
    {
      // Erlaubt Netzwerkverbindung zu SSH-Port
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["tag:qs-vps:22"]
    }
  ],
  "ssh": [
    {
      // Erlaubt SSH-Login als root
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["tag:qs-vps"],
      "users": ["root"]
    }
  ]
}
```

**⚠️ Häufiger Fehler:**
```json
// ❌ FALSCH - Nur Netzwerkzugriff, kein SSH-Login
{
  "acls": [
    {
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["tag:qs-vps:22"]
    }
  ]
  // ssh-Sektion fehlt!
}

// Fehlerme ldung: "tailnet policy does not permit you to SSH"
```

### 6.3 Spezifische SSH-Regeln für tag:ci

**Minimale Konfiguration:**
```json
{
  "ssh": [
    {
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["tag:qs-vps"],
      "users": ["root"]
    }
  ]
}
```

**Erweiterte Konfiguration mit mehreren Usern:**
```json
{
  "ssh": [
    {
      // CI darf als root und deploy-User
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["tag:qs-vps"],
      "users": ["root", "deploy"]
    },
    {
      // CI darf NICHT als andere User
      // (implizit durch fehlende Regel)
    }
  ]
}
```

**Mit autogroup:nonroot:**
```json
{
  "ssh": [
    {
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["tag:qs-vps"],
      "users": [
        "root",              // Explizit root
        "autogroup:nonroot"  // Alle nicht-root User
      ]
    }
  ]
}
```

---

## 7. OAuth Client Berechtigungen

### 7.1 Welche Berechtigungen der OAuth-Client benötigt

Der OAuth-Client benötigt minimal:

```
Scope: devices:write
```

**Was dieser Scope erlaubt:**
- ✅ Neue Geräte im Tailnet registrieren
- ✅ Ephemeral Nodes erstellen (automatische Bereinigung)
- ✅ Tags zuweisen (wenn ACL es erlaubt)
- ✅ Preauthorized Nodes erstellen

**Was dieser Scope NICHT erlaubt:**
- ❌ ACL-Policies ändern
- ❌ Andere Geräte löschen
- ❌ Routen ändern (benötigt `routes:write`)
- ❌ DNS-Einstellungen ändern

### 7.2 Wie OAuth Credentials verwendet werden

**In GitHub Actions:**

```yaml
- name: Setup Tailscale
  uses: tailscale/github-action@v2
  with:
    oauth-client-id: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID }}
    oauth-secret: ${{ secrets.TAILSCALE_OAUTH_SECRET }}
    tags: tag:ci
```

**Was passiert intern:**

```
1. GitHub Action authentifiziert sich bei Tailscale API
   ├── POST https://api.tailscale.com/api/v2/oauth/token
   ├── Client ID + Secret → Access Token
   └── Access Token wird gecacht

2. Action fordert Auth Key an
   ├── POST https://api.tailscale.com/api/v2/tailnet/$TAILNET/keys
   ├── Mit Access Token
   ├── Parameter: ephemeral=true, preauthorized=true, tags=tag:ci
   └── Erhält temporären Auth Key

3. Action registriert Node
   ├── tailscale up --authkey=$AUTHKEY --hostname=github-runner-xyz
   ├── Node wird mit tag:ci erstellt
   └── Node ist im Tailnet verfügbar

4. Workflow läuft
   ├── SSH-Verbindungen über Tailscale
   ├── Deployment-Scripts ausführen
   └── Services testen

5. Workflow endet
   ├── Action beendet (cleanup)
   ├── Ephemeral Node wird automatisch gelöscht
   └── Keine Spuren im Tailnet
```

### 7.3 Beziehung zwischen Client und ACL-Regeln

**Wichtig:** OAuth-Client + ACL-Policy arbeiten zusammen!

```
OAuth-Client Permissions (API-Ebene):
    devices:write → Darf Geräte erstellen
         ↓
ACL-Policy (Netzwerk-Ebene):
    tagOwners: tag:ci → autogroup:admin
         ↓
    Darf OAuth-Client tag:ci verwenden?
         ↓
    acls: tag:ci → tag:qs-vps:*
         ↓
    Darf tag:ci auf qs-vps zugreifen?
         ↓
    ssh: tag:ci → tag:qs-vps as root
         ↓
    Darf tag:ci als root per SSH?
```

**Fehlschlag-Szenarien:**

| Szenario | Client Permission | ACL tagOwners | Ergebnis |
|----------|-------------------|---------------|----------|
| ✅ Korrekt | `devices:write` | `autogroup:admin` | Erfolg |
| ❌ Fehler 1 | Keine | `autogroup:admin` | 403 Forbidden |
| ❌ Fehler 2 | `devices:write` | Fehlt | 400 Tags not permitted |
| ❌ Fehler 3 | `devices:write` | `user@example.com` | 400 Tags not permitted |

---

## 8. Häufige Fehlerquellen und Troubleshooting

### 8.1 "requested tags are invalid or not permitted"

**Vollständige Fehlermeldung:**
```
Status: 400, Message: "requested tags [tag:ci] are invalid or not permitted"
```

**Ursachen:**

1. **Tag-Owner fehlt in ACL:**
   ```json
   // ❌ FALSCH
   {
     "tagOwners": {}  // tag:ci nicht definiert
   }
   
   // ✅ RICHTIG
   {
     "tagOwners": {
       "tag:ci": ["autogroup:admin"]
     }
   }
   ```

2. **Tag-Owner ist spezifischer Benutzer (nicht Admin):**
   ```json
   // ❌ FALSCH - OAuth-Client ist kein spezifischer User
   {
     "tagOwners": {
       "tag:ci": ["user@example.com"]
     }
   }
   
   // ✅ RICHTIG
   {
     "tagOwners": {
       "tag:ci": ["autogroup:admin"]
     }
   }
   ```

3. **Tippfehler in Tag-Name:**
   ```json
   // ❌ FALSCH
   {
     "tagOwners": {
       "tag:IC": ["autogroup:admin"]  // IC statt ci
     }
   }
   ```

**Lösung:**
1. Gehe zu: https://login.tailscale.com/admin/acls
2. Füge hinzu:
   ```json
   {
     "tagOwners": {
       "tag:ci": ["autogroup:admin"]
     }
   }
   ```
3. Klicke "Save"
4. Teste Workflow erneut

### 8.2 "tailnet policy does not permit you to SSH"

**Vollständige Fehlermeldung:**
```
ssh: Tailscale SSH: tailnet policy does not permit you to SSH as user "root"
```

**Ursachen:**

1. **SSH-Regel fehlt komplett:**
   ```json
   // ❌ FALSCH - Kein ssh-Block
   {
     "acls": [...]
     // ssh-Block fehlt!
   }
   
   // ✅ RICHTIG
   {
     "acls": [...],
     "ssh": [
       {
         "action": "accept",
         "src": ["tag:ci"],
         "dst": ["tag:qs-vps"],
         "users": ["root"]
       }
     ]
   }
   ```

2. **SSH-Regel für falschen User:**
   ```json
   // ❌ FALSCH - Nur deploy, nicht root
   {
     "ssh": [
       {
         "action": "accept",
         "src": ["tag:ci"],
         "dst": ["tag:qs-vps"],
         "users": ["deploy"]  // root fehlt!
       }
     ]
   }
   ```

3. **SSH-Regel für falschen Tag:**
   ```json
   // ❌ FALSCH - Regel für tag:server, nicht tag:qs-vps
   {
     "ssh": [
       {
         "action": "accept",
         "src": ["tag:ci"],
         "dst": ["tag:server"],  // Falsches Ziel
         "users": ["root"]
       }
     ]
   }
   ```

**Lösung:**
1. Öffne ACL-Editor
2. Füge `ssh`-Block hinzu:
   ```json
   {
     "ssh": [
       {
         "action": "accept",
         "src": ["tag:ci"],
         "dst": ["tag:qs-vps"],
         "users": ["root"]
       }
     ]
   }
   ```
3. Speichern und testen

### 8.3 Fehlende tagOwners

**Symptom:**
```
Status: 400, Message: "requested tags [tag:ci] are invalid or not permitted"
```

**Debugging:**
```bash
# 1. ACL-Policy herunterladen und prüfen
curl -u "$TAILSCALE_API_KEY:" \
  https://api.tailscale.com/api/v2/tailnet/$TAILNET/acl | jq .

# 2. Nach tagOwners suchen
curl -u "$TAILSCALE_API_KEY:" \
  https://api.tailscale.com/api/v2/tailnet/$TAILNET/acl | jq .tagOwners
```

**Erwartete Ausgabe:**
```json
{
  "tag:ci": ["autogroup:admin"]
}
```

**Bei leerem Ergebnis:**
```json
{}
```
→ tagOwners muss hinzugefügt werden

### 8.4 Unzureichende SSH-Berechtigungen

**Symptom:**
```
Permission denied (publickey,tailscale)
```

**Ursache:** User in SSH-Regel fehlt

**Debugging:**
```json
// Aktuelle ssh-Regel
{
  "ssh": [
    {
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["tag:qs-vps"],
      "users": ["deploy"]  // root fehlt
    }
  ]
}
```

**Lösung:**
```json
{
  "ssh": [
    {
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["tag:qs-vps"],
      "users": ["root", "deploy"]  // Beide User hinzufügen
    }
  ]
}
```

### 8.5 Debug-Strategien

#### Strategie 1: Schrittweise Verifizierung

```bash
# 1. OAuth-Client testen
curl -X POST https://api.tailscale.com/api/v2/oauth/token \
  -u "$CLIENT_ID:$CLIENT_SECRET" \
  -d "grant_type=client_credentials"

# 2. ACL-Policy abrufen
curl -u "$API_KEY:" \
  https://api.tailscale.com/api/v2/tailnet/$TAILNET/acl | jq .

# 3. Tailscale Status im Workflow prüfen
- name: Debug Tailscale
  run: |
    tailscale status
    tailscale netcheck
```

#### Strategie 2: Workflow-Logging aktivieren

```yaml
- name: Setup Tailscale (OAuth) mit Debug
  uses: tailscale/github-action@v2
  env:
    ACTIONS_STEP_DEBUG: true
  with:
    oauth-client-id: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID }}
    oauth-secret: ${{ secrets.TAILSCALE_OAUTH_SECRET }}
    tags: tag:ci
```

#### Strategi e 3: Manuelle Validierung

```bash
# 1. Lokale Test-Umgebung
export TAILSCALE_OAUTH_CLIENT_ID="k..."
export TAILSCALE_OAUTH_SECRET="tskey-client-..."

# 2. Tailscale CLI lokal testen
tailscale up \
  --auth-key="$AUTH_KEY" \
  --hostname=test-runner \
  --advertise-tags=tag:ci

# 3. SSH-Verbindung testen
ssh root@qs-vps.tailnet-name.ts.net
```

#### Strategie 4: ACL-Syntax-Validierung

```bash
# JSON-Syntax prüfen
cat acl.json | jq .

# ACL in Testtailnet hochladen
curl -X POST \
  -u "$API_KEY:" \
  -H "Content-Type: application/json" \
  -d @acl.json \
  https://api.tailscale.com/api/v2/tailnet/$TAILNET/acl
```

---

## 9. Vollständiger Setup-Prozess

### 9.1 Schritt 1: OAuth-Client erstellen

```bash
# 1. Browser öffnen
https://login.tailscale.com/admin/settings/oauth

# 2. OAuth-Client generieren
Name: GitHub Actions - DevSystem
Scopes: devices:write

# 3. Credentials notieren
CLIENT_ID: k1234567890abcdef...
CLIENT_SECRET: tskey-client-k1234567890abcdef...
```

### 9.2 Schritt 2: GitHub Secrets setzen

```bash
# Repository auswählen
cd /path/to/DevSystem

# Secrets setzen
gh secret set TAILSCALE_OAUTH_CLIENT_ID --body "k1234567890abcdef..."
gh secret set TAILSCALE_OAUTH_SECRET --body "tskey-client-k1234567890abcdef..."

# Verifizierung
gh secret list | grep TAILSCALE
```

**Erwartete Ausgabe:**
```
TAILSCALE_OAUTH_CLIENT_ID  Updated 2026-04-13
TAILSCALE_OAUTH_SECRET     Updated 2026-04-13
```

### 9.3 Schritt 3: ACL anpassen

```bash
# 1. ACL-Editor öffnen
https://login.tailscale.com/admin/acls

# 2. Folgende Konfiguration hinzufügen/anpassen
```

```json
{
  "tagOwners": {
    "tag:ci": ["autogroup:admin"],
    "tag:qs-vps": ["autogroup:admin"]
  },
  
  "acls": [
    {
      "action": "accept",
      "src": ["tag:ci"],
      "dst": [
        "tag:qs-vps:22",
        "tag:qs-vps:80",
        "tag:qs-vps:443",
        "tag:qs-vps:9443",
        "tag:qs-vps:6333"
      ]
    },
    {
      "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["*:*"]
    }
  ],
  
  "ssh": [
    {
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["tag:qs-vps"],
      "users": ["root"]
    },
    {
      "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["*"],
      "users": ["root", "autogroup:nonroot"]
    }
  ]
}
```

```bash
# 3. "Save" klicken

# 4. QS-VPS taggen
https://login.tailscale.com/admin/machines
→ QS-VPS finden
→ Tags: tag:qs-vps
```

### 9.4 Schritt 4: Workflow testen

```bash
# Manueller Workflow-Trigger
gh workflow run deploy-qs-vps.yml

# Workflow-Status beobachten
gh run watch

# Oder: Browser öffnen
https://github.com/HaraldKiessling/DevSystem/actions
```

**Erfolgreiche Ausgabe:**
```
✓ Checkout Repository
✓ Setup Tailscale (OAuth)
✓ Setup SSH Key
✓ Test SSH Connection
✓ Sync Repository to QS-VPS
✓ Run Master-Orchestrator
✓ Validate Services
✓ Run Health Checks
```

### 9.5 Schritt 5: Verifizierung

#### Log-Verifizierung

```yaml
# Im Workflow-Log suchen nach:
✓ "Tailscale connected"
✓ "SSH connection successful"
✓ Keine "400" oder "403" Fehler
```

#### Tailscale Admin Verifizierung

```bash
# 1. Machines-Liste öffnen
https://login.tailscale.com/admin/machines

# 2. Github Runner suchen
Name: github-runner-xyz
Status: Offline (nach Workflow-Ende - normal bei ephemeral)
Tags: tag:ci

# 3. Activity Log prüfen
→ "Device connected"
→ "SSH session to qs-vps as root"
→ "Device disconnected"
```

#### Manueller SSH-Test

```bash
# Von lokalem Rechner (mit Tailscale)
ssh root@qs-vps.tailnet-name.ts.net

# Im Workflow (Schritt hinzufügen)
- name: Test Tailscale SSH
  run: |
    tailscale ssh root@qs-vps "hostname && whoami"
```

---

## 10. Spezifisch für deploy-qs-vps.yml

### 10.1 Wie der Workflow OAuth verwendet

**Datei:** [`.github/workflows/deploy-qs-vps.yml`](.github/workflows/deploy-qs-vps.yml)

```yaml
- name: Setup Tailscale (OAuth)
  id: tailscale_oauth
  continue-on-error: true
  uses: tailscale/github-action@v2
  with:
    oauth-client-id: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID }}
    oauth-secret: ${{ secrets.TAILSCALE_OAUTH_SECRET }}
    tags: tag:ci
```

**Ablauf:**

1. **OAuth-Authentifizierung:**
   ```
   GitHub Action → Tailscale API
   ├── Client ID + Secret
   ├── Erhält Access Token
   └── Generiert ephemeral Auth Key
   ```

2. **Node-Registrierung:**
   ```
   tailscale up \
     --authkey=$EPHEMERAL_KEY \
     --hostname=github-runner-$RUN_ID \
     --advertise-tags=tag:ci \
     --accept-routes
   ```

3. **Netzwerk-Zugriff:**
   ```
   Runner ist jetzt im Tailnet
   ├── IP: 100.x.x.x
   ├── Hostname: github-runner-123456
   ├── Tags: tag:ci
   └── Kann auf tag:qs-vps zugreifen
   ```

### 10.2 Welche Berechtigungen er benötigt

**OAuth-Client:**
- Scope: `devices:write`

**ACL-Policy:**

```json
{
  "tagOwners": {
    "tag:ci": ["autogroup:admin"]
  },
  
  "acls": [
    {
      "action": "accept",
      "src": ["tag:ci"],
      "dst": [
        "tag:qs-vps:22",    // SSH für Deployment
        "tag:qs-vps:9443",  // Caddy Admin (optional)
        "tag:qs-vps:6333"   // Qdrant Health Check (optional)
      ]
    }
  ],
  
  "ssh": [
    {
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["tag:qs-vps"],
      "users": ["root"]     // Für setup-qs-master.sh (benötigt sudo)
    }
  ]
}
```

**Begründung:**
- **Port 22:** SSH-Zugriff für Deployment-Befehle
- **Port 9443:** Caddy Admin API (Service-Konfiguration)
- **Port 6333:** Qdrant Health Check (Service-Validierung)
- **root-User:** Scripts verwenden `sudo` (setup-qs-master.sh)

### 10.3 Beispiel-Workflow-Konfiguration

**Vollständiger Workflow-Ausschnitt:**

```yaml
name: Deploy QS-VPS

on:
  workflow_dispatch:
  push:
    branches: [main]
    paths:
      - "scripts/qs/**"
      - ".github/workflows/deploy-qs-vps.yml"

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      # 1. Code auschecken
      - name: Checkout
        uses: actions/checkout@v4
      
      # 2. Tailscale mit OAuth
      - name: Setup Tailscale
        uses: tailscale/github-action@v2
        with:
          oauth-client-id: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID }}
          oauth-secret: ${{ secrets.TAILSCALE_OAUTH_SECRET }}
          tags: tag:ci
      
      # 3. Tailscale Status prüfen
      - name: Verify Tailscale
        run: |
          tailscale status
          tailscale ping qs-vps
      
      # 4. SSH-Verbindung über Tailscale
      - name: Deploy via Tailscale SSH
        run: |
          # Direkte SSH-Verbindung über Tailscale
          tailscale ssh root@qs-vps "cd /root/work/DevSystem && \
            git pull && \
            sudo bash scripts/qs/setup-qs-master.sh"
      
      # 5. Health Check
      - name: Health Check
        run: |
          tailscale ssh root@qs-vps "systemctl is-active caddy qdrant-qs"
```

**Vorteile dieser Konfiguration:**
- ✅ Kein SSH-Key-Management nötig
- ✅ Automatische Bereinigung (ephemeral)
- ✅ Tailscale SSH nutzt Tailscale-Authentifizierung  
- ✅ Keine manuellen known_hosts

**Alternative: Klassisches SSH über Tailscale:**

```yaml
- name: Setup SSH Key
  run: |
    mkdir -p ~/.ssh
    echo "${{ secrets.QS_VPS_SSH_KEY }}" > ~/.ssh/id_ed25519
    chmod 600 ~/.ssh/id_ed25519

- name: Deploy via SSH
  run: |
    # SSH über Tailscale IP
    ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no \
      root@qs-vps.your-tailnet.ts.net \
      "cd /root/work/DevSystem && bash scripts/qs/setup-qs-master.sh"
```

---

## 11. Sicherheitsaspekte

### 11.1 Least-Privilege-Prinzip

**Definition:** Jedes System erhält nur die minimal notwendigen Berechtigungen.

**Anwendung auf tag:ci:**

```json
{
  "acls": [
    {
      // ❌ FALSCH - CI hat Vollzugriff auf alles
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["*:*"]
    }
  ]
}
```

```json
{
  "acls": [
    {
      // ✅ RICHTIG - CI hat nur Zugriff auf Deployment-Ziel
      "action": "accept",
      "src": ["tag:ci"],
      "dst": [
        "tag:qs-vps:22",
        "tag:qs-vps:6333"
      ]
    },
    {
      // ✅ RICHTIG - Explizit kein Zugriff auf Datenbanken
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["tag:database:0"]  // Port 0 = kein Zugriff
    }
  ]
}
```

**Best Practices:**
- ✅ Nur spezifische Ports erlauben
- ✅ Nur spezifische Hosts erlauben
- ✅ Zeitlich begrenzte Nodes (ephemeral)
- ✅ Regelmäßige ACL-Reviews

### 11.2 Tag-basierte Isolation

**Vorteil:** Geräte sind durch Tags isoliert.

**Beispiel-Architektur:**

```
Tailnet Segmentation:
├── tag:ci (GitHub Actions)
│   ├── Darf: tag:staging, tag:qs-vps
│   └── Darf NICHT: tag:production, tag:database
├── tag:staging (Test-Server)
│   ├── Darf: tag:dev-database
│   └── Darf NICHT: tag:production-database
├── tag:production (Prod-Server)
│   ├── Darf: tag:production-database
│   └── Darf NICHT: tag:staging
└── tag:database (Alle DBs)
    └── Keine ausgehenden Verbindungen
```

**ACL-Implementierung:**

```json
{
  "tagOwners": {
    "tag:ci": ["autogroup:admin"],
    "tag:staging": ["autogroup:admin", "group:devops"],
    "tag:production": ["autogroup:admin"],
    "tag:database": ["autogroup:admin"]
  },
  
  "acls": [
    {
      // CI → Nur Staging und QS
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["tag:staging:*", "tag:qs-vps:*"]
    },
    {
      // Explizit: CI NICHT auf Production
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["tag:production:0"]  // Deny
    },
    {
      // Production → Production-DB
      "action": "accept",
      "src": ["tag:production"],
      "dst": ["tag:database:5432"]
    },
    {
      // Staging → Dev-DB (anderer Port)
      "action": "accept",
      "src": ["tag:staging"],
      "dst": ["tag:database:5433"]
    }
  ]
}
```

### 11.3 OAuth vs. Auth Keys

| Sicherheitsaspekt | OAuth Client | Auth Key |
|-------------------|--------------|----------|
| **Ablauf** | ✅ Niemals | ❌ Konfigurierbar (90 Tage) |
| **Granularität** | ✅ Scopes | ⚠️ Vollzugriff oder Tag-basiert |
| **Rotation** | ⚠️ Manuell | ✅ Automatisch (durch Ablauf) |
| **Audit-Trail** | ✅ Detailliert | ⚠️ Eingeschränkt |
| **Widerruf** | ✅ Sofort | ✅ Sofort |
| **Kompromittierung** | ⚠️ Dauerhaft gültig | ✅ Zeitlich begrenzt |

**Empfehlung:**

```
Development/Testing:
└── Auth Key (automatische Rotation durch Ablauf)

Production:
├── OAuth Client (keine manuelle Wartung)
└── + Monitoring & Alerting bei ungewöhnlicher Nutzung
```

**Besondere Sicherheitsmaßnahmen für OAuth:**

1. **Secret Rotation:**
   ```bash
   # Alle 6-12 Monate OAuth-Client erneuern
   # 1. Neuen Client erstellen
   # 2. GitHub Secrets updaten
   # 3. Alten Client löschen (nach Testphase)
   ```

2. **Monitoring:**
   ```bash
   # Tailscale Activity Log regelmäßig prüfen
   https://login.tailscale.com/admin/logs
   
   # Auf ungewöhnliche Aktivitäten achten:
   - Zugriff zu ungewöhnlichen Zeiten
   - Verbindungen zu unerwarteten Hosts
   - Unbekannte Hostnamen mit tag:ci
   ```

3. **Least-Privilege:**
   ```json
   {
     "acls": [
       {
         // NUR notwendige Ports
         "action": "accept",
         "src": ["tag:ci"],
         "dst": ["tag:qs-vps:22"]  // Nur SSH
       }
     ],
     "ssh": [
       {
         // NUR notwendige User
         "action": "accept",
         "src": ["tag:ci"],
         "dst": ["tag:qs-vps"],
         "users": ["deploy"]  // NICHT root (wenn möglich)
       }
     ]
   }
   ```

4. **Ephemeral Nodes:**
   ```yaml
   # GitHub Action erstellt automatisch ephemeral Nodes
   # → Automatische Bereinigung nach Workflow-Ende
   # → Keine dauerhaften Geräte in der Node-Liste
   # → Reduzierte Angriffsfläche
   ```

---

## 12. Referenzen und weitere Ressourcen

### 12.1 Offizielle Tailscale-Dokumentation

- **ACL Documentation:** https://tailscale.com/kb/1018/acls/
- **OAuth Clients:** https://tailscale.com/kb/1215/oauth-clients/
- **Auth Keys:** https://tailscale.com/kb/1085/auth-keys/
- **SSH Guide:** https://tailscale.com/kb/1193/tailscale-ssh/
- **Tags:** https://tailscale.com/kb/1068/tags/
- **API Reference:** https://tailscale.com/api

### 12.2 GitHub Actions

- **Tailscale GitHub Action:** https://github.com/tailscale/github-action
- **GitHub Secrets:** https://docs.github.com/en/actions/security-guides/encrypted-secrets
- **Workflow Syntax:** https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions

### 12.3 Projektspezifische Dokumente

**Setup-Anleitungen:**
- [`docs/operations/TAILSCALE-OAUTH-MIGRATION-GUIDE.md`](../docs/operations/TAILSCALE-OAUTH-MIGRATION-GUIDE.md) - Schritt-für-Schritt Migration
- [`docs/operations/TAILSCALE-GITHUB-SETUP-SIMPLIFIED.md`](../docs/operations/TAILSCALE-GITHUB-SETUP-SIMPLIFIED.md) - Vereinfachte Einrichtung
- [`docs/operations/QUICK-START-TAILSCALE-GITHUB.md`](../docs/operations/QUICK-START-TAILSCALE-GITHUB.md) - Schnellstart

**Vergleiche & Analysen:**
- [`docs/operations/TAILSCALE-AUTH-METHODS-COMPARISON.md`](../docs/operations/TAILSCALE-AUTH-METHODS-COMPARISON.md) - Auth Key vs. OAuth
- [`docs/operations/TAILSCALE-OAUTH-TEST-REPORT.md`](../docs/operations/TAILSCALE-OAUTH-TEST-REPORT.md) - Test-Ergebnisse

**Troubleshooting:**
- [`docs/operations/QS-VPS-DEPLOY-DEBUG-REPORT-2026-04-12.md`](../docs/operations/QS-VPS-DEPLOY-DEBUG-REPORT-2026-04-12.md) - Debug-Report

**GitHub Configuration:**
- [`docs/operations/github-secrets-setup.md`](../docs/operations/github-secrets-setup.md) - Secrets-Management
- [`docs/operations/GITHUB-SECRETS-SETUP-COMPLETION-REPORT.md`](../docs/operations/GITHUB-SECRETS-SETUP-COMPLETION-REPORT.md) - Setup-Status

### 12.4 Tools & Scripts

**Eigene Scripts:**
- [`scripts/setup-tailscale-github-auth.sh`](setup-tailscale-github-auth.sh) - Automatisiertes Setup
- [`scripts/setup-qs-vps.sh`](setup-qs-vps.sh) - QS-VPS Deployment
- [`scripts/test-tailscale.sh`](test-tailscale.sh) - Verbindungstest

**CLI-Tools:**
```bash
# Tailscale CLI
tailscale status
tailscale netcheck
tailscale ssh

# GitHub CLI
gh secret list
gh workflow run
gh run watch

# API-Testing
curl -u "$CLIENT_ID:$SECRET" \
  https://api.tailscale.com/api/v2/tailnet/$TAILNET/acl
```

### 12.5 Community & Support

- **Tailscale Forum:** https://forum.tailscale.com/
- **GitHub Discussions:** https://github.com/tailscale/tailscale/discussions
- **Stack Overflow:** Tag `tailscale`

---

## Anhang A: ACL-Vorlagen

### A.1 Minimale Single-Node ACL

```json
{
  "tagOwners": {
    "tag:ci": ["autogroup:admin"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["*:22"]
    }
  ],
  "ssh": [
    {
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["*"],
      "users": ["root"]
    }
  ]
}
```

### A.2 Multi-Environment ACL

```json
{
  "groups": {
    "group:devops": ["devops@example.com"]
  },
  "tagOwners": {
    "tag:ci": ["autogroup:admin"],
    "tag:dev": ["autogroup:admin", "group:devops"],
    "tag:staging": ["autogroup:admin", "group:devops"],
    "tag:production": ["autogroup:admin"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["tag:dev:*", "tag:staging:*"]
    },
    {
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["tag:production:0"]
    },
    {
      "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["*:*"]
    }
  ],
  "ssh": [
    {
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["tag:dev", "tag:staging"],
      "users": ["root", "deploy"]
    },
    {
      "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["*"],
      "users": ["root", "autogroup:nonroot"]
    }
  ]
}
```

### A.3 DevSystem-spezifische ACL

```json
{
  "tagOwners": {
    "tag:ci": ["autogroup:admin"],
    "tag:qs-vps": ["autogroup:admin"]
  },
  "hosts": {
    "qs-vps": "100.x.x.x"
  },
  "acls": [
    {
      "action": "accept",
      "src": ["tag:ci"],
      "dst": [
        "tag:qs-vps:22",
        "tag:qs-vps:80",
        "tag:qs-vps:443",
        "tag:qs-vps:9443",
        "tag:qs-vps:6333",
        "tag:qs-vps:6334"
      ]
    },
    {
      "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["*:*"]
    }
  ],
  "ssh": [
    {
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["tag:qs-vps"],
      "users": ["root"]
    },
    {
      "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["*"],
      "users": ["root", "autogroup:nonroot"]
    }
  ]
}
```

---

## Anhang B: Checklisten

### B.1 OAuth-Setup Checkliste

```markdown
- [ ] OAuth-Client in Tailscale erstellt
- [ ] Client ID notiert: k...
- [ ] Client Secret notiert: tskey-client-k...
- [ ] Scope `devices:write` ausgewählt
- [ ] GitHub Secret TAILSCALE_OAUTH_CLIENT_ID gesetzt
- [ ] GitHub Secret TAILSCALE_OAUTH_SECRET gesetzt
- [ ] Secrets mit `gh secret list` verifiziert
```

### B.2 ACL-Konfiguration Checkliste

```markdown
- [ ] ACL-Editor geöffnet: https://login.tailscale.com/admin/acls
- [ ] tagOwners für tag:ci hinzugefügt
- [ ] tagOwners enthält autogroup:admin
- [ ] acls-Regel für tag:ci → tag:qs-vps hinzugefügt
- [ ] Ports spezifiziert (22, 80, 443, etc.)
- [ ] ssh-Regel für tag:ci → tag:qs-vps hinzugefügt
- [ ] User "root" in SSH-Regel eingetragen
- [ ] ACL gespeichert (keine Syntax-Fehler)
- [ ] QS-VPS mit tag:qs-vps getaggt
```

### B.3 Workflow-Test Checkliste

```markdown
- [ ] Workflow manuell gestartet: `gh workflow run deploy-qs-vps.yml`
- [ ] Setup Tailscale (OAuth) Step: ✅ Erfolgreich
- [ ] Keine "400 tags not permitted" Fehler
- [ ] Keine "tailnet policy SSH" Fehler
- [ ] SSH-Verbindung erfolgreich
- [ ] Deployment erfolgreich
- [ ] Services laufen (caddy, qdrant-qs)
- [ ] Health Checks bestanden
```

---

## Anhang C: Häufig gestellte Fragen (FAQ)

### C.1 Allgemeine Fragen

**Q: Muss ich für jeden Workflow einen eigenen OAuth-Client erstellen?**
A: Nein, ein OAuth-Client kann für alle Workflows im gleichen Repository verwendet werden.

**Q: Kann ich denselben OAuth-Client für mehrere Repositories verwenden?**
A: Ja, aber aus Sicherheitsgründen wird empfohlen, separate Clients pro Repository oder Organisation zu verwenden.

**Q: Wie lange sind OAuth-Clients gültig?**
A: OAuth-Clients haben **kein Ablaufdatum** und sind permanent gültig, bis sie manuell widerrufen werden.

**Q: Was passiert, wenn ich mein OAuth-Secret verliere?**
A: Du musst einen neuen OAuth-Client erstellen, da Secrets nicht erneut angezeigt werden können.

### C.2 ACL-Fragen

**Q: Warum benötige ich tagOwners für OAuth-Clients?**
A: OAuth-Clients agieren im Namen von `autogroup:admin`. Ohne `tagOwners`-Eintrag dürfen Admins den Tag nicht verwenden.

**Q: Kann ich tag:ci auch für andere Services verwenden?**
A: Ja, tag:ci ist nicht auf GitHub Actions beschränkt. Du kannst ihn für alle CI/CD-Systeme verwenden.

**Q: Muss ich sowohl acls als auch ssh konfigurieren?**
A: Ja, `acls` regelt Netzwerkzugriff, `ssh` regelt SSH-Berechtigungen. Beide sind erforderlich für SSH-Zugriff.

**Q: Was ist der Unterschied zwischen tag:ci und autogroup:member?**
A: `tag:ci` ist ein benutzerdefinierter Tag für CI/CD-Systeme. `autogroup:member` umfasst alle authentifizierten Benutzer im Tailnet.

### C.3 Troubleshooting-Fragen

**Q: Workflow schlägt mit "400 tags not permitted" fehl. Was tun?**
A: Füge `"tag:ci": ["autogroup:admin"]` zu `tagOwners` in der ACL-Policy hinzu.

**Q: SSH funktioniert nicht trotz korrekter ACL. Warum?**
A: Prüfe, ob eine `ssh`-Regel mit dem richtigen User existiert. Netzwerk-ACL allein reicht nicht.

**Q: Kann ich den Workflow-Fehler lokal reproduzieren?**
A: Ja, installiere Tailscale lokal und nutze denselben OAuth-Client:
```bash
export TAILSCALE_OAUTH_CLIENT_ID="k..."
export TAILSCALE_OAUTH_SECRET="tskey-client-k..."
tailscale up --authkey=... --advertise-tags=tag:ci
```

**Q: Wie kann ich sehen, welche Nodes aktuell tag:ci haben?**
A: In der Tailscale Admin Console → Machines → Filter nach "tag:ci"

### C.4 Sicherheitsfragen

**Q: Ist OAuth sicherer als Auth Keys?**
A: OAuth bietet granularere Berechtigungen (Scopes), aber beide Methoden sind sicher bei korrekter Verwendung.

**Q: Sollte ich ephemeral Nodes verwenden?**
A: Ja, für CI/CD wird ephemeral dringend empfohlen. Nodes werden automatisch nach dem Workflow bereinigt.

**Q: Wie widerrufe ich einen kompromittierten OAuth-Client?**
A: Gehe zu https://login.tailscale.com/admin/settings/oauth → Finde den Client → "Delete"

**Q: Kann jemand mit dem OAuth-Client auf meine anderen Geräte zugreifen?**
A: Nur wenn ACL-Regeln es erlauben. Die ACL-Policy definiert, welche Tags auf welche Geräte zugreifen dürfen.

---

## Anhang D: Glossar

| Begriff | Erklärung |
|---------|-----------|
| **ACL** | Access Control List - Definiert Netzwerk- und SSH-Berechtigungen |
| **OAuth Client** | Credentials für API-Zugriff (Client ID + Secret) |
| **Auth Key** | Temporärer Schlüssel für Geräte-Registrierung |
| **Tag** | Label für Geräte (z.B. `tag:ci`) |
| **tagOwners** | Definiert, wer Tags vergeben darf |
| **ephemeral** | Temporäre Nodes, die automatisch entfernt werden |
| **preauthorized** | Geräte werden ohne manuelle Genehmigung hinzugefügt |
| **Scope** | Berechtigungen eines OAuth-Clients (z.B. `devices:write`) |
| **Tailnet** | Ihr privates Tailscale-Netzwerk |
| **autogroup:admin** | Automatische Gruppe aller Tailnet-Administratoren |
| **autogroup:member** | Automatische Gruppe aller Tailnet-Mitglieder |
| **autogroup:nonroot** | Automatische Gruppe aller nicht-root SSH-User |
| **MagicDNS** | Tailscale DNS (z.B. `qs-vps.tailnet-name.ts.net`) |

---

## Änderungshistorie

| Version | Datum | Änderungen |
|---------|-------|------------|
| 1.0 | 2026-04-12 | Initiale Version mit OAuth-Grundlagen |
| 2.0 | 2026-04-13 | Vollständige ACL-Dokumentation hinzugefügt |
|     |            | - Issue #18 Kontext integriert |
|     |            | - Detaillierte JSON-Beispiele |
|     |            | - Troubleshooting-Sektion erweitert |
|     |            | - FAQ und Glossar hinzugefügt |

---

## Lizenz und Beiträge

Diese Dokumentation ist Teil des DevSystem-Projekts und steht unter der gleichen Lizenz wie das Hauptprojekt.

**Feedback und Verbesserungen:**
- Issues: https://github.com/HaraldKiessling/DevSystem/issues
- Pull Requests: Willkommen!

---

**Ende der Dokumentation**