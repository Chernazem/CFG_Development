param(
    [ValidateSet('Clean', 'Prepare', 'UpdateConfig', 'UpdateTests', 'LoadData', 'RunUnit', 'All', 'Status')]
    [string]$Phase = 'All',

    [string]$WorkspaceRoot = '',
    [string]$RepoRoot = '',
    [string]$BspRepoRoot = '',
    [string]$ArtifactsRoot = '',
    [string]$BaseDtUrl = $env:TB_CI_BASE_DT_URL,
    [string]$BaseDtPath = $env:TB_CI_BASE_DT,
    [string]$JenkinsAuthHeader = $env:TB_CI_JENKINS_AUTH_HEADER,
    [string]$V8Version = $env:TB_CI_V8VERSION,
    [string]$VRunner = $env:TB_CI_VRUNNER,
    [string]$DbUser = $env:RUNNER_DBUSER,
    [string]$UnitDbUser = $env:TB_CI_UNIT_DBUSER,
    [string]$BspArtifact = '',
    [string]$Ibcmd = $env:TB_CI_IBCMD,
    [switch]$ForceDownloadDt,
    [switch]$UpdateConfigFromSources,
    [switch]$SkipUpdateConfigFromSources,
    [switch]$SkipMakeDist,
    [switch]$SkipSyntaxCheck
)

$ErrorActionPreference = 'Stop'

function U([string]$Base64) {
    return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Base64))
}

$SAdmin = U '0JDQtNC80LjQvdC40YHRgtGA0LDRgtC+0YA='
$SPath = U '0J/Rg9GC0Yw='
$SName = U '0JjQvNGP'
$SOverwrite = U '0J/QtdGA0LXQt9Cw0L/QuNGB0YvQstCw0YLRjA=='
$SDisableStartup = U '0J7RgtC60LvRjtGH0LjRgtGM0JvQvtCz0LjQutGD0J3QsNGH0LDQu9Cw0KDQsNCx0L7RgtGL0KHQuNGB0YLQtdC80Ys='
$SShutdown = U '0JfQsNCy0LXRgNGI0LjRgtGM0KDQsNCx0L7RgtGD0KHQuNGB0YLQtdC80Ys='
$SBspName = U '0KLQkV/QkdCh0J8='
$STestExtName = U '0KLQtdGB0YLQuNGA0L7QstCw0L3QuNC10KLQkQ=='
$SLoadExtensionEpf = U 'JHJ1bm5lclJvb3QvZXBmL9CX0LDQs9GA0YPQt9C40YLRjNCg0LDRgdGI0LjRgNC10L3QuNC10JLQoNC10LbQuNC80LXQn9GA0LXQtNC/0YDQuNGP0YLQuNGPLmVwZg=='
$SCloseEnterpriseEpf = U 'JHJ1bm5lclJvb3QvZXBmL9CX0LDQutGA0YvRgtGM0J/RgNC10LTQv9GA0LjRj9GC0LjQtS5lcGY='
$SRunDbUpdate = U '0JfQsNC/0YPRgdGC0LjRgtGM0J7QsdC90L7QstC70LXQvdC40LXQmNC90YTQvtGA0LzQsNGG0LjQvtC90L3QvtC50JHQsNC30Ys70JfQsNCy0LXRgNGI0LjRgtGM0KDQsNCx0L7RgtGD0KHQuNGB0YLQtdC80Ys='
$SLoadInitialDataUrl = U 'L1VSTCBlMWNpYi9jb21tYW5kL9Ce0LHRidCw0Y/QmtC+0LzQsNC90LTQsC7QotC10YHRgl/Ql9Cw0LPRgNGD0LfQuNGC0YzQn9C+0YHRgtCw0LLQu9GP0LXQvNGL0LXQlNCw0L3QvdGL0LU='
$SXunitCommandFormat = U 'eGRkQ29uZmlnICIiezB9IiI7IHhkZFJ1biDQl9Cw0LPRgNGD0LfRh9C40LrQoNCw0YHRiNC40YDQtdC90LjRjyAiItCi0LXRgdGC0LjRgNC+0LLQsNC90LjQtdCi0JEiIjsgeGRkUmVwb3J0INCT0LXQvdC10YDQsNGC0L7RgNCe0YLRh9C10YLQsEFsbHVyZVhNTNCS0LXRgNGB0LjRjzIgIiJ7MX0iIjsgeGRkUmVwb3J0INCT0LXQvdC10YDQsNGC0L7RgNCe0YLRh9C10YLQsEdlbmVyaWNFeGVjdXRpb24gIiJ7Mn0iIjsgeGRkRXhpdENvZGVQYXRoINCT0LXQvdC10YDQsNGG0LjRj9Ca0L7QtNCw0JLQvtC30LLRgNCw0YLQsCAiInszfSIiOyB3b3Jrc3BhY2VSb290ICIiezR9IiI7IHhkZFNodXRkb3du'

