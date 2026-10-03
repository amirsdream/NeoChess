<#
.SYNOPSIS
  Downloads the official Stockfish release into bin/ for development and for
  building a release that ships the engine.

  The engine is GPLv3 and is deliberately not stored in this repository.
#>
param(
    [string]$Version = "19",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$bin = Join-Path $root "bin"
$target = Join-Path $bin "stockfish.exe"

if ((Test-Path $target) -and -not $Force) {
    Write-Host "bin/stockfish.exe already exists. Use -Force to download it again."
    exit 0
}

$asset = "stockfish-windows-x86-64-universal.zip"
$url = "https://github.com/official-stockfish/Stockfish/releases/download/sf_$Version/$asset"
$zip = Join-Path ([System.IO.Path]::GetTempPath()) "neochess-$asset"
$extract = Join-Path ([System.IO.Path]::GetTempPath()) "neochess-stockfish-$Version"

Write-Host "Downloading $url"
$ProgressPreference = "SilentlyContinue"
Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing

if (Test-Path $extract) { Remove-Item -LiteralPath $extract -Recurse -Force }
Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force

$exe = Get-ChildItem -Path $extract -Recurse -Filter "stockfish*.exe" | Select-Object -First 1
if (-not $exe) { throw "No Stockfish executable found in the archive." }

New-Item -ItemType Directory -Force -Path $bin | Out-Null
Copy-Item -LiteralPath $exe.FullName -Destination $target -Force
foreach ($name in "Copying.txt", "AUTHORS") {
    $license = Get-ChildItem -Path $extract -Recurse -Filter $name | Select-Object -First 1
    if ($license) { Copy-Item -LiteralPath $license.FullName -Destination (Join-Path $bin $name) -Force }
}
@"
Stockfish $Version
https://stockfishchess.org

Universal Windows x86-64 build from the official sf_$Version release.
Licensed under the GNU General Public License v3. See Copying.txt.
Source: https://github.com/official-stockfish/Stockfish/releases/tag/sf_$Version
"@ | Set-Content -Path (Join-Path $bin "STOCKFISH.txt") -Encoding UTF8

Remove-Item -LiteralPath $zip -Force
Remove-Item -LiteralPath $extract -Recurse -Force
Write-Host "Installed $target"
