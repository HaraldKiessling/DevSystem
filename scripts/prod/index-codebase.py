#!/usr/bin/env python3
"""
index-codebase.py - DevSystem Codebase Indexierung mit Qdrant + Ollama

Indexiert alle Markdown- und Shell-Dateien des DevSystem-Repos in Qdrant
für semantische Suche und RAG-Anwendungen.

Verwendung:
    python3 scripts/prod/index-codebase.py [--reset] [--dry-run] [--path PATH]

Optionen:
    --reset     Collection löschen und neu erstellen
    --dry-run   Nur anzeigen was indexiert würde
    --path      Pfad zum Repository (Standard: aktuelles Verzeichnis)

Voraussetzungen:
    - Ollama läuft auf localhost:11434 mit nomic-embed-text
    - Qdrant läuft auf localhost:6333
    - Nur Standard-Library (keine externen Pakete nötig)
"""

import json
import os
import sys
import time
import urllib.request
import urllib.error
import hashlib
import argparse
from pathlib import Path

# --- Konfiguration -----------------------------------------------------------
OLLAMA_URL = "http://localhost:11434"
QDRANT_URL = "http://localhost:6333"
COLLECTION_NAME = "devsystem-codebase"
EMBEDDING_MODEL = "nomic-embed-text"
EMBEDDING_DIM = 768  # nomic-embed-text Dimensionen

# Dateitypen die indexiert werden
INCLUDE_EXTENSIONS = {".md", ".sh", ".py", ".yml", ".yaml", ".json"}
EXCLUDE_DIRS = {".git", "node_modules", "__pycache__", ".Roo"}
EXCLUDE_FILES = {"*.log", "*.tmp"}

# Chunk-Größe für lange Dokumente
MAX_CHUNK_SIZE = 2000  # Zeichen pro Chunk
CHUNK_OVERLAP = 200    # Überlappung zwischen Chunks

# --- HTTP-Hilfsfunktionen ----------------------------------------------------
def http_request(url: str, method: str = "GET", data: dict = None, timeout: int = 60) -> dict:
    """Einfache HTTP-Anfrage ohne externe Bibliotheken."""
    body = json.dumps(data).encode("utf-8") if data else None
    headers = {"Content-Type": "application/json"}

    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8") if e.fp else ""
        raise RuntimeError(f"HTTP {e.code} für {url}: {error_body[:200]}")
    except urllib.error.URLError as e:
        raise RuntimeError(f"Verbindungsfehler zu {url}: {e.reason}")


# --- Ollama Embedding --------------------------------------------------------
def get_embedding(text: str) -> list:
    """Embedding via Ollama nomic-embed-text generieren."""
    result = http_request(
        f"{OLLAMA_URL}/api/embeddings",
        method="POST",
        data={"model": EMBEDDING_MODEL, "prompt": text},
        timeout=30
    )
    return result.get("embedding", [])


# --- Qdrant Operationen ------------------------------------------------------
def qdrant_collection_exists() -> bool:
    """Prüft ob die Collection bereits existiert."""
    try:
        http_request(f"{QDRANT_URL}/collections/{COLLECTION_NAME}")
        return True
    except RuntimeError:
        return False


def qdrant_create_collection():
    """Erstellt die Qdrant Collection für die Codebase."""
    print(f"Erstelle Qdrant Collection '{COLLECTION_NAME}'...")
    http_request(
        f"{QDRANT_URL}/collections/{COLLECTION_NAME}",
        method="PUT",
        data={
            "vectors": {
                "size": EMBEDDING_DIM,
                "distance": "Cosine"
            },
            "optimizers_config": {
                "default_segment_number": 2
            },
            "replication_factor": 1
        }
    )
    print(f"✓ Collection '{COLLECTION_NAME}' erstellt")


def qdrant_delete_collection():
    """Löscht die Collection."""
    print(f"Lösche Collection '{COLLECTION_NAME}'...")
    try:
        http_request(
            f"{QDRANT_URL}/collections/{COLLECTION_NAME}",
            method="DELETE"
        )
        print(f"✓ Collection gelöscht")
    except RuntimeError as e:
        print(f"  Hinweis: {e}")


def qdrant_upsert_points(points: list):
    """Fügt Punkte in Qdrant ein."""
    http_request(
        f"{QDRANT_URL}/collections/{COLLECTION_NAME}/points",
        method="PUT",
        data={"points": points},
        timeout=60
    )


def qdrant_get_count() -> int:
    """Gibt die Anzahl der Punkte in der Collection zurück."""
    result = http_request(f"{QDRANT_URL}/collections/{COLLECTION_NAME}")
    return result.get("result", {}).get("points_count", 0)


