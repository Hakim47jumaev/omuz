# OMuz: Flutter run + API только через USB (adb reverse tcp:8000 -> PC :8000).
#
# Режимы:
#   usb (по умолчанию) — 127.0.0.1 + adb reverse + OMUZ_ADB; телефон по USB
#   -Lan               — тот же USB для деплоя, но API = http://<IP ПК>:8000 (Wi‑Fi).
#                        Обходит сбои «Connection closed before full header» на части телефонов.
#   emulator          — без dart-define API (в приложении 10.0.2.2)
#   chrome            — flutter run -d chrome; API http://127.0.0.1:8000/api/v1
#
# В другом окне: .\scripts\start-api.ps1
# Скрипт обновляет omuz/assets/local_api.json.
#
# Примеры:
#   .\scripts\dev.ps1
#   .\scripts\dev.ps1 -Lan                    # телефон и ПК в одной Wi‑Fi, без adb reverse для API
#   .\scripts\dev.ps1 -Device RRCW6017PCK   # если «more than one device»
#   .\scripts\dev.ps1 -Mode emulator
#   .\scripts\dev.ps1 -Mode chrome
#   .\scripts\dev.ps1 -ApiUrl http://127.0.0.1:8000/api/v1
param(
    [ValidateSet('usb', 'emulator', 'chrome')]
    [string]$Mode = 'usb',
    [string]$Device = '',
    [string]$ApiUrl = '',
    [switch]$Lan
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Omuz = Join-Path $Root 'omuz'

function Resolve-AdbExecutable {
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) {
        return $cmd.Source
    }
    $candidates = @()
    $candidates += (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe')
    if ($env:ANDROID_HOME) {
        $candidates += (Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe')
    }
    if ($env:ANDROID_SDK_ROOT) {
        $candidates += (Join-Path $env:ANDROID_SDK_ROOT 'platform-tools\adb.exe')
    }
    $propsPath = Join-Path $Omuz 'android\local.properties'
    if (Test-Path -LiteralPath $propsPath) {
        Get-Content -LiteralPath $propsPath -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_ -match '^\s*sdk\.dir\s*=\s*(.+)\s*$') {
                $dir = $matches[1].Trim() -replace '\\\\', '\'
                $candidates += (Join-Path $dir 'platform-tools\adb.exe')
            }
        }
    }
    foreach ($p in $candidates) {
        if ($p -and (Test-Path -LiteralPath $p)) {
            return $p
        }
    }
    return $null
}

function Test-AdbDeviceReady {
    param([Parameter(Mandatory)][string]$AdbPath)
    $lines = & $AdbPath devices 2>&1
    if ($LASTEXITCODE -ne 0) {
        return $false
    }
    foreach ($line in $lines) {
        if ($line -match '^\S+\s+device\s*$') {
            return $true
        }
    }
    return $false
}

function Get-AdbOnlineSerials {
    param([Parameter(Mandatory)][string]$AdbPath)
    $serials = @()
    $lines = & $AdbPath devices 2>&1
    foreach ($line in $lines) {
        if ($line -match '^(\S+)\s+device\s*$') {
            $serials += @($matches[1])
        }
    }
    return $serials
}

# Выбор устройства для adb -s reverse и flutter -d (несколько девайсов / эмулятор + телефон).
function Resolve-AdbUsbSerial {
    param(
        [Parameter(Mandatory)][string]$AdbPath,
        [string]$ExplicitDevice
    )
    $all = @(Get-AdbOnlineSerials -AdbPath $AdbPath)
    if ($all.Count -eq 0) {
        return $null
    }
    if ($ExplicitDevice) {
        if ($all -contains $ExplicitDevice) {
            return $ExplicitDevice
        }
        $list = $all -join ', '
        Write-Host "[dev] -Device $ExplicitDevice not in adb list. Available: $list" -ForegroundColor Red
        Write-Host "[dev] Run: $AdbPath devices" -ForegroundColor DarkGray
        exit 1
    }
    if ($all.Count -eq 1) {
        return $all[0]
    }
    $physical = @($all | Where-Object { $_ -notmatch '^emulator-' })
    if ($physical.Count -eq 1) {
        Write-Host "[dev] Neskolko ustroystv - reverse i Flutter na telefon: $($physical[0])" -ForegroundColor Cyan
        return $physical[0]
    }
    if ($physical.Count -gt 1) {
        Write-Host '[dev] Several phones connected. Use -Device SERIAL:' -ForegroundColor Yellow
        foreach ($s in $physical) {
            Write-Host "  .\scripts\dev.ps1 -Device $s" -ForegroundColor DarkGray
        }
        exit 1
    }
    Write-Host '[dev] Podklyucheny tolko ehmulyatory. Ukazhite: .\scripts\dev.ps1 -Device SERIYNYY_NOMER' -ForegroundColor Red
    foreach ($s in $all) {
        Write-Host "  $s" -ForegroundColor DarkGray
    }
    Write-Host '[dev] Komanda: adb devices' -ForegroundColor DarkGray
    exit 1
}

