# Deploy Firestore rules + indexes (and Storage rules).
# Prerequisites:
#   firebase login
#   Set project: firebase use YOUR_PROJECT_ID
#   Or edit .firebaserc "default"
#
# Usage (from pasale_register):
#   .\scripts\deploy_firestore.ps1
#   .\scripts\deploy_firestore.ps1 -ProjectId my-project-id

param(
  [string]$ProjectId = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$env:Path = "$env:APPDATA\npm;$env:LOCALAPPDATA\Pub\Cache\bin;$env:Path"

if ($ProjectId) {
  firebase use $ProjectId
}

Write-Host "Deploying Firestore rules + indexes, Storage rules..."
firebase deploy --only firestore:rules,firestore:indexes,storage

Write-Host ""
Write-Host "Done. Verify in console:"
Write-Host "  https://console.firebase.google.com/"
Write-Host "Schema reference: docs/FIRESTORE_SCHEMA.md"
