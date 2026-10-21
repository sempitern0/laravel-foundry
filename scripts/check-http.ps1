[CmdletBinding()]
param([switch]$Strict)
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$settings = @{}
foreach ($line in [IO.File]::ReadAllLines((Join-Path $root '.env'))) {
    if ($line -match '^([A-Z][A-Z0-9_]*)=(.*)$') { $settings[$Matches[1]] = $Matches[2].Trim('"') }
}
$port = if ($settings['HTTP_PORT']) { $settings['HTTP_PORT'] } else { '8080' }
# /up is Laravel's framework endpoint when enabled; /healthz only checks Nginx.
$urls = @("http://127.0.0.1:$port/up", "http://127.0.0.1:$port/")
$success = $false
foreach ($url in $urls) {
    try {
        $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5 -MaximumRedirection 0 -ErrorAction Stop
        if ([int]$r.StatusCode -lt 400 -or [int]$r.StatusCode -in @(401,403)) { $success = $true; break }
    } catch {
        if ($_.Exception.Response -and ([int]$_.Exception.Response.StatusCode -ge 300 -and [int]$_.Exception.Response.StatusCode -lt 400 -or [int]$_.Exception.Response.StatusCode -in @(401,403))) { $success = $true; break }
    }
}
if ($success) { Write-Host '[OK] Laravel responde por HTTP.' -ForegroundColor Green; exit 0 }
Write-Warning 'PHP/Nginx iniciados, pero Laravel no responde correctamente. Revisa: make logs y make artisan CMD="about".'
if ($Strict) { exit 1 }
