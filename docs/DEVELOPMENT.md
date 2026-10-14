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
```

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

### Подключение Dropbox

1. Откройте https://www.dropbox.com/developers/apps → **Create app**:
   - **Scoped access**;
   - **App folder** — приложение видит только свою папку;
   - имя приложения (должно быть уникальным во всём Dropbox).
2. Вкладка **Permissions**: отметьте `files.metadata.read`,
   `files.metadata.write`, `files.content.read`, `files.content.write` →
   **Submit**.
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

Особенности входа:

- **Windows и Android** — вход в браузере, ответ принимает локальный сервер на
  `http://127.0.0.1:47819/` (своя схема адреса на Android Google больше не
  разрешает). На телефоне после входа — кнопка «Вернуться в Transmitter».
  Повторно входить не нужно (refresh token).
- **Веб** — Google выдаёт приложениям без сервера только временный доступ
  (около часа), потом нужно войти снова.

## Выпуск релиза

1. Поднять версию в `pubspec.yaml` (`version: 0.6.0+6` — номер после `+`
   увеличивается с каждым релизом, иначе Android не обновит приложение).
2. Собрать всё в `build/dist`:
   APK, zip и установщик Windows (нужен Inno Setup 6:
   `winget install JRSoftware.InnoSetup`; сценарий — `installer/transmitter.iss`),
   AppImage и tar.gz для Linux (если установлен WSL с Ubuntu-24.04, см.
   «Сборка для Linux»).

   ```powershell
   powershell -File tool/build_release.ps1
   ```

3. Опубликовать веб-версию на GitHub Pages:

   ```powershell
   powershell -File tool/deploy_web.ps1
   ```

4. Тег и GitHub Release с файлами из `build/dist`.

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
| Фото и видео из Галереи (Android, кнопка 🖼; GalleryPicker.kt) | ✅ |
| Dropbox (вход OAuth с автообновлением токена) | ✅ |
| Google Drive (drive.file; на устройствах — вход с refresh token, в вебе — временный) | ✅ (0.3.0) |
| Установщик Windows (Inno Setup: для текущего пользователя, меню «Пуск», удаление через «Параметры») | ✅ (0.4.0) |
| Интерфейс на русском и английском, выбор языка в приложении | ✅ (0.4.0) |
| Версия для Linux (AppImage, tar.gz) | ✅ (0.5.0) |
| Лимит размера файла выбирается при создании ключа (10–100 МБ, хранится в ключе) | ✅ (0.2.0) |
| Имена устройств (подсказка при первом запуске, «· рабочий» в рабочем профиле, смена кнопкой на главном экране) | ✅ (0.2.0) |

## План

Порядок согласован; новые пункты добавляются по договорённости.

1. **Облака:** Google Drive ✅. OneDrive отложен: Microsoft требует
   подписку Azure, в которой отказано. MEGA — последним из облаков: у него
   нет публичного OAuth API, нужен нативный SDK.
2. **Установщик Windows** ✅ (Inno Setup, `installer/transmitter.iss`).
3. **Интерфейс на английском** ✅ — локализация Flutter: `lib/l10n/app_en.arb`
   (шаблон) и `app_ru.arb`, язык — по языку системы (иначе английский).
   Новый язык — новый файл `app_<код>.arb`. Ошибки в core несут код
   (`core/errors/app_error.dart`), текст подставляет интерфейс. Кнопка выбора
   языка в приложении (системный / русский / English).
4. **Версия для Linux** ✅ — проверена в WSL (Ubuntu 24.04) и на Steam Deck:
   AppImage и tar.gz (`tool/build_linux.sh`), ключи — в файле с правами 600,
   вход в облака — через локальный сервер (как на Windows), выбор файла —
   через xdg-desktop-portal. Нет «Поделиться» из системы и сканера QR
   (ключ — вставкой строки). Flatpak — по желанию позже.
5. **Версия для iPhone.** Код Flutter почти весь общий; понадобятся
   нативные части для iOS (приём «Поделиться» — Share Extension, схема
   возврата после входа в облако). Сборка под iOS возможна только на macOS с
   Xcode — либо на своём Mac, либо в облачной сборке (например, GitHub
   Actions с macOS или Codemagic). Для установки на телефон дольше чем на
   7 дней и для App Store нужен Apple Developer Program (платный, $99/год).
6. **Просмотр медиа прямо в приложении** (в самом конце):
   - изображения — миниатюры в ленте и полноэкранный просмотр с масштабом;
   - аудио — встроенный плеер в карточке поста;
   - видео — встроенный плеер (на Windows понадобится отдельный движок,
     например media_kit).

   Файлы до 100 МБ расшифровываются в память целиком, так что отдельная
   потоковая расшифровка не нужна.
