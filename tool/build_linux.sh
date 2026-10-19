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
"$FLUTTER" test

echo "== Сборка"
rm -rf build/linux
"$FLUTTER" build linux --release \
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
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$APPIMAGETOOL" --no-appstream \
  --runtime-file "$RUNTIME" "$appdir" "$out" >/dev/null
chmod +x "$out"

echo "== Готово: $dist"
ls -lh "$dist" | grep linux
