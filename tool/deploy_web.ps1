# Публикует веб-версию на GitHub Pages: https://kernien.github.io/transmitter-web/
# В публичный репозиторий Kernien/transmitter-web попадают только собранные
# файлы сайта и README — исходный код остаётся в приватном репозитории.
#   powershell -File tool/deploy_web.ps1
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot)

$repo = 'https://github.com/Kernien/transmitter-web.git'
$deploy = 'build/web-deploy'
$version = (Select-String -Path pubspec.yaml -Pattern '^version:\s*([0-9.]+)').Matches[0].Groups[1].Value

Write-Host '== Сборка веб-версии' -ForegroundColor Cyan
flutter build web --release --no-wasm-dry-run --base-href /transmitter-web/ --dart-define-from-file=config/dev.json
if ($LASTEXITCODE) { throw 'Сборка не удалась' }

if (-not (Test-Path "$deploy/.git")) {
    git clone --quiet $repo $deploy
    if ($LASTEXITCODE) { throw 'Не удалось клонировать репозиторий' }
}
# Автор коммитов — тот же, что в основном репозитории.
git -C $deploy config user.name (git config user.name)
git -C $deploy config user.email (git config user.email)
git -C $deploy checkout --quiet -B main

Get-ChildItem $deploy -Force | Where-Object Name -ne '.git' | Remove-Item -Recurse -Force
Copy-Item -Recurse 'build/web/*' $deploy
New-Item -ItemType File "$deploy/.nojekyll" | Out-Null  # GitHub Pages: отдавать файлы как есть
Copy-Item LICENSE "$deploy/LICENSE"  # собранная программа распространяется под GPL-3.0
# Описание на всех языках; ссылки на документацию разработчика ведут в
# основной репозиторий, потому что в публичный она не копируется.
$deployFull = (Resolve-Path $deploy).Path  # методы .NET не знают текущую папку PowerShell
foreach ($readme in Get-ChildItem 'README*.md') {
    $text = [IO.File]::ReadAllText($readme.FullName, [Text.Encoding]::UTF8)
    $text = $text.Replace('](docs/DEVELOPMENT.md)', '](https://github.com/Kernien/Transmitter/blob/main/docs/DEVELOPMENT.md)')
    [IO.File]::WriteAllText((Join-Path $deployFull $readme.Name), $text, (New-Object Text.UTF8Encoding($false)))
}

git -C $deploy add -A
git -C $deploy commit --quiet -m "Веб-версия $version"
if ($LASTEXITCODE) { Write-Host 'Изменений нет'; return }
git -C $deploy push --quiet -u origin main
if ($LASTEXITCODE) { throw 'Не удалось отправить изменения' }
Write-Host 'Опубликовано: https://kernien.github.io/transmitter-web/' -ForegroundColor Green
