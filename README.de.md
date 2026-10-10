# Transmitter

🌐 [Русский](README.md) · [English](README.en.md) · **Deutsch** · [中文](README.zh.md)

**Links und kleine Dateien zwischen deinen eigenen Geräten — ohne
Registrierung, ohne fremde Server, mit Ende-zu-Ende-Verschlüsselung.**

Einen Link auf dem Handy kopieren — ein paar Sekunden später ist er auf dem
Computer. Ein Dokument im Büro ins Fenster ziehen — es wartet schon auf dem
Handy. Alles liegt in **deiner eigenen Cloud** (derzeit Dropbox) und wird
direkt auf dem Gerät verschlüsselt: Die Cloud sieht nur bedeutungslose Bytes.

| | |
|---|---|
| 📱 **Android** | App, inklusive System-Menü „Teilen“ |
| 🖥️ **Windows** | App, Dateien per Drag & Drop ins Fenster |
| 🌐 **Browser** | https://kernien.github.io/transmitter-web/ — keine Installation nötig |

Version **0.2.0**.

> **Sprache der Oberfläche.** Die App ist derzeit nur auf Russisch. In dieser
> Anleitung stehen die Schaltflächen auf Deutsch, dahinter in Klammern die
> Beschriftung, die du in der App siehst, z. B. **Neuer Schlüssel**
> («Новый ключ»).

## Wozu

