[CmdletBinding()]
param([string]$Root)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# PowerShell 5.1 evaluates parameter defaults before $PSScriptRoot is
# populated. Resolve the script directory after parameter binding instead.
if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

$envPath = Join-Path $Root '.env'
if (-not (Test-Path -LiteralPath $envPath)) {
    Write-Host 'Laravel Foundry: falta .env. Ejecuta make setup.'
    exit 1
}

# Read only known, non-secret settings. Never dot-source .env or echo secrets.
$allowed = @('PROJECT_NAME','APP_LABEL','SETUP_CONFIGURED','DB_ENGINE','DB_DATABASE',
    'QUEUE_ENGINE','MAIL_ENGINE','DB_UI','HTTP_PORT','HTTPS_ENABLED','HTTPS_PORT',
    'LOCAL_DOMAIN','VITE_PORT','DB_UI_PORT','MAILPIT_PORT','TENANCY_MODE',
    'COMPOSE_PROFILES')
$settings = @{}
foreach ($line in [System.IO.File]::ReadAllLines($envPath)) {
    if ($line -match '^([A-Z][A-Z0-9_]*)=(.*)$' -and $Matches[1] -in $allowed) {
        $key = $Matches[1]
        $value = $Matches[2].Trim()
        if ($value.Length -ge 2 -and $value.StartsWith('"') -and $value.EndsWith('"')) {
            $value = $value.Substring(1, $value.Length - 2).Replace('\"', '"')
        }
        $settings[$key] = $value -replace '[\x00-\x1f\x7f]', ''
    }
}
function Setting([string]$Name, [string]$Fallback = '-') {
    if ($settings.ContainsKey($Name) -and $settings[$Name] -ne '') { return $settings[$Name] }
    return $Fallback
}

$running = @{}
$hasDockerStatus = $false
try {
    # Service names, not container names. Does not depend on localized Docker output.
    $lines = @(& docker compose ps --services --status running 2>$null)
    if ($LASTEXITCODE -eq 0) {
        $hasDockerStatus = $true
        foreach ($line in $lines) {
            $service = ([string]$line).Trim()
            if ($service -match '^[a-z][a-z0-9_-]*$') { $running[$service] = $true }
        }
    }
} catch { $hasDockerStatus = $false }
function Active([string]$Name) { return $running.ContainsKey($Name) }
function Section([string]$Name) {
    Write-Host ''
    Write-Host ('  -- ' + $Name.ToUpperInvariant() + ' ' + ('-' * [Math]::Max(0, (53 - $Name.Length)))) -ForegroundColor DarkCyan
}
function Item([string]$Label, [string]$Value) {
    Write-Host ('  {0,-20} ' -f $Label) -NoNewline -ForegroundColor DarkGray
    Write-Host $Value -ForegroundColor White
}
function Show-Service([string]$Name, [string]$Label) {
    Write-Host ('  {0,-23}' -f $Label) -NoNewline
    if (Active $Name) { Write-Host '[OK] En marcha' -ForegroundColor Green }
    elseif (-not $hasDockerStatus) { Write-Host '[?] No comprobable' -ForegroundColor Yellow }
    else { Write-Host '[--] Detenido' -ForegroundColor DarkYellow }
}
function Show-Link([string]$Label, [string]$Url, [bool]$Available, [bool]$Primary = $false) {
    Write-Host ('  {0,-20} ' -f $Label) -NoNewline -ForegroundColor Gray
    if ($Available) {
        # Full, uninterrupted URL keeps it clickable in modern terminals.
        Write-Host $Url -ForegroundColor $(if ($Primary) { 'Green' } else { 'Cyan' })
    } else {
        Write-Host '[--] Configurado, detenido' -ForegroundColor DarkYellow
    }
}
$name = Setting 'PROJECT_NAME' 'foundry'
$title = Setting 'APP_LABEL' $name
$db = Setting 'DB_ENGINE' 'postgres'
$dbName = Setting 'DB_DATABASE' 'foundry'
$queue = Setting 'QUEUE_ENGINE' 'sync'
$mail = Setting 'MAIL_ENGINE' 'log'
$ui = Setting 'DB_UI' 'none'
$https = (Setting 'HTTPS_ENABLED' '0') -eq '1'
$httpPort = Setting 'HTTP_PORT' '8080'
$httpsPort = Setting 'HTTPS_PORT' '443'
$domain = Setting 'LOCAL_DOMAIN' 'foundry.test'
$tenancy = Setting 'TENANCY_MODE' 'none'
$profiles = Setting 'COMPOSE_PROFILES' '(sin perfiles)'
$starterPath = Join-Path $Root 'app/.letsgo-starter'
$starter = if (Test-Path -LiteralPath $starterPath) {
    ([System.IO.File]::ReadAllText($starterPath)).Trim()
} elseif (Test-Path -LiteralPath (Join-Path $Root 'app/artisan')) { 'existente' } else { 'pendiente' }
$starter = $starter -replace '[\x00-\x1f\x7f]', ''

