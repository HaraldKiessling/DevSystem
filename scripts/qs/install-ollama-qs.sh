#!/bin/bash
# =============================================================================
# install-ollama-qs.sh - Ollama Installation auf QS-VPS mit phi3.5:3.8b
# =============================================================================
# Zweck:    Installiert Ollama mit phi3.5:3.8b LLM auf dem QS-VPS
# VPS:      devsystem-qs-vps (QS-Umgebung)
# Autor:    DevSystem Automation
# Datum:    2026-05-24
#
# Verwendung:
#   bash scripts/qs/install-ollama-qs.sh [--force] [--dry-run] [--cleanup-only]
#
# Optionen:
#   --force         Neuinstallation erzwingen (überschreibt bestehende Installation)
#   --dry-run       Nur prüfen, nichts installieren
#   --cleanup-only  Nur alte Modelle löschen, kein Install
#
# Modell:
#   - phi3.5:3.8b  (~2.2 GB) - Microsoft Phi-3.5 Mini Instruct LLM
#
# Ressourcen-Anforderungen:
#   - RAM:  min. 4 GB frei (empfohlen: 6 GB frei, 8 GB gesamt)
#   - Disk: min. 5 GB frei (Modell ~2.2 GB + Puffer)
#   - CPU:  2+ Kerne empfohlen
# =============================================================================

set -euo pipefail

# --- Konfiguration -----------------------------------------------------------
OLLAMA_VERSION="latest"
OLLAMA_HOST="127.0.0.1"
OLLAMA_PORT="11434"
OLLAMA_USER="ollama"
OLLAMA_MODELS_DIR="/var/lib/ollama/models"
OLLAMA_LOG_DIR="/var/log/ollama"
OLLAMA_SERVICE_FILE="/etc/systemd/system/ollama.service"
MARKER_FILE="/var/lib/ollama/.qs-install-complete"

# Modell für QS-VPS
PRIMARY_MODEL="phi3.5:3.8b"

# Ressourcen-Limits (angepasst für phi3.5:3.8b auf QS-VPS)
MEMORY_MAX="6G"
MEMORY_HIGH="5G"
CPU_QUOTA="150%"

# Schwellenwerte für Memory-Checks
RAM_MIN_GB=4       # Abbruch wenn weniger als 4 GB frei
RAM_WARN_GB=6      # Warnung wenn weniger als 6 GB frei
DISK_MIN_GB=5      # Abbruch wenn weniger als 5 GB frei
RAM_TOTAL_MIN_GB=6 # Warnung wenn Gesamt-RAM < 6 GB

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Flags -------------------------------------------------------------------
FORCE=false
DRY_RUN=false
CLEANUP_ONLY=false

for arg in "$@"; do
  case $arg in
    --force)        FORCE=true ;;
    --dry-run)      DRY_RUN=true ;;
    --cleanup-only) CLEANUP_ONLY=true ;;
  esac
done

# --- Hilfsfunktionen ---------------------------------------------------------
log_info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_section() { echo -e "\n${BLUE}=== $* ===${NC}"; }
log_detail()  { echo -e "${CYAN}  →${NC} $*"; }

run() {
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY-RUN]${NC} $*"
  else
    eval "$@"
  fi
}

# --- Voraussetzungen prüfen --------------------------------------------------
check_prerequisites() {
  log_section "Voraussetzungen prüfen"

  # Root-Rechte
  if [ "$(id -u)" -ne 0 ]; then
    log_error "Dieses Script muss als root ausgeführt werden"
    exit 1
  fi
  log_info "Root-Rechte: OK"

  # Betriebssystem
  if ! grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
    log_warn "Nicht Ubuntu - Script ist für Ubuntu optimiert"
  else
    OS_VERSION=$(grep VERSION_ID /etc/os-release | cut -d'"' -f2)
    log_info "OS: Ubuntu $OS_VERSION"
  fi

  # curl verfügbar
  if ! command -v curl &>/dev/null; then
    log_warn "curl nicht gefunden - wird installiert"
    run "apt-get install -y curl"
  fi
  log_info "curl: OK"
}

