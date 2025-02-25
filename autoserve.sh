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
    echo -e "\033[1;36m    AutoServe | Kleinanzeigen-API Installer           "
    echo -e "\033[1;34m═══════════════════════════════════════════════════"
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
LOG_FILE="/tmp/kleinanzeigen-api.log"       # Log-Datei für Installationsschritte
PYTHON_VERSION=""                            # Python-Version (wird später vom Benutzer eingegeben)

# --------------------------------------------------------------------------------
# Funktionen
# --------------------------------------------------------------------------------

# Informativnachricht
function msg_info() {
    echo -e "${YW}═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${YW}💡 ${1}${CL}"
    echo -e " ${YW}═══════════════════════════════════════════════════════════════════════════════"
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
    echo -e "${RD}❎ ${1}${CL}"
    echo -e "${RD}═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${CL}"  # Terminalfarbe zurücksetzen
    exit 1
}

# Funktion zur Installation von Voraussetzungen
function install_prerequisites() {
    local tools=("net-tools" "git")
    local tool_names=()

    # Erstelle eine Liste der zu installierenden Tools
    for tool in "${tools[@]}"; do
        if ! command -v $(echo "$tool" | cut -d '-' -f1) &>/dev/null; then
            tool_names+=("$tool")
        fi
    done

    # Zeige den Nutzerinformationen an, welche Tools fehlen
    if [ ${#tool_names[@]} -eq 0 ]; then
        msg_ok "Alle benötigten Tools sind bereits installiert."
        return
    fi

    msg_info "Die folgenden Tools müssen noch installiert werden:"
    for tool in "${tool_names[@]}"; do
        echo -e "${YW}• $tool${CL}"
    done

    # Bestätigungsabfrage
    if ! confirm_step "Möchten Sie diese Tools installieren?"; then
        msg_error "Installation abgebrochen."
    fi

    # Aktualisiere die Paketquellen
    msg_info "Aktualisiere Paketquellen..."
    if ! sudo apt-get update >> "$LOG_FILE" 2>&1; then
        msg_error "Aktualisierung der Paketquellen fehlgeschlagen."
    fi

    # Installiere die fehlenden Tools
    msg_info "Installiere erforderliche Tools..."
    if ! sudo apt-get install -y "${tool_names[@]}" >> "$LOG_FILE" 2>&1; then
        msg_error "Installation der Tools fehlgeschlagen."
    fi

    msg_ok "Erforderliche Tools wurden erfolgreich installiert."
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

# Prüfen, ob der Port verfügbar ist
function check_port_available() {
    local port=$DEFAULT_PORT
    while netstat -tuln | grep -q ":$port "; do
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
    msg_ok "Port $DEFAULT_PORT$ ist verfügbar."
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

    # Stelle sicher, dass das Zielverzeichnis existiert
    sudo mkdir -p "$(dirname "$SERVICE_PATH")" || msg_error "Konnte Zielverzeichnis nicht erstellen."

    # Schreibe den Inhalt der Systemdienst-Datei
    echo "$service_content" | sudo tee "$SERVICE_PATH" > /dev/null || \
        msg_error "Erstellung der Systemd-Service-Datei fehlgeschlagen."

    # Aktualisiere den systemd-Daemon und aktiviere den Dienst
    sudo systemctl daemon-reload || msg_error "Daemon-Reload fehlgeschlagen."
    sudo systemctl enable kleinanzeigen-api.service || msg_error "Service konnte nicht aktiviert werden."
    sudo systemctl restart kleinanzeigen-api.service || msg_error "Service konnte nicht gestartet werden."

    msg_ok "Systemdienst erfolgreich erstellt und gestartet."
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

    # Überprüfe, ob das Installationsverzeichnis bereits existiert
    if [ -d "$INSTALL_DIR" ]; then
        msg_info "Verzeichnis $INSTALL_DIR existiert bereits. Aktualisiere Repository."
        
        # Stelle sicher, dass wir im richtigen Verzeichnis sind
        cd "$INSTALL_DIR" || msg_error "Wechsel zu $INSTALL_DIR fehlgeschlagen."

        # Führe git pull aus, um das Repository zu aktualisieren
        git pull origin main || msg_error "Aktualisierung des Repositoriums fehlgeschlagen."
    else
        msg_info "Klone Repository nach $INSTALL_DIR"
        
        # Erstelle das Installationsverzeichnis
        sudo mkdir -p "$INSTALL_DIR" || msg_error "Erstellung von $INSTALL_DIR fehlgeschlagen."
        sudo chown -R $USER:$USER "$INSTALL_DIR" || msg_error "Berechtigungen für $INSTALL_DIR konnten nicht gesetzt werden."

        # Klonen des Repositories
        git clone -q https://github.com/sakis-tech/ebay-kleinanzeigen-api.git "$INSTALL_DIR" || \
            msg_error "Klonen des Repositoriums fehlgeschlagen."

        cd "$INSTALL_DIR" || msg_error "Wechsel zu $INSTALL_DIR fehlgeschlagen."
    fi

    # Überprüfe, ob die virtuelle Umgebung bereits existiert
    if [ -d "$INSTALL_DIR/.venv" ]; then
        msg_info "Virtuelle Umgebung in $INSTALL_DIR/.venv existiert bereits."
    else
        msg_info "Erstelle neue virtuelle Umgebung"
        python3 -m venv .venv || msg_error "Erstellung der virtuellen Umgebung fehlgeschlagen."
    fi

    # Aktiviere die virtuelle Umgebung
    source .venv/bin/activate || msg_error "Aktivierung der virtuellen Umgebung fehlgeschlagen."

    # Pip aktualisieren
    upgrade_pip

    # Installiere Python-Pakete
    msg_info "Installiere erforderliche Python-Pakete"
    pip install -q -r requirements.txt || msg_error "Installation der Python-Pakete fehlgeschlagen."

    # Installiere nur Chromium
    msg_info "Installiere Chromium"
    python -m playwright install chromium >> "$LOG_FILE" 2>&1 || \
        msg_error "Playwright-Chromium-Installation fehlgeschlagen."
}

# Systemabhängigkeiten installieren
function install_dependencies() {
    msg_info "Installiere Systemabhängigkeiten."

    local deps=(
        build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev
        libssl-dev libreadline-dev libffi-dev libbz2-dev libsqlite3-dev
        liblzma-dev tk-dev libdb5.3-dev uuid-dev libgpm2 libxml2-dev
        libxmlsec1-dev mlocate libreadline-dev libffi-dev liblzma-dev lzma
        python3-packaging python3-venv
    )

    if ! { sudo apt-get update >> "$LOG_FILE" 2>&1 && sudo apt-get install -y "${deps[@]}" >> "$LOG_FILE" 2>&1; }; then
        msg_error "Paketinstallation fehlgeschlagen - siehe $LOG_FILE"
    fi

    msg_ok "Systemabhängigkeiten installiert."
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
        --with-system-expat \
        --with-system-ffi \
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

# --------------------------------------------------------------------------------
# Hauptausführung
# --------------------------------------------------------------------------------

header_info

msg_info "Willkommen bei der Einrichtung der Kleinanzeigen-API"

echo -e "${GN}Dieses Skript führt Sie durch die Installation der Kleinanzeigen-API.${CL}"
echo -e "${GN}Es werden automatisch folgende Schritte ausgeführt:${CL}"
echo -e "  ${YW}• Überprüfung und Installierung der benötigten Systemabhängigkeiten${CL}"
echo -e "  ${YW}• Kompilierung und Installation einer spezifischen Python-Version (mind. 3.12.0)${CL}"
echo -e "  ${YW}• Einrichtung des API-Projekts mit virtueller Umgebung und erforderlichen Paketen${CL}"
echo -e "  ${YW}• Konfiguration eines Systemdienstes für die automatische API-Ausführung${CL}"
echo -e "  ${YW}• Optional: Bereinigung temporärer Dateien und Cache-Optimierung${CL}"
echo -e "\n"
read -n 1 -s -r -p "${YW}Drücken Sie eine beliebige Taste, um fortzufahren...${CL}"
echo -e "\n"

install_prerequisites

# Python-Version Eingabe
while true; do
    read -p "${YW}Gewünschte Python-Version eintragen und bestätigen (mind. 3.12.0): ${CL}" PYTHON_VERSION
    if validate_version "$PYTHON_VERSION"; then
        break
    fi
done

# Port-Auswahl (benutzerdefiniert)
read -p "${YW}Wählen Sie einen Port für die API (Standard: $DEFAULT_PORT): ${CL}" chosen_port
chosen_port=${chosen_port:-$DEFAULT_PORT}
DEFAULT_PORT=$chosen_port

# Prüfe, ob der Port verfügbar ist
check_port_available

if ! confirm_step "Möchten Sie mit der Installation beginnen?"; then
    msg_error "Installation abgebrochen."
    exit 0
fi

# Installationsschritte
install_dependencies

# Prüfe, ob Python bereits installiert ist
if command -v "python${PYTHON_VERSION%.*}" &>/dev/null; then
    msg_ok "Python ${PYTHON_VERSION} ist bereits installiert."
else
    compile_python
fi

setup_project

# Systemdienst erstellen
create_systemd_service


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
    sudo apt-get autoremove -yq >> "$LOG_FILE" 2>&1
    sudo apt-get clean -yq >> "$LOG_FILE" 2>&1
    msg_ok "Paket-Cache erfolgreich bereinigt."
fi

# Stelle sicher, dass die Terminalfarben zurückgesetzt werden
echo -e "${CL}"
