[CmdletBinding()]
param([switch]$SkipHosts, [switch]$SkipTrust)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $root
try {
    $settings=@{}
    foreach($line in Get-Content -LiteralPath '.env') {
        if($line -match '^([A-Z][A-Z0-9_]*)=(.*)$') {
            $settings[$Matches[1]]=$Matches[2].Trim('"')
        }
    }
    if($settings['HTTPS_ENABLED'] -ne '1') { throw 'Enable HTTPS in make setup first.' }
    $domain=$settings['LOCAL_DOMAIN']
    if($domain -notmatch '^[a-z0-9][a-z0-9.-]*\.test$') { throw 'Invalid .test domain.' }
    $port=$settings['HTTPS_PORT']
    if([string]::IsNullOrWhiteSpace($port)) { $port='443' }
    if($port -notmatch '^\d+$' -or [int]$port -lt 1 -or [int]$port -gt 65535) { throw 'Invalid HTTPS port.' }
    Write-Host "Local HTTPS domain: $domain, port: $port"
    if(-not $SkipHosts) {
        $hostsPath=Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
        $current=Get-Content -LiteralPath $hostsPath
        $matching=@($current | Where-Object { $_ -notmatch '^\s*#' -and $_ -match "(?i)(^|\s)$([regex]::Escape($domain))(\s|$)" })
        if($matching.Count -gt 0) {
            Write-Host "Existing hosts entry: $($matching -join '; ')"
            Write-Host 'Please verify it resolves to 127.0.0.1. No change made.'
        } else {
            $reply=Read-Host "Add '127.0.0.1 $domain' to Windows hosts? (yes/no)"
            if($reply -eq 'yes') {
                $line="127.0.0.1 $domain"
                try {
                    Add-Content -LiteralPath $hostsPath -Value $line -ErrorAction Stop
                    Write-Host 'Updated hosts file.'
                } catch {
                    Write-Warning 'Administrator permissions are required to edit hosts. Open PowerShell as Administrator and retry, or edit hosts manually.'
                    throw
                }
            }
        }
    }
    & docker compose --profile https up -d caddy-local
    if($LASTEXITCODE -ne 0) { throw 'Caddy failed to start. Check whether port 443 is already occupied.' }
    $certDir=Join-Path $root 'certs'
    if(-not (Test-Path -LiteralPath $certDir)) { New-Item -ItemType Directory -Path $certDir | Out-Null }
    $cert=Join-Path $certDir 'caddy-local-root.crt'
    $found=$false
    for($attempt=0;$attempt -lt 10;$attempt++) {
        & docker compose --profile https cp 'caddy-local:/data/caddy/pki/authorities/local/root.crt' $cert 2>$null
        if($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $cert)) { $found=$true; break }
        Start-Sleep -Seconds 1
    }
    if(-not $found) { throw 'Caddy root certificate not available. Inspect docker compose logs caddy-local.' }
    $details=New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($cert)
    Write-Host "Certificate subject: $($details.Subject)"
    Write-Host "Certificate issuer:  $($details.Issuer)"
    Write-Host "SHA256 fingerprint:   $($details.GetCertHashString('SHA256'))"
    if($details.Subject -ne $details.Issuer) { throw 'Unexpected non-self-issued root certificate. Refusing automatic trust.' }
    if(-not $SkipTrust) {
        $answer=Read-Host 'Trust this local CA in YOUR CurrentUser Root certificate store? (yes/no)'
        if($answer -eq 'yes') {
            $store=New-Object System.Security.Cryptography.X509Certificates.X509Store('Root','CurrentUser')
            try { $store.Open('ReadWrite'); $store.Add($details) }
            finally { $store.Close() }
            Write-Host 'Added local CA to CurrentUser trusted roots. Restart the browser if necessary.'
        } else { Write-Host 'Certificate trust not changed.' }
    }
    $suffix=if($port -eq '443'){''}else{":$port"}
    Write-Host "Open https://$domain$suffix/"
} finally { Pop-Location }
