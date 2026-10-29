[CmdletBinding()]
param([ValidateSet('Setup','Run')][string]$Mode = 'Run', [string]$Root)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent $PSScriptRoot }
$root = $Root
$path = Join-Path $root '.env'
if (-not (Test-Path -LiteralPath $path)) { throw 'Missing .env. Run make setup.' }
$cfg = @{}
foreach ($line in [IO.File]::ReadAllLines($path)) {
    if ($line -match '^([A-Z][A-Z0-9_]*)=(.*)$') {
        $v = $Matches[2].Trim().Trim('"')
        $cfg[$Matches[1]] = $v
    }
}
function Val([string]$Key,[string]$Default) {
    if ($cfg.ContainsKey($Key)) { return [string]$cfg[$Key] }
    return $Default
}
$name = Val 'PROJECT_NAME' ''
$db = Val 'DB_ENGINE' 'postgres'
$queue = Val 'QUEUE_ENGINE' 'sync'
$mail = Val 'MAIL_ENGINE' 'mailpit'
$ui = Val 'DB_UI' 'none'
$https = Val 'HTTPS_ENABLED' '0'
if ($name -cnotmatch '^[a-z][a-z0-9_-]{0,40}$') { throw 'PROJECT_NAME must start with a lowercase letter and contain only lowercase letters, digits, - or _.' }
$choices = @{
    DB_ENGINE = @('postgres','mysql','mariadb','sqlite')
    QUEUE_ENGINE = @('sync','database','redis')
    MAIL_ENGINE = @('mailpit','log','smtp')
    DB_UI = @('none','pgweb','phpmyadmin','adminer')
    HTTPS_ENABLED = @('0','1')
    TENANCY_MODE = @('none','shared-db','database-per-tenant')
}
foreach ($key in $choices.Keys) {
    if ((Val $key '') -cnotin $choices[$key]) { throw "Invalid $key. Run make reconfigure." }
}
if (($db -eq 'sqlite' -and $ui -ne 'none') -or
    ($ui -eq 'pgweb' -and $db -ne 'postgres') -or
    ($ui -eq 'phpmyadmin' -and $db -notin @('mysql','mariadb'))) {
    throw "Database UI $ui is incompatible with $db. Run make reconfigure."
}
if ($https -eq '1' -and (Val 'LOCAL_DOMAIN' '') -notmatch '^[a-z0-9][a-z0-9.-]*\.test$') {
    throw 'HTTPS requires LOCAL_DOMAIN to end in .test.'
}
$ports = @{}
foreach ($item in @(
    @{ Key='HTTP_PORT'; Service='web'; Enabled=$true; Default='8080' },
    @{ Key='HTTPS_PORT'; Service='caddy-local'; Enabled=($https -eq '1'); Default='443' },
    @{ Key='DB_UI_PORT'; Service=$ui; Enabled=($ui -ne 'none'); Default='8081' },
    @{ Key='MAILPIT_PORT'; Service='mailpit'; Enabled=($mail -eq 'mailpit'); Default='8025' },
    @{ Key='VITE_PORT'; Service='node'; Enabled=($https -ne '1'); Default='5173' }
)) {
    if (-not $item.Enabled) { continue }
    $value = Val $item.Key $item.Default
    if ($value -notmatch '^[0-9]{1,5}$' -or [int]$value -lt 1 -or [int]$value -gt 65535) {
        throw "$($item.Key) must be between 1 and 65535."
    }
    if ($ports.ContainsKey($value)) {
        throw "Duplicate port $value: $($ports[$value].Key) y $($item.Key). Update .env."
    }
    $ports[$value] = $item
}
if ($Mode -eq 'Run' -and (-not (Test-Path -LiteralPath (Join-Path $root 'app/artisan')) -or
        -not (Test-Path -LiteralPath (Join-Path $root 'app/composer.json')))) {
    throw 'Laravel source is missing (app/artisan or composer.json). Run make setup.'
}
if ($Mode -eq 'Setup' -and (Test-Path -LiteralPath (Join-Path $root '.foundry.json')) -and
    -not (Test-Path -LiteralPath (Join-Path $root 'app/artisan'))) {
    throw 'The portable manifest exists but Laravel source is missing. Restore app/ before continuing.'
}

# Protect the last successfully configured Compose identity and database.
$previousPath = Join-Path $root '.foundry-runtime-state'
if (Test-Path -LiteralPath $previousPath) {
    $previous = @{}
    foreach ($line in Get-Content -LiteralPath $previousPath) {
        if ($line -match '^(PROJECT_NAME|DB_ENGINE|DB_DATABASE)=(.*)$') {
            $previous[$Matches[1]] = $Matches[2]
        }
    }
    foreach ($key in @('PROJECT_NAME', 'DB_ENGINE', 'DB_DATABASE')) {
        if (-not $previous.ContainsKey($key)) { continue }
        $current = Val $key ''
        if ($previous[$key] -cne $current) {
            $message = "WARNING: $key changed since the last successful setup ($($previous[$key]) -> $current). Existing data remains in the previous Docker volumes."
            if ($Mode -eq 'Run') {
                throw "$message Review the change and run make reconfigure if intentional."
            }
            Write-Warning $message
        }
    }
}
# Docker Compose identifies the containers belonging to this project.
$owned = @{}
try {
    $lines = @(& docker compose ps --services --status running 2>$null)
    if ($LASTEXITCODE -eq 0) {
        foreach ($line in $lines) { $owned[([string]$line).Trim()] = $true }
    }
} catch { Write-Warning 'Could not identify project containers; checking ports.' }
foreach ($entry in $ports.GetEnumerator()) {
    $port = [int]$entry.Key
    $service = [string]$entry.Value.Service
    if ($owned.ContainsKey($service)) { continue }
    $listener = $null
    try {
        $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,$port)
        $listener.Start()
    } catch [Net.Sockets.SocketException] {
        throw "El puerto $port ($($entry.Value.Key)) is occupied. Stop the conflicting service or update .env; inspect using Get-NetTCPConnection -LocalPort $port."
    } finally {
        if ($null -ne $listener) { $listener.Stop() }
    }
}
Write-Host '[OK] Configuration and local ports validated.' -ForegroundColor Green
