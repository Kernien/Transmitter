# Transmitter

🌐 [Русский](README.md) · [English](README.en.md) · **Deutsch** · [中文](README.zh.md)

**Links und kleine Dateien zwischen deinen eigenen Geräten — ohne
Registrierung, ohne fremde Server, mit Ende-zu-Ende-Verschlüsselung.**

Einen Link auf dem Handy kopieren — ein paar Sekunden später ist er auf dem
Computer. Ein Dokument im Büro ins Fenster ziehen — es wartet schon auf dem
Handy. Alles liegt in **deiner eigenen Cloud** (Dropbox, Google Drive oder MEGA) und
wird direkt auf dem Gerät verschlüsselt: Die Cloud sieht nur bedeutungslose
Bytes.

| | |
|---|---|
| 📱 **Android** | App, inklusive System-Menü „Teilen“ |
| 🖥️ **Windows** | App mit Installationsprogramm, Dateien per Drag & Drop ins Fenster |
| 🐧 **Linux** | AppImage — eine einzige Datei ohne Installation; getestet auf dem Steam Deck |
| 🌐 **Browser** | https://kernien.github.io/transmitter-web/ — keine Installation nötig |

Version **0.17.0**.

> **Sprache der Oberfläche.** Die App gibt es auf Englisch und Russisch; auf
> einem deutschen System ist sie auf Englisch (umschalten unter ⚙ „Settings“).
> In dieser Anleitung stehen die Schaltflächen auf Deutsch, dahinter in
> Klammern die englische Beschriftung aus der App, z. B. **Neuer Schlüssel**
> („New key“).

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
- **Dateien bis 100 MB** — Fotos, Dokumente, Archive. Die Grenze (10, 25, 50
  oder 100 MB) wird für jeden Tresor beim Anlegen festgelegt. Über die
  📎-Schaltfläche, per Drag & Drop ins Fenster (Windows und Browser) oder mit
  „Teilen“ aus jeder App unter Android.
- **„Teilen“ in beide Richtungen (Android).** Aus Browser, Galerie oder jeder
  anderen App direkt in Transmitter — und aus Transmitter in jede App.
- **Mehrere Tresore.** Zum Beispiel einer für das Paar „privates ↔
  Arbeitsprofil“ und einer für den Computer: Jeder hat seinen eigenen
  Schlüssel, nichts vermischt sich.
- **Mit mehreren Einträgen gleichzeitig arbeiten.** Auswählen und als ein
  ZIP-Archiv herunterladen, teilen oder löschen.
- **Kommentare zu Einträgen.** Eine Notiz zu einem Link oder einer Datei —
  was es ist und wozu; auf jedem Gerät änderbar oder löschbar.
- **Überall löschen.** Ein gelöschter Eintrag verschwindet auf allen Geräten,
  samt Datei in der Cloud.
- **Gerätenamen.** Bei jedem Eintrag sieht man, woher er kommt: „Redmi 10“,
  „Redmi 10 · work“, „Laptop“.
- **Englisch und Russisch.** Die Sprache folgt dem System oder wird in der App
  gewählt.
- **Erscheinungsbild nach Wahl.** Helles oder dunkles Design, wie im System,
  oder eine Farbvorlage: Ozean, Wald, Sonnenuntergang, Nacht (schwarz) — der
  schwarze Hintergrund schont den Akku bei OLED-Bildschirmen. Dazu beliebte
  dunkle Editor-Designs: Dracula, Nord, One Dark, Solarized Dark, Gruvbox,
  Catppuccin Mocha.
- **Fotos direkt im Verlauf.** Vorschauen bei Einträgen mit Bildern und eine
  Vollbildansicht mit Zoom. Große Fotos (über 10 MB) werden auf Knopfdruck
  geladen.
- **Dokumente direkt in der App.** Textdateien (`.txt`, `.csv`, `.json`,
  `.log`, Quellcode), formatiertes Markdown und Word-Dokumente `.docx`
  öffnen sich per Tippen: markieren, kopieren, Festbreitenschrift.
- **Videos und Musik direkt in der App** (Android, Windows, Browser): ein
  Player mit Spulen und Vollbild, fast jedes Format (`.mp4`, `.mkv`, `.avi`,
  `.mp3`, `.flac`…). Während ein Video läuft, bleibt der Bildschirm an;
  Musik spielt auch bei ausgeschaltetem Bildschirm weiter.
- **In einer anderen App öffnen** („Open in another app“) — für jede Datei:
  PDF, `.doc`, Archive, Videos unter Linux und alles, was Transmitter nicht
  selbst anzeigt.
