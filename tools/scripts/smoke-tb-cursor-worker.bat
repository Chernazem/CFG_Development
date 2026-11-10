@echo off
setlocal EnableExtensions
title TB-PC worker smoke (verbose)
cd /d "%~dp0"

echo.
echo === Smoke-test agent worker start (verbose) ===
echo Writes Desktop\tb-worker-smoke.txt then restarts TB-Cursor-Worker
echo.

set "PS1=%~dp0smoke-tb-cursor-worker.ps1"
if not exist "%PS1%" (
  set "PS1=%~dp0TB-workspace\overlay\tools\scripts\smoke-tb-cursor-worker.ps1"
)
if not exist "%PS1%" (
  echo ERROR: smoke-tb-cursor-worker.ps1 not found
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
set "EC=%ERRORLEVEL%"
if not "%EC%"=="0" (
  echo FAILED %EC%
  pause
)
exit /b %EC%
