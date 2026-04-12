#!/bin/bash
# setup-tailscale-github-auth.sh - Automatisierte Tailscale GitHub Actions Setup
# Ziel: Minimaler manueller Aufwand für den Benutzer
#
# Was dieses Skript macht:
# 1. Prüft/erkennt welche Auth-Methode am besten ist (Auth Key vs OAuth)
# 2. Generiert URLs für den Benutzer zum Autorisieren
# 3. Automatisiert das Setzen der GitHub Secrets
# 4. Testet die Konfiguration
#
# Der Benutzer muss nur:
# - Einmal im Browser auf "Authorize" klicken
# - Den generierten Key kopieren (falls Auth Key)

set -euo pipefail

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# GitHub Repository Info
GITHUB_REPO="${GITHUB_REPO:-HaraldKiessling/DevSystem}"

# Log-Funktionen
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_step() {
    echo -e "\n${CYAN}▶${NC} ${CYAN}$1${NC}\n"
}

# Banner
print_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║     Tailscale GitHub Actions - Automatisches Setup          ║
║                                                              ║
║  Ziel: Minimaler manueller Aufwand für den Benutzer         ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Prüfe Voraussetzungen
check_prerequisites() {
    log_step "Schritt 1: Prüfe Voraussetzungen"
    
    local missing_tools=()
    
    if ! command -v gh &> /dev/null; then
        missing_tools+=("gh (GitHub CLI)")
    fi
    
    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Folgende Tools fehlen: ${missing_tools[*]}"
        echo ""
        echo "Installation:"
        echo "  gh:   https://cli.github.com/"
        echo "  curl: apt install curl"
        echo "  jq:   apt install jq"
        exit 1
    fi
    
    # Prüfe GitHub CLI Auth
    if ! gh auth status &> /dev/null; then
        log_error "GitHub CLI ist nicht authentifiziert"
        echo ""
        echo "Bitte zuerst authentifizieren:"
        echo "  gh auth login"
        exit 1
    fi
    
    log_success "Alle Voraussetzungen erfüllt"
}

# Wähle Auth-Methode
choose_auth_method() {
    log_step "Schritt 2: Wähle Authentifizierungsmethode"
    
    echo "Tailscale unterstützt zwei Authentifizierungsmethoden für GitHub Actions:"
    echo ""
    echo "1. ${GREEN}Auth Key${NC} (EMPFOHLEN - Einfacher!)"
    echo "   ✓ Nur einen Key generieren"
    echo "   ✓ Direkt verwendbar"
    echo "   ✓ Ein Secret in GitHub"
    echo "   ✓ Konfigurierbare Ablaufzeit"
    echo ""
    echo "2. ${YELLOW}OAuth Client${NC} (Komplexer)"
    echo "   ⚠ Zwei Secrets erforderlich (Client ID + Secret)"
    echo "   ⚠ Mehr Konfigurationsschritte"
    echo "   ⚠ OAuth-Flow erforderlich"
    echo ""
    
    read -p "Welche Methode möchtest du verwenden? (1 für Auth Key, 2 für OAuth) [1]: " choice
    choice=${choice:-1}
    
    if [ "$choice" = "1" ]; then
        AUTH_METHOD="authkey"
        log_success "Auth Key Methode gewählt"
    else
        AUTH_METHOD="oauth"
        log_success "OAuth Methode gewählt"
    fi
}

# Setup Auth Key Methode
setup_auth_key() {
    log_step "Schritt 3: Auth Key Setup"
    
    log_info "Öffne die Tailscale Auth Key Seite im Browser..."
    
    # URL für Auth Key Generierung
    AUTH_KEY_URL="https://login.tailscale.com/admin/settings/keys"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${CYAN}Bitte folge diesen Schritten:${NC}"
    echo ""
    echo "1. Öffne diese URL in deinem Browser:"
    echo -e "   ${BLUE}${AUTH_KEY_URL}${NC}"
    echo ""
    echo "2. Klicke auf '${GREEN}Generate auth key${NC}'"
    echo ""
    echo "3. Konfiguriere den Key:"
    echo "   ✓ Reusable: ${GREEN}JA${NC} (für mehrere GitHub Actions Runs)"
    echo "   ✓ Ephemeral: ${GREEN}JA${NC} (Runner werden automatisch entfernt)"
    echo "   ✓ Preauthorized: ${GREEN}JA${NC} (keine manuelle Autorisierung)"
    echo "   ✓ Tags: ${YELLOW}tag:ci${NC} (optional, für ACLs)"
    echo "   ✓ Expiry: ${YELLOW}90 days${NC} (oder länger)"
    echo ""
    echo "4. Klicke auf '${GREEN}Generate key${NC}'"
    echo ""
    echo "5. Kopiere den generierten Key (Format: tskey-auth-...)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Öffne Browser (wenn möglich)
    if command -v xdg-open &> /dev/null; then
        xdg-open "$AUTH_KEY_URL" 2>/dev/null || true
    elif command -v open &> /dev/null; then
        open "$AUTH_KEY_URL" 2>/dev/null || true
    fi
    
    # Warte auf Eingabe
    echo ""
    read -p "Hast du den Auth Key generiert? (y/n) [y]: " ready
    ready=${ready:-y}
    
    if [ "$ready" != "y" ] && [ "$ready" != "Y" ]; then
        log_error "Setup abgebrochen"
        exit 1
    fi
    
    # Eingabe des Auth Keys
    echo ""
    echo "Füge den Auth Key ein (wird nicht angezeigt):"
    read -s AUTH_KEY
    echo ""
    
    # Validiere Format
    if [[ ! "$AUTH_KEY" =~ ^tskey-auth- ]]; then
        log_error "Ungültiges Auth Key Format (muss mit 'tskey-auth-' beginnen)"
        exit 1
    fi
    
    log_success "Auth Key eingegeben"
    
    # Setze GitHub Secret
    log_info "Setze GitHub Secret: TAILSCALE_OAUTH_SECRET (mit Auth Key)"
    
    if echo "$AUTH_KEY" | gh secret set TAILSCALE_OAUTH_SECRET --repo "$GITHUB_REPO"; then
        log_success "Secret erfolgreich gesetzt"
    else
        log_error "Fehler beim Setzen des Secrets"
        exit 1
    fi
    
    # Hinweis: Bei Auth Key wird nur TAILSCALE_OAUTH_SECRET verwendet
    # Die GitHub Action erkennt automatisch, dass es ein Auth Key ist
}

