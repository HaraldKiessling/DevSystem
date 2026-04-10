#!/bin/bash
#
# QS-VPS: Qdrant Diagnose-Script
# Analysiert warum Qdrant nicht startet
#
# Verwendung:
#   sudo bash diagnose-qdrant-qs.sh

set -euo pipefail

# Farben
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

echo -e "${CYAN}=== QDRANT QS-VPS DIAGNOSE ===${NC}"
echo "Timestamp: $(date -Iseconds)"
echo ""

echo -e "${BLUE}1. SERVICE STATUS${NC}"
systemctl status qdrant-qs --no-pager -l 2>&1 || echo -e "${RED}Service nicht gefunden${NC}"
echo ""

echo -e "${BLUE}2. JOURNAL LOGS (letzte 50 Zeilen)${NC}"
journalctl -u qdrant-qs -n 50 --no-pager 2>&1 || echo -e "${YELLOW}Keine Logs verfügbar${NC}"
echo ""

echo -e "${BLUE}3. BINARY PRÜFUNG${NC}"
echo "Binary existiert:"
ls -lh /opt/qdrant-qs/qdrant 2>&1 || echo -e "${RED}Binary nicht gefunden${NC}"
echo ""
echo "Binary ausführbar:"
file /opt/qdrant-qs/qdrant 2>&1 || echo -e "${RED}Fehler${NC}"
echo ""
echo "Version direkt:"
/opt/qdrant-qs/qdrant --version 2>&1 || echo -e "${RED}Fehler beim Aufruf${NC}"
echo ""

echo -e "${BLUE}4. KONFIGURATION${NC}"
echo "Config-Datei:"
ls -l /opt/qdrant-qs/config.yaml 2>&1 || echo -e "${RED}Config nicht gefunden${NC}"
echo ""
if [ -f /opt/qdrant-qs/config.yaml ]; then
    echo "Config-Inhalt:"
    cat /opt/qdrant-qs/config.yaml
fi
echo ""

echo -e "${BLUE}5. VERZEICHNIS-BERECHTIGUNGEN${NC}"
echo "Install-Dir:"
ls -la /opt/qdrant-qs/ 2>&1 || echo -e "${RED}Nicht gefunden${NC}"
echo ""
echo "Data-Dir:"
ls -la /var/lib/qdrant-qs/ 2>&1 || echo -e "${RED}Nicht gefunden${NC}"
echo ""
echo "Log-Dir:"
ls -la /var/log/qdrant-qs/ 2>&1 || echo -e "${RED}Nicht gefunden${NC}"
echo ""

echo -e "${BLUE}6. USER & GRUPPE${NC}"
id qdrant-qs 2>&1 || echo -e "${RED}User nicht gefunden${NC}"
echo ""

echo -e "${BLUE}7. SYSTEMD SERVICE FILE${NC}"
if [ -f /etc/systemd/system/qdrant-qs.service ]; then
    cat /etc/systemd/system/qdrant-qs.service
else
    echo -e "${RED}Service-File nicht gefunden${NC}"
fi
echo ""

echo -e "${BLUE}8. MANUELLE START-VERSUCH (als qdrant-qs User)${NC}"
sudo -u qdrant-qs /opt/qdrant-qs/qdrant --version 2>&1 || echo -e "${RED}Fehler als User${NC}"
echo ""

echo -e "${BLUE}9. PORT-BELEGUNG${NC}"
ss -tlnp 2>/dev/null | grep -E "6333|6334" || echo -e "${YELLOW}Keine Qdrant-Ports belegt${NC}"
echo ""

echo -e "${BLUE}10. IDEMPOTENZ-STATUS (falls vorhanden)${NC}"
if [ -d /var/lib/qs-deployment/markers ]; then
    echo "Qdrant-Marker:"
    find /var/lib/qs-deployment/markers -name "qdrant*" -exec basename {} \; 2>&1 || echo "Keine"
fi
if [ -d /var/lib/qs-deployment/state ]; then
    echo ""
    echo "Qdrant-State:"
    cat /var/lib/qs-deployment/state/qdrant.state 2>&1 || echo "Kein State gefunden"
fi
echo ""

echo -e "${GREEN}=== DIAGNOSE ABGESCHLOSSEN ===${NC}"
echo ""
echo "Logs gespeichert in: /var/log/qs-deployment.log"
