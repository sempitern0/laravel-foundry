<?php
declare(strict_types=1);
require __DIR__.'/../scripts/project-config.php';
function check(bool $condition, string $message): void { if (!$condition) throw new RuntimeException($message); }
$root=sys_get_temp_dir().'/foundry-'.bin2hex(random_bytes(6));
mkdir($root); mkdir($root.'/app');
copy(__DIR__.'/../.env.example',$root.'/.env');
file_put_contents($root.'/app/artisan','fixture');
file_put_contents($root.'/app/.letsgo-starter',"svelte\n");
foundryWriteEnv($root.'/.env',['SETUP_CONFIGURED'=>'1','PROJECT_NAME'=>'demo','DB_ENGINE'=>'mysql','DB_UI'=>'phpmyadmin','QUEUE_ENGINE'=>'redis','HTTPS_ENABLED'=>'1','TENANCY_MODE'=>'shared-db','DB_PASSWORD'=>'private-secret','MAIL_PASSWORD'=>'smtp-secret']);
foundryProject('save',$root,$root.'/app');
$manifest=file_get_contents($root.'/.foundry.json');
check(!str_contains($manifest,'private-secret') && !str_contains($manifest,'MAIL_PASSWORD') && !str_contains($manifest,'DEV_UID'),'Manifest leaked local settings');
copy(__DIR__.'/../.env.example',$root.'/.env');
foundryProject('restore',$root,$root.'/app');
$local=foundryRead($root.'/.env');
check($local['DB_ENGINE']==='mysql' && $local['PROJECT_NAME']==='demo','Clone lost configuration');
check($local['COMPOSE_PROFILES']==='mysql,redis,mailpit,phpmyadmin,https,scheduler,workers','Incorrect profiles');
check($local['CADDY_LOCAL_CONFIG_FILE']==='./docker/caddy/Caddyfile.saas','SaaS config lost');
check($local['DB_PASSWORD']!=='local-only-change-me' && $local['DB_PASSWORD']!=='private-secret','Secrets not regenerated');
foundryWriteEnv($root.'/.env',['HTTP_PORT'=>'9080','DB_PASSWORD'=>'keep-me']);
foundryProject('restore',$root,$root.'/app');
$local=foundryRead($root.'/.env');
check($local['HTTP_PORT']==='9080' && $local['DB_PASSWORD']==='keep-me','Local override replaced');
$before=file_get_contents($root.'/.env');
$bad=json_decode($manifest,true);$bad['settings']['APP_KEY']='injected';
file_put_contents($root.'/.foundry.json',json_encode($bad));
try { foundryProject('restore',$root,$root.'/app'); throw new LogicException('Accepted forbidden key'); } catch (RuntimeException $e) { check(!($e instanceof LogicException),'Invalid manifest accepted'); }
check(file_get_contents($root.'/.env')===$before,'Invalid manifest changed .env');
file_put_contents($root.'/.foundry.json',$manifest);
unlink($root.'/app/artisan');
try { foundryProject('restore',$root,$root.'/app'); throw new LogicException('Recreated missing product'); } catch (RuntimeException $e) { check(!($e instanceof LogicException),'Missing product accepted'); }
foreach (glob($root.'/app/.*') as $p) if (is_file($p)) unlink($p);
rmdir($root.'/app');foreach (glob($root.'/.*') as $p) if (is_file($p)) unlink($p);rmdir($root);
echo "PASS portable settings, profiles, secret exclusion, local overrides and missing-source protection\n";
