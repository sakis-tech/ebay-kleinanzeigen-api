# Autonome Serverkonfiguration für eBay-Kleinanzeigen-API

<div align="center">
  <img src="https://i.imgur.com/i4iu51v.jpeg">
</div>

------------


Mit diesem Skript wird die komplette Einrichtung eines Servers zur Ausführung der [**eBay Kleinanzeigen API**](https://github.com/DanielWTE/ebay-kleinanzeigen-api) vereinfacht und automatisiert. Es sorgt dafür, dass der Server optimal konfiguriert ist und die API problemlos funktioniert, ohne dass der Benutzer sich um komplexe Konfigurationsdetails kümmern muss.

---

## 🚀 Was macht das Skript?

### **Hauptfunktionen:**

1. **Automatische Installation von Abhängigkeiten**:
   - Das Skript überprüft und installiert alle benötigten Systemtools und Programme, die für den korrekten Betrieb der API erforderlich sind.

2. **Einrichtung der API-Umgebung**:
   - Die API wird heruntergeladen, konfiguriert und bereitgestellt. Dabei wird sichergestellt, dass alle Komponenten ordnungsgemäß integriert sind.

3. **Port-Konfiguration**:
   - Der Benutzer kann einen spezifischen Port für die API auswählen oder den Standardport ```(8000)``` verwenden. Das Skript prüft, ob der gewählte Port verfügbar ist, und passt die Konfiguration entsprechend an.

4. **Erstellung eines Systemdienstes**:
   - Der API-Dienst wird als `Systemdienst` konfiguriert, wobei der zuvor vom Benutzer ausgewählte Port in die Konfiguration des Dienstes eingetragen wird. Dadurch wird sichergestellt, dass die API auf dem gewünschten Port läuft und der Dienst automatisch beim Systemstart gestartet wird.

5. **Benutzerfreundliche Anleitung**:
   - Während der Installation wird der Benutzer durch jede Phase geführt. Es gibt klare Anweisungen und Bestätigungsabfragen, um Missverständnisse zu vermeiden.

6. **Bereinigungsoptionen**:
   - Nach Abschluss der Installation bietet das Skript die Möglichkeit, temporäre Dateien und unnötige Pakete zu entfernen, um Speicherplatz freizugeben und die Systemperformance zu optimieren.

---

## 📋 Zusätzliche Informationen 
### **Überwachung der Installation** 

Während der Installation können Sie den Fortschritt und alle Aktionen, die im Hintergrund ausgeführt werden, in Echtzeit verfolgen. Dies ermöglicht es Ihnen, einen detaillierten Einblick in den Installationsprozess zu erhalten. 

**So überwachen Sie die Installationsschritte:**  
Führen Sie den folgenden Befehl in einer separaten Terminal-Sitzung aus:

```bash
tail -f /tmp/ebay-kleinanzeigen-api.txt
```

Dieser Befehl zeigt die fortlaufenden Logs der Installation in Echtzeit an. Sobald die Installation abgeschlossen ist, können Sie das ```tail```-Kommando durch Drücken von ```Ctrl + C``` beenden. 

---

## 📋 Voraussetzungen

- Ubuntu/Debian-basiertes System
- Bash Shell
- Sudo-Rechte

---

## 🛠 Installation

### Schnelle Installation (Empfohlen)

Die einfachste Möglichkeit, die eBay-Kleinanzeigen-API einzurichten, ist die Verwendung des automatisierten Setup-Skripts über einen einzigen Befehl. 
Dieses Skript führt alle notwendigen Schritte für die vollautomatische Einrichtung durch.

Führen Sie den folgenden Befehl in Ihrer Terminal aus:

```bash
bash <(wget -qO- --no-cache https://raw.githubusercontent.com/sakis-tech/ebay-kleinanzeigen-api/main/autoserve.sh)
```

Das Skript wird Sie schrittweise durch die Einrichtung führen, einschließlich der Auswahl der Python-Version und des API-Ports.

---

### Manuelle Installation

Alternativ können Sie das Repository klonen und das Setup-Skript lokal ausführen. Dazu gehen Sie wie folgt vor:

1. Klonen Sie das Repository auf Ihren Server:

   ```bash
   git clone https://github.com/sakis-tech/ebay-kleinanzeigen-api.git
   cd ebay-kleinanzeigen-api
   chmod +x autoserve.sh
   ```

2. Führen Sie das `autoserve.sh`-Skript aus:

   ```bash
   ./autoserve.sh
   ```

Dieser Weg bietet mehr Kontrolle über die Einrichtungsprozesse und kann nützlich sein, wenn Sie das Skript vor dem Ausführen anpassen möchten.

---

## 🔧 Verwendung

### Service-Steuerung

```bash
sudo systemctl status ebay-kleinanzeigen-api  # Service-Status anzeigen
sudo systemctl restart ebay-kleinanzeigen-api # Service neustarten
```

### API-Zugriff

Nach erfolgreicher Installation:

- **Swagger UI**: `http://<IP>:8000/docs`
- **Redoc Dokumentation**: `http://<IP>:8000/redoc`

---

## ⚙️ Konfiguration

### Port ändern

#### Während der Installation:
- Geben Sie den gewünschten Port ein, wenn Sie dazu aufgefordert werden.

#### Nachträglich ändern:
1. Öffnen Sie die Service-Datei:

   ```bash
   sudo nano /etc/systemd/system/ebay-kleinanzeigen-api.service
   ```

2. Ändern Sie den Port in der `ExecStart`-Zeile.
3. Aktualisieren Sie den Service:

   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart ebay-kleinanzeigen-api
   ```

---

## 📄 Lizenz

Distributed under the MIT License. Siehe [LICENSE](https://raw.githubusercontent.com/sakis-tech/ebay-kleinanzeigen-api/main/LICENSE) für weitere Informationen.

---

## 🙌 Danksagung

Ein besonderer Dank geht an den Entwickler von eBay-Kleinanzeigen-API:

- [Daniel Wagner](https://github.com/DanielWTE) - Hauptentwickler

---

## 💖 Unterstütze das Projekt

Wenn dir dieses Projekt gefällt und du die Entwicklung unterstützen möchtest, kannst du gerne eine Spende über Ko-fi hinterlassen.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/J3J5NZMHT)

Jede Unterstützung hilft, die Arbeit an diesem Projekt fortzusetzen und neue Funktionen zu entwickeln.

Ein herzliches Dankeschön an alle, die bereits gespendet haben! Euer Beitrag wird sehr geschätzt und motiviert mich, weiterhin an diesem Projekt zu arbeiten.

---
