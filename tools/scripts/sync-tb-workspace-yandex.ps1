# Explicit-only copy of a workspace bundle via Yandex.Disk "_AI".
# Not the default path between machines. Rules and scripts travel by git CFG_Development.
# Use for large files or when the user explicitly asks for Yandex.Disk.
# Does not copy nested git working trees, DEV-* task dirs, secrets, or ".tools".
# Locations: docs/setup/yandex-disk.md
# Keep this file ASCII-only so Windows PowerShell 5.1 can parse it without a BOM.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Export', 'Apply')]
    [string]$Action,
    [string]$WorkspaceRoot = '',
    [string]$YandexAiDir = '',
    [string]$BundleName = 'TB-workspace'
)

$ErrorActionPreference = 'Stop'

function Find-YandexAiDir {
    param([string]$Hint)
    if ($Hint) {
        if (-not (Test-Path -LiteralPath $Hint)) { throw "Yandex _AI not found: $Hint" }
        return (Resolve-Path -LiteralPath $Hint).Path
    }
    if ($env:TB_YANDEX_AI -and (Test-Path -LiteralPath $env:TB_YANDEX_AI)) {
        return (Resolve-Path -LiteralPath $env:TB_YANDEX_AI).Path
    }
    $found = New-Object System.Collections.Generic.List[string]
    $settingsGlob = Join-Path $env:LOCALAPPDATA 'Yandex\Yandex.Disk.2\*\settings.xml'
    Get-ChildItem -Path $settingsGlob -ErrorAction SilentlyContinue | ForEach-Object {
        [xml]$xml = Get-Content -LiteralPath $_.FullName -Encoding UTF8
        $sync = $xml.Settings.SyncFolder
        if ($sync) {
            $ai = Join-Path $sync '_AI'
            if (Test-Path -LiteralPath $ai) {
                [void]$found.Add((Resolve-Path -LiteralPath $ai).Path)
            }
        }
    }
    foreach ($c in @(
            (Join-Path $env:USERPROFILE 'YandexDisk\_AI'),
            (Join-Path $env:USERPROFILE 'Yandex.Disk\_AI'),
            'D:\YandexDisk\_AI',
            'F:\YandexDisk\_AI'
        )) {
        if ($c -and (Test-Path -LiteralPath $c)) {
            [void]$found.Add((Resolve-Path -LiteralPath $c).Path)
        }
    }
    # New Yandex account roots on TB-PC look like D:\YandexDisk_a.kuznecov@ftech.io\_AI
    foreach ($root in @('D:\', 'F:\', 'C:\')) {
        Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'YandexDisk*' -or $_.Name -like 'Yandex.Disk*' } |
            ForEach-Object {
                $ai = Join-Path $_.FullName '_AI'
                if (Test-Path -LiteralPath $ai) {
                    [void]$found.Add((Resolve-Path -LiteralPath $ai).Path)
                }
            }
    }
    $uniq = @($found | Select-Object -Unique)
    if ($uniq.Count -eq 0) {
        throw 'Cannot find Yandex.Disk _AI. Pass -YandexAiDir or set TB_YANDEX_AI (e.g. D:\YandexDisk_a.kuznecov@ftech.io\_AI).'
    }
    # Prefer roots that contain TB-workspace bundle if several exist
    foreach ($p in $uniq) {
        if (Test-Path -LiteralPath (Join-Path $p 'TB-workspace')) { return $p }
    }
    return $uniq[0]
}

function Find-WorkspaceRoot {
    param([string]$Hint)
    if ($Hint) {
        if (-not (Test-Path -LiteralPath $Hint)) { throw "Workspace not found: $Hint" }
        return (Resolve-Path -LiteralPath $Hint).Path
    }
    if ($env:TB_WORKSPACE_ROOT -and (Test-Path -LiteralPath $env:TB_WORKSPACE_ROOT)) {
        return (Resolve-Path -LiteralPath $env:TB_WORKSPACE_ROOT).Path
    }
    $here = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    if (Test-Path -LiteralPath (Join-Path $here 'repos\manifest.yaml')) {
        return (Resolve-Path -LiteralPath $here).Path
    }
    foreach ($c in @(
            'F:\Codex Projects\TB',
            'D:\Dev Projects\TB',
            'D:\Codex Projects\TB'
        )) {
        if (Test-Path -LiteralPath (Join-Path $c 'repos\manifest.yaml')) { return $c }
        if (Test-Path -LiteralPath $c) { return $c }
    }
    throw 'Pass -WorkspaceRoot (TB multi-repo workspace folder).'
}

function Invoke-RobocopyChecked {
    param(
        [string]$Source,
        [string]$Dest,
        [string[]]$RobocopyArgs
    )
    New-Item -ItemType Directory -Force -Path $Dest | Out-Null
    & robocopy.exe $Source $Dest @RobocopyArgs | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE): $Source -> $Dest" }
}

$aiDir = Find-YandexAiDir $YandexAiDir
$bundleRoot = Join-Path $aiDir $BundleName
$overlay = Join-Path $bundleRoot 'overlay'
$manifestPath = Join-Path $bundleRoot 'MANIFEST.json'
$robocopyQuiet = @(
    '/E', '/NFL', '/NDL', '/NJH', '/NJS', '/NC', '/NS', '/NP', '/R:1', '/W:1'
)

