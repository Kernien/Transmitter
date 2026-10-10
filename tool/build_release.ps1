# Собирает релиз в build/dist: APK для Android (arm64, armv7) и zip для Windows.
# Перед сборкой прогоняет тесты. Версия берётся из pubspec.yaml.
#   powershell -File tool/build_release.ps1
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot)

function Invoke-Step([string]$Title, [scriptblock]$Command) {
    Write-Host "== $Title" -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE) { throw "Шаг «$Title» завершился с ошибкой" }
}

$version = (Select-String -Path pubspec.yaml -Pattern '^version:\s*([0-9.]+)').Matches[0].Groups[1].Value
if (-not (Test-Path android/key.properties)) {
    throw 'Нет android/key.properties: релиз нельзя подписать (см. docs/DEVELOPMENT.md)'
}
$define = '--dart-define-from-file=config/dev.json'

Invoke-Step 'Тесты' { flutter test }
Invoke-Step 'Android' { flutter build apk --release --split-per-abi $define }
# Сборка Windows с нуля: при повторной сборке Flutter может оставить старый
# урезанный шрифт иконок, и новые значки не отображаются.
if (Test-Path 'build/windows') { Remove-Item -Recurse -Force 'build/windows' }
Invoke-Step 'Windows' { flutter build windows --release $define }

$dist = 'build/dist'
if (Test-Path $dist) { Remove-Item -Recurse -Force $dist }
New-Item -ItemType Directory $dist | Out-Null

$apks = 'build/app/outputs/flutter-apk'
Copy-Item "$apks/app-arm64-v8a-release.apk" "$dist/Transmitter-$version-android-arm64.apk"
Copy-Item "$apks/app-armeabi-v7a-release.apk" "$dist/Transmitter-$version-android-armv7.apk"

# В архиве — папка Transmitter, чтобы при распаковке файлы не рассыпались.
$stage = Join-Path $env:TEMP "transmitter-release"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
Copy-Item -Recurse 'build/windows/x64/runner/Release' "$stage/Transmitter"
Compress-Archive -Path "$stage/Transmitter" -DestinationPath "$dist/Transmitter-$version-windows-x64.zip"
Remove-Item -Recurse -Force $stage

Write-Host "Готово: $dist" -ForegroundColor Green
Get-ChildItem $dist | Select-Object Name, @{ n = 'МБ'; e = { [math]::Round($_.Length / 1MB, 1) } }
