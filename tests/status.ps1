$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$statusScript = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/status.ps1')).Path
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($statusScript, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw ($parseErrors | Out-String) }
$paramBlock = $ast.ParamBlock.Extent.Text
if ($paramBlock -match 'PSScriptRoot') { throw 'Status script must not use PSScriptRoot in a parameter default.' }
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('foundry-status-' + [Guid]::NewGuid().ToString('N'))
try {
  [void](New-Item -ItemType Directory -Path $temp)
  $settings = @('PROJECT_NAME="videoapp"', 'APP_LABEL="VideoApp"', 'DB_ENGINE="mariadb"', 'DB_DATABASE="foundry"', 'QUEUE_ENGINE="database"', 'MAIL_ENGINE="mailpit"', 'DB_UI="phpmyadmin"', 'HTTPS_ENABLED="1"', 'LOCAL_DOMAIN="videoapp.test"', 'DB_PASSWORD="DO-NOT-PRINT-THIS"')
  [System.IO.File]::WriteAllLines((Join-Path $temp '.env'), $settings)
  function docker {
    $global:LASTEXITCODE = 0
    @('app','web','caddy-local','mariadb','mailpit','phpmyadmin','worker')
  }
  $output = (& $statusScript -Root $temp 6>&1 | Out-String)
  if ($output -notmatch 'https://videoapp.test') { throw 'HTTPS URL missing from status output' }
  if ($output -notmatch 'Primary app') { throw 'Primary URL not highlighted' }
  if ($output -match 'DO-NOT-PRINT-THIS') { throw 'Status leaked a credential' }
  Write-Host 'PASS Windows status script parameter binding and GUI output'
} finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force } }
