param(
  [string]$ApiBaseUrl = $env:API_BASE_URL,
  [string]$WsHost = $env:WS_HOST,
  [string]$WsScheme = $env:WS_SCHEME,
  [string]$WsKey = $env:WS_KEY
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "==> Generating runtime env-config.js"
node scripts/generate-env-config.mjs frontend/web/env-config.js

Set-Location frontend
flutter pub get

$buildArgs = @("build", "web", "--release")
if ($ApiBaseUrl) { $buildArgs += "--dart-define=API_BASE_URL=$ApiBaseUrl" }
if ($WsHost) { $buildArgs += "--dart-define=WS_HOST=$WsHost" }
if ($WsScheme) { $buildArgs += "--dart-define=WS_SCHEME=$WsScheme" }
if ($WsKey) { $buildArgs += "--dart-define=WS_KEY=$WsKey" }

flutter @buildArgs
Write-Host "==> Build complete: frontend/build/web"
