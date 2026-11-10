# TB-PC Cursor My Machines worker diagnostics. ASCII-only for Windows PowerShell 5.1.
# Invoked by diag-tb-cursor-worker.bat. Does not print API keys or proxy passwords.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$lines = New-Object System.Collections.Generic.List[string]

function Add-Line([string]$Text) {
    [void]$lines.Add($Text)
    Write-Host $Text
}

function Scrub([string]$Text) {
    if (-not $Text) { return $Text }
    $t = $Text
    $t = [regex]::Replace($t, '(?i)(api[_-]?key|authorization|bearer|password)\s*[:=]\s*\S+', '$1=***')
    $t = [regex]::Replace($t, 'https?://[^:\s/]+:[^@\s/]+@', 'http://***:***@')
    $t = [regex]::Replace($t, '(?i)(sk-[A-Za-z0-9_-]{10,})', 'sk-***')
    return $t
}

Add-Line ('=== TB-PC worker diagnostics ' + (Get-Date -Format o) + ' ===')
Add-Line ('User=' + $env:USERNAME)
Add-Line ('Computer=' + $env:COMPUTERNAME)
Add-Line ''

Add-Line '--- Scheduled task TB-Cursor-Worker ---'
$task = Get-ScheduledTask -TaskName 'TB-Cursor-Worker' -ErrorAction SilentlyContinue
if (-not $task) {
    Add-Line 'TASK_MISSING'
} else {
    $info = Get-ScheduledTaskInfo -TaskName 'TB-Cursor-Worker' -ErrorAction SilentlyContinue
    Add-Line ('State=' + $task.State)
    Add-Line ('LastTaskResult=' + $info.LastTaskResult)
    Add-Line ('LastRunTime=' + $info.LastRunTime)
    Add-Line ('NextRunTime=' + $info.NextRunTime)
    $act = @($task.Actions | ForEach-Object { $_.Execute + ' ' + $_.Arguments }) -join '; '
    Add-Line ('Action=' + $act)
}

Add-Line ''
Add-Line '--- tb-worker.env keys (values redacted) ---'
$envFile = Join-Path $env:USERPROFILE '.cursor\tb-worker.env'
if (-not (Test-Path -LiteralPath $envFile)) {
    Add-Line ('MISSING ' + $envFile)
} else {
    Add-Line ('Path=' + $envFile)
    Get-Content -LiteralPath $envFile | ForEach-Object {
        $t = $_.Trim()
        if (-not $t -or $t.StartsWith('#')) { return }
        $i = $t.IndexOf('=')
        if ($i -lt 1) { return }
        $k = $t.Substring(0, $i).Trim()
        $v = $t.Substring($i + 1)
        if ($k -match 'KEY|PROXY|PASS|TOKEN') {
            Add-Line ($k + '=<set len=' + $v.Length + '>')
        } else {
            Add-Line ($k + '=' + $v)
        }
    }
}

Add-Line ''
Add-Line '--- cursor-agent binaries ---'
foreach ($p in @(
        (Join-Path $env:LOCALAPPDATA 'cursor-agent\agent.cmd'),
        (Join-Path $env:LOCALAPPDATA 'cursor-agent\agent.exe'),
        (Join-Path $env:USERPROFILE '.local\bin\agent.exe')
    )) {
    if (Test-Path -LiteralPath $p) { Add-Line ('FOUND ' + $p) } else { Add-Line ('MISS  ' + $p) }
}

Add-Line ''
Add-Line '--- node processes with cursor-agent path ---'
$procs = Get-Process -Name node -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like '*cursor-agent*' }
if (-not $procs) {
    Add-Line 'NONE'
} else {
    $procs | ForEach-Object { Add-Line ('PID=' + $_.Id + ' Path=' + $_.Path) }
}

Add-Line ''
Add-Line '--- tb-worker.log tail (secrets scrubbed) ---'
$log = Join-Path $env:USERPROFILE '.cursor\tb-worker.log'
if (-not (Test-Path -LiteralPath $log)) {
    Add-Line ('MISSING ' + $log)
} else {
    Add-Line ('Path=' + $log + ' Size=' + (Get-Item -LiteralPath $log).Length)
    Get-Content -LiteralPath $log -Tail 50 | ForEach-Object { Add-Line (Scrub $_) }
}

Add-Line ''
Add-Line '=== end ==='

$desktop = [Environment]::GetFolderPath('Desktop')
$report = Join-Path $desktop 'tb-worker-diag.txt'
if (-not $desktop -or -not (Test-Path -LiteralPath $desktop)) {
    $report = Join-Path $env:USERPROFILE 'tb-worker-diag.txt'
}
($lines -join [Environment]::NewLine) | Set-Content -LiteralPath $report -Encoding utf8
Add-Line ('Wrote report: ' + $report)
Write-Host ''
Write-Host 'Send tb-worker-diag.txt contents (already redacted).'
Write-Host 'Press Enter to close...'
[void][Console]::ReadLine()
