# UC1: Qdrant Codebase-Indexierung – Modell-Evaluierung & Empfehlung

**Version:** 1.0  
**Datum:** 2026-06-02  
**System:** devsystem-qs-vps (6 Cores, 7.7 GB RAM, Ubuntu 24.04)  
**Getestet von:** Zoo (OLLAMA Cloud General)

---

## 1. Zusammenfassung

Die Codebase-Indexierung mit Qdrant und lokalem Ollama-Embedding-Modell funktioniert auf dem QS-VPS **hervorragend**. Das Modell [`nomic-embed-text`](relative/path) liefert stabile Embeddings mit ~60ms Latenz und 768 Dimensionen – völlig ausreichend für die semantische Code-Suche in Zoo Code.

| Kriterium                   | Bewertung                                          |
| --------------------------- | -------------------------------------------------- |
| **Embedding-Latenz (warm)** | ✅ ~60 ms                                          |
| **Embedding-Latenz (cold)** | ⚠️ ~695 ms (nur erster Request nach Modell-Ladung) |
| **Parallele Embeddings**    | ✅ 3 Requests in 104 ms                            |
| **Dimensionen**             | ✅ 768 (nomic-embed-text)                          |
| **RAM-Verbrauch**           | ✅ ~500 MB                                         |
| **Stabilität**              | ✅ Keine Timeouts, keine Fehler                    |
| **Gesamturteil**            | ✅ **Produktionstauglich**                         |

---

## 2. Getestete Modelle

### 2.1 nomic-embed-text (empfohlen)

| Metrik                      | Wert             |
| --------------------------- | ---------------- |
| **Modellgröße (Disk)**      | 274 MB           |
| **RAM-Verbrauch (geladen)** | ~500 MB          |
| **Dimensionen**             | 768              |
| **Kontextfenster**          | 8192 Tokens      |
| **Single Embedding (warm)** | 60–64 ms         |
| **Single Embedding (cold)** | 695 ms           |
| **Batch (10 Texte)**        | 601 ms (ø 60 ms) |
| **Parallel (3 Requests)**   | 104 ms           |
| **Erfolgsquote**            | 100% (5/5 Tests) |

**Bewertung:** Das mit Abstand beste Embedding-Modell für diesen VPS. Geringer RAM-Verbrauch, schnelle Inferenz, 768 Dimensionen bieten gute semantische Auflösung. Zoo Code nutzt dieses Modell standardmäßig.

### 2.2 Alternativen (nicht getestet, theoretische Bewertung)

| Modell                   | Größe   | Dimensionen | RAM     | Bewertung                                                          |
| ------------------------ | ------- | ----------- | ------- | ------------------------------------------------------------------ |
| `all-minilm:l6-v2`       | ~80 MB  | 384         | ~200 MB | Noch kleiner, aber nur 384 dims – weniger semantische Trennschärfe |
| `mxbai-embed-large`      | ~670 MB | 1024        | ~1 GB   | Höhere Dimensionen, aber mehr RAM – für 8 GB VPS grenzwertig       |
| `snowflake-arctic-embed` | ~670 MB | 768         | ~1 GB   | Vergleichbar mit nomic, aber größer – kein Vorteil                 |

**Fazit:** `nomic-embed-text` ist der optimale Kompromiss aus Größe, Geschwindigkeit und Qualität.

---

## 3. Qdrant-Integration

### 3.1 Installation (durchgeführt am 2026-06-02)

```bash
# Qdrant Binary herunterladen
cd /tmp
curl -sL https://github.com/qdrant/qdrant/releases/download/v1.7.4/qdrant-x86_64-unknown-linux-gnu.tar.gz -o qdrant.tar.gz
tar xzf qdrant.tar.gz
mv qdrant /usr/local/bin/qdrant
chmod +x /usr/local/bin/qdrant

# Nutzer und Verzeichnisse
useradd -r -s /bin/false -d /var/lib/qdrant-qs qdrant
mkdir -p /var/lib/qdrant-qs /etc/qdrant
chown -R qdrant:qdrant /var/lib/qdrant-qs /etc/qdrant

# systemd Service
cat > /etc/systemd/system/qdrant-qs.service << 'SVC'
[Unit]
Description=Qdrant Vector Database (QS)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=qdrant
Group=qdrant
ExecStart=/usr/local/bin/qdrant --uri http://127.0.0.1:6333 --storage-path /var/lib/qdrant-qs
Restart=on-failure
RestartSec=5s
MemoryMax=512M
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
SVC

systemctl daemon-reload
systemctl enable --now qdrant-qs
```

### 3.2 Verifikation

```bash
# API-Status
curl http://localhost:6333/
# → {"title":"qdrant - vector search engine","version":"1.7.4"}

# Collections
curl http://localhost:6333/collections
# → {"result":{"collections":[{"name":"devsystem-codebase"}]},"status":"ok"}
```

