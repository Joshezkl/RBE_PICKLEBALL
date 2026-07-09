# Run Flutter on Android against a local backend (requires php artisan serve).
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$frontend = Join-Path $repoRoot "frontend"
$adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"

function Get-LanIp {
    $ips = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.IPAddress -notlike "127.*" -and
            $_.IPAddress -notlike "169.254.*" -and
            $_.IPAddress -notlike "192.168.56.*"
        } |
        Select-Object -ExpandProperty IPAddress

    if ($ips.Count -eq 0) {
        throw "No LAN IPv4 address found. Connect to Wi-Fi and retry."
    }

    return $ips[0]
}

$apiHost = Get-LanIp
Write-Host "Using DEV_API_HOST=$apiHost"

if (Test-Path $adb) {
    & $adb reverse tcp:8000 tcp:8000 | Out-Null
    Write-Host "adb reverse tcp:8000 tcp:8000"
}

Push-Location $frontend
try {
    flutter run `
        --dart-define=USE_LOCAL_API=true `
        --dart-define=DEV_API_HOST=$apiHost `
        @args
} finally {
    Pop-Location
}
