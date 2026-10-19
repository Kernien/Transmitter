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
# Секреты (config/secrets.json) не в git; если файла нет — создаём пустой.
if (-not (Test-Path config/secrets.json)) { Set-Content config/secrets.json '{}' -Encoding ascii }
$define = @('--dart-define-from-file=config/dev.json', '--dart-define-from-file=config/secrets.json')

Invoke-Step 'Тесты' { flutter test }
Invoke-Step 'Android' { flutter build apk --release --split-per-abi @define }
# Сборка Windows с нуля: при повторной сборке Flutter может оставить старый
# урезанный шрифт иконок, и новые значки не отображаются. Шрифт кешируется
# и в .dart_tool/flutter_build — чистим оба места.
foreach ($dir in 'build/windows', '.dart_tool/flutter_build') {
  if (Test-Path $dir) { Remove-Item -Recurse -Force $dir }
}
Invoke-Step 'Windows' { flutter build windows --release @define }

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

# Установщик (Inno Setup 6): installer/transmitter.iss.
$iscc = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($iscc) {
    $release = (Resolve-Path 'build/windows/x64/runner/Release').Path
    $distFull = (Resolve-Path $dist).Path
    Invoke-Step 'Установщик Windows' {
        & $iscc /Q "/DAppVersion=$version" "/DSourceDir=$release" "/DOutputDir=$distFull" installer/transmitter.iss
    }
} else {
    Write-Warning 'Inno Setup 6 не найден — установщик не собран (winget install JRSoftware.InnoSetup)'
}
# Linux-версия собирается в WSL (Ubuntu-24.04), см. docs/DEVELOPMENT.md.
$env:WSL_UTF8 = '1'
if ((wsl.exe -l -q 2>$null) -match 'Ubuntu-24.04') {
    $project = (Resolve-Path '.').Path
    $wslProject = '/mnt/' + $project.Substring(0, 1).ToLower() + ($project.Substring(2) -replace '\\', '/')
    Invoke-Step 'Linux' { wsl.exe -d Ubuntu-24.04 --cd $wslProject -- bash tool/build_linux.sh }
} else {
    Write-Warning 'WSL с Ubuntu-24.04 не найден — Linux-версия не собрана'
}
Write-Host "Готово: $dist" -ForegroundColor Green
Get-ChildItem $dist | Select-Object Name, @{ n = 'МБ'; e = { [math]::Round($_.Length / 1MB, 1) } }
