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
   `& "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe" /Q /DAppVersion=<версия> /DSourceDir=(Resolve-Path build\windows\x64\runner\Release).Path /DOutputDir=(Resolve-Path build\local-install).Path installer\transmitter.iss`
3. Закрыть работающее приложение (`Get-Process transmitter -ErrorAction SilentlyContinue | Stop-Process`),
   затем `Start-Process "build\local-install\Transmitter-<версия>-windows-setup.exe" -ArgumentList /SILENT,/CLOSEAPPLICATIONS -Wait`.
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

## Linux (Steam Deck)

Steam Deck подключён по сети (`deck@192.168.31.177`). На нём используются две версии:
- **Flatpak** (`io.github.kernien.Transmitter`, ветка `stable`) — режим рабочего стола (Discover, ярлык на рабочем столе).
- **AppImage** (`~/.var/app/AppImage/Transmitter-linux-x86_64.AppImage`) — игровой режим (ярлык в Steam).

Порядок обновления:
1. `wsl -d Ubuntu-24.04 -- bash tool/build_linux.sh` (собирает bundle, tar.gz и AppImage в `build/dist/`).
2. Для Flatpak через репозиторий:
   - `wsl -d Ubuntu-24.04 -- bash tool/publish_flatpak.sh`
   - `powershell -ExecutionPolicy Bypass -File tool/deploy_web.ps1`
   - На Deck: `ssh deck@192.168.31.177 "flatpak update -y io.github.kernien.Transmitter"`
3. Для игрового режима (AppImage):
   - `scp build/dist/Transmitter-<версия>-linux-x86_64.AppImage deck@192.168.31.177:/home/deck/.var/app/AppImage/Transmitter-linux-x86_64.AppImage`
   - `ssh deck@192.168.31.177 "chmod +x /home/deck/.var/app/AppImage/Transmitter-linux-x86_64.AppImage"`

## Релиз

Полная процедура — «Выпуск релиза» в `docs/DEVELOPMENT.md`
(`tool/build_release.ps1`, Flatpak через WSL, `tool/deploy_web.ps1`,
`gh release`).