# --- Memory und Disk prüfen --------------------------------------------------
check_resources() {
  log_section "Ressourcen prüfen (phi3.5:3.8b benötigt ~4-5 GB RAM)"

  # Gesamt-RAM
  TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  TOTAL_RAM_GB=$(echo "scale=1; $TOTAL_RAM_KB / 1024 / 1024" | bc)
  log_info "RAM gesamt: ${TOTAL_RAM_GB} GB"

  if (( $(echo "$TOTAL_RAM_GB < $RAM_TOTAL_MIN_GB" | bc -l) )); then
    log_warn "Gesamt-RAM (${TOTAL_RAM_GB} GB) unter Empfehlung (${RAM_TOTAL_MIN_GB} GB)"
    log_warn "phi3.5:3.8b könnte langsam sein oder OOM-Fehler verursachen"
  fi

  # Freier RAM
  FREE_RAM_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
  FREE_RAM_GB=$(echo "scale=1; $FREE_RAM_KB / 1024 / 1024" | bc)
  log_info "RAM verfügbar: ${FREE_RAM_GB} GB"

  if (( $(echo "$FREE_RAM_GB < $RAM_MIN_GB" | bc -l) )); then
    log_error "Zu wenig freier RAM (${FREE_RAM_GB} GB). Minimum: ${RAM_MIN_GB} GB"
    log_error "Bitte andere Prozesse beenden oder LLMs löschen (--cleanup-only)"
    log_error "Tipp: 'ollama list' und 'ollama rm <model>' zum Aufräumen"
    exit 1
  elif (( $(echo "$FREE_RAM_GB < $RAM_WARN_GB" | bc -l) )); then
    log_warn "Wenig freier RAM (${FREE_RAM_GB} GB). Empfohlen: ${RAM_WARN_GB} GB"
    log_warn "Automatisches Cleanup alter Ollama-Modelle wird durchgeführt..."
    cleanup_old_models
  else
    log_info "RAM: ausreichend ✓ (${FREE_RAM_GB} GB frei)"
  fi

  # Disk-Speicher
  FREE_DISK_GB=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
  log_info "Disk frei: ${FREE_DISK_GB} GB"

  if [ "$FREE_DISK_GB" -lt "$DISK_MIN_GB" ]; then
    log_warn "Wenig Disk-Speicher (${FREE_DISK_GB} GB). Cleanup wird durchgeführt..."
    cleanup_old_models
    # Erneut prüfen
    FREE_DISK_GB=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
    if [ "$FREE_DISK_GB" -lt "$DISK_MIN_GB" ]; then
      log_error "Immer noch zu wenig Disk-Speicher (${FREE_DISK_GB} GB). Minimum: ${DISK_MIN_GB} GB"
      exit 1
    fi
  fi
  log_info "Disk: ausreichend ✓ (${FREE_DISK_GB} GB frei)"

  # Laufende Ollama-Prozesse anzeigen
  if pgrep -x "ollama" &>/dev/null; then
    OLLAMA_MEM=$(ps aux | grep "ollama serve" | grep -v grep | awk '{sum += $6} END {printf "%.0f", sum/1024}' || echo "0")
    log_info "Ollama läuft bereits (RAM-Nutzung: ~${OLLAMA_MEM} MB)"
  fi
}

