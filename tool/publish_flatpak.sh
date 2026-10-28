#!/usr/bin/env bash
# Свой репозиторий Flatpak Transmitter — на GitHub Pages рядом с веб-версией:
#   https://kernien.github.io/transmitter-web/flatpak/
# Пользователи ставят из него в один клик (.flatpakref) и получают
# обновления через `flatpak update` или Discover на Steam Deck.
#
# Порядок релиза: tool/build_release.ps1 → этот скрипт → tool/deploy_web.ps1
# (он и отправляет папку flatpak/ на GitHub Pages вместе с сайтом):
#   wsl -d Ubuntu-24.04 -- bash tool/publish_flatpak.sh
#
# Подпись — ключ GPG «Transmitter Flatpak» (резервная копия в
# %USERPROFILE%\.transmitter-signing\flatpak-signing-key.asc; восстановить:
# gpg --import <файл>). Потеряется ключ — пользователям придётся подключить
# репозиторий заново.
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
APP_ID="io.github.kernien.Transmitter"
BRANCH="stable"
SITE="https://kernien.github.io/transmitter-web/flatpak"
UID_NAME="Transmitter Flatpak"
WORK="$HOME/.cache/transmitter-flatpak/publish"

version=$(sed -n 's/^version:[[:space:]]*\([0-9.]*\).*/\1/p' "$SRC/pubspec.yaml")
archive="$SRC/build/dist/Transmitter-$version-linux-x64.tar.gz"
deploy="$SRC/build/web-deploy"
[ -f "$archive" ] || { echo "Нет $archive — сначала tool/build_linux.sh" >&2; exit 1; }
[ -d "$deploy/.git" ] || {
  echo "Нет $deploy — один раз запустите tool/deploy_web.ps1" >&2
  exit 1
}
key=$(gpg --with-colons --list-secret-keys "$UID_NAME" 2>/dev/null |
  awk -F: '/^fpr:/ {print $10; exit}')
[ -n "$key" ] || {
  echo "Нет ключа «$UID_NAME»: gpg --import flatpak-signing-key.asc" >&2
  exit 1
}
echo "== Transmitter $version — репозиторий Flatpak (ключ ${key: -16})"

# Репозиторий собирается на диске Linux (на /mnt/… OSTree медленный), а
# потом целиком переносится в папку сайта. Опубликованные версии берутся из
# неё же — так история не зависит от этой машины.
rm -rf "$WORK"
mkdir -p "$WORK" "$SRC/build/flatpak"
cp "$archive" "$SRC/build/flatpak/transmitter-linux-x64.tar.gz"
pub="$deploy/flatpak"
[ -d "$pub/repo" ] && cp -a "$pub/repo" "$WORK/repo"

echo "== Сборка в ветку $BRANCH"
flatpak-builder --force-clean --disable-cache --default-branch="$BRANCH" \
  --gpg-sign="$key" --repo="$WORK/repo" --state-dir="$WORK/state" \
  "$WORK/build" "$SRC/linux/flatpak/$APP_ID.yml"

echo "== Сводка репозитория"
# Две последние версии: можно откатиться на прошлую, а сайт не разрастается.
flatpak build-update-repo --gpg-sign="$key" --generate-static-deltas \
  --prune --prune-depth=2 --title=Transmitter \
  --default-branch="$BRANCH" "$WORK/repo"

echo "== Файлы для подключения"
mkdir -p "$pub"
rsync -a --delete "$WORK/repo/" "$pub/repo/"
gpg_key=$(gpg --export "$key" | base64 -w0)
icon="https://kernien.github.io/transmitter-web/icons/Icon-512.png"
cat > "$pub/transmitter.flatpakrepo" <<EOF
[Flatpak Repo]
Title=Transmitter
Url=$SITE/repo/
Homepage=https://github.com/Kernien/Transmitter
Comment=Links and small files between your own devices
Icon=$icon
GPGKey=$gpg_key
EOF
cat > "$pub/$APP_ID.flatpakref" <<EOF
[Flatpak Ref]
Name=$APP_ID
Branch=$BRANCH
Title=Transmitter
Url=$SITE/repo/
SuggestRemoteName=transmitter
Homepage=https://github.com/Kernien/Transmitter
Icon=$icon
RuntimeRepo=https://dl.flathub.org/repo/flathub.flatpakrepo
IsRuntime=false
GPGKey=$gpg_key
EOF
du -sh "$pub/repo"
echo "== Готово: дальше tool/deploy_web.ps1"
echo "   Установка: flatpak install --user $SITE/$APP_ID.flatpakref"
