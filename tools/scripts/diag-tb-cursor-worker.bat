@echo off
setlocal EnableExtensions
title TB-PC worker diagnostics
cd /d "%~dp0"

echo.
echo === TB-PC: Cursor worker diagnostics ===
echo This window: %CD%
echo.

set "PS1=%~dp0diag-tb-cursor-worker.ps1"
if not exist "%PS1%" (
  set "PS1=%~dp0TB-workspace\overlay\tools\scripts\diag-tb-cursor-worker.ps1"
)
if not exist "%PS1%" (
  echo ERROR: diag-tb-cursor-worker.ps1 not found
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
)
exit /b %EC%
