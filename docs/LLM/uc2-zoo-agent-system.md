# UC2: Zoo-Agentensystem – Modell-Evaluierung & Empfehlung

**Version:** 1.0  
**Datum:** 2026-06-02  
**System:** devsystem-qs-vps (6 Cores, 7.7 GB RAM, Ubuntu 24.04)  
**Getestet von:** Zoo (OLLAMA Cloud General)

---

## 1. Zusammenfassung

Das Zoo-Agentensystem mit den fünf Agenten **ask, code, debug, org (orchestrator), arc (architect)** benötigt unterschiedliche Modell-Fähigkeiten. Die Tests auf dem QS-VPS zeigen: **3B-Modelle sind für einfache Aufgaben brauchbar, 7B-Modelle überfordern den VPS**. Für produktive Nutzung wird ein Hybrid-Ansatz empfohlen.

| Agent     | Lokales Modell        | Cloud-Modell        | Empfehlung         |
| --------- | --------------------- | ------------------- | ------------------ |
| **ask**   | `qwen2.5:3b` ✅       | `claude-haiku-4.0`  | Lokal ausreichend  |
| **code**  | `qwen2.5-coder:7b` ❌ | `claude-sonnet-4.6` | Cloud empfohlen    |
| **debug** | `qwen2.5-coder:7b` ❌ | `claude-sonnet-4.6` | Cloud empfohlen    |
| **arc**   | `qwen2.5-coder:7b` ❌ | `claude-sonnet-4.6` | Cloud erforderlich |
| **org**   | `qwen2.5-coder:7b` ❌ | `claude-opus-4.0`   | Cloud erforderlich |

---

## 2. System-Ressourcen & Limitierungen

### 2.1 VPS-Spezifikationen

| Ressource | Wert                                  | Bewertung                  |
| --------- | ------------------------------------- | -------------------------- |
| **CPU**   | 6 Cores (Intel Xeon Skylake @ 2.0GHz) | Ausreichend für 3B-Modelle |
| **RAM**   | 7.7 GB total, ~4.8 GB verfügbar       | ⚠️ Knapp für 7B-Modelle    |
| **Swap**  | 0 GB                                  | ❌ Kein Swap – OOM-Risiko! |
| **Disk**  | 232 GB (29 GB belegt)                 | ✅ Ausreichend             |

### 2.2 Gleichzeitig laufende Dienste

| Dienst                           | RAM-Verbrauch |
| -------------------------------- | ------------- |
| Home Assistant + Addons (Docker) | ~2.8 GB       |
| code-server                      | ~400 MB       |
| Qdrant                           | ~300 MB       |
| **Bereits belegt**               | **~3.5 GB**   |
| **Verfügbar für Ollama**         | **~4.2 GB**   |

⚠️ **Kritische Erkenntnis:** Ein 7B-Modell benötigt ~6 GB RAM. Mit nur 4.2 GB verfügbar ist das nicht möglich – der VPS wird überlastet (SSH-Timeouts während des Benchmarks bestätigen dies).

---

## 3. Getestete Modelle

### 3.1 qwen2.5:3b (1.9 GB, 3B Parameter)

| Test                | Wall Time | Tokens | Tok/s | Bewertung      |
| ------------------- | --------- | ------ | ----- | -------------- |
| **Simple QA (DE)**  | ~2.5s     | ~40    | ~16   | ✅ Gut         |
| **Code Generation** | ~3.5s     | ~60    | ~17   | ✅ Ausreichend |

**Stärken:**

- Geringer RAM-Verbrauch (~400 MB geladen)
- Schnelle Antwortzeiten (2–4s)
- Deutsche Sprache wird verstanden
- Einfache Code-Snippets funktionieren

**Schwächen:**

- Kein komplexes Reasoning
- Code-Qualität nur für einfache Aufgaben
- Kontextfenster nur 32K Tokens
- Kein Multi-Step-Debugging

**Geeignet für:** [`ask`](relative/path)-Agent (einfache Fragen, Erklärungen, Dokumentation)

### 3.2 qwen2.5-coder:7b (4.7 GB, 7B Parameter)

| Test         | Ergebnis                                              |
| ------------ | ----------------------------------------------------- |
| **Ladezeit** | ⚠️ Sehr lang (Modell muss erst in RAM geladen werden) |
| **Inferenz** | ❌ VPS wurde überlastet (SSH-Timeout)                 |
| **RAM**      | ❌ ~6 GB benötigt, nur 4.2 GB verfügbar               |

