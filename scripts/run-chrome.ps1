# Запуск Omuz в Chrome — без Visual Studio (см. также: .\scripts\dev.ps1 -Mode chrome).
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'dev.ps1') -Mode chrome @args
