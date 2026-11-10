$ErrorActionPreference = "Stop"

$WorkspaceRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$McpRoot = Join-Path $WorkspaceRoot ".tools\mcp-1c-v1"

if (-not (Test-Path $McpRoot)) {
    throw "mcp-1c-v1 is not cloned at $McpRoot"
}

$Docker = Get-Command docker -ErrorAction SilentlyContinue
if (-not $Docker -and (Test-Path "C:\Program Files\Docker\Docker\resources\bin\docker.exe")) {
    $Docker = Get-Item "C:\Program Files\Docker\Docker\resources\bin\docker.exe"
}
if (-not $Docker) {
    throw "Docker CLI is not available in PATH."
}

Push-Location $McpRoot
try {
    & $Docker.Source compose down
}
finally {
    Pop-Location
}

Write-Host "mcp-1c-v1 stopped"
