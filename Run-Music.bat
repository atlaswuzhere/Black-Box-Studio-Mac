@echo off
setlocal
title BLACKBOX // PERSONAL AUDIO SYSTEM
set "ROOT=%~dp0"
where powershell.exe >nul 2>&1
if errorlevel 1 (
  echo [BLACKBOX ERROR] Windows PowerShell was not found.
  pause
  exit /b 1
)
echo.
echo  BLACKBOX
echo  Starting your local browser player...
echo  This window hosts the app. Close it to stop the local server.
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ROOT%Start-BlackBox-Web.ps1"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" pause
exit /b %RC%
