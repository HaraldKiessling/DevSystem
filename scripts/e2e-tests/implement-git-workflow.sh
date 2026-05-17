#!/bin/bash
#
# implement-git-workflow.sh
# 
# Dieses Skript implementiert den Git-Workflow für die automatisierten E2E-Tests
# gemäß dem Implementierungsplan in plans/e2e-tests-implementation-plan.md.
#
# Teil der Umsetzung von GitHub Issue #18.
# 

# Farbkonstanten für bessere Lesbarkeit
GRÜN='\033[0;32m'
ROT='\033[0;31m'
GELB='\033[1;33m'
BLAU='\033[0;34m'
FETT='\033[1m'
NORMAL='\033[0m'

# Variablen
FEATURE_BRANCH="feature/e2e-tests-automation"
TAG_NAME="v1.0.0-e2e-tests"
TAG_MESSAGE="Release v1.0.0: Automatisierte E2E-Tests für code-server"
COMMIT_MESSAGE="feat: Implementiere automatisierte E2E-Tests für code-server"

# Funktion für Ausgaben mit farbiger Formatierung
log_info() {
  echo -e "${BLAU}[INFO]${NORMAL} $1"
}

log_success() {
  echo -e "${GRÜN}[ERFOLG]${NORMAL} $1"
}

log_warning() {
  echo -e "${GELB}[WARNUNG]${NORMAL} $1"
}

log_error() {
  echo -e "${ROT}[FEHLER]${NORMAL} $1"
}

log_step() {
  echo -e "\n${FETT}===== SCHRITT $1: $2 =====${NORMAL}"
}

# Funktion zur Bestätigungsabfrage
confirm_step() {
  echo -e "${GELB}[BESTÄTIGUNG]${NORMAL} $1 (j/n): "
  read -r antwort
  if [[ ! $antwort =~ ^[jJ]$ ]]; then
    log_warning "Schritt übersprungen oder abgebrochen."
    return 1
  fi
  return 0
}

# Funktion zur Fehlerbehandlung
handle_error() {
  log_error "$1"
  log_error "Der Workflow wurde unterbrochen. Bitte beheben Sie den Fehler und versuchen Sie es erneut."
  exit 1
}

# Funktion zum Prüfen des Git-Status
check_git_status() {
  if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    handle_error "Dieses Skript muss innerhalb eines Git-Repositories ausgeführt werden."
  fi
  
  if [ -n "$(git status --porcelain)" ]; then
    log_warning "Es gibt nicht commitete Änderungen im Arbeitsverzeichnis:"
    git status --short
    
    if ! confirm_step "Möchten Sie trotzdem fortfahren? Nicht commitete Änderungen könnten den Workflow beeinflussen."; then
      handle_error "Workflow auf Benutzeranfrage abgebrochen."
    fi
  fi
}

# Funktion zum Überprüfen, ob der Feature-Branch bereits existiert
branch_exists() {
  git show-ref --verify --quiet "refs/heads/$1"
  return $?
}

# Funktion zum Überprüfen, ob der Tag bereits existiert
tag_exists() {
  git show-ref --verify --quiet "refs/tags/$1"
  return $?
}

# Funktion zum Überprüfen, ob der Remote-Branch existiert
remote_branch_exists() {
  git ls-remote --exit-code --heads origin "$1" > /dev/null 2>&1
  return $?
}

