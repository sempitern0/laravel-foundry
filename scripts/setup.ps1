[CmdletBinding()]
param([string]$Starter = '', [switch]$Reconfigure)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'prepare-fresh-project.ps1')
. (Join-Path $PSScriptRoot 'docker-preflight.ps1')
. (Join-Path $PSScriptRoot 'setup-checkpoint.ps1')
function Compose {
    param([string[]]$Cmd)
    & docker compose @Cmd
    if ($LASTEXITCODE -ne 0) {
        $operation = ($Cmd -join ' ')
        Write-Host "ERROR en Docker Compose (codigo $LASTEXITCODE): $operation" -ForegroundColor Red
        Write-Host 'Comprueba Docker Desktop y ejecuta make ps o make logs. Puedes reintentar make setup: se conserva el progreso.' -ForegroundColor Yellow
        throw "Docker Compose termino con codigo $LASTEXITCODE."
    }
}
$root = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $root
try {
    # Validate host prerequisites; the on-demand install remains a separate,
    # explicitly opt-in entry point, since make cannot install itself.
    $dockerStatus = Get-FoundryDockerStatus
    if (-not $dockerStatus.Ready) {
        Write-Host ''
        Write-Host ('ERROR: ' + $dockerStatus.Message) -ForegroundColor Red
        Write-Host 'No se ha modificado la configuración del proyecto.' -ForegroundColor Yellow
        exit 1
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Warning 'Git for Windows is not available on the host; install it to clone/version projects.'
    }
    [void](Initialize-FoundryFreshProject -Root $root)
    # Configure the infrastructure before downloading Laravel. Otherwise a
    # failed git clone prevents the wizard from ever appearing.
    if (-not (Test-Path -LiteralPath '.env')) {
        Copy-Item -LiteralPath '.env.example' -Destination '.env'
    }
    & (Join-Path $PSScriptRoot 'environment.ps1') -Mode Apply
    Compose -Cmd @('build','composer')
    Compose -Cmd @('run','--rm','--no-deps','composer','php','/opt/letsgo/env-sync.php','--root-only')
    Compose -Cmd @('run','--rm','--no-deps','composer','php','/opt/letsgo/project-config.php','restore')
    $wizardArgs = @('run','--rm','--interactive','--no-deps','composer','php','/opt/letsgo/wizard.php')
    if (-not $Reconfigure) { $wizardArgs += '--if-needed' }
    Compose -Cmd $wizardArgs
    Save-FoundrySetupCheckpoint -Root $root
    & (Join-Path $PSScriptRoot 'preflight.ps1') -Mode Setup
    if ($LASTEXITCODE -ne 0) { throw 'Preflight failed' }
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
    Complete-FoundrySetup -Root $root
    try { & (Join-Path $PSScriptRoot 'check-http.ps1') } catch { Write-Warning 'Comprobacion HTTP no disponible.' }
    try { & (Join-Path $PSScriptRoot 'status.ps1') } catch { Write-Warning 'No se pudo mostrar el resumen; prueba make status.' }

} finally { Pop-Location }