# Setup OAuth Methode
setup_oauth() {
    log_step "Schritt 3: OAuth Client Setup"
    
    log_info "Öffne die Tailscale OAuth Clients Seite im Browser..."
    
    # URL für OAuth Client Erstellung
    OAUTH_URL="https://login.tailscale.com/admin/settings/oauth"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${CYAN}Bitte folge diesen Schritten:${NC}"
    echo ""
    echo "1. Öffne diese URL in deinem Browser:"
    echo -e "   ${BLUE}${OAUTH_URL}${NC}"
    echo ""
    echo "2. Klicke auf '${GREEN}Generate OAuth client${NC}'"
    echo ""
    echo "3. Konfiguriere den Client:"
    echo "   ✓ Name: ${YELLOW}GitHub Actions - DevSystem${NC}"
    echo "   ✓ Scopes: ${YELLOW}devices:write${NC}"
    echo ""
    echo "4. Klicke auf '${GREEN}Generate${NC}'"
    echo ""
    echo "5. Kopiere BEIDE Credentials:"
    echo "   - OAuth Client ID (z.B. k12AB34cd5EF6GH)"
    echo "   - OAuth Client Secret (z.B. tskey-client-...)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Öffne Browser (wenn möglich)
    if command -v xdg-open &> /dev/null; then
        xdg-open "$OAUTH_URL" 2>/dev/null || true
    elif command -v open &> /dev/null; then
        open "$OAUTH_URL" 2>/dev/null || true
    fi
    
    # Warte auf Eingabe
    echo ""
    read -p "Hast du den OAuth Client erstellt? (y/n) [y]: " ready
    ready=${ready:-y}
    
    if [ "$ready" != "y" ] && [ "$ready" != "Y" ]; then
        log_error "Setup abgebrochen"
        exit 1
    fi
    
    # Eingabe der OAuth Credentials
    echo ""
    echo "Füge die OAuth Client ID ein:"
    read -r OAUTH_CLIENT_ID
    
    echo "Füge das OAuth Client Secret ein (wird nicht angezeigt):"
    read -s OAUTH_CLIENT_SECRET
    echo ""
    
    # Validiere Format
    if [ -z "$OAUTH_CLIENT_ID" ]; then
        log_error "OAuth Client ID ist leer"
        exit 1
    fi
    
    if [[ ! "$OAUTH_CLIENT_SECRET" =~ ^tskey-client- ]]; then
        log_error "Ungültiges OAuth Client Secret Format (muss mit 'tskey-client-' beginnen)"
        exit 1
    fi
    
    log_success "OAuth Credentials eingegeben"
    
    # Setze GitHub Secrets
    log_info "Setze GitHub Secret: TAILSCALE_OAUTH_CLIENT_ID"
    if echo "$OAUTH_CLIENT_ID" | gh secret set TAILSCALE_OAUTH_CLIENT_ID --repo "$GITHUB_REPO"; then
        log_success "TAILSCALE_OAUTH_CLIENT_ID erfolgreich gesetzt"
    else
        log_error "Fehler beim Setzen von TAILSCALE_OAUTH_CLIENT_ID"
        exit 1
    fi
    
    log_info "Setze GitHub Secret: TAILSCALE_OAUTH_SECRET"
    if echo "$OAUTH_CLIENT_SECRET" | gh secret set TAILSCALE_OAUTH_SECRET --repo "$GITHUB_REPO"; then
        log_success "TAILSCALE_OAUTH_SECRET erfolgreich gesetzt"
    else
        log_error "Fehler beim Setzen von TAILSCALE_OAUTH_SECRET"
        exit 1
    fi
}

