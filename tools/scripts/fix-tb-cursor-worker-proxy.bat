@echo off
setlocal EnableExtensions
title Fix TB-PC Cursor worker proxy
cd /d "%~dp0"

echo.
echo === TB-PC: HTTPS proxy + restart worker ===
echo This window: %CD%
echo.

set "PS1=%~dp0fix-tb-cursor-worker-proxy.ps1"
if not exist "%PS1%" (
  echo ERROR: fix-tb-cursor-worker-proxy.ps1 not found next to this bat.
  echo Run it from the CFG_Development clone, tools\scripts.
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
set "EC=%ERRORLEVEL%"
if not "%EC%"=="0" (
  echo.
  echo FAILED with exit code %EC%
  pause
  exit /b %EC%
)
exit /b 0
