#!/usr/bin/env bash

# --------------------------------------------------------------------------------
# Header-Block: Zeigt den Header und grundlegende Informationen an
# --------------------------------------------------------------------------------

clear

YW=$(tput setaf 3)  # Gelb
GN=$(tput setaf 2)  # Grün
RD=$(tput setaf 1)  # Rot
BL=$(tput setaf 4)  # Blau
CY=$(tput setaf 6)  # Cyan
OR=$(tput setaf 5)  # Orange
CL=$(tput sgr0)     # Reset

function header_info {
    echo -e "\033[1;36m    ___         __      _____"
    echo -e "   /   | __  __/ /_____/ ___/___  ______   \033[1;34m____"
    echo -e "  / /| |/ / / / __/ __ \\\\__ \/ _ \/ ___/ |\033[1;36m / /_ \\"
    echo -e " / ___ / /_/ / /_/ /_/ /__/   __/  /  | |\033[1;34m/ / __/"
    echo -e "/_/  |_\\\\__,_/\\\\__/\\\\____/____/\\\\___/_/   |___\033[1;36m/\\\\___/"
    echo -e "\033[1;36m       -- Autonome Serverkonfiguration --\033[0m${CL}"
    echo -e "\033[1;34m════════════════════════════════════════════════"
    echo -e "\033[1;36m        eBay-Kleinanzeigen API Installer        "
    echo -e "\033[1;34m════════════════════════════════════════════════"
    echo
}

header_info

# --------------------------------------------------------------------------------
# Globale Variablen
# --------------------------------------------------------------------------------

INSTALL_DIR="/opt/ebay-kleinanzeigen-api"                            # Installationsverzeichnis
SERVICE_PATH="/etc/systemd/system/ebay-kleinanzeigen-api.service"    # Pfad zur Systemd-Service-Datei
BUILD_DIR="/usr/src/python_build"                                    # Build-Verzeichnis für Python-Kompilierung
IP=$(hostname -I | awk '{print $1}')                                 # IP-Adresse des Servers
DEFAULT_PORT=8000                                                    # Standardport für die API
LOG_FILE="/tmp/ebay-kleinanzeigen-api.log"                           # Log-Datei für Installationsschritte
PYTHON_VERSION=""                                                    # Python-Version (wird später vom Benutzer eingegeben)

# --------------------------------------------------------------------------------
# Hilfsfunktionen
# --------------------------------------------------------------------------------

function msg_info() {
    echo -e "${YW}═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${YW}💡 ${1}${CL}"
    echo -e "${YW}═══════════════════════════════════════════════════════════════════════════════"
}

function msg_ok() {
    echo -e "${GN}═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${GN}✅ ${1}${CL}"
    echo -e "${GN}═══════════════════════════════════════════════════════════════════════════════"
}

function msg_error() {
    echo -e "${RD}═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${RD}❎ ${1}${CL}"
    echo -e "${RD}═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${CL}"
    exit 1
}

function msg_warn() {
    echo -e "${OR}═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${OR}❗${1}${CL}"
    echo -e "${OR}═══════════════════════════════════════════════════════════════════════════════"
}

# Bestätigungsabfrage
function confirm_step() {
    local question="$1"
    msg_info "$question"  # Zeigt die Frage als informative Meldung an
    read -p "${YW}Antwort (y/N): ${CL}" -n 1 -r
    echo -e "\n"
    [[ $REPLY =~ ^[Yy]$ ]]
}

function validate_version() {
    local version=$1
    if [[ -z "$version" ]]; then
        msg_error "Python-Version darf nicht leer sein."
        return 1
    fi

    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        msg_error "Ungültiges Format. Bitte im Format X.Y.Z eingeben (z.B. 3.12.3)."
        return 1
    fi

    IFS='.' read -r -a parts <<< "$version"
    if (( ${parts[0]} < 3 )) || (( ${parts[1]} < 12 )); then
        msg_error "Mindestanforderung: Python 3.12.0 oder höher!"
        return 1
    fi

    return 0
}

# --------------------------------------------------------------------------------
# pyenv-Funktionen
# --------------------------------------------------------------------------------

