param(
    [string]$Url = $env:ONEC_QUERY_URL,
    [string]$Login = $env:ONEC_QUERY_LOGIN,
    [string]$Password = $env:ONEC_QUERY_PASSWORD,
    [string]$Query,
    [string]$QueryFile,
    [switch]$Health
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Url)) {
    throw "Url is required. Pass -Url or set ONEC_QUERY_URL."
}

if ([string]::IsNullOrWhiteSpace($Login)) {
    throw "Login is required. Pass -Login or set ONEC_QUERY_LOGIN."
}

if ([string]::IsNullOrWhiteSpace($Password)) {
    throw "Password is required. Pass -Password or set ONEC_QUERY_PASSWORD."
}

if ($Health) {
    $requestUrl = $Url -replace "/query/?$", "/health"
}
else {
    $requestUrl = $Url
}

$authBytes = [Text.Encoding]::UTF8.GetBytes("$($Login):$($Password)")
$authHeader = [Convert]::ToBase64String($authBytes)
$headers = @{ Authorization = "Basic $authHeader" }

if ($Health) {
    Invoke-WebRequest -Method Get -Uri $requestUrl -Headers $headers -UseBasicParsing | Select-Object -ExpandProperty Content
    return
}

if ($QueryFile) {
    $Query = Get-Content -Raw -Encoding UTF8 -Path $QueryFile
}

if (-not $Query) {
    $Query = [Console]::In.ReadToEnd()
}

if ([string]::IsNullOrWhiteSpace($Query)) {
    throw "Query is empty. Use -Query, -QueryFile, or pipe input."
}

$payload = @{ query = $Query } | ConvertTo-Json -Compress
$payloadBytes = [Text.Encoding]::UTF8.GetBytes($payload)

$requestParams = @{
    Method      = "Post"
    Uri         = $requestUrl
    Headers     = $headers
    ContentType = "application/json; charset=utf-8"
    Body        = $payloadBytes
    TimeoutSec  = 60
}

if ($PSVersionTable.PSVersion.Major -lt 6) {
    $requestParams.UseBasicParsing = $true
}

try {
    Invoke-WebRequest @requestParams -ErrorAction Stop | Select-Object -ExpandProperty Content
}
catch {
    $responseBody = $null
    $response = $_.Exception.Response

    if ($null -ne $response) {
        try {
            $stream = $response.GetResponseStream()
            if ($null -ne $stream) {
                $reader = New-Object System.IO.StreamReader($stream, [Text.Encoding]::UTF8)
                $responseBody = $reader.ReadToEnd()
                $reader.Close()
            }
        }
        catch {
        }
    }

    if ([string]::IsNullOrWhiteSpace($responseBody)) {
        throw
    }

    Write-Output $responseBody
    exit 1
}
