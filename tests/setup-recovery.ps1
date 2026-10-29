$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot '../scripts/setup-checkpoint.ps1')
. (Join-Path $PSScriptRoot '../scripts/prepare-fresh-project.ps1')
$root = Join-Path ([IO.Path]::GetTempPath()) ('foundry-recovery-' + [Guid]::NewGuid().ToString('N'))
try {
    [void](New-Item -ItemType Directory -Path $root)
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../.env.example') -Destination (Join-Path $root '.env.example')
    Copy-Item -LiteralPath (Join-Path $root '.env.example') -Destination (Join-Path $root '.env')
    $envPath = Join-Path $root '.env'
    (Get-Content -LiteralPath $envPath) -replace '^PROJECT_NAME=.*$', 'PROJECT_NAME=videoapp' | Set-Content -LiteralPath $envPath
    Save-FoundrySetupCheckpoint -Root $root
    [void](Initialize-FoundryFreshProject -Root $root)
    if (-not (Select-String -LiteralPath $envPath -Pattern '^PROJECT_NAME=videoapp$' -Quiet)) { throw 'Setup restarted with a new name' }
    Complete-FoundrySetup -Root $root
    if (Test-Path (Join-Path $root '.foundry-setup-pending')) { throw 'Pending setup marker remains after success' }
    if (-not (Select-String -LiteralPath (Join-Path $root '.foundry-runtime-state') -Pattern '^PROJECT_NAME=videoapp$' -Quiet)) { throw 'Completed identity missing' }
    $statePath = Join-Path $root '.foundry-runtime-state'
    $stateLines = @([IO.File]::ReadAllLines($statePath))
    if ($stateLines.Count -ne 3) { throw 'Runtime identity must contain three distinct lines.' }
    if ($stateLines[0] -ne 'PROJECT_NAME=videoapp' -or
        $stateLines[1] -ne 'DB_ENGINE=postgres' -or
        $stateLines[2] -ne 'DB_DATABASE=foundry') {
        throw 'Runtime identity checkpoint contains unexpected values.'
    }
    Write-Host 'PASS Windows interrupted setup resume and identity snapshot'
} finally { if (Test-Path $root) { Remove-Item -LiteralPath $root -Force -Recurse } }