- **Schnell, auch offline.** Einträge werden auf dem Gerät gespeichert
  (verschlüsselt, wie in der Cloud): Der Verlauf öffnet sich sofort und zeigt
  ohne Verbindung das Gespeicherte. Geöffnete Dateien bleiben ebenfalls auf dem
  Gerät (Limit unter ⚙ „Settings“ → „Storage on this device“, standardmäßig
  1 GB).
- **Öffentliche Boards.** Öffne einen beliebigen Tresor nur zum Lesen und
  teile ihn mit anderen: Mit einem Leseschlüssel lassen sich Einträge ansehen,
  kopieren und herunterladen, aber nicht ändern. Leser brauchen kein
  Cloud-Konto.
- **Keine Registrierung.** Keine Transmitter-Konten: Geräte werden über einen
  Schlüssel verbunden — per QR-Code oder als Zeichenfolge.

## Datenschutz

- **Ende-zu-Ende-Verschlüsselung mit AES-256-GCM.** Links und Dateien werden
  vor dem Senden verschlüsselt und nur auf deinen Geräten entschlüsselt.
- **Kein eigener Server.** Deine Daten liegen nur in deiner Cloud, in einem
  eigenen Ordner: `Apps/<App-Name>` in Dropbox oder `Transmitter` in Google
  Drive bzw. MEGA. In Dropbox und Google Drive sieht Transmitter keine anderen
  Dateien; MEGA kennt keinen Zugriff auf nur einen Ordner, die App arbeitet
  aber nur mit ihrem eigenen. Mehr dazu in der
  [Datenschutzerklärung](https://kernien.github.io/transmitter-web/privacy.html).
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
   - `Transmitter-0.17.0-android-arm64.apk` — für die meisten Handys der
     letzten Jahre;
   - `Transmitter-0.17.0-android-armv7.apk` — für ältere oder günstige
     Modelle, falls sich die erste nicht installieren lässt.
2. Öffne die Datei auf dem Handy. Android fragt, ob Installationen aus dieser
   Quelle (Browser oder Dateimanager) erlaubt sind — erlaube es.

**Arbeitsprofil (Shelter).** Installiere Transmitter im privaten Profil, wähle
es dann in Shelter aus und tippe auf **In Arbeitsprofil klonen**. Für die
Cloud-Anmeldung im Arbeitsprofil wird dort auch ein Browser gebraucht —
klone ihn ebenfalls.

### Windows

1. Lade `Transmitter-0.17.0-windows-setup.exe` unter [**Releases**](https://github.com/Kernien/Transmitter/releases)
   herunter und starte es. Die Installation gilt nur für deinen Benutzer —
   ohne Administratorrechte — und legt Transmitter im Startmenü an.
   Deinstallieren unter **Einstellungen → Apps**; Schlüssel und
   Cloud-Anmeldungen bleiben erhalten.
2. Beim ersten Start meldet Windows eventuell „Der Computer wurde durch
   Windows geschützt“ — die App hat kein kostenpflichtiges
   Signaturzertifikat. Klicke auf **Weitere Informationen → Trotzdem
   ausführen**.

Lieber ohne Installation? `Transmitter-0.17.0-windows-x64.zip` ist eine
portable Version: irgendwo entpacken und `transmitter.exe` starten.

### Linux und Steam Deck

1. Lade `Transmitter-0.17.0-linux-x86_64.AppImage` unter [**Releases**](https://github.com/Kernien/Transmitter/releases) herunter.
2. Mache die Datei ausführbar — im Dateimanager per Rechtsklick →
   **Eigenschaften → Berechtigungen → Ausführbar** (oder
   `chmod +x Transmitter-*.AppImage`) — und starte sie.

**Steam Deck:** Das alles im Desktop-Modus (Steam-Taste → Ein/Aus → Zum
Desktop wechseln). Um Transmitter auch im Spielmodus zu starten, klicke die
Datei mit rechts an → **Zu Steam hinzufügen** — sie erscheint in der
Bibliothek unter den Nicht-Steam-Spielen.

Unter Linux gibt es keinen QR-Scanner — füge den Schlüssel als Text ein.
Schlüssel und Cloud-Anmeldungen liegen in
`~/.local/share/app.transmitter.transmitter` (nur für deinen Benutzer
lesbar). Außerdem gibt es `Transmitter-0.17.0-linux-x64.tar.gz`: entpacken und
`transmitter` starten.

### Browser

Öffne https://kernien.github.io/transmitter-web/. Schlüssel und
Cloud-Anmeldung werden in diesem Browser gespeichert.

---

## Bedienung

### 1. Erstes Gerät: Tresor anlegen

1. Tippe auf **Neuer Schlüssel** („New key“), gib einen Namen ein (z. B.
   „Privat ↔ Arbeit“) und wähle die Cloud (**Dropbox**, **Google
   Drive** oder **MEGA**) und die **maximale Dateigröße** („Maximum file size“; später
   änderbar: ⋮ beim Tresor → „File size…“) → **Erstellen** („Create“).
2. Der QR-Code des Schlüssels erscheint — du kannst ihn schließen, er ist
   jederzeit über das ⋮-Menü erreichbar.
3. Tippe auf den neuen Tresor → **Bei Dropbox anmelden** („Sign in to
   Dropbox“, bzw. Google Drive). Melde dich an und erlaube den Zugriff — der
   Verlauf öffnet sich. Bei MEGA meldest du dich mit E-Mail und Passwort
   direkt in der App an (und mit einem Code, falls die
   Zwei-Faktor-Authentifizierung aktiv ist); das Passwort wird nicht
   gespeichert.

### 2. Weitere Geräte: denselben Tresor verbinden

1. Auf dem ersten Gerät: ⋮ neben dem Tresor → **Schlüssel / QR anzeigen**
   („Show key / QR“).
2. Auf dem neuen Gerät: QR-Symbol oben → **QR-Code scannen** („Scan QR code“)
   (Handy oder Browser mit Kamera) oder die Schlüsselzeichenfolge `TRM1.…`
   einfügen, kopiert mit **Schlüssel kopieren** („Copy key“).
3. Melde dich beim **selben** Cloud-Konto an — und der Verlauf erscheint.

**Besonderheiten von Google Drive.** Bei der Anmeldung warnt Google, dass die
App nicht überprüft ist — wähle **Erweitert → Weiter zu Transmitter**. Auf dem
Handy nach der Anmeldung **Zurück zu Transmitter** („Return to
Transmitter“) tippen. Im Browser gewährt Google den Zugriff etwa eine Stunde,
danach erneut anmelden.

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
- **Foto oder Video** (Android) — 🖼 links neben 📎 öffnet die Galerie-App;
  so findet man Aufnahmen leichter als in den Dateien.

Neues erscheint auf den anderen Geräten innerhalb weniger Sekunden, solange
der Verlauf geöffnet ist.

### 4. Mit Einträgen arbeiten

- **⋮ neben einem Eintrag:** **Kommentar hinzufügen** („Add comment“, später
  „Edit comment“), **Text auswählen** („Select text“, um einen Teil zu
  kopieren), **Teilen** („Share“), **Datei speichern** („Save
  file“), **Text kopieren** („Copy text“ — Link oder Bildunterschrift), **Auf
  allen Geräten löschen** („Delete on all devices“).
- **Tippen** auf einen Link öffnet ihn, auf eine Datei speichert sie.
- **Langes Drücken** (oder **Auswählen** — „Select“ — im ⋮-Menü) startet die
  Auswahl. Markiere mehrere Einträge und wähle oben: **herunterladen** (ein
  ZIP-Archiv; Links und Bildunterschriften landen in `items.txt`), **teilen**
  oder **löschen**.
- **⋮ in der Kopfzeile des Verlaufs → Verlauf leeren** („Clear feed“) löscht
  alles in diesem Tresor auf allen Geräten.

### 5. Verwalten

- **Mehrere Tresore:** Lege einen weiteren Schlüssel an — er bekommt einen
  eigenen Verlauf.
- **Einstellungen:** das ⚙-Symbol auf dem Startbildschirm („Settings“) —
  Erscheinungsbild („Appearance“), Sprache („Language“: wie im System,
  Русский oder English) und Speicher auf dem Gerät („Storage on this device“,
  nicht im Browser). Die Wahl gilt für jedes Gerät einzeln.
- **Gerätename:** das 🪪-Symbol auf dem Startbildschirm. Beim ersten Start
  schlägt Transmitter selbst einen Namen vor.
- **Clouds:** das ☁-Symbol auf dem Startbildschirm — auf diesem Gerät bei
  einer Cloud an- oder abmelden.
- **Tresor vom Gerät entfernen:** ⋮ neben dem Tresor → **Vom Gerät
  entfernen** („Remove from device“). Die Daten in der Cloud und auf anderen
  Geräten bleiben erhalten.

### 6. Öffentliche Boards: mit anderen teilen

Jeder Tresor (in Dropbox, Google Drive oder MEGA) lässt sich **nur zum
Lesen** öffnen — zum Beispiel, um eine Sammlung von Links oder Fotos mit
Freunden oder Kollegen zu teilen.

**Besitzer:**

1. ⋮ neben dem Tresor → **Lesezugriff…** („Read-only access…“) →
   **Zugriff öffnen** („Open access“). Bei Dropbox bittet die App einmalig
   um eine neue Anmeldung (Schaltfläche „Sign in to Dropbox again“ direkt in
   diesem Fenster) — so erhält sie das Recht, öffentliche Links zu erstellen.
2. Es erscheint ein **Leseschlüssel** — QR-Code und Zeichenkette `TRM1R.…`.
   Schicke ihn an die Personen, mit denen du teilen möchtest. Er lässt sich
   dort jederzeit wieder anzeigen.
3. Danach nutzt du den Tresor wie gewohnt: Neue Einträge, Kommentare und
   Löschungen erreichen die Leser von selbst, innerhalb etwa einer Minute.
4. **Zugriff schließen** („Close access“) — alle ausgegebenen Leseschlüssel
   funktionieren nicht mehr. Öffnest du den Zugriff erneut, gibt es einen
   neuen Schlüssel.

**Leser:** QR-Symbol oben → Leseschlüssel einfügen oder scannen. Das Board
erscheint in der Liste mit dem Vermerk „Read-only“. Ein Cloud-Konto oder eine
Anmeldung ist nicht nötig, auch der Browser genügt. Einträge lassen sich
ansehen, kopieren, herunterladen und weiterleiten, aber nicht ändern.

Ein Leser sieht **den gesamten Tresor** samt Kommentaren — lege zum Teilen mit
anderen also einen eigenen Tresor an. Hinter den Cloud-Links liegen nur
verschlüsselte Daten, und der Leseschlüssel enthält nicht das Geheimnis des
Tresors — ändern lässt er sich damit nicht. Leseschlüssel öffnen sich ab
Transmitter 0.7.0.

---

## Wenn etwas nicht funktioniert

| Was passiert | Was tun |
|---|---|
| Der Browser öffnet das Cloud-Anmeldefenster nicht | Pop-ups für die Seite erlauben; in Brave die Shields für diese Adresse ausschalten |
| Google Drive verlangt im Browser eine neue Anmeldung | Google begrenzt Web-Apps ohne Server auf etwa eine Stunde Zugriff. ☁ → Google Drive → **Anmelden** („Sign in“) |
| Im Arbeitsprofil öffnet sich die Cloud-Anmeldung nicht | Mit Shelter einen Browser ins Arbeitsprofil klonen |
| „File is larger than N MB“ | Das ist die beim Anlegen gewählte Grenze des Tresors. Für größere Dateien einen Tresor mit höherer Grenze (bis 100 MB) anlegen oder ein geteiltes Archiv senden |
| Ein Eintrag erscheint nicht auf einem anderen Gerät | Internetverbindung prüfen und ob derselbe Tresor geöffnet ist; der Verlauf aktualisiert sich alle 5 Sekunden. In Shelter prüfen, dass Transmitter im Arbeitsprofil nicht eingefroren ist |
| „Sign in to the cloud again“ | ☁ auf dem Startbildschirm → **Abmelden** („Sign out“) → **Anmelden** („Sign in“) |
| Xiaomi lässt die APK nicht installieren | Installation aus unbekannten Quellen für die App erlauben, mit der du die Datei öffnest |
| Bei einem `TRM1R.…`-Schlüssel erscheint „This isn't a Transmitter key“ | Das ist ein Leseschlüssel eines öffentlichen Boards: Transmitter auf 0.7.0 oder neuer aktualisieren |
| Beim Öffnen des Lesezugriffs: erneut bei Dropbox anmelden | Im selben Fenster „Sign in to Dropbox again“ drücken und den Zugriff erlauben — nur einmal nötig |
| „The owner has closed access to this board“ | Dieser Leseschlüssel funktioniert nicht mehr — bitte den Besitzer um einen neuen |
| Das AppImage startet unter Linux nicht | Mache die Datei ausführbar (siehe Installation → Linux). Manche Distributionen brauchen das Paket `libfuse2`; auf dem Steam Deck ist es schon vorhanden |

---

## Wie es weitergeht

- Die Linux-Version auf Flathub: Installation und Updates aus dem App-Store
  (auf dem Steam Deck — Discover).

Eine iPhone-Version gibt es vorerst nicht: Es fehlt ein Gerät zum Testen. Auf
dem iPhone kannst du die [Web-Version](https://kernien.github.io/transmitter-web/) in Safari nutzen.

---

## Lizenz

Transmitter ist freie Software unter der [GNU GPL v3.0](LICENSE). Du darfst sie nutzen, untersuchen, verändern und weitergeben; veränderte Versionen müssen ebenfalls unter der GPL-3.0 offen bleiben. Quellcode: https://github.com/Kernien/Transmitter

---

<sub>Für Entwickler: Aufbau, Build und Veröffentlichung — siehe
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) (auf Russisch).</sub>
