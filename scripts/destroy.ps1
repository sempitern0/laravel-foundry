[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    $confirmation = Read-Host 'This permanently deletes local volumes. Type DELETE to continue'
    if ($confirmation -cne 'DELETE') {
        Write-Host 'Cancelled.'
        exit 1
    }
    & docker compose --profile dev --profile workers --profile redis down --volumes --remove-orphans
    if ($LASTEXITCODE -ne 0) { throw "docker compose down failed ($LASTEXITCODE)" }
}
finally {
    Pop-Location
}
