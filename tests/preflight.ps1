$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$scriptPath = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/preflight.ps1')).Path
$temp = Join-Path ([IO.Path]::GetTempPath()) ('foundry-preflight-' + [guid]::NewGuid().ToString('N'))
try {
  [void](New-Item -ItemType Directory -Path $temp)
  [void](New-Item -ItemType Directory -Path (Join-Path $temp 'app'))
  Set-Content -LiteralPath (Join-Path $temp 'app/artisan') -Value 'fixture'
  Set-Content -LiteralPath (Join-Path $temp 'app/composer.json') -Value '{}'
  @('PROJECT_NAME=demo','DB_ENGINE=mariadb','QUEUE_ENGINE=database','MAIL_ENGINE=log','DB_UI=none','HTTPS_ENABLED=0','TENANCY_MODE=none','HTTP_PORT=18080','VITE_PORT=15173') | Set-Content (Join-Path $temp '.env')
  function docker { $global:LASTEXITCODE = 0; @('web','node') }
  & $scriptPath -Mode Run -Root $temp
  if ($LASTEXITCODE -ne 0) { throw 'Valid configuration rejected' }
  Add-Content (Join-Path $temp '.env') 'HTTP_PORT=15173'
  $failed = $false
  try { & $scriptPath -Mode Run -Root $temp } catch {
    $failed = $true
    if ($_.Exception.Message -notmatch 'Duplicate port 15173:' -or $_.Exception.Message -notmatch 'Update \.env') {
      throw "Duplicate-port error must be actionable English: $($_.Exception.Message)"
    }
  }
  if (-not $failed) { throw 'Duplicate port accepted' }
  Write-Host 'PASS Windows preflight validates options and rejects duplicate ports'
} finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force } }