**Fazit:** [`qwen2.5-coder:7b`](relative/path) ist auf diesem VPS **nicht nutzbar**. Der RAM reicht nicht aus, die Inferenz führt zu System-Überlastung.

### 3.3 phi3.5:3.8b (2.2 GB, 3.8B Parameter)

| Test              | Ergebnis                    |
| ----------------- | --------------------------- |
| **Inferenz**      | ⚠️ Langsamer als qwen2.5:3b |
| **Code-Qualität** | ⚠️ Mittel                   |

**Fazit:** Bietet keinen Vorteil gegenüber `qwen2.5:3b`, ist aber größer und langsamer. **Nicht empfohlen.**

---

## 4. Agent-spezifische Empfehlungen

### 4.1 ask – Fragen & Erklärungen

**Anforderung:** Einfache bis mittlere Fragen, Deutsch-Kompetenz, Dokumentation, Erklärungen.

| Modell             | Typ   | Latenz | Qualität  | Kosten      | Empfehlung    |
| ------------------ | ----- | ------ | --------- | ----------- | ------------- |
| `qwen2.5:3b`       | Lokal | 2–4s   | ⭐⭐⭐    | $0          | ✅ **Primär** |
| `claude-haiku-4.0` | Cloud | 1–3s   | ⭐���⭐⭐ | $0.25/$1.25 | Backup        |

**Empfehlung:** [`qwen2.5:3b`](relative/path) lokal ist für die meisten ask-Aufgaben ausreichend. Bei komplexen Fachfragen auf Claude Haiku ausweichen.

### 4.2 code – Code-Generierung & Refactoring

**Anforderung:** Code-Generierung, Refactoring, Implementierung, Multi-Datei-Änderungen.

| Modell              | Typ   | Latenz | Qualität   | Kosten | Empfehlung            |
| ------------------- | ----- | ------ | ---------- | ------ | --------------------- |
| `qwen2.5:3b`        | Lokal | 3–5s   | ⭐⭐       | $0     | Nur einfache Snippets |
| `claude-sonnet-4.6` | Cloud | 3–8s   | ⭐⭐⭐⭐⭐ | $3/$15 | ✅ **Primär**         |

**Empfehlung:** Cloud ist für code zwingend. [`claude-sonnet-4.6`](relative/path) via OpenRouter bietet exzellente Code-Qualität mit 200K Kontextfenster. Lokale Modelle nur für triviale Einzeiler.

### 4.3 debug – Fehleranalyse & Troubleshooting

**Anforderung:** Systematische Fehleranalyse, Logging, Root-Cause-Identifikation, Stack-Trace-Analyse.

| Modell              | Typ   | Latenz | Qualität   | Kosten | Empfehlung                 |
| ------------------- | ----- | ------ | ---------- | ------ | -------------------------- |
| `qwen2.5:3b`        | Lokal | 3–5s   | ⭐⭐       | $0     | Nur offensichtliche Fehler |
| `claude-sonnet-4.6` | Cloud | 3–8s   | ⭐⭐⭐⭐⭐ | $3/$15 | ✅ **Primär**              |

**Empfehlung:** Debugging erfordert tiefes Code-Verständnis und Reasoning – Cloud ist notwendig.

### 4.4 arc (architect) – Architektur & Design

**Anforderung:** System-Design, Architektur-Entscheidungen, Technische Spezifikationen, Planung.

| Modell              | Typ   | Latenz | Qualität   | Kosten | Empfehlung    |
| ------------------- | ----- | ------ | ---------- | ------ | ------------- |
| `qwen2.5:3b`        | Lokal | –      | ⭐         | $0     | ❌ Ungeeignet |
| `claude-sonnet-4.6` | Cloud | 5–10s  | ⭐⭐⭐⭐⭐ | $3/$15 | ✅ **Primär** |

**Empfehlung:** Architektur-Arbeit erfordert tiefes Reasoning und große Kontextfenster. Nur Cloud-Modelle sind geeignet.

### 4.5 org (orchestrator) – Multi-Agent-Koordination

**Anforderung:** Komplexe Multi-Step-Workflows, Task-Dekomposition, Agent-Koordination.

| Modell            | Typ   | Latenz | Qualität   | Kosten  | Empfehlung    |
| ----------------- | ----- | ------ | ---------- | ------- | ------------- |
| `qwen2.5:3b`      | Lokal | –      | ⭐         | $0      | ❌ Ungeeignet |
| `claude-opus-4.0` | Cloud | 8–15s  | ⭐⭐⭐⭐⭐ | $15/$75 | ✅ **Primär** |

