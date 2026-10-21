<?php
declare(strict_types=1);

// Version only structural development choices. Credentials, host UID/GID,
// APP_KEY and arbitrary environment variables never enter this manifest.
function foundryKeys(): array {
    return ['PROJECT_NAME','APP_LABEL','DB_ENGINE','DB_DATABASE','DB_USERNAME',
        'QUEUE_ENGINE','MAIL_ENGINE','DB_UI','HTTP_PORT','HTTPS_ENABLED','HTTPS_PORT',
        'LOCAL_DOMAIN','VITE_PORT','DB_UI_PORT','MAILPIT_PORT','TENANCY_MODE',
        'TENANCY_TEST_TENANTS','TENANCY_TEST_PATH','TENANCY_ASSERT_HEADER'];
}
function foundryRead(string $path): array {
    $values = [];
    foreach (file($path, FILE_IGNORE_NEW_LINES) ?: [] as $line) {
        if (preg_match('/^([A-Z][A-Z0-9_]*)=(.*)$/', $line, $m)) {
            $value = trim($m[2]);
            if (str_starts_with($value, '"') && str_ends_with($value, '"')) {
                $value = str_replace(['\\"', '\\\\'], ['"', '\\'], substr($value, 1, -1));
            } elseif (str_starts_with($value, "'") && str_ends_with($value, "'")) {
                $value = substr($value, 1, -1);
            }
            $values[$m[1]] = $value;
        }
    }
    return $values;
}
function foundryValidate(array $values): void {
    foreach ($values as $key => $value) {
        if (!in_array($key, foundryKeys(), true) || !is_string($value)
            || strlen($value) > 200 || preg_match('/[\x00-\x1f\x7f$]/', $value)) {
            throw new RuntimeException('Invalid portable setting: '.$key);
        }
    }
    foreach (['DB_ENGINE'=>['postgres','mariadb','mysql','sqlite'],
        'QUEUE_ENGINE'=>['sync','database','redis'], 'MAIL_ENGINE'=>['mailpit','log','smtp'],
        'DB_UI'=>['none','pgweb','phpmyadmin','adminer'], 'HTTPS_ENABLED'=>['0','1'],
        'TENANCY_MODE'=>['none','shared-db','database-per-tenant']] as $key=>$allowed) {
        if (isset($values[$key]) && !in_array($values[$key],$allowed,true)) throw new RuntimeException('Invalid '.$key);
    }
    if (!preg_match('/^[a-z][a-z0-9_-]{0,40}$/', $values['PROJECT_NAME'] ?? '')) throw new RuntimeException('Invalid PROJECT_NAME');
    foreach (['HTTP_PORT','HTTPS_PORT','VITE_PORT','DB_UI_PORT','MAILPIT_PORT'] as $key) {
        if (isset($values[$key]) && (!ctype_digit($values[$key]) || (int)$values[$key]<1 || (int)$values[$key]>65535)) throw new RuntimeException('Invalid '.$key);
    }
}
function foundryWriteEnv(string $path, array $updates): void {
    $lines = file($path, FILE_IGNORE_NEW_LINES) ?: [];
    foreach ($lines as &$line) {
        if (preg_match('/^([A-Z][A-Z0-9_]*)=/', $line, $m) && array_key_exists($m[1],$updates)) {
            $line = $m[1].'="'.str_replace(['\\','"'],['\\\\','\\"'],$updates[$m[1]]).'"';
            unset($updates[$m[1]]);
        }
    }
    unset($line);
    foreach ($updates as $key=>$value) $lines[]=$key.'="'.str_replace(['\\','"'],['\\\\','\\"'],$value).'"';
    if (file_put_contents($path,implode("\n",$lines)."\n",LOCK_EX)===false) throw new RuntimeException('Cannot write local settings');
}
function foundryProfiles(array $v): array {
    $db=$v['DB_ENGINE']??'postgres'; $queue=$v['QUEUE_ENGINE']??'sync'; $ui=$v['DB_UI']??'none';
    if (($ui==='pgweb' && $db!=='postgres') || ($ui==='phpmyadmin' && !in_array($db,['mysql','mariadb'],true)) || ($db==='sqlite' && $ui!=='none')) throw new RuntimeException('DB_UI is incompatible with DB_ENGINE');
    $profiles=$db==='sqlite'?[]:[$db];
    if ($queue==='redis') $profiles[]='redis';
    if (($v['MAIL_ENGINE']??'log')==='mailpit') $profiles[]='mailpit';
    if ($ui!=='none') $profiles[]=$ui;
    $https=($v['HTTPS_ENABLED']??'0')==='1';
    $profiles[]=$https?'https':'dev'; $profiles[]='scheduler';
    if ($queue!=='sync') $profiles[]='workers';
    return ['COMPOSE_PROFILES'=>implode(',',$profiles),'DB_SERVER'=>$db==='sqlite'?'':$db,
        'CADDY_LOCAL_CONFIG_FILE'=>(($v['TENANCY_MODE']??'none')!=='none' && $https)?'./docker/caddy/Caddyfile.saas':'./docker/caddy/Caddyfile.local'];
}
function foundryProject(string $mode, string $root, string $app): void {
    $path=$root.'/.env'; $manifest=$root.'/.foundry.json';
    $local=foundryRead($path);
    if ($mode==='restore') {
        if (is_file($manifest)) {
            $saved=json_decode(file_get_contents($manifest),true,512,JSON_THROW_ON_ERROR);
            if (($saved['version']??null)!==1 || !is_array($saved['settings']??null)
                || !in_array($saved['starter']??null,['laravel','svelte','vue','react','livewire','existing'],true)) throw new RuntimeException('Unsupported Foundry manifest');
            foundryValidate($saved['settings']);
            // A configured product must bring its actual source, never regenerate it.
            if (!is_file($app.'/artisan')) throw new RuntimeException('Configured project is missing app/artisan. Commit application source and lockfiles in the product repository; refusing to replace it with a starter.');
            if (($local['SETUP_CONFIGURED']??'0')!=='1') {
                $updates=$saved['settings']; $updates['SETUP_CONFIGURED']='1';
                if (($local['DB_PASSWORD']??'')==='local-only-change-me') $updates['DB_PASSWORD']=bin2hex(random_bytes(16));
                if (($local['DB_ROOT_PASSWORD']??'')==='local-only-root-change-me') $updates['DB_ROOT_PASSWORD']=bin2hex(random_bytes(16));
                foundryWriteEnv($path,$updates);
                $local=foundryRead($path);
            }
            file_put_contents($root.'/.foundry-starter',$saved['starter']."\n");
        }
        if (($local['SETUP_CONFIGURED']??'0')==='1') {
            foundryValidate(array_intersect_key($local,array_flip(foundryKeys())));
            foundryWriteEnv($path,foundryProfiles($local));
        }
        echo "Local settings ready; existing configuration retained.\n";
    } elseif ($mode==='save') {
        if (($local['SETUP_CONFIGURED']??'0')!=='1') throw new RuntimeException('Configure the project before saving');
        $settings=array_intersect_key($local,array_flip(foundryKeys())); foundryValidate($settings);
        $starter=is_file($app.'/.letsgo-starter')?trim(file_get_contents($app.'/.letsgo-starter')):(is_file($root.'/.foundry-starter')?trim(file_get_contents($root.'/.foundry-starter')):'existing');
        if (!in_array($starter,['laravel','svelte','vue','react','livewire','existing'],true)) $starter='existing';
        $json=json_encode(['version'=>1,'starter'=>$starter,'settings'=>$settings],JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES|JSON_THROW_ON_ERROR)."\n";
        if (file_put_contents($manifest.'.tmp',$json,LOCK_EX)===false || !rename($manifest.'.tmp',$manifest)) throw new RuntimeException('Cannot save portable project settings');
        echo "Saved .foundry.json (no credentials). Commit it with product source and lockfiles.\n";
    } else throw new RuntimeException('Expected restore or save');
}
if (realpath($_SERVER['SCRIPT_FILENAME']??'')===__FILE__) {
    foundryProject($argv[1]??'',getenv('LETSGO_PROJECT_ROOT')?:'/workspace',getenv('FOUNDRY_APP_ROOT')?:'/var/www/html');
}