if (-not $V8Version) {
    $V8Version = '8.3.27.1936'
}
if (-not $BaseDtUrl) {
    $BaseDtUrl = 'https://jenkins.centrofinans.ru/job/TB/job/TB/job/main/lastSuccessfulBuild/artifact/bin/1cv8.dt'
}
if (-not $JenkinsAuthHeader) {
    $JenkinsAuthHeader = $env:AUTH_HEADER
}
if (-not $UnitDbUser) {
    $UnitDbUser = $SAdmin
}

if (-not $WorkspaceRoot) {
    $WorkspaceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
} else {
    $WorkspaceRoot = (Resolve-Path -LiteralPath $WorkspaceRoot).Path
}
if (-not $RepoRoot) {
    $RepoRoot = Join-Path $WorkspaceRoot 'repos\conf-main'
}
if (-not $BspRepoRoot) {
    $BspRepoRoot = Join-Path $WorkspaceRoot 'repos\tb_cfe_bsp'
}
if (-not $ArtifactsRoot) {
    $ArtifactsRoot = Join-Path $WorkspaceRoot '.local-ci\conf-main'
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$BspRepoRoot = (Resolve-Path -LiteralPath $BspRepoRoot).Path
$ArtifactsRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ArtifactsRoot)

if (-not $VRunner) {
    $localVRunner = Join-Path $WorkspaceRoot 'oscript_modules\bin\vrunner.bat'
    if (Test-Path -LiteralPath $localVRunner) {
        $VRunner = $localVRunner
    } else {
        $VRunner = 'vrunner'
    }
}

if (-not $Ibcmd) {
    $candidate = Join-Path ${env:ProgramFiles} "1cv8\$V8Version\bin\ibcmd.exe"
    if (Test-Path -LiteralPath $candidate) {
        $Ibcmd = $candidate
    } else {
        $candidate = Join-Path ${env:ProgramFiles(x86)} "1cv8\$V8Version\bin\ibcmd.exe"
        if (Test-Path -LiteralPath $candidate) {
            $Ibcmd = $candidate
        } else {
            $candidate = Join-Path $WorkspaceRoot ".local-tools\1cv8-$V8Version\Program Files 64\1cv8\$V8Version\bin\ibcmd.exe"
            if (Test-Path -LiteralPath $candidate) {
                $Ibcmd = $candidate
            } else {
                $cmd = Get-Command 'ibcmd.exe' -ErrorAction SilentlyContinue
                if ($cmd) {
                    $Ibcmd = $cmd.Source
                }
            }
        }
    }
}

$WorkRoot = Join-Path $ArtifactsRoot 'work'
$DbRoot = Join-Path $WorkRoot 'standalone-server'
$IbPath = Join-Path $DbRoot 'db-data'
$ConnectionString = "/F$IbPath"
$TempDir = Join-Path $RepoRoot '.temp'
$ArtifactsDir = Join-Path $ArtifactsRoot 'artifacts'
$BspCfe = Join-Path $ArtifactsDir 'tb_bsp.cfe'
$TestCfe = Join-Path $ArtifactsDir 'test.cfe'
$StatusPath = Join-Path $ArtifactsRoot 'status.txt'
$DistDir = Join-Path $ArtifactsRoot 'bin'
$DistCf = Join-Path $DistDir 'tb_main_local.cf'
$BaseDtPathExplicit = [bool]$BaseDtPath
if (-not $BaseDtPath) {
    $BaseDtPath = Join-Path (Join-Path $WorkRoot 'base-dt') '1cv8.dt'
}
$BaseDtPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($BaseDtPath)
$RuntimeParamsDir = Join-Path $env:TEMP 'tb-local-ci\conf-main'
$LocalVAParams = Join-Path $RuntimeParamsDir 'VAParams.local.json'
$XddLog = Join-Path $RuntimeParamsDir 'xddlog.log'
$LocalAddRoot = Join-Path $ArtifactsRoot 'add'
$LocalXddRunner = Join-Path $ArtifactsRoot 'add\xddTestRunner.epf'
$LocalAddPatchMarker = Join-Path $ArtifactsRoot 'add\.tb-local-add-patched'
$LocalAddPatchVersion = 'serializer-business-process-task-v2'
$LocalAddSourceRoot = Join-Path $WorkspaceRoot '.local-ci\add-xddTestRunner-src\xddTestRunner'
$LocalAddPluginSourceRoot = Join-Path $WorkspaceRoot '.local-ci\add-plugin-src'

function Write-Info([string]$Message) {
    Write-Host "==> $Message"
}

function Ensure-Directory([string]$Path) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

function Invoke-Tool([string]$Exe, [string[]]$Arguments, [string]$WorkingDirectory = $RepoRoot) {
    Write-Info "$Exe $($Arguments -join ' ')"
    Push-Location $WorkingDirectory
    try {
        & $Exe @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "$Exe failed with exit code $LASTEXITCODE"
        }
    } finally {
        Pop-Location
    }
}

function Invoke-ToolAllowFail([string]$Exe, [string[]]$Arguments, [string]$WorkingDirectory = $RepoRoot) {
    Write-Info "$Exe $($Arguments -join ' ')"
    Push-Location $WorkingDirectory
    try {
        & $Exe @Arguments 2>&1 | ForEach-Object { Write-Host $_ }
        $exitCode = $LASTEXITCODE
        return $exitCode
    } finally {
        Pop-Location
    }
}

