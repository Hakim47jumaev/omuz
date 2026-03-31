# Установка toolchain для `flutter run -d windows` (требуются права администратора).
# После установки: закройте терминал, откройте заново, выполните `flutter doctor`.
#
# Запуск из PowerShell **от имени администратора**:
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   .\scripts\install-vs-cpp.ps1

$ErrorActionPreference = 'Stop'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Запустите этот скрипт от имени администратора (ПКМ -> Запуск от имени администратора).' -ForegroundColor Red
    exit 1
}

$winget = Get-Command winget -ErrorAction SilentlyContinue
if (-not $winget) {
    Write-Host 'winget не найден. Установите Visual Studio Community вручную:' -ForegroundColor Yellow
    Write-Host 'https://visualstudio.microsoft.com/downloads/' -ForegroundColor Cyan
    Write-Host 'Рабочая нагрузка: Desktop development with C++' -ForegroundColor Yellow
    exit 1
}

Write-Host 'Устанавливаю Visual Studio 2022 Build Tools (C++ workload)... Это может занять 10–30 минут.' -ForegroundColor Cyan

# Workload: MSVC, Windows SDK — нужно Flutter для Windows desktop.
winget install --id Microsoft.VisualStudio.2022.BuildTools -e --source winget --accept-package-agreements --accept-source-agreements `
    --override '--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'

if ($LASTEXITCODE -ne 0) {
    Write-Host 'winget завершился с ошибкой. Поставьте VS вручную (см. выше).' -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host 'Готово. Выполните: flutter doctor' -ForegroundColor Green
