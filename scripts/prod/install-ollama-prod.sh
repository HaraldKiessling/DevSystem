#!/bin/bash
# =============================================================================
# install-ollama-prod.sh - Ollama Installation auf Produktions-VPS
# =============================================================================
# Zweck:    Installiert Ollama mit nomic-embed-text Embedding-Modell für Qdrant
# VPS:      devsystem-vps (100.100.221.56)
# Autor:    DevSystem Automation
# Datum:    2026-05-24
#
# Verwendung:
#   bash scripts/prod/install-ollama-prod.sh [--force] [--dry-run]
#
# Optionen:
#   --force     Neuinstallation erzwingen (überschreibt bestehende Installation)
#   --dry-run   Nur prüfen, nichts installieren
#
# Modelle:
#   - nomic-embed-text  (274 MB) - Embedding-Modell für Qdrant/RAG
#   - mxbai-embed-large (670 MB) - Optional: Bessere Embedding-Qualität
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
MARKER_FILE="/var/lib/ollama/.install-complete"

# Modelle für Qdrant-Integration
PRIMARY_MODEL="nomic-embed-text"
OPTIONAL_MODEL="mxbai-embed-large"

# Ressourcen-Limits (konservativ für Produktions-VPS)
MEMORY_MAX="4G"
MEMORY_HIGH="3G"
CPU_QUOTA="200%"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Flags -------------------------------------------------------------------
FORCE=false
DRY_RUN=false

for arg in "$@"; do
  case $arg in
    --force)   FORCE=true ;;
    --dry-run) DRY_RUN=true ;;
  esac
done

# --- Hilfsfunktionen ---------------------------------------------------------
log_info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_section() { echo -e "\n${BLUE}=== $* ===${NC}"; }

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

  # RAM prüfen
  TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  TOTAL_RAM_GB=$(echo "scale=1; $TOTAL_RAM_KB / 1024 / 1024" | bc)
  FREE_RAM_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
  FREE_RAM_GB=$(echo "scale=1; $FREE_RAM_KB / 1024 / 1024" | bc)
  log_info "RAM gesamt: ${TOTAL_RAM_GB} GB | Verfügbar: ${FREE_RAM_GB} GB"

  if [ "$TOTAL_RAM_KB" -lt 2097152 ]; then  # < 2 GB
    log_error "Zu wenig RAM (${TOTAL_RAM_GB} GB). Minimum: 2 GB für nomic-embed-text"
    exit 1
  fi

  # Disk prüfen
  FREE_DISK_GB=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
  log_info "Freier Disk-Speicher: ${FREE_DISK_GB} GB"

  if [ "$FREE_DISK_GB" -lt 5 ]; then
    log_error "Zu wenig Disk-Speicher (${FREE_DISK_GB} GB). Minimum: 5 GB"
    exit 1
  fi

  # curl verfügbar
  if ! command -v curl &>/dev/null; then
    log_warn "curl nicht gefunden - wird installiert"
    run "apt-get install -y curl"
  fi
  log_info "curl: OK"

  # Qdrant läuft (Warnung wenn nicht)
  if systemctl is-active --quiet qdrant 2>/dev/null; then
    log_info "Qdrant Service: aktiv ✓"
  else
    log_warn "Qdrant Service nicht aktiv - Ollama wird trotzdem installiert"
  fi
}