# Prüft, ob ein vorhandener .pyenv-Ordner existiert und fragt nach seiner Entfernung
function check_and_remove_existing_pyenv() {
    local pyenv_dir="$HOME/.pyenv"
    if [[ -d "$pyenv_dir" ]]; then
        msg_warn "Ein vorhandener pyenv-Ordner wurde gefunden: $pyenv_dir."
        if confirm_step "Möchten Sie den vorhandenen pyenv-Ordner entfernen?"; then
            msg_info "Entferne vorhandenen pyenv-Ordner..."
            rm -rf "$pyenv_dir" || msg_error "Entfernen des pyenv-Ordners fehlgeschlagen."
            msg_ok "Vorhandener pyenv-Ordner erfolgreich entfernt."
        else
            msg_error "Die Installation von pyenv kann nicht fortgesetzt werden, solange der vorhandene pyenv-Ordner existiert."
            exit 1
        fi
    fi
}

# Installiert pyenv
function install_pyenv() {
    msg_info "Installiere pyenv."

    # Überprüfe und entferne vorhandenen .pyenv-Ordner, falls nötig
    check_and_remove_existing_pyenv

    if ! command -v pyenv &>/dev/null; then
        curl https://pyenv.run | bash >> "$LOG_FILE" 2>&1 || \
            msg_error "Installation von pyenv fehlgeschlagen."
        export PATH="$HOME/.pyenv/bin:$PATH"
        eval "$(pyenv init --path)"
        eval "$(pyenv init -)"
    else
        msg_ok "pyenv ist bereits installiert."
    fi
}

# Python-Version mit pyenv installieren
function install_python_with_pyenv() {
    local version=$PYTHON_VERSION
    msg_info "Installiere Python ${version} mit pyenv. Dies kann mehrere Minuten dauern."

    if ! pyenv versions | grep -q "${version}"; then
        pyenv install "${version}" >> "$LOG_FILE" 2>&1 || \
            msg_error "Installation von Python ${version} mit pyenv fehlgeschlagen."
        pyenv global "${version}" || \
            msg_error "Festlegen der globalen Python-Version fehlgeschlagen."
    else
        msg_ok "Python ${version} ist bereits mit pyenv installiert."
    fi

    msg_ok "Python ${version} erfolgreich installiert."
}

# --------------------------------------------------------------------------------
# Prüft die Python-Version
# --------------------------------------------------------------------------------

function check_python_version() {
    msg_info "Überprüfe installierte Python-Version."

    local installed_version=$(python3 --version 2>&1 | cut -d ' ' -f 2)
    if [[ -z "$installed_version" ]]; then
        msg_info "Keine Python-Version gefunden. Python ${PYTHON_VERSION} wird mit pyenv installiert."
        return 1
    fi

    IFS='.' read -r -a parts <<< "$installed_version"
    if (( ${parts[0]} < 3 )) || (( ${parts[1]} < 12 )); then
        msg_warn "Python-Version ($installed_version) ist zu alt."
        if confirm_step "Möchten Sie Python ${PYTHON_VERSION} mit pyenv installieren?"; then
            msg_info "Python ${PYTHON_VERSION} wird mit pyenv installiert."
            return 1
        else
            msg_error "Installation abgebrochen."
            exit 1
        fi
    fi

    msg_ok "Python $installed_version ist bereits installiert und erfüllt die Anforderungen."
    if confirm_step "Möchten Sie die installierte Python-Version ($installed_version) behalten?"; then
        msg_ok "Die aktuelle Python-Version wird beibehalten."
        return 0
    else
        msg_info "Python ${PYTHON_VERSION} wird mit pyenv installiert."
        return 1
    fi
}

# --------------------------------------------------------------------------------
# Port-Prüfung
# --------------------------------------------------------------------------------

function check_port_available() {
    local port=$DEFAULT_PORT
    while sudo lsof -i :$port > /dev/null 2>&1; do
        msg_error "Port ${YW}$port${RD} ist bereits belegt."
        read -p "${YW}Bitte geben Sie einen anderen Port ein: ${CL}" new_port
        if [[ -z "$new_port" ]]; then
            msg_error "Port darf nicht leer sein."
            continue
        fi
        if ! [[ "$new_port" =~ ^[0-9]+$ ]]; then
            msg_error "Ungültige Eingabe. Bitte geben Sie eine numerische Portnummer ein."
            continue
        fi
        port=$new_port
    done
    DEFAULT_PORT=$port
    msg_ok "Port $DEFAULT_PORT ist verfügbar."
}