function Get-OmuzPrimaryLanIPv4 {
    try {
        $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object {
                $_.IPAddress -notlike '127.*' -and
                $_.IPAddress -notlike '169.254.*'
            } |
            Sort-Object InterfaceMetric |
            Select-Object -First 1 -ExpandProperty IPAddress
        if ($ip -and $ip -match '^\d{1,3}(\.\d{1,3}){3}$') {
            return $ip
        }
    }
    catch { }
    return $null
}

$resolvedApi = $null
$AdbSerialForUsb = $null
$usbReverseApplied = $false
if ($ApiUrl) {
    $resolvedApi = $ApiUrl
    Write-Host "[dev] API from parameter: $resolvedApi" -ForegroundColor Cyan
}

if ($Mode -eq 'usb') {
    if ($Lan -and $ApiUrl) {
        Write-Host '[dev] -Lan ignored because -ApiUrl is set.' -ForegroundColor Yellow
    }
    elseif ($Lan) {
        $lip = Get-OmuzPrimaryLanIPv4
        if (-not $lip) {
            Write-Host '[dev] Could not detect PC IPv4 for -Lan. Use -ApiUrl http://YOUR_PC_IP:8000/api/v1' -ForegroundColor Red
            exit 1
        }
        $resolvedApi = "http://${lip}:8000/api/v1"
        Write-Host "[dev] LAN API (no adb reverse): $resolvedApi" -ForegroundColor Cyan
        Write-Host '[dev] Phone must use same Wi-Fi as this PC. If blocked, run scripts/open-firewall-8000.ps1 as Admin.' -ForegroundColor DarkGray
    }
    elseif (-not $resolvedApi) {
        $resolvedApi = 'http://127.0.0.1:8000/api/v1'
    }

    $adbExe = Resolve-AdbExecutable
    if (-not $adbExe) {
        Write-Host '[dev] adb not found. Install Android SDK Platform-Tools or add platform-tools to PATH.' -ForegroundColor Red
        Write-Host ('[dev] Typical path: {0}\Android\Sdk\platform-tools' -f $env:LOCALAPPDATA) -ForegroundColor DarkGray
        exit 1
    }
    Write-Host "[dev] adb: $adbExe" -ForegroundColor DarkGray
    if (-not (Test-AdbDeviceReady -AdbPath $adbExe)) {
        Write-Host '[dev] No device in "device" state. Enable USB debugging and authorize this PC.' -ForegroundColor Red
        Write-Host "[dev] Check: $adbExe devices" -ForegroundColor DarkGray
        exit 1
    }
    $AdbSerialForUsb = Resolve-AdbUsbSerial -AdbPath $adbExe -ExplicitDevice $Device
    if (-not $AdbSerialForUsb) {
        Write-Host '[dev] No adb device serial resolved.' -ForegroundColor Red
        exit 1
    }

    if ($resolvedApi -match '127\.0\.0\.1|localhost') {
        Write-Host "[dev] adb -s $AdbSerialForUsb reverse tcp:8000 to localhost:8000" -ForegroundColor Cyan
        & $adbExe -s $AdbSerialForUsb reverse tcp:8000 tcp:8000
        if ($LASTEXITCODE -ne 0) {
            Write-Host '[dev] adb reverse failed.' -ForegroundColor Red
            exit 1
        }
        & $adbExe -s $AdbSerialForUsb reverse --list
        $usbReverseApplied = $true
    }
}
elseif ($Mode -eq 'emulator') {
    if (-not $resolvedApi) {
        Write-Host '[dev] Emulator: app uses http://10.0.2.2:8000/api/v1' -ForegroundColor Cyan
    }
}
elseif ($Mode -eq 'chrome') {
    if (-not $resolvedApi) {
        $resolvedApi = 'http://127.0.0.1:8000/api/v1'
        Write-Host '[dev] Chrome: API http://127.0.0.1:8000/api/v1' -ForegroundColor Cyan
    }
}

$urlForAsset = $resolvedApi
if (-not $urlForAsset -and $Mode -eq 'emulator') {
    $urlForAsset = 'http://10.0.2.2:8000/api/v1'
}
if ($urlForAsset) {
    $assetPath = Join-Path $Omuz 'assets\local_api.json'
    $json = (@{ api_base_url = $urlForAsset } | ConvertTo-Json -Compress)
    [System.IO.File]::WriteAllText($assetPath, $json, [System.Text.UTF8Encoding]::new($false))
    Write-Host '[dev] assets/local_api.json updated' -ForegroundColor DarkGray
}

Push-Location $Omuz
try {
    $flutterArgs = @('run')
    if ($Mode -eq 'chrome') {
        $flutterArgs += '-d', 'chrome'
    }
    else {
        $flutterTarget = if ($Device) { $Device } elseif ($AdbSerialForUsb) { $AdbSerialForUsb } else { '' }
        if ($flutterTarget) {
            $flutterArgs += '-d', $flutterTarget
        }
    }
    if ($resolvedApi) {
        $flutterArgs += '--dart-define=API_BASE_URL=' + $resolvedApi
    }
    if ($usbReverseApplied) {
        $flutterArgs += '--dart-define=OMUZ_ADB=true'
    }

    $flutterCmd = $flutterArgs -join ' '
    Write-Host "[dev] flutter $flutterCmd" -ForegroundColor DarkGray
    & flutter @flutterArgs
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
