<?php

declare(strict_types=1);

/**
 * Create Laravel's writable runtime tree on a fresh Git checkout.
 *
 * This runs as the same unprivileged UID/GID as PHP-FPM and the frontend
 * builder. No chown, root privileges, volume removal or secret changes.
 */
$root = getenv('FOUNDRY_APP_ROOT') ?: '/var/www/html';

if (! is_file($root.'/artisan') || ! is_file($root.'/composer.json')) {
    fwrite(STDERR, "Laravel Foundry source is missing in {$root}.\n");
    exit(1);
}

$directories = [
    'bootstrap/cache',
    'storage',
    'storage/app',
    'storage/app/private',
    'storage/app/public',
    'storage/framework',
    'storage/framework/cache',
    'storage/framework/cache/data',
    'storage/framework/sessions',
    'storage/framework/testing',
    'storage/framework/views',
    'storage/logs',
];

foreach ($directories as $directory) {
    $path = $root.'/'.$directory;

    if (! is_dir($path) && ! mkdir($path, 0775, true) && ! is_dir($path)) {
        fwrite(STDERR, "Cannot create {$path}. Check Docker bind mount and DEV_UID/DEV_GID.\n");
        exit(1);
    }

    if (! is_writable($path)) {
        fwrite(STDERR, "Directory not writable: {$path}. Check DEV_UID/DEV_GID.\n");
        exit(1);
    }
}

echo "Laravel Foundry Laravel runtime directories are ready.\n";

if (!is_file($root.'/.env')) {
    if (!is_file($root.'/.env.example') || !copy($root.'/.env.example', $root.'/.env')) {
        throw new RuntimeException('Missing app/.env.example; cannot initialize Laravel settings.');
    }
}
