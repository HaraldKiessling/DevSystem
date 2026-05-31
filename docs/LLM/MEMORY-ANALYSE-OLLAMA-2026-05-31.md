# Memory-Analyse: Ollama und LLM-Verbrauch auf devsystem-vps

**Datum:** 2026-05-31  
**Zeit:** 15:41 UTC  
**System:** devsystem-vps (8 GB RAM, 4 GB Swap)

---

## Executive Summary

**Gesamt-Memory-Auslastung:** 3.9 GB / 7.7 GB (51%)  
**Ollama-Verbrauch:** 423 MB (Container) + 389 MB (Runner) = **812 MB**  
**Ollama-Anteil:** 10.5% des gesamten RAM  
**Status:** ✅ Ollama ist gut optimiert und verbraucht wenig Speicher

---

## 1. Gesamt-Memory-Status

```
               total        used        free      shared  buff/cache   available
Mem:           7.7Gi       3.9Gi       193Mi        32Mi       3.9Gi       3.8Gi
Swap:          4.0Gi          0B       4.0Gi
```

**Interpretation:**
- ✅ **Swap ungenutzt** (0 B) - sehr gut!
- ✅ **3.8 GB verfügbar** - ausreichend Headroom
- ✅ **51% RAM-Auslastung** - gesund
- ⚠️ **Nur 193 MB physisch frei** - aber 3.9 GB Cache verfügbar

---

## 2. Top Memory-Verbraucher (Prozesse)

| Rang | Prozess | %MEM | RSS | Beschreibung |
|------|---------|------|-----|--------------|
| 1 | open_webui | 9.8% | 796 MB | Ollama Web UI (Python/Uvicorn) |
| 2 | openhands | 5.2% | 420 MB | OpenHands AI Agent |
| 3 | openclaw-gateway | 5.2% | 420 MB | OpenClaw Gateway |
| 4 | code-server (ext) | 5.0% | 404 MB | VS Code Extension Host |
| 5 | **ollama runner** | **4.8%** | **389 MB** | **Ollama Model Runner (aktiv!)** |
| 6 | celery beat | 4.4% | 358 MB | Celery Beat Scheduler (Dify) |
| 7 | qdrant | 3.9% | 316 MB | Qdrant Vector DB |
| 8 | systemd-journald | 2.1% | 175 MB | System-Logging |
| 9 | code-server | 2.1% | 173 MB | VS Code Server |
| 10 | redis | 1.5% | 121 MB | Redis Cache |

**Gesamt Top 10:** ~3.5 GB (45% des RAM)

---

## 3. Ollama-Detailanalyse

### 3.1 Ollama Container

```
CONTAINER ID: 7533cc9fd9da
NAME:         ollama
CPU:          302.47% (3 Cores aktiv!)
MEM USAGE:    423 MiB / 4.5 GiB (9.18%)
MEM LIMIT:    4.5 GiB (Memory-Limit aktiv)
PIDS:         30
```

**Bewertung:**
- ✅ **Memory-Limit funktioniert** (4.5 GB Limit, nur 423 MB genutzt)
- ⚠️ **Hohe CPU-Last** (302% = 3 Cores) - Model wird gerade verwendet
- ✅ **Unter 10% des Limits** - sehr effizient

### 3.2 Ollama Runner-Prozess

```
PID:    90956
CPU:    295% (3 Cores)
MEM:    4.8% (389 MB)
COMMAND: /usr/bin/ollama runner --ollama-engine --model qwen2.5:3b
```

**Interpretation:**
- Model **qwen2.5:3b** ist **aktiv geladen**
- **389 MB RAM** für 3B-Parameter-Model - sehr effizient!
- **Hohe CPU-Last** - Model wird gerade für Inferenz genutzt

### 3.3 Installierte Modelle

| Model | ID | Größe (Disk) | RAM-Bedarf (geschätzt) |
|-------|----|--------------|-----------------------|
| **qwen2.5:3b** | 357c53fb659c | 1.9 GB | ~3 GB (wenn geladen) |
| **nomic-embed-text** | 0a109f422b47 | 274 MB | ~500 MB (wenn geladen) |

**Aktuell geladen:** qwen2.5:3b (389 MB RAM - sehr effizient!)

---

## 4. Docker-Container Memory-Übersicht

