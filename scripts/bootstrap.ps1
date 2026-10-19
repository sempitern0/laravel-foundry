[CmdletBinding()]
param([string]$Starter = '')

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-Compose {
    param([string[]]$Arguments)
    & docker compose @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
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
        if ((Get-Content -LiteralPath 'app/composer.json' -Raw) -match '"laravel/sail"\s*:') {
            Write-Host 'Removing unwanted Laravel Sail from existing app (and updating composer.lock).'
            Invoke-Compose -Arguments @('build', 'app')
            Invoke-Compose -Arguments @('run', '--rm', '--no-deps', 'app', 'composer', 'remove', 'laravel/sail', '--dev', '--no-interaction', '--no-progress')
        }
        if (-not (Test-Path -LiteralPath 'app/vendor/autoload.php')) {
            Invoke-Compose -Arguments @('build', 'app')
            Invoke-Compose -Arguments @('run', '--rm', '--no-deps', 'app', 'composer', 'install', '--no-interaction', '--prefer-dist', '--no-progress')
        }
        return
    }

    if (-not (Test-Path -LiteralPath 'app')) {
        New-Item -ItemType Directory -Path 'app' | Out-Null
    }
    if (@(Get-ChildItem -LiteralPath 'app' -Force).Count -gt 0) {
        throw 'app/ is not empty but contains no artisan file. Refusing to overwrite.'
    }

    Write-Host "Installing Laravel starter $Starter from $repository ($revision)"
    Invoke-Compose -Arguments @('build', 'app')
    Invoke-Compose -Arguments @('run', '--rm', '--no-deps', 'app', 'git', 'clone', '--depth', '1', '--branch', $revision, "https://github.com/$repository.git", '/var/www/html')
    Invoke-Compose -Arguments @('run', '--rm', '--no-deps', 'app', 'rm', '-rf', '/var/www/html/.git')
    # Exclude Sail from composer.json before dependency resolution and lockfile creation.
    if ((Get-Content -LiteralPath 'app/composer.json' -Raw) -match '"laravel/sail"\s*:') {
        Write-Host 'Excluding Laravel Sail before Composer installs dependencies.'
        Invoke-Compose -Arguments @('run', '--rm', '--no-deps', 'app', 'composer', 'remove', 'laravel/sail', '--dev', '--no-update', '--no-scripts', '--no-plugins', '--no-interaction', '--no-progress')
    }

    Invoke-Compose -Arguments @('run', '--rm', '--no-deps', 'app', 'composer', 'install', '--no-interaction', '--prefer-dist', '--no-progress')

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
