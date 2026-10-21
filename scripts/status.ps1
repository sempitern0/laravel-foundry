[CmdletBinding()]
param([string]$Root = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

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
function Show-Service([string]$Name, [string]$Label) {
    $state = if (Active $Name) { 'en marcha' } else { 'detenido' }
    Write-Host ('  {0,-16} {1}' -f $Label, $state)
}
function Show-Link([string]$Label, [string]$Url, [bool]$Available) {
    if ($Available) { Write-Host ('  {0,-16} {1}' -f $Label, $Url) }
    else { Write-Host ('  {0,-16} {1}' -f $Label, '(configurado, no iniciado)') }
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
Write-Host '======================================================'
Write-Host ('  Laravel Foundry  |  {0}' -f $title)
Write-Host '======================================================'
Write-Host ('  Proyecto:       {0}' -f $name)
Write-Host ('  Starter:        {0}' -f $starter)
Write-Host ('  Base de datos:  {0} ({1})' -f $db, $dbName)
Write-Host ('  Cola:           {0}' -f $queue)
Write-Host ('  Correo:         {0}' -f $mail)
Write-Host ('  Panel de BD:    {0}' -f $ui)
Write-Host ('  HTTPS local:    {0}' -f $(if ($https) { 'si' } else { 'no' }))
Write-Host ('  Tenancy:        {0} (solo configuracion)' -f $tenancy)
Write-Host ('  Perfiles:       {0}' -f $profiles)
Write-Host ''
Write-Host 'SERVICIOS'
if (-not $hasDockerStatus) { Write-Host '  Estado no comprobable: inicia Docker Desktop o revisa docker compose ps.' }
Show-Service 'app' 'Laravel PHP'
Show-Service 'web' 'Nginx'
if ($https) { Show-Service 'caddy-local' 'HTTPS Caddy' }
if ($db -ne 'sqlite') { Show-Service $db $db }
if ($queue -ne 'sync') { Show-Service 'worker' 'Colas worker' }
Show-Service 'scheduler' 'Scheduler'
if ($queue -eq 'redis') { Show-Service 'redis' 'Redis' }
if ($mail -eq 'mailpit') { Show-Service 'mailpit' 'Mailpit' }
if ($ui -ne 'none') { Show-Service $ui $ui }
Write-Host ''
Write-Host 'ACCESOS EN EL NAVEGADOR'
$appReady = (Active 'app') -and (Active 'web')
Show-Link 'Aplicacion HTTP' ("http://localhost:{0}" -f $httpPort) $appReady
if ($https) {
    $suffix = if ($httpsPort -eq '443') { '' } else { ':' + $httpsPort }
    Show-Link 'Aplicacion HTTPS' ("https://{0}{1}" -f $domain, $suffix) ($appReady -and (Active 'caddy-local'))
}
if ($mail -eq 'mailpit') {
    Show-Link 'Mailpit' ("http://localhost:{0}" -f (Setting 'MAILPIT_PORT' '8025')) (Active 'mailpit')
}
if ($ui -in @('pgweb','phpmyadmin','adminer')) {
    Show-Link $ui ("http://localhost:{0}" -f (Setting 'DB_UI_PORT' '8081')) (Active $ui)
}
if ((-not $https) -and (Active 'node')) {
    Write-Host ('  Vite (HMR):      http://localhost:{0} (herramienta, no panel GUI)' -f (Setting 'VITE_PORT' '5173'))
}
Write-Host ''
if ($https) {
    Write-Host ('  HTTPS: configura hosts (127.0.0.1 {0}) y confia en la CA local con make https-setup.' -f $domain)
}
if ($tenancy -ne 'none') { Write-Host '  Tenancy es solo un blueprint: Laravel debe implementar el aislamiento.' }
Write-Host '  Estado = contenedor en marcha; no garantiza que la web responda.'
Write-Host '  Comandos: make status | make ps | make logs | make up-wait | make reconfigure'
Write-Host '======================================================'
