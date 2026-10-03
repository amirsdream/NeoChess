<#
.SYNOPSIS
  Exports NeoChess for Windows and assembles dist/NeoChess.

.DESCRIPTION
  Needs Godot 4.7.2 with the matching export templates installed. By default
  the official Stockfish build is bundled next to the exe so the game works
  immediately; pass -NoEngine to ship without it (players then get the
  in-app download).

.PARAMETER Godot
  Path to the Godot console executable. Defaults to $env:GODOT, then "godot"
  on PATH, then .tools/godot in this repository.

.PARAMETER Zip
  Also create dist/NeoChess-windows.zip.

.PARAMETER Version
  Version such as 1.2.0 to stamp into the exe properties. Rewrites
  export_presets.cfg in the working copy, so it is meant for CI.
#>
param(
    [string]$Godot = $env:GODOT,
    [switch]$NoEngine,
    [switch]$Zip,
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root "dist/NeoChess"

if (-not $Godot) {
    $onPath = Get-Command godot -ErrorAction SilentlyContinue
    if ($onPath) { $Godot = $onPath.Source }
}
if (-not $Godot) {
    $local = Get-ChildItem -Path (Join-Path $root ".tools/godot") -Filter "Godot*console.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($local) { $Godot = $local.FullName }
}
if (-not $Godot -or -not (Test-Path $Godot)) {
    throw "Godot was not found. Pass -Godot <path> or set the GODOT environment variable."
}

if (-not $NoEngine) {
    & (Join-Path $PSScriptRoot "fetch_stockfish.ps1")
}

if ($Version) {
    if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "Version must look like 1.2.3." }
    $presets = Join-Path $root "export_presets.cfg"
    $text = [System.IO.File]::ReadAllText($presets)
    $text = $text -replace 'application/file_version="[^"]*"', "application/file_version=`"$Version.0`""
    $text = $text -replace 'application/product_version="[^"]*"', "application/product_version=`"$Version.0`""
    [System.IO.File]::WriteAllText($presets, $text)
}

New-Item -ItemType Directory -Force -Path $out | Out-Null
& $Godot --headless --path $root --import | Out-Null
& $Godot --headless --path $root --export-release "Windows Desktop" (Join-Path $out "NeoChess.exe")
if ($LASTEXITCODE -ne 0) { throw "Godot export failed." }

if (-not $NoEngine) {
    foreach ($name in "stockfish.exe", "Copying.txt", "AUTHORS", "STOCKFISH.txt") {
        Copy-Item -LiteralPath (Join-Path $root "bin/$name") -Destination $out -Force
    }
}

if ($Zip) {
    $archive = Join-Path $root "dist/NeoChess-windows.zip"
    if (Test-Path $archive) { Remove-Item -LiteralPath $archive -Force }
    Compress-Archive -Path $out -DestinationPath $archive
    Write-Host "Created $archive"
}
Write-Host "Built $out"
