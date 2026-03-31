@echo off
cd /d "%~dp0..\omuz"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-chrome.ps1" %*
