$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$tokens = $null
$errors = $null
$path = Join-Path $PSScriptRoot '../scripts/https-setup.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $path).Path, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$helper = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-Compose' }, $true)
. ([scriptblock]::Create($helper.Extent.Text))
# Native process output reproduces Docker's stdout/stderr on Windows 5.1 and pwsh.
function docker {
    if ($env:OS -eq 'Windows_NT') {
        & cmd.exe /d /c "echo progress & echo diagnostic 1>&2 & exit /b $script:exitCode"
    } else {
        & /bin/sh -c "echo progress; echo diagnostic >&2; exit $script:exitCode"
    }
    $global:LASTEXITCODE = $LASTEXITCODE
}
foreach ($exitCode in @(0, 7)) {
    foreach ($quiet in @($false, $true)) {
        $result = @(Invoke-Compose -Arguments @('--profile', 'https', 'up', '-d', 'caddy-local') -Quiet:$quiet)
        if ($result.Count -ne 1 -or $result[0] -isnot [int] -or $result[0] -ne $exitCode) {
            throw 'Compose output contaminated its exit code or masked failure.'
        }
        if ($ErrorActionPreference -ne 'Stop') { throw 'Error preference was not restored.' }
    }
}
Write-Host 'HTTPS Compose exit-code regression checks passed.'