Write-Host ''
Write-Host '  ======================================================' -ForegroundColor DarkCyan
Write-Host ('   LARAVEL FOUNDRY  /  {0}' -f $title) -ForegroundColor Cyan
Write-Host '  ======================================================' -ForegroundColor DarkCyan

Section 'Accesos web'
$appReady = (Active 'app') -and (Active 'web')
if ($https) {
    $suffix = if ($httpsPort -eq '443') { '' } else { ':' + $httpsPort }
    Show-Link 'APP PRINCIPAL' ("https://{0}{1}" -f $domain, $suffix) ($appReady -and (Active 'caddy-local')) $true
}
Show-Link 'Aplicacion HTTP' ("http://localhost:{0}" -f $httpPort) $appReady (-not $https)
if ($mail -eq 'mailpit') {
    Show-Link 'Mailpit' ("http://localhost:{0}" -f (Setting 'MAILPIT_PORT' '8025')) (Active 'mailpit')
}
if ($ui -in @('pgweb','phpmyadmin','adminer')) {
    Show-Link $ui ("http://localhost:{0}" -f (Setting 'DB_UI_PORT' '8081')) (Active $ui)
}
if ((-not $https) -and (Active 'node')) {
    Show-Link 'Vite HMR' ("http://localhost:{0}" -f (Setting 'VITE_PORT' '5173')) $true
}

Section 'Configuracion'
Item 'Proyecto / starter' ("{0} / {1}" -f $name, $starter)
Item 'Base de datos' ("{0}  |  {1}" -f $db, $dbName)
Item 'Colas / correo' ("{0}  |  {1}" -f $queue, $mail)
Item 'Panel de BD' $ui
Item 'HTTPS / tenancy' ("{0}  |  {1}" -f $(if ($https) { 'Activado' } else { 'Desactivado' }), $tenancy)
Item 'Perfiles' $profiles

Section 'Contenedores'
if (-not $hasDockerStatus) { Write-Host '  Docker no disponible: no se pueden verificar los servicios.' -ForegroundColor Yellow }
Show-Service 'app' 'Laravel PHP'
Show-Service 'web' 'Nginx'
if ($https) { Show-Service 'caddy-local' 'HTTPS Caddy' }
if ($db -ne 'sqlite') { Show-Service $db $db }
if ($queue -ne 'sync') { Show-Service 'worker' 'Worker de colas' }
Show-Service 'scheduler' 'Scheduler'
if ($queue -eq 'redis') { Show-Service 'redis' 'Redis' }
if ($mail -eq 'mailpit') { Show-Service 'mailpit' 'Mailpit' }
if ($ui -ne 'none') { Show-Service $ui $ui }

Section 'Notas'
if ($https) {
    Write-Host ('  HTTPS local: hosts 127.0.0.1 {0} / ejecutar make https-setup.' -f $domain) -ForegroundColor Yellow
}
if ($tenancy -ne 'none') { Write-Host '  Tenancy solo define el entorno; la aplicacion debe implementar el aislamiento.' -ForegroundColor Yellow }
Write-Host '  [OK] = contenedor iniciado; no sustituye una prueba HTTP.' -ForegroundColor DarkGray
Write-Host '  make status | make ps | make logs | make up-wait | make reconfigure' -ForegroundColor Gray
Write-Host '  ======================================================' -ForegroundColor DarkCyan
