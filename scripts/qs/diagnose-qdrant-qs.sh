#!/bin/bash
#
# QS-VPS: Qdrant Diagnose-Script
# Analysiert warum Qdrant nicht startet
#

echo "=== QDRANT DIAGNOSE ==="
echo ""

echo "1. SERVICE STATUS"
systemctl status qdrant-qs --no-pager -l || echo "Service nicht gefunden"
echo ""

echo "2. JOURNAL LOGS (letzte 30 Zeilen)"
journalctl -u qdrant-qs -n 30 --no-pager
echo ""

echo "3. BINARY PRÜFUNG"
echo "Binary existiert:"
ls -lh /opt/qdrant-qs/qdrant
echo ""
echo "Binary ausführbar:"
file /opt/qdrant-qs/qdrant
echo ""
echo "Version direkt:"
/opt/qdrant-qs/qdrant --version || echo "Fehler beim Aufruf"
echo ""

echo "4. KONFIGURATION"
echo "Config-Datei:"
ls -l /opt/qdrant-qs/config.yaml
echo ""
cat /opt/qdrant-qs/config.yaml
echo ""

echo "5. VERZEICHNIS-BERECHTIGUNGEN"
ls -la /opt/qdrant-qs/
echo ""
ls -la /var/lib/qdrant-qs/
echo ""
ls -la /var/log/qdrant-qs/
echo ""

echo "6. USER & GRUPPE"
id qdrant-qs
echo ""

echo "7. SYSTEMD SERVICE FILE"
cat /etc/systemd/system/qdrant-qs.service
echo ""

echo "8. MANUELLE START-VERSUCH (als qdrant-qs User)"
sudo -u qdrant-qs /opt/qdrant-qs/qdrant --version 2>&1 || echo "Fehler als User"
echo ""

echo "9. PORT-BELEGUNG"
ss -tlnp | grep -E "6333|6334" || echo "Keine Ports belegt"
echo ""

echo "=== DIAGNOSE ABGESCHLOSSEN ==="
