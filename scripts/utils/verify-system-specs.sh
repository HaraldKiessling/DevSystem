#!/bin/bash
#
# System Specs Verification Script
# 
# Sammelt Hardware- und Versions-Informationen vom VPS
# Verwendung: bash scripts/utils/verify-system-specs.sh

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🖥️  DevSystem Hardware & Version Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Hardware
echo "=== Hardware ==="
echo "CPU Cores: $(nproc)"
echo "CPU Model: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
echo "RAM Total: $(free -h | grep Mem | awk '{print $2}')"
echo "RAM Used: $(free -h | grep Mem | awk '{print $3}')"
echo "RAM Available: $(free -h | grep Mem | awk '{print $7}')"
echo "Disk Total: $(df -h / | tail -1 | awk '{print $2}')"
echo "Disk Used: $(df -h / | tail -1 | awk '{print $3}') ($(df -h / | tail -1 | awk '{print $5}'))"
echo "Disk Available: $(df -h / | tail -1 | awk '{print $4}')"
echo ""

# OS
echo "=== Operating System ==="
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo ""

# Services
echo "=== Service Versions ==="
if command -v tailscale >/dev/null 2>&1; then
  echo "Tailscale: $(tailscale version | head -1)"
else
  echo "Tailscale: Not installed"
fi

if command -v caddy >/dev/null 2>&1; then
  echo "Caddy: $(caddy version 2>&1 | head -1)"
else
  echo "Caddy: Not installed"
fi

if command -v code-server >/dev/null 2>&1; then
  echo "code-server: $(code-server --version 2>&1 | head -1)"
else
  echo "code-server: Not installed"
fi

if docker ps | grep -q qdrant; then
  echo "Qdrant: $(docker exec qdrant curl -s http://localhost:6333/health 2>/dev/null | jq -r .version || echo 'Running but version unavailable')"
else
  echo "Qdrant: Not running"
fi

echo ""

# Service Status
echo "=== Service Status ==="
for service in tailscaled caddy code-server qdrant; do
  if systemctl list-unit-files | grep -q "^${service}.service"; then
    status=$(systemctl is-active $service 2>/dev/null || echo "inactive")
    echo "$service: $status"
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Verification Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
