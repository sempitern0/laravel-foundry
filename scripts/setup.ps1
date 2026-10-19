[CmdletBinding()]
param([string]$Starter = '')

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-Compose {
    param([string[]]$Arguments)
    & docker compose @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    & (Join-Path $PSScriptRoot 'bootstrap.ps1') -Starter $Starter
    & (Join-Path $PSScriptRoot 'configure-app.ps1')

    Invoke-Compose -Arguments @('up', '-d', '--build', 'postgres', 'mailpit', 'app', 'web')

    $appEnv = Get-Content -LiteralPath 'app/.env'
    if (-not ($appEnv | Where-Object { $_ -match '^APP_KEY=.+$' })) {
        Invoke-Compose -Arguments @('exec', '-T', 'app', 'php', 'artisan', 'key:generate', '--force')
    }

    Invoke-Compose -Arguments @('exec', '-T', 'app', 'php', 'artisan', 'migrate', '--force')
    Invoke-Compose -Arguments @('--profile', 'dev', 'run', '--rm', '--no-deps', '--entrypoint', 'npm', 'node', 'install')
    Invoke-Compose -Arguments @('--profile', 'dev', 'up', '-d', 'node')

    $settings = @{}
    Get-Content -LiteralPath '.env' | ForEach-Object {
        if ($_ -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') { $settings[$Matches[1]] = $Matches[2] }
    }
    Write-Host ''
    Write-Host "Application: http://localhost:$($settings['HTTP_PORT'])"
    Write-Host "Mailpit:     http://localhost:$($settings['MAILPIT_PORT'])"
}
finally {
    Pop-Location
}
