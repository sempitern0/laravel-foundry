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
    Write-Host '[ERROR] Foundry is not configured. Run make setup to create the project environment.'
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
# Compose JSON contains per-service health information on current Docker versions.
# The running list remains a compatibility fallback for older Compose versions.
$health = @{}
if ($hasDockerStatus) {
    try {
        $raw = @(& docker compose ps --all --format json 2>$null)
        if ($LASTEXITCODE -eq 0 -and $raw.Count -gt 0) {
            $joined = ($raw -join [Environment]::NewLine).Trim()
            $entries = @()
            try { $entries = @(ConvertFrom-Json -InputObject $joined -ErrorAction Stop) }
            catch {
                foreach ($line in $raw) {
                    try { $entries += ConvertFrom-Json -InputObject ([string]$line) -ErrorAction Stop }
                    catch { $entries = @(); break }
                }
            }
            foreach ($entry in $entries) {
                if (-not $entry -or -not $entry.PSObject.Properties['Service']) { continue }
                $serviceName = [string]$entry.Service
                if ($serviceName -notmatch '^[a-z][a-z0-9_-]*$') { continue }
                $health[$serviceName] = @{
                    State = if ($entry.PSObject.Properties['State']) { [string]$entry.State } else { '' }
                    Health = if ($entry.PSObject.Properties['Health']) { [string]$entry.Health } else { '' }
                }
            }
        }
    } catch { }
}
function Active([string]$Name) { return $running.ContainsKey($Name) }
function Section([string]$Name) {
    Write-Host ''
    Write-Host ('  {0}' -f $Name.ToUpperInvariant()) -ForegroundColor DarkCyan
    Write-Host '  --------------------------------------------------------' -ForegroundColor DarkGray
}
function Item([string]$Label,[string]$Value) {
    Write-Host ('  {0,-22}' -f $Label) -NoNewline -ForegroundColor Gray
    Write-Host $Value -ForegroundColor White
}
function Show-Service([string]$Name,[string]$Label) {
    $state = 'OFF     stopped'
    $color = 'DarkYellow'
    if (-not $hasDockerStatus) {
        $state = 'UNKNOWN Docker unavailable'; $color = 'Yellow'
    } elseif (Active $Name) {
        $state = 'OK      running'; $color = 'Green'
        if ($health.ContainsKey($Name)) {
            switch ($health[$Name].Health.ToLowerInvariant()) {
                'healthy' { $state = 'OK      healthy'; $color = 'Green' }
                'unhealthy' { $state = 'WARN    unhealthy'; $color = 'Yellow' }
                'starting' { $state = 'WAIT    starting'; $color = 'Yellow' }
            }
        }
    } elseif ($health.ContainsKey($Name) -and $health[$Name].State -eq 'running') {
        $state = 'OK      running'; $color = 'Green'
    }
    Write-Host ('  {0,-24}' -f $Label) -NoNewline -ForegroundColor Gray
    Write-Host $state -ForegroundColor $color
}
function Show-Link([string]$Label,[string]$Url,[bool]$Available,[bool]$Primary = $false) {
    Write-Host ('  {0,-22}' -f $Label) -NoNewline -ForegroundColor Gray
    if ($Available) {
        Write-Host $Url -ForegroundColor $(if ($Primary) { 'Green' } else { 'Cyan' })
    } elseif (-not $hasDockerStatus) {
        Write-Host 'UNKNOWN  Docker unavailable' -ForegroundColor Yellow
    } else {
        Write-Host 'OFF      service not running' -ForegroundColor DarkYellow
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
Write-Host '  +--------------------------------------------------------+' -ForegroundColor DarkCyan
Write-Host '  | LARAVEL FOUNDRY                                        |' -ForegroundColor Cyan
Write-Host '  +--------------------------------------------------------+' -ForegroundColor DarkCyan
Item 'Application' $title
Item 'Project' $name
Item 'Starter' $starter

Section 'Endpoints'
$appReady = (Active 'app') -and (Active 'web')
if ($https) {
    $suffix = if ($httpsPort -eq '443') { '' } else { ':' + $httpsPort }
    Show-Link 'Primary app' ("https://{0}{1}" -f $domain,$suffix) ($appReady -and (Active 'caddy-local')) $true
}
Show-Link 'Application HTTP' ("http://localhost:{0}" -f $httpPort) $appReady (-not $https)
if ($mail -eq 'mailpit') {
    Show-Link 'Mailpit' ("http://localhost:{0}" -f (Setting 'MAILPIT_PORT' '8025')) (Active 'mailpit')
}
if ($ui -in @('pgweb','phpmyadmin','adminer')) {
    Show-Link $ui ("http://localhost:{0}" -f (Setting 'DB_UI_PORT' '8081')) (Active $ui)
}
if ((-not $https) -and (Active 'node')) {
    Show-Link 'Vite HMR' ("http://localhost:{0}" -f (Setting 'VITE_PORT' '5173')) $true
}

Section 'Configuration'
Item 'Database' ("{0} / {1}" -f $db,$dbName)
Item 'Queue / Mail' ("{0} / {1}" -f $queue,$mail)
Item 'Database UI' $ui
Item 'HTTPS / Tenancy' ("{0} / {1}" -f $(if ($https) { 'enabled' } else { 'disabled' }),$tenancy)
Item 'Profiles' $profiles

Section 'Services'
if (-not $hasDockerStatus) {
    Write-Host '  [WARN] Docker status is unavailable. Start Docker and run make status again.' -ForegroundColor Yellow
}
Show-Service 'app' 'Laravel (PHP-FPM)'
Show-Service 'web' 'Nginx'
if ($https) { Show-Service 'caddy-local' 'Caddy (HTTPS)' }
if ($db -ne 'sqlite') { Show-Service $db $db }
if ($queue -ne 'sync') { Show-Service 'worker' 'Queue worker' }
Show-Service 'scheduler' 'Scheduler'
if ($queue -eq 'redis') { Show-Service 'redis' 'Redis' }
if ($mail -eq 'mailpit') { Show-Service 'mailpit' 'Mailpit' }
if ($ui -ne 'none') { Show-Service $ui $ui }

Section 'Next steps'
if ($https) {
    Write-Host ('  [INFO] Point {0} to 127.0.0.1; run make https-setup to trust your local CA.' -f $domain) -ForegroundColor Yellow
}
if ($tenancy -ne 'none') {
    Write-Host '  [INFO] Tenancy routing does not provide tenant data isolation. Test it in Laravel.' -ForegroundColor Yellow
}
Write-Host '  Run make up-wait for startup checks, or make doctor for host diagnostics.' -ForegroundColor Gray
Write-Host '  HEALTHY means Docker healthcheck passed; RUNNING only means started.' -ForegroundColor DarkGray
Write-Host '  +--------------------------------------------------------+' -ForegroundColor DarkCyan
