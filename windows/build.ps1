# build.ps1 — Build and package Indigo for Windows
$ErrorActionPreference = "Stop"

$publishDir = "publish"
$appName = "Indigo"

Write-Host "Building $appName..." -ForegroundColor Cyan
dotnet publish IndigoWindows/IndigoWindows.csproj -c Release -r win-x64 --self-contained -o $publishDir

# Copy native dependencies if present
Write-Host "Copying native libraries..." -ForegroundColor Cyan
if (Test-Path "libs/SpoutDX") {
    Copy-Item "libs/SpoutDX/*.dll" $publishDir -Force -ErrorAction SilentlyContinue
    Write-Host "  Copied Spout DLLs" -ForegroundColor Gray
}
if (Test-Path "libs/NDI") {
    Copy-Item "libs/NDI/*.dll" $publishDir -Force -ErrorAction SilentlyContinue
    Write-Host "  Copied NDI DLLs" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Build complete: $publishDir/" -ForegroundColor Green
Write-Host "Run: $publishDir/$appName.exe" -ForegroundColor Yellow
