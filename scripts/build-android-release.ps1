# Build a release APK that talks to the hosted Vercel API (no local backend).
$ErrorActionPreference = "Stop"

$frontend = Join-Path (Split-Path -Parent $PSScriptRoot) "frontend"

Push-Location $frontend
try {
    flutter build apk --release @args
    Write-Host ""
    Write-Host "APK: frontend/build/app/outputs/flutter-apk/app-release.apk"
    Write-Host "API: https://rbe-pickleball.vercel.app/api (no local backend required)"
} finally {
    Pop-Location
}
