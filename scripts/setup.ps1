[CmdletBinding()]
param([string]$Starter = '')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
function Compose {
    param([string[]]$Cmd)
    & docker compose @Cmd
    if ($LASTEXITCODE -ne 0) { throw "docker compose $($Cmd -join ' ') failed ($LASTEXITCODE)" }
}
$root = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $root
try {
    & (Join-Path $PSScriptRoot 'bootstrap.ps1') -Starter $Starter
    if (-not $?) { throw 'Bootstrap failed' }
    Compose -Cmd @('run','--rm','--no-deps','app','php','/opt/letsgo/wizard.php')
    Compose -Cmd @('run','--rm','--no-deps','app','php','/opt/letsgo/configure-app.php')
    $config=@{}
    foreach ($line in Get-Content '.env') {
        if ($line -match '^([A-Z][A-Z0-9_]*)=(.*)$') { $config[$Matches[1]]=$Matches[2].Trim('"') }
    }
    if ($config['DB_ENGINE'] -eq 'postgres') { Compose -Cmd @('up','-d','postgres') }
    if ($config['DB_ENGINE'] -eq 'mariadb') { Compose -Cmd @('up','-d','mariadb') }
    Compose -Cmd @('up','-d','app','web')
    if (-not ((Get-Content 'app/.env') | Where-Object { $_ -match '^APP_KEY=.+$' })) {
        Compose -Cmd @('exec','-T','app','php','artisan','key:generate','--force')
    }
    Compose -Cmd @('exec','-T','app','php','artisan','migrate','--force')
    Compose -Cmd @('--profile','dev','run','--rm','--no-deps','--entrypoint','sh','node','/opt/letsgo/npm-ensure.sh')
    if ($config['HTTPS_ENABLED'] -eq '1') {
        Compose -Cmd @('--profile','dev','run','--rm','--no-deps','--entrypoint','npm','node','run','build')
        if (Test-Path -LiteralPath 'app/public/hot') { Remove-Item -LiteralPath 'app/public/hot' -Force }
    }
    Compose -Cmd @('up','-d')
    Compose -Cmd @('ps')
    Write-Host ''
    Write-Host "HTTP:     http://localhost:$($config['HTTP_PORT'])"
    if ($config['HTTPS_ENABLED'] -eq '1') {
        Write-Host "HTTPS:    https://$($config['LOCAL_DOMAIN']):$($config['HTTPS_PORT'])"
        Write-Host "Hosts:    127.0.0.1 $($config['LOCAL_DOMAIN'])"
        Write-Host 'Trust Caddy local root CA only after verifying it belongs to your own Docker deployment.'
    }
} finally { Pop-Location }
