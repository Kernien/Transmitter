#!/usr/bin/env bash
# Сборка Linux-версии: AppImage (один файл, запускается без установки, в том
# числе на Steam Deck) и tar.gz. Собирается в WSL (Ubuntu) или на Linux.
#
# Из Windows, в папке проекта:
#   wsl -d Ubuntu-24.04 -- bash tool/build_linux.sh
#
# Проект копируется в ~/transmitter-build: сборка с диска Windows (/mnt/...)
# в разы медленнее. Результат — в build/dist исходной папки.
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$HOME/transmitter-build"
FLUTTER="${FLUTTER:-$HOME/flutter/bin/flutter}"
APP_ID="app.transmitter.transmitter"
APPIMAGETOOL="$HOME/.cache/transmitter/appimagetool-x86_64.AppImage"
RUNTIME="$HOME/.cache/transmitter/runtime-x86_64"

version=$(sed -n 's/^version:[[:space:]]*\([0-9.]*\).*/\1/p' "$SRC/pubspec.yaml")
echo "== Transmitter $version для Linux"

mkdir -p "$WORK"
rsync -a --delete \
  --exclude build/ --exclude .dart_tool/ --exclude .git/ \
  --exclude android/ --exclude windows/ --exclude installer/ \
  "$SRC/" "$WORK/"
cd "$WORK"
# Секреты (config/secrets.json) не в git; если файла нет — пустой.
[ -f config/secrets.json ] || echo '{}' > config/secrets.json

echo "== Тесты"
"$FLUTTER" pub get >/dev/null
# BoringSSL (пакет webcrypto) для тестов: собирается один раз в .dart_tool.
[ -f .dart_tool/webcrypto/libwebcrypto.so ] ||
  "$(dirname "$FLUTTER")/dart" run webcrypto:setup
"$FLUTTER" test

echo "== Сборка"
rm -rf build/linux
"$FLUTTER" build linux --release \
  --no-tree-shake-icons \
  --dart-define-from-file=config/dev.json \
  --dart-define-from-file=config/secrets.json
bundle="build/linux/x64/release/bundle"

dist="$SRC/build/dist"
mkdir -p "$dist"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

echo "== tar.gz"
cp -r "$bundle" "$stage/Transmitter"
tar -C "$stage" -czf "$dist/Transmitter-$version-linux-x64.tar.gz" Transmitter

echo "== AppImage"
appdir="$stage/Transmitter.AppDir"
cp -r "$bundle" "$appdir"
cp linux/packaging/$APP_ID.desktop "$appdir/$APP_ID.desktop"
cp web/icons/Icon-512.png "$appdir/$APP_ID.png"
cat > "$appdir/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"

if [ "${1:-}" = "--update" ] || [ "${1:-}" = "-u" ]; then
  if [ -z "${APPIMAGE:-}" ]; then
    echo "Ошибка: запуск --update поддерживается только из упакованного AppImage." >&2
    exit 1
  fi
  echo "== Проверка обновлений Transmitter..."
  LATEST_JSON=$(curl -fsSL "https://api.github.com/repos/Kernien/Transmitter/releases/latest" 2>/dev/null || true)
  if [ -z "$LATEST_JSON" ]; then
    echo "Не удалось связаться с GitHub Releases. Проверьте подключение к интернету." >&2
    exit 1
  fi
  TAG=$(echo "$LATEST_JSON" | grep -Po '"tag_name":\s*"\K[^"]+' || true)
  DOWNLOAD_URL=$(echo "$LATEST_JSON" | grep -Po '"browser_download_url":\s*"\K[^"]*linux-x86_64\.AppImage' | head -n1 || true)
  if [ -z "$DOWNLOAD_URL" ]; then
    echo "Файл обновления не найден в релизе $TAG." >&2
    exit 1
  fi
  echo "Найдена актуальная версия: $TAG"
  TMP_FILE="${APPIMAGE}.part"
  echo "Загрузка обновления из $DOWNLOAD_URL..."
  if curl -fSL --progress-bar -o "$TMP_FILE" "$DOWNLOAD_URL"; then
    chmod +x "$TMP_FILE"
    mv -f "$TMP_FILE" "$APPIMAGE"
    echo "== Transmitter успешно обновлён до версии $TAG!"
    exit 0
  else
    rm -f "$TMP_FILE"
    echo "Ошибка при скачивании обновления." >&2
    exit 1
  fi
fi

exec "$HERE/transmitter" "$@"
EOF
chmod +x "$appdir/AppRun"

if [ ! -x "$APPIMAGETOOL" ]; then
  mkdir -p "$(dirname "$APPIMAGETOOL")"
  curl -fsSL -o "$APPIMAGETOOL" \
    https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
  chmod +x "$APPIMAGETOOL"
fi
# Runtime AppImage тоже держим в кеше: иначе appimagetool скачивает его
# при каждой сборке и падает, если GitHub не ответил.
if [ ! -s "$RUNTIME" ]; then
  curl -fsSL --retry 5 --retry-all-errors -o "$RUNTIME.part" \
    https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-x86_64
  mv "$RUNTIME.part" "$RUNTIME"
fi
out="$dist/Transmitter-$version-linux-x86_64.AppImage"
UPDATE_INFO="gh-releases-zsync|Kernien|Transmitter|latest|Transmitter-*-linux-x86_64.AppImage.zsync"
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$APPIMAGETOOL" --no-appstream \
  -u "$UPDATE_INFO" \
  --runtime-file "$RUNTIME" "$appdir" "$out" >/dev/null
chmod +x "$out"

echo "== Готово: $dist"
ls -lh "$dist" | grep linux
