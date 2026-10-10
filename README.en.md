# Transmitter

🌐 [Русский](README.md) · **English** · [Deutsch](README.de.md) · [中文](README.zh.md)

**Messages, links and files between your own devices — no sign-up, no
third-party servers, end-to-end encrypted.**

Send a link from your phone — a couple of seconds later it's on your computer.
Drop a document into the window at work — it's waiting for you on your phone.
Everything is stored in **your own cloud** (currently Dropbox) and encrypted
right on the device: the cloud only ever sees meaningless bytes.

| | |
|---|---|
| 📱 **Android** | app, including the system “Share” menu |
| 🖥️ **Windows** | app, drag-and-drop files into the window |
| 🌐 **Browser** | https://kernien.github.io/transmitter-web/ — nothing to install |

Version **0.1.0** — the first release.

> **Interface language.** The app's interface is currently in Russian only.
> In this guide, button names are given in English with the label you will
> actually see in the app in brackets, e.g. **New key** («Новый ключ»).

---

## Features

- **Text and links.** Links are detected automatically and open with a single
  tap.
- **Files up to 25 MB** — photos, documents, archives. Use the 📎 button,
  drag files into the window (Windows and browser) or “Share” from any app on
  Android.
- **“Share” both ways (Android).** From your browser, gallery or messenger
  straight into Transmitter — and from Transmitter into any app.
- **Several vaults.** One feed for work, another for home: each has its own
  key, and they never mix.
- **Work with many messages at once.** Select them, then download as a single
  zip archive, share or delete.
- **Delete everywhere.** A deleted message disappears from all devices, along
  with its file in the cloud.
- **No sign-up.** No Transmitter accounts: devices are linked with a QR code.

## Privacy

- **End-to-end AES-256-GCM encryption.** Messages and files are encrypted
  before they are sent and decrypted only on your devices.
- **No server of our own.** Your data lives only in your cloud, in a separate
  `Apps/<app name>` folder. Transmitter cannot see any other files there.
- **The key is both the address and the password.** Any device with a vault
  key can read and write to that vault. Share keys only with your own devices.
- **A lost key cannot be recovered.** As long as the key is on at least one
  device, you can show it again. Remove it everywhere and access to the vault
  is gone.

---

## Installation

### Android

1. Download the APK from [**Releases**](https://github.com/Kernien/Transmitter/releases):
   - `Transmitter-0.1.0-android-arm64.apk` — for most phones from recent
     years;
   - `Transmitter-0.1.0-android-armv7.apk` — for older or budget models, if
     the first one doesn't install.
2. Open the file on your phone. Android will ask to allow installs from this
   source (your browser or file manager) — allow it.

### Windows

1. Download `Transmitter-0.1.0-windows-x64.zip` from [**Releases**](https://github.com/Kernien/Transmitter/releases).
2. Unpack it to a convenient folder (e.g. `C:\Program Files\Transmitter` or
   `Documents\Transmitter`) and run `transmitter.exe`.
3. On first launch Windows may say “Windows protected your PC” — the app has
   no paid code-signing certificate. Click **More info → Run anyway**.

### Browser

Open https://kernien.github.io/transmitter-web/. Keys and the cloud sign-in
are remembered in that browser.

---

## How to use

### 1. First device: create a vault

1. Tap **New key** («Новый ключ»), give it a name (e.g. “Personal”) and choose
   the **Dropbox** cloud → **Create** («Создать»).
2. The key's QR code appears — you can close it; it's always available from
   the ⋮ menu.
3. Tap the new vault → **Sign in to Dropbox** («Войти в Dropbox»). Sign in and
   allow access — the feed opens.

### 2. Other devices: connect the same vault

1. On the first device: ⋮ next to the vault → **Show key / QR**
   («Показать ключ / QR»).
2. On the new device: the QR icon at the top → **Scan QR code**
   («Сканировать QR-код») (phone, or a browser with a camera), or paste the
   key string `TRM1.…` (copy it with **Copy key** — «Скопировать ключ»).
3. Sign in to the **same** Dropbox account — and the feed appears.

### 3. Send

- **Text or a link** — the field at the bottom of the feed and the ➤ button.
- **A file** — 📎 to the left of the field (any text in the field becomes the
  file's caption), or drag files into the window, or on Android:
  **Share → Transmitter** in any app.

New messages appear on your other devices within a few seconds while the feed
is open.

### 4. Work with messages

- **⋮ next to a message:** share, save file, copy text, delete.
- **Tap** a link to open it, tap a file to save it.
- **Long-press** (or **Select** — «Выбрать» — in the ⋮ menu) starts
  selection. Tick several messages and choose at the top: **download** (one
  zip archive with the files and `сообщения.txt` holding the texts),
  **share** or **delete**.
- **⋮ in the feed header → Clear feed** («Очистить ленту») deletes everything
  in this vault on all devices.

### 5. Manage

- **Several vaults:** create another key — it gets its own feed.
- **Clouds:** the ☁ icon on the main screen — sign in to or out of a cloud on
  this device.
- **Remove a vault from a device:** ⋮ next to the vault →
  **Remove from device** («Удалить с устройства»). The data in the cloud and
  on other devices stays.

---

## Troubleshooting

| What happens | What to do |
|---|---|
| The browser doesn't open the Dropbox sign-in window | Allow pop-ups for the site; in Brave, turn off Shields for this address |
| “File larger than 25 MB” | A limit of version 0.1.0: send smaller files or a split archive |
| A message didn't show up on another device | Check your connection and that the same vault is open; the feed refreshes every 5 seconds |
| “Sign in to the cloud again” | ☁ on the main screen → **Sign out** («Выйти») → **Sign in** («Войти») |
| Xiaomi won't install the APK | Allow installs from unknown sources for the app you open the file with |

---

## What's next

- Google Drive and OneDrive, then MEGA;
- device names and new-message notifications;
- an iPhone version;
- viewing photos, audio and video right in the app.

---

<sub>For developers: architecture, building and releasing — see
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) (in Russian).</sub>
