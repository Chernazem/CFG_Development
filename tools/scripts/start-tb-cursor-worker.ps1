# Long-lived Cursor My Machines worker for the TB contour PC.
# Used by Scheduled Task "TB-Cursor-Worker" after autologin / reboot.
# Workspace root is the assignment directory (multi-repo TB). Extra
# --worker-dir only for repos listed in repos/manifest.yaml (not DEV-* worktrees).
# ASCII-only for Windows PowerShell 5.1.

$ErrorActionPreference = 'Stop'

$envFile = Join-Path $env:USERPROFILE '.cursor\tb-worker.env'
$logDir = Join-Path $env:USERPROFILE '.cursor'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir 'tb-worker.log'

function Write-WorkerLog([string]$Message) {
    "$(Get-Date -Format o) $Message" | Add-Content -LiteralPath $log -Encoding utf8
}

if (-not (Test-Path -LiteralPath $envFile)) {
    Write-WorkerLog "FATAL missing env file: $envFile"
    throw "Missing $envFile - see docs/setup/cursor-my-machines-worker.md"
}

Get-Content -LiteralPath $envFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq '' -or $line.StartsWith('#')) { return }
    $eq = $line.IndexOf('=')
    if ($eq -lt 1) { return }
    $name = $line.Substring(0, $eq).Trim()
    $value = $line.Substring($eq + 1).Trim().Trim('"')
    Set-Item -Path "Env:$name" -Value $value
}

if (-not $env:CURSOR_API_KEY) {
    Write-WorkerLog 'FATAL CURSOR_API_KEY is empty in tb-worker.env'
    throw 'CURSOR_API_KEY is empty in tb-worker.env'
}

$workerName = if ($env:TB_WORKER_NAME) { $env:TB_WORKER_NAME } else { 'TB-PC' }
$workerDir = if ($env:TB_WORKER_DIR) { $env:TB_WORKER_DIR } else { $env:TB_WORKSPACE_ROOT }
if (-not $workerDir) { throw 'Set TB_WORKER_DIR or TB_WORKSPACE_ROOT in tb-worker.env' }
if (-not (Test-Path -LiteralPath $workerDir)) { throw "Worker dir not found: $workerDir" }

$agentCmd = $null
foreach ($candidate in @(
        (Join-Path $env:LOCALAPPDATA 'cursor-agent\agent.cmd'),
        (Join-Path $env:USERPROFILE '.local\bin\agent.exe'),
        (Join-Path $env:LOCALAPPDATA 'cursor-agent\agent.exe')
    )) {
    if ($candidate -and (Test-Path -LiteralPath $candidate)) {
        $agentCmd = $candidate
        break
    }
}
if (-not $agentCmd) { throw 'Cursor CLI agent not found. Run install-tb-cursor-worker.ps1 first.' }

