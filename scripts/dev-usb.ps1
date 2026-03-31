# Алиас: по умолчанию dev.ps1 уже USB/adb.
param(
    [string]$Device = '',
    [string]$ApiUrl = ''
)
$ErrorActionPreference = 'Stop'
$dev = Join-Path $PSScriptRoot 'dev.ps1'
if ($Device -and $ApiUrl) { & $dev -Device $Device -ApiUrl $ApiUrl; exit $LASTEXITCODE }
if ($Device) { & $dev -Device $Device; exit $LASTEXITCODE }
if ($ApiUrl) { & $dev -ApiUrl $ApiUrl; exit $LASTEXITCODE }
& $dev
exit $LASTEXITCODE