# --- Datei-Verarbeitung ------------------------------------------------------
def should_index_file(path: Path) -> bool:
    """Prüft ob eine Datei indexiert werden soll."""
    # Ausgeschlossene Verzeichnisse
    for part in path.parts:
        if part in EXCLUDE_DIRS:
            return False

    # Nur bestimmte Dateitypen
    return path.suffix.lower() in INCLUDE_EXTENSIONS


def chunk_text(text: str, file_path: str) -> list[dict]:
    """Teilt langen Text in überlappende Chunks auf."""
    if len(text) <= MAX_CHUNK_SIZE:
        return [{"text": text, "chunk_index": 0, "total_chunks": 1}]

    chunks = []
    start = 0
    chunk_index = 0

    while start < len(text):
        end = start + MAX_CHUNK_SIZE

        # Am Zeilenende aufteilen wenn möglich
        if end < len(text):
            newline_pos = text.rfind("\n", start, end)
            if newline_pos > start + MAX_CHUNK_SIZE // 2:
                end = newline_pos + 1

        chunk = text[start:end].strip()
        if chunk:
            chunks.append({
                "text": chunk,
                "chunk_index": chunk_index,
                "total_chunks": -1  # wird später gesetzt
            })
            chunk_index += 1

        start = end - CHUNK_OVERLAP
        if start >= len(text):
            break

    # total_chunks setzen
    for chunk in chunks:
        chunk["total_chunks"] = len(chunks)

    return chunks


def generate_point_id(file_path: str, chunk_index: int) -> int:
    """Generiert eine eindeutige numerische ID für einen Punkt."""
    hash_str = f"{file_path}:{chunk_index}"
    return int(hashlib.md5(hash_str.encode()).hexdigest()[:8], 16)


def collect_files(repo_path: Path) -> list[Path]:
    """Sammelt alle zu indexierenden Dateien."""
    files = []
    for path in repo_path.rglob("*"):
        if path.is_file() and should_index_file(path.relative_to(repo_path)):
            files.append(path)
    return sorted(files)


