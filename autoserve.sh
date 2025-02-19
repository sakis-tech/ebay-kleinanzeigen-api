#!/usr/bin/env bash
clear

# Copyright (c) 2025 AutoServe - Automatisierte Server-Einrichtung
# Creator (autoserve.sh): sakis-tech | Main developer (ebay-kleinanzeigen-api) : DanielWTE 
# License: MIT | https://github.com/sakis-tech/ebay-kleinanzeigen-api/raw/main/LICENSE

function header_info {
    cat <<"EOF"
    ___         __       _____
   /   | __  __/ /_____ / ___/___  ______   _____
  / /| |/ / / / __/ __ \\__ \/ _ \/ ___/ | / / _ \
 / ___ / /_/ / /_/ /_/ /__/ /  __/ /   | |/ /  __/
/_/  |_\__,_/\__/\____/____/\___/_/    |___/\___/
═══════════════════════════════════════════════════
                  Automatisierte Server-Einrichtung

   Kleinanzeigen API | Modern Python Implementation
EOF
}

# Farbdefinitionen
YW=$(tput setaf 3)  # Gelb
GN=$(tput setaf 2)  # Grün
RD=$(tput setaf 1)  # Rot
BL=$(tput setaf 4)  # Blau
CL=$(tput sgr0)     # Reset

# Konfiguration
APP="Kleinanzeigen-API"
INSTALL_DIR="/opt/community-scripts/kleinanzeigen-api"
SERVICE_PATH="/etc/systemd/system/kleinanzeigen-api.service"
PYTHON_BIN_DIR="/usr/local/bin"
IP=$(hostname -I | awk '{print $1}')
DEFAULT_PORT=8000

header_info

# Funktionen
function msg_info() { echo -e "${YW}💡 ${YW}${1}...${CL}"; }
function msg_ok() { echo -e "${GN}✅ ${1}${CL}"; }
function msg_error() { echo -e "${RD}❎ ${1}${CL}"; }

function confirm_step() {
    read -p "${YW}${1} (y/N)?${CL} " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

function validate_python_version() {
    if [[ ! $1 =~ ^3\.(1[2-9]|[2-9][0-9])\.[0-9]+$ ]]; then
        msg_error "Ungültige Version! Mindestens Python 3.12 erforderlich"
        return 1
    fi
    return 0
}

function install_system_deps() {
    msg_info "Installiere Systemabhängigkeiten"
    sudo apt update && sudo apt install -y \
        build-essential libssl-dev libbz2-dev \
        libreadline-dev libsqlite3-dev wget \
        curl llvm libffi-dev zlib1g-dev \
        python3-pip git
    msg_ok "Systemabhängigkeiten installiert"
}

function compile_python() {
    local version=$1
    msg_info "Kompiliere Python ${version}"

    cd /usr/src
    sudo rm -rf "Python-${version}"

    sudo wget -q "https://www.python.org/ftp/python/${version}/Python-${version}.tgz" || return 1
    sudo tar xzf "Python-${version}.tgz" || return 1
    cd "Python-${version}"

    sudo ./configure --enable-optimizations >/dev/null || return 1
    sudo make -j $(nproc) altinstall >/dev/null || return 1

    if [ ! -f "${PYTHON_BIN_DIR}/python${version:0:4}" ]; then
        msg_error "Python-Installation fehlgeschlagen"
        return 1
    fi

    msg_ok "Python ${version} installiert"
    return 0
}

function setup_project() {
    if [ -d "$INSTALL_DIR" ]; then
        msg_error "Installationsverzeichnis existiert bereits"
        if confirm_step "Verzeichnis löschen"; then
            sudo rm -rf "$INSTALL_DIR"
        else
            exit 1
        fi
    fi

    msg_info "Richte Projekt ein"
    sudo mkdir -p "$INSTALL_DIR"
    sudo chown -R $USER:$USER "$INSTALL_DIR"
    git clone -q https://github.com/sakis-tech/ebay-kleinanzeigen-api.git "$INSTALL_DIR"
    cd "$INSTALL_DIR" || exit 1
    msg_ok "Projekt eingerichtet"
}

function install_browser_deps() {
    msg_info "Installiere Browser-Abhängigkeiten"
    sudo apt install -y \
        libatk1.0-0 libatk-bridge2.0-0 libcups2 \
        libxcomposite1 libxdamage1 libxfixes3 \
        libxrandr2 libgbm1 libxkbcommon0 \
        libpango-1.0-0 libcairo2 libasound2 \
        libatspi2.0-0
    msg_ok "Browser-Abhängigkeiten installiert"
}

function create_venv() {
    local py_version=$1
    msg_info "Erstelle virtuelle Umgebung"
    "${PYTHON_BIN_DIR}/python${py_version}" -m venv .venv
    source .venv/bin/activate
    msg_ok "Virtuelle Umgebung aktiviert"
}

function install_python_deps() {
    msg_info "Installiere Python-Abhängigkeiten"
    pip install -q -r requirements.txt
    pip install -q playwright
    msg_ok "Abhängigkeiten installiert"
}

function install_chromium() {
    msg_info "Installiere Chromium"
    python -m playwright install chromium
    msg_ok "Chromium installiert"
}

function setup_service() {
    local port=$1
    msg_info "Erstelle Systemd-Service"

    cat <<EOF | sudo tee "$SERVICE_PATH" >/dev/null
[Unit]
Description=Kleinanzeigen API Service
After=network.target

[Service]
User=$USER
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$INSTALL_DIR/.venv/bin:$PATH"
ExecStart=$INSTALL_DIR/.venv/bin/uvicorn main:app --host 0.0.0.0 --port $port
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now kleinanzeigen-api.service
    msg_ok "Service aktiviert"
}

# Hauptinstallation
echo -e "\n"
while true; do
    read -p "${YW}Bitte die gewünschte Python Version eintragen (z.B. 3.12.0): ${CL}" py_version
    validate_python_version "$py_version" && break
done

if confirm_step "Systemabhängigkeiten installieren"; then
    install_system_deps || exit 1
fi

if [ ! -f "${PYTHON_BIN_DIR}/python${py_version:0:4}" ]; then
    if confirm_step "Python ${py_version} kompilieren"; then
        compile_python "$py_version" || exit 1
    else
        exit 1
    fi
fi

setup_project || exit 1
cd "$INSTALL_DIR" || exit 1

if confirm_step "Browser-Abhängigkeiten installieren"; then
    install_browser_deps || exit 1
fi

create_venv "${py_version:0:4}" || exit 1
install_python_deps || exit 1
install_chromium || exit 1

read -p "${YW}Port (Standard: $DEFAULT_PORT): ${CL}" port
port=${port:-$DEFAULT_PORT}

if confirm_step "Systemdienst einrichten"; then
    setup_service "$port" || exit 1
fi

echo -e "\n${GN}╔════════════════════════════════════════════╗"
echo -e "║            ${BL}INSTALLATION ERFOLGREICH${GN}           ║"
echo -e "╠════════════════════════════════════════════╣"
echo -e "║ ${YW}API Dokumentation: ${YW}http://$IP:$port/docs${GN}     ║"
echo -e "║ ${YW}Swagger UI:        ${YW}http://$IP:$port/redoc${GN}     ║"
echo -e "╚════════════════════════════════════════════╝${CL}"

if confirm_step "Temporäre Dateien bereinigen"; then
    sudo rm -rf /usr/src/Python-*
fi
