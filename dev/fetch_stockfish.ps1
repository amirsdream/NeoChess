<#
.SYNOPSIS
  Downloads the official Stockfish release into bin/ for development and for
  building a release that ships the engine.

  The engine is GPLv3 and is deliberately not stored in this repository.
#>
param(
    [string]$Version = "19",
    [ValidateSet("Auto", "Windows", "Linux")]
    [string]$Target = "Auto",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$bin = Join-Path $root "bin"

function Get-HostTarget {
    if ($IsWindows -eq $true) { return "Windows" }
    if ($IsLinux -eq $true) { return "Linux" }
    if ($env:OS -match "Windows") { return "Windows" }
    return "Linux"
}

if ($Target -eq "Auto") { $Target = Get-HostTarget }

$forWindows = $Target -eq "Windows"
$exeName = if ($forWindows) { "stockfish.exe" } else { "stockfish" }
$target = Join-Path $bin $exeName

if ((Test-Path $target) -and -not $Force) {
    Write-Host "bin/$exeName already exists. Use -Force to download it again."
    exit 0
}

if ($forWindows) {
    $asset = "stockfish-windows-x86-64-universal.zip"
    $label = "Universal Windows x86-64"
} else {
    $asset = "stockfish-linux-x86-64-universal.tar.gz"
    $label = "Universal Linux x86-64"
}

$url = "https://github.com/official-stockfish/Stockfish/releases/download/sf_$Version/$asset"
$archive = Join-Path ([System.IO.Path]::GetTempPath()) "neochess-$asset"
$extract = Join-Path ([System.IO.Path]::GetTempPath()) "neochess-stockfish-$Version-$Target"

Write-Host "Downloading $url"
$ProgressPreference = "SilentlyContinue"
Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing

if (Test-Path $extract) { Remove-Item -LiteralPath $extract -Recurse -Force }
New-Item -ItemType Directory -Force -Path $extract | Out-Null

if ($asset.EndsWith(".zip")) {
    Expand-Archive -LiteralPath $archive -DestinationPath $extract -Force
} else {
    & tar -xzf $archive -C $extract
    if ($LASTEXITCODE -ne 0) { throw "Failed to extract $asset." }
}

if ($forWindows) {
    $exe = Get-ChildItem -Path $extract -Recurse -Filter "stockfish*.exe" | Select-Object -First 1
} else {
    $exe = Get-ChildItem -Path $extract -Recurse -File |
        Where-Object { $_.Name -like "stockfish*" -and $_.Name -notlike "*.*" } |
        Select-Object -First 1
}
if (-not $exe) { throw "No Stockfish executable found in the archive." }

New-Item -ItemType Directory -Force -Path $bin | Out-Null
Copy-Item -LiteralPath $exe.FullName -Destination $target -Force
if (-not $forWindows) {
    & chmod +x $target
    if ($LASTEXITCODE -ne 0) { throw "Failed to mark $target executable." }
}
foreach ($name in "Copying.txt", "AUTHORS") {
    $license = Get-ChildItem -Path $extract -Recurse -Filter $name | Select-Object -First 1
    if ($license) { Copy-Item -LiteralPath $license.FullName -Destination (Join-Path $bin $name) -Force }
}
@"
Stockfish $Version
https://stockfishchess.org

$label build from the official sf_$Version release.
Licensed under the GNU General Public License v3. See Copying.txt.
Source: https://github.com/official-stockfish/Stockfish/releases/tag/sf_$Version
"@ | Set-Content -Path (Join-Path $bin "STOCKFISH.txt") -Encoding UTF8

Remove-Item -LiteralPath $archive -Force
Remove-Item -LiteralPath $extract -Recurse -Force
Write-Host "Installed $target"
