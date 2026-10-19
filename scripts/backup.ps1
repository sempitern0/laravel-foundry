[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-Compose {
    param([string[]]$Arguments)
    & docker compose @Arguments
    if ($LASTEXITCODE -ne 0) { throw "docker compose $($Arguments -join ' ') failed with exit code $LASTEXITCODE" }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    if (-not (Test-Path -LiteralPath '.env')) { throw 'Missing root .env.' }
    $settings = @{}
    foreach ($line in Get-Content -LiteralPath '.env') {
        if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') { $settings[$Matches[1]] = $Matches[2].Trim() }
    }
    foreach ($key in @('DB_USERNAME', 'DB_DATABASE')) {
        if (-not $settings.ContainsKey($key) -or $settings[$key] -notmatch '^[A-Za-z0-9_.-]+$') {
            throw "Invalid or missing $key in .env"
        }
    }
    if (-not (Test-Path -LiteralPath 'backups')) { New-Item -ItemType Directory 'backups' | Out-Null }

    $file = 'postgres-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.dump'
    $remote = '/tmp/' + $file
    try {
        Invoke-Compose -Arguments @('exec', '-T', 'postgres', 'pg_dump', '-Fc', '--no-owner', '--no-acl', '-U', $settings['DB_USERNAME'], '-d', $settings['DB_DATABASE'], '-f', $remote)
        Invoke-Compose -Arguments @('cp', ('postgres:' + $remote), ('backups/' + $file))
        if ((Get-Item -LiteralPath (Join-Path 'backups' $file)).Length -le 0) {
            throw 'The PostgreSQL backup is empty.'
        }
        Write-Host "PostgreSQL dump saved: backups/$file"
        Write-Host 'This is a LOCAL backup. Configure encrypted offsite backups for production.'
    }
    finally {
        & docker compose exec -T postgres rm -f $remote | Out-Null
    }
}
finally {
    Pop-Location
}
