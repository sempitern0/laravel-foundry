<?php
declare(strict_types=1);
$root = '/workspace';
$path = "$root/.env";
if (!file_exists($path)) copy("$root/.env.example", $path);
$env = [];
foreach (file($path, FILE_IGNORE_NEW_LINES) as $line) {
    if (preg_match('/^([A-Z][A-Z0-9_]*)=(.*)$/', $line, $m)) $env[$m[1]] = trim($m[2], '"');
}
function ask(string $label, string $default, ?array $allowed = null): string {
    while (true) {
        fwrite(STDOUT, "$label [$default]: ");
        $line = fgets(STDIN);
        if ($line === false) {
            fwrite(STDERR, "Wizard input is not connected to the terminal. Run setup interactively.\n");
            exit(2);
        }
        $value = trim($line) ?: $default;
        if ($allowed === null || in_array($value, $allowed, true)) return $value;
        fwrite(STDERR, "Valid options: ".implode(', ', $allowed)."\n");
    }
}
function yn(string $label, bool $default): bool {
    return ask($label.' (yes/no)', $default ? 'yes' : 'no', ['yes','no']) === 'yes';
}
$existing = ($env['SETUP_CONFIGURED'] ?? '0') === '1';
if ($existing && !yn('Reconfigure existing infrastructure? (No preserves your settings)', false)) {
    echo "Keeping infrastructure settings.\n";
    exit(0);
}
echo "\n=== Laravel Foundry — infrastructure wizard ===\n";
$name = ask('Project slug (Docker Compose project name)', $env['PROJECT_NAME'] ?? 'foundry');
if (!preg_match('/^[a-z][a-z0-9_-]{0,40}$/', $name)) { fwrite(STDERR, "Invalid project slug.\n"); exit(2); }
$label = ask('Application display name', $env['APP_LABEL'] ?? $name);
$db = ask('Database (postgres/mariadb/sqlite)', $env['DB_ENGINE'] ?? 'postgres', ['postgres','mariadb','sqlite']);
$queue = ask('Queue (sync/database/redis)', $env['QUEUE_ENGINE'] ?? 'sync', ['sync','database','redis']);
$mail = ask('Mail (mailpit/log/smtp)', $env['MAIL_ENGINE'] ?? 'mailpit', ['mailpit','log','smtp']);
$ui = ask('Database UI (none/pgweb/adminer)', $env['DB_UI'] ?? ($db === 'postgres' ? 'pgweb' : 'none'), ['none','pgweb','adminer']);
if ($db === 'sqlite' && $ui !== 'none') { echo "No remote database UI for SQLite; disabling.\n"; $ui='none'; }
if ($db !== 'postgres' && $ui === 'pgweb') { echo "Pgweb supports PostgreSQL only; using Adminer.\n"; $ui='adminer'; }
$https = yn('Local HTTPS with Caddy?', ($env['HTTPS_ENABLED'] ?? '0') === '1');
$domain = $https ? ask('Local domain (*.test recommended)', $env['LOCAL_DOMAIN'] ?? "$name.test") : ($env['LOCAL_DOMAIN'] ?? "$name.test");
if ($https && !preg_match('/^[a-z0-9][a-z0-9.-]*\.test$/', $domain)) { fwrite(STDERR, "Use a .test domain, e.g. $name.test\n"); exit(2); }
$httpsPort = $https ? ask('Local HTTPS port (443 avoids typing a port in URLs)', $env['HTTPS_PORT'] ?? '443') : ($env['HTTPS_PORT'] ?? '443');
if (!ctype_digit((string) $httpsPort) || (int) $httpsPort < 1 || (int) $httpsPort > 65535) {
    fwrite(STDERR, "Invalid HTTPS port (1–65535).\n"); exit(2);
}
$profiles = [];
if ($db !== 'sqlite') $profiles[]=$db;
if ($queue === 'redis') $profiles[]='redis';
if ($mail === 'mailpit') $profiles[]='mailpit';
if ($ui !== 'none') $profiles[]=$ui;
if ($https) $profiles[]='https';
if (!$https) $profiles[]='dev';  // Avoid mixed-content Vite HMR over local HTTPS.
$profiles[]='scheduler';
if ($queue !== 'sync') $profiles[]='workers';
$env = array_merge($env, [
    'PROJECT_NAME'=>$name,'APP_LABEL'=>$label,'SETUP_CONFIGURED'=>'1',
    'DB_ENGINE'=>$db,'DB_SERVER'=>$db === 'mariadb' ? 'mariadb' : 'postgres',
    'QUEUE_ENGINE'=>$queue,'MAIL_ENGINE'=>$mail,'DB_UI'=>$ui,
    'HTTPS_ENABLED'=>$https?'1':'0','LOCAL_DOMAIN'=>$domain,'HTTPS_PORT'=>$httpsPort,
    'COMPOSE_PROFILES'=>implode(',', $profiles),
]);
if ($mail === 'smtp') {
    $env['MAIL_HOST']=ask('SMTP hostname', $env['MAIL_HOST'] ?? 'smtp.example.com');
    $env['MAIL_PORT']=ask('SMTP port', $env['MAIL_PORT'] ?? '587');
    $env['MAIL_USERNAME']=ask('SMTP username', $env['MAIL_USERNAME'] ?? '');
    $env['MAIL_PASSWORD']=ask('SMTP password (stored in ignored .env)', $env['MAIL_PASSWORD'] ?? '');
} else {
    $env['MAIL_HOST']=$mail==='mailpit'?'mailpit':'';
    $env['MAIL_PORT']=$mail==='mailpit'?'1025':'';
}
if ($db !== 'sqlite' && ($env['DB_PASSWORD'] ?? '') === 'local-only-change-me')
    $env['DB_PASSWORD']=bin2hex(random_bytes(16));
if ($db === 'mariadb' && ($env['DB_ROOT_PASSWORD'] ?? '') === 'local-only-root-change-me')
    $env['DB_ROOT_PASSWORD']=bin2hex(random_bytes(16));
$lines = [];
foreach ($env as $key=>$value) {
    if (!preg_match('/^[A-Z][A-Z0-9_]*$/', $key)) continue;
    if (strpbrk($value,"\r\n") !== false) throw new RuntimeException("Multiline setting not permitted");
    $lines[]=$key.'="'.str_replace(['\\','"'], ['\\\\','\\"'], $value).'"';
}
file_put_contents($path, implode("\n",$lines)."\n");
echo "\nConfigured $name: DB=$db, queue=$queue, mail=$mail, admin=$ui, HTTPS=".($https?'yes':'no')."\n";
if ($https) echo "Add 127.0.0.1 $domain to your hosts file; then open https://$domain".($httpsPort==='443'?'':":$httpsPort")."\nRun make https-setup on Windows to configure hosts and certificate trust with confirmation.\n";
