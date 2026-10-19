[CmdletBinding()]
param([switch]$InstallMissing)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Has-Command([string]$Name) {
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}
function Install-Winget([string]$Id, [string]$Label) {
    if (-not (Has-Command 'winget')) { throw "winget unavailable. Install $Label manually." }
    Write-Host "Requesting $Label ($Id) through winget..."
    & winget install --id $Id --exact --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { throw "winget installation failed for $Label." }
}
function Test-Ready {
    $docker = Has-Command 'docker'
    $git = Has-Command 'git'
    $make = Has-Command 'make'
    $compose = $false
    if ($docker) {
        & docker compose version *> $null
        $compose = $LASTEXITCODE -eq 0
    }
    Write-Host ("Git: {0} | Docker: {1} | Compose v2: {2} | GNU Make: {3}" -f $git,$docker,$compose,$make)
    return [bool]($docker -and $git -and $compose -and $make)
}
Write-Host "Laravel Foundry - Windows prerequisites"
if (Test-Ready) { Write-Host 'Prerequisites present.'; exit 0 }
if (-not $InstallMissing) {
    Write-Host 'Run .\scripts\prerequisites.ps1 -InstallMissing to request installation of missing tools.'
    exit 1
}
$confirmation = Read-Host 'Allow package-manager installations for missing prerequisites? (yes/no)'
if ($confirmation -ne 'yes') { throw 'No packages were installed.' }
if (-not (Has-Command 'git')) { Install-Winget 'Git.Git' 'Git for Windows' }
if (-not (Has-Command 'docker')) {
    Install-Winget 'Docker.DockerDesktop' 'Docker Desktop'
    Write-Host 'Docker Desktop may require enabling WSL2, rebooting and starting Docker Desktop manually.'
}
if (-not (Has-Command 'make')) {
    if (Has-Command 'choco') {
        & choco install make -y --no-progress
        if ($LASTEXITCODE -ne 0) { throw 'Chocolatey could not install GNU Make.' }
    } elseif (Has-Command 'scoop') {
        & scoop install make
        if ($LASTEXITCODE -ne 0) { throw 'Scoop could not install GNU Make.' }
    } elseif (Has-Command 'winget') {
        # Do not assume a stable winget ID for GNU Make: first check the catalogue.
        & winget show --id GnuWin32.Make --exact --accept-source-agreements *> $null
        if ($LASTEXITCODE -eq 0) {
            Install-Winget 'GnuWin32.Make' 'GNU Make'
        } else {
            Write-Warning 'No confirmed GNU Make package from the available managers. Install via Chocolatey (choco install make -y), Scoop (scoop install make), or use setup.ps1 directly.'
        }
    }
}
Write-Host 'Refresh PATH / open a new PowerShell session after installing tools.'
if (Test-Ready) {
    & docker info --format '{{.ServerVersion}}'
    if ($LASTEXITCODE -ne 0) {
        Write-Warning 'Docker CLI exists, but Docker Engine is not running. Start Docker Desktop.'
    }
} else {
    Write-Warning 'Some prerequisites are not yet available in this PowerShell process. Open a new terminal and retry.'
}
