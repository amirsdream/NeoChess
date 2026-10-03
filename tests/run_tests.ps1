<#
.SYNOPSIS
  Runs the NeoChess test suite with a headless Godot.

.PARAMETER Godot
  Path to the Godot 4.7 console executable. Defaults to $env:GODOT, then
  "godot" on PATH, then .tools/godot in this repository.

.PARAMETER Filter
  Only run test files whose name contains this text, for example "uci".

.PARAMETER Verbose
  Print every passing check as well as failures.
#>
param(
    [string]$Godot = $env:GODOT,
    [string]$Filter = "",
    [switch]$VerboseChecks
)

$root = Split-Path -Parent $PSScriptRoot

if (-not $Godot) {
    $onPath = Get-Command godot -ErrorAction SilentlyContinue
    if ($onPath) { $Godot = $onPath.Source }
}
if (-not $Godot) {
    $local = Get-ChildItem -Path (Join-Path $root ".tools/godot") -Filter "Godot*console.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($local) { $Godot = $local.FullName }
}
if (-not $Godot -or -not (Test-Path $Godot)) {
    Write-Error "Godot was not found. Pass -Godot <path> or set the GODOT environment variable."
    exit 2
}

# Make sure the global classes (ChessGame, Appearance, ...) are registered.
& $Godot --headless --path $root --import 2>&1 | Out-Null

$tests = Get-ChildItem -Path $PSScriptRoot -Filter "test_*.gd" |
    Where-Object { $_.Name -ne "test_base.gd" -and $_.Name -like "*$Filter*" } |
    Sort-Object Name

$failed = @()
foreach ($test in $tests) {
    Write-Host "== $($test.Name)" -ForegroundColor Cyan
    $args = @("--headless", "--path", $root, "-s", "res://tests/$($test.Name)", "--", "--no-engine")
    if ($VerboseChecks) { $args += "--verbose" }
    & $Godot @args
    if ($LASTEXITCODE -ne 0) { $failed += $test.Name }
}

Write-Host ""
if ($failed.Count -gt 0) {
    Write-Host "FAILED: $($failed -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host "All $($tests.Count) test files passed." -ForegroundColor Green
exit 0