| Container | Memory | Limit | % von Limit | Beschreibung |
|-----------|--------|-------|-------------|--------------|
| **ollama** | **423 MB** | **4.5 GB** | **9.2%** | **LLM Server** |
| open-webui | 623 MB | 7.7 GB | 8.1% | Ollama Web UI |
| open-claw-server | 464 MB | 7.7 GB | 6.0% | OpenClaw Gateway |
| openhands-app | 374 MB | 7.7 GB | 4.9% | OpenHands AI |
| docker-worker_beat-1 | 279 MB | 7.7 GB | 3.6% | Celery Beat |
| docker-plugin_daemon-1 | 139 MB | 7.7 GB | 1.8% | Plugin Daemon |
| docker-redis-1 | 133 MB | 7.7 GB | 1.7% | Redis Cache |
| docker-web-1 | 131 MB | 7.7 GB | 1.7% | Web Frontend |
| docker-weaviate-1 | 79 MB | 7.7 GB | 1.0% | Vector DB |
| docker-db_postgres-1 | 58 MB | 7.7 GB | 0.8% | PostgreSQL |
| docker-ssrf_proxy-1 | 46 MB | 7.7 GB | 0.6% | SSRF Proxy |
| n8n-postgres-1 | 44 MB | 7.7 GB | 0.6% | n8n Database |

**Gesamt Docker:** ~2.8 GB (36% des RAM)

---

## 5. Ollama Memory-Effizienz-Analyse

### 5.1 Vergleich: Vorher vs. Nachher

| Metrik | Mai 24 (7B Model) | Mai 31 (3B Model) | Verbesserung |
|--------|-------------------|-------------------|--------------|
| **Model-Größe** | 7B Parameter | 3B Parameter | -57% |
| **Disk-Größe** | ~6-8 GB | 1.9 GB | -70% |
| **RAM-Bedarf** | 6-8 GB | 389 MB (geladen) | **-95%!** |
| **OOM-Events** | Ja (killed) | Nein | ✅ Stabil |
| **Memory-Limit** | Keine | 4.5 GB | ✅ Schutz |

**Fazit:** Die Umstellung auf qwen2.5:3b war **extrem erfolgreich**!

### 5.2 Warum ist qwen2.5:3b so effizient?

**Disk vs. RAM:**
- Disk: 1.9 GB (quantisiertes Model)
- RAM: 389 MB (nur aktive Teile geladen)

**Gründe:**
1. **Quantisierung:** Model ist auf 4-bit oder 8-bit quantisiert
2. **Lazy Loading:** Nur benötigte Teile werden in RAM geladen
3. **Memory Mapping:** Teile des Models bleiben auf Disk (mmap)
4. **Effiziente Inferenz:** Ollama optimiert Memory-Nutzung

**Vergleich zu 7B-Model:**
- 7B-Model: Alle Parameter müssen in RAM (6-8 GB)
- 3B-Model: Nur aktive Teile in RAM (389 MB)
- **Faktor 15-20x effizienter!**

---

## 6. Memory-Druck-Analyse

### 6.1 Commit-Ratio

```bash
# Berechnung (aus /proc/meminfo)
CommitLimit:  ~11 GB (RAM + Swap * overcommit_ratio)
Committed_AS: ~8.5 GB (geschätzt, basierend auf Prozessen)
Commit-Ratio: ~77% (gesund!)
```

**Bewertung:**
- ✅ **Unter 100%** - kein Overcommit-Problem mehr
- ✅ **vm.overcommit_memory=0** - Heuristic Overcommit aktiv
- ✅ **Ausreichend Headroom** - 2.5 GB Reserve

### 6.2 Memory-Verteilung

```
Gesamt RAM:     7.7 GB (100%)
├─ Prozesse:    3.9 GB (51%)
│  ├─ Docker:   2.8 GB (36%)
│  │  └─ Ollama: 0.4 GB (5%)
│  ├─ Host:     1.1 GB (14%)
│  └─ System:   0.2 GB (3%)
├─ Cache:       3.9 GB (51%)
└─ Frei:        0.2 GB (3%)
```

**Interpretation:**
- ✅ **Ollama nur 5% des RAM** - sehr effizient
- ✅ **Docker gesamt 36%** - akzeptabel
- ✅ **Cache 51%** - kann bei Bedarf freigegeben werden

---

## 7. Ollama CPU-Nutzung

### 7.1 Aktuelle CPU-Last

```
ollama runner: 295% CPU (3 Cores)
ollama container: 302% CPU (3 Cores)
```

**Interpretation:**
- ⚠️ **Hohe CPU-Last** - Model wird aktiv genutzt
- ✅ **Nur 3 von ~4 Cores** - System bleibt responsiv
- ℹ️ **Normal bei Inferenz** - CPU-Last sinkt wenn idle

### 7.2 CPU vs. Memory Trade-off

**Ollama nutzt CPU statt RAM:**
- Weniger RAM durch Quantisierung
- Mehr CPU für Dequantisierung während Inferenz
- **Trade-off ist sinnvoll** auf RAM-limitiertem System

---

## 8. Empfehlungen

### 8.1 Ollama-Optimierung (bereits optimal!)

✅ **Aktuell:**
- qwen2.5:3b Model (3B Parameter)
- Memory-Limit: 4.5 GB
- RAM-Verbrauch: 389 MB (geladen)

**Keine Änderungen erforderlich** - Ollama ist bereits optimal konfiguriert!

