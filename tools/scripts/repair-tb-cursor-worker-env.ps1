# Explicit repair of TB-PC tb-worker.env from secrets already stored under Yandex _AI.
# Does not copy rules or scripts. Those come from the CFG_Development git clone.
# ASCII-only for Windows PowerShell 5.1. Does not print secrets.

[CmdletBinding()]
param(
    [string]$AiRoot = '',
    [string]$WorkspaceRoot = 'D:\Dev Projects\TB'
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
    throw 'Yandex _AI folder not found (and Find-TbYandexAiDir.ps1 missing)'
}

function Read-SecretFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $raw = (Get-Content -LiteralPath $Path -Raw -Encoding utf8)
    if (-not $raw) { return $null }
    return $raw.Trim().Trim('"')
}

$AiRoot = Find-AiRoot -Hint $AiRoot
$bundle = Join-Path $AiRoot 'TB-workspace'
$secrets = Join-Path $bundle 'secrets'
Write-Step "AI root: $AiRoot"

$cursorDir = Join-Path $env:USERPROFILE '.cursor'
New-Item -ItemType Directory -Force -Path $cursorDir | Out-Null
$envFile = Join-Path $cursorDir 'tb-worker.env'

$keys = [ordered]@{}
if (Test-Path -LiteralPath $envFile) {
    Get-Content -LiteralPath $envFile | ForEach-Object {
        $t = $_.Trim()
        if ($t -eq '' -or $t.StartsWith('#')) { return }
        $eq = $t.IndexOf('=')
        if ($eq -lt 1) { return }
        $keys[$t.Substring(0, $eq).Trim()] = $t.Substring($eq + 1).Trim()
    }
}

$apiKey = $null
if ($keys.Contains('CURSOR_API_KEY') -and $keys['CURSOR_API_KEY']) {
    $apiKey = $keys['CURSOR_API_KEY']
    Write-Step 'CURSOR_API_KEY already present in tb-worker.env'
} else {
    $apiKey = Read-SecretFile (Join-Path $secrets 'cursor-api-key.txt')
    if (-not $apiKey) {
        throw "CURSOR_API_KEY missing. Put key into $secrets\cursor-api-key.txt (one line) and re-run."
    }
    Write-Step 'CURSOR_API_KEY restored from _AI secrets'
}

$proxyUrl = $null
if ($keys.Contains('HTTPS_PROXY') -and $keys['HTTPS_PROXY']) {
    $proxyUrl = $keys['HTTPS_PROXY']
} else {
    $proxyUrl = Read-SecretFile (Join-Path $secrets 'cursor-https-proxy.url')
}
if (-not $proxyUrl) {
    $cursorSettings = Join-Path $env:APPDATA 'Cursor\User\settings.json'
    if (Test-Path -LiteralPath $cursorSettings) {
        $settingsJson = Get-Content -LiteralPath $cursorSettings -Raw -Encoding utf8 | ConvertFrom-Json
        $proxyUrl = [string]$settingsJson.'http.proxy'
    }
}
if (-not $proxyUrl) {
    throw "HTTPS_PROXY missing. Need $secrets\cursor-https-proxy.url"
}
Write-Step ("Proxy host: {0}" -f ([uri]$proxyUrl).Host)

if (-not (Test-Path -LiteralPath $WorkspaceRoot)) {
    foreach ($c in @('D:\Dev Projects\TB', 'D:\Codex Projects\TB')) {
        if (Test-Path -LiteralPath (Join-Path $c 'repos\manifest.yaml')) {
            $WorkspaceRoot = $c
            break
        }
    }
}

$noProxy = 'localhost,127.0.0.1,.centrofinans.ru,centrofinans.ru,jenkins.centrofinans.ru,gitlab.centrofinans.ru'
$keys['CURSOR_API_KEY'] = $apiKey
$keys['TB_WORKER_NAME'] = 'TB-PC'
$keys['TB_WORKSPACE_ROOT'] = $WorkspaceRoot
$keys['TB_WORKER_DIR'] = $WorkspaceRoot
$keys['HTTPS_PROXY'] = $proxyUrl
$keys['HTTP_PROXY'] = $proxyUrl
$keys['ALL_PROXY'] = $proxyUrl
$keys['NO_PROXY'] = $noProxy

$order = @('CURSOR_API_KEY', 'TB_WORKER_NAME', 'TB_WORKSPACE_ROOT', 'TB_WORKER_DIR', 'HTTPS_PROXY', 'HTTP_PROXY', 'ALL_PROXY', 'NO_PROXY')
$out = New-Object System.Collections.Generic.List[string]
foreach ($k in $order) {
    if ($keys.Contains($k) -and $keys[$k]) {
        [void]$out.Add("$k=$($keys[$k])")
        $keys.Remove($k)
    }
}
foreach ($k in @($keys.Keys)) {
    if ($k -eq 'no_proxy') { continue }
    if ($keys[$k]) { [void]$out.Add("$k=$($keys[$k])") }
}
$out | Set-Content -LiteralPath $envFile -Encoding utf8
Write-Step ("Wrote $envFile (CURSOR_API_KEY len={0})" -f $apiKey.Length)

# Shell files stay on CFG_Development. This repair does not copy the Yandex overlay.

$applyScript = Join-Path $WorkspaceRoot 'tools\scripts\apply-tb-worker-proxy-from-cursor-settings.ps1'
if (Test-Path -LiteralPath $applyScript) {
    Write-Step 'Ensure task + restart worker...'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $applyScript `
        -ProxyUrl $proxyUrl -RestartWorker
    if ($LASTEXITCODE -ne 0) { throw "apply/restart failed exit $LASTEXITCODE" }
} else {
    throw "Missing $applyScript"
}

Start-Sleep -Seconds 5
$task = Get-ScheduledTask -TaskName 'TB-Cursor-Worker' -ErrorAction SilentlyContinue
if ($task) {
    Write-Step ("Task state: {0}" -f $task.State)
    $info = Get-ScheduledTaskInfo -TaskName 'TB-Cursor-Worker' -ErrorAction SilentlyContinue
    Write-Step ("LastTaskResult: {0}" -f $info.LastTaskResult)
}
$log = Join-Path $env:USERPROFILE '.cursor\tb-worker.log'
if (Test-Path -LiteralPath $log) {
    Write-Step "Tail of log:"
    Get-Content -LiteralPath $log -Tail 20
} else {
    Write-Step "Log still missing: $log"
}

$procs = Get-Process -Name node -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like '*cursor-agent*' }
if ($procs) {
    Write-Step ('cursor-agent node PIDs: ' + (($procs | ForEach-Object { $_.Id }) -join ','))
} else {
    Write-Step 'WARN: no cursor-agent node process yet'
}

Write-Step 'Done. Re-run diag-tb-cursor-worker.bat and/or check cursor.com/agents.'
Write-Host 'Press Enter to close...'
[void][Console]::ReadLine()
