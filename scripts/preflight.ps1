[CmdletBinding()]
param([ValidateSet('Setup','Run')][string]$Mode = 'Run', [string]$Root)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent $PSScriptRoot }
$root = $Root
$path = Join-Path $root '.env'
if (-not (Test-Path -LiteralPath $path)) { throw 'Falta .env. Ejecuta make setup.' }
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
if ($name -cnotmatch '^[a-z][a-z0-9_-]{0,40}$') { throw 'PROJECT_NAME debe comenzar por una letra y usar solo minusculas, numeros, - o _.' }
$choices = @{
    DB_ENGINE = @('postgres','mysql','mariadb','sqlite')
    QUEUE_ENGINE = @('sync','database','redis')
    MAIL_ENGINE = @('mailpit','log','smtp')
    DB_UI = @('none','pgweb','phpmyadmin','adminer')
    HTTPS_ENABLED = @('0','1')
    TENANCY_MODE = @('none','shared-db','database-per-tenant')
}
foreach ($key in $choices.Keys) {
    if ((Val $key '') -cnotin $choices[$key]) { throw "Valor incompatible de $key. Ejecuta make reconfigure." }
}
if (($db -eq 'sqlite' -and $ui -ne 'none') -or
    ($ui -eq 'pgweb' -and $db -ne 'postgres') -or
    ($ui -eq 'phpmyadmin' -and $db -notin @('mysql','mariadb'))) {
    throw "La GUI $ui no es compatible con $db. Ejecuta make reconfigure."
}
if ($https -eq '1' -and (Val 'LOCAL_DOMAIN' '') -notmatch '^[a-z0-9][a-z0-9.-]*\.test$') {
    throw 'HTTPS requiere LOCAL_DOMAIN terminado en .test.'
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
        throw "$($item.Key) debe estar entre 1 y 65535."
    }
    if ($ports.ContainsKey($value)) {
        throw "Puerto $value duplicado: $($ports[$value].Key) y $($item.Key). Modifica .env."
    }
    $ports[$value] = $item
}
if ($Mode -eq 'Run' -and (-not (Test-Path -LiteralPath (Join-Path $root 'app/artisan')) -or
        -not (Test-Path -LiteralPath (Join-Path $root 'app/composer.json')))) {
    throw 'Falta Laravel (app/artisan o composer.json). Ejecuta make setup antes de iniciar.'
}
if ($Mode -eq 'Setup' -and (Test-Path -LiteralPath (Join-Path $root '.foundry.json')) -and
    -not (Test-Path -LiteralPath (Join-Path $root 'app/artisan'))) {
    throw 'Existe .foundry.json pero falta Laravel: recupera el codigo, no se reemplazara.'
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
            $message = "ATENCION: $key ha cambiado desde el ultimo setup correcto ($($previous[$key]) -> $current). Los datos anteriores permanecen en sus volumenes."
            if ($Mode -eq 'Run') {
                throw "$message Revisa el cambio antes de iniciar y usa make reconfigure si es intencional."
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
} catch { Write-Warning 'No se pudieron identificar los contenedores propios; se revisaran los puertos.' }
foreach ($entry in $ports.GetEnumerator()) {
    $port = [int]$entry.Key
    $service = [string]$entry.Value.Service
    if ($owned.ContainsKey($service)) { continue }
    $listener = $null
    try {
        $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,$port)
        $listener.Start()
    } catch [Net.Sockets.SocketException] {
        throw "El puerto $port ($($entry.Value.Key)) ya esta ocupado. Cierra la otra aplicacion o cambia el puerto en .env; comprueba con Get-NetTCPConnection -LocalPort $port."
    } finally {
        if ($null -ne $listener) { $listener.Stop() }
    }
}
Write-Host '[OK] Configuracion y puertos locales comprobados.' -ForegroundColor Green
