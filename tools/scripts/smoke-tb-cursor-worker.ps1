# One-shot verbose worker start for TB-PC diagnostics. ASCII-only.
# Writes Desktop\tb-worker-smoke.txt (secrets scrubbed) and restarts scheduled task.

[CmdletBinding()]
param(
    [int]$TimeoutSec = 60
)

$ErrorActionPreference = 'Stop'

function Scrub([string]$Text) {
    if (-not $Text) { return $Text }
    $t = $Text
    $t = [regex]::Replace($t, '(?i)(api[_-]?key|authorization|bearer|password)\s*[:=]\s*\S+', '$1=***')
    $t = [regex]::Replace($t, 'https?://[^:\s/]+:[^@\s/]+@', 'http://***:***@')
    $t = [regex]::Replace($t, '(?i)(sk-[A-Za-z0-9_-]{10,}|crsr_[A-Za-z0-9_-]{10,})', '***')
    return $t
}

function Add-Report([System.Collections.Generic.List[string]]$Lines, [string]$Text) {
    [void]$Lines.Add($Text)
    Write-Host $Text
}

function Invoke-AgentCapture {
    param(
        [string]$AgentCmd,
        [string[]]$AgentArgs,
        [string]$WorkDir,
        [int]$TimeoutSec,
        [string]$OutFile,
        [switch]$LeaveRunningOnTimeout
    )
    if (Test-Path -LiteralPath $OutFile) {
        Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
    }

    $argLine = ($AgentArgs | ForEach-Object {
            if ($_ -match '[\s&<>|^"]') { '"' + ($_ -replace '"', '""') + '"' } else { $_ }
        }) -join ' '

    # cmd quoting: cmd /c ""C:\path\agent.cmd" arg1 arg2 > "out" 2>&1"
    $cmdline = '""' + $AgentCmd + '" ' + $argLine + ' > "' + $OutFile + '" 2>&1"'

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'cmd.exe'
    $psi.Arguments = '/c ' + $cmdline
    $psi.WorkingDirectory = $WorkDir
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()
    if (-not $proc.WaitForExit($TimeoutSec * 1000)) {
        if ($LeaveRunningOnTimeout) {
            # worker start --wait stays up on success; do not kill
            return 'TIMEOUT_LEFT_RUNNING'
        }
        try { $proc.Kill() } catch {}
        Start-Sleep -Milliseconds 500
        return 'TIMEOUT'
    }
    return ('EXIT=' + $proc.ExitCode)
}

function Read-MaybeUnicode([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    try {
        $fs = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
        try {
            $ms = New-Object IO.MemoryStream
            $fs.CopyTo($ms)
            $raw = $ms.ToArray()
        } finally {
            $fs.Dispose()
        }
    } catch {
        return ('(could not read out file: ' + $_.Exception.Message + ')')
    }
    if ($raw.Length -eq 0) { return '' }
    if ($raw.Length -ge 2 -and $raw[1] -eq 0) {
        return [Text.Encoding]::Unicode.GetString($raw)
    }
    if ($raw.Length -ge 2 -and $raw[0] -eq 0xFF -and $raw[1] -eq 0xFE) {
        return [Text.Encoding]::Unicode.GetString($raw, 2, $raw.Length - 2)
    }
    return [Text.Encoding]::UTF8.GetString($raw)
}

$report = New-Object System.Collections.Generic.List[string]
Add-Report $report ('=== TB worker smoke ' + (Get-Date -Format o) + ' ===')
Add-Report $report ('User=' + $env:USERNAME)
Add-Report $report ('Computer=' + $env:COMPUTERNAME)

$envFile = Join-Path $env:USERPROFILE '.cursor\tb-worker.env'
if (-not (Test-Path -LiteralPath $envFile)) { throw "Missing $envFile" }

Get-Content -LiteralPath $envFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq '' -or $line.StartsWith('#')) { return }
    $eq = $line.IndexOf('=')
    if ($eq -lt 1) { return }
    Set-Item -Path ('Env:' + $line.Substring(0, $eq).Trim()) -Value $line.Substring($eq + 1).Trim().Trim('"')
}

if (-not $env:CURSOR_API_KEY) { throw 'CURSOR_API_KEY empty' }
$workspace = $env:TB_WORKSPACE_ROOT
if (-not $workspace) { $workspace = 'D:\Dev Projects\TB' }

Add-Report $report ('Workspace=' + $workspace)
Add-Report $report ('ProxyHost=' + ([uri]$env:HTTPS_PROXY).Host)
Add-Report $report ('ApiKeyLen=' + $env:CURSOR_API_KEY.Length)

# Same as start-tb-cursor-worker: force Node to use env proxy (region 403 fix)
if ($env:HTTPS_PROXY) {
    $env:NODE_USE_ENV_PROXY = '1'
    $env:NODE_TLS_REJECT_UNAUTHORIZED = '0'
    Add-Report $report 'NODE_USE_ENV_PROXY=1'
}

Add-Report $report 'Shell source: CFG_Development git. Yandex overlay is not applied.'

$agentCmd = Join-Path $env:LOCALAPPDATA 'cursor-agent\agent.cmd'
if (-not (Test-Path -LiteralPath $agentCmd)) { throw "Missing $agentCmd" }
Add-Report $report ('AgentCmd=' + $agentCmd)

