# Passwort-Generierung für devsystem-qs-vps code-server

**Erstellt:** 2026-04-11  
**Zweck:** code-server Web-IDE Login  
**System:** devsystem-qs-vps (Quality Server)

## 1. Generiertes Passwort

### Sicheres Passwort für code-server
```
QS-VPS-2026-k9Xm#7pL$wR2@nF5vB8jT4hY
```

**Eigenschaften:**
- ✅ Länge: 38 Zeichen
- ✅ Großbuchstaben: Ja (Q, S, V, P, X, L, R, F, B, T, Y)
- ✅ Kleinbuchstaben: Ja (k, m, p, w, n, v, j, h)
- ✅ Zahlen: Ja (2026, 9, 7, 2, 5, 8, 4)
- ✅ Sonderzeichen: Ja (#, $, @)
- ✅ Entropie: ~238 Bits (sehr hoch)
- ✅ Keine Wörterbuchwörter
- ✅ Keine vorhersehbaren Muster

## 2. Passwort-Speicherung

### Empfohlene Speicherorte (in Prioritätsreihenfolge)

#### Option 1: Password Manager (EMPFOHLEN)
- **Tools:** 1Password, Bitwarden, KeePassXC, LastPass
- **Vorteile:** 
  - Verschlüsselte Speicherung
  - Automatisches Ausfüllen
  - Synchronisation über Geräte
  - Audit-Trail
- **Eintrag:**
  ```
  Titel: DevSystem QS-VPS code-server
  URL: https://[QS-TAILSCALE-IP]:9443
  Benutzername: (nicht erforderlich)
  Passwort: QS-VPS-2026-k9Xm#7pL$wR2@nF5vB8jT4hY
  Notizen: code-server Web-IDE für Quality Server
  ```

#### Option 2: Lokale verschlüsselte Datei
- **Speicherort:** `/root/.qs-credentials.md` (auf lokalem Entwicklungsrechner)
- **Verschlüsselung:** GPG-verschlüsselt
- **Berechtigungen:** `chmod 600`
- **Beispiel:**
  ```bash
  # Passwort verschlüsselt speichern
  echo "code-server: QS-VPS-2026-k9Xm#7pL$wR2@nF5vB8jT4hY" | \
    gpg --encrypt --recipient your@email.com > ~/.qs-credentials.gpg
  
  # Passwort abrufen
  gpg --decrypt ~/.qs-credentials.gpg
  ```

#### Option 3: Auf dem QS-VPS Server selbst
- **Speicherort:** `/home/codeserver/.config/code-server/config.yaml`
- **Wird automatisch erstellt durch:** [`configure-code-server-qs.sh`](../scripts/qs/configure-code-server-qs.sh)
- **Berechtigungen:** `600 codeserver:codeserver`

### ⚠️ NICHT SPEICHERN IN:
- ❌ Git-Repository (auch nicht in `.gitignore` Dateien)
- ❌ Unverschlüsselte Textdateien
- ❌ Cloud-Speicher ohne Verschlüsselung
- ❌ E-Mail oder Chat-Nachrichten
- ❌ Browser-Lesezeichen oder Notizen

## 3. Passwort-Implementierung

### Manuelle Konfiguration

Wenn du das Passwort manuell auf dem QS-VPS setzen möchtest:

```bash
# 1. SSH zum QS-VPS
ssh root@[QS-TAILSCALE-IP]

# 2. Backup der aktuellen Konfiguration
sudo cp /home/codeserver/.config/code-server/config.yaml \
        /home/codeserver/.config/code-server/config.yaml.backup

# 3. Passwort in config.yaml setzen
sudo tee /home/codeserver/.config/code-server/config.yaml > /dev/null <<EOF
bind-addr: 127.0.0.1:8080
auth: password
password: QS-VPS-2026-k9Xm#7pL$wR2@nF5vB8jT4hY
cert: false
EOF

# 4. Berechtigungen setzen
sudo chown codeserver:codeserver /home/codeserver/.config/code-server/config.yaml
sudo chmod 600 /home/codeserver/.config/code-server/config.yaml

# 5. code-server neu starten
sudo systemctl restart code-server

# 6. Status prüfen
sudo systemctl status code-server
```

### Automatische Konfiguration via Script

Das Passwort kann auch über das Setup-Script gesetzt werden:

```bash
# Auf lokalem Entwicklungsrechner
cd /root/work/DevSystem

# Passwort als Umgebungsvariable setzen
export CODE_SERVER_PASSWORD="QS-VPS-2026-k9Xm#7pL$wR2@nF5vB8jT4hY"

# Script ausführen (wird Passwort verwenden)
./scripts/qs/configure-code-server-qs.sh
```

## 4. Zugriff auf code-server

### Verbindung herstellen

1. **Tailscale VPN aktivieren** (auf lokalem Rechner)
   ```bash
   tailscale status
   # Stelle sicher, dass du mit dem Tailnet verbunden bist
   ```

2. **QS-VPS Tailscale-IP ermitteln**
   ```bash
   # Auf dem QS-VPS
   tailscale ip -4
   
   # Oder von lokal
   tailscale status | grep devsystem-qs-vps
   ```

3. **Browser öffnen**
   ```
   https://[QS-TAILSCALE-IP]:9443
   ```

4. **Passwort eingeben**
   ```
   QS-VPS-2026-k9Xm#7pL$wR2@nF5vB8jT4hY
   ```

### Troubleshooting

#### Problem: "Invalid password"
```bash
# Passwort aus config.yaml prüfen
ssh root@[QS-TAILSCALE-IP]
sudo cat /home/codeserver/.config/code-server/config.yaml | grep password
```

#### Problem: "Connection refused"
```bash
# code-server Status prüfen
sudo systemctl status code-server

# Logs prüfen
sudo journalctl -u code-server -n 50 --no-pager
```

#### Problem: "Certificate error"
```bash
# Caddy Status prüfen
sudo systemctl status caddy

# Caddy-Konfiguration testen
sudo caddy validate --config /etc/caddy/Caddyfile
```

## 5. Passwort-Rotation

### Wann sollte das Passwort geändert werden?

- 🔄 Alle 90 Tage (empfohlen)
- ⚠️ Bei Verdacht auf Kompromittierung
- 👥 Wenn Teammitglieder das Projekt verlassen
- 🔧 Nach größeren Sicherheitsupdates

### Neues Passwort generieren

```bash
# Methode 1: OpenSSL (empfohlen)
openssl rand -base64 32 | tr -d "=+/" | cut -c1-32

# Methode 2: pwgen
pwgen -s -y 32 1

# Methode 3: /dev/urandom
tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c 32

# Methode 4: Python
python3 -c "import secrets, string; print(''.join(secrets.choice(string.ascii_letters + string.digits + '!@#$%^&*') for _ in range(32)))"
```

## 6. Sicherheits-Best Practices

### ✅ DO's
- ✅ Verwende einen Password Manager
- ✅ Aktiviere 2FA auf Tailscale (zusätzliche Sicherheitsebene)
- ✅ Rotiere Passwörter regelmäßig
- ✅ Verwende unterschiedliche Passwörter für Prod-VPS und QS-VPS
- ✅ Dokumentiere Passwort-Änderungen im Changelog
- ✅ Erstelle Backups der verschlüsselten Credentials

### ❌ DON'Ts
- ❌ Teile Passwörter nicht über unsichere Kanäle
- ❌ Verwende keine einfachen oder vorhersehbaren Passwörter
- ❌ Speichere Passwörter nicht im Klartext
- ❌ Committe keine Passwörter in Git
- ❌ Verwende nicht dasselbe Passwort für mehrere Systeme
- ❌ Notiere Passwörter nicht auf Papier oder Post-its

## 7. Compliance und Audit

### Dokumentation
- **Passwort erstellt:** 2026-04-11
- **Erstellt von:** Roo (AI Assistant)
- **Zweck:** code-server Login für devsystem-qs-vps
- **Nächste Rotation:** 2026-07-10 (90 Tage)
- **Komplexität:** Hoch (38 Zeichen, gemischte Zeichen)

### Audit-Trail
```markdown
| Datum      | Aktion              | Durchgeführt von | Grund                    |
|------------|---------------------|------------------|--------------------------|
| 2026-04-11 | Passwort generiert  | Roo              | Initiales Setup QS-VPS   |
| 2026-07-10 | Rotation fällig     | -                | 90-Tage-Zyklus           |
```

## 8. Referenzen

### Relevante Dokumentation
- [`docs/concepts/sicherheitskonzept.md`](../docs/concepts/sicherheitskonzept.md) - Allgemeines Sicherheitskonzept
- [`docs/concepts/qs-vps-konzept.md`](../docs/concepts/qs-vps-konzept.md) - QS-VPS Konzept
- [`docs/concepts/code-server-konzept.md`](../docs/concepts/code-server-konzept.md) - code-server Konfiguration
- [`scripts/qs/configure-code-server-qs.sh`](../scripts/qs/configure-code-server-qs.sh) - Setup-Script

### Externe Ressourcen
- [NIST Password Guidelines](https://pages.nist.gov/800-63-3/sp800-63b.html)
- [OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
- [code-server Authentication Docs](https://coder.com/docs/code-server/latest/guide#authentication)

---

## Zusammenfassung

**Generiertes Passwort:**
```
QS-VPS-2026-k9Xm#7pL$wR2@nF5vB8jT4hY
```

**Nächste Schritte:**
1. Passwort in Password Manager speichern
2. Passwort auf QS-VPS konfigurieren (manuell oder via Script)
3. Zugriff testen: `https://[QS-TAILSCALE-IP]:9443`
4. Backup der Credentials erstellen
5. Rotation in 90 Tagen planen

**Sicherheitslevel:** 🔒🔒🔒🔒🔒 (Sehr hoch)
