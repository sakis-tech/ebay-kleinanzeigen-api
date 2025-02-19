
# Kleinanzeigen API - Modern Python Implementation

<div style="text-align:center">
  <img src="https://i.imgur.com/jFbdJ4h.jpeg" />
</div>

Eine moderne Python-Implementierung der [eBay Kleinanzeigen API](https://github.com/DanielWTE/ebay-kleinanzeigen-api) mit automatischer Server-Einrichtung und Browser-Integration.

## ✨ Funktionen

- **Modernes API-Design** mit FastAPI
- **Automatisierte Installation** mit Bash-Skript
- **Swagger UI** Dokumentation
- **Headless Browser-Support** mit Playwright
- **Systemd-Service** Integration

## 🚀 Installation

### Voraussetzungen

- Ubuntu/Debian-basiertes System
- Bash Shell
- Sudo-Rechte

### Schnellstart

```bash
git clone https://github.com/sakis-tech/ebay-kleinanzeigen-api.git
cd ebay-kleinanzeigen-api
sudo ./install.sh
```

Das Installationsskript führt folgende Schritte durch:

-   Installiert Systemabhängigkeiten
-   Kompiliert Python 3.12+
-   Richtet virtuelle Umgebung ein
-   Installiert Chromium und Browser-Deps
-   Erstellt Systemd-Service
-   Startet den API-Server

## 🔧 Verwendung

### Service-Steuerung

```bash
sudo systemctl status kleinanzeigen-api  # Service-Status
sudo systemctl restart kleinanzeigen-api # Neustart
```

### API-Zugriff

Nach erfolgreicher Installation:

-   Swagger UI: `http://:8000/docs`
-   Redoc Dokumentation: `http://:8000/redoc`

## ⚙️ Konfiguration

### Port ändern

**Während der Installation:**

-   Gewünschten Port bei der Aufforderung eingeben.

**Nachträglich ändern:**

```bash
sudo nano /etc/systemd/system/kleinanzeigen-api.service
```

-   Port in der `ExecStart`-Zeile anpassen.
-   Mit den folgenden Befehlen den Service neu laden und neu starten:

```bash
sudo systemctl daemon-reload
sudo systemctl restart kleinanzeigen-api
```

### Umgebungsvariablen

**In der Service-Datei hinzufügen:**

```bash
Environment="VARIABLE=wert"
```

## 🤝 Beitragen

**Beiträge sind willkommen!**

-   Fork das Repository
-   Erstelle einen Feature-Branch (`git checkout -b feature/AmazingFeature`)
-   Commite deine Änderungen (`git commit -m 'Add some AmazingFeature'`)
-   Pushe den Branch (`git push origin feature/AmazingFeature`)
-   Öffne einen Pull Request

## 📄 Lizenz

Distributed under the MIT License. Siehe LICENSE für mehr Informationen.

## 🙌 Danksagung

Ein besonderer Dank geht an den ursprünglichen Entwickler:

-   [Daniel Wagner](https://github.com/DanielWTE) - Hauptentwickler

## 💖 Unterstütze das Projekt

Wenn dir dieses Projekt gefällt und du die Entwicklung unterstützen möchtest, kannst du gerne eine Spende über [Ko-fi](https://ko-fi.com/sakistech) hinterlassen. 

Jede Unterstützung hilft, die Arbeit an diesem Projekt fortzusetzen und neue Funktionen zu entwickeln.

Ein herzliches Dankeschön an alle, die bereits gespendet haben! Euer Beitrag wird sehr geschätzt und motiviert mich, weiterhin an diesem Projekt zu arbeiten.