# --- Idempotenz-Check --------------------------------------------------------
check_already_installed() {
  log_section "Installations-Status prüfen"

  if [ -f "$MARKER_FILE" ] && [ "$FORCE" = false ]; then
    log_info "Ollama bereits installiert (Marker: $MARKER_FILE)"
    log_info "Verwende --force um neu zu installieren"

    # Service-Status anzeigen
    if systemctl is-active --quiet ollama 2>/dev/null; then
      log_info "Ollama Service: aktiv ✓"
      OLLAMA_VERSION_INSTALLED=$(ollama --version 2>/dev/null || echo "unbekannt")
      log_info "Version: $OLLAMA_VERSION_INSTALLED"
    else
      log_warn "Ollama Service: nicht aktiv"
      run "systemctl start ollama"
    fi

    # Modell-Status
    if ollama list 2>/dev/null | grep -q "$PRIMARY_MODEL"; then
      log_info "Modell $PRIMARY_MODEL: installiert ✓"
    else
      log_warn "Modell $PRIMARY_MODEL fehlt - wird nachinstalliert"
      pull_models
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
  log_section "systemd Service konfigurieren"

  SERVICE_CONTENT="[Unit]
Description=Ollama Local LLM Service (Prod)
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
TimeoutStartSec=120

# Netzwerk: nur localhost (kein externer Zugriff direkt)
Environment=\"OLLAMA_HOST=${OLLAMA_HOST}:${OLLAMA_PORT}\"
Environment=\"OLLAMA_MODELS=${OLLAMA_MODELS_DIR}\"
Environment=\"OLLAMA_KEEP_ALIVE=10m\"
Environment=\"OLLAMA_MAX_LOADED_MODELS=2\"
Environment=\"OLLAMA_NUM_PARALLEL=2\"

# Ressourcen-Limits (konservativ für Produktions-VPS)
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
    # Warten bis Service bereit
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

# --- Modelle herunterladen ---------------------------------------------------
pull_models() {
  log_section "Embedding-Modelle herunterladen"

  # Primäres Modell: nomic-embed-text (274 MB)
  log_info "Lade $PRIMARY_MODEL (274 MB, optimiert für RAG/Qdrant)..."
  if [ "$DRY_RUN" = false ]; then
    if ollama list 2>/dev/null | grep -q "$PRIMARY_MODEL"; then
      log_info "$PRIMARY_MODEL bereits vorhanden ✓"
    else
      ollama pull "$PRIMARY_MODEL"
      log_info "$PRIMARY_MODEL heruntergeladen ✓"
    fi
  else
    echo -e "${YELLOW}[DRY-RUN]${NC} ollama pull $PRIMARY_MODEL"
  fi

  # RAM-Check für optionales Modell
  FREE_RAM_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
  FREE_RAM_GB=$(echo "scale=0; $FREE_RAM_KB / 1024 / 1024" | bc)

  if [ "$FREE_RAM_GB" -ge 4 ]; then
    log_info "Genug RAM (${FREE_RAM_GB} GB frei) - lade auch $OPTIONAL_MODEL (670 MB)..."
    if [ "$DRY_RUN" = false ]; then
      if ollama list 2>/dev/null | grep -q "$OPTIONAL_MODEL"; then
        log_info "$OPTIONAL_MODEL bereits vorhanden ✓"
      else
        ollama pull "$OPTIONAL_MODEL"
        log_info "$OPTIONAL_MODEL heruntergeladen ✓"
      fi
    else
      echo -e "${YELLOW}[DRY-RUN]${NC} ollama pull $OPTIONAL_MODEL"
    fi
  else
    log_warn "Wenig RAM (${FREE_RAM_GB} GB frei) - $OPTIONAL_MODEL wird übersprungen"
  fi
}

# --- Caddy-Konfiguration für Ollama ------------------------------------------
configure_caddy() {
  log_section "Caddy-Konfiguration für Ollama"

  CADDY_OLLAMA_CONF="/etc/caddy/sites/ollama.caddy"
  CADDY_SITES_DIR="/etc/caddy/sites"

  if [ ! -d "$CADDY_SITES_DIR" ]; then
    log_warn "Caddy sites-Verzeichnis nicht gefunden: $CADDY_SITES_DIR"
    log_warn "Caddy-Konfiguration wird übersprungen"
    return 0
  fi

  CADDY_CONTENT="# Ollama API - nur über Tailscale erreichbar
# Generiert von install-ollama-prod.sh am $(date '+%Y-%m-%d')
ollama.devsystem.internal {
    # Nur Tailscale-Zugriff erlauben
    @tailscale {
        remote_ip 100.64.0.0/10
    }
    @not_tailscale {
        not remote_ip 100.64.0.0/10
    }

    # Nicht-Tailscale-Zugriffe blockieren
    handle @not_tailscale {
        respond \"403 Forbidden: Nur Tailscale-Zugriff erlaubt\" 403
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
        output file /var/log/caddy/ollama.log {
            roll_size 50MB
            roll_keep 5
        }
    }
}"

  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY-RUN]${NC} Würde schreiben: $CADDY_OLLAMA_CONF"
    echo "$CADDY_CONTENT"
  else
    echo "$CADDY_CONTENT" > "$CADDY_OLLAMA_CONF"
    log_info "Caddy-Konfiguration geschrieben: $CADDY_OLLAMA_CONF"

    # Caddy-Konfiguration validieren und neu laden
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
optional_model=${OPTIONAL_MODEL}
installed_by=install-ollama-prod.sh
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
    API_VERSION=$(curl -s "http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/version" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
    log_info "✓ Ollama API: erreichbar (v${API_VERSION})"
  else
    log_error "✗ Ollama API: nicht erreichbar auf ${OLLAMA_HOST}:${OLLAMA_PORT}"
    ((errors++))
  fi

  # 3. Primäres Modell vorhanden
  if ollama list 2>/dev/null | grep -q "$PRIMARY_MODEL"; then
    log_info "✓ Modell $PRIMARY_MODEL: installiert"
  else
    log_error "✗ Modell $PRIMARY_MODEL: nicht gefunden"
    ((errors++))
  fi

  # 4. Embedding-Test
  log_info "Teste Embedding-Generierung..."
  EMBED_RESULT=$(curl -s -X POST "http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/embeddings" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"${PRIMARY_MODEL}\",\"prompt\":\"Test embedding für Qdrant\"}" \
    2>/dev/null | grep -c "embedding" || echo "0")

  if [ "$EMBED_RESULT" -gt 0 ]; then
    log_info "✓ Embedding-Test: erfolgreich"
  else
    log_error "✗ Embedding-Test: fehlgeschlagen"
    ((errors++))
  fi

  # 5. Ressourcen-Nutzung
  OLLAMA_MEM=$(ps aux | grep "ollama serve" | grep -v grep | awk '{print $4}' | head -1)
  log_info "Ollama RAM-Nutzung: ${OLLAMA_MEM:-unbekannt}%"

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
  echo "  Ollama Embedding-Server für Qdrant/RAG"
  echo "  ======================================="
  echo "  VPS:          devsystem-vps (100.100.221.56)"
  echo "  API:          http://localhost:${OLLAMA_PORT}"
  echo "  Modell:       ${PRIMARY_MODEL} (Embeddings)"
  echo "  Service:      ollama.service (systemd)"
  echo "  Logs:         ${OLLAMA_LOG_DIR}/ollama.log"
  echo ""
  echo "  Qdrant-Integration:"
  echo "  -------------------"
  echo "  Embedding-Endpoint: POST http://localhost:${OLLAMA_PORT}/api/embeddings"
  echo "  Payload: {\"model\":\"${PRIMARY_MODEL}\",\"prompt\":\"<text>\"}"
  echo ""
  echo "  Caddy (Tailscale-Zugriff):"
  echo "  --------------------------"
  echo "  URL: https://ollama.devsystem.internal"
  echo "  Nur über Tailscale VPN erreichbar"
  echo ""
  echo "  Nützliche Befehle:"
  echo "  ------------------"
  echo "  systemctl status ollama"
  echo "  ollama list"
  echo "  ollama run ${PRIMARY_MODEL}"
  echo "  journalctl -u ollama -f"
  echo ""
}

# --- Hauptprogramm -----------------------------------------------------------
main() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║     Ollama Installation - Produktions-VPS                ║"
  echo "║     Embedding-Server für Qdrant/RAG                      ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo ""

  if [ "$DRY_RUN" = true ]; then
    log_warn "DRY-RUN Modus - keine Änderungen werden vorgenommen"
  fi

  check_prerequisites
  check_already_installed
  install_ollama
  setup_directories
  configure_service
  pull_models
  configure_caddy
  set_marker
  validate_installation
  print_summary

  log_info "🎉 Ollama Installation abgeschlossen!"
}

main "$@"
