<#
.SYNOPSIS
  Regenerates the screenshots in docs/images.

.DESCRIPTION
  Runs the game with the hidden --shot switch, which fills the window with a
  sample game and sample engine lines, saves .tools/preview.png and quits.
  The library and opening book pictures use a made-up sample library from
  dev/make_demo_library.gd, so no personal data ends up in the images.
  Needs a desktop session (it opens real windows for a moment).

.PARAMETER Godot
  Path to the Godot executable (not the console build is fine too). Defaults to
  $env:GODOT, then .tools/godot in this repository.
#>
param([string]$Godot = $env:GODOT)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not $Godot) {
    $found = Get-ChildItem (Join-Path $root ".tools/godot") -Recurse -Filter "Godot*.exe" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike "*console*" } | Select-Object -First 1
    if ($found) { $Godot = $found.FullName } else { $Godot = "godot" }
}
$console = $Godot
$consoleFound = Get-ChildItem (Split-Path $Godot) -Filter "Godot*console.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($consoleFound) { $console = $consoleFound.FullName }

$demo = Join-Path $root ".tools/demo/library.db"
New-Item -ItemType Directory -Force (Split-Path $demo) | Out-Null
if (-not (Test-Path $demo)) {
    Write-Host "Building the sample library (about a minute)..."
    & $console --headless --path $root --script dev/make_demo_library.gd -- $demo | Out-Host
}

$out = Join-Path $root "docs/images"
New-Item -ItemType Directory -Force $out | Out-Null
$preview = Join-Path $root ".tools/preview.png"

# name, extra game arguments
$shots = @(
    @("game",          @("--book", "--library=$demo")),
    @("review",        @("--review", "--board=2", "--library=$demo")),
    @("book",          @("--review", "--book", "--library=$demo")),
    @("library",       @("--library", "--library=$demo")),
    @("ocean",         @("--board=2", "--library=$demo")),
    @("settings-look", @("--settings", "--library=$demo")),
    @("settings-play", @("--settings", "--play", "--library=$demo")),
    @("new-game",      @("--newgame", "--library=$demo")),
    @("download",      @("--setup", "--no-lines", "--library=$demo")),
    @("settings-engine", @("--settings", "--engine", "--leela", "--library=$demo")),
    @("download-leela", @("--leela", "--setup", "--no-lines", "--library=$demo"))
)

foreach ($shot in $shots) {
    Remove-Item -LiteralPath $preview -ErrorAction SilentlyContinue
    $arguments = @("--path", $root, "--resolution", "1180x1000", "--", "--shot") + $shot[1]
    $process = Start-Process -FilePath $Godot -ArgumentList $arguments -PassThru
    if (-not $process.WaitForExit(90000)) { $process.Kill(); throw "Timed out making $($shot[0])." }
    if (-not (Test-Path $preview)) { throw "No picture was made for $($shot[0])." }
    Copy-Item -LiteralPath $preview -Destination (Join-Path $out "$($shot[0]).png") -Force
    Write-Host "docs/images/$($shot[0]).png"
}