# Only root + manifest repos (conf-main / extensions / api-swagger). Skip DEV-* worktrees.
$workerDirs = New-Object System.Collections.Generic.List[string]
[void]$workerDirs.Add((Resolve-Path -LiteralPath $workerDir).Path)
$manifestPath = Join-Path $workerDir 'repos\manifest.yaml'
if (Test-Path -LiteralPath $manifestPath) {
    $manifestText = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8
    $pathMatches = [regex]::Matches($manifestText, '(?m)^\s*path:\s*(\S+)\s*$')
    foreach ($m in $pathMatches) {
        $rel = $m.Groups[1].Value.Trim().Trim('"').Trim("'")
        $full = Join-Path $workerDir ($rel -replace '/', '\')
        $git = Join-Path $full '.git'
        if ((Test-Path -LiteralPath $full) -and (Test-Path -LiteralPath $git)) {
            $resolved = (Resolve-Path -LiteralPath $full).Path
            if (-not ($workerDirs -contains $resolved)) {
                [void]$workerDirs.Add($resolved)
            }
        } else {
            Write-WorkerLog "WARN skip manifest path (missing or no .git): $full"
        }
    }
} else {
    Write-WorkerLog "WARN missing $manifestPath - worker-dir root only"
}

$dirsJoined = [string]::Join('; ', $workerDirs)
Write-WorkerLog "starting worker name=$workerName agent=$agentCmd dirs=$dirsJoined"
foreach ($d in $workerDirs) {
    $origin = ''
    try {
        $origin = (& git -C $d remote get-url origin 2>$null)
        if ($LASTEXITCODE -ne 0) { $origin = '(no git origin)' }
    } catch {
        $origin = '(git unavailable)'
    }
    if (-not $origin) { $origin = '(no git origin)' }
    Write-WorkerLog "worker-dir $d origin=$origin"
}

# Never show Git Credential Manager UI to agents (SCREEN blocker on gitlab/jenkins).
# Secrets must already be in Windows CredMan for this Windows user — see docs/setup/tb-pc-git-credentials.md
$env:GCM_INTERACTIVE = 'never'
$env:GIT_TERMINAL_PROMPT = '0'
$env:GCM_MODAL_PROMPT = 'false'
$env:GIT_ASKPASS = ''
Remove-Item Env:SSH_ASKPASS -ErrorAction SilentlyContinue
Write-WorkerLog 'GCM non-interactive: GCM_INTERACTIVE=never GIT_TERMINAL_PROMPT=0'

# Cursor Cloud / My Machines: go through corporate outbound proxy when set in tb-worker.env.
# Internal centrofinans hosts stay on VPN via NO_PROXY (do not send them to proxy-ext).
$proxyUrl = $env:HTTPS_PROXY
if (-not $proxyUrl) { $proxyUrl = $env:HTTP_PROXY }
if (-not $proxyUrl) { $proxyUrl = $env:ALL_PROXY }
$noProxyDefault = 'localhost,127.0.0.1,.centrofinans.ru,centrofinans.ru,jenkins.centrofinans.ru,gitlab.centrofinans.ru'
if ($proxyUrl) {
    $env:HTTPS_PROXY = $proxyUrl
    $env:HTTP_PROXY = $proxyUrl
    $env:ALL_PROXY = $proxyUrl
    $env:https_proxy = $proxyUrl
    $env:http_proxy = $proxyUrl
    $env:all_proxy = $proxyUrl
    if (-not $env:NO_PROXY) { $env:NO_PROXY = $noProxyDefault }
    if (-not $env:no_proxy) { $env:no_proxy = $env:NO_PROXY }
    # Force Node/undici (cursor-agent) to honor HTTP(S)_PROXY. Without this,
    # worker auth may work while liveness hits api2.cursor.sh directly and gets region 403.
    $env:NODE_USE_ENV_PROXY = '1'
    $env:NODE_TLS_REJECT_UNAUTHORIZED = '0'
    Write-WorkerLog ("proxy enabled host={0} no_proxy={1} NODE_USE_ENV_PROXY=1" -f ([uri]$proxyUrl).Host, $env:NO_PROXY)
} else {
    foreach ($n in 'HTTPS_PROXY', 'HTTP_PROXY', 'ALL_PROXY', 'https_proxy', 'http_proxy', 'all_proxy') {
        Remove-Item "Env:$n" -ErrorAction SilentlyContinue
    }
    Write-WorkerLog 'proxy not set in tb-worker.env - cleared process proxy env'
}

$agentArgs = @(
    'worker', 'start',
    '--name', $workerName,
    '--idle-release-timeout', '0',
    '--verbose',
    '--wait'
)
foreach ($d in $workerDirs) {
    $agentArgs += @('--worker-dir', $d)
}

Write-WorkerLog ("exec: `"$agentCmd`" " + ($agentArgs -join ' '))
Set-Location -LiteralPath $workerDir

# Capture mixed stdout/stderr; agent.cmd may emit UTF-16-ish console text.
$outFile = Join-Path $logDir 'tb-worker-agent-out.log'
if (Test-Path -LiteralPath $outFile) {
    Remove-Item -LiteralPath $outFile -Force -ErrorAction SilentlyContinue
}

$argLine = ($agentArgs | ForEach-Object {
        if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
    }) -join ' '

$cmd = "`"$agentCmd`" $argLine"
cmd.exe /c "$cmd > `"$outFile`" 2>&1"
$exitCode = $LASTEXITCODE
Write-WorkerLog ("agent exited code=$exitCode out=$outFile")
if (Test-Path -LiteralPath $outFile) {
    try {
        $raw = [IO.File]::ReadAllBytes($outFile)
        $text = $null
        if ($raw.Length -ge 2 -and $raw[1] -eq 0) {
            $text = [Text.Encoding]::Unicode.GetString($raw)
        } else {
            $text = [Text.Encoding]::UTF8.GetString($raw)
        }
        foreach ($line in ($text -split "`r?`n")) {
            if ($line.Trim().Length -gt 0) {
                Write-WorkerLog ('agent: ' + $line.Trim())
            }
        }
    } catch {
        Write-WorkerLog ("WARN could not decode agent out: " + $_.Exception.Message)
    }
}

exit $exitCode
