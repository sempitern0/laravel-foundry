[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location -LiteralPath $root
try {
    if (-not (Test-Path -LiteralPath '.env.example')) {
        throw 'Cannot reset outside the template repository.'
    }

    $project = 'letsgo'
    if (Test-Path -LiteralPath '.env') {
        $setting = Get-Content -LiteralPath '.env' | Where-Object { $_ -match '^PROJECT_NAME=' } | Select-Object -First 1
        if ($null -ne $setting -and $setting -match '^PROJECT_NAME=(.*)$') {
            $project = $Matches[1].Trim('"')
        }
    }
    if ($project -notmatch '^[a-z][a-z0-9_-]{0,40}$') {
        throw 'Invalid PROJECT_NAME in root .env; reset cancelled for safety.'
    }
    if ([Console]::IsInputRedirected) {
        throw 'Reset requires an interactive terminal.'
    }

    Write-Warning "This permanently removes the generated app/, root .env, .foundry.json and ALL Docker volumes belonging to Compose project '$project' (database, Redis, npm caches, Caddy CA)."
    Write-Host 'Local backups/ and app-backups/ are preserved. Windows hosts and trusted certificates are not changed.'
    $expected = "RESET $project"
    $confirmation = Read-Host "Type exactly '$expected' to continue"
    if ($confirmation -cne $expected) {
        throw 'Cancelled without removing the project.'
    }

    $profiles = @('dev','workers','scheduler','redis','https','pgweb','adminer','mariadb','mysql','phpmyadmin','postgres','mailpit','tools')
    $args = @()
    foreach ($profile in $profiles) { $args += @('--profile', $profile) }
    $args += @('down', '--volumes', '--remove-orphans')
    & docker compose @args
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose down failed ($LASTEXITCODE). No local files were removed."
    }

    # Delete only known generated paths, never source files, backup archives or
    # arbitrary paths. Refuse directory junctions/symlinks.
    foreach ($relative in @('app', '.env', '.foundry.json', '.foundry-starter', 'certs/caddy-local-root.crt', 'caddy-local-root.crt')) {
        $path = Join-Path $root $relative
        if (Test-Path -LiteralPath $path) {
            $item = Get-Item -LiteralPath $path -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Refusing to remove a symlink/junction: $relative"
            }
            Remove-Item -LiteralPath $path -Force -Recurse -ErrorAction Stop
            Write-Host "Removed: $relative"
        }
    }
    $certDir = Join-Path $root 'certs'
    if ((Test-Path -LiteralPath $certDir) -and @(Get-ChildItem -LiteralPath $certDir -Force).Count -eq 0) {
        Remove-Item -LiteralPath $certDir
    }
    Write-Host 'Template reset complete. Run: make setup STARTER=svelte (or choose another starter).'
}
finally {
    Pop-Location
}
