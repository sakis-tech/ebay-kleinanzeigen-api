#!/usr/bin/env bash
clear
# Copyright (c) 2025 AutoServe - Automatisierte Server-Einrichtung
# License: MIT | https://github.com/sakis-tech/ebay-kleinanzeigen-api/raw/main/LICENSE

function header_info {
    echo -e "\033[1;36m    ___         __       _____"
    echo -e "   /   | __  __/ /_____ / ___/___  ______   \033[1;34m_____"
    echo -e "  / /| |/ / / / __/ __ \\\\__ \/ _ \/ ___/ |\033[1;36m/ / _ \\\\"
    echo -e " / ___ / /_/ / /_/ /_/ /__/ /  __/ /   | |\033[1;34m/ /  __/"
    echo -e "/_/  |_\\\\__,_/\\\\__/\\\\____/____/\\\\___/_/    |___\033[1;36m/\\\\___/"
    echo -e "\033[1;34m═══════════════════════════════════════════════════"
    echo -e "\033[1;36m    Automatisierte Server-Einrichtung           "
    echo -e "\033[1;34m═══════════════════════════════════════════════════"
    echo -e "\033[1;36m   Kleinanzeigen API | Modern Python Implementation\033[0m"
    echo
}

# Farbdefinitionen
YW=$(tput setaf 3)  # Gelb
GN=$(tput setaf 2)  # Grün
RD=$(tput setaf 1)  # Rot
BL=$(tput setaf 4)  # Blau
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
    echo -e "${YW}💡 ${1}...${CL}"
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
    echo -e "${RD}═══════════════════════════════════════════════════════════════════════════════${CL}"
    exit 1
}

function confirm_step() {
    echo -e "${YW}═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${YW}💡 ${1}${CL}"
    echo -e "${YW}═══════════════════════════════════════════════════════════════════════════════"
    read -p "${YW}Antwort (y/N): ${CL}" -n 1 -r
    echo  
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

# Playwright auswahl
function select_playwright_browsers() {
    echo -e "\n${YW}Verfügbare Browser für Playwright:${CL}"
    local options=("chromium" "firefox" "webkit" "alle")
    local selected=()
    
    PS3="${YW}Wählen Sie Browser (Mehrfachauswahl mit Komma getrennt): ${CL}"
    select opt in "${options[@]}"; do
        case $opt in
            "chromium") selected+=("chromium");;
            "firefox") selected+=("firefox");;
            "webkit") selected+=("webkit");;
            "alle") selected=("chromium" "firefox" "webkit"); break;;
            *) msg_error "Ungültige Option";;
        esac
        [[ $REPLY == 4 ]] && break
    done
    
    if [ ${#selected[@]} -eq 0 ]; then
        msg_info "Standardmäßig wird Chromium installiert"
        selected=("chromium")
    fi
    
    echo -n "${GN}Ausgewählte Browser: "
    printf "%s " "${selected[@]}"
    echo -e "${CL}"
    PLAYWRIGHT_BROWSERS=("${selected[@]}")
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

    # Browserauswahl
    select_playwright_browsers
    python -m playwright install "${PLAYWRIGHT_BROWSERS[@]}" >> "$LOG_FILE" 2>&1 || \
        msg_error "Playwright-Installation fehlgeschlagen"
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

function setup_swap() {
    local mem_total=$(free -m | awk '/Mem:/ {print $2}')
    if [ -z "$mem_total" ]; then
        msg_info "Speichererkennung fehlgeschlagen, überspringe Swap-Erstellung${CL}"
        return
    fi
    
    if [ "$mem_total" -lt 2048 ]; then
        msg_info "Erstelle 2GB Swap-Space für stabilen Build"
        sudo fallocate -l 2G /swapfile >> "$LOG_FILE" 2>&1
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile >> "$LOG_FILE" 2>&1
        sudo swapon /swapfile
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >> "$LOG_FILE" 2>&1
        msg_ok "Swap-Space erfolgreich eingerichtet"
    fi
}

function compile_python() {
    local version=$PYTHON_VERSION
    msg_info "Kompiliere Python ${version} - Dies kann mehrere Minuten dauern... "
    
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
    msg_info "Kompilierung gestartet mit ${cores} Kernen - Bitte haben Sie Geduld...${CL}"
    make -j$((cores > 2 ? cores-1 : 1)) >> "$LOG_FILE" 2>&1 || \
        msg_error "Kompilierung fehlgeschlagen - Details in $LOG_FILE"

    sudo make altinstall >> "$LOG_FILE" 2>&1 || \
        msg_error "Installation fehlgeschlagen"

    sudo update-alternatives --install /usr/local/bin/python3 python3 \
        "/usr/local/bin/python${version%.*}" 10
    sudo update-alternatives --set python3 "/usr/local/bin/python${version%.*}"

    msg_ok "Python ${version} erfolgreich installiert"
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
    msg_error "Installation abgebrochen${CL}"
    exit 0
fi

# Installationsschritte
setup_swap
install_dependencies
compile_python
setup_project
create_service

echo -e "\n${GN}╔════════════════════════════════════════════╗"
echo -e "║            ${BL}INSTALLATION ERFOLGREICH${GN}           ║"
echo -e "╠════════════════════════════════════════════╣"
echo -e "║ ${YW}API Dokumentation: ${BL}http://$IP:$port/docs${CL}     ║"
echo -e "║ ${YW}Swagger UI:        ${BL}http://$IP:$port/redoc${CL}     ║"
echo -e "╚════════════════════════════════════════════╝${CL}"


# Bereinigung
if confirm_step "Möchten Sie temporäre Build-Dateien löschen"; then
    msg_info "Bereinige Build-Verzeichnis"
    sudo rm -rf "$BUILD_DIR"
    msg_ok "Bereinigung abgeschlossen"
fi

echo -e "\n${GN}Installation abgeschlossen um $(date)${CL}"
