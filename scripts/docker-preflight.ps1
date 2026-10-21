# Shared, side-effect-free Docker readiness check for Windows PowerShell 5.1+.
# Does not start Desktop, create files, or modify the selected Docker context.
function Test-FoundryDockerCommand {
    param([string[]]$Arguments)
    try {
        # Native stderr (including Docker Desktop's named-pipe message) is
        # intentionally suppressed here. The caller gets actionable guidance.
        $global:LASTEXITCODE = 0
        & docker @Arguments *> $null
        return ($LASTEXITCODE -eq 0)
    }
    catch {
        return $false
    }
}

function Get-FoundryDockerStatus {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        return [pscustomobject]@{
            Ready = $false
            Reason = 'missing-cli'
            Message = 'Docker no está instalado o no está disponible en PATH. Instala Docker Desktop y abre otra sesión de PowerShell.'
        }
    }

    if (-not (Test-FoundryDockerCommand -Arguments @('compose', 'version'))) {
        return [pscustomobject]@{
            Ready = $false
            Reason = 'missing-compose'
            Message = 'Docker Compose v2 no está disponible. Actualiza Docker Desktop o instala el complemento Docker Compose v2.'
        }
    }

    if (-not (Test-FoundryDockerCommand -Arguments @('info', '--format', '{{.ServerVersion}}'))) {
        return [pscustomobject]@{
            Ready = $false
            Reason = 'engine-unavailable'
            Message = 'El motor de Docker no está disponible. Abre Docker Desktop y espera a que termine de iniciarse, o inicia el servicio Docker Engine. En Windows, usa el motor de contenedores Linux. Después vuelve a ejecutar make setup.'
        }
    }

    return [pscustomobject]@{ Ready = $true; Reason = 'ready'; Message = '' }
}
