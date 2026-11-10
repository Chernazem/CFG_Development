# Seed GitLab + Jenkins into Windows Credential Manager for the current user
# and disable GCM interactive prompts for TB-PC agents.
# Docs: docs/setup/tb-pc-git-credentials.md
#
# Reads (not committed), first existing:
#   %USERPROFILE%\.cursor\tb-pc-credentials.env
#   %USERPROFILE%\.cursor\tb-gitlab.env
#
#   GITLAB_HOST / GITLAB_USERNAME / GITLAB_PAT
#   JENKINS_HOST / JENKINS_USERNAME / JENKINS_API_TOKEN  (optional but recommended)

[CmdletBinding()]
param(
    [string]$EnvFile = '',
    [string]$WorkerEnvFile = '',
    [string]$TestRemote = 'https://gitlab.centrofinans.ru/1c/TB.git',
    [switch]$SkipRemoteTest,
    [switch]$SkipJenkins
)

$ErrorActionPreference = 'Stop'

if (-not $EnvFile) {
    $candidates = @(
        (Join-Path $env:USERPROFILE '.cursor\tb-pc-credentials.env'),
        (Join-Path $env:USERPROFILE '.cursor\tb-gitlab.env')
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { $EnvFile = $c; break }
    }
    if (-not $EnvFile) {
        throw "Missing tb-pc-credentials.env (or tb-gitlab.env). See docs/setup/tb-pc-git-credentials.md"
    }
}
if (-not $WorkerEnvFile) {
    $WorkerEnvFile = Join-Path $env:USERPROFILE '.cursor\tb-worker.env'
}

function Read-DotEnv([string]$Path) {
    $map = @{}
    Get-Content -LiteralPath $Path | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { return }
        $eq = $line.IndexOf('=')
        if ($eq -lt 1) { return }
        $map[$line.Substring(0, $eq).Trim()] = $line.Substring($eq + 1).Trim().Trim('"')
    }
    return $map
}

function Set-WorkerEnvVar([string]$Path, [string]$Name, [string]$Value) {
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    $lines = @()
    if (Test-Path -LiteralPath $Path) {
        $lines = @(Get-Content -LiteralPath $Path)
    }
    $found = $false
    $out = foreach ($line in $lines) {
        if ($line -match ('^\s*' + [regex]::Escape($Name) + '\s*=')) {
            $found = $true
            '{0}={1}' -f $Name, $Value
        } else {
            $line
        }
    }
    if (-not $found) {
        $out = @($out) + ('{0}={1}' -f $Name, $Value)
    }
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllLines($Path, $out, $utf8)
}

function Set-GitHttpsCredential {
    param(
        [Parameter(Mandatory = $true)][string]$HostName,
        [Parameter(Mandatory = $true)][string]$UserName,
        [Parameter(Mandatory = $true)][string]$Secret
    )
    git config --global ("credential.https://{0}.username" -f $HostName) $UserName
    $reject = "protocol=https`nhost=$HostName`n`n"
    $approve = "protocol=https`nhost=$HostName`nusername=$UserName`npassword=$Secret`n`n"
    $reject | & git credential reject 2>$null
    $approve | & git credential approve
    if ($LASTEXITCODE -ne 0) {
        throw "git credential approve failed for $HostName (exit $LASTEXITCODE)"
    }
    Write-Host "CredMan OK: $HostName (user=$UserName, secretLen=$($Secret.Length))"
}

$map = Read-DotEnv $EnvFile
Write-Host "Env file: $EnvFile"
Write-Host "User: $env:USERNAME / $(whoami)"

$gitlabHost = if ($map['GITLAB_HOST']) { $map['GITLAB_HOST'] } else { 'gitlab.centrofinans.ru' }
$gitlabUser = $map['GITLAB_USERNAME']
$gitlabPat = $map['GITLAB_PAT']
if (-not $gitlabUser) { throw 'GITLAB_USERNAME is empty' }
if (-not $gitlabPat) { throw 'GITLAB_PAT is empty' }
if ($gitlabPat.Length -lt 12) { throw 'GITLAB_PAT looks too short' }

$jenkinsHost = if ($map['JENKINS_HOST']) { $map['JENKINS_HOST'] } else { 'jenkins.centrofinans.ru' }
$jenkinsUser = $map['JENKINS_USERNAME']
$jenkinsSecret = $map['JENKINS_API_TOKEN']
if (-not $jenkinsSecret) { $jenkinsSecret = $map['JENKINS_PASSWORD'] }

# Non-interactive for this process
$env:GCM_INTERACTIVE = 'never'
$env:GIT_TERMINAL_PROMPT = '0'
$env:GCM_MODAL_PROMPT = 'false'
$env:GIT_ASKPASS = ''
Remove-Item Env:SSH_ASKPASS -ErrorAction SilentlyContinue

git config --global credential.helper manager
git config --global http.sslBackend openssl

Set-GitHttpsCredential -HostName $gitlabHost -UserName $gitlabUser -Secret $gitlabPat

if (-not $SkipJenkins) {
    if (-not $jenkinsUser -or -not $jenkinsSecret) {
        Write-Warning "JENKINS_USERNAME / JENKINS_API_TOKEN missing — skip Jenkins CredMan seed (GCM dialogs on jenkins.* may remain)."
    } else {
        Set-GitHttpsCredential -HostName $jenkinsHost -UserName $jenkinsUser -Secret $jenkinsSecret
    }
}

Set-WorkerEnvVar $WorkerEnvFile 'GCM_INTERACTIVE' 'never'
Set-WorkerEnvVar $WorkerEnvFile 'GIT_TERMINAL_PROMPT' '0'
Set-WorkerEnvVar $WorkerEnvFile 'GCM_MODAL_PROMPT' 'false'
Write-Host "Updated $WorkerEnvFile (GCM non-interactive)"

if (-not $SkipRemoteTest) {
    Write-Host "Testing GitLab ls-remote $TestRemote ..."
    & git `
        -c http.sslbackend=openssl `
        -c http.sslVerify=false `
        -c http.proxy= `
        -c https.proxy= `
        -c ("http.https://{0}.proxy=" -f $gitlabHost) `
        -c credential.helper=manager `
        ls-remote --heads $TestRemote 2>&1 | Select-Object -First 5
    if ($LASTEXITCODE -ne 0) {
        throw "GitLab ls-remote failed (exit $LASTEXITCODE). Check PAT / VPN. Do not click GCM UI."
    }
    Write-Host 'GitLab ls-remote OK'

    if (-not $SkipJenkins -and $jenkinsUser -and $jenkinsSecret) {
        Write-Host "Testing Jenkins credential fill (no UI) ..."
        $fillIn = "protocol=https`nhost=$jenkinsHost`n`n"
        $fillOut = $fillIn | & git -c credential.helper=manager credential fill 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Jenkins credential fill failed (exit $LASTEXITCODE). Do not click GCM UI."
        }
        if (($fillOut -join "`n") -notmatch 'password=') {
            throw 'Jenkins credential fill returned no password — CredMan seed incomplete.'
        }
        Write-Host 'Jenkins credential fill OK (secret not printed)'
    }
}

Write-Host ''
Write-Host 'Next: restart Scheduled Task TB-Cursor-Worker so agents inherit env.'
Write-Host 'Clear secrets from tb-pc-credentials.env after success.'