# --- Alte Modelle aufräumen --------------------------------------------------
cleanup_old_models() {
  log_section "Alte Ollama-Modelle aufräumen"

  if ! command -v ollama &>/dev/null; then
    log_info "Ollama nicht installiert - kein Cleanup nötig"
    return 0
  fi

  # Service starten falls nicht aktiv (für ollama list)
  if ! systemctl is-active --quiet ollama 2>/dev/null; then
    log_info "Starte Ollama Service temporär für Cleanup..."
    systemctl start ollama 2>/dev/null || true
    sleep 3
  fi

  # Alle Modelle auflisten
  MODELS=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' || echo "")

  if [ -z "$MODELS" ]; then
    log_info "Keine Modelle vorhanden - kein Cleanup nötig"
    return 0
  fi

  log_info "Gefundene Modelle:"
  ollama list 2>/dev/null | tail -n +2 | while read -r line; do
    log_detail "$line"
  done

  # Alle Modelle außer phi3.5:3.8b löschen
  while IFS= read -r model; do
    if [ -z "$model" ]; then
      continue
    fi
    # phi3.5:3.8b behalten (falls bereits vorhanden)
    if echo "$model" | grep -q "phi3.5"; then
      log_info "Behalte: $model"
      continue
    fi
    log_info "Lösche Modell: $model"
    if [ "$DRY_RUN" = false ]; then
      ollama rm "$model" 2>/dev/null && log_info "  → gelöscht ✓" || log_warn "  → Fehler beim Löschen"
    else
      echo -e "${YELLOW}[DRY-RUN]${NC} ollama rm $model"
    fi
  done <<< "$MODELS"

  # Disk nach Cleanup
  FREE_DISK_AFTER=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
  log_info "Disk nach Cleanup: ${FREE_DISK_AFTER} GB frei"
}

# --- Idempotenz-Check --------------------------------------------------------
check_already_installed() {
  log_section "Installations-Status prüfen"

  if [ -f "$MARKER_FILE" ] && [ "$FORCE" = false ]; then
    log_info "Ollama QS-Installation bereits vorhanden (Marker: $MARKER_FILE)"
    log_info "Verwende --force um neu zu installieren"

    # Service-Status
    if systemctl is-active --quiet ollama 2>/dev/null; then
      log_info "Ollama Service: aktiv ✓"
      OLLAMA_VER=$(ollama --version 2>/dev/null || echo "unbekannt")
      log_info "Version: $OLLAMA_VER"
    else
      log_warn "Ollama Service: nicht aktiv - wird gestartet"
      run "systemctl start ollama"
    fi

    # Modell-Status
    if ollama list 2>/dev/null | grep -q "phi3.5"; then
      log_info "Modell $PRIMARY_MODEL: installiert ✓"
    else
      log_warn "Modell $PRIMARY_MODEL fehlt - wird nachinstalliert"
      pull_model
    fi

    exit 0
  fi

  if [ "$FORCE" = true ] && command -v ollama &>/dev/null; then
    log_warn "Force-Modus: Bestehende Installation wird überschrieben"
  fi
}

# --- Ollama installieren -----------------------------------------------------
install_ollama() {
  log_section "Ollama installieren"

  if command -v ollama &>/dev/null && [ "$FORCE" = false ]; then
    INSTALLED_VER=$(ollama --version 2>/dev/null || echo "unbekannt")
    log_info "Ollama bereits vorhanden: $INSTALLED_VER"
    return 0
  fi

  log_info "Lade Ollama Installations-Script herunter..."
  run "curl -fsSL https://ollama.com/install.sh | sh"

  if [ "$DRY_RUN" = false ]; then
    if ! command -v ollama &>/dev/null; then
      log_error "Ollama Installation fehlgeschlagen"
      exit 1
    fi
    INSTALLED_VER=$(ollama --version 2>/dev/null || echo "unbekannt")
    log_info "Ollama installiert: $INSTALLED_VER"
  fi
}

# --- Verzeichnisse erstellen -------------------------------------------------
setup_directories() {
  log_section "Verzeichnisse einrichten"

  run "mkdir -p $OLLAMA_MODELS_DIR"
  run "mkdir -p $OLLAMA_LOG_DIR"

  if [ "$DRY_RUN" = false ]; then
    # User anlegen falls nicht vorhanden
    if ! id "$OLLAMA_USER" &>/dev/null; then
      useradd --system --shell /bin/false --home-dir /var/lib/ollama \
        --comment "Ollama Service User" "$OLLAMA_USER"
      log_info "User '$OLLAMA_USER' erstellt"
    else
      log_info "User '$OLLAMA_USER' bereits vorhanden"
    fi

    chown -R "$OLLAMA_USER:$OLLAMA_USER" /var/lib/ollama
    chown -R "$OLLAMA_USER:$OLLAMA_USER" "$OLLAMA_LOG_DIR"
    chmod 750 /var/lib/ollama
    chmod 750 "$OLLAMA_LOG_DIR"
    log_info "Verzeichnisse: OK"
  fi
}