# Hauptfunktion, die den Workflow ausführt
execute_workflow() {
  # Vorbereitende Prüfungen
  check_git_status

  # Schritt 1: Feature-Branch erstellen
  log_step "1" "Feature-Branch erstellen: $FEATURE_BRANCH"
  log_info "Ein Feature-Branch wird erstellt, um die Änderungen zu isolieren."
  
  if branch_exists "$FEATURE_BRANCH"; then
    log_warning "Der Branch '$FEATURE_BRANCH' existiert bereits."
    if confirm_step "Möchten Sie den bestehenden Branch verwenden?"; then
      git checkout "$FEATURE_BRANCH" || handle_error "Konnte nicht zum Branch '$FEATURE_BRANCH' wechseln."
      log_success "Zum bestehenden Branch gewechselt."
    else
      handle_error "Workflow abgebrochen. Bitte löschen oder umbenennen Sie den bestehenden Branch."
    fi
  else
    if confirm_step "Möchten Sie den Feature-Branch '$FEATURE_BRANCH' erstellen?"; then
      git checkout -b "$FEATURE_BRANCH" || handle_error "Konnte den Branch '$FEATURE_BRANCH' nicht erstellen."
      log_success "Feature-Branch erfolgreich erstellt."
    else
      handle_error "Branch-Erstellung abgebrochen."
    fi
  fi

  # Schritt 2: Wechsel zum Branch bestätigen
  log_step "2" "Wechsel zum Branch bestätigen"
  log_info "Bestätigen, dass wir uns im richtigen Branch befinden."
  
  current_branch=$(git branch --show-current)
  if [ "$current_branch" != "$FEATURE_BRANCH" ]; then
    handle_error "Unerwarteter Branch: $current_branch. Erwartet: $FEATURE_BRANCH"
  fi
  log_success "Wir befinden uns im Branch: $current_branch"
  
  # Schritt 3: Änderungen stagen
  log_step "3" "Änderungen stagen"
  log_info "Die Änderungen im scripts/e2e-tests/ Verzeichnis werden zum Staging-Bereich hinzugefügt."
  
  if confirm_step "Möchten Sie alle Änderungen im Verzeichnis 'scripts/e2e-tests/' stagen?"; then
    git add scripts/e2e-tests/ || handle_error "Konnte Änderungen nicht stagen."
    log_success "Änderungen erfolgreich gestaged."
    git status --short
  else
    handle_error "Staging der Änderungen abgebrochen."
  fi
  
  # Schritt 4: Commit mit aussagekräftiger Message
  log_step "4" "Commit mit aussagekräftiger Message"
  log_info "Die gestageten Änderungen werden mit einer aussagekräftigen Commit-Nachricht committet."
  
  echo -e "Commit-Nachricht: ${FETT}$COMMIT_MESSAGE${NORMAL}"
  if confirm_step "Möchten Sie die Änderungen mit dieser Nachricht committen?"; then
    git commit -m "$COMMIT_MESSAGE" || handle_error "Konnte Änderungen nicht committen."
    log_success "Änderungen erfolgreich committet."
  else
    log_warning "Möchten Sie eine alternative Commit-Nachricht eingeben?"
    if confirm_step "Alternative Commit-Nachricht eingeben?"; then
      echo -e "${GELB}[EINGABE]${NORMAL} Bitte geben Sie die neue Commit-Nachricht ein:"
      read -r new_commit_message
      git commit -m "$new_commit_message" || handle_error "Konnte Änderungen nicht committen."
      log_success "Änderungen mit alternativer Nachricht committet."
    else
      handle_error "Commit abgebrochen."
    fi
  fi
  
  # Schritt 5: Wechsel zu main
  log_step "5" "Wechsel zu main"
  log_info "Wir wechseln zurück zum main Branch, um später den Feature-Branch zu mergen."
  
  if confirm_step "Möchten Sie zum main Branch wechseln?"; then
    git checkout main || handle_error "Konnte nicht zum main Branch wechseln."
    log_success "Erfolgreich zum main Branch gewechselt."
  else
    handle_error "Wechsel zum main Branch abgebrochen."
  fi
  
  # Schritt 6: Merge mit No-FF-Option
  log_step "6" "Merge mit No-FF-Option"
  log_info "Der Feature-Branch wird mit der No-Fast-Forward-Option in den main Branch gemerged."
  log_info "Dies bewahrt die Feature-Branch-Historie und macht den Merge im Git-Log besser sichtbar."
  
  if confirm_step "Möchten Sie den Branch '$FEATURE_BRANCH' mit No-FF in main mergen?"; then
    git merge "$FEATURE_BRANCH" --no-ff || handle_error "Konnte den Branch nicht mergen. Möglicherweise gibt es Konflikte."
    log_success "Branch erfolgreich gemerged."
  else
    handle_error "Merge abgebrochen."
  fi
  
  # Schritt 7: Tag erstellen
  log_step "7" "Tag erstellen: $TAG_NAME"
  log_info "Ein annotierter Tag wird erstellt, um diesen Meilenstein zu kennzeichnen."
  
  if tag_exists "$TAG_NAME"; then
    log_warning "Der Tag '$TAG_NAME' existiert bereits."
    if confirm_step "Möchten Sie den bestehenden Tag überschreiben?"; then
      git tag -d "$TAG_NAME" || handle_error "Konnte bestehenden Tag nicht löschen."
      git tag -a "$TAG_NAME" -m "$TAG_MESSAGE" || handle_error "Konnte Tag nicht erstellen."
      log_success "Tag erfolgreich überschrieben."
    else
      handle_error "Tag-Erstellung abgebrochen. Bitte wählen Sie einen anderen Tag-Namen."
    fi
  else {
    if confirm_step "Möchten Sie den Tag '$TAG_NAME' mit der Nachricht '$TAG_MESSAGE' erstellen?"; then
      git tag -a "$TAG_NAME" -m "$TAG_MESSAGE" || handle_error "Konnte Tag nicht erstellen."
      log_success "Tag erfolgreich erstellt."
    else
      log_warning "Möchten Sie einen alternativen Tag-Namen und/oder -Nachricht eingeben?"
      if confirm_step "Alternative Tag-Information eingeben?"; then
        echo -e "${GELB}[EINGABE]${NORMAL} Bitte geben Sie den neuen Tag-Namen ein:"
        read -r new_tag_name
        echo -e "${GELB}[EINGABE]${NORMAL} Bitte geben Sie die neue Tag-Nachricht ein:"
        read -r new_tag_message
        git tag -a "$new_tag_name" -m "$new_tag_message" || handle_error "Konnte Tag nicht erstellen."
        TAG_NAME="$new_tag_name"
        log_success "Tag mit alternativen Informationen erstellt."
      else
        handle_error "Tag-Erstellung abgebrochen."
      fi
    fi
  }
  fi
  
  # Schritt 8: Push zu Remote
  log_step "8" "Push zu Remote"
  log_info "Die Änderungen im main Branch werden zu Remote (origin) gepusht."
  
  if confirm_step "Möchten Sie den main Branch zu origin pushen?"; then
    git push origin main || handle_error "Konnte nicht zu origin/main pushen. Überprüfen Sie Ihre Berechtigungen und Verbindung."
    log_success "Main Branch erfolgreich zu origin gepusht."
  else
    handle_error "Push abgebrochen. KRITISCH: Die lokalen Änderungen wurden nicht zu Remote übertragen!"
  fi
  
  # Schritt 9: Tags zu Remote pushen
  log_step "9" "Tags zu Remote pushen"
  log_info "Der erstellte Tag wird zu Remote (origin) gepusht."
  
  if confirm_step "Möchten Sie den Tag '$TAG_NAME' zu origin pushen?"; then
    git push origin --tags || handle_error "Konnte Tags nicht zu origin pushen."
    log_success "Tags erfolgreich zu origin gepusht."
  else
    handle_error "Tag-Push abgebrochen. KRITISCH: Der lokale Tag wurde nicht zu Remote übertragen!"
  fi
  
  # Schritt 10: Push-Erfolg verifizieren
  log_step "10" "Push-Erfolg verifizieren"
  log_info "Der Push-Erfolg wird durch Überprüfung des Logs von origin/main verifiziert."
  
  if confirm_step "Möchten Sie den Push-Erfolg überprüfen?"; then
    echo -e "\n${FETT}Log der letzten 3 Commits in origin/main:${NORMAL}"
    git log origin/main -3 --oneline || handle_error "Konnte Log nicht abrufen."
    log_success "Push-Erfolg verifiziert: Die Commits sind in origin/main sichtbar."
  else
    log_warning "Überprüfung übersprungen. Es wird angenommen, dass der Push erfolgreich war."
  fi
  
  # Schritt 11: Feature-Branch lokal löschen
  log_step "11" "Feature-Branch lokal löschen"
  log_info "Der Feature-Branch wird lokal gelöscht, da er nicht mehr benötigt wird."
  
  if confirm_step "Möchten Sie den lokalen Feature-Branch '$FEATURE_BRANCH' löschen?"; then
    git branch -d "$FEATURE_BRANCH" || {
      log_warning "Konnte Branch nicht mit -d löschen. Versuche mit -D (force)."
      if confirm_step "Möchten Sie den Branch mit -D (force) löschen?"; then
        git branch -D "$FEATURE_BRANCH" || handle_error "Konnte Branch nicht löschen."
      else
        log_warning "Force-Löschung abgebrochen. Branch bleibt bestehen."
      fi
    }
    if ! branch_exists "$FEATURE_BRANCH"; then
      log_success "Feature-Branch lokal erfolgreich gelöscht."
    fi
  else
    log_warning "Löschung des lokalen Branch abgebrochen. Branch bleibt bestehen."
  fi
  
  # Schritt 12: Feature-Branch remote löschen
  log_step "12" "Feature-Branch remote löschen"
  log_info "Der Feature-Branch wird auch auf Remote (origin) gelöscht, falls er existiert."
  
  if remote_branch_exists "$FEATURE_BRANCH"; then
    if confirm_step "Möchten Sie den Remote-Feature-Branch '$FEATURE_BRANCH' löschen?"; then
      git push origin --delete "$FEATURE_BRANCH" || handle_error "Konnte Remote-Branch nicht löschen."
      log_success "Feature-Branch auf origin erfolgreich gelöscht."
    else
      log_warning "Löschung des Remote-Branch abgebrochen. Branch bleibt auf origin bestehen."
    fi
  else
    log_info "Der Branch '$FEATURE_BRANCH' existiert nicht auf origin. Keine Löschung erforderlich."
  fi
  
  # Workflow abgeschlossen
  echo -e "\n${FETT}${GRÜN}===== GIT-WORKFLOW ERFOLGREICH ABGESCHLOSSEN =====${NORMAL}"
  echo -e "${GRÜN}Alle Schritte wurden erfolgreich durchgeführt. Die E2E-Tests sind nun in den main Branch integriert.${NORMAL}"
  echo -e "${GRÜN}Der Tag '$TAG_NAME' wurde erstellt und zu Remote gepusht.${NORMAL}"
  echo -e "${GRÜN}Die Implementierung für GitHub Issue #18 ist abgeschlossen.${NORMAL}"
}

# Hauptprogramm
echo -e "${FETT}${BLAU}===== AUTOMATISIERTER GIT-WORKFLOW FÜR E2E-TESTS =====${NORMAL}"
echo -e "${BLAU}Dieses Skript führt den Git-Workflow für die Implementierung der automatisierten E2E-Tests durch.${NORMAL}"
echo -e "${BLAU}Teil der Umsetzung von GitHub Issue #18.${NORMAL}"
echo -e "${BLAU}Jeder Schritt wird erklärt und kann bestätigt oder übersprungen werden.${NORMAL}\n"

if confirm_step "Möchten Sie mit dem Git-Workflow beginnen?"; then
  execute_workflow
else
  log_warning "Git-Workflow abgebrochen."
  exit 0
fi