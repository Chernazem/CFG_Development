@echo off
setlocal EnableExtensions
title Fix TB-PC Cursor worker proxy
cd /d "%~dp0"

echo.
echo === TB-PC: overlay + HTTPS proxy + restart worker ===
echo This window: %CD%
echo.

REM Prefer companion .ps1 next to this .bat (copied into _AI).
set "PS1=%~dp0fix-tb-cursor-worker-proxy.ps1"
if not exist "%PS1%" (
  set "PS1=%~dp0TB-workspace\overlay\tools\scripts\fix-tb-cursor-worker-proxy.ps1"
)
if not exist "%PS1%" (
  echo ERROR: fix-tb-cursor-worker-proxy.ps1 not found next to this bat
  echo        or under TB-workspace\overlay\tools\scripts\
  echo Wait for Yandex sync of _AI\TB-workspace, then re-run.
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -AiRoot "%~dp0."
set "EC=%ERRORLEVEL%"
if not "%EC%"=="0" (
  echo.
  echo FAILED with exit code %EC%
  pause
  exit /b %EC%
)
exit /b 0
