@echo off
setlocal
title BLACKBOX // AUDIO ENGINE v6
set "ROOT=%~dp0"
where powershell.exe >nul 2>&1
if errorlevel 1 (
  echo [BLACKBOX ERROR] Windows PowerShell was not found.
  pause
  exit /b 1
)
mode con: cols=100 lines=32 >nul 2>&1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%ROOT%BlackBox-Audio.ps1"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" pause
exit /b %RC%
