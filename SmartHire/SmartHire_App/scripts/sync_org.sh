#!/bin/bash

# Skrypt do synchronizacji zmian z organizacji Salesforce
# Autor: Anna Polanczyk
# Data: $(date +%Y-%m-%d)

# Ustawienia
ORG_ALIAS="myOrg"
MANIFEST_PATH="manifest/package.xml"
LOG_FILE="sync_log.txt"

# Funkcja do logowania
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a $LOG_FILE
}

# Rozpoczęcie synchronizacji
log "Rozpoczęcie synchronizacji z organizacją $ORG_ALIAS"

# Sprawdzenie, czy plik manifestu istnieje
if [ ! -f "$MANIFEST_PATH" ]; then
    log "Plik manifestu $MANIFEST_PATH nie istnieje. Generowanie..."
    sf project generate manifest --source-dir force-app --output-dir manifest --name package.xml
    if [ $? -ne 0 ]; then
        log "Błąd podczas generowania manifestu. Kończenie."
        exit 1
    fi
    log "Manifest wygenerowany pomyślnie."
fi

# Pobranie zmian z organizacji Salesforce
log "Pobieranie zmian z organizacji $ORG_ALIAS..."
sf project retrieve start -x $MANIFEST_PATH -o $ORG_ALIAS

if [ $? -ne 0 ]; then
    log "Błąd podczas pobierania zmian. Kończenie."
    exit 1
fi

log "Zmiany pobrane pomyślnie."

# Sprawdzenie, czy są jakieś zmiany do zacommitowania
git status --porcelain | grep -q "force-app"
if [ $? -eq 0 ]; then
    log "Wykryto zmiany w lokalnym repozytorium."
    
    # Opcjonalnie: automatyczne commitowanie zmian
    # git add force-app
    # git commit -m "Automatyczna synchronizacja z organizacją Salesforce - $(date +%Y-%m-%d)"
    # log "Zmiany zacommitowane lokalnie."
    
    # Opcjonalnie: automatyczne pushowanie zmian
    # git push
    # log "Zmiany wypchnięte do zdalnego repozytorium."
else
    log "Brak zmian do zacommitowania."
fi

log "Synchronizacja zakończona pomyślnie."
exit 0 