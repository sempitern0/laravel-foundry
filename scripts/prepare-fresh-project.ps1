# Runs before the first Docker Compose invocation.
. (Join-Path $PSScriptRoot 'app-source-guard.ps1')
# A new, empty Foundry checkout must not inherit an abandoned .env or
# another Compose project's named volumes.
function Initialize-FoundryFreshProject {
    param([Parameter(Mandatory = $true)][string]$Root)

    $app = Join-Path $Root 'app'
    $manifest = Join-Path $Root '.foundry.json'
    if (Test-Path -LiteralPath (Join-Path $app 'artisan')) { return $false }
    $pending = Join-Path $Root '.foundry-setup-pending'
    if (Test-Path -LiteralPath $pending) {
        $savedName = [IO.File]::ReadAllText($pending).Trim()
        $envPath = Join-Path $Root '.env'
        if (-not (Test-Path -LiteralPath $envPath)) { throw 'Setup pendiente sin .env: recupera la configuracion anterior.' }
        $currentName = @(Get-Content -LiteralPath $envPath | Where-Object { $_ -match '^PROJECT_NAME=' } | Select-Object -Last 1)
        if ($currentName.Count -ne 1 -or (($currentName[0] -split '=',2)[1].Trim('"')) -cne $savedName) {
            throw 'Setup pendiente con identidad distinta. No se sustituye la configuracion automaticamente.'
        }
        Write-Host "Reanudando setup pendiente de $savedName sin perder las opciones guardadas."
        return $false
    }
    if (Test-Path -LiteralPath $manifest) {
        throw 'Este repositorio contiene .foundry.json pero falta app/artisan. Es un proyecto configurado incompleto; recupera el código antes de iniciar setup.'
    }

    if (Test-Path -LiteralPath $app) {
        $unexpected = @(Get-FoundryUnexpectedAppEntries -AppPath $app)
        if ($unexpected.Count -gt 0) {
            throw 'app/ contiene archivos pero no artisan. No se modificará ni sobrescribirá su contenido.'
        }
    }

    $example = Join-Path $Root '.env.example'
    $environment = Join-Path $Root '.env'
    if (-not (Test-Path -LiteralPath $example)) { throw 'Falta .env.example; no se puede preparar un proyecto nuevo.' }

    $defaults = [System.IO.File]::ReadAllText($example)
    if (Test-Path -LiteralPath $environment) {
        $old = [System.IO.File]::ReadAllText($environment)
        if ($old -ne $defaults) {
            $backupDir = Join-Path $Root 'app-backups'
            [void](New-Item -ItemType Directory -Path $backupDir -Force)
            $backupName = 'foundry-env-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '.bak'
            Copy-Item -LiteralPath $environment -Destination (Join-Path $backupDir $backupName) -ErrorAction Stop
            Write-Host 'Configuración local anterior guardada en app-backups/. Se iniciará un proyecto nuevo.'
        }
    }

    $slug = (Split-Path -Leaf (Get-Item -LiteralPath $Root).FullName).ToLowerInvariant() -replace '[^a-z0-9_-]', '-'
    $slug = $slug.Trim('-')
    if ($slug -notmatch '^[a-z]') { $slug = 'project-' + $slug }
    if ($slug.Length -gt 26) { $slug = $slug.Substring(0, 26) }
    $suffix = [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $name = $slug + '-' + $suffix
    $updated = [regex]::Replace($defaults, '(?m)^PROJECT_NAME=.*$', 'PROJECT_NAME=' + $name)
    [System.IO.File]::WriteAllText($environment, $updated, (New-Object System.Text.UTF8Encoding($false)))

    # A starter hint without its portable manifest is not a source of truth.
    $hint = Join-Path $Root '.foundry-starter'
    if (Test-Path -LiteralPath $hint) { Remove-Item -LiteralPath $hint -Force }

    Write-Host "Proyecto nuevo: $name. Selecciona la configuración en el asistente."
    return $true
}
