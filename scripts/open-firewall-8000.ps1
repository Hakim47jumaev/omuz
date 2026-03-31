# Разрешить входящие TCP 8000 (Django) в брандмауэре Windows — иначе телефон по Wi‑Fi не достучится до API.
# Запуск: PowerShell от имени администратора.
$ErrorActionPreference = 'Stop'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Запустите скрипт от имени администратора.' -ForegroundColor Red
    exit 1
}

$existing = Get-NetFirewallRule -DisplayName 'Omuz Django 8000' -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host 'Правило Omuz Django 8000 уже есть.' -ForegroundColor Green
    exit 0
}

New-NetFirewallRule -DisplayName 'Omuz Django 8000' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8000
Write-Host 'Готово: входящий TCP 8000 разрешён.' -ForegroundColor Green
