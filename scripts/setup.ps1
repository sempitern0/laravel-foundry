[CmdletBinding()]
param([string]$Starter = '', [switch]$Reconfigure)
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
    # Validate host prerequisites; the on-demand install remains a separate,
    # explicitly opt-in entry point, since make cannot install itself.
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw 'Docker is missing. Run .\scripts\prerequisites.ps1 -InstallMissing first.'
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Warning 'Git for Windows is not available on the host; install it to clone/version projects.'
    }
    # Configure the infrastructure before downloading Laravel. Otherwise a
    # failed git clone prevents the wizard from ever appearing.
    if (-not (Test-Path -LiteralPath '.env')) {
        Copy-Item -LiteralPath '.env.example' -Destination '.env'
    }
    Compose -Cmd @('build','composer')
    Compose -Cmd @('run','--rm','--no-deps','composer','php','/opt/letsgo/env-sync.php','--root-only')
    Compose -Cmd @('run','--rm','--no-deps','composer','php','/opt/letsgo/project-config.php','restore')
    $wizardArgs = @('run','--rm','--interactive','--no-deps','composer','php','/opt/letsgo/wizard.php')
    if (-not $Reconfigure) { $wizardArgs += '--if-needed' }
    Compose -Cmd $wizardArgs
    Compose -Cmd @('build','app','composer','node')
    & (Join-Path $PSScriptRoot 'bootstrap.ps1') -Starter $Starter
    if (-not $?) { throw 'Bootstrap failed' }
    Compose -Cmd @('run','--rm','--no-deps','composer','php','/opt/letsgo/project-config.php','save')
    Compose -Cmd @('run','--rm','--no-deps','composer','php','/opt/letsgo/configure-app.php')
    $config=@{}
    foreach ($line in Get-Content '.env') {
        if ($line -match '^([A-Z][A-Z0-9_]*)=(.*)$') { $config[$Matches[1]]=$Matches[2].Trim('"') }
    }
    if ($config['DB_ENGINE'] -eq 'postgres') { Compose -Cmd @('up','-d','--wait','--wait-timeout','120','postgres') }
    if ($config['DB_ENGINE'] -eq 'mariadb') { Compose -Cmd @('up','-d','--wait','--wait-timeout','120','mariadb') }
    if ($config['DB_ENGINE'] -eq 'mysql') { Compose -Cmd @('up','-d','--wait','--wait-timeout','120','mysql') }
    Compose -Cmd @('up','-d','--wait','--wait-timeout','120','app','web')
    if (-not ((Get-Content 'app/.env') | Where-Object { $_ -match '^APP_KEY=("[^"]+"|[^"\s]+)$' })) {
        Compose -Cmd @('exec','-T','app','php','artisan','key:generate','--force')
    }
    Compose -Cmd @('exec','-T','app','php','artisan','migrate','--force')
    if (Test-Path -LiteralPath 'app/package.json') {
        Compose -Cmd @('--profile','dev','run','--rm','--no-deps','--entrypoint','sh','node','/opt/letsgo/npm-ensure.sh')
        Compose -Cmd @('--profile','dev','run','--rm','--no-deps','--entrypoint','npm','node','run','build')
        if (Test-Path -LiteralPath 'app/public/hot') { Remove-Item -LiteralPath 'app/public/hot' -Force }
    }
    Compose -Cmd @('up','-d')
    Compose -Cmd @('ps')
    Write-Host ''
    Write-Host "HTTP:     http://localhost:$($config['HTTP_PORT'])"
    if ($config['HTTPS_ENABLED'] -eq '1') {
        $urlPort = if ($config['HTTPS_PORT'] -eq '443') { '' } else { ":$($config['HTTPS_PORT'])" }
        Write-Host "HTTPS:    https://$($config['LOCAL_DOMAIN'])$urlPort"
        Write-Host 'Windows helper: make https-setup (configures hosts and offers to trust the local CA).'
        Write-Host "Hosts:    127.0.0.1 $($config['LOCAL_DOMAIN'])"
        Write-Host 'Trust Caddy local root CA only after verifying it belongs to your own Docker deployment.'
    }
    if ($config['TENANCY_MODE'] -ne 'none') {
        Write-Host "SaaS blueprint: $($config['TENANCY_MODE']). Local alpha/beta subdomains: make tenancy-check."
        Write-Host 'This does not implement tenant isolation in Laravel; see docs/SAAS.md.'
    }
} finally { Pop-Location }
