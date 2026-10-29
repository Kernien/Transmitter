# Transmitter: разработка

Описание для пользователей — в [README.md](../README.md). Здесь — как всё
устроено и как собирать.

## Как это работает

1. Пользователь создаёт **ключ базы** — 32 случайных байта. Ключей может быть
   несколько, каждый открывает свою базу постов.
2. Ключ передаётся на другое устройство QR-кодом или строкой `TRM1.…`.
3. Из ключа через HKDF-SHA256 получаются:
   - `vaultId` — имя папки базы в облаке;
   - ключ AES-256-GCM — им шифруются посты и файлы.
4. Каждое устройство само входит в облако (токен хранится только на нём).
   Облако видит только зашифрованные файлы.
5. Пока база открыта, приложение раз в 5 секунд проверяет новые посты.

Раскладка в облаке (внутри папки приложения):

```
<vaultId>/posts/<время>_<id>.post   — зашифрованный пост (JSON)
<vaultId>/files/<id>.bin            — зашифрованный файл
<vaultId>/settings.bin              — настройки базы: название и лимит файла
```

Название базы и лимит размера файла общие для всех её устройств
(`data/vault_settings.dart`). Изменение сначала пишется в `settings.bin`
(JSON `{v, label, m, ts}`, зашифрован ключом базы), потом в ключ на
устройстве. Другие устройства подтягивают его при запуске и после выхода
из ленты базы (`VaultsController.refreshSettings`). Пока файла нет (базу ни
разу не переименовывали), действуют название и лимит из ключа. Без связи
с облаком изменить название или лимит нельзя: иначе устройства разошлись бы.

## Архитектура

Код разбит на слои. Зависимости направлены только сверху вниз:
`features → app → data → core/domain`. Нижние слои ничего не знают о верхних.

```
lib/
├── main.dart                 Точка сборки: создаёт реализации и связывает их
├── app/                      Корень приложения, конфиг, фабрика сессий базы,
│                             локализация (l10n.dart: тексты ошибок, размеры),
│   └── widgets/              общие виджеты (ContentWidth)
├── core/                     Инфраструктура, не зависит от UI
│   ├── auth/                 OAuth: PKCE, токены с автообновлением,
│   │   └── browsers/         вход на Windows (localhost), Android (ссылка), Web (окно)
│   ├── crypto/               Cipher (интерфейс), AES-GCM, вывод ключей HKDF
│   ├── errors/               ErrorCode — коды ошибок для показа пользователю
│   ├── files/                Выбор/сохранение файлов, zip
│   ├── share/                «Поделиться»: приём (Android) и отправка
│   ├── vault/                VaultKey, кодек QR/строки, хранилище ключей
│   ├── storage/              CloudStorage (интерфейс), адаптеры облаков,
│   │   └── providers/        реализации облаков: dropbox/, …
│   ├── persistence/          Защищённое хранилище строк на устройстве
│   └── utils/
├── l10n/                     Тексты интерфейса: app_en.arb (шаблон), app_ru.arb
├── domain/                   Модели: Post, Attachment
├── data/                     PostRepository (интерфейс) и его реализация
└── features/                 Экраны, каждый со своим контроллером
    ├── vaults/               Список ключей, создание, импорт, QR
    ├── cloud_connect/        Вход в облако
    ├── feed/                 Лента постов, отправка, выделение
    └── share_target/         Экран «Отправить в Transmitter»

android/app/src/main/kotlin/…/ShareReceiver.kt — приём «Поделиться» на Android
```

Принципы:

- **Интерфейсы на границах модулей.** `Cipher`, `CloudStorage`,
  `PostRepository`, `SecureKeyValueStore`, `FileTransferService`,
  `IncomingShareSource`, `ShareSender`. Реализацию можно заменить, не трогая
  код, который ею пользуется.
- **Новое облако — один новый класс.** Реализуйте `CloudStorage` и
  `CloudProviderAdapter` в `core/storage/providers/` и добавьте адаптер в
  реестр в `main.dart`. Больше ничего менять не нужно.
- **Контроллеры отдельно от виджетов.** Логика экрана живёт в
  `ChangeNotifier`-контроллере, который тестируется без UI.
