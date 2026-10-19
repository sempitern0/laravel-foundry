[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    $settings=@{}
    foreach($line in Get-Content '.env') {
        if($line -match '^([A-Z][A-Z0-9_]*)=(.*)$') { $settings[$Matches[1]]=$Matches[2].Trim('"') }
    }
    if($settings['TENANCY_MODE'] -eq 'none') { throw 'SaaS blueprint not enabled. Run make setup and reconfigure infrastructure.' }
    $domain=$settings['LOCAL_DOMAIN']
    if($domain -notmatch '^[a-z0-9][a-z0-9.-]*\.test$') { throw 'Invalid .test domain.' }
    $https=$settings['HTTPS_ENABLED'] -eq '1'
    $port=if($https){$settings['HTTPS_PORT']}else{$settings['HTTP_PORT']}
    if(!$port){$port=if($https){'443'}else{'8080'}}
    $slugs=($settings['TENANCY_TEST_TENANTS'] -split ',')
    $path=$settings['TENANCY_TEST_PATH']; if(!$path){$path='/'}
    if(!$path.StartsWith('/') -or $path.StartsWith('//')) { throw 'TENANCY_TEST_PATH must be a relative URL path.' }
    $expectedHeader=$settings['TENANCY_ASSERT_HEADER']
    $failures=0
    foreach($slug in $slugs) {
        if($slug -notmatch '^[a-z][a-z0-9-]{0,40}$') { throw "Invalid tenant slug: $slug" }
        $hostName="$slug.$domain"
        $scheme=if($https){'https'}else{'http'}
        $url = '{0}://{1}:{2}{3}' -f $scheme, $hostName, $port, $path
        $args=@('--silent','--show-error','--max-time','10','--resolve',"${hostName}:${port}:127.0.0.1",'-D','-','-o','NUL',$url)
        if($https) {
            $cert=Join-Path $root 'certs/caddy-local-root.crt'
            if(!(Test-Path $cert)) { throw 'Missing Caddy CA file. Run make https-setup and inspect/trust the CA.' }
            $args=@('--cacert',$cert)+$args
        }
        $headers=& curl.exe @args
        if($LASTEXITCODE -ne 0) { Write-Warning "$url failed";$failures++;continue }
        $status=@($headers | Where-Object {$_ -match '^HTTP/\S+\s+(\d+)'}) | Select-Object -Last 1
        if($status -notmatch '^HTTP/\S+\s+([23]\d\d)') { Write-Warning "$url returned $status";$failures++;continue }
        if($expectedHeader) {
            $value=@($headers | Where-Object {$_ -match "^(?i:$([regex]::Escape($expectedHeader))):\s*(.*)$"}) | Select-Object -Last 1
            if(!$value -or $value -notmatch "^(?i:$([regex]::Escape($expectedHeader))):\s*$([regex]::Escape($slug))\s*$") {
                Write-Warning "$url did not return expected $expectedHeader=$slug";$failures++;continue
            }
        }
        Write-Host "PASS $url"
    }
    if($failures -ne 0) { throw "$failures tenancy routing checks failed." }
    Write-Host 'Hostname check passed. Real data isolation requires Laravel feature tests (see docs/SAAS.md).'
} finally {Pop-Location}
