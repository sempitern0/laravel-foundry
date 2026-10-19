<?php
declare(strict_types=1);

// Add missing infrastructure keys from the versioned example, without ever
// replacing project-specific values, credentials, comments or custom keys.
// This file runs in the disposable Composer container (Windows and Unix).
$root = getenv('LETSGO_PROJECT_ROOT') ?: '/workspace';
$template = $root . '/.env.example';
$target = $root . '/.env';
$rootOnly = in_array('--root-only', $argv, true);

if (!is_file($template)) {
    fwrite(STDERR, "Missing infrastructure .env.example\n");
    exit(1);
}
if (!file_exists($target)) {
    if (!copy($template, $target)) {
        throw new RuntimeException('Failed to initialize .env from .env.example');
    }
    echo "Created root .env from .env.example\n";
} else {
    $original = file_get_contents($target);
    $example = file_get_contents($template);
    if ($original === false || $example === false) {
        throw new RuntimeException('Cannot read the environment files');
    }
    $keys = [];
    foreach (preg_split('/\r\n|\n|\r/', $original) as $line) {
        if (preg_match('/^\s*([A-Z][A-Z0-9_]*)\s*=/', $line, $m)) {
            $keys[$m[1]] = true;
        }
    }
    $missing = [];
    $names = [];
    foreach (preg_split('/\r\n|\n|\r/', $example) as $line) {
        if (!preg_match('/^([A-Z][A-Z0-9_]*)=/', $line, $m)) {
            continue;
        }
        if (!isset($keys[$m[1]])) {
            $missing[] = $line;
            $names[] = $m[1];
            $keys[$m[1]] = true;
        }
    }
    if ($missing !== []) {
        $newline = str_contains($original, "\r\n") ? "\r\n" : "\n";
        $updated = rtrim($original, "\r\n") . $newline
            . $newline . '# Added by make env-sync (review new defaults)' . $newline
            . implode($newline, $missing) . $newline;
        if (file_put_contents($target, $updated, LOCK_EX) === false) {
            throw new RuntimeException('Unable to update root .env');
        }
        echo 'Added missing configuration keys: ' . implode(', ', $names) . "\n";
    } else {
        echo "Root .env already has all known keys; existing values preserved.\n";
    }
}

if (!$rootOnly && is_file('/var/www/html/artisan')) {
    // Keep generated Laravel runtime settings coherent with root .env, while
    // leaving unrelated variables and the application key unchanged.
    require __DIR__ . '/configure-app.php';
} elseif (!$rootOnly) {
    echo "No Laravel installation detected; app/.env not modified.\n";
}
