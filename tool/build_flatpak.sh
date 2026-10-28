#!/usr/bin/env bash
# Flatpak-пакет Transmitter из архива Linux-версии (build/dist, его делает
# tool/build_linux.sh): сборка, установка для текущего пользователя и проверка
# карточки магазина. Собирается в WSL (Ubuntu) или на Linux.
#
# Из Windows, в папке проекта:
#   wsl -d Ubuntu-24.04 -- bash tool/build_flatpak.sh
# Запуск собранного пакета:
#   wsl -d Ubuntu-24.04 -- flatpak run io.github.kernien.Transmitter
#
# Заодно пишется build/flatpak/flathub/io.github.kernien.Transmitter.yml —
# манифест для Flathub: те же шаги, но файлы берутся из релиза на GitHub
# (тег v<версия> уже должен быть опубликован).
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
APP_ID="io.github.kernien.Transmitter"
WORK="$HOME/.cache/transmitter-flatpak"
REPO="Kernien/Transmitter"

version=$(sed -n 's/^version:[[:space:]]*\([0-9.]*\).*/\1/p' "$SRC/pubspec.yaml")
archive="$SRC/build/dist/Transmitter-$version-linux-x64.tar.gz"
[ -f "$archive" ] || {
  echo "Нет $archive — сначала tool/build_linux.sh" >&2
  exit 1
}
echo "== Transmitter $version — Flatpak"

out="$SRC/build/flatpak"
mkdir -p "$out/flathub"
cp "$archive" "$out/transmitter-linux-x64.tar.gz"

for tool in flatpak flatpak-builder; do
  command -v "$tool" >/dev/null || {
    echo "Нет $tool: sudo apt-get install flatpak flatpak-builder" >&2
    exit 1
  }
done
flatpak remote-add --user --if-not-exists flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo

echo "== Сборка и установка"
mkdir -p "$WORK"
# --disable-cache: архив подключён по пути, и смену его содержимого
# flatpak-builder не замечает — без этого ставится прошлая сборка.
flatpak-builder --user --install --force-clean --disable-cache \
  --install-deps-from=flathub \
  --state-dir="$WORK/state" --repo="$WORK/repo" "$WORK/build" \
  "$SRC/linux/flatpak/$APP_ID.yml"

# Один файл для установки на другой машине (например, Steam Deck):
#   flatpak install --user Transmitter.flatpak
# Среда GNOME при этом докачивается с Flathub.
echo "== Файл-установщик"
flatpak build-bundle \
  --runtime-repo=https://dl.flathub.org/repo/flathub.flatpakrepo \
  "$WORK/repo" "$out/Transmitter-$version.flatpak" "$APP_ID"
echo "   $out/Transmitter-$version.flatpak"

echo "== Проверка карточки (AppStream)"
if command -v appstreamcli >/dev/null; then
  appstreamcli validate --no-net --explain "$SRC/linux/flatpak/$APP_ID.metainfo.xml"
else
  echo "appstreamcli не установлен — пропуск (sudo apt-get install appstream)"
fi

echo "== Манифест для Flathub"
sha() { sha256sum "$1" | cut -d' ' -f1; }
raw="https://raw.githubusercontent.com/$REPO/v$version"
sed \
  -e "s|path: ../../build/flatpak/transmitter-linux-x64.tar.gz|url: https://github.com/$REPO/releases/download/v$version/Transmitter-$version-linux-x64.tar.gz\n        sha256: $(sha "$archive")|" \
  -e "s|path: $APP_ID.desktop|url: $raw/linux/flatpak/$APP_ID.desktop\n        sha256: $(sha "$SRC/linux/flatpak/$APP_ID.desktop")|" \
  -e "s|path: $APP_ID.metainfo.xml|url: $raw/linux/flatpak/$APP_ID.metainfo.xml\n        sha256: $(sha "$SRC/linux/flatpak/$APP_ID.metainfo.xml")|" \
  -e "s|path: ../../web/icons/Icon-512.png|url: $raw/web/icons/Icon-512.png\n        sha256: $(sha "$SRC/web/icons/Icon-512.png")|" \
  "$SRC/linux/flatpak/$APP_ID.yml" > "$out/flathub/$APP_ID.yml"
echo "   $out/flathub/$APP_ID.yml"

echo "== Готово: flatpak run $APP_ID"
