# Transmitter

🌐 [Русский](README.md) · **English** · [Deutsch](README.de.md) · [中文](README.zh.md)

**Links and small files between your own devices — no sign-up, no third-party
servers, end-to-end encrypted.**

Copy a link on your phone — a couple of seconds later it's on your computer.
Drop a document into the window at work — it's waiting for you on your phone.
Everything is stored in **your own cloud** (Dropbox or Google Drive) and encrypted
right on the device: the cloud only ever sees meaningless bytes.

| | |
|---|---|
| 📱 **Android** | app, including the system “Share” menu |
| 🖥️ **Windows** | app with an installer, drag-and-drop files into the window |
| 🐧 **Linux** | AppImage — a single file, no installation; tested on Steam Deck |
| 🌐 **Browser** | https://kernien.github.io/transmitter-web/ — nothing to install |

Version **0.5.1**. The interface is in **English and Russian** — it follows the
system language, or pick one with the 🌐 button.

## Why

Transmitter exists because its author got tired of inventing ways to move a
link or a file between the **personal and work profiles on Android** (the work
profile is created with [Shelter](https://github.com/PeterCxy/Shelter)). The
profiles are isolated from each other, and the usual workarounds — sending it
to yourself in a messenger, emailing it, copying through a cloud by hand — are
clumsy or simply don't work.

Now Transmitter is installed in both profiles and connected to the same vault:
**Share → Transmitter** in one profile — and the link or file is already
waiting in the other. It works just as well between your phone, computer and
browser.

---

## Features

- **Links.** Detected automatically and opened with a single tap.
- **Files up to 100 MB** — photos, documents, archives. The limit (10, 25, 50
  or 100 MB) is chosen for each vault when it is created. Use the 📎 button,
  drag files into the window (Windows and browser) or “Share” from any app on
  Android.
- **“Share” both ways (Android).** From your browser, gallery or any app
  straight into Transmitter — and from Transmitter into any app.
- **Several vaults.** For example, one for the “personal ↔ work profile” pair
  and another for your computer: each has its own key, and they never mix.
- **Work with many items at once.** Select them, then download as a single zip
  archive, share or delete.
- **Delete everywhere.** A deleted item disappears from all devices, along with
  its file in the cloud.
- **Device names.** Every item shows where it came from: “Redmi 10”,
  “Redmi 10 · work”, “Laptop”.
- **English and Russian.** The language follows the system or is chosen in the
  app — handy if you're learning a language.
- **No sign-up.** No Transmitter accounts: devices are linked with a key — a
  QR code or a text string.

## Privacy

- **End-to-end AES-256-GCM encryption.** Links and files are encrypted before
  they are sent and decrypted only on your devices.
- **No server of our own.** Your data lives only in your cloud, in a separate
  `Apps/<app name>` folder in Dropbox or the `Transmitter` folder in Google
  Drive. Transmitter cannot see any other files there. Details: the
  [privacy policy](https://kernien.github.io/transmitter-web/privacy.html).
- **The key is both the address and the password.** Any device with a vault
  key can read and write to that vault. Share keys only with your own devices.
- **A lost key cannot be recovered.** As long as the key is on at least one
  device, you can show it again. Remove it everywhere and access to the vault
  is gone.

---

## Installation

### Android

1. Download the APK from [**Releases**](https://github.com/Kernien/Transmitter/releases):
   - `Transmitter-0.5.1-android-arm64.apk` — for most phones from recent
     years;
   - `Transmitter-0.5.1-android-armv7.apk` — for older or budget models, if
     the first one doesn't install.
2. Open the file on your phone. Android will ask to allow installs from this
   source (your browser or file manager) — allow it.

**Work profile (Shelter).** Install Transmitter in your personal profile, then
select it in Shelter and choose **Clone to work profile**. Signing in to
the cloud in the work profile also needs a browser there — clone one as well.

### Windows

1. Download `Transmitter-0.5.1-windows-setup.exe` from [**Releases**](https://github.com/Kernien/Transmitter/releases)
   and run it. It installs for your user only — no administrator rights
   needed — and adds Transmitter to the Start menu. Uninstall it in
   **Settings → Apps**; your keys and cloud sign-ins are kept.
2. On first launch Windows may say “Windows protected your PC” — the app has
   no paid code-signing certificate. Click **More info → Run anyway**.

Prefer no installation? `Transmitter-0.5.1-windows-x64.zip` is a portable
version: unpack it anywhere and run `transmitter.exe`.

### Linux and Steam Deck

1. Download `Transmitter-0.5.1-linux-x86_64.AppImage` from [**Releases**](https://github.com/Kernien/Transmitter/releases).
2. Make the file executable — in the file manager, right-click →
   **Properties → Permissions → Is executable** (or
   `chmod +x Transmitter-*.AppImage`) — and run it.

**Steam Deck:** do this in Desktop Mode (Steam button → Power → Switch to
Desktop). To launch Transmitter from Game Mode as well, right-click the file →
**Add to Steam** — it will appear in your library among non-Steam games.

There is no QR scanner on Linux — paste the key as a string. Keys and cloud
sign-ins are stored in `~/.local/share/app.transmitter.transmitter`
(accessible only to your user). There is also
`Transmitter-0.5.1-linux-x64.tar.gz`: extract it and run `transmitter`.

### Browser

Open https://kernien.github.io/transmitter-web/. Keys and the cloud sign-in
are remembered in that browser.

---

## How to use

### 1. First device: create a vault

1. Tap **New key**, give it a name (e.g. “Personal ↔ Work”) and choose the
   cloud (**Dropbox** or **Google Drive**) and the **maximum file size** (it
   can't be changed later) → **Create**.
2. The key's QR code appears — you can close it; it's always available from
   the ⋮ menu.
3. Tap the new vault → **Sign in to Dropbox** (or Google Drive). Sign in and
   allow access — the feed opens.

### 2. Other devices: connect the same vault

1. On the first device: ⋮ next to the vault → **Show key / QR**.
2. On the new device: the QR icon at the top → **Scan QR code** (phone, or a
   browser with a camera), or paste the key string `TRM1.…` copied with
   **Copy key**.
3. Sign in to the **same** cloud account — and the feed appears.

**Google Drive notes.** During sign-in Google warns that the app isn't
verified — choose **Advanced → Go to Transmitter**. On the phone, tap
**Return to Transmitter** after signing in. In the browser Google grants
access for about an hour, then you sign in again.

**The other profile on the same phone.** You can't scan a QR code shown on
the phone's own screen, so copy the key as text and paste it into Transmitter
in the other profile. If the clipboard is blocked between profiles, show the
QR code on your computer or in the browser and scan it from there.

### 3. Send

- **A link** — paste it into the field at the bottom of the feed and tap ➤.
  Or in your browser on Android: **Share → Transmitter**.
- **A file** — 📎 to the left of the field (any text in the field becomes the
  file's caption), or drag files into the window, or on Android:
  **Share → Transmitter** in any app.
- **A photo or video** (Android) — 🖼 to the left of 📎 opens your gallery app,
  which is easier than digging through files.

New items appear on your other devices within a few seconds while the feed is
open.

### 4. Work with items

- **⋮ next to an item:** **Share**, **Save file**, **Copy text** (the link or
  caption), **Delete on all devices**.
- **Tap** a link to open it, tap a file to save it.
- **Long-press** (or **Select** in the ⋮ menu) starts selection. Tick several
  items and choose at the top: **download** (one zip archive; links and
  captions go into `items.txt`), **share** or **delete**.
- **⋮ in the feed header → Clear feed** deletes everything in this vault on all
  devices.

### 5. Manage

- **Several vaults:** create another key — it gets its own feed.
- **Language:** the 🌐 icon on the main screen — *As in the system*, Русский or
  English. The choice is stored on each device separately.
- **Device name:** the 🪪 icon on the main screen. On first launch Transmitter
  suggests a name itself.
- **Clouds:** the ☁ icon on the main screen — sign in to or out of a cloud on
  this device.
- **Remove a vault from a device:** ⋮ next to the vault → **Remove from
  device**. The data in the cloud and on other devices stays.

---

## Troubleshooting

| What happens | What to do |
|---|---|
| The browser doesn't open the cloud sign-in window | Allow pop-ups for the site; in Brave, turn off Shields for this address |
| Google Drive asks to sign in again in the browser | Google limits server-less web apps to about an hour of access. ☁ → Google Drive → **Sign in** |
| Cloud sign-in won't open in the work profile | Clone a browser into the work profile with Shelter |
| “File is larger than N MB” | That is the vault's limit chosen when it was created. For bigger files create a vault with a higher limit (up to 100 MB) or send a split archive |
| An item didn't show up on another device | Check your connection and that the same vault is open; the feed refreshes every 5 seconds. In Shelter, make sure Transmitter isn't frozen in the work profile |
| “Sign in to the cloud again” | ☁ on the main screen → **Sign out** → **Sign in** |
| Xiaomi won't install the APK | Allow installs from unknown sources for the app you open the file with |
| The AppImage won't start on Linux | Make the file executable (see Installation → Linux). Some distributions need the `libfuse2` package; Steam Deck already has it |

---

## What's next

- the MEGA cloud;
- comments on items — a note you can add and edit later;
- viewing photos, audio and video right in the app;
- an iPhone version.

---

## License

Transmitter is free software licensed under the [GNU GPL v3.0](LICENSE). You may use, study, modify and share it; modified versions must also remain open under the GPL-3.0. Source code: https://github.com/Kernien/Transmitter

---

<sub>For developers: architecture, building and releasing — see
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) (in Russian).</sub>
