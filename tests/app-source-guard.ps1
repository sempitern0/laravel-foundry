$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot '../scripts/app-source-guard.ps1')
$root = Join-Path ([System.IO.Path]::GetTempPath()) ('foundry-app-check-' + [guid]::NewGuid().ToString('N'))
try {
  New-Item -ItemType Directory -Path $root | Out-Null
  foreach ($starter in @('laravel','svelte','vue','react','livewire')) {
    $app = Join-Path $root $starter
    New-Item -ItemType Directory -Path (Join-Path $app 'vendor') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $app 'node_modules') -Force | Out-Null
    if (@(Get-FoundryUnexpectedAppEntries -AppPath $app).Count -ne 0) { throw "Dependency directories rejected for $starter" }
    Set-Content -LiteralPath (Join-Path $app 'composer.json') -Value '{}'
    if (@(Get-FoundryUnexpectedAppEntries -AppPath $app).Count -ne 1) { throw "App source was not protected for $starter" }
  }
  Write-Host 'PASS dependency-mount guard for all five starters'
} finally { if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force } }
