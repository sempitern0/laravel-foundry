#!/usr/bin/env php
<?php
declare(strict_types=1);

// Executed before any Docker invocation, on an empty checkout only.
// Existing apps and portable projects are deliberately untouched.
$root = getenv('LETSGO_PROJECT_ROOT') ?: dirname(__DIR__);
$app = $root.'/app';
if (is_file($app.'/artisan')) exit(0);
if (is_file($root.'/.foundry.json')) {
    fwrite(STDERR, "Configured project has no app/artisan. Restore its source before setup.\n");
    exit(2);
}
if (is_dir($app)) {
    foreach (new DirectoryIterator($app) as $entry) {
        if ($entry->isDot() || $entry->getFilename() === 'node_modules') continue;
        fwrite(STDERR, "app/ contains files but no artisan; refusing to overwrite.\n");
        exit(2);
    }
}
$template = $root.'/.env.example';
$target = $root.'/.env';
if (!is_file($template)) {
    fwrite(STDERR, "Missing .env.example.\n");
    exit(2);
}
$defaults = file_get_contents($template);
if (is_file($target) && file_get_contents($target) !== $defaults) {
    $dir = $root.'/app-backups';
    if (!is_dir($dir) && !mkdir($dir, 0775, true) && !is_dir($dir)) throw new RuntimeException('Cannot create backup directory.');
    $backup = $dir.'/foundry-env-'.gmdate('Ymd-His').'-'.bin2hex(random_bytes(4)).'.bak';
    if (!copy($target, $backup)) throw new RuntimeException('Cannot backup previous local .env.');
    echo "Previous local settings backed up under app-backups/.\n";
}
$slug = strtolower(preg_replace('/[^a-zA-Z0-9_-]/', '-', basename($root)));
$slug = trim($slug, '-');
if (!preg_match('/^[a-z]/', $slug)) $slug = 'project-'.$slug;
$slug = substr($slug, 0, 26);
$name = $slug.'-'.bin2hex(random_bytes(4));
$updated = preg_replace('/^PROJECT_NAME=.*$/m', 'PROJECT_NAME='.$name, $defaults);
if ($updated === null || file_put_contents($target, $updated, LOCK_EX) === false) throw new RuntimeException('Cannot create fresh project environment.');
if (is_file($root.'/.foundry-starter')) unlink($root.'/.foundry-starter');
echo "New project: $name. Choose settings in the wizard.\n";
