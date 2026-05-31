#!/bin/bash
# Diagnose und Reparatur für devsystem-vps
# Datum: 2026-05-31
# Problem: VPS über Tailscale nicht erreichbar

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}devsystem-vps Diagnose & Reparatur${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Funktion für Status-Ausgabe
check_status() {
    local service=$1
    local status=$2
    if [ "$status" = "active" ] || [ "$status" = "running" ]; then
        echo -e "${GREEN}✓${NC} $service: $status"
        return 0
    else
        echo -e "${RED}✗${NC} $service: $status"
        return 1
    fi
}

# 1. System-Status prüfen
echo -e "${YELLOW}[1/7] System-Status prüfen...${NC}"
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime -p)"
echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
echo ""

# 2. Speicher-Status prüfen
echo -e "${YELLOW}[2/7] Speicher-Status prüfen...${NC}"
free -h
echo ""

# Prüfe auf OOM-Killer Events
echo "Letzte OOM-Killer Events:"
dmesg | grep -i "out of memory" | tail -5 || echo "Keine OOM-Events gefunden"
echo ""

# 3. Tailscale-Status prüfen
echo -e "${YELLOW}[3/7] Tailscale-Status prüfen...${NC}"
if systemctl is-active --quiet tailscaled; then
    check_status "tailscaled" "active"
    echo "Tailscale Status:"
    tailscale status || echo "Tailscale status command failed"
    echo ""
    echo "Tailscale IP:"
    tailscale ip -4 || echo "Keine Tailscale IP"
else
    check_status "tailscaled" "inactive"
    echo -e "${RED}Tailscale läuft nicht! Starte neu...${NC}"
    systemctl start tailscaled
    sleep 3
    systemctl status tailscaled --no-pager
fi
echo ""

# 4. Caddy-Status prüfen
echo -e "${YELLOW}[4/7] Caddy-Status prüfen...${NC}"
if systemctl is-active --quiet caddy; then
    check_status "caddy" "active"
    echo "Caddy lauscht auf:"
    ss -tlnp | grep caddy || echo "Keine Caddy-Ports gefunden"
else
    check_status "caddy" "inactive"
    echo -e "${RED}Caddy läuft nicht!${NC}"
fi
echo ""

# 5. Code-Server-Status prüfen
echo -e "${YELLOW}[5/7] Code-Server-Status prüfen...${NC}"
if systemctl is-active --quiet code-server@root; then
    check_status "code-server@root" "active"
    echo "Code-Server lauscht auf:"
    ss -tlnp | grep "node.*8080" || echo "Code-Server Port nicht gefunden"
else
    check_status "code-server@root" "inactive"
    echo -e "${RED}Code-Server läuft nicht!${NC}"
fi
echo ""

# 6. Docker & Ollama-Status prüfen
echo -e "${YELLOW}[6/7] Docker & Ollama-Status prüfen...${NC}"
if systemctl is-active --quiet docker; then
    check_status "docker" "active"
    echo "Docker Container:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || echo "Keine Container laufen"
    echo ""
    
    # Prüfe Ollama Container
    if docker ps | grep -q ollama; then
        echo -e "${GREEN}✓${NC} Ollama Container läuft"
        echo "Ollama Modelle:"
        docker exec ollama ollama list || echo "Konnte Modelle nicht auflisten"
    else
        echo -e "${RED}✗${NC} Ollama Container läuft nicht"
    fi
else
    check_status "docker" "inactive"
fi
echo ""

# 7. Netzwerk-Konnektivität prüfen
echo -e "${YELLOW}[7/7] Netzwerk-Konnektivität prüfen...${NC}"
echo "DNS-Test (8.8.8.8):"
ping -c 2 8.8.8.8 > /dev/null 2>&1 && echo -e "${GREEN}✓${NC} Internet erreichbar" || echo -e "${RED}✗${NC} Kein Internet"

echo "DNS-Auflösung (google.com):"
ping -c 2 google.com > /dev/null 2>&1 && echo -e "${GREEN}✓${NC} DNS funktioniert" || echo -e "${RED}✗${NC} DNS-Problem"
echo ""

