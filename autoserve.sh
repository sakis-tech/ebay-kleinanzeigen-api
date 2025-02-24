#!/usr/bin/env bash

# --------------------------------------------------------------------------------
# Initialisierung und Header
# --------------------------------------------------------------------------------

clear

# Creator (autoserve.sh): sakis-tech | Main developer (ebay-kleinanzeigen-api): DanielWTE
# License: MIT | https://github.com/sakis-tech/ebay-kleinanzeigen-api/raw/main/LICENSE

function header_info {
    echo -e "\033[1;36m    ___         __      _____"
    echo -e "   /   | __  __/ /_____/ ___/___  ______   \033[1;34m____"
    echo -e "  / /| |/ / / / __/ __ \\\\__ \/ _ \/ ___/ |\033[1;36m / /_ \\"
    echo -e " / ___ / /_/ / /_/ /_/ /__/   __/  /  | |\033[1;34m/ / __/"
    echo -e "/_/  |_\\\\__,_/\\\\__/\\\\____/____/\\\\___/_/   |___\033[1;36m/\\\\___/"
    echo -e "\033[1;34m═══════════════════════════════════════════════════"
    echo -e "\033[1;36m    Automatisierte Server-Einrichtung           "
    echo -e "\033[1;34m═══════════════════════════════════════════════════"
    echo -e "\033[1;36m   Kleinanzeigen API | Modern Python Implementation\033[0m${CL}"
    echo
}

# Farbdefinitionen für bessere Lesbarkeit
YW=$(tput setaf 3)  # Gelb
GN=$(tput setaf 2)  # Grün
RD=$(tput setaf 1)  # Rot
BL=$(tput setaf 4)  # Blau
CY=$(tput setaf 6)  # Cyan
CL=$(tput sgr0)     # Reset

# Konfiguration der Variablen
APP="Kleinanzeigen-API"
INSTALL_DIR="/opt/kleinanzeigen-api"          # Installationsverzeichnis
SERVICE_PATH="/etc/systemd/system/kleinanzeigen-api.service"  # Pfad zur Systemd-Service-Datei
BUILD_DIR="/usr/src/python_build"            # Build-Verzeichnis für Python-Kompilierung
IP=$(hostname -I | awk '{print $1}')         # IP-Adresse des Servers
DEFAULT_PORT=8000                            # Standardport für die API
LOG_FILE="/tmp/python_build.log"             # Log-Datei für Installationsschritte
PYTHON_VERSION=""                            # Python-Version (wird später vom Benutzer eingegeben)

# --------------------------------------------------------------------------------
# Funktionen
# --------------------------------------------------------------------------------

# Informationsnachricht
function msg_info() {
    echo -e "${YW}═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${YW}💡 ${1}${CL}"
    echo -e "${YW}═══════════════════════════════════════════════════════════════════════════════"
}

# Erfolgsnachricht
function msg_ok() {
    echo -e "${GN}═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${GN}✅ ${1}${CL}"
    echo -e "${GN}═══════════════════════════════════════════════════════════════════════════════"
}

# Fehlermeldung
function msg_error() {
    echo -e "${RD}═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${RD} Cena ${1}${CL}"
    echo -e "${RD}═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${CL}"  # Terminalfarbe zurücksetzen
    exit 1
}