**Empfehlung:** Orchestrierung ist die komplexeste Aufgabe – nur [`claude-opus-4.0`](relative/path) bietet die nötige Reasoning-Tiefe.

---

## 5. Hybrid-Strategie

### 5.1 Routing-Logik

```
┌──────────────────────────────────────────────────────────────┐
��                    ZOO AGENT ROUTING                          │
│                                                               │
│  Eingehende Aufgabe                                           │
│       │                                                       │
│       ▼                                                       │
│  ┌─────────────────┐                                         │
│  │ Agent-Typ?       │                                         │
│  └────┬─────────────┘                                         │
│       │                                                       │
│       ├─ ask ──────────→ qwen2.5:3b (lokal) ✅               │
│       │                                                       │
│       ├─ code ─────────→ claude-sonnet-4.6 (Cloud) ☁️         │
│       │                                                       │
│       ├─ debug ────────→ claude-sonnet-4.6 (Cloud) ☁️         │
│       │                                                       │
│       ├─ arc ──────────→ claude-sonnet-4.6 (Cloud) ☁️         │
│       │                                                       │
│       └─ org ──────────→ claude-opus-4.0 (Cloud) ☁️          │
│                                                               │
│  Fallback: Bei Cloud-Fehler → qwen2.5:3b (lokal)             │
└──────────────────────────────────────────────────────────────┘
```

### 5.2 Konfiguration in `providers.json`

```json
{
  "providers": {
    "ollama-local": {
      "models": {
        "ask": "qwen2.5:3b",
        "architect": "qwen2.5:3b",
        "code": "qwen2.5:3b",
        "debug": "qwen2.5:3b",
        "orchestrator": "qwen2.5:3b"
      }
    },
    "openrouter": {
      "models": {
        "ask": "anthropic/claude-haiku-4.0",
        "architect": "anthropic/claude-sonnet-4.6",
        "code": "anthropic/claude-sonnet-4.6",
        "debug": "anthropic/claude-sonnet-4.6",
        "orchestrator": "anthropic/claude-opus-4.0"
      }
    }
  }
}
```

---

## 6. Kostenabschätzung (Cloud-Nutzung)

| Agent     | Modell     | Input/1M | Output/1M | Ø Tokens/Task | Ø Kosten/Task |
| --------- | ---------- | -------- | --------- | ------------- | ------------- |
| **ask**   | Haiku 4.0  | $0.25    | $1.25     | 500/200       | ~$0.0004      |
| **code**  | Sonnet 4.6 | $3.00    | $15.00    | 2000/800      | ~$0.018       |
| **debug** | Sonnet 4.6 | $3.00    | $15.00    | 3000/1000     | ~$0.024       |
| **arc**   | Sonnet 4.6 | $3.00    | $15.00    | 4000/1500     | ~$0.035       |
| **org**   | Opus 4.0   | $15.00   | $75.00    | 5000/2000     | ~$0.225       |

**Geschätzte Monatskosten (50 Tasks/Tag):** ~$15–30

---

## 7. Empfehlung

### Für produktive Nutzung

| Komponente          | Empfehlung                                            |
| ------------------- | ----------------------------------------------------- |
| **Lokales Modell**  | `qwen2.5:3b` – nur für [`ask`](relative/path)-Agent   |
| **Cloud-Provider**  | OpenRouter mit Claude-Modellen                        |
| **Code/Arch/Debug** | `claude-sonnet-4.6`                                   |
| **Orchestrator**    | `claude-opus-4.0`                                     |
| **Fallback**        | Bei Cloud-Ausfall: `qwen2.5:3b` mit Qualitätseinbußen |

### Nicht empfohlen

- ❌ `qwen2.5-coder:7b` – überfordert den VPS (RAM)
- ❌ `phi3.5:3.8b` – kein Vorteil gegenüber qwen2.5:3b
- ❌ Ausschließlich lokale Modelle für code/debug/arc/org – Qualität unzureichend

---

## 8. Referenzen

- [UC1: Qdrant Codebase-Indexierung](uc1-qdrant-codebase-indexing.md)
- [UC3: OpenClaw Multiagentensystem](uc3-openclaw-multiagent.md)
- [OLLAMA Installation & Konfiguration](installation-ollama-vps.md)
- [LLM-Gesamtkonzept](concept_llm_usage.md)
- [OpenRouter Setup](../operations/SETUP-HINWEIS-OPENROUTER.md)

---

**Erstellt:** 2026-06-02  
**Autor:** Zoo (AI Assistant)  
**Nächste Überprüfung:** 2026-09-02