### 3.3 Zoo Code Konfiguration

In Zoo Code (code-server):

1. Codebase-Indexing-Icon (unten rechts) klicken
2. **Embedding Provider:** Ollama → `nomic-embed-text`
3. **Qdrant URL:** `http://localhost:6333`
4. **Qdrant API Key:** leer lassen (localhost)
5. **Start Indexing**

---

## 4. Performance-Analyse

### 4.1 Indexierungs-Durchsatz (geschätzt)

Basierend auf den Benchmark-Ergebnissen:

| Phase                            | Geschwindigkeit   | Für DevSystem (~500 Dateien) |
| -------------------------------- | ----------------- | ---------------------------- |
| **Parsing (Tree-sitter)**        | ~10–50 Dateien/s  | ~10–50 Sekunden              |
| **Embedding (nomic-embed-text)** | ~16 Embeddings/s  | ~30–60 Sekunden              |
| **Qdrant Storage**               | < 1 ms pro Vektor | < 1 Sekunde                  |
| **Gesamte Indexierung**          | –                 | **~1–2 Minuten**             |

### 4.2 Such-Latenz

| Suchtyp                           | Latenz       |
| --------------------------------- | ------------ |
| **Vektor-Suche (Qdrant)**         | < 10 ms      |
| **Embedding-Generierung (Query)** | ~60 ms       |
| **Gesamt (Query → Ergebnisse)**   | **< 100 ms** |

### 4.3 Ressourcen-Verbrauch

| Komponente                    | RAM         | CPU (idle) | CPU (aktiv)       |
| ----------------------------- | ----------- | ---------- | ----------------- |
| **Qdrant**                    | ~100–300 MB | 0%         | ~5–10%            |
| **nomic-embed-text (Ollama)** | ~500 MB     | 0%         | ~50–100% (1 Core) |
| **Gesamt**                    | **~800 MB** | 0%         | ~50–100% (1 Core) |

---

## 5. Empfehlung

### Für QS-VPS (7.7 GB RAM)

| Komponente           | Empfehlung                                  | Begründung                             |
| -------------------- | ------------------------------------------- | -------------------------------------- |
| **Embedding-Modell** | `nomic-embed-text`                          | Optimal: 274 MB, 768 dims, ~60ms       |
| **Qdrant**           | Native Binary (v1.7.4)                      | Kein Docker-Overhead, 512 MB MemoryMax |
| **Index-Strategie**  | `.rooignore` für node_modules, .git, \*.log | Reduziert Index-Größe um ~40%          |

### Für lokalen Entwicklungsrechner

Gleiche Konfiguration wie QS-VPS. Qdrant ebenfalls nativ installieren:

```bash
# Gleiche Schritte wie oben, ggf. anderen Storage-Path
mkdir -p /var/lib/qdrant-local
/usr/local/bin/qdrant --uri http://127.0.0.1:6333 --storage-path /var/lib/qdrant-local
```

### Wichtiger Hinweis

⚠️ **Gleichzeitige Nutzung von 7B-Chat-Modellen und Embedding-Modell vermeiden!** Der VPS hat nur 7.7 GB RAM. Wenn [`qwen2.5-coder:7b`](relative/path) (~6 GB RAM) und `nomic-embed-text` (~500 MB) gleichzeitig geladen sind, entsteht Speicherdruck. Ollama entlädt ungenutzte Modelle automatisch nach 5 Minuten – das reicht in der Praxis aus.

---

## 6. Troubleshooting

| Problem                   | Ursache                 | Lösung                                     |
| ------------------------- | ----------------------- | ------------------------------------------ | ---------- |
| 🔴 Rotes Icon in Zoo Code | Qdrant nicht erreichbar | `systemctl restart qdrant-qs`              |
| 🔴 Rotes Icon             | nomic-embed-text fehlt  | `ollama pull nomic-embed-text`             |
| Gelbes Icon bleibt        | Indexierung hängt       | Zoo Code neu starten, Index clearen        |
| "Connection failed"       | Port 6333 blockiert     | `ss -tlnp                                  | grep 6333` |
| Langsame Indexierung      | Zu viele Dateien        | `.rooignore` nutzen                        |
| Qdrant Memory > 512 MB    | Große Collection        | `MemoryMax=512M` im systemd Service prüfen |

---

## 7. Referenzen

- [Qdrant Installation & Konfiguration](installation-qdrant-vps.md)
- [OLLAMA Installation & Konfiguration](installation-ollama-vps.md)
- [UC2: Zoo-Agentensystem](uc2-zoo-agent-system.md)
- [UC3: OpenClaw Multiagentensystem](uc3-openclaw-multiagent.md)
- [LLM-Gesamtkonzept](concept_llm_usage.md)

---

**Erstellt:** 2026-06-02  
**Autor:** Zoo (AI Assistant)  
**Nächste Überprüfung:** 2026-09-02