Transmitter ist entstanden, weil der Autor es leid war, sich immer wieder
neue Wege auszudenken, einen Link oder eine Datei zwischen **privatem Profil
und Arbeitsprofil unter Android** zu übertragen (das Arbeitsprofil ist mit
[Shelter](https://github.com/PeterCxy/Shelter) eingerichtet). Die Profile sind
voneinander isoliert, und die üblichen Umwege — sich selbst im Messenger
schreiben, per E-Mail schicken, von Hand über eine Cloud kopieren — sind
umständlich oder funktionieren gar nicht.

Jetzt ist Transmitter in beiden Profilen installiert und mit demselben Tresor
verbunden: **Teilen → Transmitter** im einen Profil — und der Link oder die
Datei wartet schon im anderen. Genauso bequem klappt es zwischen Handy,
Computer und Browser.

---

## Funktionen

- **Links.** Werden automatisch erkannt und mit einem Tippen geöffnet.
- **Dateien bis 100 MB** — Fotos, Dokumente, Archive. Die Grenze (10, 25, 50 oder 100 MB) wird für jeden Tresor beim Anlegen festgelegt. Über die 📎-Schaltfläche,
  per Drag & Drop ins Fenster (Windows und Browser) oder mit „Teilen“ aus jeder
  App unter Android.
- **„Teilen“ in beide Richtungen (Android).** Aus Browser, Galerie oder jeder
  anderen App direkt in Transmitter — und aus Transmitter in jede App.
- **Mehrere Tresore.** Zum Beispiel einer für das Paar „privates ↔
  Arbeitsprofil“ und einer für den Computer: Jeder hat seinen eigenen
  Schlüssel, nichts vermischt sich.
- **Mit mehreren Einträgen gleichzeitig arbeiten.** Auswählen und als ein
  ZIP-Archiv herunterladen, teilen oder löschen.
- **Überall löschen.** Ein gelöschter Eintrag verschwindet auf allen Geräten,
  samt Datei in der Cloud.
- **Gerätenamen.** Bei jedem Eintrag sieht man, woher er kommt: „Redmi 10“, „Redmi 10 · рабочий“ (Arbeit), „Laptop“.
- **Keine Registrierung.** Keine Transmitter-Konten: Geräte werden über einen
  Schlüssel verbunden — per QR-Code oder als Zeichenfolge.

## Datenschutz

- **Ende-zu-Ende-Verschlüsselung mit AES-256-GCM.** Links und Dateien werden
  vor dem Senden verschlüsselt und nur auf deinen Geräten entschlüsselt.
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
   - `Transmitter-0.2.0-android-arm64.apk` — für die meisten Handys der
     letzten Jahre;
   - `Transmitter-0.2.0-android-armv7.apk` — für ältere oder günstige
     Modelle, falls sich die erste nicht installieren lässt.
2. Öffne die Datei auf dem Handy. Android fragt, ob Installationen aus dieser
   Quelle (Browser oder Dateimanager) erlaubt sind — erlaube es.

**Arbeitsprofil (Shelter).** Installiere Transmitter im privaten Profil, wähle
es dann in Shelter aus und tippe auf **In Arbeitsprofil klonen**. Für die
Dropbox-Anmeldung im Arbeitsprofil wird dort auch ein Browser gebraucht —
klone ihn ebenfalls.

### Windows

1. Lade `Transmitter-0.2.0-windows-x64.zip` unter [**Releases**](https://github.com/Kernien/Transmitter/releases) herunter.
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
   „Privat ↔ Arbeit“) und wähle die Cloud **Dropbox** und die **maximale Dateigröße** («Максимальный размер файла»; später nicht änderbar) → **Erstellen**
   («Создать»).
2. Der QR-Code des Schlüssels erscheint — du kannst ihn schließen, er ist
   jederzeit über das ⋮-Menü erreichbar.
3. Tippe auf den neuen Tresor → **Bei Dropbox anmelden** («Войти в Dropbox»).
   Melde dich an und erlaube den Zugriff — der Verlauf öffnet sich.

### 2. Weitere Geräte: denselben Tresor verbinden

1. Auf dem ersten Gerät: ⋮ neben dem Tresor → **Schlüssel / QR anzeigen**
   («Показать ключ / QR»).
2. Auf dem neuen Gerät: QR-Symbol oben → **QR-Code scannen**
   («Сканировать QR-код») (Handy oder Browser mit Kamera) oder die
   Schlüsselzeichenfolge `TRM1.…` einfügen, kopiert mit **Schlüssel kopieren**
   («Скопировать ключ»).
3. Melde dich beim **selben** Dropbox-Konto an — und der Verlauf erscheint.

**Das andere Profil auf demselben Handy.** Einen QR-Code vom eigenen
Bildschirm kann man nicht scannen — kopiere den Schlüssel deshalb als Text
und füge ihn in Transmitter im anderen Profil ein. Ist die Zwischenablage
zwischen den Profilen gesperrt, zeige den QR-Code am Computer oder im Browser
an und scanne ihn von dort.

### 3. Senden

- **Link** — ins Feld unten im Verlauf einfügen und ➤ tippen. Oder im Browser
  unter Android: **Teilen → Transmitter**.
- **Datei** — 📎 links neben dem Feld (Text im Feld wird zur Bildunterschrift),
  Dateien ins Fenster ziehen oder unter Android: **Teilen → Transmitter** in
  jeder App.

Neues erscheint auf den anderen Geräten innerhalb weniger Sekunden, solange
der Verlauf geöffnet ist.

### 4. Mit Einträgen arbeiten

- **⋮ neben einem Eintrag:** **Teilen** («Поделиться»), **Datei speichern**
  («Сохранить файл»), **Text kopieren** («Копировать текст» — Link oder
  Bildunterschrift), **Auf allen Geräten löschen**
  («Удалить для всех устройств»).
- **Tippen** auf einen Link öffnet ihn, auf eine Datei speichert sie.
- **Langes Drücken** (oder **Auswählen** — «Выбрать» — im ⋮-Menü) startet die
  Auswahl. Markiere mehrere Einträge und wähle oben: **herunterladen** (ein
  ZIP-Archiv; Links und Bildunterschriften landen in `сообщения.txt`),
  **teilen** oder **löschen**.
- **⋮ in der Kopfzeile des Verlaufs → Verlauf leeren** («Очистить ленту»)
  löscht alles in diesem Tresor auf allen Geräten.

### 5. Verwalten

- **Mehrere Tresore:** Lege einen weiteren Schlüssel an — er bekommt einen
  eigenen Verlauf.
- **Gerätename:** das 🪪-Symbol links neben ☁ auf dem Startbildschirm («Имя устройства»). Beim ersten Start schlägt Transmitter selbst einen Namen vor.
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
| Im Arbeitsprofil öffnet sich die Dropbox-Anmeldung nicht | Mit Shelter einen Browser ins Arbeitsprofil klonen |
| „Datei größer als N MB“ | Das ist die beim Anlegen gewählte Grenze des Tresors. Für größere Dateien einen Tresor mit höherer Grenze (bis 100 MB) anlegen oder ein geteiltes Archiv senden |
| Ein Eintrag erscheint nicht auf einem anderen Gerät | Internetverbindung prüfen und ob derselbe Tresor geöffnet ist; der Verlauf aktualisiert sich alle 5 Sekunden. In Shelter prüfen, dass Transmitter im Arbeitsprofil nicht eingefroren ist |
| „Erneut bei der Cloud anmelden“ | ☁ auf dem Startbildschirm → **Abmelden** («Выйти») → **Anmelden** («Войти») |
| Xiaomi lässt die APK nicht installieren | Installation aus unbekannten Quellen für die App erlauben, mit der du die Datei öffnest |

---

## Wie es weitergeht

- Google Drive und OneDrive, danach MEGA;
- ein Installationsprogramm für Windows;
- eine Version für das iPhone;
- Fotos, Audio und Videos direkt in der App ansehen.

---

## Lizenz

Transmitter ist freie Software unter der [GNU GPL v3.0](LICENSE). Du darfst sie nutzen, untersuchen, verändern und weitergeben; veränderte Versionen müssen ebenfalls unter der GPL-3.0 offen bleiben. Quellcode: https://github.com/Kernien/Transmitter

---

<sub>Für Entwickler: Aufbau, Build und Veröffentlichung — siehe
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) (auf Russisch).</sub>
