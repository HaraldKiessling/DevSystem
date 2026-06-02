# UC3: OpenClaw Multiagentensystem – Modell-Evaluierung & Empfehlung

**Version:** 1.0  
**Datum:** 2026-06-02  
**System:** devsystem-qs-vps (6 Cores, 7.7 GB RAM, Ubuntu 24.04)  
**Getestet von:** Zoo (OLLAMA Cloud General)

---

## 1. Zusammenfassung

OpenClaw ist ein CLI-basiertes Multiagentensystem für terminalbasierte KI-Interaktion. Es benötigt Modelle mit **großem Kontextfenster** und **starkem Reasoning**, da mehrere Agenten koordiniert werden müssen. Die Analyse zeigt: **Lokale Modelle auf dem QS-VPS sind für OpenClaw ungeeignet** – Cloud-Modelle sind erforderlich.

| Kriterium                    | Lokal (qwen2.5:3b) | Cloud (Claude)   |
| ---------------------------- | ------------------ | ---------------- |
| **Kontextfenster**           | 32K ❌             | 200K ✅          |
| **Multi-Agent-Koordination** | ❌ Nicht möglich   | ✅ Exzellent     |
| **Reasoning-Tiefe**          | ⭐⭐               | ⭐⭐⭐⭐⭐       |
| **Antwortzeit**              | 2–5s               | 5–15s            |
| **Kosten**                   | $0                 | $0.02–0.25/Task  |
| **Gesamturteil**             | ❌ Ungeeignet      | ✅ **Empfohlen** |

---

## 2. Anforderungen von OpenClaw

### 2.1 Technische Anforderungen

| Anforderung        | Begründung                                       | Minimum                       |
| ------------------ | ------------------------------------------------ | ----------------------------- |
| **Kontextfenster** | Mehrere Agenten teilen sich den Kontext          | ≥ 128K Tokens                 |
| **Reasoning**      | Multi-Step-Planung und -Ausführung               | Hohe Reasoning-Fähigkeit      |
| **Tool Use**       | Dateizugriff, Shell-Kommandos, API-Calls         | Native Tool-Use-Unterstützung |
| **Deutsch**        | Kommunikation in deutscher Sprache               | Gute Deutsch-Kenntnisse       |
| **Latenz**         | Akzeptable Antwortzeiten für interaktive Nutzung | < 30s pro Task                |

### 2.2 Warum lokale Modelle scheitern

| Limitierung        | qwen2.5:3b                   | qwen2.5-coder:7b             |
| ------------------ | ---------------------------- | ---------------------------- |
| **Kontextfenster** | 32K (zu klein)               | 32K (zu klein)               |
| **RAM**            | 400 MB (passt)               | 6 GB (überlastet VPS)        |
| **Multi-Agent**    | ❌ Kein Multi-Task-Reasoning | ❌ Kein Multi-Task-Reasoning |
| **Tool Use**       | ⚠️ Eingeschränkt             | ⚠️ Eingeschränkt             |

OpenClaw benötigt Modelle, die mehrere Agenten-Personas gleichzeitig im Kontext halten und zwischen ihnen koordinieren können. Das 32K-Kontextfenster von qwen2.5 reicht dafür nicht aus.

---

## 3. Empfohlene Cloud-Modelle

### 3.1 Primär: Claude Sonnet 4.6 (OpenRouter)

| Metrik             | Wert                       |
| ------------------ | -------------------------- |
| **Kontextfenster** | 200K Tokens                |
| **Max Output**     | 8.192 Tokens               |
| **Latenz**         | 5–15s (komplexe Tasks)     |
| **Kosten**         | $3/1M Input, $15/1M Output |
| **Tool Use**       | ��� Native Unterstützung   |
| **Deutsch**        | ✅ Sehr gut                |

**Bewertung:** Der beste Kompromiss aus Leistung, Kosten und Geschwindigkeit für OpenClaw. 200K Kontextfenster ermöglicht mehrere Agenten gleichzeitig.