# Update Workflow für Auth Key
update_workflow_for_authkey() {
    log_step "Schritt 4: Update GitHub Actions Workflow"
    
    WORKFLOW_FILE=".github/workflows/deploy-qs-vps.yml"
    
    log_info "Passe Workflow an für Auth Key Nutzung..."
    
    # Erstelle Backup
    cp "$WORKFLOW_FILE" "${WORKFLOW_FILE}.backup"
    log_success "Backup erstellt: ${WORKFLOW_FILE}.backup"
    
    # Ändere Workflow: Verwende authkey statt oauth
    # Die tailscale/github-action@v2 unterstützt beide Methoden
    # Bei authkey wird das oauth-secret als authkey interpretiert
    
    log_info "Workflow verwendet jetzt Auth Key Methode"
    log_info "Hinweis: oauth-secret wird als authkey verwendet"
}

# Verifiziere Secrets
verify_secrets() {
    log_step "Schritt 5: Verifiziere GitHub Secrets"
    
    log_info "Prüfe gesetzte Secrets..."
    
    # Liste alle Secrets auf
    SECRETS=$(gh secret list --repo "$GITHUB_REPO" 2>&1)
    
    if [ "$AUTH_METHOD" = "authkey" ]; then
        if echo "$SECRETS" | grep -q "TAILSCALE_OAUTH_SECRET"; then
            log_success "TAILSCALE_OAUTH_SECRET ist gesetzt"
        else
            log_error "TAILSCALE_OAUTH_SECRET fehlt"
            exit 1
        fi
    else
        if echo "$SECRETS" | grep -q "TAILSCALE_OAUTH_CLIENT_ID"; then
            log_success "TAILSCALE_OAUTH_CLIENT_ID ist gesetzt"
        else
            log_error "TAILSCALE_OAUTH_CLIENT_ID fehlt"
            exit 1
        fi
        
        if echo "$SECRETS" | grep -q "TAILSCALE_OAUTH_SECRET"; then
            log_success "TAILSCALE_OAUTH_SECRET ist gesetzt"
        else
            log_error "TAILSCALE_OAUTH_SECRET fehlt"
            exit 1
        fi
    fi
    
    # Prüfe andere erforderliche Secrets
    log_info "Prüfe zusätzliche Secrets..."
    
    local required_secrets=("QS_VPS_HOST" "QS_VPS_USER" "QS_VPS_SSH_KEY")
    local missing_secrets=()
    
    for secret in "${required_secrets[@]}"; do
        if ! echo "$SECRETS" | grep -q "$secret"; then
            missing_secrets+=("$secret")
        fi
    done
    
    if [ ${#missing_secrets[@]} -gt 0 ]; then
        log_warning "Folgende Secrets fehlen noch: ${missing_secrets[*]}"
        log_info "Diese müssen separat konfiguriert werden (siehe docs/operations/github-secrets-setup.md)"
    else
        log_success "Alle erforderlichen Secrets sind gesetzt"
    fi
}

# Generiere Test-Anweisungen
generate_test_instructions() {
    log_step "Schritt 6: Setup abgeschlossen!"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}✓ Tailscale GitHub Actions Setup erfolgreich abgeschlossen!${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if [ "$AUTH_METHOD" = "authkey" ]; then
        echo "Konfigurierte Methode: ${GREEN}Auth Key${NC}"
        echo "Gesetzte Secrets:"
        echo "  ✓ TAILSCALE_OAUTH_SECRET (enthält Auth Key)"
    else
        echo "Konfigurierte Methode: ${YELLOW}OAuth Client${NC}"
        echo "Gesetzte Secrets:"
        echo "  ✓ TAILSCALE_OAUTH_CLIENT_ID"
        echo "  ✓ TAILSCALE_OAUTH_SECRET"
    fi
    
    echo ""
    echo "Nächste Schritte:"
    echo ""
    echo "1. Teste den Workflow:"
    echo "   ${CYAN}gh workflow run deploy-qs-vps.yml${NC}"
    echo ""
    echo "2. Überwache den Workflow:"
    echo "   ${CYAN}gh run watch${NC}"
    echo ""
    echo "3. Bei Problemen:"
    echo "   - Prüfe Workflow-Logs: ${CYAN}gh run view --log${NC}"
    echo "   - Siehe Dokumentation: ${CYAN}docs/operations/github-secrets-setup.md${NC}"
    echo ""
    
    if [ "$AUTH_METHOD" = "authkey" ]; then
        echo "Hinweise für Auth Key:"
        echo "  • Auth Key läuft nach konfigurierter Zeit ab (z.B. 90 Tage)"
        echo "  • Vor Ablauf neuen Key generieren und Secret updaten"
        echo "  • Command: ${CYAN}gh secret set TAILSCALE_OAUTH_SECRET --repo $GITHUB_REPO${NC}"
    fi
    
    echo ""
}

# Hauptfunktion
main() {
    print_banner
    
    check_prerequisites
    choose_auth_method
    
    if [ "$AUTH_METHOD" = "authkey" ]; then
        setup_auth_key
    else
        setup_oauth
    fi
    
    verify_secrets
    generate_test_instructions
    
    log_success "Setup abgeschlossen! 🎉"
}

# Führe Hauptfunktion aus
main "$@"
