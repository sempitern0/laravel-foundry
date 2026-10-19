"""Check Compose rendering without a Docker daemon or real environment secrets."""
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
for host_values in (False, True):
    env = dict(os.environ, APP_IMAGE='example.invalid/php:test',
               WEB_IMAGE='example.invalid/web:test', APP_DOMAIN='example.test',
               APP_ENV_FILE='./app.production.env.example',
               DB_ENV_FILE='./db.production.env.example')
    for name in ('MYSQL_ROOT_PASSWORD', 'POSTGRES_USER', 'POSTGRES_DB'):
        env.pop(name, None)
        if host_values:
            env[name] = 'host-value-must-not-replace-container-value'
    for filename, service, variables in (
        ('compose.yaml', 'mysql', ('MYSQL_ROOT_PASSWORD',)),
        ('compose.production.yaml', 'postgres', ('POSTGRES_USER', 'POSTGRES_DB')),
    ):
        result = subprocess.run(
            ['docker', 'compose', '--env-file', '/dev/null', '-f', filename,
             '--profile', '*', 'config', '--format', 'json'],
            cwd=ROOT, env=env, capture_output=True, text=True, check=True)
        services = json.loads(result.stdout)['services']
        if filename == 'compose.yaml':
            for app_service in ('app', 'composer', 'node', 'worker', 'scheduler'):
                assert 'APP_ENV' not in (services[app_service].get('environment') or {}), app_service
        command = services[service]['healthcheck']['test'][1]
        assert 'host-value-must-not-replace-container-value' not in command
        for name in variables:
            assert '$' + name in command, (filename, name)
            assert name not in result.stderr, result.stderr
print('Container healthcheck variables survive Compose rendering with and without host values.')
