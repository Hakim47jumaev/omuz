# Запуск Django на 0.0.0.0:8000 (доступ с телефона по Wi‑Fi и с эмулятора через LAN).
$ErrorActionPreference = 'Stop'
$ApiRoot = Resolve-Path (Join-Path $PSScriptRoot '..\omuzapi')
Push-Location $ApiRoot
try {
    if (Test-Path '.\.venv\Scripts\Activate.ps1') {
        . .\.venv\Scripts\Activate.ps1
    }
    elseif (Test-Path '.\venv\Scripts\Activate.ps1') {
        . .\venv\Scripts\Activate.ps1
    }
    Write-Host '[start-api] python manage.py runserver 0.0.0.0:8000' -ForegroundColor Cyan
    python manage.py runserver 0.0.0.0:8000
}
finally {
    Pop-Location
}
