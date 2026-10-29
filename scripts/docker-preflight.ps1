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
            Message = 'Docker CLI is missing from PATH. Install Docker Desktop and open a new PowerShell session.'
        }
    }

    if (-not (Test-FoundryDockerCommand -Arguments @('compose', 'version'))) {
        return [pscustomobject]@{
            Ready = $false
            Reason = 'missing-compose'
            Message = 'Docker Compose v2 is unavailable. Update Docker Desktop or install the Compose v2 plugin.'
        }
    }

    if (-not (Test-FoundryDockerCommand -Arguments @('info', '--format', '{{.ServerVersion}}'))) {
        return [pscustomobject]@{
            Ready = $false
            Reason = 'engine-unavailable'
            Message = 'Docker Engine is unavailable. Start Docker Desktop with Linux containers and retry make setup once the engine is ready.'
        }
    }

    return [pscustomobject]@{ Ready = $true; Reason = 'ready'; Message = '' }
}
