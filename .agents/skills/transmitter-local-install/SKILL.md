---
name: transmitter-local-install
description: >-
  Как собрать и поставить актуальную версию Transmitter на Windows этого
  компьютера и на Android-телефон по USB. Использовать после любых изменений
  в приложении, когда владелец просит «установи новую версию» или по правилу
  из AGENTS.md.
---

# Установка актуальной сборки Transmitter

Все команды — из корня проекта, с `BypassSandbox: true` (анализатор Dart и
запись в `.git`/`build` в песочнице падают с «Отказано в доступе»).
Перед установкой: `flutter analyze` и `flutter test` без ошибок.
Flutter: `C:\dev\flutter\bin`. Скрипты `.ps1` запускать с
`powershell -ExecutionPolicy Bypass -File …`.

## Windows

1. `flutter build windows --release --dart-define-from-file=config/dev.json --dart-define-from-file=config/secrets.json`
   (в PATH — `%LOCALAPPDATA%\bin\NASM`).
2. Установщик из свежей сборки (Inno Setup 6, версия из `pubspec.yaml`):
   `ISCC.exe /Q /DAppVersion=<версия> /DSourceDir=<build\windows\x64\runner\Release> /DOutputDir=<build\local-install> installer\transmitter.iss`
3. Закрыть работающее приложение (`Get-Process transmitter | Stop-Process`),
   затем `Start-Process <setup.exe> -ArgumentList /SILENT,/CLOSEAPPLICATIONS -Wait`.
4. Проверить: время `data\app.so` в `%LOCALAPPDATA%\Programs\Transmitter`
   совпадает со сборкой. Время `transmitter.exe` не меняется при правках на
   Dart — по нему версию не проверять.

Не запускать `build\...\transmitter.exe` вместо установки: у приложения один
экземпляр, и если уже открыта установленная старая версия, запуск лишь
покажет её окно.

## Android (телефон по USB)

1. `flutter build apk --release --split-per-abi --dart-define-from-file=config/dev.json --dart-define-from-file=config/secrets.json`
2. `& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" install -r build\app\outputs\flutter-apk\app-arm64-v8a-release.apk`
3. Откат на старую версию невозможен (`INSTALL_FAILED_VERSION_DOWNGRADE`
   из-за номера после `+` в `pubspec.yaml`): собирать прошлый коммит с тем же
   или большим номером.

## Релиз

Полная процедура — «Выпуск релиза» в `docs/DEVELOPMENT.md`
(`tool/build_release.ps1`, Flatpak через WSL, `tool/deploy_web.ps1`,
`gh release`).