- **Тесты на каждый модуль.** Для тестов есть реализации в памяти
  (`InMemoryCloudStorage`, `InMemoryKeyValueStore`), реальное облако не нужно.

## Разработка

```powershell
flutter test        # все тесты: должны проходить перед каждым коммитом
flutter analyze     # статический анализ
```

Шифрование AES-GCM — BoringSSL через пакет `webcrypto`. Для `flutter test`
его библиотеку нужно один раз собрать в `.dart_tool/webcrypto/` (и заново
после `flutter clean`); на Windows для этого и для сборки приложения нужны
CMake из Visual Studio Build Tools и NASM (`winget install NASM.NASM`):

```powershell
$env:Path += ";$env:LOCALAPPDATA\bin\NASM;C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
dart run webcrypto:setup
```

Ключи облаков: публичные — в `config/dev.json` (в git), секретные — в
`config/secrets.json` (не в git; если его нет, создайте файл с `{}`).
Передаются при запуске:

```powershell
flutter run -d windows --dart-define-from-file=config/dev.json --dart-define-from-file=config/secrets.json
flutter run            --dart-define-from-file=config/dev.json --dart-define-from-file=config/secrets.json   # Android
```

В веб-сборку `secrets.json` **не передаётся**: всё, что в неё попадает,
видно в опубликованном JavaScript.

Веб-версия для разработки раздаётся на http://localhost:47820 (этот адрес
прописан в Dropbox):

```powershell
flutter build web --dart-define-from-file=config/dev.json
dart run tool/serve_web.dart
```

В VS Code те же варианты есть в меню запуска (`.vscode/launch.json`).

### Логотип и иконки

Исходники — SVG в `assets/branding/`: `icon.svg` (иконка со скруглёнными
углами), `icon-maskable.svg` (квадрат без скруглений — для веба, форму задаёт
система), `icon-foreground.svg` (знак без фона — передний слой адаптивной
иконки Android и иконки в цвет темы). Цвет — индиго `#3F51B5`. После правки
SVG иконки всех платформ пересобираются одной командой (нужен Microsoft
Edge — им SVG отрисовывается в PNG):

```powershell
powershell -File tool/make_icons.ps1
```

Скрипт вызывает `flutter_launcher_icons` (настройки —
`flutter_launcher_icons.yaml`), потом сам делает скруглённые веб-иконки и
favicon и `app_icon.ico` со всеми размерами 16–256. Linux (AppImage) берёт
`web/icons/Icon-512.png`.

Экран запуска — индиго и белый знак (`splash.svg`, для Android 12+ —
`splash-android12.svg`: система обрезает его кругом). На Android и в вебе
он системный (`flutter_native_splash`, настройки — `flutter_native_splash.yaml`,
пересобирается тем же скриптом): `main()` держит его (`preserve`), пока
загружаются ключи и настройки, и убирает после `runApp` (`remove`). На
Windows и Linux системного экрана нет — сразу показывается такой же
`SplashScreen` (`app/widgets/splash_screen.dart`).

### Сборка для Linux

Linux-версию можно собрать только на Linux — на Windows для этого есть WSL2
(Ubuntu 24.04, пользователь `dev`). Подготовка (один раз):

```powershell
wsl --install -d Ubuntu-24.04      # нужна перезагрузка
```

```bash
sudo apt-get install -y git curl unzip xz-utils zip rsync clang cmake ninja-build \
  pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev libsecret-1-dev \
  libjsoncpp-dev file fuse libfuse2t64
git clone --depth 1 -b <версия Flutter> https://github.com/flutter/flutter.git ~/flutter
```

Сборка AppImage и tar.gz в `build/dist` (тесты прогоняются и под Linux):

```powershell
wsl -d Ubuntu-24.04 --cd /mnt/f/Code/Projects/Transmitter -- bash tool/build_linux.sh
```

Особенности Linux:

- **Ключи и токены** — в `~/.local/share/app.transmitter.transmitter/secure_store.json`
  (папка 700, файл 600), а не в «связке ключей»: Secret Service есть не
  везде (например, в игровом режиме Steam Deck).