# --------------------------------------------------------------------------------
# Voraussetzungen installieren
# --------------------------------------------------------------------------------

function install_prerequisites() {
    msg_info "Installiere grundlegende Tools."
    local tools=("git" "net-tools" "curl")
    local missing=()

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
        fi
    done

    if [ ${#missing[@]} -eq 0 ]; then
        msg_ok "Alle benötigten Tools sind bereits installiert."
        return
    fi

    msg_info "Die folgenden Tools müssen noch installiert werden:"
    for tool in "${missing[@]}"; do
        echo -e "${YW}• $tool${CL}"
    done

    if ! confirm_step "Möchten Sie diese Tools installieren?"; then
        msg_error "Installation abgebrochen."
    fi

    sudo apt-get update >> "$LOG_FILE" 2>&1 || msg_error "Paketquellen aktualisieren fehlgeschlagen."
    sudo apt-get install -y "${missing[@]}" >> "$LOG_FILE" 2>&1 || msg_error "Tool-Installation fehlgeschlagen."
    msg_ok "Erforderliche Tools wurden erfolgreich installiert."
}

# --------------------------------------------------------------------------------
# Systemabhängigkeiten installieren
# --------------------------------------------------------------------------------

function install_dependencies() {
    msg_info "Installiere Systemabhängigkeiten."

    local deps=(
        build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev
        libssl-dev libreadline-dev libffi-dev libbz2-dev libsqlite3-dev
        liblzma-dev tk-dev libdb5.3-dev uuid-dev libgpm2 libxml2-dev
        libxmlsec1-dev mlocate python3-packaging python3-venv

        # Playwright-Abhängigkeiten
        libatk1.0-0 libatk-bridge2.0-0 libcups2 libxcomposite1
        libxdamage1 libxfixes3 libxrandr2 libgbm1 libxkbcommon0
        libpango-1.0-0 libcairo2 libasound2 libatspi2.0-0
    )

    msg_info "Die folgenden Pakete werden installiert:"
    for dep in "${deps[@]}"; do
        echo -e "${YW}• $dep${CL}"
    done

    if ! confirm_step "Möchten Sie diese Abhängigkeiten installieren? Dauer: 1-2 Minuten"; then
        msg_error "Installation abgebrochen."
    fi

    sudo apt-get update >> "$LOG_FILE" 2>&1 || msg_error "Paketquellen aktualisieren fehlgeschlagen."
    sudo apt-get install -y "${deps[@]}" >> "$LOG_FILE" 2>&1 || msg_error "Abhängigkeiten-Installation fehlgeschlagen."
    msg_ok "Systemabhängigkeiten installiert."
}

# --------------------------------------------------------------------------------
# Projekt einrichten
# --------------------------------------------------------------------------------
function setup_project() {
    msg_info "Richte Projekt ein."

    # Überprüfe, ob das Installationsverzeichnis bereits existiert
    if [ -d "$INSTALL_DIR" ]; then
        msg_info "Verzeichnis $INSTALL_DIR existiert bereits. Aktualisiere Repository."
        
        # Stelle sicher, dass wir im richtigen Verzeichnis sind
        cd "$INSTALL_DIR" || msg_error "Wechsel zu $INSTALL_DIR fehlgeschlagen."
        # Führe git pull aus, um das Repository zu aktualisieren
        git pull origin main || msg_error "Aktualisierung des Repositoriums fehlgeschlagen."
    else
        msg_info "Klone Repository nach $INSTALL_DIR."
        
        # Erstelle das Installationsverzeichnis
        sudo mkdir -p "$INSTALL_DIR" || msg_error "Erstellung von $INSTALL_DIR fehlgeschlagen."
        sudo chown -R "$USER:$USER" "$INSTALL_DIR" || msg_error "Berechtigungen für $INSTALL_DIR konnten nicht gesetzt werden."
        # Klonen des Repositories
        git clone -q https://github.com/sakis-tech/ebay-kleinanzeigen-api.git "$INSTALL_DIR" || \
            msg_error "Klonen des Repositoriums fehlgeschlagen."
        cd "$INSTALL_DIR" || msg_error "Wechsel zu $INSTALL_DIR fehlgeschlagen."
    fi

    msg_ok "Projekt erfolgreich eingerichtet."
}

# --------------------------------------------------------------------------------
# Python-Umgebung einrichten
# --------------------------------------------------------------------------------
function setup_python_environment() {
    msg_info "Richte Python-Umgebung ein."

    # Stelle sicher, dass wir im Installationsverzeichnis sind
    cd "$INSTALL_DIR" || msg_error "Wechsel zu $INSTALL_DIR fehlgeschlagen."

    # Überprüfe, ob die virtuelle Umgebung bereits existiert
    if [ -d "$INSTALL_DIR/.venv" ]; then
        msg_ok "Virtuelle Umgebung in $INSTALL_DIR/.venv existiert bereits."
    else
        msg_info "Erstelle neue virtuelle Umgebung."
        python3 -m venv .venv || msg_error "Erstellung der virtuellen Umgebung fehlgeschlagen."
    fi

    # Aktiviere die virtuelle Umgebung
    source "$INSTALL_DIR/.venv/bin/activate" || msg_error "Aktivierung der virtuellen Umgebung fehlgeschlagen."

    # Aktualisiere pip auf die neueste Version
    msg_info "Aktualisiere pip auf die neueste Version..."
    python3 -m pip install --upgrade pip >> "$LOG_FILE" 2>&1 || msg_error "Pip-Aktualisierung fehlgeschlagen."

    # Installiere erforderliche Python-Pakete
    msg_info "Installiere erforderliche Python-Pakete..."
    pip install -q -r requirements.txt >> "$LOG_FILE" 2>&1 || msg_error "Installation der Python-Pakete fehlgeschlagen."

    # Installiere Playwright-Chromium
    msg_info "Installiere Playwright-Chromium..."
    python -m playwright install chromium >> "$LOG_FILE" 2>&1 || msg_error "Playwright-Chromium-Installation fehlgeschlagen."

    msg_ok "Python-Umgebung erfolgreich eingerichtet."
}

# --------------------------------------------------------------------------------
# Systemdienst erstellen
# --------------------------------------------------------------------------------

function create_systemd_service() {
    local service_content="[Unit]
Description=eBay-Kleinanzeigen API Service
After=network.target

[Service]
User=$USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/.venv/bin/python -m uvicorn main:app --host 0.0.0.0 --port $DEFAULT_PORT
Restart=always

[Install]
WantedBy=multi-user.target"

    echo "$service_content" | sudo tee "$SERVICE_PATH" > /dev/null || msg_error "Erstellung der Systemd-Service-Datei fehlgeschlagen."

    sudo systemctl daemon-reload || msg_error "Daemon-Reload fehlgeschlagen."
    sudo systemctl enable ebay-kleinanzeigen-api.service || msg_error "Service konnte nicht aktiviert werden."
    sudo systemctl restart ebay-kleinanzeigen-api.service || msg_error "Service konnte nicht gestartet werden."

    msg_ok "Systemdienst erfolgreich erstellt und gestartet."
}

# --------------------------------------------------------------------------------
# Hauptausführung
# --------------------------------------------------------------------------------

msg_info "Willkommen bei der Einrichtung der eBay-Kleinanzeigen-API"

echo -e "${GN}Dieses Skript führt Sie durch die Installation der eBay-Kleinanzeigen-API.${CL}"
echo -e "${GN}Es werden automatisch folgende Schritte ausgeführt:${CL}"
echo -e "  ${YW}• Überprüfung und Installierung der benötigten Systemabhängigkeiten${CL}"
echo -e "  ${YW}• Installieren einer spezifischen Python-Version (mind. 3.12.0) mit pyenv${CL}"
echo -e "  ${YW}• Einrichtung der Python-Umgebung und Installation der Pakete${CL}"
echo -e "  ${YW}• Einrichtung des API-Projekts mit Repository und Konfiguration${CL}"
echo -e "  ${YW}• Konfiguration eines Systemdienstes für die automatische API-Ausführung${CL}"

read -n 1 -s -r -p "${CY}Drücken Sie eine beliebige Taste, um fortzufahren...${CL}"
echo -e "\n"

# Python-Version auswählen
msg_info "Bitte geben Sie die Python-Version ein (mindestens 3.12.0):"
read -p "${YW}Python-Version: ${CL}" PYTHON_VERSION
validate_version "$PYTHON_VERSION" || exit 1

# Port auswählen
msg_info "Bitte geben Sie den Port für die API ein (Standard: 8000):"
read -p "${YW}Port: ${CL}" user_port
if [[ -z "$user_port" ]]; then
    user_port=8000
fi
DEFAULT_PORT=$user_port
check_port_available

# Installationsschritte
install_prerequisites                # Installiere grundlegende Tools
install_dependencies                 # Installiere Systemabhängigkeiten
install_pyenv                        # Installiere pyenv
if ! check_python_version; then
    install_python_with_pyenv        # Installiere Python mit pyenv
fi
setup_project                        # Klone oder aktualisiere das Repository
setup_python_environment             # Richte Python-Umgebung ein
create_systemd_service               # Erstelle den Systemdienst

msg_ok "eBay-Kleinanzeigen API wurde erfolgreich installiert!"

# Abschlussinformationen
echo -e "\033[1;34m══════════════════════════════════════════════════════════════════════════════"
echo -e "${GN}API-Zugriffspunkte:${CL}"
echo -e "  ${YW}• Dokumentation (Swagger):${CL} ${CY}http://$IP:$DEFAULT_PORT/docs${CL}"
echo -e "  ${YW}• Interaktive Dokumentation (Redoc):${CL} ${CY}http://$IP:$DEFAULT_PORT/redoc${CL}"

echo -e "\033[1;34m══════════════════════════════════════════════════════════════════════════════"
echo -e "${GN}Serviceverwaltung:${CL}"
echo -e "  ${YW}• Starten:${CL} ${CY}sudo systemctl start ebay-kleinanzeigen-api.service${CL}"
echo -e "  ${YW}• Stoppen:${CL} ${CY}sudo systemctl stop ebay-kleinanzeigen-api.service${CL}"
echo -e "  ${YW}• Neustarten:${CL} ${CY}sudo systemctl restart ebay-kleinanzeigen-api.service${CL}"
echo -e "  ${YW}• Status prüfen:${CL} ${CY}sudo systemctl status ebay-kleinanzeigen-api.service${CL}"

echo -e "\033[1;34m══════════════════════════════════════════════════════════════════════════════"
echo -e "${GN}Protokolle und Logs:${CL}"
echo -e "  ${YW}• Installationsprotokoll:${CL} ${CY}$LOG_FILE${CL}" 
echo -e "  ${YW}• Dienstprotokoll:${CL} ${CY}journalctl -u ebay-kleinanzeigen-api.service${CL}"

echo -e "\033[1;34m══════════════════════════════════════════════════════════════════════════════"
echo -e "${GN}Hinweise:${CL}"
echo -e "  ${YW}• Der API-Dienst läuft auf Port ${CY}$DEFAULT_PORT${CL}."
echo -e "  ${YW}• Wenn Sie Probleme haben, überprüfen Sie die Log-Dateien.${CL}"

msg_ok "Die Installation wurde am $(date) abgeschlossen."

# --------------------------------------------------------------------------------
# Bereinigungsblock: Fragt nach optionaler Bereinigung
# --------------------------------------------------------------------------------

if confirm_step "Möchten Sie temporäre Build-Dateien löschen?"; then
    msg_info "Bereinige Build-Verzeichnis"
    sudo rm -rf "$BUILD_DIR"
    find "$INSTALL_DIR" -type d -name "__pycache__" -exec rm -rf {} +
    msg_ok "Bereinigung abgeschlossen."
fi

if confirm_step "Möchten Sie altes Paket-Cache löschen?"; then
    msg_info "Bereinige Paket-Cache!"
    sudo apt-get autoremove -yq >> "$LOG_FILE" 2>&1
    sudo apt-get clean -yq >> "$LOG_FILE" 2>&1
    msg_ok "Paket-Cache erfolgreich bereinigt."
fi

# Stelle sicher, dass die Terminalfarben zurückgesetzt werden
echo -e "${CL}"
