[CmdletBinding()]
param([switch]$Strict, [string]$Root)
$ErrorActionPreference = 'Continue'
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent $PSScriptRoot }
$root = $Root
$settings = @{}
foreach ($line in [IO.File]::ReadAllLines((Join-Path $root '.env'))) {
    if ($line -match '^([A-Z][A-Z0-9_]*)=(.*)$') { $settings[$Matches[1]] = $Matches[2].Trim('"') }
}
$port = if ($settings['HTTP_PORT']) { $settings['HTTP_PORT'] } else { '8080' }
# /up is Laravel's framework endpoint when enabled; /healthz only checks Nginx.
$urls = @("http://127.0.0.1:$port/up", "http://127.0.0.1:$port/")
$success = $false
$upCode = 'sin respuesta'
$rootCode = 'no consultado'
foreach ($path in @('/up', '/')) {
    if ($path -eq '/' -and $upCode -notin @('404','sin respuesta')) { break }
    $code = 'sin respuesta'
    try {
        $response = Invoke-WebRequest -Uri ("http://127.0.0.1:${port}${path}") -UseBasicParsing -TimeoutSec 5 -MaximumRedirection 0 -ErrorAction Stop
        $code = [string][int]$response.StatusCode
    } catch {
        if ($_.Exception.Response) {
            $code = [string][int]$_.Exception.Response.StatusCode
        }
    }
    if ($path -eq '/up') { $upCode = $code } else { $rootCode = $code }
    if ($code -match '^(2[0-9][0-9]|3[0-9][0-9]|401|403)$') {
        $success = $true
        break
    }
}
if ($success) { Write-Host '[OK] Laravel responde por HTTP.' -ForegroundColor Green; exit 0 }
Write-Warning "Laravel no verificado (/up: $upCode; /: $rootCode). Revisa: docker compose logs --tail=80 web app; make artisan CMD='about'."
if ($Strict) { exit 1 }
