#!/usr/bin/env bash
clear

# Copyright (c) 2025 AutoServe - Automatisierte Server-Einrichtung
# License: MIT | https://github.com/sakis-tech/ebay-kleinanzeigen-api/raw/main/LICENSE

function header_info {
    echo -e "\033[1;36m    ___         __      _____"
    echo -e "   /   | __  __/ /_____/ ___/___  ______   \033[1;34m____"
    echo -e "  / /| |/ / / / __/ __ \\\\__ \/ _ \/ ___/ |\033[1;36m / /_ \\\\"
    echo -e " / ___ / /_/ / /_/ /_/ /__/   __/  /  | |\033[1;34m/ / __/"
    echo -e "/_/  |_\\\\__,_/\\\\__/\\\\____/____/\\\\___/_/   |___\033[1;36m/\\\\___/"
    echo -e "\033[1;34m═══════════════════════════════════════════════════"
    echo -e "\033[1;36m    Automatisierte Server-Einrichtung           "
    echo -e "\033[1;34m═══════════════════════════════════════════════════"
    echo -e "\033[1;36m   Kleinanzeigen API | Modern Python Implementation\033[0m${CL}"
    echo
}

# Farbdefinitionen
YW=$(tput setaf 3)  # Gelb
GN=$(tput setaf 2)  # Grün
RD=$(tput setaf 1)  # Rot
BL=$(tput setaf 4)  # Blau
CY=$(tput setaf 6)  # Cyan
CL=$(tput sgr0)     # Reset

# Konfiguration
APP="Kleinanzeigen-API"
INSTALL_DIR="/opt/kleinanzeigen-api"
SERVICE_PATH="/etc/systemd/system/kleinanzeigen-api.service"
BUILD_DIR="/usr/src/python_build"
IP=$(hostname -I | awk '{print $1}')
DEFAULT_PORT=8000
LOG_FILE="/tmp/python_build.log"
PYTHON_VERSION=""

header_info

# Willkommensnachricht und Bestätigung
echo -e "\n${GN}Willkommen bei der Einrichtung der Kleinanzeigen-API.${CL}"
echo -e "${GN}Dieses Skript überprüft Ihre Python-Version und installiert bei Bedarf Python 3.12 oder höher.${CL}"
echo -e "${GN}Es werden automatisch alle erforderlichen Pakete installiert.${CL}"

read -n 1 -s -r -p "${YW}Drücken Sie eine beliebige Taste, um fortzufahren...${CL}"
echo -e "\n"

# Funktionen
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
    exit 1
}

function confirm_step() {
    echo -e "${YW}═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${YW}💡 ${1}${CL}"
    echo -e "${YW}═══════════════════════════════════════════════════════════════════════════════"
    read -p "${YW}Antwort (y/N): ${CL}" -n 1 -r
    echo -e "\n"  
    [[ $REPLY =~ ^[Yy]$ ]]
}

function validate_version() {
    local version=$1
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        msg_error "Ungültiges Format. Bitte im Format X.Y.Z eingeben (z.B. 3.12.3)"
        return 1
    fi
    
    IFS='.' read -r -a parts <<< "$version"
    if [[ ${parts[0]} -ne 3 ]] || [[ ${parts[1]} -lt 12 ]]; then
        msg_error "Mindestanforderung: Python 3.12.0 oder höher!"
        return 1
    fi
    
    return 0
}

function setup_project() {
    msg_info "Richte Projekt ein"
    
    sudo mkdir -p "$INSTALL_DIR"
    sudo chown -R $USER:$USER "$INSTALL_DIR"
    
    git clone -q https://github.com/sakis-tech/ebay-kleinanzeigen-api.git "$INSTALL_DIR" || \
        msg_error "Klonen fehlgeschlagen"
    
    cd "$INSTALL_DIR" || msg_error "Verzeichniswechsel fehlgeschlagen"

    # Browser-Abhängigkeiten
    sudo apt install -y \
        libx11-xcb1 libdrm2 libgbm1 libasound2 libxcomposite1 \
        libxrandr2 libxkbcommon0 >> "$LOG_FILE" 2>&1

    # Virtuelle Umgebung
    python3 -m venv .venv || msg_error "Virtuelle Umgebung fehlgeschlagen"
    source .venv/bin/activate

    # Pakete installieren
    pip install -q -r requirements.txt || msg_error "Paketinstallation fehlgeschlagen"

    # Installiere nur Chromium
    msg_info "Installiere Chromium"
    python -m playwright install chromium >> "$LOG_FILE" 2>&1 || \
        msg_error "Playwright-Installation fehlgeschlagen"
}