# Bestätigungsabfrage
function confirm_step() {
    echo -e "${YW}═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${YW}💡 ${1}${CL}"
    echo -e "${YW}═══════════════════════════════════════════════════════════════════════════════"
    read -p "${YW}Antwort (y/N): ${CL}" -n 1 -r
    echo -e "\n"
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Funktion zur Installation von Voraussetzungen
function install_prerequisites() {
    msg_info "Installiere erforderliche Tools"
    local tools=("net-tools" "curl" "build-essential" "git")
    for tool in "${tools[@]}"; do
        if ! command -v $(echo "$tool" | cut -d '-' -f1) &>/dev/null; then
            msg_info "Installiere $tool..."
            sudo apt update >> "$LOG_FILE" 2>&1 || \
                msg_error "Aktualisierung der Paketquellen fehlgeschlagen."
            sudo apt install -y "$tool" >> "$LOG_FILE" 2>&1 || \
                msg_error "Installation von $tool fehlgeschlagen."
        else
            msg_ok "$tool ist bereits installiert."
        fi
    done
}

# Prüfen, ob der Port verfügbar ist
function check_port_available() {
    local port=$1
    while netstat -tuln | awk -v p="$port" '$4 ~ ":"p"$" { exit 0 } END { exit 1 }'; do
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
    msg_ok "Port ${GN}$port${CL} ist verfügbar."
    echo "$port"
}

# Python-Version validieren
function validate_version() {
    local version=$1
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

# Python kompilieren
function compile_python() {
    local version=$PYTHON_VERSION
    msg_info "Kompiliere Python ${version} - Dies kann mehrere Minuten dauern."
    sudo mkdir -p "$BUILD_DIR" || msg_error "Erstellung von $BUILD_DIR fehlgeschlagen."
    sudo chmod 777 "$BUILD_DIR" || msg_error "Berechtigungen für $BUILD_DIR konnten nicht gesetzt werden."
    cd "$BUILD_DIR" || msg_error "Wechsel zu $BUILD_DIR fehlgeschlagen."
    if ! wget -q "https://www.python.org/ftp/python/${version}/Python-${version}.tgz"; then
        msg_error "Download der Python-Version ${version} fehlgeschlagen."
    fi
    tar xzf "Python-${version}.tgz" || msg_error "Entpacken fehlgeschlagen."
    cd "Python-${version}" || msg_error "Wechsel zu Python-${version}-Verzeichnis fehlgeschlagen."
    ./configure \
        --enable-optimizations \
        --with-lto \
        --enable-loadable-sqlite-extensions \
        CFLAGS="-fPIC -Wno-error=deprecated-declarations" >> "$LOG_FILE" 2>&1 || \
        msg_error "Konfiguration fehlgeschlagen."
    local cores=$(nproc)
    msg_info "Kompilierung gestartet mit ${cores} Kernen - Bitte haben Sie Geduld."
    make -j$((cores > 2 ? cores-1 : 1)) >> "$LOG_FILE" 2>&1 || \
        msg_error "Kompilierung fehlgeschlagen - Details in $LOG_FILE."
    sudo make altinstall >> "$LOG_FILE" 2>&1 || \
        msg_error "Installation fehlgeschlagen."
    sudo update-alternatives --install /usr/local/bin/python3 python3 "/usr/local/bin/python${version%.*}" 10 || \
        msg_error "Update-Alternatives-Konfiguration fehlgeschlagen."
    sudo update-alternatives --set python3 "/usr/local/bin/python${version%.*}" || \
        msg_error "Setzen der Python-Version fehlgeschlagen."
    msg_ok "Python ${version} erfolgreich installiert."
}

# Funktion zur Aktualisierung von pip
function upgrade_pip() {
    msg_info "Aktualisiere pip auf die neueste Version..."
    python3 -m pip install --upgrade pip >> "$LOG_FILE" 2>&1 || \
        msg_error "Pip-Aktualisierung fehlgeschlagen."
    msg_ok "Pip wurde erfolgreich aktualisiert."
}

# Projekt einrichten
function setup_project() {
    msg_info "Richte Projekt ein"
    sudo mkdir -p "$INSTALL_DIR" || msg_error "Erstellung von $INSTALL_DIR fehlgeschlagen."
    sudo chown -R $USER:$USER "$INSTALL_DIR" || msg_error "Berechtigungen für $INSTALL_DIR konnten nicht gesetzt werden."
    git clone -q https://github.com/sakis-tech/ebay-kleinanzeigen-api.git "$INSTALL_DIR" || \
        msg_error "Klonen des Repositoriums fehlgeschlagen."
    cd "$INSTALL_DIR" || msg_error "Wechsel zu $INSTALL_DIR fehlgeschlagen."
    python3 -m venv .venv || msg_error "Erstellung der virtuellen Umgebung fehlgeschlagen."
    source .venv/bin/activate || msg_error "Aktivierung der virtuellen Umgebung fehlgeschlagen."
    upgrade_pip
    pip install -q -r requirements.txt || msg_error "Installation der Python-Pakete fehlgeschlagen."
    msg_info "Installiere Chromium"
    python -m playwright install chromium >> "$LOG_FILE" 2>&1 || \
        msg_error "Playwright-Chromium-Installation fehlgeschlagen."
}

# Systemabhängigkeiten installieren
function install_dependencies() {
    msg_info "Installiere Systemabhängigkeiten."

    local deps=(
        # Basis-Entwicklungspakete
        build-essential

        # Für Python-Build
        zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev
        libssl-dev libreadline-dev libffi-dev libbz2-dev libsqlite3-dev
        liblzma-dev tk-dev uuid-dev libexpat1-dev libgpm2 libxml2-dev
        libxmlsec1-dev mlocate python3-packaging python3-venv

        # Zusätzliche Pakete für Python-Module
        libdb5.3-dev libdb-dev libgmp-dev libmpdec-dev libmpfr-dev
        libbluetooth-dev libbz2-dev libcurl4-openssl-dev libffi-dev
        liblzma-dev libncurses5-dev libncursesw5-dev libreadline-dev
        libsqlite3-dev libssl-dev libxml2-dev libxslt1-dev

        # Für Playwright/Chromium
        libx11-xcb1 libdrm2 libgbm1 libasound2 libxcomposite1
        libxrandr2 libxkbcommon0

        # Optional: Debugging-Tools
        gdb valgrind strace
    )

    if ! { sudo apt update >> "$LOG_FILE" 2>&1 && sudo apt install -y "${deps[@]}" >> "$LOG_FILE" 2>&1; }; then
        msg_error "Paketinstallation fehlgeschlagen - siehe $LOG_FILE"
    fi

    msg_ok "Systemabhängigkeiten installiert."
}

# Systemdienst erstellen
function create_systemd_service() {
    local service_content="[Unit]
Description=Kleinanzeigen API Service
After=network.target

[Service]
User=$USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/.venv/bin/python -m uvicorn main:app --host 0.0.0.0 --port $DEFAULT_PORT
Restart=always

[Install]
WantedBy=multi-user.target"

    msg_info "Erstelle Systemd-Service-Datei..."
    echo "$service_content" | sudo tee "$SERVICE_PATH" > /dev/null || \
        msg_error "Erstellung der Systemd-Service-Datei fehlgeschlagen."
    sudo systemctl daemon-reload > /dev/null 2>&1 || \
        msg_error "Daemon-Reload fehlgeschlagen."
    sudo systemctl enable kleinanzeigen-api.service > /dev/null 2>&1 || \
        msg_error "Service konnte nicht aktiviert werden."
    sudo systemctl start kleinanzeigen-api.service > /dev/null 2>&1 || \
        msg_error "Service konnte nicht gestartet werden."
    msg_ok "Systemdienst erfolgreich erstellt und gestartet."
}

# API-Status prüfen
function check_api_health() {
    local url="http://$IP:$DEFAULT_PORT/docs"
    if command -v curl &>/dev/null; then
        if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200"; then
            msg_ok "API ist erreichbar unter ${GN}$url${CL}"
        else
            msg_error "API ist nicht erreichbar. Bitte überprüfen Sie den Dienst."
        fi
    elif command -v wget &>/dev/null; then
        if wget --spider -q "$url"; then
            msg_ok "API ist erreichbar unter ${GN}$url${CL}"
        else
            msg_error "API ist nicht erreichbar. Bitte überprüfen Sie den Dienst."
        fi
    else
        msg_error "Weder curl noch wget sind installiert. Installieren Sie eines davon, um die API-Statusüberprüfung durchzuführen."
    fi
}

# --------------------------------------------------------------------------------
# Hauptausführung
# --------------------------------------------------------------------------------
header_info
# Willkommensnachricht und Bestätigung
msg_info "Willkommen bei der Einrichtung der Kleinanzeigen-API"
echo -e "${GN}Dieses Skript führt Sie durch die Installation der Kleinanzeigen-API.${CL}"
echo -e "${GN}Es werden automatisch alle erforderlichen Pakete installiert.${CL}"
read -n 1 -s -r -p "${YW}Drücken Sie eine beliebige Taste, um fortzufahren...${CL}"
echo -e "\n"

# Installation von Voraussetzungen
if confirm_step "Möchten Sie erforderliche Tools (net-tools, curl, build-essential, git) installieren?"; then
    install_prerequisites
else
    msg_error "Die Installation wurde abgebrochen, da erforderliche Tools nicht installiert wurden."
fi

# Port-Auswahl und -Prüfung
read -p "${YW}Wählen Sie einen Port für die API (Standard: $DEFAULT_PORT): ${CL}" chosen_port
chosen_port=${chosen_port:-$DEFAULT_PORT}
DEFAULT_PORT=$(check_port_available "$chosen_port")

# Installationsprotokoll
msg_info "Installationsprotokoll wird geschrieben nach: ${GN}$LOG_FILE${CL}"

# Python-Version Eingabe
while true; do
    read -p "${YW}Gewünschte Python-Version eintragen und bestätigen (mind. 3.12.0): ${CL}" PYTHON_VERSION
    if validate_version "$PYTHON_VERSION"; then
        break
    fi
done

# Startbestätigung
if ! confirm_step "Möchten Sie mit der Installation beginnen?"; then
    msg_error "Installation abgebrochen."
    exit 0
fi

# Prüfe, ob Python bereits installiert ist
if command -v "python${PYTHON_VERSION%.*}" &>/dev/null; then
    msg_ok "Python ${PYTHON_VERSION} ist bereits installiert."
else
    compile_python
fi

# Installationsschritte
install_dependencies
setup_project
create_systemd_service

# API-Status prüfen
msg_info "Überprüfe API-Status..."
check_api_health

# Nach der Installation
msg_ok "ebay-kleinanzeigen API wurde erfolgreich installiert!"
echo -e "\033[1;34m══════════════════════════════════════════════════════════════════════════════"
echo -e "${GN}API-Zugriffspunkte:${CL}"
echo -e "  ${YW}• Dokumentation (Swagger):${CL} ${CY}http://$IP:$DEFAULT_PORT/docs${CL}"
echo -e "  ${YW}• Interaktive Dokumentation (Redoc):${CL} ${CY}http://$IP:$DEFAULT_PORT/redoc${CL}"

echo -e "\033[1;34m══════════════════════════════════════════════════════════════════════════════"
echo -e "${GN}Serviceverwaltung:${CL}"
echo -e "  ${YW}• Starten:${CL} ${CY}sudo systemctl start kleinanzeigen-api.service${CL}"
echo -e "  ${YW}• Stoppen:${CL} ${CY}sudo systemctl stop kleinanzeigen-api.service${CL}"
echo -e "  ${YW}• Neustarten:${CL} ${CY}sudo systemctl restart kleinanzeigen-api.service${CL}"
echo -e "  ${YW}• Status prüfen:${CL} ${CY}sudo systemctl status kleinanzeigen-api.service${CL}"

echo -e "\033[1;34m══════════════════════════════════════════════════════════════════════════════"
echo -e "${GN}Protokolle und Logs:${CL}"
echo -e "  ${YW}• Installationsprotokoll:${CL} ${CY}$LOG_FILE${CL}"
echo -e "  ${YW}• Dienstprotokoll:${CL} ${CY}journalctl -u kleinanzeigen-api.service${CL}"

echo -e "\033[1;34m══════════════════════════════════════════════════════════════════════════════"
echo -e "${GN}Hinweise:${CL}"
echo -e "  ${YW}• Der API-Dienst läuft auf Port ${CY}$DEFAULT_PORT${CL}."
echo -e "  ${YW}• Wenn Sie Probleme haben, überprüfen Sie die Log-Dateien.${CL}"

msg_ok "Die Installation wurde am $(date) abgeschlossen."

# Bereinigung
if confirm_step "Möchten Sie temporäre Build-Dateien löschen?"; then
    msg_info "Bereinige Build-Verzeichnis"
    sudo rm -rf "$BUILD_DIR"
    find "$INSTALL_DIR" -type d -name "__pycache__" -exec rm -rf {} +
    msg_ok "Bereinigung abgeschlossen."
fi

if confirm_step "Möchten Sie altes Paket-Cache löschen?"; then
    msg_info "Bereinige Paket-Cache!"
    sudo apt autoremove -yq >> "$LOG_FILE" 2>&1
    sudo apt clean -yq >> "$LOG_FILE" 2>&1
    msg_ok "Paket-Cache erfolgreich bereinigt."
fi

# Reset Terminalfarben
echo -e "${CL}"
