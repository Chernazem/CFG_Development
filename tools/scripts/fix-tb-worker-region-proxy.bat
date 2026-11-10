@echo off
setlocal EnableExtensions
title Fix TB worker region 403 via Node proxy
cd /d "%~dp0"

echo.
echo === Force NODE_USE_ENV_PROXY + HTTP/1.1, restart worker ===
echo.

set "PS1=%~dp0fix-tb-worker-region-proxy.ps1"
if not exist "%PS1%" set "PS1=%~dp0TB-workspace\overlay\tools\scripts\fix-tb-worker-region-proxy.ps1"
if not exist "%PS1%" (
  echo ERROR: fix-tb-worker-region-proxy.ps1 not found
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -AiRoot "%~dp0."
set "EC=%ERRORLEVEL%"
if not "%EC%"=="0" (
  echo FAILED %EC%
  pause
)
exit /b %EC%