if ($Action -eq 'Export') {
    $ws = Find-WorkspaceRoot $WorkspaceRoot
    if (-not (Test-Path -LiteralPath (Join-Path $ws '.cursor\skills'))) {
        throw "Source does not look like the current TB workspace: $ws"
    }

    if (Test-Path -LiteralPath $overlay) {
        Remove-Item -LiteralPath $overlay -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $overlay | Out-Null

    $dirMaps = @(
        @{ Src = '.cursor'; Dest = '.cursor' },
        @{ Src = 'docs'; Dest = 'docs' },
        @{ Src = 'tools'; Dest = 'tools' },
        @{ Src = 'agents'; Dest = 'agents' },
        @{ Src = 'tool-patches'; Dest = 'tool-patches' }
    )
    $copyArgs = $robocopyQuiet + @(
        '/XD', '.git', 'node_modules', '.temp',
        '/XF', '*.env', '.env', '.env.*', 'credentials.*', '*.log'
    )
    foreach ($m in $dirMaps) {
        $src = Join-Path $ws $m.Src
        if (Test-Path -LiteralPath $src) {
            Invoke-RobocopyChecked $src (Join-Path $overlay $m.Dest) $copyArgs
        }
    }

    New-Item -ItemType Directory -Force -Path (Join-Path $overlay 'repos') | Out-Null
    foreach ($f in @('manifest.yaml', 'manifest.example.yaml', 'README.md')) {
        $src = Join-Path $ws (Join-Path 'repos' $f)
        if (Test-Path -LiteralPath $src) {
            Copy-Item -LiteralPath $src -Destination (Join-Path $overlay "repos\$f") -Force
        }
    }

    foreach ($f in @(
            'AGENTS.md', 'README.md', 'TB.code-workspace', '.editorconfig',
            '.gitignore', '.cursorignore', 'BACKUP-MANIFEST.md'
        )) {
        $src = Join-Path $ws $f
        if (Test-Path -LiteralPath $src) {
            Copy-Item -LiteralPath $src -Destination (Join-Path $overlay $f) -Force
        }
    }

    $applyLines = @(
        'Explicit Yandex.Disk apply only. Default shell sync is git CFG_Development.',
        'Apply TB overlay on the contour PC:',
        '',
        'powershell -NoProfile -File .\overlay\tools\scripts\sync-tb-workspace-yandex.ps1 -Action Apply -WorkspaceRoot "D:\Dev Projects\TB"',
        '',
        'Does not copy git clones under repos/conf-main, repos/extensions, repos/api-swagger.',
        'Does not touch secrets, .env, or CursorAPIKey.txt.',
        'Restart scheduled task TB-Cursor-Worker after apply.'
    )
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllLines((Join-Path $bundleRoot 'APPLY.txt'), $applyLines, $utf8)

    Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $aiDir 'sync-tb-workspace-yandex.ps1') -Force

    $files = @(Get-ChildItem -LiteralPath $overlay -Recurse -File)
    $fileCount = $files.Count
    $bytes = ($files | Measure-Object Length -Sum).Sum
    $info = [ordered]@{
        exportedAt   = [datetime]::UtcNow.ToString('o')
        sourceHost   = $env:COMPUTERNAME
        sourcePath   = $ws
        overlayFiles = $fileCount
        overlayBytes = $bytes
        excludes     = @(
            'repos/conf-main', 'repos/extensions', 'repos/api-swagger', 'repos/DEV-*',
            'DEV-*', '.tools', '.local-ci', 'oscript_modules', 'secrets', '.env*', 'src/', 'tests/'
        )
        note         = 'Apply with overlay/tools/scripts/sync-tb-workspace-yandex.ps1 -Action Apply'
    }
    [System.IO.File]::WriteAllText($manifestPath, ($info | ConvertTo-Json), $utf8)
    Write-Host ("Exported {0} files ({1:N2} MB) -> {2}" -f $fileCount, ($bytes / 1MB), $bundleRoot)
    return
}

# Apply
$ws = Find-WorkspaceRoot $WorkspaceRoot
if (-not (Test-Path -LiteralPath $overlay)) {
    throw "Bundle overlay not found: $overlay (wait for Yandex.Disk sync)"
}
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "MANIFEST.json not found in $bundleRoot"
}

New-Item -ItemType Directory -Force -Path $ws | Out-Null
$mirrorDirs = @('.cursor', 'docs', 'tools', 'agents', 'tool-patches')
$applyArgs = $robocopyQuiet + @('/IS', '/IT', '/MIR')
foreach ($d in $mirrorDirs) {
    $src = Join-Path $overlay $d
    if (Test-Path -LiteralPath $src) {
        Invoke-RobocopyChecked $src (Join-Path $ws $d) $applyArgs
    }
}

New-Item -ItemType Directory -Force -Path (Join-Path $ws 'repos') | Out-Null
foreach ($f in @('manifest.yaml', 'manifest.example.yaml', 'README.md')) {
    $src = Join-Path $overlay (Join-Path 'repos' $f)
    if (Test-Path -LiteralPath $src) {
        Copy-Item -LiteralPath $src -Destination (Join-Path $ws "repos\$f") -Force
    }
}
foreach ($f in @(
        'AGENTS.md', 'README.md', 'TB.code-workspace', '.editorconfig',
        '.gitignore', '.cursorignore', 'BACKUP-MANIFEST.md'
    )) {
    $src = Join-Path $overlay $f
    if (Test-Path -LiteralPath $src) {
        Copy-Item -LiteralPath $src -Destination (Join-Path $ws $f) -Force
    }
}

Write-Host ("Applied overlay -> {0}" -f $ws)
Write-Host 'Nested git clones in repos/* were not touched. Pull them from GitLab separately if needed.'
Write-Host 'Restart scheduled task TB-Cursor-Worker after this apply.'