# --- systemd Service konfigurieren ------------------------------------------
configure_service() {
  log_section "systemd Service konfigurieren (phi3.5:3.8b optimiert)"

  SERVICE_CONTENT="[Unit]
Description=Ollama Local LLM Service (QS) - phi3.5:3.8b
Documentation=https://ollama.ai/docs
After=network.target
Wants=network.target

[Service]
Type=simple
User=${OLLAMA_USER}
Group=${OLLAMA_USER}
WorkingDirectory=/var/lib/ollama
ExecStart=/usr/local/bin/ollama serve
Restart=always
RestartSec=10
TimeoutStartSec=180

# Netzwerk: nur localhost (kein externer Zugriff direkt)
Environment=\"OLLAMA_HOST=${OLLAMA_HOST}:${OLLAMA_PORT}\"
Environment=\"OLLAMA_MODELS=${OLLAMA_MODELS_DIR}\"
# phi3.5:3.8b: nach 15min aus RAM entladen (spart Ressourcen auf QS)
Environment=\"OLLAMA_KEEP_ALIVE=15m\"
# Nur 1 Modell gleichzeitig (phi3.5 braucht ~4-5 GB RAM)
Environment=\"OLLAMA_MAX_LOADED_MODELS=1\"
Environment=\"OLLAMA_NUM_PARALLEL=1\"

# Ressourcen-Limits (angepasst für phi3.5:3.8b auf QS-VPS)
MemoryMax=${MEMORY_MAX}
MemoryHigh=${MEMORY_HIGH}
CPUQuota=${CPU_QUOTA}

# Logging
StandardOutput=append:${OLLAMA_LOG_DIR}/ollama.log
StandardError=append:${OLLAMA_LOG_DIR}/ollama-error.log

# Sicherheit
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/var/lib/ollama ${OLLAMA_LOG_DIR}

[Install]
WantedBy=multi-user.target"

  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY-RUN]${NC} Würde schreiben: $OLLAMA_SERVICE_FILE"
    echo "$SERVICE_CONTENT"
  else
    echo "$SERVICE_CONTENT" > "$OLLAMA_SERVICE_FILE"
    log_info "Service-Datei geschrieben: $OLLAMA_SERVICE_FILE"
  fi

  run "systemctl daemon-reload"
  run "systemctl enable ollama"
  run "systemctl restart ollama"

  if [ "$DRY_RUN" = false ]; then
    log_info "Warte auf Ollama Service..."
    for i in $(seq 1 30); do
      if curl -s "http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/version" &>/dev/null; then
        log_info "Ollama Service bereit ✓ (nach ${i}s)"
        break
      fi
      sleep 1
      if [ "$i" -eq 30 ]; then
        log_error "Ollama Service nicht bereit nach 30s"
        systemctl status ollama --no-pager
        exit 1
      fi
    done
  fi
}

# --- Modell herunterladen ----------------------------------------------------
pull_model() {
  log_section "phi3.5:3.8b herunterladen (~2.2 GB)"

  log_info "Lade $PRIMARY_MODEL..."
  log_warn "Download kann 5-15 Minuten dauern je nach Verbindung"

  if [ "$DRY_RUN" = false ]; then
    if ollama list 2>/dev/null | grep -q "phi3.5"; then
      log_info "$PRIMARY_MODEL bereits vorhanden ✓"
    else
      # Sicherstellen dass Service läuft
      if ! systemctl is-active --quiet ollama 2>/dev/null; then
        systemctl start ollama
        sleep 5
      fi
      ollama pull "$PRIMARY_MODEL"
      log_info "$PRIMARY_MODEL heruntergeladen ✓"
    fi
  else
    echo -e "${YELLOW}[DRY-RUN]${NC} ollama pull $PRIMARY_MODEL"
  fi
}

