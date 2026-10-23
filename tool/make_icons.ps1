# Пересобирает иконки приложения из SVG в assets/branding:
#   1. SVG → PNG 1024×1024 (Microsoft Edge без окна);
#   2. Android (адаптивная + обычная), веб и Windows — flutter_launcher_icons;
#   3. веб: обычные иконки и favicon — со скруглёнными углами (генератор
#      берёт одну картинку на всё, а квадратная нужна только maskable);
#   4. Windows: .ico со всеми размерами 16–256 (генератор кладёт один 256).
# Linux берёт web/icons/Icon-512.png (tool/build_linux.sh).
#   powershell -File tool/make_icons.ps1
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot)
Add-Type -AssemblyName System.Drawing

$branding = (Resolve-Path 'assets/branding').Path
$edge = @(
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { throw 'Нужен Microsoft Edge: им SVG отрисовывается в PNG' }

Write-Host '== SVG → PNG' -ForegroundColor Cyan
foreach ($name in 'icon', 'icon-maskable', 'icon-foreground') {
    $png = Join-Path $branding "$name.png"
    $url = 'file:///' + ($branding -replace '\\', '/') + "/$name.svg"
    $edgeArgs = @('--headless=new', '--disable-gpu', '--hide-scrollbars',
        '--force-device-scale-factor=1', '--default-background-color=00000000',
        "--screenshot=$png", '--window-size=1024,1024', $url)
    $p = Start-Process -FilePath $edge -ArgumentList $edgeArgs -Wait -PassThru -WindowStyle Hidden
    if ($p.ExitCode) { throw "Не удалось отрисовать $name.svg" }
}

Write-Host '== flutter_launcher_icons' -ForegroundColor Cyan
dart run flutter_launcher_icons
if ($LASTEXITCODE) { throw 'flutter_launcher_icons завершился с ошибкой' }

# Картинка size×size из большой PNG — с качественным уменьшением.
function Resize-Png([string]$Source, [int]$Size) {
    $image = [System.Drawing.Image]::FromFile($Source)
    try {
        $bitmap = New-Object System.Drawing.Bitmap $Size, $Size
        $g = [System.Drawing.Graphics]::FromImage($bitmap)
        $g.InterpolationMode = 'HighQualityBicubic'
        $g.SmoothingMode = 'HighQuality'
        $g.PixelOffsetMode = 'HighQuality'
        $g.CompositingQuality = 'HighQuality'
        $g.Clear([System.Drawing.Color]::Transparent)
        $g.DrawImage($image, 0, 0, $Size, $Size)
        $g.Dispose()
        $stream = New-Object System.IO.MemoryStream
        $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
        $bitmap.Dispose()
        return , $stream.ToArray()
    } finally {
        $image.Dispose()
    }
}

Write-Host '== Веб: скруглённые иконки' -ForegroundColor Cyan
$icon = Join-Path $branding 'icon.png'
foreach ($target in @(
        @{ Path = 'web/icons/Icon-192.png'; Size = 192 },
        @{ Path = 'web/icons/Icon-512.png'; Size = 512 },
        @{ Path = 'web/favicon.png'; Size = 32 })) {
    [System.IO.File]::WriteAllBytes(
        (Join-Path (Get-Location) $target.Path), (Resize-Png $icon $target.Size))
}

Write-Host '== Windows: app_icon.ico (16–256)' -ForegroundColor Cyan
$sizes = 16, 24, 32, 48, 64, 128, 256
$images = foreach ($size in $sizes) { , (Resize-Png $icon $size) }
$ico = New-Object System.IO.MemoryStream
$writer = New-Object System.IO.BinaryWriter $ico
# ICONDIR, затем по записи ICONDIRENTRY на размер; картинки — PNG.
$writer.Write([UInt16]0); $writer.Write([UInt16]1); $writer.Write([UInt16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $dimension = if ($sizes[$i] -ge 256) { 0 } else { $sizes[$i] }
    $writer.Write([Byte]$dimension); $writer.Write([Byte]$dimension)
    $writer.Write([Byte]0); $writer.Write([Byte]0)
    $writer.Write([UInt16]1); $writer.Write([UInt16]32)
    $writer.Write([UInt32]$images[$i].Length); $writer.Write([UInt32]$offset)
    $offset += $images[$i].Length
}
foreach ($bytes in $images) { $writer.Write($bytes) }
$writer.Flush()
[System.IO.File]::WriteAllBytes(
    (Join-Path (Get-Location) 'windows/runner/resources/app_icon.ico'), $ico.ToArray())

Write-Host 'Готово' -ForegroundColor Green
