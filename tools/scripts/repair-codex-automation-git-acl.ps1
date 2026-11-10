param(
    [string]$WorkspaceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$ProblemSid = 'S-1-5-21-2994193773-3879609815-543980735-1115835159',
    [switch]$RemoveStaleLocks,
    [switch]$FixPackFiles,
    [switch]$VerifyGit
)

$ErrorActionPreference = 'Continue'

$sid = [System.Security.Principal.SecurityIdentifier]$ProblemSid
$reposRoot = Join-Path $WorkspaceRoot 'repos'

function Resolve-GitDir {
    param([Parameter(Mandatory = $true)][string]$RepoPath)

    $gitPath = Join-Path $RepoPath '.git'
    if (-not (Test-Path -LiteralPath $gitPath)) {
        return $null
    }

    $gitItem = Get-Item -LiteralPath $gitPath -Force
    if ($gitItem.PSIsContainer) {
        return $gitItem.FullName
    }

    $gitFile = Get-Content -LiteralPath $gitItem.FullName -TotalCount 1
    if ($gitFile -match '^gitdir:\s*(.+)$') {
        $gitDir = $Matches[1].Trim()
        if ([System.IO.Path]::IsPathRooted($gitDir)) {
            return (Resolve-Path -LiteralPath $gitDir).Path
        }

        return (Resolve-Path -LiteralPath (Join-Path $RepoPath $gitDir)).Path
    }

    return $null
}

function Remove-DenyForSid {
    param(
        [Parameter(Mandatory = $true)][string]$LiteralPath,
        [Parameter(Mandatory = $true)][System.Security.Principal.SecurityIdentifier]$Sid,
        [switch]$ProtectAcl
    )

    $item = Get-Item -LiteralPath $LiteralPath -Force -ErrorAction Stop
    if ($item.PSIsContainer) {
        $fsItem = [System.IO.DirectoryInfo]::new($item.FullName)
    } else {
        $fsItem = [System.IO.FileInfo]::new($item.FullName)
    }

    $acl = $fsItem.GetAccessControl([System.Security.AccessControl.AccessControlSections]::Access)
    $rules = @($acl.GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier]) |
        Where-Object { $_.IdentityReference -eq $Sid -and $_.AccessControlType -eq 'Deny' })

    foreach ($rule in $rules) {
        [void]$acl.RemoveAccessRuleSpecific($rule)
    }

    if ($ProtectAcl) {
        $acl.SetAccessRuleProtection($true, $true)
    }

    if ($rules.Count -gt 0 -or $ProtectAcl) {
        $fsItem.SetAccessControl($acl)
    }

    [pscustomobject]@{
        Path = $item.FullName
        RemovedDeny = $rules.Count
        Protected = if ($item.PSIsContainer) { $acl.AreAccessRulesProtected } else { $null }
        Error = $null
    }
}

function Test-GitWrite {
    param([Parameter(Mandatory = $true)][string]$GitDir)

    $testFile = Join-Path $GitDir 'codex_acl_write_test.tmp'
    Set-Content -LiteralPath $testFile -Value 'acl test' -Encoding ASCII -ErrorAction Stop
    Remove-Item -LiteralPath $testFile -Force -ErrorAction Stop
}

function Remove-StaleGitLocks {
    param([Parameter(Mandatory = $true)][string]$GitDir)

    $removed = 0
    $gitProcesses = @(Get-Process | Where-Object { $_.ProcessName -match '^(git|git-lfs|ssh|sh)$' })
    if ($gitProcesses.Count -gt 0) {
        return [pscustomobject]@{ Removed = 0; Skipped = $true; Reason = 'active git-like process found' }
    }

    $locks = New-Object System.Collections.Generic.List[string]
    $mainLock = Join-Path $GitDir 'index.lock'
    if (Test-Path -LiteralPath $mainLock) {
        $locks.Add($mainLock)
    }

    $worktreesDir = Join-Path $GitDir 'worktrees'
    if (Test-Path -LiteralPath $worktreesDir) {
        Get-ChildItem -LiteralPath $worktreesDir -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
            $lock = Join-Path $_.FullName 'index.lock'
            if (Test-Path -LiteralPath $lock) {
                $locks.Add($lock)
            }
        }
    }

    foreach ($lock in $locks) {
        Remove-Item -LiteralPath $lock -Force -ErrorAction Stop
        $removed++
    }

    [pscustomobject]@{ Removed = $removed; Skipped = $false; Reason = $null }
}