# --- Hauptprogramm -----------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="DevSystem Codebase Indexierung")
    parser.add_argument("--reset", action="store_true", help="Collection neu erstellen")
    parser.add_argument("--dry-run", action="store_true", help="Nur anzeigen, nicht indexieren")
    parser.add_argument("--path", default=".", help="Pfad zum Repository")
    parser.add_argument("--batch-size", type=int, default=10, help="Punkte pro Batch")
    args = parser.parse_args()

    repo_path = Path(args.path).resolve()
    print(f"\n{'='*60}")
    print(f"DevSystem Codebase Indexierung")
    print(f"{'='*60}")
    print(f"Repository: {repo_path}")
    print(f"Ollama:     {OLLAMA_URL} (Modell: {EMBEDDING_MODEL})")
    print(f"Qdrant:     {QDRANT_URL} (Collection: {COLLECTION_NAME})")
    print(f"Dry-Run:    {args.dry_run}")
    print()

    # --- Verbindungen prüfen -------------------------------------------------
    print("Prüfe Verbindungen...")

    try:
        ollama_info = http_request(f"{OLLAMA_URL}/api/version")
        print(f"✓ Ollama: v{ollama_info.get('version', '?')}")
    except RuntimeError as e:
        print(f"✗ Ollama nicht erreichbar: {e}")
        sys.exit(1)

    try:
        qdrant_info = http_request(f"{QDRANT_URL}/")
        print(f"✓ Qdrant: v{qdrant_info.get('version', '?')}")
    except RuntimeError as e:
        print(f"✗ Qdrant nicht erreichbar: {e}")
        sys.exit(1)

    # Embedding-Modell prüfen
    try:
        models = http_request(f"{OLLAMA_URL}/api/tags")
        model_names = [m["name"] for m in models.get("models", [])]
        if not any(EMBEDDING_MODEL in m for m in model_names):
            print(f"✗ Modell '{EMBEDDING_MODEL}' nicht gefunden. Verfügbar: {model_names}")
            sys.exit(1)
        print(f"✓ Modell: {EMBEDDING_MODEL}")
    except RuntimeError as e:
        print(f"✗ Modell-Check fehlgeschlagen: {e}")
        sys.exit(1)

    print()

    # --- Collection vorbereiten ----------------------------------------------
    if not args.dry_run:
        if args.reset and qdrant_collection_exists():
            qdrant_delete_collection()
            time.sleep(1)

        if not qdrant_collection_exists():
            qdrant_create_collection()
        else:
            count = qdrant_get_count()
            print(f"✓ Collection '{COLLECTION_NAME}' existiert bereits ({count} Punkte)")
            if not args.reset:
                print("  Verwende --reset um neu zu indexieren")

    # --- Dateien sammeln -----------------------------------------------------
    print(f"\nSammle Dateien aus: {repo_path}")
    files = collect_files(repo_path)
    print(f"Gefunden: {len(files)} Dateien")

    if args.dry_run:
        print("\n[DRY-RUN] Würde folgende Dateien indexieren:")
        for f in files[:20]:
            rel = f.relative_to(repo_path)
            print(f"  {rel}")
        if len(files) > 20:
            print(f"  ... und {len(files) - 20} weitere")
        return

    # --- Indexierung ---------------------------------------------------------
    print(f"\nStarte Indexierung...")
    total_chunks = 0
    total_errors = 0
    batch = []
    start_time = time.time()

    for file_idx, file_path in enumerate(files):
        rel_path = str(file_path.relative_to(repo_path))

        try:
            text = file_path.read_text(encoding="utf-8", errors="ignore")
            if not text.strip():
                continue

            chunks = chunk_text(text, rel_path)

            for chunk_data in chunks:
                chunk_text_content = chunk_data["text"]
                chunk_index = chunk_data["chunk_index"]
                total_chunks_in_file = chunk_data["total_chunks"]

                # Embedding generieren
                embedding = get_embedding(chunk_text_content)
                if not embedding:
                    print(f"  ⚠ Kein Embedding für {rel_path}:{chunk_index}")
                    continue

                # Punkt erstellen
                point_id = generate_point_id(rel_path, chunk_index)
                point = {
                    "id": point_id,
                    "vector": embedding,
                    "payload": {
                        "file_path": rel_path,
                        "file_type": file_path.suffix.lstrip("."),
                        "chunk_index": chunk_index,
                        "total_chunks": total_chunks_in_file,
                        "text": chunk_text_content[:500],  # Vorschau
                        "full_text": chunk_text_content,
                        "indexed_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
                    }
                }
                batch.append(point)
                total_chunks += 1

                # Batch hochladen
                if len(batch) >= args.batch_size:
                    qdrant_upsert_points(batch)
                    batch = []

            # Fortschritt anzeigen
            if (file_idx + 1) % 10 == 0 or file_idx == len(files) - 1:
                elapsed = time.time() - start_time
                rate = total_chunks / elapsed if elapsed > 0 else 0
                print(f"  [{file_idx+1}/{len(files)}] {total_chunks} Chunks | {rate:.1f} Chunks/s | Fehler: {total_errors}")

        except Exception as e:
            print(f"  ✗ Fehler bei {rel_path}: {e}")
            total_errors += 1

    # Letzten Batch hochladen
    if batch:
        qdrant_upsert_points(batch)

    # --- Zusammenfassung -----------------------------------------------------
    elapsed = time.time() - start_time
    final_count = qdrant_get_count()

    print(f"\n{'='*60}")
    print(f"Indexierung abgeschlossen!")
    print(f"{'='*60}")
    print(f"Dateien verarbeitet:  {len(files)}")
    print(f"Chunks indexiert:     {total_chunks}")
    print(f"Fehler:               {total_errors}")
    print(f"Punkte in Qdrant:     {final_count}")
    print(f"Dauer:                {elapsed:.1f}s")
    print(f"Durchsatz:            {total_chunks/elapsed:.1f} Chunks/s")
    print()
    print(f"Collection: {COLLECTION_NAME}")
    print(f"Qdrant URL: {QDRANT_URL}/collections/{COLLECTION_NAME}")
    print()

    # Beispiel-Suche
    print("Beispiel-Suche: 'Tailscale VPN Konfiguration'")
    try:
        query_embedding = get_embedding("Tailscale VPN Konfiguration")
        results = http_request(
            f"{QDRANT_URL}/collections/{COLLECTION_NAME}/points/search",
            method="POST",
            data={
                "vector": query_embedding,
                "limit": 3,
                "with_payload": True
            }
        )
        for i, hit in enumerate(results.get("result", [])[:3]):
            score = hit.get("score", 0)
            payload = hit.get("payload", {})
            print(f"  {i+1}. [{score:.3f}] {payload.get('file_path', '?')} (Chunk {payload.get('chunk_index', 0)})")
            print(f"     {payload.get('text', '')[:100]}...")
    except Exception as e:
        print(f"  Suche fehlgeschlagen: {e}")


if __name__ == "__main__":
    main()
