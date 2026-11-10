$ErrorActionPreference = "Stop"

$Docker = Get-Command docker -ErrorAction SilentlyContinue
if (-not $Docker -and (Test-Path "C:\Program Files\Docker\Docker\resources\bin\docker.exe")) {
    $Docker = Get-Item "C:\Program Files\Docker\Docker\resources\bin\docker.exe"
}
if (-not $Docker) {
    throw "Docker CLI is not available in PATH."
}

& $Docker.Source ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" |
    Select-String -Pattern "^(NAMES|qdrant|embedding-service|loader|mcp-server|mcp-inspector)\b"