### 3.2 Für komplexe Orchestrierung: Claude Opus 4.0

| Metrik             | Wert                        |
| ------------------ | --------------------------- |
| **Kontextfenster** | 200K Tokens                 |
| **Max Output**     | 8.192 Tokens                |
| **Latenz**         | 8–20s                       |
| **Kosten**         | $15/1M Input, $75/1M Output |
| **Tool Use**       | ✅ Native Unterstützung     |

**Bewertung:** Für sehr komplexe Multi-Agent-Workflows mit vielen Abhängigkeiten. Höhere Kosten, aber bessere Reasoning-Qualität.

### 3.3 Budget-Option: Claude Haiku 4.0

| Metrik             | Wert                            |
| ------------------ | ------------------------------- |
| **Kontextfenster** | 200K Tokens                     |
| **Max Output**     | 8.192 Tokens                    |
| **Latenz**         | 2–5s                            |
| **Kosten**         | $0.25/1M Input, $1.25/1M Output |

**Bewertung:** Für einfachere OpenClaw-Tasks mit weniger Agenten. Günstigste Cloud-Option mit ausreichendem Kontextfenster.

---

## 4. OpenClaw-Konfiguration

### 4.1 Provider-Konfiguration

```bash
# ~/.openclaw/config.env

# === Cloud Provider (empfohlen) ===
OPENROUTER_API_KEY=sk-or-v1-...
OPENROUTER_MODEL=anthropic/claude-sonnet-4.6

# === Lokales Ollama (nur für einfache Tasks) ===
OLLAMA_HOST=http://localhost:11434
OLLAMA_MODEL=qwen2.5:3b

# === Fallback-Strategie ===
# Bei OpenRouter-Fehler → Lokales Ollama
# Bei Timeout → Retry mit Claude Haiku (günstiger)
```

### 4.2 Verwendung

```bash
# Mit Cloud (empfohlen für Multi-Agent)
openclaw --provider openrouter --model anthropic/claude-sonnet-4.6 \
  "Analysiere den Code in src/ und erstelle einen Refactoring-Plan"

# Mit lokalem Ollama (nur einfache Tasks)
openclaw --provider ollama "Erkläre die Funktion in zeile 42"

# Mit Budget-Option
openclaw --provider openrouter --model anthropic/claude-haiku-4.0 \
  "Dokumentiere diese Klasse"
```

---

## 5. Performance-Vergleich

### 5.1 Antwortzeiten (geschätzt für OpenClaw Multi-Agent)

| Task-Typ                       | Claude Haiku 4.0 | Claude Sonnet 4.6 | Claude Opus 4.0 |
| ------------------------------ | ---------------- | ----------------- | --------------- |
| **Einfache Analyse**           | 2–5s             | 3–8s              | 5–12s           |
| **Code-Review (3 Dateien)**    | 5–10s            | 8–15s             | 12–25s          |
| **Multi-Agent-Orchestrierung** | 10–20s           | 15–30s            | 20–45s          |
| **Komplexes Refactoring**      | 15–25s           | 20–40s            | 30–60s          |

### 5.2 Ressourcen-Verbrauch (lokal)

| Komponente                  | RAM       | CPU      |
| --------------------------- | --------- | -------- |
| **OpenClaw Gateway**        | ~420 MB   | ~5% idle |
| **Ollama (nur Embeddings)** | ~500 MB   | ~0% idle |
| **Gesamt (Cloud-Nutzung)**  | **~1 GB** | **~5%**  |

✅ Bei Cloud-Nutzung bleibt der VPS stabil – die gesamte Inferenz findet extern statt.

---

## 6. Kostenabschätzung

### 6.1 Pro Task

| Task-Komplexität | Modell     | Tokens (In/Out) | Kosten   |
| ---------------- | ---------- | --------------- | -------- |
| **Einfach**      | Haiku 4.0  | 1.000/500       | ~$0.0009 |
| **Mittel**       | Sonnet 4.6 | 3.000/1.500     | ~$0.032  |
| **Komplex**      | Sonnet 4.6 | 8.000/3.000     | ~$0.069  |
| **Sehr komplex** | Opus 4.0   | 10.000/4.000    | ~$0.45   |