# Zusammenfassung und Reparatur-Optionen
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Diagnose abgeschlossen${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Automatische Reparatur anbieten
echo -e "${YELLOW}Möchten Sie eine automatische Reparatur durchführen? (j/n)${NC}"
read -r response

if [[ "$response" =~ ^[Jj]$ ]]; then
    echo ""
    echo -e "${BLUE}Starte automatische Reparatur...${NC}"
    echo ""
    
    # Tailscale reparieren
    if ! systemctl is-active --quiet tailscaled; then
        echo -e "${YELLOW}[1/4] Starte Tailscale...${NC}"
        systemctl start tailscaled
        sleep 3
        if systemctl is-active --quiet tailscaled; then
            echo -e "${GREEN}✓${NC} Tailscale gestartet"
        else
            echo -e "${RED}✗${NC} Tailscale konnte nicht gestartet werden"
            systemctl status tailscaled --no-pager
        fi
    fi
    
    # Caddy reparieren
    if ! systemctl is-active --quiet caddy; then
        echo -e "${YELLOW}[2/4] Starte Caddy...${NC}"
        systemctl start caddy
        sleep 2
        if systemctl is-active --quiet caddy; then
            echo -e "${GREEN}✓${NC} Caddy gestartet"
        else
            echo -e "${RED}✗${NC} Caddy konnte nicht gestartet werden"
            systemctl status caddy --no-pager
        fi
    fi
    
    # Code-Server reparieren
    if ! systemctl is-active --quiet code-server@root; then
        echo -e "${YELLOW}[3/4] Starte Code-Server...${NC}"
        systemctl start code-server@root
        sleep 2
        if systemctl is-active --quiet code-server@root; then
            echo -e "${GREEN}✓${NC} Code-Server gestartet"
        else
            echo -e "${RED}✗${NC} Code-Server konnte nicht gestartet werden"
            systemctl status code-server@root --no-pager
        fi
    fi
    
    # Ollama reparieren
    if systemctl is-active --quiet docker; then
        if ! docker ps | grep -q ollama; then
            echo -e "${YELLOW}[4/4] Starte Ollama Container...${NC}"
            
            # Prüfe ob Container existiert aber gestoppt ist
            if docker ps -a | grep -q ollama; then
                docker start ollama
            else
                echo -e "${RED}Ollama Container existiert nicht. Bitte manuell neu erstellen.${NC}"
                echo "Befehl: docker run -d --name ollama -v ollama:/root/.ollama -p 11434:11434 --memory=\"4.5g\" --memory-swap=\"5.5g\" --restart unless-stopped ollama/ollama"
            fi
            
            sleep 3
            if docker ps | grep -q ollama; then
                echo -e "${GREEN}✓${NC} Ollama Container gestartet"
            else
                echo -e "${RED}✗${NC} Ollama Container konnte nicht gestartet werden"
            fi
        fi
    fi
    
    echo ""
    echo -e "${GREEN}Reparatur abgeschlossen!${NC}"
    echo ""
    
    # Finale Verifikation
    echo -e "${BLUE}Finale Verifikation:${NC}"
    echo ""
    
    echo "Services:"
    systemctl is-active tailscaled && echo -e "${GREEN}✓${NC} tailscaled" || echo -e "${RED}✗${NC} tailscaled"
    systemctl is-active caddy && echo -e "${GREEN}✓${NC} caddy" || echo -e "${RED}✗${NC} caddy"
    systemctl is-active code-server@root && echo -e "${GREEN}✓${NC} code-server" || echo -e "${RED}✗${NC} code-server"
    docker ps | grep -q ollama && echo -e "${GREEN}✓${NC} ollama" || echo -e "${RED}✗${NC} ollama"
    
    echo ""
    echo "Tailscale IP:"
    tailscale ip -4
    
    echo ""
    echo -e "${GREEN}System sollte jetzt über Tailscale erreichbar sein:${NC}"
    echo "  SSH: ssh root@devsystem-vps.tailcfea8a.ts.net"
    echo "  Web: https://devsystem-vps.tailcfea8a.ts.net:9443"
else
    echo ""
    echo -e "${YELLOW}Keine Reparatur durchgeführt.${NC}"
    echo ""
    echo "Manuelle Reparatur-Befehle:"
    echo "  systemctl start tailscaled"
    echo "  systemctl start caddy"
    echo "  systemctl start code-server@root"
    echo "  docker start ollama"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Skript beendet${NC}"
echo -e "${BLUE}========================================${NC}"
