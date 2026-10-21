[CmdletBinding()]
param([string]$Starter = '')

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'app-source-guard.ps1')

function Invoke-Compose {
    param([string[]]$Arguments)
    & docker compose @Arguments
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR Docker Compose (codigo $LASTEXITCODE): $($Arguments -join ' ')" -ForegroundColor Red
        Write-Host 'Consulta make logs y reintenta make setup; no se sobrescribira el codigo Laravel.' -ForegroundColor Yellow
        throw "Docker Compose termino con codigo $LASTEXITCODE."
    }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    if (-not (Test-Path -LiteralPath '.env')) {
        Copy-Item -LiteralPath '.env.example' -Destination '.env'
    }
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw 'Docker is required (Docker Engine / Docker Desktop with Compose v2).'
    }
    Invoke-Compose -Arguments @('version')

    if (Test-Path -LiteralPath 'app/artisan') { $Starter = 'laravel' }
    elseif ([string]::IsNullOrWhiteSpace($Starter) -and (Test-Path -LiteralPath '.foundry-starter')) { $Starter = (Get-Content '.foundry-starter' -Raw).Trim() }
    if ([string]::IsNullOrWhiteSpace($Starter)) {
        if ([Console]::IsInputRedirected) {
            $Starter = 'laravel'
            Write-Host 'Non-interactive setup: defaulting to plain Laravel.'
        }
        else {
            Write-Host ''
            Write-Host 'Choose your Laravel starter:'
            Write-Host '  1) Laravel only (no authentication starter) [default]'
            Write-Host '  2) Svelte + Inertia'
            Write-Host '  3) Vue + Inertia'
            Write-Host '  4) React + Inertia'
            Write-Host '  5) Livewire'
            $answer = Read-Host 'Select [1-5]'
            switch ($answer) {
                { $_ -in @('', '1') } { $Starter = 'laravel'; break }
                '2' { $Starter = 'svelte'; break }
                '3' { $Starter = 'vue'; break }
                '4' { $Starter = 'react'; break }
                '5' { $Starter = 'livewire'; break }
                default { throw "Invalid starter selection: $answer" }
            }
        }
    }

    switch ($Starter.ToLowerInvariant()) {
        { $_ -in @('laravel', 'blank', 'none') } {
            $Starter = 'laravel'
            $repository = 'laravel/laravel'
            $revision = '13.x'
            break
        }
        'svelte' { $repository = 'laravel/svelte-starter-kit'; $revision = 'main'; break }
        'vue' { $repository = 'laravel/vue-starter-kit'; $revision = 'main'; break }
        'react' { $repository = 'laravel/react-starter-kit'; $revision = 'main'; break }
        'livewire' { $repository = 'laravel/livewire-starter-kit'; $revision = 'main'; break }
        default { throw "Unknown starter '$Starter'. Valid: laravel, svelte, vue, react, livewire." }
    }

    if (Test-Path -LiteralPath 'app/artisan') {
        Write-Host 'Existing Laravel app found. Preserving its code and frontend.'
        # A previous setup might have failed in Composer's post-update-cmd
        # AFTER vendor/autoload.php was written. Always rebuild/check tools.
        Invoke-Compose -Arguments @('build', 'composer')
        Invoke-Compose -Arguments @('run', '--rm', '--no-deps', '--user', '0:0', 'composer', 'sh', '-ec', 'sh /opt/letsgo/prepare-node-volumes.sh && sh /opt/letsgo/prepare-composer-volume.sh')
        Invoke-Compose -Arguments @('run', '--rm', '--no-deps', 'composer', 'sh', '-c', 'node --version && npm --version')

        Invoke-Compose -Arguments @('run','--rm','--no-deps','composer','php','/opt/letsgo/prepare-app.php')
        Write-Host 'Instalando dependencias PHP en el volumen Docker (primera instalación puede tardar)...'
        Invoke-Compose -Arguments @('run','--rm','--no-deps','composer','composer','install','--no-interaction','--prefer-dist','--no-progress')
        return
    }

    if (-not (Test-Path -LiteralPath 'app')) {
        New-Item -ItemType Directory -Path 'app' | Out-Null
    }
    if (@(Get-FoundryUnexpectedAppEntries -AppPath 'app').Count -gt 0) {
        throw 'app/ is not empty but contains no artisan file. Refusing to overwrite.'
    }

    Write-Host "Installing Laravel starter $Starter from $repository ($revision)"
    Invoke-Compose -Arguments @('build', 'composer')
    Invoke-Compose -Arguments @('run', '--rm', '--no-deps', '--user', '0:0', 'composer', 'sh', '-ec', 'sh /opt/letsgo/prepare-node-volumes.sh && sh /opt/letsgo/prepare-composer-volume.sh')
    Invoke-Compose -Arguments @('run', '--rm', '--no-deps', 'composer', 'sh', '-c', 'node --version && npm --version')
    Invoke-Compose -Arguments @('run', '--rm', '--no-deps', 'composer', 'sh', '/opt/letsgo/checkout-starter.sh', $revision, "https://github.com/$repository.git")
    # Exclude Sail from composer.json before dependency resolution and lockfile creation.
    if ((Get-Content -LiteralPath 'app/composer.json' -Raw) -match '"laravel/sail"\s*:') {
        Write-Host 'Excluding Laravel Sail before Composer installs dependencies.'
        Invoke-Compose -Arguments @('run', '--rm', '--no-deps', 'composer', 'composer', 'remove', 'laravel/sail', '--dev', '--no-update', '--no-scripts', '--no-plugins', '--no-interaction', '--no-progress')
    }

    Invoke-Compose -Arguments @('run','--rm','--no-deps','composer','php','/opt/letsgo/prepare-app.php')
    Invoke-Compose -Arguments @('run', '--rm', '--no-deps', 'composer', 'composer', 'install', '--no-interaction', '--prefer-dist', '--no-progress')

    [System.IO.File]::WriteAllText(
        (Join-Path (Get-Location).Path 'app/.letsgo-starter'),
        "$Starter`n",
        (New-Object System.Text.UTF8Encoding($false))
    )
    Write-Host 'Laravel scaffold ready.'
}
finally {
    Pop-Location
}