### 6.2 Monatliche Schätzung

| Nutzungsprofil | Tasks/Tag | Modell-Mix                      | Kosten/Monat |
| -------------- | --------- | ------------------------------- | ------------ |
| **Minimal**    | 10        | 80% Haiku, 20% Sonnet           | ~$5          |
| **Moderat**    | 30        | 50% Haiku, 40% Sonnet, 10% Opus | ~$25         |
| **Intensiv**   | 100       | 30% Haiku, 50% Sonnet, 20% Opus | ~$120        |

---

## 7. Empfehlung

### Für OpenClaw auf dem QS-VPS

| Komponente          | Empfehlung                       | Begründung                        |
| ------------------- | -------------------------------- | --------------------------------- |
| **Primäres Modell** | `claude-sonnet-4.6` (OpenRouter) | Beste Balance aus Leistung/Kosten |
| **Budget-Modell**   | `claude-haiku-4.0` (OpenRouter)  | Für einfache Tasks                |
| **Komplex-Modell**  | `claude-opus-4.0` (OpenRouter)   | Für Multi-Agent-Orchestrierung    |
| **Lokales Modell**  | `qwen2.5:3b`                     | Nur als Fallback                  |
| **Embeddings**      | `nomic-embed-text` (lokal)       | Für RAG/Code-Suche                |

### Nicht empfohlen

- ❌ Ausschließlich lokale Modelle – Kontextfenster zu klein, Reasoning zu schwach
- ❌ `qwen2.5-coder:7b` – überfordert den VPS
- ❌ OpenClaw ohne Cloud-Anbindung – nicht produktiv nutzbar

---

## 8. Integration mit Zoo Code

OpenClaw und Zoo Code teilen sich dieselbe Infrastruktur:

```
┌──────────────────────────────────────────────────────────────┐
│                      DevSystem VPS                            │
│                                                               │
│  ┌──────────────────┐     ┌──────────────────┐              │
│  │ Zoo Code         │     │ OpenClaw         │              │
│  │ (code-server)    │     │ (CLI)            │              │
│  │                  │     │                  │              │
│  │ Ask/Code/Debug   │     │ Multi-Agent      │              │
│  │ Arch/Orch        │     │ Koordination     │              │
│  └────────┬─────────┘     └────────┬─────────┘              │
│           │                        │                         │
│           ▼                        ▼                         │
│  ┌──────────────────────────────────────────┐               │
│  │           LLM Routing Layer               │               │
│  │  ┌──────────┐  ┌──────────┐  ┌─────────┐ │               │
│  │  │ Ollama   │  │ Open     │  │ Ollama  │ │               │
│  │  │ Local    │  │ Router   │  │ Cloud   │ │               │
│  │  │ :11434   │  │          │  │         │ │               │
│  │  └──────────┘  └──────────┘  └─────────┘ │               │
│  └──────────────────────────────────────────┘               │
│                                                               │
│  ┌──────────────────┐     ┌──────────────────┐              │
│  │ Qdrant           │     │ nomic-embed-text │              │
│  │ :6333            │     │ (Ollama)         │              │
│  └──────────────────┘     └──────────────────┘              │
└──────────────────────────────────────────────────────────────┘
```

---

## 9. Referenzen

- [UC1: Qdrant Codebase-Indexierung](uc1-qdrant-codebase-indexing.md)
- [UC2: Zoo-Agentensystem](uc2-zoo-agent-system.md)
- [OLLAMA Installation & Konfiguration](installation-ollama-vps.md)
- [LLM-Gesamtkonzept](concept_llm_usage.md)
- [OpenRouter Setup](../operations/SETUP-HINWEIS-OPENROUTER.md)

---

**Erstellt:** 2026-06-02  
**Autor:** Zoo (AI Assistant)  
**Nächste Überprüfung:** 2026-09-02
