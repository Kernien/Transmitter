# Transmitter

🌐 [Русский](README.md) · [English](README.en.md) · **Deutsch** · [中文](README.zh.md)

**Nachrichten, Links und Dateien zwischen deinen eigenen Geräten — ohne
Registrierung, ohne fremde Server, mit Ende-zu-Ende-Verschlüsselung.**

Einen Link auf dem Handy abschicken — ein paar Sekunden später ist er auf dem
Computer. Ein Dokument im Büro ins Fenster ziehen — es wartet schon auf dem
Handy. Alles liegt in **deiner eigenen Cloud** (derzeit Dropbox) und wird
direkt auf dem Gerät verschlüsselt: Die Cloud sieht nur bedeutungslose Bytes.

| | |
|---|---|
| 📱 **Android** | App, inklusive System-Menü „Teilen“ |
| 🖥️ **Windows** | App, Dateien per Drag & Drop ins Fenster |
| 🌐 **Browser** | https://kernien.github.io/transmitter-web/ — keine Installation nötig |

Version **0.1.0** — die erste Veröffentlichung.

> **Sprache der Oberfläche.** Die App ist derzeit nur auf Russisch. In dieser
> Anleitung stehen die Schaltflächen auf Deutsch, dahinter in Klammern die
> Beschriftung, die du in der App siehst, z. B. **Neuer Schlüssel**
> («Новый ключ»).

---

## Funktionen

- **Text und Links.** Links werden automatisch erkannt und mit einem Tippen
  geöffnet.
- **Dateien bis 25 MB** — Fotos, Dokumente, Archive. Über die 📎-Schaltfläche,
  per Drag & Drop ins Fenster (Windows und Browser) oder mit „Teilen“ aus jeder
  App unter Android.
- **„Teilen“ in beide Richtungen (Android).** Aus Browser, Galerie oder
  Messenger direkt in Transmitter — und aus Transmitter in jede App.
- **Mehrere Tresore.** Ein Verlauf für die Arbeit, einer für zu Hause: Jeder
  hat seinen eigenen Schlüssel, nichts vermischt sich.
- **Mit mehreren Nachrichten gleichzeitig arbeiten.** Auswählen und als ein
  ZIP-Archiv herunterladen, teilen oder löschen.
- **Überall löschen.** Eine gelöschte Nachricht verschwindet auf allen
  Geräten, samt Datei in der Cloud.
- **Keine Registrierung.** Keine Transmitter-Konten: Geräte werden per
  QR-Code verbunden.

## Datenschutz

- **Ende-zu-Ende-Verschlüsselung mit AES-256-GCM.** Nachrichten und Dateien
  werden vor dem Senden verschlüsselt und nur auf deinen Geräten entschlüsselt.
- **Kein eigener Server.** Deine Daten liegen nur in deiner Cloud, in einem
  eigenen Ordner `Apps/<App-Name>`. Andere Dateien sieht Transmitter nicht.
- **Der Schlüssel ist Adresse und Passwort zugleich.** Jedes Gerät mit dem
  Schlüssel eines Tresors kann darin lesen und schreiben. Gib Schlüssel nur an
  deine eigenen Geräte weiter.
- **Ein verlorener Schlüssel lässt sich nicht wiederherstellen.** Solange er
  auf mindestens einem Gerät vorhanden ist, kannst du ihn erneut anzeigen.
  Löschst du ihn überall, ist der Zugriff auf den Tresor weg.

---

## Installation

### Android

