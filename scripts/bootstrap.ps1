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

    if ((Test-Path -LiteralPath 'app') -and @(Get-ChildItem -LiteralPath 'app' -Force).Count -gt 0) {
        if ([Console]::IsInputRedirected) { throw 'Existing app/: an interactive choice is required.' }
        $choice = Read-Host 'Existing app/: [K]eep or [R]eplace (archive existing files)'
        switch ($choice.ToUpperInvariant()) {
            { $_ -in @('', 'K') } { Write-Host 'Keeping existing app/.'; break }
            'R' {
                $parent = Join-Path (Get-Location).Path 'app-backups'
                if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent | Out-Null }
                $archive = Join-Path $parent ('app-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
                if (Test-Path -LiteralPath $archive) { throw "Archive already exists: $archive" }
                Invoke-Compose -Arguments @('--profile', 'dev', '--profile', 'workers', 'down', '--remove-orphans')
                Move-Item -LiteralPath 'app' -Destination $archive -ErrorAction Stop
                New-Item -ItemType Directory -Path 'app' | Out-Null
                Write-Host "Previous app archived at $archive"
                break
            }
            default { throw 'Cancelled; no changes.' }
        }
    }

    if (Test-Path -LiteralPath 'app/artisan') {
        Write-Host 'Existing Laravel app found. Preserving its code and frontend.'
        # A previous setup might have failed in Composer's post-update-cmd
        # AFTER vendor/autoload.php was written. Always rebuild/check tools.
        Invoke-Compose -Arguments @('build', 'app')
        Invoke-Compose -Arguments @('run', '--rm', '--no-deps', '--user', '0:0', 'app', 'sh', '-ec', 'chown "$DEV_UID:$DEV_GID" /var/www/html/node_modules /tmp/npm-cache /tmp/composer')
        Invoke-Compose -Arguments @('run', '--rm', '--no-deps', 'app', 'sh', '-c', 'node --version && npm --version')

        if ((Get-Content -LiteralPath 'app/composer.json' -Raw) -match '"laravel/sail"\s*:') {
            Write-Host 'Removing unwanted Laravel Sail from existing app (and updating composer.lock).'
            Invoke-Compose -Arguments @('run', '--rm', '--no-deps', 'app', 'composer', 'remove', 'laravel/sail', '--dev', '--no-interaction', '--no-progress')
        }

        if (-not (Test-Path -LiteralPath 'app/.letsgo-starter') -or -not (Test-Path -LiteralPath 'app/vendor/autoload.php')) {
            Invoke-Compose -Arguments @('run', '--rm', '--no-deps', 'app', 'composer', 'install', '--no-interaction', '--prefer-dist', '--no-progress')
            $composerManifest = Get-Content -LiteralPath 'app/composer.json' -Raw
            if (-not (Test-Path -LiteralPath 'app/.letsgo-starter') -and $composerManifest.Contains('artisan install:features')) {
                Write-Host 'Replaying interrupted Laravel feature-install hook.'
                Invoke-Compose -Arguments @('run', '--rm', '--no-deps', 'app', 'composer', 'run-script', 'post-update-cmd', '--no-interaction')
            }
            if (-not (Test-Path -LiteralPath 'app/.letsgo-starter')) {
                [System.IO.File]::WriteAllText(
                    (Join-Path (Get-Location).Path 'app/.letsgo-starter'),
                    "existing`n",
                    (New-Object System.Text.UTF8Encoding($false))
                )
            }
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
    Invoke-Compose -Arguments @('run', '--rm', '--no-deps', '--user', '0:0', 'app', 'sh', '-ec', 'chown "$DEV_UID:$DEV_GID" /var/www/html/node_modules /tmp/npm-cache /tmp/composer')
    Invoke-Compose -Arguments @('run', '--rm', '--no-deps', 'app', 'sh', '-c', 'node --version && npm --version')
    Invoke-Compose -Arguments @('run', '--rm', '--no-deps', 'app', 'sh', '/opt/letsgo/checkout-starter.sh', $revision, "https://github.com/$repository.git")
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