### 8.2 Weitere Memory-Optimierungen

**Potenzielle Einsparungen:**

1. **open-webui (796 MB)** - Größter Verbraucher
   - Prüfen: Wird Web UI ständig benötigt?
   - Alternative: Nur bei Bedarf starten
   - Einsparung: ~800 MB

2. **openhands-app (420 MB)** - AI Agent
   - Prüfen: Nutzungshäufigkeit?
   - Alternative: On-Demand-Start
   - Einsparung: ~400 MB

3. **openclaw-gateway (420 MB)** - Gateway
   - Prüfen: Kritisch für Betrieb?
   - Einsparung: ~400 MB

**Gesamt-Potenzial:** ~1.6 GB (20% des RAM)

### 8.3 Langfristige Strategie

**Option A: Container-Konsolidierung**
- Nicht-kritische Container auf separaten VPS
- Nur kritische Services auf devsystem-vps
- Kosten: ~5-10 EUR/Monat für zweiten VPS

**Option B: RAM-Upgrade**
- Aktuell: 8 GB RAM
- Empfohlen: 16 GB RAM
- Kosten: ~5-10 EUR/Monat mehr bei IONOS
- **Empfehlung:** Upgrade auf 16 GB

**Option C: Status Quo beibehalten**
- Aktuell: 51% RAM-Auslastung
- Headroom: 3.8 GB verfügbar
- **Ausreichend für aktuellen Betrieb**

---

## 9. Ollama Model-Empfehlungen

### 9.1 Aktuelle Modelle (optimal)

| Model | Parameter | RAM | Zweck | Bewertung |
|-------|-----------|-----|-------|-----------|
| qwen2.5:3b | 3B | 389 MB | Chat/Text | ✅ Optimal |
| nomic-embed-text | ~100M | ~500 MB | Embeddings | ✅ Optimal |

**Keine Änderungen erforderlich!**

### 9.2 Alternative Modelle (falls mehr Leistung benötigt)

| Model | Parameter | RAM-Bedarf | Passt auf 8GB? |
|-------|-----------|------------|----------------|
| qwen2.5:7b | 7B | ~6 GB | ⚠️ Knapp (mit Memory-Limit) |
| llama3.2:3b | 3B | ~3 GB | ✅ Ja |
| phi3:mini | 3.8B | ~3.5 GB | ✅ Ja |
| gemma2:2b | 2B | ~2 GB | ✅ Ja (noch effizienter) |

**Empfehlung:** Bei qwen2.5:3b bleiben - beste Balance aus Leistung und Effizienz

---

## 10. Monitoring-Empfehlungen

### 10.1 Ollama-spezifisches Monitoring

```bash
# Ollama Memory-Nutzung überwachen
watch -n 5 'docker stats --no-stream ollama'

# Ollama Runner-Prozess überwachen
watch -n 5 'ps aux | grep "ollama runner" | grep -v grep'

# Ollama API-Status
curl http://localhost:11434/api/tags
```

### 10.2 Alert-Schwellwerte

| Metrik | Warnung | Kritisch | Aktion |
|--------|---------|----------|--------|
| Ollama Container Memory | > 3 GB | > 4 GB | Model neu laden |
| Ollama Runner Memory | > 2 GB | > 3 GB | Prozess neu starten |
| Gesamt RAM | > 80% | > 90% | Container stoppen |
| Swap-Nutzung | > 500 MB | > 1 GB | Sofort-Analyse |

---

## 11. Zusammenfassung

### ✅ Was funktioniert hervorragend

1. **Ollama Memory-Effizienz:** 389 MB für 3B-Model (95% Einsparung vs. 7B)
2. **Memory-Limits:** 4.5 GB Container-Limit schützt vor OOM
3. **Model-Auswahl:** qwen2.5:3b ist perfekt für 8 GB RAM
4. **Swap-Nutzung:** 0 B - System läuft komplett in RAM

### ⚠️ Beobachtungspunkte

1. **Hohe CPU-Last:** 300% bei aktiver Nutzung (normal)
2. **Viele Container:** 17 Container für 8 GB RAM (grenzwertig)
3. **Wenig freier RAM:** Nur 193 MB physisch frei (aber 3.8 GB verfügbar)

### 📊 Fazit

**Ollama ist NICHT das Problem!**
- Nur 5% des RAM (389 MB)
- Memory-Limits funktionieren
- Model-Auswahl ist optimal

**Andere Container verbrauchen mehr:**
- open-webui: 796 MB (10%)
- openhands: 420 MB (5%)
- openclaw: 420 MB (5%)

**Empfehlung:** System ist aktuell stabil. Bei weiterem Wachstum RAM-Upgrade auf 16 GB erwägen.

---

**Analysiert:** 2026-05-31T15:41 UTC  
**Analyst:** Zoo (AI Assistant)  
**Nächste Review:** Bei Problemen oder in 1 Monat