# Local, non-secret setup marker. A failed first setup resumes its saved wizard
# selections rather than silently replacing .env on the next attempt.
function Save-FoundrySetupCheckpoint {
    param([string]$Root)
    $envPath = Join-Path $Root '.env'
    $line = @(Get-Content -LiteralPath $envPath | Where-Object { $_ -match '^PROJECT_NAME=' } | Select-Object -Last 1)
    if ($line.Count -ne 1) { throw 'Missing PROJECT_NAME; cannot save the setup checkpoint.' }
    $name = ($line[0] -split '=',2)[1].Trim('"')
    if ($name -cnotmatch '^[a-z][a-z0-9_-]{0,40}$') { throw 'Invalid PROJECT_NAME.' }
    [IO.File]::WriteAllText((Join-Path $Root '.foundry-setup-pending'), $name + "`n", (New-Object Text.UTF8Encoding($false)))
}
function Complete-FoundrySetup {
    param([string]$Root)
    $config = @{}
    foreach ($line in Get-Content -LiteralPath (Join-Path $Root '.env')) {
        if ($line -match '^(PROJECT_NAME|DB_ENGINE|DB_DATABASE)=(.*)$') {
            $config[$Matches[1]] = $Matches[2].Trim('"')
        }
    }
    if (-not $config.ContainsKey('PROJECT_NAME')) { throw 'Falta PROJECT_NAME.' }
    $lines = @('PROJECT_NAME=' + $config['PROJECT_NAME'], 'DB_ENGINE=' + $config['DB_ENGINE'], 'DB_DATABASE=' + $config['DB_DATABASE'])
    [IO.File]::WriteAllLines((Join-Path $Root '.foundry-runtime-state'), $lines, (New-Object Text.UTF8Encoding($false)))
    Remove-Item -LiteralPath (Join-Path $Root '.foundry-setup-pending') -Force -ErrorAction SilentlyContinue
}
