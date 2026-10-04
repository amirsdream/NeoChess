<#
.SYNOPSIS
  Exports NeoChess and assembles dist/NeoChess for Windows or Linux.

.DESCRIPTION
  Needs Godot 4.7.2 with the matching export templates installed. By default
  the official Stockfish build is bundled next to the binary so the game works
  immediately; pass -NoEngine to ship without it (players then get the
  in-app download).

.PARAMETER Godot
  Path to the Godot console executable. Defaults to $env:GODOT, then "godot"
  on PATH, then .tools/godot in this repository.

.PARAMETER Target
  Windows or Linux. Defaults to the host OS.

.PARAMETER Zip
  Also create dist/NeoChess-windows.zip or dist/NeoChess-linux.zip.

.PARAMETER Version
  Version such as 1.2.0 to stamp into Windows exe properties. Rewrites
  export_presets.cfg in the working copy, so it is meant for CI.
#>
param(
    [string]$Godot = $env:GODOT,
    [ValidateSet("Auto", "Windows", "Linux")]
    [string]$Target = "Auto",
    [switch]$NoEngine,
    [switch]$Zip,
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root "dist/NeoChess"

function Get-HostTarget {
    if ($IsWindows -eq $true) { return "Windows" }
    if ($IsLinux -eq $true) { return "Linux" }
    if ($env:OS -match "Windows") { return "Windows" }
    return "Linux"
}

if ($Target -eq "Auto") { $Target = Get-HostTarget }
$forWindows = $Target -eq "Windows"

if (-not $Godot) {
    $onPath = Get-Command godot -ErrorAction SilentlyContinue
    if ($onPath) { $Godot = $onPath.Source }
}
if (-not $Godot) {
    $tools = Join-Path $root ".tools/godot"
    if ($forWindows) {
        $local = Get-ChildItem -Path $tools -Filter "Godot*console.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    } else {
        $local = Get-ChildItem -Path $tools -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "Godot*_linux*" -and $_.Name -notlike "*.zip" } |
            Select-Object -First 1
    }
    if ($local) { $Godot = $local.FullName }
}
if (-not $Godot -or -not (Test-Path $Godot)) {
    throw "Godot was not found. Pass -Godot <path> or set the GODOT environment variable."
}

if (-not $NoEngine) {
    & (Join-Path $PSScriptRoot "fetch_stockfish.ps1") -Target $Target
}

if ($Version) {
    if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "Version must look like 1.2.3." }
    if ($forWindows) {
        $presets = Join-Path $root "export_presets.cfg"
        $text = [System.IO.File]::ReadAllText($presets)
        $text = $text -replace 'application/file_version="[^"]*"', "application/file_version=`"$Version.0`""
        $text = $text -replace 'application/product_version="[^"]*"', "application/product_version=`"$Version.0`""
        [System.IO.File]::WriteAllText($presets, $text)
    }
}

if (Test-Path $out) { Remove-Item -LiteralPath $out -Recurse -Force }
New-Item -ItemType Directory -Force -Path $out | Out-Null
& $Godot --headless --path $root --import | Out-Null

if ($forWindows) {
    $preset = "Windows Desktop"
    $binary = Join-Path $out "NeoChess.exe"
    $engineName = "stockfish.exe"
} else {
    $preset = "Linux Desktop"
    $binary = Join-Path $out "NeoChess.x86_64"
    $engineName = "stockfish"
}

& $Godot --headless --path $root --export-release $preset $binary
if ($LASTEXITCODE -ne 0) { throw "Godot export failed." }
if (-not (Test-Path $binary)) { throw "Export did not create $binary." }
if (-not $forWindows) {
    & chmod +x $binary
    if ($LASTEXITCODE -ne 0) { throw "Failed to mark $binary executable." }
}

if (-not $NoEngine) {
    foreach ($name in $engineName, "Copying.txt", "AUTHORS", "STOCKFISH.txt") {
        Copy-Item -LiteralPath (Join-Path $root "bin/$name") -Destination $out -Force
    }
    if (-not $forWindows) {
        & chmod +x (Join-Path $out $engineName)
        if ($LASTEXITCODE -ne 0) { throw "Failed to mark bundled Stockfish executable." }
    }
}

if ($Zip) {
    $slug = if ($forWindows) { "windows" } else { "linux" }
    $archive = Join-Path $root "dist/NeoChess-$slug.zip"
    if (Test-Path $archive) { Remove-Item -LiteralPath $archive -Force }
    if ($forWindows) {
        Compress-Archive -Path $out -DestinationPath $archive
    } else {
        Push-Location (Join-Path $root "dist")
        try {
            & zip -r (Split-Path $archive -Leaf) "NeoChess"
            if ($LASTEXITCODE -ne 0) { throw "zip failed." }
        } finally {
            Pop-Location
        }
    }
    Write-Host "Created $archive"
}
Write-Host "Built $out"