$dirs = New-Object System.Collections.Generic.List[string]
[void]$dirs.Add((Resolve-Path $workspace).Path)
$manifestPath = Join-Path $workspace 'repos\manifest.yaml'
$manifestText = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8
foreach ($m in [regex]::Matches($manifestText, '(?m)^\s*path:\s*(\S+)\s*$')) {
    $full = Join-Path $workspace (($m.Groups[1].Value.Trim().Trim('"') -replace '/', '\'))
    if (Test-Path (Join-Path $full '.git')) {
        $r = (Resolve-Path $full).Path
        if (-not ($dirs -contains $r)) { [void]$dirs.Add($r) }
    }
}
Add-Report $report ('Dirs=' + $dirs.Count)
foreach ($d in $dirs) { Add-Report $report ('DIR ' + $d) }

Stop-ScheduledTask -TaskName TB-Cursor-Worker -ErrorAction SilentlyContinue
Get-Process -Name node -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like '*cursor-agent*' } |
    Stop-Process -Force -ErrorAction SilentlyContinue

$tmp = Join-Path $env:TEMP 'tb-worker-smoke'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

# 1) help / version probes
Add-Report $report '--- probe: agent --version ---'
$verOut = Join-Path $tmp 'version.log'
$verRes = Invoke-AgentCapture -AgentCmd $agentCmd -AgentArgs @('--version') -WorkDir $workspace -TimeoutSec 30 -OutFile $verOut
Add-Report $report ('Result=' + $verRes)
Add-Report $report (Scrub (Read-MaybeUnicode $verOut))

Add-Report $report '--- probe: agent status ---'
$stOut = Join-Path $tmp 'status.log'
$stRes = Invoke-AgentCapture -AgentCmd $agentCmd -AgentArgs @('status') -WorkDir $workspace -TimeoutSec 30 -OutFile $stOut
Add-Report $report ('Result=' + $stRes)
Add-Report $report (Scrub (Read-MaybeUnicode $stOut))

Add-Report $report '--- probe: agent whoami ---'
$whoOut = Join-Path $tmp 'whoami.log'
$whoRes = Invoke-AgentCapture -AgentCmd $agentCmd -AgentArgs @('whoami') -WorkDir $workspace -TimeoutSec 30 -OutFile $whoOut
Add-Report $report ('Result=' + $whoRes)
Add-Report $report (Scrub (Read-MaybeUnicode $whoOut))

# 2) worker start verbose
$argsList = @('worker', 'start', '--name', 'TB-PC', '--idle-release-timeout', '0', '--verbose', '--wait')
foreach ($d in $dirs) { $argsList += @('--worker-dir', $d) }

Add-Report $report '--- worker start --verbose ---'
Add-Report $report ('Args=' + (($argsList | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '))

$smokeOut = Join-Path $tmp 'worker.log'
$smokeRes = Invoke-AgentCapture -AgentCmd $agentCmd -AgentArgs $argsList -WorkDir $workspace -TimeoutSec $TimeoutSec -OutFile $smokeOut -LeaveRunningOnTimeout
Add-Report $report ('Result=' + $smokeRes)
if ($smokeRes -eq 'TIMEOUT_LEFT_RUNNING') {
    Add-Report $report 'NOTE: timeout with --wait usually means worker stayed up (success). Not killing process.'
}
Add-Report $report '--- agent output (scrubbed) ---'
$agentText = Read-MaybeUnicode $smokeOut
if ([string]::IsNullOrWhiteSpace($agentText)) {
    Add-Report $report '(empty agent output file)'
    Add-Report $report ('OutFileExists=' + (Test-Path $smokeOut) + ' Size=' + ($(if (Test-Path $smokeOut) { (Get-Item $smokeOut).Length } else { 0 })))
} else {
    foreach ($line in ($agentText -split "`r?`n")) {
        if ($line.Trim().Length -gt 0) { Add-Report $report (Scrub $line) }
    }
}

# If worker already connected via this smoke, do not restart task (would disrupt)
$skipRestart = ($smokeRes -eq 'TIMEOUT_LEFT_RUNNING')
$procsAlive = Get-Process -Name node -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like '*cursor-agent*' }
if ($procsAlive) {
    Add-Report $report ('cursor-agent PIDs=' + (($procsAlive | ForEach-Object Id) -join ','))
    $skipRestart = $true
}

# 3) append recent worker log if any
$workerLog = Join-Path $env:USERPROFILE '.cursor\tb-worker.log'
Add-Report $report '--- tb-worker.log tail ---'
if (Test-Path -LiteralPath $workerLog) {
    Get-Content -LiteralPath $workerLog -Tail 40 | ForEach-Object { Add-Report $report (Scrub $_) }
} else {
    Add-Report $report 'MISSING tb-worker.log'
}

$desktop = [Environment]::GetFolderPath('Desktop')
$reportPath = Join-Path $desktop 'tb-worker-smoke.txt'
if (-not $desktop -or -not (Test-Path -LiteralPath $desktop)) {
    $reportPath = Join-Path $env:USERPROFILE 'tb-worker-smoke.txt'
}
($report -join [Environment]::NewLine) | Set-Content -LiteralPath $reportPath -Encoding utf8
Add-Report $report ('Wrote report: ' + $reportPath)

if ($skipRestart) {
    Add-Report $report 'Skip scheduled-task restart: worker process already running from smoke.'
} else {
    Write-Host 'Restarting scheduled task TB-Cursor-Worker...'
    Start-ScheduledTask -TaskName TB-Cursor-Worker -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
}
$task = Get-ScheduledTask -TaskName TB-Cursor-Worker -ErrorAction SilentlyContinue
if ($task) {
    $info = Get-ScheduledTaskInfo -TaskName TB-Cursor-Worker -ErrorAction SilentlyContinue
    Add-Report $report ('TaskState=' + $task.State + ' LastTaskResult=' + $info.LastTaskResult)
}

Write-Host 'Press Enter to close...'
[void][Console]::ReadLine()
