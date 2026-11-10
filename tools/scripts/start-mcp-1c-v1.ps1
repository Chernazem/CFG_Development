param(
    [string]$CollectionName = "tb_1c_rag"
)

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
    throw "Docker CLI is not available in PATH. Install/start Docker Desktop, then rerun this script."
}

Push-Location $McpRoot
try {
    $env:COLLECTION_NAME = $CollectionName
    & $Docker.Source compose up --build -d
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose up failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

Write-Host "mcp-1c-v1 started"
Write-Host "Loader: http://localhost:8501"
Write-Host "Embedding Service: http://localhost:5000"
Write-Host "Qdrant: http://localhost:6333/dashboard"
Write-Host "MCP Server: http://localhost:8000/mcp"
Write-Host "MCP Inspector: http://localhost:6274"