if (-not (Test-Path -LiteralPath $reposRoot)) {
    throw "repos directory not found: $reposRoot"
}

$rows = New-Object System.Collections.Generic.List[object]
$repos = Get-ChildItem -LiteralPath $reposRoot -Directory -Force |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName '.git') } |
    Sort-Object Name

foreach ($repo in $repos) {
    $gitDir = Resolve-GitDir -RepoPath $repo.FullName
    $row = [ordered]@{
        Repo = $repo.Name
        GitDir = $gitDir
        Skipped = $false
        GitDenyRemoved = $null
        GitProtected = $null
        PackDenyRemoved = 0
        LocksRemoved = 0
        WriteTest = $false
        GitDryRun = $null
        Warning = $null
        Error = $null
    }

    if (-not $gitDir) {
        $row.Error = 'cannot resolve .git directory'
        $rows.Add([pscustomobject]$row)
        continue
    }

    if (-not (Test-Path -LiteralPath (Join-Path $gitDir 'HEAD'))) {
        $row.Skipped = $true
        $row.Error = 'invalid .git directory, skipped'
        $rows.Add([pscustomobject]$row)
        continue
    }

    try {
        try {
        $fix = Remove-DenyForSid -LiteralPath $gitDir -Sid $sid -ProtectAcl
        $row.GitDenyRemoved = $fix.RemovedDeny
        $row.GitProtected = $fix.Protected
        } catch {
            $row.Warning = "git ACL was not changed: $($_.Exception.Message)"
        }

        if ($FixPackFiles) {
            $packDir = Join-Path $gitDir 'objects\pack'
            if (Test-Path -LiteralPath $packDir) {
                Get-ChildItem -LiteralPath $packDir -Filter 'pack-*.pack' -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
                    try {
                        $packFix = Remove-DenyForSid -LiteralPath $_.FullName -Sid $sid -ProtectAcl
                        $row.PackDenyRemoved += $packFix.RemovedDeny
                    } catch {
                        $row.Warning = "pack ACL $($_.FullName): $($_.Exception.Message)"
                    }
                }
            }
        }

        Test-GitWrite -GitDir $gitDir
        $row.WriteTest = $true

        if ($RemoveStaleLocks) {
            $lockResult = Remove-StaleGitLocks -GitDir $gitDir
            $row.LocksRemoved = $lockResult.Removed
            if ($lockResult.Skipped) {
                $row.Warning = $lockResult.Reason
            }
        }

        if ($VerifyGit) {
            Push-Location -LiteralPath $repo.FullName
            try {
                git add -A --dry-run *> $null
                $row.GitDryRun = ($LASTEXITCODE -eq 0)
            } finally {
                Pop-Location
            }
        }
    } catch {
        $row.Error = $_.Exception.Message
    }

    $rows.Add([pscustomobject]$row)
}

$rows | Format-Table Repo,Skipped,GitDenyRemoved,GitProtected,PackDenyRemoved,LocksRemoved,WriteTest,GitDryRun,Warning,Error -AutoSize -Wrap

$failed = @($rows | Where-Object { -not $_.Skipped -and ($_.Error -or $_.WriteTest -ne $true -or ($VerifyGit -and $_.GitDryRun -ne $true)) })
if ($failed.Count -gt 0) {
    exit 1
}