# --- Caddy-Konfiguration für Ollama auf QS-VPS ------------------------------
configure_caddy() {
  log_section "Caddy-Konfiguration für Ollama (QS)"

  CADDY_OLLAMA_CONF="/etc/caddy/sites/ollama-qs.caddy"
  CADDY_SITES_DIR="/etc/caddy/sites"

  if [ ! -d "$CADDY_SITES_DIR" ]; then
    log_warn "Caddy sites-Verzeichnis nicht gefunden: $CADDY_SITES_DIR"
    log_warn "Caddy-Konfiguration wird übersprungen"
    return 0
  fi

  CADDY_CONTENT="# Ollama API (QS) - nur über Tailscale erreichbar
# Generiert von install-ollama-qs.sh am $(date '+%Y-%m-%d')
ollama.devsystem-qs.internal {
    # Nur Tailscale-Zugriff erlauben
    @tailscale {
        remote_ip 100.64.0.0/10
    }
    @not_tailscale {
        not remote_ip 100.64.0.0/10
    }

    # Nicht-Tailscale-Zugriffe blockieren
    handle @not_tailscale {
        respond \"403 Forbidden: Nur Tailscale-Zugriff erlaubt (QS)\" 403
    }

    # Ollama API weiterleiten
    handle @tailscale {
        reverse_proxy localhost:${OLLAMA_PORT} {
            header_up Host {upstream_hostport}
            header_up X-Real-IP {remote_ip}
        }
    }

    # Logging
    log {
        output file /var/log/caddy/ollama-qs.log {
            roll_size 50MB
            roll_keep 3
        }
    }
}"

  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY-RUN]${NC} Würde schreiben: $CADDY_OLLAMA_CONF"
    echo "$CADDY_CONTENT"
  else
    echo "$CADDY_CONTENT" > "$CADDY_OLLAMA_CONF"
    log_info "Caddy-Konfiguration geschrieben: $CADDY_OLLAMA_CONF"

    if caddy validate --config /etc/caddy/Caddyfile &>/dev/null 2>&1; then
      systemctl reload caddy
      log_info "Caddy neu geladen ✓"
    else
      log_warn "Caddy-Validierung fehlgeschlagen - manuelle Prüfung erforderlich"
      caddy validate --config /etc/caddy/Caddyfile 2>&1 || true
    fi
  fi
}

# --- Installations-Marker setzen --------------------------------------------
set_marker() {
  if [ "$DRY_RUN" = false ]; then
    cat > "$MARKER_FILE" << EOF
install_date=$(date -u +%Y-%m-%dT%H:%M:%SZ)
ollama_version=$(ollama --version 2>/dev/null || echo "unbekannt")
primary_model=${PRIMARY_MODEL}
installed_by=install-ollama-qs.sh
qs_vps=true
EOF
    log_info "Installations-Marker gesetzt: $MARKER_FILE"
  fi
}