- **Выбор файла** (file_picker) работает только через xdg-desktop-portal. Для
  проверки в WSL: `sudo apt-get install xdg-desktop-portal xdg-desktop-portal-gtk`.
- В WSL окна Linux показываются на рабочем столе Windows, но перетаскивание
  файлов из Windows в них не работает — это ограничение WSL.
- Иконка и ярлык — `linux/packaging/`; идентификатор приложения
  `app.transmitter.transmitter` (как на Android).

#### Flatpak

Пакет собирается из того же tar.gz, что и релиз для Linux (Flutter во
Flathub без сети не собрать). Файлы — `linux/flatpak/`: манифест (среда
`org.gnome.Platform` 51), ярлык и карточка магазина (`metainfo.xml`).

```powershell
wsl -d Ubuntu-24.04 -- bash tool/build_flatpak.sh   # после tool/build_linux.sh
wsl -d Ubuntu-24.04 -- flatpak run io.github.kernien.Transmitter
```

Скрипт ставит пакет для текущего пользователя, проверяет карточку
(`appstreamcli`), кладёт в `build/flatpak/` файл-установщик
`Transmitter-<версия>.flatpak` (на другой машине: `flatpak install --user
<файл>`) и манифест для Flathub (`build/flatpak/flathub/`: ссылки на архив
релиза и файлы по тегу `v<версия>` с sha256 — тег должен быть опубликован).
Нужны `flatpak`, `flatpak-builder`, `appstream` (`sudo apt-get install …`).

