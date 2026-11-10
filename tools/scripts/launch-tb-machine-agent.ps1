# Launch a Cloud Agent that executes tools on the TB My Machines worker.
# Requires: personal CURSOR_API_KEY in %USERPROFILE%\.cursor\tb-worker.env
# Docs: docs/setup/cursor-my-machines-worker.md
# Cyrillic prompts go through a UTF-8 JSON file + curl.exe (not Invoke-RestMethod).
#
# Default: env.machine only, no repos[]. Worker cwd is the whole TB workspace
# (conf-main, extensions, api-swagger). RepoId/StartingRef go into the prompt.
# -BindRepo sends one GitLab URL (Cursor matches that remote; dashboard primary is 1c/TB).

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$RepoId,
    [Parameter(Mandatory = $true)][string]$StartingRef,
    [string]$Prompt = '',
    [string]$PromptPath = '',
    [string]$WorkspaceRoot = '',
    [string]$Model = 'default',
    [switch]$WorkOnCurrentBranch,
    [switch]$BindRepo
)

$ErrorActionPreference = 'Stop'

foreach ($n in 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'http_proxy', 'https_proxy', 'all_proxy') {
    Remove-Item "Env:$n" -ErrorAction SilentlyContinue
}

if (-not $Prompt -and -not $PromptPath) {
    throw 'Pass -Prompt or -PromptPath'
}
if ($PromptPath) {
    $Prompt = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $PromptPath), [System.Text.Encoding]::UTF8)
}

if (-not $WorkspaceRoot) {
    $WorkspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

$envFile = Join-Path $env:USERPROFILE '.cursor\tb-worker.env'
if (-not (Test-Path -LiteralPath $envFile)) {
    throw "Missing $envFile"
}
Get-Content -LiteralPath $envFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq '' -or $line.StartsWith('#')) { return }
    $eq = $line.IndexOf('=')
    if ($eq -lt 1) { return }
    Set-Item -Path ("Env:" + $line.Substring(0, $eq).Trim()) -Value $line.Substring($eq + 1).Trim().Trim('"')
}
if (-not $env:CURSOR_API_KEY) { throw 'CURSOR_API_KEY is empty' }

$workerName = if ($env:TB_WORKER_NAME) { $env:TB_WORKER_NAME } else { 'TB-PC' }
$manifest = [System.IO.File]::ReadAllText((Join-Path $WorkspaceRoot 'repos\manifest.yaml'), [System.Text.Encoding]::UTF8)
if ($manifest -notmatch ("(?ms)- id: " + [regex]::Escape($RepoId) + ".*?path: (\S+).*?remote: (\S+)")) {
    throw "Repo '$RepoId' not found in repos/manifest.yaml"
}
$repoPath = $Matches[1].Trim('"')
$remote = $Matches[2].Trim('"').TrimEnd('/')
if ($remote.ToLower().EndsWith('.git')) {
    $remote = $remote.Substring(0, $remote.Length - 4)
}

$prefix = @(
    "Worker: $workerName. Workspace: весь каталог TB (мультирепо), не один git.",
    "Целевой репозиторий: $RepoId ($repoPath).",
    "Remote: $remote.",
    "Ветка / startingRef: $StartingRef.",
    "Правки только в этом репозитории, если задача не помечена как кросс-репозиторная.",
    "Не вызывать move_agent_to_root / move_agent_to_cloned_root.",
    ""
) -join [Environment]::NewLine

$body = [ordered]@{
    name   = $Name
    prompt = [ordered]@{ text = ($prefix + $Prompt) }
    env    = [ordered]@{ type = 'machine'; name = $workerName }
}
if ($Model) {
    $body.model = [ordered]@{ id = $Model }
}
if ($BindRepo) {
    $body.repos = @([ordered]@{ url = $remote; startingRef = $StartingRef })
    if ($WorkOnCurrentBranch) {
        $body.workOnCurrentBranch = $true
    }
} elseif ($WorkOnCurrentBranch) {
    throw '-WorkOnCurrentBranch requires -BindRepo'
}

$payloadPath = Join-Path $env:TEMP ('tb-agent-' + [guid]::NewGuid().ToString() + '.json')
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($payloadPath, ($body | ConvertTo-Json -Depth 8), $utf8NoBom)

$curlArgs = @(
    '-sS', '-X', 'POST', 'https://api.cursor.com/v1/agents',
    '-u', ($env:CURSOR_API_KEY + ':'),
    '-H', 'Content-Type: application/json; charset=utf-8',
    '--data-binary', "@$payloadPath"
)
$proxyUrl = $env:HTTPS_PROXY
if (-not $proxyUrl) { $proxyUrl = $env:HTTP_PROXY }
if (-not $proxyUrl) { $proxyUrl = $env:ALL_PROXY }
if ($proxyUrl) {
    $curlArgs = @('-x', $proxyUrl) + $curlArgs
}

try {
    $out = & curl.exe @curlArgs
    if ($LASTEXITCODE -ne 0) { throw "curl exit $LASTEXITCODE : $out" }
    $out
} finally {
    Remove-Item -LiteralPath $payloadPath -ErrorAction SilentlyContinue
}
