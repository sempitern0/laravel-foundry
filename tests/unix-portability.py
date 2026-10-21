"""Exercise real POSIX entry points with isolated files and fake Docker/curl."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
failures = []
checks = 0


def expect(condition, message):
    global checks
    checks += 1
    if not condition:
        failures.append(message)


with tempfile.TemporaryDirectory(prefix='foundry unix ') as directory:
    work = Path(directory)
    shutil.copytree(ROOT / 'scripts', work / 'scripts')
    shutil.copy(ROOT / '.env.example', work / '.env.example')
    (work / 'app').mkdir()
    for name in ('artisan', 'composer.json'):
        (work / 'app' / name).write_text('{}')
    (work / '.foundry.json').write_text('{}')
    (work / 'certs').mkdir()
    (work / 'certs/caddy-local-root.crt').write_text('fixture CA')
    (work / 'bin').mkdir()
    docker = work / 'bin/docker'
    docker.write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
with open(os.environ['CALL_LOG'], 'a') as log:
    log.write(json.dumps(args) + '\\n')
if os.environ.get('DOCKER_FAIL') == '1' or (os.environ.get('DOCKER_FAIL') == 'engine' and args[:1] == ['info']):
    sys.exit(1)
if args[:2] == ['compose', 'ps']:
    print('app\\nweb\\ncaddy-local\\npostgres\\nmailpit')
if args[:2] == ['compose', 'cp']:
    Path(args[-1]).write_text('fixture dump')
''')
    docker.chmod(0o755)
    curl = work / 'bin/curl'
    curl.write_text('#!/bin/sh\nprintf 200\n')
    curl.chmod(0o755)
    env = dict(os.environ, PATH=str(work / 'bin') + os.pathsep + os.environ['PATH'],
               CALL_LOG=str(work / 'calls.jsonl'))
    config = ('PROJECT_NAME="unix-demo"\nDB_ENGINE="postgres"\n'
              'DB_DATABASE="foundry"\nDB_USERNAME="foundry"\nQUEUE_ENGINE="sync"\n'
              'MAIL_ENGINE="mailpit"\nDB_UI="none"\nHTTPS_ENABLED="1"\n'
              'LOCAL_DOMAIN="unix-demo.test"\nTENANCY_MODE="shared-db"\n'
              'HTTP_PORT="18080"\nHTTPS_PORT="18443"\nMAILPIT_PORT="18025"\n')

    def configure(text=config):
        (work / '.env').write_bytes(text.replace('\n', '\r\n').encode())

    def run(script, *args, extra=None):
        return subprocess.run(['sh', str(work / 'scripts' / script), *args],
                              cwd=work.parent, env=dict(env, **(extra or {})),
                              input='', text=True, capture_output=True, timeout=60)

    configure()
    result = run('preflight.sh')
    expect(result.returncode == 0, 'preflight must accept quoted CRLF settings')
    result = run('status.sh')
    expect('https://unix-demo.test:18443' in result.stdout, 'status must render a clean CRLF HTTPS URL')
    result = run('tenancy-check.sh')
    expect(result.returncode == 0, 'tenant routing must accept CRLF settings')
    result = run('backup.sh')
    expect(result.returncode == 0, 'backup must accept quoted CRLF DB names')
    for key in ('base64:existing-key', '"base64:existing-key"', ''):
        configure()
        (work / 'app/.env').write_bytes(('APP_KEY=' + key + '\r\n').encode())
        (work / 'calls.jsonl').write_text('')
        result = run('setup.sh')
        calls = [json.loads(line) for line in (work / 'calls.jsonl').read_text().splitlines()]
        expect(result.returncode == 0, 'setup must complete with Windows-created settings')
        expect(any('key:generate' in call for call in calls) == (key == ''),
               'setup must preserve existing CRLF APP_KEY and generate only when empty')
        expect(['compose', 'up', '-d', '--wait', '--wait-timeout', '120', 'postgres'] in calls,
               'setup must wait for selected CRLF database')

    configure(config.replace('shared-db', 'invalid'))
    expect(run('preflight.sh').returncode != 0, 'preflight must reject invalid tenancy')
    configure()
    expect(run('preflight.sh', 'typo').returncode != 0, 'preflight must reject unknown mode')

    # A fresh setup must not replace local settings when Docker is unavailable.
    shutil.rmtree(work / 'app')
    (work / '.foundry.json').unlink()
    (work / '.foundry-setup-pending').unlink(missing_ok=True)
    configure()
    before = (work / '.env').read_bytes()
    for failure in ('1', 'engine'):
        result = run('setup.sh', extra={'DOCKER_FAIL': failure})
        expect(result.returncode != 0, 'setup must fail if Docker cannot run')
        expect((work / '.env').read_bytes() == before, 'unavailable Docker must not rewrite .env')

if failures:
    raise SystemExit('\n'.join('FAIL: ' + item for item in failures))
print(f'PASS {checks} Unix portability and setup safety checks (mocked Docker/curl)')
