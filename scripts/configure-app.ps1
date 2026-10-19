[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    if (-not (Test-Path -LiteralPath '.env')) {
        throw 'Root .env is missing. Run make setup first.'
    }
    if (-not (Test-Path -LiteralPath 'app/.env')) {
        Copy-Item -LiteralPath 'app/.env.example' -Destination 'app/.env'
    }

    $settings = @{}
    foreach ($line in [System.IO.File]::ReadAllLines((Join-Path (Get-Location).Path '.env'))) {
        if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
            $settings[$Matches[1]] = $Matches[2].Trim()
        }
    }
    foreach ($key in @('HTTP_PORT', 'DB_DATABASE', 'DB_USERNAME', 'DB_PASSWORD')) {
        if (-not $settings.ContainsKey($key) -or [string]::IsNullOrEmpty($settings[$key])) {
            throw "Missing required '$key' in root .env"
        }
    }

    $values = [ordered]@{
        APP_URL          = "http://localhost:$($settings['HTTP_PORT'])"
        DB_CONNECTION    = 'pgsql'
        DB_HOST          = 'postgres'
        DB_PORT          = '5432'
        DB_DATABASE      = $settings['DB_DATABASE']
        DB_USERNAME      = $settings['DB_USERNAME']
        DB_PASSWORD      = $settings['DB_PASSWORD']
        MAIL_MAILER      = 'smtp'
        MAIL_HOST        = 'mailpit'
        MAIL_PORT        = '1025'
        QUEUE_CONNECTION = 'database'
        CACHE_STORE     = 'database'
        SESSION_DRIVER  = 'database'
        REDIS_HOST      = 'redis'
    }

    $appEnvPath = Join-Path (Get-Location).Path 'app/.env'
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $seen = @{}
    foreach ($line in [System.IO.File]::ReadAllLines($appEnvPath)) {
        if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)=') {
            $key = $Matches[1]
            if ($values.Contains($key)) {
                $lines.Add("$key=$($values[$key])")
                $seen[$key] = $true
                continue
            }
        }
        $lines.Add($line)
    }
    foreach ($key in $values.Keys) {
        if (-not $seen.ContainsKey($key)) {
            $lines.Add("$key=$($values[$key])")
        }
    }
    [System.IO.File]::WriteAllLines($appEnvPath, $lines.ToArray(), (New-Object System.Text.UTF8Encoding($false)))
    Write-Host 'Configured app/.env for PostgreSQL and Mailpit.'
}
finally {
    Pop-Location
}