1. Lade die APK unter [**Releases**](https://github.com/Kernien/Transmitter/releases) herunter:
   - `Transmitter-0.1.0-android-arm64.apk` — für die meisten Handys der
     letzten Jahre;
   - `Transmitter-0.1.0-android-armv7.apk` — für ältere oder günstige
     Modelle, falls sich die erste nicht installieren lässt.
2. Öffne die Datei auf dem Handy. Android fragt, ob Installationen aus dieser
   Quelle (Browser oder Dateimanager) erlaubt sind — erlaube es.

### Windows

1. Lade `Transmitter-0.1.0-windows-x64.zip` unter [**Releases**](https://github.com/Kernien/Transmitter/releases) herunter.
2. Entpacke es in einen passenden Ordner (z. B. `C:\Program Files\Transmitter`
   oder `Dokumente\Transmitter`) und starte `transmitter.exe`.
3. Beim ersten Start meldet Windows eventuell „Der Computer wurde durch
   Windows geschützt“ — die App hat kein kostenpflichtiges
   Signaturzertifikat. Klicke auf **Weitere Informationen → Trotzdem
   ausführen**.

### Browser

Öffne https://kernien.github.io/transmitter-web/. Schlüssel und
Cloud-Anmeldung werden in diesem Browser gespeichert.

---

## Bedienung

### 1. Erstes Gerät: Tresor anlegen

1. Tippe auf **Neuer Schlüssel** («Новый ключ»), gib einen Namen ein (z. B.
   „Privat“) und wähle die Cloud **Dropbox** → **Erstellen** («Создать»).
2. Der QR-Code des Schlüssels erscheint — du kannst ihn schließen, er ist
   jederzeit über das ⋮-Menü erreichbar.
3. Tippe auf den neuen Tresor → **Bei Dropbox anmelden** («Войти в Dropbox»).
   Melde dich an und erlaube den Zugriff — der Verlauf öffnet sich.

### 2. Weitere Geräte: denselben Tresor verbinden

1. Auf dem ersten Gerät: ⋮ neben dem Tresor → **Schlüssel / QR anzeigen**
   («Показать ключ / QR»).
2. Auf dem neuen Gerät: QR-Symbol oben → **QR-Code scannen**
   («Сканировать QR-код») (Handy oder Browser mit Kamera) oder die
   Schlüsselzeichenfolge `TRM1.…` einfügen (kopieren mit **Schlüssel
   kopieren** — «Скопировать ключ»).
3. Melde dich beim **selben** Dropbox-Konto an — und der Verlauf erscheint.

### 3. Senden

- **Text oder Link** — das Feld unten im Verlauf und die ➤-Schaltfläche.
- **Datei** — 📎 links neben dem Feld (Text im Feld wird zur Bildunterschrift),
  Dateien ins Fenster ziehen oder unter Android: **Teilen → Transmitter** in
  jeder App.

Neue Nachrichten erscheinen auf den anderen Geräten innerhalb weniger
Sekunden, solange der Verlauf geöffnet ist.

### 4. Mit Nachrichten arbeiten

- **⋮ neben einer Nachricht:** teilen, Datei speichern, Text kopieren,
  löschen.
- **Tippen** auf einen Link öffnet ihn, auf eine Datei speichert sie.
- **Langes Drücken** (oder **Auswählen** — «Выбрать» — im ⋮-Menü) startet die
  Auswahl. Markiere mehrere Nachrichten und wähle oben: **herunterladen** (ein
  ZIP-Archiv mit den Dateien und `сообщения.txt` mit den Texten), **teilen**
  oder **löschen**.
- **⋮ in der Kopfzeile des Verlaufs → Verlauf leeren** («Очистить ленту»)
  löscht alles in diesem Tresor auf allen Geräten.

### 5. Verwalten

- **Mehrere Tresore:** Lege einen weiteren Schlüssel an — er bekommt einen
  eigenen Verlauf.
- **Clouds:** das ☁-Symbol auf dem Startbildschirm — auf diesem Gerät bei
  einer Cloud an- oder abmelden.
- **Tresor vom Gerät entfernen:** ⋮ neben dem Tresor → **Vom Gerät
  entfernen** («Удалить с устройства»). Die Daten in der Cloud und auf anderen
  Geräten bleiben erhalten.

---

## Wenn etwas nicht funktioniert

| Was passiert | Was tun |
|---|---|
| Der Browser öffnet das Dropbox-Anmeldefenster nicht | Pop-ups für die Seite erlauben; in Brave die Shields für diese Adresse ausschalten |
| „Datei größer als 25 MB“ | Grenze der Version 0.1.0: kleinere Dateien oder ein geteiltes Archiv senden |
| Eine Nachricht erscheint nicht auf einem anderen Gerät | Internetverbindung prüfen und ob derselbe Tresor geöffnet ist; der Verlauf aktualisiert sich alle 5 Sekunden |
| „Erneut bei der Cloud anmelden“ | ☁ auf dem Startbildschirm → **Abmelden** («Выйти») → **Anmelden** («Войти») |
| Xiaomi lässt die APK nicht installieren | Installation aus unbekannten Quellen für die App erlauben, mit der du die Datei öffnest |

---

## Wie es weitergeht

- Google Drive und OneDrive, danach MEGA;
- Gerätenamen und Benachrichtigungen über neue Nachrichten;
- eine Version für das iPhone;
- Fotos, Audio und Videos direkt in der App ansehen.

---

<sub>Für Entwickler: Aufbau, Build und Veröffentlichung — siehe
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) (auf Russisch).</sub>
