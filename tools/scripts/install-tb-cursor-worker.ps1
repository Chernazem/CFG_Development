# One-time setup on the always-on TB Windows PC.
# After this + autologin, the Cursor worker starts without RDP.

[CmdletBinding()]
param(
    [string]$WorkspaceRoot = '',
    [string]$WorkerDir = '',
    [string]$WorkerName = 'TB-PC',
    [switch]$SkipCliInstall
)

$ErrorActionPreference = 'Stop'

function Resolve-WorkspaceRoot {
    param([string]$Hint)
    if ($Hint -and (Test-Path -LiteralPath $Hint)) {
        return (Resolve-Path -LiteralPath $Hint).Path
    }
    $here = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    if (Test-Path -LiteralPath (Join-Path $here 'repos\manifest.yaml')) {
        return (Resolve-Path -LiteralPath $here).Path
    }
    foreach ($candidate in @(
            'D:\Dev Projects\TB',
            'F:\Codex Projects\TB',
            'D:\Codex Projects\TB',
            'C:\Codex Projects\TB'
        )) {
        if (Test-Path -LiteralPath (Join-Path $candidate 'repos\manifest.yaml')) {
            return $candidate
        }
    }
    throw 'Pass -WorkspaceRoot to the TB workspace (folder with repos\manifest.yaml).'
}

$WorkspaceRoot = Resolve-WorkspaceRoot $WorkspaceRoot
if (-not $WorkerDir) {
    $WorkerDir = $WorkspaceRoot
}
if (-not (Test-Path -LiteralPath $WorkerDir)) {
    throw "Worker dir not found: $WorkerDir"
}

$cursorDir = Join-Path $env:USERPROFILE '.cursor'
New-Item -ItemType Directory -Force -Path $cursorDir | Out-Null
$envFile = Join-Path $cursorDir 'tb-worker.env'

if (-not (Test-Path -LiteralPath $envFile)) {
    $key = Read-Host 'CURSOR_API_KEY from https://cursor.com/dashboard/api (personal user key)'
    if (-not $key) { throw 'CURSOR_API_KEY is required' }
    @(
        "CURSOR_API_KEY=$key",
        "TB_WORKER_NAME=$WorkerName",
        "TB_WORKSPACE_ROOT=$WorkspaceRoot",
        "TB_WORKER_DIR=$WorkerDir"
    ) | Set-Content -LiteralPath $envFile -Encoding utf8
    Write-Host "Wrote $envFile"
} else {
    Write-Host "Using existing $envFile"
    $envLines = Get-Content -LiteralPath $envFile
    $keys = @{}
    foreach ($line in $envLines) {
        $t = $line.Trim()
        if ($t -eq '' -or $t.StartsWith('#')) { continue }
        $eq = $t.IndexOf('=')
        if ($eq -lt 1) { continue }
        $keys[$t.Substring(0, $eq).Trim()] = $t.Substring($eq + 1).Trim()
    }
    $keys['TB_WORKER_NAME'] = $WorkerName
    $keys['TB_WORKSPACE_ROOT'] = $WorkspaceRoot
    $keys['TB_WORKER_DIR'] = $WorkerDir
    $out = @()
    if ($keys.ContainsKey('CURSOR_API_KEY')) {
        $out += "CURSOR_API_KEY=$($keys['CURSOR_API_KEY'])"
    }
    $out += "TB_WORKER_NAME=$($keys['TB_WORKER_NAME'])"
    $out += "TB_WORKSPACE_ROOT=$($keys['TB_WORKSPACE_ROOT'])"
    $out += "TB_WORKER_DIR=$($keys['TB_WORKER_DIR'])"
    foreach ($proxyKey in @('HTTPS_PROXY', 'HTTP_PROXY', 'ALL_PROXY', 'NO_PROXY', 'no_proxy')) {
        if ($keys.ContainsKey($proxyKey) -and $keys[$proxyKey]) {
            $out += "$proxyKey=$($keys[$proxyKey])"
        }
    }
    $out | Set-Content -LiteralPath $envFile -Encoding utf8
    Write-Host "Updated worker dir in $envFile"
}

# If Cursor IDE proxy is set and env has no HTTPS_PROXY, copy it once (same egress for My Machines).
$cursorSettings = Join-Path $env:APPDATA 'Cursor\User\settings.json'
if (Test-Path -LiteralPath $cursorSettings) {
    $envLinesNow = Get-Content -LiteralPath $envFile
    $hasHttpsProxy = $false
    foreach ($line in $envLinesNow) {
        if ($line.Trim().StartsWith('HTTPS_PROXY=')) { $hasHttpsProxy = $true; break }
    }
    if (-not $hasHttpsProxy) {
        try {
            $settingsJson = Get-Content -LiteralPath $cursorSettings -Raw -Encoding utf8 | ConvertFrom-Json
            $ideProxy = [string]$settingsJson.'http.proxy'
            if ($ideProxy) {
                $noProxy = 'localhost,127.0.0.1,.centrofinans.ru,centrofinans.ru,jenkins.centrofinans.ru,gitlab.centrofinans.ru'
                Add-Content -LiteralPath $envFile -Encoding utf8 -Value @(
                    "HTTPS_PROXY=$ideProxy",
                    "HTTP_PROXY=$ideProxy",
                    "ALL_PROXY=$ideProxy",
                    "NO_PROXY=$noProxy"
                )
                Write-Host "Copied http.proxy from Cursor settings into $envFile"
            }
        } catch {
            Write-Host "Could not read Cursor http.proxy: $($_.Exception.Message)"
        }
    }
}

if (-not $SkipCliInstall) {
    Write-Host 'Installing / updating Cursor CLI...'
    irm 'https://cursor.com/install?win32=true' | iex
}

$startScript = Join-Path $WorkspaceRoot 'tools\scripts\start-tb-cursor-worker.ps1'
if (-not (Test-Path -LiteralPath $startScript)) {
    throw "Missing $startScript - sync the TB workspace onto this PC first."
}

$taskName = 'TB-Cursor-Worker'
$arg = "-NoProfile -ExecutionPolicy Bypass -File `"$startScript`""
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -RestartCount 10 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force | Out-Null

Write-Host "Scheduled task '$taskName' registered for logon of $($env:USERNAME)."
Write-Host 'Starting worker once now (leave this window; it stays connected)...'
Start-ScheduledTask -TaskName $taskName
Write-Host "Log: $(Join-Path $cursorDir 'tb-worker.log')"
Write-Host 'After reboot the worker should start with autologin. Check cursor.com/agents -> My Machines.'
