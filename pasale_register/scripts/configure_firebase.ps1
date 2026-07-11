# Run from pasale_register after: firebase login
# Usage: .\scripts\configure_firebase.ps1 -ProjectId your-firebase-project-id

param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectId
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$env:Path = "$env:APPDATA\npm;$env:LOCALAPPDATA\Pub\Cache\bin;$env:Path"

Write-Host "Configuring FlutterFire for project: $ProjectId"
dart pub global activate flutterfire_cli | Out-Null
flutterfire configure --project=$ProjectId --platforms=android,ios --yes

Write-Host ""
Write-Host "Done. Rebuild the app:"
Write-Host "  flutter clean"
Write-Host "  flutter pub get"
Write-Host "  flutter run"
Write-Host ""
Write-Host "Banner should show: Firebase · real camera"