**Свой репозиторий** — `tool/publish_flatpak.sh`: собирает пакет в ветку
`stable`, подписывает его ключом GPG «Transmitter Flatpak» и добавляет в
репозиторий OSTree в `build/web-deploy/flatpak/repo/` (хранятся две
последние версии); рядом пишет `transmitter.flatpakrepo` и
`io.github.kernien.Transmitter.flatpakref` с ключом. На GitHub Pages
(https://kernien.github.io/transmitter-web/flatpak/) его отправляет
`tool/deploy_web.ps1` вместе с сайтом и папку `flatpak/` при этом не
трогает. Пользователь ставит одной командой или открывает `.flatpakref` в
Discover:

```bash
flatpak install --user https://kernien.github.io/transmitter-web/flatpak/io.github.kernien.Transmitter.flatpakref
```

**Ключ подписи** — в WSL (`gpg`), резервная копия:
`%USERPROFILE%\.transmitter-signing\flatpak-signing-key.asc` (восстановить:
`gpg --import`). Без него новые версии не подписать, а с новым ключом
пользователям придётся подключать репозиторий заново — держите копию.

Особенности песочницы:

- **Идентификатор** во Flatpak — `io.github.kernien.Transmitter` (Flathub
  требует домен или аккаунт владельца). Песочница разрешает занять в D-Bus
  только имя со своим идентификатором, а по нему работает запуск в один
  экземпляр, — поэтому `my_application.cc` берёт идентификатор из
  `FLATPAK_ID`, если он задан. Тот же архив годится и для AppImage.
- **Данные** — в `~/.var/app/io.github.kernien.Transmitter/` (Flatpak
  подменяет `XDG_DATA_HOME`). Ключи из AppImage-версии песочница не видит —
  их добавляют заново.
- **Перетаскивание** приносит обычные пути (`/home/…`), поэтому у пакета
  `--filesystem=home:ro`. Выбор и сохранение файлов — через порталы.
- **«Открыть в другом приложении»**: копия кладётся в кеш приложения, не в
  `/tmp` — у песочницы свой `/tmp`, и портал не открывает файлы оттуда.
- `flatpak-builder` не замечает смену архива, подключённого по пути, —
  скрипт собирает с `--disable-cache`.
- В релизной сборке под Linux `print` никуда не выводится — для отладки в
  песочнице писать журнал в файл (например, в `$XDG_CACHE_HOME`).

### Подключение Dropbox

1. Откройте https://www.dropbox.com/developers/apps → **Create app**:
   - **Scoped access**;
   - **App folder** — приложение видит только свою папку;
   - имя приложения (должно быть уникальным во всём Dropbox).
2. Вкладка **Permissions**: отметьте `files.metadata.read`,
   `files.metadata.write`, `files.content.read`, `files.content.write`, а для
   публичных досок — `sharing.write` и `sharing.read` → **Submit**.
3. Вкладка **Settings → OAuth 2 → Redirect URIs**, добавьте по одному:
   - `http://localhost:47819/dropbox` — Windows;
   - `app.transmitter://oauth/dropbox` — Android;
   - `http://localhost:47820/auth.html` — веб-версия при разработке;
   - `https://kernien.github.io/transmitter-web/auth.html` — опубликованная веб-версия.

   **Allow public clients (Implicit Grant & PKCE)** должно быть **Allow**.
4. Скопируйте **App key** в `config/dev.json` → `DROPBOX_APP_KEY`.
   App secret не нужен: вход идёт по PKCE.

Пока приложение в статусе Development, войти в него могут до 500 аккаунтов
Dropbox. Для личного использования этого достаточно.

### Подключение Google Drive

Доступ `drive.file`: приложение видит только созданные им файлы — папку
**Transmitter** в «Моём диске». Нужен обычный Google-аккаунт, карта не нужна.

1. https://console.cloud.google.com → создайте проект (например, «Transmitter»).
2. **APIs & Services → Library** → найдите **Google Drive API** → **Enable**.
3. **Google Auth Platform** (OAuth consent screen) → **Get started**:
   имя приложения «Transmitter», почта поддержки, тип аудитории **External**,
   контактная почта → создать.
4. **Data Access → Add or remove scopes** → отметьте
   `.../auth/drive.file` → **Update** → **Save**.
5. **Audience → Publish app** (статус **In production**). В тестовом режиме
   Google сбрасывает вход каждые 7 дней. Проверка Google для `drive.file`
   не нужна; при входе будет предупреждение «приложение не проверено» —
   **Дополнительно → Перейти на страницу Transmitter**.
6. **Clients → Create client → Desktop app** (имя «Transmitter Desktop») —
   для Windows и Android. Скопируйте:
   - Client ID → `config/dev.json` → `GOOGLE_DESKTOP_CLIENT_ID`;
   - Client secret → `config/secrets.json` → `GOOGLE_DESKTOP_CLIENT_SECRET`.
7. **Clients → Create client → Web application** (имя «Transmitter Web»):
   - Authorized JavaScript origins: `https://kernien.github.io`,
     `http://localhost:47820`;
   - Authorized redirect URIs:
     `https://kernien.github.io/transmitter-web/auth.html`,
     `http://localhost:47820/auth.html`.

   Client ID → `config/dev.json` → `GOOGLE_WEB_CLIENT_ID`.
8. **APIs & Services → Credentials → Create credentials → API key**
   (имя «Transmitter public read»), **API restrictions → Restrict key →
   Google Drive API**. Ключ → `config/dev.json` → `GOOGLE_API_KEY`. Он не
   секретный: им читатели публичных досок скачивают файлы, открытые
   «всем по ссылке». GitHub Secret Scanning находит его в `main.dart.js`
   веб-версии и присылает письмо «Secrets detected» — предупреждение
   закрывается как **Won't fix** (так сделано 2026-10-15). Если ключом
   начнут злоупотреблять (квота Drive API), создайте новый и замените в
   `config/dev.json`.

Особенности входа:

- **Windows и Android** — вход в браузере, ответ принимает локальный сервер на
  `http://127.0.0.1:47819/` (своя схема адреса на Android Google больше не
  разрешает). На телефоне после входа — кнопка «Вернуться в Transmitter».
  Повторно входить не нужно (refresh token).
- **Веб** — Google выдаёт приложениям без сервера только временный доступ
  (около часа), потом нужно войти снова.

## Выпуск релиза

1. Поднять версию в `pubspec.yaml` (`version: 0.13.0+16` — номер после `+`
   увеличивается с каждым релизом, иначе Android не обновит приложение).
2. Собрать всё в `build/dist`:
   APK, zip и установщик Windows (нужен Inno Setup 6:
   `winget install JRSoftware.InnoSetup`; сценарий — `installer/transmitter.iss`),
   AppImage и tar.gz для Linux (если установлен WSL с Ubuntu-24.04, см.
   «Сборка для Linux»).

   ```powershell
   powershell -File tool/build_release.ps1
   ```

3. Flatpak: файл-установщик (в `build/flatpak/`, приложить к релизу) и
   новая версия в своём репозитории Flatpak (в `build/web-deploy/flatpak/`):

   ```powershell
   wsl -d Ubuntu-24.04 -- bash tool/build_flatpak.sh
   wsl -d Ubuntu-24.04 -- bash tool/publish_flatpak.sh
   ```

4. Опубликовать веб-версию на GitHub Pages — вместе с ней уходит и
   репозиторий Flatpak:

   ```powershell
   powershell -File tool/deploy_web.ps1
   ```

5. Тег и GitHub Release с файлами из `build/dist` и
   `build/flatpak/Transmitter-<версия>.flatpak`: черновик
   (`gh release create --draft`), файлы по одному (`gh release upload`),
   проверка размеров, публикация (`gh release edit --draft=false --latest`).

**Ключ подписи Android** лежит в `%USERPROFILE%\.transmitter-signing\`
(`upload-keystore.jks` и копия `key.properties` с паролем); рабочая копия
`key.properties` — в `android/` (не в git). Без этого ключа новые версии
нельзя установить поверх старых — держите резервную копию.

## Статус

| Возможность | Статус |
|---|---|
| Ключи баз, QR, импорт | ✅ |
| Шифрование AES-256-GCM | ✅ |
| Текст и ссылки | ✅ |
| Файлы до 25 МБ: отправка, сохранение, перетаскивание в окно | ✅ |
| Удаление, очистка ленты, выделение нескольких постов, скачивание zip | ✅ |
| Адаптация под широкие экраны | ✅ |
| «Поделиться» в Transmitter и из него (Android) | ✅ |
| Фото и видео из Галереи (Android, кнопка 🖼; GalleryPicker.kt) | ✅ (0.5.1) |
| Комментарии к записям (добавить, изменить, удалить; файлы `.note` рядом с постом) | ✅ (0.6.0) |
| Публичные доски: доступ на чтение по ключу читателя (Dropbox, Google Drive), «Выделить текст» | ✅ (0.7.0) |
| Публичные доски в MEGA (ссылки на папки); лента читателя очищается, когда доску закрыли | ✅ (0.14.0) |
| Кеш: сессии в памяти, записи и опись доски на устройстве (лента сразу и без сети) | ✅ (0.7.1) |
| Один экземпляр на Windows и Linux: повторный запуск показывает открытое окно | ✅ (0.7.2) |
| Фото в ленте: превью (до 10 МБ сами, больше — по кнопке), просмотр на весь экран, кеш вложений до 10 МБ | ✅ (0.8.0) |
| Положение и размер окна на Windows и Linux; название доски у читателей; понятная ошибка без сети | ✅ (0.8.0) |
| Чтение документов: текстовые файлы (UTF-8/UTF-16/Windows-1251), Markdown с оформлением, .docx | ✅ (0.9.0) |
| Плеер видео и музыки (video_player; Windows — video_player_win; Linux — другим приложением), на весь экран, экран не гаснет | ✅ (0.10.0) |
| Плеер на media_kit (libmpv: .avi, .mkv, .wmv…; Android и Windows), музыка не встаёт на паузу при выключенном экране | ✅ (0.13.0) |
| Шифрование на BoringSSL (webcrypto): файлы из кеша открываются в десятки раз быстрее | ✅ (0.13.0) |
| Тёмные темы редакторов: Dracula, Nord, One Dark, Solarized Dark, Gruvbox, Catppuccin Mocha | ✅ (0.13.0) |
| «Открыть в другом приложении» (Android — FileProvider, ПК — программа по умолчанию) | ✅ (0.10.0) |
| Все открытые файлы на устройстве, лимит 500 МБ–5 ГБ (по умолчанию 1 ГБ), «Место на устройстве» | ✅ (0.10.0) |
| Оформление: как в системе, светлая, тёмная и пресеты «Океан», «Лес», «Закат», «Ночь (чёрная)»; ⚙ «Настройки» (оформление, язык, место) | ✅ (0.11.0) |
| MEGA: свой клиент протокола на Dart (`providers/mega/`), вход по почте и паролю (+2FA), папка «Transmitter», журнал изменений /sc | ✅ (0.12.0) |
| Dropbox (вход OAuth с автообновлением токена) | ✅ |
| Google Drive (drive.file; на устройствах — вход с refresh token, в вебе — временный) | ✅ (0.3.0) |
| Установщик Windows (Inno Setup: для текущего пользователя, меню «Пуск», удаление через «Параметры») | ✅ (0.4.0) |
| Интерфейс на русском и английском, выбор языка в приложении | ✅ (0.4.0) |
| Версия для Linux (AppImage, tar.gz) | ✅ (0.5.0) |
| Лимит размера файла выбирается при создании ключа (10–100 МБ, хранится в ключе) | ✅ (0.2.0) |
| Название и лимит размера файла общие для устройств базы (`settings.bin`), лимит можно изменить: ⋮ → «Размер файлов…» | ✅ (0.15.0) |
| Логотип и иконки (запись, которая ходит по кругу; индиго) для Android (адаптивная, в цвет темы), Windows, Linux и веба — `tool/make_icons.ps1` | ✅ (0.15.0) |
| Экран запуска (индиго и знак): системный на Android (и Android 12+) и в вебе, свой на Windows и Linux | ✅ (0.16.0) |
| Имена устройств (подсказка при первом запуске, «· рабочий» в рабочем профиле, смена кнопкой на главном экране) | ✅ (0.2.0) |

## План

Порядок согласован; новые пункты добавляются по договорённости.
**Принцип:** то, что добавляет новые места для проверки (новые облака,
новые платформы), стоит в конце плана.

### Сделано

- **Облака:** Dropbox, Google Drive ✅. OneDrive не делаем: Microsoft требует
  подписку Azure, в которой отказано; из приложения убран (код `onedrive` занят).
- **Установщик Windows** ✅ (Inno Setup, `installer/transmitter.iss`).
- **Интерфейс на английском** ✅ — локализация Flutter: `lib/l10n/app_en.arb`
  (шаблон) и `app_ru.arb`, язык — по языку системы (иначе английский).
  Новый язык — новый файл `app_<код>.arb`. Ошибки в core несут код
  (`core/errors/app_error.dart`), текст подставляет интерфейс. Кнопка выбора
  языка в приложении (системный / русский / English).
- **Версия для Linux** ✅ — проверена в WSL (Ubuntu 24.04) и на Steam Deck:
  AppImage и tar.gz (`tool/build_linux.sh`), ключи — в файле с правами 600,
  вход в облака — через локальный сервер (как на Windows), выбор файла —
  через xdg-desktop-portal. Нет «Поделиться» из системы и сканера QR
  (ключ — вставкой строки). Flatpak — в плане (п. 5 «Дальше»).
- **Фото и видео из Галереи** ✅ (Android, кнопка 🖼).
- **Комментарии к записям** ✅ — пояснение, которое можно добавить, изменить
  или удалить с любого устройства базы (меню ⋮ у записи).
  - Лежат рядом с постом: `<vaultId>/posts/<время>_<id>~<правка>.note`
    (зашифрованный JSON: id поста, текст, устройство, время правки). Правка —
    новый файл и удаление старого, поэтому лента замечает её по тому же
    списку файлов, что и новые посты, без лишних запросов. Из нескольких
    файлов действует самый свежий. Сами посты не меняются.
  - Старые версии приложения читают только `.post` и комментарии не видят.
- **Публичные доски** ✅ — любую базу можно открыть только для чтения
  (⋮ → «Доступ на чтение…»). Два ключа: владельца (`TRM1.`, всё можно) и
  читателя (`TRM1R.`: смотреть, копировать, скачивать).
  - Облако владельца: `<vaultId>/board/state.bin` — состояние доски
    (`BoardState`, ключом базы; видят все устройства владельца) и
    `<vaultId>/board/<uuid>.board` — опись для читателей: `[версия][подпись
    Ed25519][AES-GCM JSON]` (`BoardManifestCodec`). Файлы вложений не
    копируются — открываются по ссылке как есть (они уже зашифрованы ключом
    базы).
  - Ключ читателя: адрес описи, ключ шифрования базы, открытый ключ подписи
    (зерно — HKDF `board-signing-key` из секрета базы). Секрета базы в нём
    нет, доступа к облаку у читателя нет — изменить ничего нельзя.
  - `BoardPublisher` обновляет опись из `PublishingPostRepository` после
    чтения ленты и изменений (в фоне); пишет только при изменении хеша,
    порядок однозначный, название фиксируется при открытии — устройства
    владельца не спорят. Состояние перечитывается раз в минуту и перед
    записью.
  - Закрыть доступ: опись удаляется (ссылка умирает), ссылки на файлы
    закрываются; повторное открытие — новая опись и новый ключ.
  - Ссылки: `PublicSharing` / `PublicFileReader` (core/storage). Dropbox —
    shared links, право `sharing.write` (старому входу его не хватает →
    `cloudSharingNotAllowed`, кнопка «Войти заново»); прямой адрес — тот же
    путь на `dl.dropboxusercontent.com`. Google Drive — «всем по ссылке»,
    читатель качает `files/<id>?alt=media&key=<GOOGLE_API_KEY>`. Оба облака
    отдают файлы браузеру (CORS) — проверено `tool/check_public_links.dart`.
  - MEGA (0.14.0): ссылка на файл при перезаписи не сохраняется (новый
    узел — новая ссылка), поэтому открывается **папка** с файлом
    (`board/` для описи, `files/` для вложений). Адрес —
    `https://mega.nz/folder/<ph>#<ключ папки>/<имя файла>`
    (`MegaFolderLink`); читатель (`MegaPublicReader`) находит файл в списке
    папки по имени.
    - Общий ключ папки не хранится: HKDF от мастер-ключа аккаунта и
      дескриптора папки (info `transmitter-mega-share-key`), так его знают
      все устройства владельца. Сервер принимает `s2` только без `ok`/`ha`
      (новое хранение ключей MEGA, `^!keys`), а `cr` внутри `s2` пропускает —
      ключи файлов для читателя уходят отдельной командой `k`.
    - Каждая загрузка в открытую папку добавляет `cr` с ключом файла.
      Открытые папки и ссылки берутся из полей `s`/`ph` дерева; события
      `s`/`ph` в `/sc` перезагружают дерево.
    - Закрыть ссылку — `l` с `d: 1` и `s2` с `r: ''`; поэтому
      `BoardPublisher.close()` явно закрывает и ссылку на опись.
    - Проверено на настоящем MEGA: `tool/check_mega_links_test.dart`
      (почта и пароль — в переменных окружения, см. файл).
  - Читатель: `PublicBoardRepository` (подпись проверяется до расшифровки),
    ключи — `ReaderKeyStore`, опрос раз в 30 секунд.

### Дальше

1. **Просмотр медиа прямо в приложении:**
   - изображения ✅ (0.8.0) — превью в ленте и просмотр на весь экран
     (`features/feed/attachment_previews.dart`, `image_viewer_screen.dart`);
   - текстовые файлы ✅ — чтение в приложении ():
     UTF-8/UTF-16/Windows-1251, выделение, моноширинный шрифт, до 512 КБ
     с начала; Markdown — с оформлением (flutter_markdown_plus), .docx —
     текст с заголовками, списками и таблицами ().
     PDF и .doc — не делаем (PDF: +5–8 МБ движка, решено 2026-10-17).
   - аудио и видео ✅ (0.10.0) — встроенный плеер (`media_player_screen.dart`);
     с 0.13.0 — media_kit (libmpv) на Android и Windows. Linux пока
     открывает видео другим приложением: для встроенного плеера нужен
     libmpv-dev при сборке и libmpv внутри AppImage.

   Файлы до 100 МБ расшифровываются в память целиком, так что отдельная
   потоковая расшифровка не нужна.
2. **Смена оформления** ✅ (0.11.0) — пресеты темы и цвета
   (`app/theme_controller.dart`), хранится на устройстве, как язык.
   Своя картинка фона — не делали.
3. **Облако MEGA** ✅ (0.12.0) — вместо нативного SDK свой клиент протокола
   на Dart по открытому megajs (`core/storage/providers/mega/`): работает и в
   вебе. Логин и пароль вводятся в приложении, хранится только сеанс.
   Публичные доски для MEGA ✅ (0.14.0) — через ссылки на папки (см. выше).
4. **Версия для iPhone** — отложена (решено 2026-10-26): нет ни iPhone, ни Mac
   для проверки, а нативные части без устройства пришлось бы писать вслепую.
   На iPhone можно пользоваться веб-версией в Safari. Вернуться, когда
   появится устройство или тот, кто будет тестировать. Что понадобится:
   код Flutter почти весь общий;
   нативные части для iOS (приём «Поделиться» — Share Extension,
   схема возврата после входа в облако). Сборка под iOS возможна только на
   macOS с Xcode — либо на своём Mac, либо в облачной сборке (например,
   GitHub Actions с macOS или Codemagic). Для установки на телефон дольше чем
   на 7 дней и для App Store нужен Apple Developer Program (платный,
   $99/год).
5. **Linux-версия во Flatpak** ✅ (0.17.0) — свой репозиторий на GitHub
   Pages: установка в один клик (`.flatpakref`, на Steam Deck — Discover) и
   автообновления. Проверено на Steam Deck (2026-10-28): вход в облака,
   выбор и сохранение файлов, перетаскивание, «Открыть в другом приложении»,
   один экземпляр. Как устроено — «Flatpak» в «Сборке для Linux».
   - **Во Flathub не подаём** (решено 2026-10-28): правила Flathub
     запрещают ИИ-помощь с упаковкой и заявкой, а манифест не может
     содержать сгенерированного ИИ; код приложения тоже требует раскрытия.
     Если подавать — манифест и заявку владелец делает сам, вручную.
     `tool/build_flatpak.sh` по-прежнему пишет черновик манифеста в
     `build/flatpak/flathub/`, но в этом виде его подавать нельзя.

Идеи от 2026-10-29 (обсуждены, порядок согласован):

6. **Убрать OneDrive** ✅ — из списка облаков («Скоро») и диалога создания
   базы (`CloudProviderId.oneDrive`). В данных пользователей его не было;
   код `onedrive` оставлен занятым.
7. **Имя устройства и облака — в «Настройки».** На главном экране остаются
   ⚙ и «Добавить ключ».
8. **ПИН-код на входе** (на Android — и отпечаток пальца): при запуске и
   после нескольких минут в фоне. Это защита от чужих рук, не шифрование.
   Забыли ПИН — сброс ключей на этом устройстве (данные в облаке остаются,
   ключи — с другого устройства).
9. **Полоска отправки и скачивания** — со скоростью и оставшимся временем.
10. **Базы без шифрования** — выбор при создании базы. Облако становится
    обычной папкой: файлы с настоящими именами (`files/Фото отпуска.jpg`),
    их видно и можно открыть в самом облаке. Как устроено: вторая
    реализация `Cipher` без шифрования (весь код и так работает через этот
    интерфейс), отметка в ключе — новая версия формата ключа (старые версии
    приложения просят обновиться), своя раскладка файлов для таких баз
    (одинаковые имена, переименование); зашифрованные базы не меняются.
    Публичные доски работают (подпись описи остаётся).
11. **Большие файлы без жёсткого лимита.** Сейчас файл целиком
    шифруется в памяти и уходит одним запросом. Нужны: шифрование по
    частям (новая версия формата файла, старые читаются), загрузка по
    частям с докачкой (Dropbox upload sessions, Google resumable upload,
    MEGA и так по частям), скачивание сразу на диск. Вместе с п. 9.
12. **Telegram как хранилище — исследование.** Бот не подходит (загрузка
    до 50 МБ, скачивание до 20 МБ, не видит историю канала без своего
    сервера). Реальный путь — клиент TDLib: вход по номеру телефона,
    «Избранное» или закрытый канал, файлы до 2 ГБ; нативная библиотека на
    каждую платформу, регистрация на my.telegram.org, в вебе почти
    неподъёмно. Объём — как MEGA или больше.

Не делаем: **TeraBox** — нет открытого API для сторонних приложений
(только обратная разработка протокола: хрупко и против их условий).
