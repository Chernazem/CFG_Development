@echo off
setlocal EnableExtensions
title Repair TB-PC worker env (API key + proxy)
cd /d "%~dp0"

echo.
echo === Repair CURSOR_API_KEY + proxy, restart worker ===
echo This window: %CD%
echo.

set "PS1=%~dp0repair-tb-cursor-worker-env.ps1"
if not exist "%PS1%" (
  set "PS1=%~dp0TB-workspace\overlay\tools\scripts\repair-tb-cursor-worker-env.ps1"
)
if not exist "%PS1%" (
  echo ERROR: repair-tb-cursor-worker-env.ps1 not found
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -AiRoot "%~dp0."
set "EC=%ERRORLEVEL%"
if not "%EC%"=="0" (
  echo.
  echo FAILED with exit code %EC%
  pause
)
exit /b %EC%
