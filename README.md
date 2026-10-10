# Transmitter

Передача сообщений, ссылок и небольших файлов (до 25 МБ) между своими
устройствами: Android, Windows и Web. Без регистрации и без своего сервера:
данные шифруются на устройстве и хранятся в облаке пользователя.

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
├── app/                      Корень приложения, конфиг, фабрика сессий базы
├── core/                     Инфраструктура, не зависит от UI
│   ├── auth/                 OAuth: PKCE, токены с автообновлением,
│   │   └── browsers/         вход на Windows (localhost), Android (ссылка), Web (окно)
│   ├── crypto/               Cipher (интерфейс), AES-GCM, вывод ключей HKDF
│   ├── vault/                VaultKey, кодек QR/строки, хранилище ключей
│   ├── storage/              CloudStorage (интерфейс), адаптеры облаков,
│   │   └── providers/        реализации облаков: dropbox/, …
│   ├── persistence/          Защищённое хранилище строк на устройстве
│   └── utils/
├── domain/                   Модели: Post, Attachment
├── data/                     PostRepository (интерфейс) и его реализация
└── features/                 Экраны, каждый со своим контроллером
    ├── vaults/               Список ключей, создание, импорт, QR
    ├── cloud_connect/        Вход в облако
    └── feed/                 Лента постов и отправка
```

Принципы:

- **Интерфейсы на границах модулей.** `Cipher`, `CloudStorage`,
  `PostRepository`, `SecureKeyValueStore`. Реализацию можно заменить, не трогая
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

Ключи облаков задаются в `config/dev.json` и передаются при запуске:

```powershell
flutter run -d windows --dart-define-from-file=config/dev.json
flutter run            --dart-define-from-file=config/dev.json   # Android-устройство
```

Веб-версия собирается и раздаётся на http://localhost:47820 (этот адрес
прописан в Dropbox), открывать в любом браузере:

```powershell
flutter build web --dart-define-from-file=config/dev.json
dart run tool/serve_web.dart
```

В VS Code те же варианты есть в меню запуска (`.vscode/launch.json`).

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
   - `http://localhost:47820/auth.html` — веб-версия при разработке.

   **Allow public clients (Implicit Grant & PKCE)** должно быть **Allow**.
4. Скопируйте **App key** в `config/dev.json` → `DROPBOX_APP_KEY`.
   App secret не нужен: вход идёт по PKCE.

Пока приложение в статусе Development, войти в него могут до 500 аккаунтов
Dropbox. Для личного использования этого достаточно.

## Статус

| Возможность | Статус |
|---|---|
| Ключи баз, QR, импорт | ✅ |
| Шифрование AES-256-GCM | ✅ |
| Текст и ссылки | ✅ |
| Файлы до 25 МБ | Слой данных готов, нужен UI выбора и сохранения файла |
| Dropbox (вход OAuth с автообновлением токена) | ✅ |
| Google Drive, OneDrive | Запланировано |
| MEGA | Запланировано последним: нет публичного OAuth API |
