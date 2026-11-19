# Fast-forward the workspace shell to origin/main of CFG_Development.
# Does not touch product repos under repos/ and does not discard local edits.
# Exit 0: this machine matches origin/main (already, or after pull).
# Exit 2: origin/main has commits this tree cannot fast-forward.
# Exit 1: fetch or git failed.
# Docs: docs/setup/shell-sync.md

[CmdletBinding()]
param(
    [string]$WorkspaceRoot = ''
)

$ErrorActionPreference = 'Stop'

function Resolve-WorkspaceRoot {
    param([string]$Hint)
    if ($Hint) {
        if (-not (Test-Path -LiteralPath $Hint)) { throw "Workspace not found: $Hint" }
        return (Resolve-Path -LiteralPath $Hint).Path
    }
    $here = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    if (Test-Path -LiteralPath (Join-Path $here '.git')) {
        return (Resolve-Path -LiteralPath $here).Path
    }
    throw 'Pass -WorkspaceRoot. Script could not find the workspace root.'
}

function Invoke-Git {
    param([string[]]$Arguments)
    & git -C $root @Arguments
    if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed with exit $LASTEXITCODE" }
}

$root = Resolve-WorkspaceRoot $WorkspaceRoot
$originUrl = (& git -C $root remote get-url origin 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $originUrl) { throw "No origin in $root" }
if ($originUrl -notmatch 'CFG_Development') {
    throw "origin is not CFG_Development: $originUrl"
}

Write-Host "SHELL_SYNC root=$root"
Write-Host "SHELL_SYNC origin=$originUrl"
Invoke-Git @('fetch', 'origin', 'main')

$counts = (& git -C $root rev-list --left-right --count 'HEAD...origin/main')
if ($LASTEXITCODE -ne 0) { throw 'Cannot compare HEAD with origin/main' }
$parts = @($counts.Trim() -split '\s+')
$ahead = [int]$parts[0]
$behind = [int]$parts[1]
$head = (& git -C $root rev-parse --short HEAD).Trim()
$remote = (& git -C $root rev-parse --short 'origin/main').Trim()
Write-Host "SHELL_SYNC ahead=$ahead behind=$behind head=$head origin_main=$remote"

$porcelain = @(& git -C $root status --porcelain)
$trackedDirty = @($porcelain | Where-Object { $_ -and ($_ -notmatch '^\?\?') })

if ($behind -gt 0 -and ($ahead -gt 0 -or $trackedDirty.Count -gt 0)) {
    Write-Host 'SHELL_SYNC blocked: origin/main is ahead and this tree cannot fast-forward'
    if ($trackedDirty.Count -gt 0) {
        Write-Host 'SHELL_SYNC tracked changes:'
        $trackedDirty | Select-Object -First 20 | ForEach-Object { Write-Host $_ }
    }
    exit 2
}

if ($behind -gt 0) {
    Invoke-Git @('pull', '--ff-only', 'origin', 'main')
    $head = (& git -C $root rev-parse --short HEAD).Trim()
    Write-Host "SHELL_SYNC pulled head=$head"
}

$stampDir = Join-Path $root '.local-ci'
if (-not (Test-Path -LiteralPath $stampDir)) {
    New-Item -ItemType Directory -Path $stampDir | Out-Null
}
$stampPath = Join-Path $stampDir 'cfg-development-sync.txt'
$checkedAt = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
$machine = $env:COMPUTERNAME
@(
    "checked_at_utc=$checkedAt"
    "machine=$machine"
    "head=$head"
    "origin_main=$remote"
    "ahead=$ahead"
    "behind=0"
) | Set-Content -LiteralPath $stampPath -Encoding ASCII
Write-Host "SHELL_SYNC ok stamp=$stampPath"
exit 0
