<?php
declare(strict_types=1);
$root = getenv('LETSGO_PROJECT_ROOT') ?: '/workspace';
$appRoot = getenv('FOUNDRY_APP_ROOT') ?: '/var/www/html';
$env=[];
foreach (file("$root/.env",FILE_IGNORE_NEW_LINES) as $line) {
    if(preg_match('/^([A-Z][A-Z0-9_]*)=(.*)$/',$line,$m)) {
        $value=trim($m[2]);
        $env[$m[1]]=trim($value,'"');
    }
}
$appPath=$appRoot.'/.env';
if (!file_exists($appPath)) copy($appRoot.'/.env.example',$appPath);
$https=($env['HTTPS_ENABLED']??'0')==='1';
$db=$env['DB_ENGINE']??'postgres';
$mail=$env['MAIL_ENGINE']??'mailpit';
$queue=$env['QUEUE_ENGINE']??'sync';
$values=[
    'APP_NAME'=>$env['APP_LABEL']??'Laravel',
    'APP_URL'=>$https?'https://'.$env['LOCAL_DOMAIN'].(($env['HTTPS_PORT']??'443')==='443'?'':':'.$env['HTTPS_PORT']):'http://localhost:'.($env['HTTP_PORT']??'8080'),
    'DB_CONNECTION'=> $db==='postgres'?'pgsql':(in_array($db, ['mariadb','mysql'], true)?'mysql':'sqlite'),
    'DB_HOST'=> in_array($db, ['mariadb','mysql'], true)?$db:'postgres',
    'DB_PORT'=> in_array($db, ['mariadb','mysql'], true)?'3306':'5432',
    'DB_DATABASE'=> $db==='sqlite'?'/var/www/html/database/database.sqlite':($env['DB_DATABASE']??'letsgo'),
    'DB_USERNAME'=>$env['DB_USERNAME']??'letsgo',
    'DB_PASSWORD'=>$env['DB_PASSWORD']??'',
    'QUEUE_CONNECTION'=>$queue,
    'CACHE_STORE'=>'database',
    'SESSION_DRIVER'=>'database',
    'REDIS_HOST'=>'redis',
    'MAIL_MAILER'=>$mail==='smtp'?'smtp':($mail==='mailpit'?'smtp':'log'),
    'MAIL_HOST'=>$env['MAIL_HOST']??'mailpit',
    'MAIL_PORT'=>$env['MAIL_PORT']??'1025',
    'MAIL_USERNAME'=>$env['MAIL_USERNAME']??'',
    'MAIL_PASSWORD'=>$env['MAIL_PASSWORD']??'',
    'MAIL_FROM_ADDRESS'=>$env['MAIL_FROM_ADDRESS']??'hello@example.test',
];
$old=file($appPath,FILE_IGNORE_NEW_LINES);
$seen=[];
foreach($old as &$line){
    if(preg_match('/^([A-Z][A-Z0-9_]*)=/',$line,$m)&&array_key_exists($m[1],$values)){
        $key=$m[1];$value=$values[$key];
        $line=$key.'="'.str_replace(['\\','"'],['\\\\','\\"'],$value).'"';
        $seen[$key]=true;
    }
}unset($line);
foreach($values as $key=>$value)if(!isset($seen[$key]))$old[]=$key.'="'.str_replace(['\\','"'],['\\\\','\\"'],$value).'"';
file_put_contents($appPath,implode("\n",$old)."\n");
if($db==='sqlite'){
    $dbFile=$appRoot.'/database/database.sqlite';
    if(!file_exists($dbFile))touch($dbFile);
}
echo "Laravel environment configured ($db / $queue / $mail).\n";