function Set-RunnerDbUserForCommand {
    $userForCommand = $DbUser
    if (-not $userForCommand) {
        $userForCommand = $UnitDbUser
    }

    if ($userForCommand) {
        $env:RUNNER_DBUSER = $userForCommand
    } else {
        Remove-Item Env:RUNNER_DBUSER -ErrorAction SilentlyContinue
    }
}

function Restore-RunnerDbUser([AllowNull()][string]$OldValue) {
    if ($null -ne $OldValue) {
        $env:RUNNER_DBUSER = $OldValue
    } else {
        Remove-Item Env:RUNNER_DBUSER -ErrorAction SilentlyContinue
    }
}

function Get-DbUserArguments {
    $userForCommand = $DbUser
    if (-not $userForCommand) {
        $userForCommand = $UnitDbUser
    }

    if ($userForCommand) {
        return @('--db-user', $userForCommand)
    }

    return @()
}

function Download-BaseDt {
    Ensure-Directory (Split-Path $BaseDtPath -Parent)
    if ((Test-Path -LiteralPath $BaseDtPath) -and (-not $ForceDownloadDt)) {
        Write-Info "Use existing base DT: $BaseDtPath"
        return
    }

    $tempPath = "$BaseDtPath.tmp"
    Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
    Write-Info "Download base DT: $BaseDtUrl"
    $curl = Join-Path $env:SystemRoot 'System32\curl.exe'
    if (Test-Path -LiteralPath $curl) {
        $curlArgs = @(
            '--fail',
            '--location',
            '--show-error',
            '--insecure',
            '--noproxy', '*',
            '--output', $tempPath,
            $BaseDtUrl
        )
        if ($JenkinsAuthHeader) {
            $curlArgs = @('-H', "Authorization: $JenkinsAuthHeader") + $curlArgs
        }
        Invoke-Tool $curl $curlArgs $WorkspaceRoot
    } else {
        $headers = @{}
        if ($JenkinsAuthHeader) {
            $headers['Authorization'] = $JenkinsAuthHeader
        }
        Invoke-WebRequest -Uri $BaseDtUrl -Headers $headers -OutFile $tempPath -UseBasicParsing
    }
    Move-Item -LiteralPath $tempPath -Destination $BaseDtPath -Force
}