function install_dependencies() {
    msg_info "Installiere Systemabhängigkeiten"
    
    local deps=(
        build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev
        libssl-dev libreadline-dev libffi-dev libbz2-dev libsqlite3-dev
        liblzma-dev tk-dev libdb5.3-dev uuid-dev libgpm2 libxml2-dev 
        libxmlsec1-dev mlocate libreadline-dev libffi-dev liblzma-dev lzma
        python3-packaging python3-venv
    )

    if ! sudo apt update >> "$LOG_FILE" 2>&1 || \
       ! sudo apt install -y "${deps[@]}" >> "$LOG_FILE" 2>&1; then
        msg_error "Paketinstallation fehlgeschlagen - siehe $LOG_FILE"
    fi
    msg_ok "Systemabhängigkeiten installiert"
}

function compile_python() {
    local version=$PYTHON_VERSION
    msg_info "Kompiliere Python ${version} - Dies kann mehrere Minuten dauern"
    
    sudo mkdir -p "$BUILD_DIR"
    sudo chmod 777 "$BUILD_DIR"
    cd "$BUILD_DIR" || msg_error "Verzeichniswechsel fehlgeschlagen"

    if ! wget -q "https://www.python.org/ftp/python/${version}/Python-${version}.tgz"; then
        msg_error "Download der Python-Version ${version} fehlgeschlagen"
    fi

    tar xzf "Python-${version}.tgz" || msg_error "Entpacken fehlgeschlagen"
    cd "Python-${version}" || msg_error "Verzeichniswechsel fehlgeschlagen"

    ./configure \
        --enable-optimizations \
        --with-lto \
        --with-system-expat \
        --with-system-ffi \
        --enable-loadable-sqlite-extensions \
        CFLAGS="-fPIC -Wno-error=deprecated-declarations" >> "$LOG_FILE" 2>&1 || \
        msg_error "Konfiguration fehlgeschlagen"

    local cores=$(nproc)
    msg_info "Kompilierung gestartet mit ${cores} Kernen - Bitte haben Sie Geduld"
    make -j$((cores > 2 ? cores-1 : 1)) >> "$LOG_FILE" 2>&1 || \
        msg_error "Kompilierung fehlgeschlagen - Details in $LOG_FILE"

    sudo make altinstall >> "$LOG_FILE" 2>&1 || \
        msg_error "Installation fehlgeschlagen"

    sudo update-alternatives --install /usr/local/bin/python3 python3 \
        "/usr/local/bin/python${version%.*}" 10
    sudo update-alternatives --set python3 "/usr/local/bin/python${version%.*}"

    msg_ok "Python ${version} erfolgreich installiert"
}

# Hauptausführung
msg_info "Installationsprotokoll wird geschrieben nach: $LOG_FILE"

# Python-Version Eingabe
while true; do
    read -p "${YW}Gewünschte Python-Version (mind. 3.12.0): ${CL}" PYTHON_VERSION
    if validate_version "$PYTHON_VERSION"; then
        break
    fi
done

if ! confirm_step "Möchten Sie mit der Installation beginnen"; then
    msg_error "Installation abgebrochen"
    exit 0
fi

# Installationsschritte
install_dependencies
compile_python
setup_project

# Nach der Installation
msg_ok "${GN}Installation erfolgreich abgeschlossen!${CL}"
echo -e "\n${YW}Zugangslinks:"
echo -e "  ${GN}• API Dokumentation: ${CY}🌐 http://$IP:$DEFAULT_PORT/docs"
echo -e "  ${GN}• Swagger UI:        ${CY}🌐 http://$IP:$DEFAULT_PORT/redoc"
echo -e "\n${YW}Serviceverwaltung:"
echo -e "  ${GN}sudo systemctl [start|stop|restart] kleinanzeigen-api.service${CL}\n"

# Bereinigung
if confirm_step "Möchten Sie temporäre Build-Dateien löschen"; then
    msg_info "Bereinige Build-Verzeichnis"
    sudo rm -rf "$BUILD_DIR"
    sudo apt autoremove -yq >> "$LOG_FILE" 2>&1
    sudo apt clean -yq >> "$LOG_FILE" 2>&1
    find "$INSTALL_DIR" -type d -name "__pycache__" -exec rm -rf {} +
    msg_ok "Bereinigung abgeschlossen"
fi

msg_info "Installation abgeschlossen am $(date)"
