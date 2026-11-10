# Fix TB-PC worker region 403: force Node env proxy + HTTP/1.1 for agent, restart worker.
# Root cause: liveness hits api2.cursor.sh directly (RU) while HTTPS_PROXY is ignored.
# ASCII-only for Windows PowerShell 5.1.

[CmdletBinding()]
param(
    [string]$AiRoot = ''
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
    $settingsGlob = Join-Path $env:LOCALAPPDATA 'Yandex\Yandex.Disk.2\*\settings.xml'
    foreach ($f in @(Get-ChildItem -Path $settingsGlob -ErrorAction SilentlyContinue)) {
        [xml]$xml = Get-Content -LiteralPath $f.FullName -Encoding UTF8
        if ($xml.Settings.SyncFolder) {
            $ai = Join-Path $xml.Settings.SyncFolder '_AI'
            if (Test-Path -LiteralPath $ai) { return (Resolve-Path -LiteralPath $ai).Path }
        }
    }
    $helper = Join-Path $PSScriptRoot 'Find-TbYandexAiDir.ps1'
    if (Test-Path -LiteralPath $helper) {
        . $helper
        return Find-TbYandexAiDir
    }
    foreach ($c in @('D:\YandexDisk\_AI', (Join-Path $env:USERPROFILE 'YandexDisk\_AI'))) {
        if (Test-Path -LiteralPath $c) { return (Resolve-Path -LiteralPath $c).Path }
    }
    throw 'Yandex _AI not found. Set TB_YANDEX_AI e.g. D:\YandexDisk_a.kuznecov@ftech.io\_AI'
}

$AiRoot = Find-AiRoot -Hint $AiRoot
Write-Step "AI root: $AiRoot"

$envFile = Join-Path $env:USERPROFILE '.cursor\tb-worker.env'
if (-not (Test-Path -LiteralPath $envFile)) { throw "Missing $envFile" }

$keys = [ordered]@{}
Get-Content -LiteralPath $envFile | ForEach-Object {
    $t = $_.Trim()
    if ($t -eq '' -or $t.StartsWith('#')) { return }
    $eq = $t.IndexOf('=')
    if ($eq -lt 1) { return }
    $keys[$t.Substring(0, $eq).Trim()] = $t.Substring($eq + 1).Trim()
}
if (-not $keys['CURSOR_API_KEY']) { throw 'CURSOR_API_KEY missing in tb-worker.env' }
if (-not $keys['HTTPS_PROXY']) { throw 'HTTPS_PROXY missing in tb-worker.env' }

$keys['NODE_USE_ENV_PROXY'] = '1'
$keys['NODE_TLS_REJECT_UNAUTHORIZED'] = '0'
$order = @(
    'CURSOR_API_KEY', 'TB_WORKER_NAME', 'TB_WORKSPACE_ROOT', 'TB_WORKER_DIR',
    'HTTPS_PROXY', 'HTTP_PROXY', 'ALL_PROXY', 'NO_PROXY',
    'NODE_USE_ENV_PROXY', 'NODE_TLS_REJECT_UNAUTHORIZED'
)
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
Write-Step 'tb-worker.env: NODE_USE_ENV_PROXY=1 added'

# Force HTTP/1.1 path for agent (better proxy support)
$cliConfig = Join-Path $env:USERPROFILE '.cursor\cli-config.json'
if (Test-Path -LiteralPath $cliConfig) {
    $json = Get-Content -LiteralPath $cliConfig -Raw -Encoding utf8 | ConvertFrom-Json
} else {
    $json = [pscustomobject]@{ version = 1 }
}
if (-not $json.network) {
    $json | Add-Member -NotePropertyName network -NotePropertyValue ([pscustomobject]@{}) -Force
}
$json.network | Add-Member -NotePropertyName useHttp1ForAgent -NotePropertyValue $true -Force
$enc = New-Object System.Text.UTF8Encoding $false
[IO.File]::WriteAllText($cliConfig, ($json | ConvertTo-Json -Depth 8), $enc)
Write-Step 'cli-config.json: network.useHttp1ForAgent=true'

