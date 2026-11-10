# Copy Cursor IDE http.proxy into %USERPROFILE%\.cursor\tb-worker.env for My Machines worker.
# Does not print the proxy URL. Safe to run on laptop and TB-PC.
# Docs: docs/setup/cursor-my-machines-worker.md
# ASCII-only for Windows PowerShell 5.1.

[CmdletBinding()]
param(
    [string]$ProxyUrl = '',
    [switch]$RestartWorker
)

$ErrorActionPreference = 'Stop'

$cursorDir = Join-Path $env:USERPROFILE '.cursor'
New-Item -ItemType Directory -Force -Path $cursorDir | Out-Null
$envFile = Join-Path $cursorDir 'tb-worker.env'
if (-not (Test-Path -LiteralPath $envFile)) {
    throw "Missing $envFile - create it via install-tb-cursor-worker.ps1 first"
}

if (-not $ProxyUrl) {
    $cursorSettings = Join-Path $env:APPDATA 'Cursor\User\settings.json'
    if (-not (Test-Path -LiteralPath $cursorSettings)) {
        throw "Pass -ProxyUrl or set http.proxy in $cursorSettings"
    }
    $settingsJson = Get-Content -LiteralPath $cursorSettings -Raw -Encoding utf8 | ConvertFrom-Json
    $ProxyUrl = [string]$settingsJson.'http.proxy'
    if (-not $ProxyUrl) {
        throw "http.proxy is empty in Cursor settings; pass -ProxyUrl"
    }
}

$noProxy = 'localhost,127.0.0.1,.centrofinans.ru,centrofinans.ru,jenkins.centrofinans.ru,gitlab.centrofinans.ru'
$keys = [ordered]@{}
Get-Content -LiteralPath $envFile | ForEach-Object {
    $t = $_.Trim()
    if ($t -eq '' -or $t.StartsWith('#')) { return }
    $eq = $t.IndexOf('=')
    if ($eq -lt 1) { return }
    $keys[$t.Substring(0, $eq).Trim()] = $t.Substring($eq + 1).Trim()
}

$keys['HTTPS_PROXY'] = $ProxyUrl
$keys['HTTP_PROXY'] = $ProxyUrl
$keys['ALL_PROXY'] = $ProxyUrl
$keys['NO_PROXY'] = $noProxy

$order = @(
    'CURSOR_API_KEY',
    'TB_WORKER_NAME',
    'TB_WORKSPACE_ROOT',
    'TB_WORKER_DIR',
    'HTTPS_PROXY',
    'HTTP_PROXY',
    'ALL_PROXY',
    'NO_PROXY'
)
$out = New-Object System.Collections.Generic.List[string]
foreach ($k in $order) {
    if ($keys.Contains($k) -and $keys[$k]) {
        [void]$out.Add("$k=$($keys[$k])")
        $keys.Remove($k)
    }
}
foreach ($k in @($keys.Keys)) {
    if ($keys[$k]) { [void]$out.Add("$k=$($keys[$k])") }
}
$out | Set-Content -LiteralPath $envFile -Encoding utf8
Write-Host ("Updated proxy in {0} (host={1})" -f $envFile, ([uri]$ProxyUrl).Host)

if (-not (Select-String -Path $envFile -Pattern '^CURSOR_API_KEY=' -Quiet)) {
    throw "Refusing to continue: CURSOR_API_KEY missing in $envFile after proxy update. Run repair-tb-cursor-worker-env.bat"
}

$workspaceFromEnv = $null
Get-Content -LiteralPath $envFile | ForEach-Object {
    $t = $_.Trim()
    if ($t.StartsWith('TB_WORKSPACE_ROOT=')) {
        $workspaceFromEnv = $t.Substring('TB_WORKSPACE_ROOT='.Length).Trim().Trim('"')
    }
}

function Ensure-TbCursorWorkerTask {
    $taskName = 'TB-Cursor-Worker'
    $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existing) { return $true }

    $workspace = $script:workspaceFromEnv
    if (-not $workspace -or -not (Test-Path -LiteralPath $workspace)) {
        foreach ($c in @('D:\Dev Projects\TB', 'D:\Codex Projects\TB')) {
            if (Test-Path -LiteralPath (Join-Path $c 'tools\scripts\start-tb-cursor-worker.ps1')) {
                $workspace = $c
                break
            }
        }
    }
    if (-not $workspace) {
        Write-Host 'WARN: cannot register TB-Cursor-Worker - workspace not found'
        return $false
    }

    $startScript = Join-Path $workspace 'tools\scripts\start-tb-cursor-worker.ps1'
    if (-not (Test-Path -LiteralPath $startScript)) {
        Write-Host "WARN: missing $startScript"
        return $false
    }

    Write-Host "Scheduled task $taskName not found - registering..."
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
    Write-Host "Registered scheduled task $taskName"
    return $true
}

if ($RestartWorker) {
    Get-Process -Name node -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -like '*cursor-agent*' } |
        Stop-Process -Force -ErrorAction SilentlyContinue

    $ok = Ensure-TbCursorWorkerTask
    if (-not $ok) {
        throw 'TB-Cursor-Worker task missing and could not be registered'
    }

    Stop-ScheduledTask -TaskName TB-Cursor-Worker -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-ScheduledTask -TaskName TB-Cursor-Worker
    Write-Host 'Scheduled task TB-Cursor-Worker started'
}
