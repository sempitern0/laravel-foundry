$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot '../scripts/docker-preflight.ps1')

$script:scenario = 'ready'
function docker {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    if ($script:scenario -eq 'engine-unavailable' -and $Arguments[0] -eq 'info') {
        $global:LASTEXITCODE = 1
        return
    }
    if ($script:scenario -eq 'missing-compose' -and $Arguments[0] -eq 'compose') {
        $global:LASTEXITCODE = 1
        return
    }
    $global:LASTEXITCODE = 0
}
function Get-Command {
    param([string]$Name, [string]$ErrorAction)
    if ($script:scenario -eq 'missing-cli') { return $null }
    return [pscustomobject]@{ Name = $Name }
}

foreach ($case in @(
    @{ Mode = 'missing-cli'; Reason = 'missing-cli'; Ready = $false },
    @{ Mode = 'missing-compose'; Reason = 'missing-compose'; Ready = $false },
    @{ Mode = 'engine-unavailable'; Reason = 'engine-unavailable'; Ready = $false },
    @{ Mode = 'ready'; Reason = 'ready'; Ready = $true }
)) {
    $script:scenario = $case.Mode
    $status = Get-FoundryDockerStatus
    if ($status.Reason -ne $case.Reason -or $status.Ready -ne $case.Ready) {
        throw "Unexpected preflight status for $($case.Mode): $($status.Reason)"
    }
    if ($case.Mode -eq 'engine-unavailable' -and ($status.Message -notmatch 'Docker Desktop' -or $status.Message -notmatch 'Linux')) {
        throw 'Missing actionable Windows/Docker Desktop guidance.'
    }
}

Write-Host 'Docker preflight test passed: missing CLI, missing Compose, stopped engine, ready.'
