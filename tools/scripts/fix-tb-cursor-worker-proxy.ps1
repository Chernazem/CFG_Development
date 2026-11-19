# Write Cursor HTTPS proxy into tb-worker.env and restart the My Machines worker.
# Shell files come from the CFG_Development clone. Yandex overlay is off unless -UseYandexOverlay.
# Invoked by fix-tb-cursor-worker-proxy.bat on TB-PC. ASCII-only for Windows PowerShell 5.1.

[CmdletBinding()]
param(
    [string]$AiRoot = '',
    [string]$WorkspaceRoot = 'D:\Dev Projects\TB',
    [switch]$UseYandexOverlay
)

$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
    Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message)
}

function Find-AiRoot {
    param([string]$Hint)
    if ($Hint -and (Test-Path -LiteralPath $Hint)) {
        return (Resolve-Path -LiteralPath $Hint).Path
    }
    if ($PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'TB-workspace'))) {
        return (Resolve-Path -LiteralPath $PSScriptRoot).Path
    }
    $helper = Join-Path $PSScriptRoot 'Find-TbYandexAiDir.ps1'
    if (Test-Path -LiteralPath $helper) {
        . $helper
        return Find-TbYandexAiDir
    }
    throw 'Yandex _AI folder not found. Pass -AiRoot or put this script next to TB-workspace.'
}

function Resolve-ProxyUrl {
    param([string]$BundleRoot)
    $secret = Join-Path $BundleRoot 'secrets\cursor-https-proxy.url'
    if (Test-Path -LiteralPath $secret) {
        $url = (Get-Content -LiteralPath $secret -Raw -Encoding utf8).Trim()
        if ($url) { return $url }
    }
    $cursorSettings = Join-Path $env:APPDATA 'Cursor\User\settings.json'
    if (Test-Path -LiteralPath $cursorSettings) {
        $settingsJson = Get-Content -LiteralPath $cursorSettings -Raw -Encoding utf8 | ConvertFrom-Json
        $ideProxy = [string]$settingsJson.'http.proxy'
        if ($ideProxy) { return $ideProxy }
    }
    throw 'Proxy URL not found. Need TB-workspace\secrets\cursor-https-proxy.url or Cursor http.proxy.'
}

if (-not (Test-Path -LiteralPath $WorkspaceRoot)) {
    foreach ($c in @('D:\Dev Projects\TB', 'D:\Codex Projects\TB', 'C:\Dev Projects\TB')) {
        if (Test-Path -LiteralPath (Join-Path $c 'repos\manifest.yaml')) {
            $WorkspaceRoot = $c
            break
        }
    }
}
if (-not (Test-Path -LiteralPath (Join-Path $WorkspaceRoot 'repos\manifest.yaml'))) {
    throw "TB workspace not found (expected repos\manifest.yaml). Pass -WorkspaceRoot."
}
Write-Step "Workspace: $WorkspaceRoot"

$bundle = ''
if ($UseYandexOverlay) {
    $AiRoot = Find-AiRoot -Hint $AiRoot
    $bundle = Join-Path $AiRoot 'TB-workspace'
    if (-not (Test-Path -LiteralPath $bundle)) {
        throw "Bundle not found: $bundle"
    }
    Write-Step "AI root: $AiRoot"
    $syncScript = Join-Path $bundle 'overlay\tools\scripts\sync-tb-workspace-yandex.ps1'
    if (-not (Test-Path -LiteralPath $syncScript)) {
        throw "Missing overlay sync script: $syncScript"
    }
    Write-Step 'Applying Yandex overlay by explicit request...'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $syncScript `
        -Action Apply -WorkspaceRoot $WorkspaceRoot -YandexAiDir $AiRoot
    if ($LASTEXITCODE -ne 0) { throw "overlay Apply failed with exit $LASTEXITCODE" }
}

$proxyUrl = Resolve-ProxyUrl -BundleRoot $bundle
Write-Step ("Proxy host: {0}" -f ([uri]$proxyUrl).Host)

$applyScript = Join-Path $WorkspaceRoot 'tools\scripts\apply-tb-worker-proxy-from-cursor-settings.ps1'
if (-not (Test-Path -LiteralPath $applyScript)) {
    throw "Missing $applyScript after overlay Apply"
}

Write-Step 'Writing proxy into tb-worker.env and ensuring TB-Cursor-Worker task...'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $applyScript `
    -ProxyUrl $proxyUrl -RestartWorker
if ($LASTEXITCODE -ne 0) { throw "apply-tb-worker-proxy failed with exit $LASTEXITCODE" }

$task2 = Get-ScheduledTask -TaskName 'TB-Cursor-Worker' -ErrorAction SilentlyContinue
if (-not $task2) {
    throw 'TB-Cursor-Worker still missing after register/start'
}
Write-Step ("Task state: {0}" -f $task2.State)
if ($task2.State -ne 'Running') {
    Start-ScheduledTask -TaskName 'TB-Cursor-Worker' -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    $task2 = Get-ScheduledTask -TaskName 'TB-Cursor-Worker' -ErrorAction SilentlyContinue
    Write-Step ("Task state after start: {0}" -f $task2.State)
}

$log = Join-Path $env:USERPROFILE '.cursor\tb-worker.log'
if (Test-Path -LiteralPath $log) {
    Write-Step "Tail of $log :"
    Get-Content -LiteralPath $log -Tail 30 -ErrorAction SilentlyContinue
} else {
    Write-Step "Log not found yet: $log"
}

Write-Step 'Done. Check cursor.com/agents -> TB-PC is online (from a network that can open Cursor).'
Write-Host 'Press Enter to close...'
[void][Console]::ReadLine()