$workspace = $keys['TB_WORKSPACE_ROOT']
if (-not $workspace) { $workspace = 'D:\Dev Projects\TB' }
# keys may have removed TB_WORKSPACE_ROOT - reread
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^TB_WORKSPACE_ROOT=(.+)$') { $workspace = $Matches[1].Trim() }
}

$syncScript = Join-Path $AiRoot 'TB-workspace\overlay\tools\scripts\sync-tb-workspace-yandex.ps1'
if (Test-Path -LiteralPath $syncScript) {
    Write-Step 'Applying overlay (updated start-tb-cursor-worker.ps1)...'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $syncScript `
        -Action Apply -WorkspaceRoot $workspace -YandexAiDir $AiRoot
}

# User-level env so child processes definitely see proxy even if script misses one
[Environment]::SetEnvironmentVariable('HTTPS_PROXY', (Get-Content $envFile | Where-Object { $_ -match '^HTTPS_PROXY=' } | ForEach-Object { $_.Substring(12) } | Select-Object -First 1), 'User')
[Environment]::SetEnvironmentVariable('HTTP_PROXY', (Get-Content $envFile | Where-Object { $_ -match '^HTTP_PROXY=' } | ForEach-Object { $_.Substring(11) } | Select-Object -First 1), 'User')
[Environment]::SetEnvironmentVariable('ALL_PROXY', (Get-Content $envFile | Where-Object { $_ -match '^ALL_PROXY=' } | ForEach-Object { $_.Substring(10) } | Select-Object -First 1), 'User')
[Environment]::SetEnvironmentVariable('NODE_USE_ENV_PROXY', '1', 'User')
[Environment]::SetEnvironmentVariable('NO_PROXY', 'localhost,127.0.0.1,.centrofinans.ru,centrofinans.ru,jenkins.centrofinans.ru,gitlab.centrofinans.ru', 'User')
Write-Step 'User env: HTTPS_PROXY / NODE_USE_ENV_PROXY set (new processes inherit)'

Write-Step 'Restarting TB-Cursor-Worker...'
Stop-ScheduledTask -TaskName TB-Cursor-Worker -ErrorAction SilentlyContinue
Get-Process -Name node -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like '*cursor-agent*' } |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

$apply = Join-Path $workspace 'tools\scripts\apply-tb-worker-proxy-from-cursor-settings.ps1'
$proxyUrl = (Get-Content $envFile | Where-Object { $_ -match '^HTTPS_PROXY=' } | ForEach-Object { $_.Substring(12) } | Select-Object -First 1)
if (Test-Path $apply) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $apply -ProxyUrl $proxyUrl -RestartWorker
} else {
    Start-ScheduledTask -TaskName TB-Cursor-Worker
}

Start-Sleep -Seconds 8
$task = Get-ScheduledTask -TaskName TB-Cursor-Worker -ErrorAction SilentlyContinue
if ($task) {
    $info = Get-ScheduledTaskInfo -TaskName TB-Cursor-Worker
    Write-Step ("Task state={0} LastTaskResult={1}" -f $task.State, $info.LastTaskResult)
}
$log = Join-Path $env:USERPROFILE '.cursor\tb-worker.log'
if (Test-Path $log) {
    Write-Step 'Log tail:'
    Get-Content $log -Tail 25
}
$procs = Get-Process -Name node -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*cursor-agent*' }
if ($procs) {
    Write-Step ('cursor-agent running PIDs=' + (($procs | ForEach-Object Id) -join ','))
} else {
    Write-Step 'WARN: no cursor-agent process - re-run smoke-tb-cursor-worker.bat'
}

Write-Step 'Done.'
Write-Host 'Press Enter to close...'
[void][Console]::ReadLine()