# --- Validierung -------------------------------------------------------------
validate_installation() {
  log_section "Installation validieren"

  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Validierung übersprungen"
    return 0
  fi

  local errors=0

  # 1. Service läuft
  if systemctl is-active --quiet ollama; then
    log_info "✓ Ollama Service: aktiv"
  else
    log_error "✗ Ollama Service: nicht aktiv"
    ((errors++))
  fi

  # 2. API erreichbar
  if curl -s "http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/version" &>/dev/null; then
    API_VERSION=$(curl -s "http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/version" \
      | grep -o '"version":"[^"]*"' | cut -d'"' -f4 || echo "unbekannt")
    log_info "✓ Ollama API: erreichbar (v${API_VERSION})"
  else
    log_error "✗ Ollama API: nicht erreichbar auf ${OLLAMA_HOST}:${OLLAMA_PORT}"
    ((errors++))
  fi

  # 3. Modell vorhanden
  if ollama list 2>/dev/null | grep -q "phi3.5"; then
    MODEL_SIZE=$(ollama list 2>/dev/null | grep "phi3.5" | awk '{print $3, $4}' || echo "unbekannt")
    log_info "✓ Modell $PRIMARY_MODEL: installiert (${MODEL_SIZE})"
  else
    log_error "✗ Modell $PRIMARY_MODEL: nicht gefunden"
    ((errors++))
  fi

  # 4. Schneller Inference-Test (kurze Antwort)
  log_info "Teste phi3.5:3.8b Inference (kurze Antwort)..."
  INFERENCE_RESULT=$(curl -s --max-time 60 \
    -X POST "http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"${PRIMARY_MODEL}\",\"prompt\":\"Antworte nur mit: OK\",\"stream\":false}" \
    2>/dev/null | grep -c "response" || echo "0")

  if [ "$INFERENCE_RESULT" -gt 0 ]; then
    log_info "✓ Inference-Test: erfolgreich"
  else
    log_warn "⚠ Inference-Test: Timeout oder Fehler (Modell lädt möglicherweise noch)"
  fi

  # 5. Ressourcen-Nutzung nach Installation
  OLLAMA_MEM_PCT=$(ps aux | grep "ollama serve" | grep -v grep | awk '{print $4}' | head -1 || echo "0")
  FREE_RAM_AFTER=$(grep MemAvailable /proc/meminfo | awk '{printf "%.1f", $2/1024/1024}')
  log_info "RAM nach Installation: ${FREE_RAM_AFTER} GB frei | Ollama: ${OLLAMA_MEM_PCT}% RAM"

  echo ""
  if [ "$errors" -eq 0 ]; then
    log_info "✅ Alle Validierungen bestanden"
    return 0
  else
    log_error "❌ $errors Validierung(en) fehlgeschlagen"
    return 1
  fi
}

# --- Zusammenfassung ---------------------------------------------------------
print_summary() {
  log_section "Installations-Zusammenfassung"

  echo ""
  echo "  Ollama LLM-Server auf QS-VPS"
  echo "  ============================="
  echo "  VPS:          devsystem-qs-vps"
  echo "  API:          http://localhost:${OLLAMA_PORT}"
  echo "  Modell:       ${PRIMARY_MODEL} (Microsoft Phi-3.5 Mini)"
  echo "  Service:      ollama.service (systemd)"
  echo "  Logs:         ${OLLAMA_LOG_DIR}/ollama.log"
  echo "  Memory-Limit: ${MEMORY_MAX} max / ${MEMORY_HIGH} high"
  echo ""
  echo "  Inference-Endpoint:"
  echo "  -------------------"
  echo "  POST http://localhost:${OLLAMA_PORT}/api/generate"
  echo "  {\"model\":\"${PRIMARY_MODEL}\",\"prompt\":\"<text>\",\"stream\":false}"
  echo ""
  echo "  Chat-Endpoint:"
  echo "  --------------"
  echo "  POST http://localhost:${OLLAMA_PORT}/api/chat"
  echo "  {\"model\":\"${PRIMARY_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"<text>\"}]}"
  echo ""
  echo "  Nützliche Befehle:"
  echo "  ------------------"
  echo "  systemctl status ollama"
  echo "  ollama list"
  echo "  ollama run ${PRIMARY_MODEL}"
  echo "  journalctl -u ollama -f"
  echo "  curl http://localhost:${OLLAMA_PORT}/api/version"
  echo ""
}

# --- Hauptprogramm -----------------------------------------------------------
main() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║     Ollama Installation - QS-VPS                         ║"
  echo "║     Modell: phi3.5:3.8b (Microsoft Phi-3.5 Mini)        ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo ""

  if [ "$DRY_RUN" = true ]; then
    log_warn "DRY-RUN Modus - keine Änderungen werden vorgenommen"
  fi

  check_prerequisites

  # Nur Cleanup-Modus
  if [ "$CLEANUP_ONLY" = true ]; then
    cleanup_old_models
    log_info "Cleanup abgeschlossen"
    exit 0
  fi

  check_resources
  check_already_installed
  install_ollama
  setup_directories
  configure_service
  pull_model
  configure_caddy
  set_marker
  validate_installation
  print_summary

  log_info "🎉 Ollama QS-Installation abgeschlossen!"
}

main "$@"