function Ensure-LocalAddRunner {
    if ((Test-Path -LiteralPath $LocalXddRunner) -and
        (Test-Path -LiteralPath $LocalAddPatchMarker) -and
        ((Get-Content -LiteralPath $LocalAddPatchMarker -Raw -ErrorAction SilentlyContinue).Trim() -eq $LocalAddPatchVersion)) {
        return
    }

    $globalAddRoot = Join-Path ${env:ProgramFiles} 'OneScript\lib\add'
    $globalXddRunner = Join-Path $globalAddRoot 'xddTestRunner.epf'
    if (-not (Test-Path -LiteralPath $globalXddRunner)) {
        throw "ADD xddTestRunner.epf not found: $globalXddRunner"
    }

    if (-not (Test-Path -LiteralPath $LocalAddSourceRoot)) {
        $oldRunnerDbUser = $env:RUNNER_DBUSER
        Set-RunnerDbUserForCommand
        try {
            Ensure-Directory (Split-Path $LocalAddSourceRoot -Parent)
                Invoke-Tool $VRunner @(
                    'decompileepf',
                    $globalXddRunner,
                    $LocalAddSourceRoot,
                    '--ibconnection', $ConnectionString,
                    '--v8version', $V8Version,
                    '--language', 'ru'
                ) $WorkspaceRoot
        } finally {
            Restore-RunnerDbUser $oldRunnerDbUser
        }
    }

    $managedFormModule = Join-Path $LocalAddSourceRoot (U 'eGRkVGVzdFJ1bm5lclxGb3Jtc1zQo9C/0YDQsNCy0LvRj9C10LzQsNGP0KTQvtGA0LzQsFxFeHRcRm9ybVxNb2R1bGUuYnNs')
    $wrongLine = U '0J7QsdGK0LXQutGCLtCS0YvQstC+0LTQuNGC0YzQn9C+0LTRgNC+0LHQvdC+0LXQn9GA0LXQtNGB0YLQsNCy0LvQtdC90LjQtdCe0YjQuNCx0LrQuCA9INCX0L3QsNGH0LXQvdC40LXQndCw0YHRgtGA0L7QudC60LgoItCY0LzRj9Ck0LDQudC70LDQm9C+0LPQktGL0L/QvtC70L3QtdC90LjRj9Ch0YbQtdC90LDRgNC40LXQsiIsICIiLCDQn9C70LDQs9C40L3QndCw0YHRgtGA0L7QtdC6KTs='
    $fixedLine = U '0J7QsdGK0LXQutGCLtCY0LzRj9Ck0LDQudC70LDQm9C+0LPQktGL0L/QvtC70L3QtdC90LjRj9Ch0YbQtdC90LDRgNC40LXQsiA9INCX0L3QsNGH0LXQvdC40LXQndCw0YHRgtGA0L7QudC60LgoItCY0LzRj9Ck0LDQudC70LDQm9C+0LPQktGL0L/QvtC70L3QtdC90LjRj9Ch0YbQtdC90LDRgNC40LXQsiIsICIiLCDQn9C70LDQs9C40L3QndCw0YHRgtGA0L7QtdC6KTs='
    $moduleText = [IO.File]::ReadAllText($managedFormModule, [Text.Encoding]::UTF8)
    if ($moduleText.Contains($wrongLine)) {
        [IO.File]::WriteAllText($managedFormModule, $moduleText.Replace($wrongLine, $fixedLine), [Text.UTF8Encoding]::new($false))
    }

    Remove-Item -LiteralPath $LocalAddRoot -Recurse -Force -ErrorAction SilentlyContinue
    Ensure-Directory $LocalAddRoot
    foreach ($name in @('plugins', 'tools', 'locales', 'vendor')) {
        $source = Join-Path $globalAddRoot $name
        if (Test-Path -LiteralPath $source) {
            Copy-Item -LiteralPath $source -Destination $LocalAddRoot -Recurse -Force
        }
    }
    $bddRunner = Join-Path $globalAddRoot 'bddRunner.epf'
    if (Test-Path -LiteralPath $bddRunner) {
        Copy-Item -LiteralPath $bddRunner -Destination $LocalAddRoot -Force
    }

    $loaderPluginName = U '0JfQsNCz0YDRg9C30YfQuNC60KDQsNGB0YjQuNGA0LXQvdC40Y8='
    $loaderPlugin = Join-Path (Join-Path $LocalAddRoot 'plugins') ($loaderPluginName + '.epf')
    if (Test-Path -LiteralPath $loaderPlugin) {
        $loaderSourceRoot = Join-Path $LocalAddPluginSourceRoot $loaderPluginName
        if (-not (Test-Path -LiteralPath $loaderSourceRoot)) {
            $oldRunnerDbUser = $env:RUNNER_DBUSER
            Set-RunnerDbUserForCommand
            try {
                Ensure-Directory (Split-Path $loaderSourceRoot -Parent)
                Invoke-Tool $VRunner @(
                    'decompileepf',
                    $loaderPlugin,
                    $loaderSourceRoot,
                    '--ibconnection', $ConnectionString,
                    '--v8version', $V8Version,
                    '--language', 'ru'
                ) $WorkspaceRoot
            } finally {
                Restore-RunnerDbUser $oldRunnerDbUser
            }
        }

        $loaderModule = Join-Path $loaderSourceRoot ($loaderPluginName + '\' + $loaderPluginName + '\Ext\ObjectModule.bsl')
        $loaderText = [IO.File]::ReadAllText($loaderModule, [Text.Encoding]::UTF8)
        $patchedLoaderText = $loaderText
        $patchedLoaderText = $patchedLoaderText.Replace(
            (U '0KHRgtGA0KjQsNCx0LvQvtC9KCIlMS4lMiIsINCc0L7QtNGD0LvRjCwg0JjQvNGP0J7QsdGK0LXQutGC0LApKQ=='),
            (U '0KHRgtGA0KjQsNCx0LvQvtC9KCIlMS4lMiIsINCc0L7QtNGD0LvRjCwg0JjQvNGP0J7QsdGK0LXQutGC0LAu0JjQvNGPKSk=')
        )
        $patchedLoaderText = $patchedLoaderText.Replace(
            (U '0KHRgtGA0KjQsNCx0LvQvtC9KCIlMS4lMi4lMyIsINCc0L7QtNGD0LvRjC7Ql9C90LDRh9C10L3QuNC1LCDQmNC80Y/QntCx0YrQtdC60YLQsCwg0JzQvtC00YPQu9GMLtCf0YDQtdC00YHRgtCw0LLQu9C10L3QuNC1KSk='),
            (U '0KHRgtGA0KjQsNCx0LvQvtC9KCIlMS4lMi4lMyIsINCc0L7QtNGD0LvRjC7Ql9C90LDRh9C10L3QuNC1LCDQmNC80Y/QntCx0YrQtdC60YLQsC7QmNC80Y8sINCc0L7QtNGD0LvRjC7Qn9GA0LXQtNGB0YLQsNCy0LvQtdC90LjQtSkp')
        )
        if ($patchedLoaderText -ne $loaderText) {
            [IO.File]::WriteAllText($loaderModule, $patchedLoaderText, [Text.UTF8Encoding]::new($false))
        }

        $loaderFormModule = Join-Path $loaderSourceRoot ($loaderPluginName + '\' + $loaderPluginName + (U 'XEZvcm1zXNCk0L7RgNC80LBcRXh0XEZvcm1cTW9kdWxlLmJzbA=='))
        $loaderFormText = [IO.File]::ReadAllText($loaderFormModule, [Text.Encoding]::UTF8)
        $patchedLoaderFormText = $loaderFormText.Replace(
            (U '0KTRg9C90LrRhtC40Y8g0KLQuNC/0JrQvtC90YLQtdC60YHRgtCw0JzQvtC00YPQu9GPKCkg0K3QutGB0L/QvtGA0YIKCdCS0L7Qt9Cy0YDQsNGCINCe0LHRitC10LrRgi7QotC40L/Ri9Ca0L7QvdGC0LXQutGB0YLQsNCc0L7QtNGD0LvQtdC5LtCa0LvQuNC10L3RgjsK0JrQvtC90LXRhtCk0YPQvdC60YbQuNC4Cgoj0JrQvtC90LXRhtCe0LHQu9Cw0YHRgtC4'),
            (U '0KTRg9C90LrRhtC40Y8g0KLQuNC/0JrQvtC90YLQtdC60YHRgtCw0JzQvtC00YPQu9GPKCkg0K3QutGB0L/QvtGA0YIKCdCS0L7Qt9Cy0YDQsNGCINCe0LHRitC10LrRgi7QotC40L/Ri9Ca0L7QvdGC0LXQutGB0YLQsNCc0L7QtNGD0LvQtdC5LtCa0LvQuNC10L3RgjsK0JrQvtC90LXRhtCk0YPQvdC60YbQuNC4Cgom0J3QsNCa0LvQuNC10L3RgtC1CtCk0YPQvdC60YbQuNGPINCi0LjQv9Ca0L7QvdGC0LXQutGB0YLQsNCe0LHRitC10LrRgtCwKCkg0K3QutGB0L/QvtGA0YIKCdCS0L7Qt9Cy0YDQsNGCINCe0LHRitC10LrRgi7QotC40L/Ri9Ca0L7QvdGC0LXQutGB0YLQsNCc0L7QtNGD0LvQtdC5LtCe0LHRitC10LrRgjsK0JrQvtC90LXRhtCk0YPQvdC60YbQuNC4Cgoj0JrQvtC90LXRhtCe0LHQu9Cw0YHRgtC4')
        )
        if ($patchedLoaderFormText -ne $loaderFormText) {
            [IO.File]::WriteAllText($loaderFormModule, $patchedLoaderFormText, [Text.UTF8Encoding]::new($false))
        }

        $oldRunnerDbUser = $env:RUNNER_DBUSER
        Set-RunnerDbUserForCommand
        try {
            Invoke-Tool $VRunner @(
                'compileepf',
                $loaderSourceRoot,
                (Join-Path $LocalAddRoot 'plugins'),
                '--ibconnection', $ConnectionString,
                '--v8version', $V8Version,
                '--language', 'ru'
            ) $WorkspaceRoot
        } finally {
            Restore-RunnerDbUser $oldRunnerDbUser
        }
    }

    $serializerPluginName = U '0KHQtdGA0LjQsNC70LjQt9Cw0YLQvtGATVhM'
    $serializerPlugin = Join-Path (Join-Path $LocalAddRoot 'plugins') ($serializerPluginName + '.epf')
    if (Test-Path -LiteralPath $serializerPlugin) {
        $serializerSourceRoot = Join-Path $LocalAddPluginSourceRoot $serializerPluginName
        if (-not (Test-Path -LiteralPath $serializerSourceRoot)) {
            $oldRunnerDbUser = $env:RUNNER_DBUSER
            Set-RunnerDbUserForCommand
            try {
                Ensure-Directory (Split-Path $serializerSourceRoot -Parent)
                Invoke-Tool $VRunner @(
                    'decompileepf',
                    $serializerPlugin,
                    $serializerSourceRoot,
                    '--ibconnection', $ConnectionString,
                    '--v8version', $V8Version,
                    '--language', 'ru'
                ) $WorkspaceRoot
            } finally {
                Restore-RunnerDbUser $oldRunnerDbUser
            }
        }

        $serializerModule = Join-Path $serializerSourceRoot ($serializerPluginName + '\' + $serializerPluginName + (U 'XEV4dFxPYmplY3RNb2R1bGUuYnNs'))
        $serializerText = [IO.File]::ReadAllText($serializerModule, [Text.Encoding]::UTF8)
        $patchedSerializerText = $serializerText.Replace(
            (U 'CQkJ0JjQvdCw0YfQtdCV0YHQu9C4INCd0LDQudGC0Lgo0J/QvtC70L3QvtC10JjQvNGP0KLQuNC/0LDQoNC10LrQstC40LfQuNGC0LAsINCS0LXRgNC90YPRgtGM0JfQvdCw0YfQtdC90LjQtdCh0L7QvtGC0LLQtdGC0YHRgtCy0LjRjygi0J/Qu9Cw0L3QktC40LTQvtCy0KDQsNGB0YfQtdGC0LAiKSkgPSAxINCi0L7Qs9C00LAKCQkJCdC80LXQvdC10LTQttC10YDQntCx0YrQtdC60YLQsCA9INCf0LvQsNC90YvQktC40LTQvtCy0KDQsNGB0YfQtdGC0LBb0JzQtdGC0LDQtNCw0L3QvdGL0LXQotC40L/QsNCg0LXQutCy0LjQt9C40YLQsC7QmNC80Y9dOwoJCQnQmtC+0L3QtdGG0JXRgdC70Lg7'),
            (U 'CQkJ0JjQvdCw0YfQtdCV0YHQu9C4INCd0LDQudGC0Lgo0J/QvtC70L3QvtC10JjQvNGP0KLQuNC/0LDQoNC10LrQstC40LfQuNGC0LAsINCS0LXRgNC90YPRgtGM0JfQvdCw0YfQtdC90LjQtdCh0L7QvtGC0LLQtdGC0YHRgtCy0LjRjygi0J/Qu9Cw0L3QktC40LTQvtCy0KDQsNGB0YfQtdGC0LAiKSkgPSAxINCi0L7Qs9C00LAKCQkJCdC80LXQvdC10LTQttC10YDQntCx0YrQtdC60YLQsCA9INCf0LvQsNC90YvQktC40LTQvtCy0KDQsNGB0YfQtdGC0LBb0JzQtdGC0LDQtNCw0L3QvdGL0LXQotC40L/QsNCg0LXQutCy0LjQt9C40YLQsC7QmNC80Y9dOwoJCQnQmNC90LDRh9C10JXRgdC70Lgg0J3QsNC50YLQuCjQn9C+0LvQvdC+0LXQmNC80Y/QotC40L/QsNCg0LXQutCy0LjQt9C40YLQsCwg0JLQtdGA0L3Rg9GC0YzQl9C90LDRh9C10L3QuNC10KHQvtC+0YLQstC10YLRgdGC0LLQuNGPKCLQkdC40LfQvdC10YHQn9GA0L7RhtC10YHRgSIpKSA9IDEg0KLQvtCz0LTQsAoJCQkJ0LzQtdC90LXQtNC20LXRgNCe0LHRitC10LrRgtCwID0g0JHQuNC30L3QtdGB0J/RgNC+0YbQtdGB0YHRi1vQnNC10YLQsNC00LDQvdC90YvQtdCi0LjQv9Cw0KDQtdC60LLQuNC30LjRgtCwLtCY0LzRj107CgkJCdCY0L3QsNGH0LXQldGB0LvQuCDQndCw0LnRgtC4KNCf0L7Qu9C90L7QtdCY0LzRj9Ci0LjQv9Cw0KDQtdC60LLQuNC30LjRgtCwLCDQktC10YDQvdGD0YLRjNCX0L3QsNGH0LXQvdC40LXQodC+0L7RgtCy0LXRgtGB0YLQstC40Y8oItCX0LDQtNCw0YfQsCIpKSA9IDEg0KLQvtCz0LTQsAoJCQkJ0LzQtdC90LXQtNC20LXRgNCe0LHRitC10LrRgtCwID0g0JfQsNC00LDRh9C4W9Cc0LXRgtCw0LTQsNC90L3Ri9C10KLQuNC/0LDQoNC10LrQstC40LfQuNGC0LAu0JjQvNGPXTsKCQkJ0JrQvtC90LXRhtCV0YHQu9C4Ow==')
        )
        if ($patchedSerializerText -ne $serializerText) {
            [IO.File]::WriteAllText($serializerModule, $patchedSerializerText, [Text.UTF8Encoding]::new($false))
            $serializerText = $patchedSerializerText
        }

        $businessProcessesManagerName = U '0JHQuNC30L3QtdGB0J/RgNC+0YbQtdGB0YHRiw=='
        $tasksManagerName = U '0JfQsNC00LDRh9C4'
        if (($serializerText -notmatch [regex]::Escape($businessProcessesManagerName)) -or ($serializerText -notmatch [regex]::Escape($tasksManagerName))) {
            throw "Serializer patch was not applied: $serializerModule"
        }

        $oldRunnerDbUser = $env:RUNNER_DBUSER
        Set-RunnerDbUserForCommand
        try {
            Invoke-Tool $VRunner @(
                'compileepf',
                $serializerSourceRoot,
                (Join-Path $LocalAddRoot 'plugins'),
                '--ibconnection', $ConnectionString,
                '--v8version', $V8Version,
                '--language', 'ru'
            ) $WorkspaceRoot
        } finally {
            Restore-RunnerDbUser $oldRunnerDbUser
        }
    }

    $oldRunnerDbUser = $env:RUNNER_DBUSER
    Set-RunnerDbUserForCommand
    try {
        Invoke-Tool $VRunner @(
            'compileepf',
            $LocalAddSourceRoot,
            $LocalAddRoot,
            '--ibconnection', $ConnectionString,
            '--v8version', $V8Version,
            '--language', 'ru'
        ) $WorkspaceRoot
    } finally {
        Restore-RunnerDbUser $oldRunnerDbUser
    }

    Set-Content -LiteralPath $LocalAddPatchMarker -Value $LocalAddPatchVersion -Encoding ASCII
}

function Reset-LocalCi {
    Write-Info "Clean local CI artifacts: $ArtifactsRoot"
    Remove-Item -LiteralPath $ArtifactsRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}

function Initialize-Base {
    Reset-LocalCi
    Ensure-Directory $DbRoot
    Ensure-Directory $ArtifactsDir

    if ($Ibcmd -and (Test-Path -LiteralPath $Ibcmd)) {
        Write-Info 'Create infobase from src/cf via ibcmd'
        Invoke-Tool $Ibcmd @(
            'infobase', 'create',
            "--data=$DbRoot",
            '--import=src/cf',
            '--apply',
            '--force'
        )
    } else {
        Write-Info 'Create infobase from src/cf via vrunner init-dev'
        Invoke-Tool $VRunner @(
            'init-dev',
            '--src', 'src/cf',
            '--ibconnection', $ConnectionString,
            '--v8version', $V8Version,
            '--nocacheuse'
        )
    }
}

function Restore-BaseFromDt {
    Reset-LocalCi
    Ensure-Directory $DbRoot
    Ensure-Directory $ArtifactsDir
    Download-BaseDt

    if (-not ($Ibcmd -and (Test-Path -LiteralPath $Ibcmd))) {
        throw "ibcmd.exe is required to restore DT, but was not found. Set TB_CI_IBCMD or pass -Ibcmd."
    }

    try {
        Write-Info 'Create infobase from Jenkins DT artifact'
        Invoke-Tool $Ibcmd @(
            'infobase', 'create',
            "--data=$DbRoot",
            "--restore=$BaseDtPath",
            '--force'
        ) $RepoRoot
    } finally {
        if (-not $BaseDtPathExplicit) {
            Remove-Item -LiteralPath $BaseDtPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Make-Dist {
    if ($SkipMakeDist) {
        Write-Info 'Skip make-dist'
        return
    }

    Ensure-Directory $DistDir
    $oldRunnerDbUser = $env:RUNNER_DBUSER
    Set-RunnerDbUserForCommand
    try {
        $args = @(
            'make-dist',
            $DistCf,
            '--src', 'src/cf',
            '--ibconnection', $ConnectionString,
            '--nocacheuse',
            '--v8version', $V8Version
        ) + (Get-DbUserArguments)
        Invoke-Tool $VRunner $args
    } finally {
        Restore-RunnerDbUser $oldRunnerDbUser
    }
}

function Compile-Bsp {
    Ensure-Directory $ArtifactsDir
    if ($BspArtifact) {
        if (-not (Test-Path -LiteralPath $BspArtifact)) {
            throw "BSP artifact not found: $BspArtifact"
        }
        Copy-Item -LiteralPath $BspArtifact -Destination $BspCfe -Force
        return
    }

    Invoke-Tool $VRunner @(
        'compileexttocfe',
        '--src', 'cfe',
        '--out', $BspCfe,
        '--nocacheuse',
        '--v8version', $V8Version
    ) $BspRepoRoot
}

function Load-Extension([string]$Path, [string]$Name, [switch]$Overwrite) {
    $commandParts = @("$SPath=$Path", "$SName=$Name")
    if ($Overwrite) {
        $commandParts += $SOverwrite
    }
    $commandParts += @($SDisableStartup, $SShutdown)

    $oldRunnerDbUser = $env:RUNNER_DBUSER
    Set-RunnerDbUserForCommand
    try {
        $args = @(
            'run',
            '--execute', $SLoadExtensionEpf,
            '--command', ($commandParts -join ';'),
            '--ibconnection', $ConnectionString,
            '--nocacheuse',
            '--v8version', $V8Version
        ) + (Get-DbUserArguments)
        Invoke-Tool $VRunner $args
    } finally {
        Restore-RunnerDbUser $oldRunnerDbUser
    }
}

function Load-Bsp {
    Compile-Bsp
    Load-Extension $BspCfe $SBspName
}

function Update-Test-Extension {
    Invoke-Tool $VRunner @(
        'compileexttocfe',
        '--src', 'src/tests',
        '--out', $TestCfe,
        '--nocacheuse',
        '--v8version', $V8Version
    )

    Load-Extension $TestCfe $STestExtName -Overwrite
}

function Update-Main-Configuration {
    Make-Dist

    $oldRunnerDbUser = $env:RUNNER_DBUSER
    Set-RunnerDbUserForCommand
    try {
        $loadArgs = @(
            'load',
            '--src', $DistCf,
            '--ibconnection', $ConnectionString,
            '--nocacheuse',
            '--v8version', $V8Version
        ) + (Get-DbUserArguments)
        Invoke-Tool $VRunner $loadArgs $RepoRoot

        $updateArgs = @(
            'updatedb',
            '--ibconnection', $ConnectionString,
            '--nocacheuse',
            '--v8version', $V8Version,
            '--additional', '/AllowExecuteScheduledJobs -Off /DisableUnrecoverableErrorMessage'
        ) + (Get-DbUserArguments)
        Invoke-Tool $VRunner $updateArgs $RepoRoot
    } finally {
        Restore-RunnerDbUser $oldRunnerDbUser
    }
}

function Invoke-FirstStart {
    Invoke-Tool $VRunner @(
        'run',
        '--execute', $SCloseEnterpriseEpf,
        '--command', $SRunDbUpdate,
        '--exitCodePath', $StatusPath,
        '--ibconnection', $ConnectionString,
        '--v8version', $V8Version
    )
}

function Invoke-SyntaxCheck {
    if ($SkipSyntaxCheck) {
        Write-Info 'Skip syntax-check'
        return
    }

    $syntaxAllure = Join-Path $TempDir 'syntax-check\allure'
    Invoke-Tool $VRunner @(
        'syntax-check',
        '--ibconnection', $ConnectionString,
        '--v8version', $V8Version,
        '--allure-results2', $syntaxAllure,
        '--mode', '-ThinClient', '-Server', '-ExternalConnectionServer'
    )
}

function Invoke-InitialData {
    $oldRunnerDbUser = $env:RUNNER_DBUSER
    Remove-Item Env:RUNNER_DBUSER -ErrorAction SilentlyContinue
    try {
        Invoke-Tool $VRunner @(
            'run',
            '--command', $SShutdown,
            '--additional', $SLoadInitialDataUrl,
            '--ibconnection', $ConnectionString,
            '--v8version', $V8Version
        )
    } finally {
        Restore-RunnerDbUser $oldRunnerDbUser
    }
}

function Invoke-Unit {
    Ensure-Directory $ArtifactsRoot
    Ensure-Directory $RuntimeParamsDir
    Ensure-Directory (Join-Path $TempDir 'xunit\allure')
    $savedDbUserParameter = $DbUser
    if (-not $script:DbUser) {
        $script:DbUser = $UnitDbUser
    }
    $oldRunnerDbUser = $env:RUNNER_DBUSER
    try {
        Ensure-LocalAddRunner
        @{
            (U '0JTQtdC70LDRgtGM0JvQvtCz0JLRi9C/0L7Qu9C90LXQvdC40Y/QodGG0LXQvdCw0YDQuNC10LLQktCi0LXQutGB0YLQvtCy0YvQudCk0LDQudC7') = (U '0JjRgdGC0LjQvdCw')
            (U '0JjQvNGP0KTQsNC50LvQsNCb0L7Qs9CS0YvQv9C+0LvQvdC10L3QuNGP0KHRhtC10L3QsNGA0LjQtdCy') = $XddLog
        } | ConvertTo-Json | ForEach-Object {
            [IO.File]::WriteAllText($LocalVAParams, [string]$_, (New-Object System.Text.UTF8Encoding $false))
        }

        Set-RunnerDbUserForCommand
        $args = @(
            'xunit',
            '--settings', 'build/vrunnerXUnit.json',
            '--ibconnection', $ConnectionString,
            '--v8version', $V8Version,
            '--additional', '/AllowExecuteScheduledJobs -Off /DisableUnrecoverableErrorMessage',
            '--workspace', $RepoRoot,
            '--xddConfig', $LocalVAParams,
            '--pathxunit', $LocalXddRunner
        ) + (Get-DbUserArguments)
        $exitCode = Invoke-ToolAllowFail $VRunner $args

        if ($exitCode -ne 0) {
            Write-Info "Unit returned exit code $exitCode"
        }

        return $exitCode
    } finally {
        Restore-RunnerDbUser $oldRunnerDbUser
        $script:DbUser = $savedDbUserParameter
    }
}

function Show-Status {
    Write-Host "Repo: $RepoRoot"
    Write-Host "Artifacts: $ArtifactsRoot"
    Write-Host "Base DT URL: $BaseDtUrl"
    Write-Host "Base DT path: $BaseDtPath"
    Write-Host "Base DT mode: $(if ($BaseDtPathExplicit) { 'explicit path' } else { 'temporary download for clean run' })"
    Write-Host "All updates src/cf: $(-not $SkipUpdateConfigFromSources)"
    Write-Host "Base DT exists: $(Test-Path -LiteralPath $BaseDtPath)"
    if (Test-Path -LiteralPath $BaseDtPath) {
        Write-Host "Base DT file time: $((Get-Item -LiteralPath $BaseDtPath).LastWriteTime)"
    }
    Write-Host "Connection: $ConnectionString"
    Write-Host "Base exists: $(Test-Path -LiteralPath $IbPath)"
    Write-Host "ibcmd: $Ibcmd"
    Write-Host "Unit user: $UnitDbUser"
    Write-Host "Allure: $(Join-Path $TempDir 'xunit\allure')"
    Write-Host "GenericExecution: $(Join-Path $TempDir 'genericExecution.xml')"
}

switch ($Phase) {
    'Clean' {
        Reset-LocalCi
    }
    'Prepare' {
        Restore-BaseFromDt
        Invoke-InitialData
    }
    'UpdateConfig' {
        Ensure-Directory $ArtifactsDir
        Update-Main-Configuration
    }
    'UpdateTests' {
        Ensure-Directory $ArtifactsDir
        Update-Test-Extension
    }
    'LoadData' {
        Invoke-InitialData
    }
    'RunUnit' {
        exit (Invoke-Unit)
    }
    'All' {
        Restore-BaseFromDt
        Invoke-InitialData
        if (-not $SkipUpdateConfigFromSources) {
            Update-Main-Configuration
        } elseif ($UpdateConfigFromSources) {
            Write-Info 'SkipUpdateConfigFromSources is set, ignore UpdateConfigFromSources'
        }
        Update-Test-Extension
        exit (Invoke-Unit)
    }
    'Status' {
        Show-Status
    }
}
