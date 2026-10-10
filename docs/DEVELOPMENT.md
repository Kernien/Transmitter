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
│   └── widgets/              общие виджеты (ContentWidth)
├── core/                     Инфраструктура, не зависит от UI
│   ├── auth/                 OAuth: PKCE, токены с автообновлением,
│   │   └── browsers/         вход на Windows (localhost), Android (ссылка), Web (окно)
│   ├── crypto/               Cipher (интерфейс), AES-GCM, вывод ключей HKDF
│   ├── files/                Выбор/сохранение файлов, zip
│   ├── share/                «Поделиться»: приём (Android) и отправка
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

Ключи облаков задаются в `config/dev.json` и передаются при запуске:

```powershell
flutter run -d windows --dart-define-from-file=config/dev.json
flutter run            --dart-define-from-file=config/dev.json   # Android-устройство
```

Веб-версия для разработки раздаётся на http://localhost:47820 (этот адрес
прописан в Dropbox):

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
   - `http://localhost:47820/auth.html` — веб-версия при разработке;
   - `https://kernien.github.io/transmitter-web/auth.html` — опубликованная веб-версия.

   **Allow public clients (Implicit Grant & PKCE)** должно быть **Allow**.
4. Скопируйте **App key** в `config/dev.json` → `DROPBOX_APP_KEY`.
   App secret не нужен: вход идёт по PKCE.

Пока приложение в статусе Development, войти в него могут до 500 аккаунтов
Dropbox. Для личного использования этого достаточно.

## Выпуск релиза

1. Поднять версию в `pubspec.yaml` (`version: 0.3.0+3` — номер после `+`
   увеличивается с каждым релизом, иначе Android не обновит приложение).
2. Собрать всё в `build/dist`:

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
| Dropbox (вход OAuth с автообновлением токена) | ✅ |
| Лимит размера файла выбирается при создании ключа (10–100 МБ, хранится в ключе) | ✅ (0.2.0) |
| Имена устройств (подсказка при первом запуске, «· рабочий» в рабочем профиле, смена кнопкой на главном экране) | ✅ (0.2.0) |

## План

Порядок согласован; новые пункты добавляются по договорённости.



1. **Облака:** Google Drive, OneDrive. MEGA — последним из облаков: у него
   нет публичного OAuth API, нужен нативный SDK.
2. **Улучшения:** уведомления о новых сообщениях, удобная установка на Windows.
3. **Версия для iPhone.** Код Flutter почти весь общий; понадобятся
   нативные части для iOS (приём «Поделиться» — Share Extension, схема
   возврата после входа в облако). Сборка под iOS возможна только на macOS с
   Xcode — либо на своём Mac, либо в облачной сборке (например, GitHub
   Actions с macOS или Codemagic). Для установки на телефон дольше чем на
   7 дней и для App Store нужен Apple Developer Program (платный, $99/год).
4. **Просмотр медиа прямо в приложении** (в самом конце):
   - изображения — миниатюры в ленте и полноэкранный просмотр с масштабом;
   - аудио — встроенный плеер в карточке поста;
   - видео — встроенный плеер (на Windows понадобится отдельный движок,
     например media_kit).

   Файлы до 25 МБ расшифровываются в память целиком, так что отдельная
   потоковая расшифровка не нужна.
