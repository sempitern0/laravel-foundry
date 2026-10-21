"""Exercise make build twice with Docker calls recorded, without real volumes."""
import json, os, pathlib, shutil, subprocess, tempfile
root = pathlib.Path(__file__).resolve().parents[1]
php = os.environ.get('PHP_BIN', 'php')
with tempfile.TemporaryDirectory() as temp:
    work = pathlib.Path(temp)
    shutil.copytree(root/'scripts', work/'scripts')
    for name in ('Makefile', '.env.example'):
        shutil.copy(root/name, work/name)
    app=work/'app'; app.mkdir()
    for name, content in {'artisan':'fixture', 'composer.json':'{}', 'composer.lock':'{}', 'package.json':'{}', '.env.example':'APP_KEY=\n', '.env':'APP_KEY=base64:existing-key\n'}.items():
        (app/name).write_text(content)
    (work/'.foundry.json').write_text(json.dumps({'version':1,'starter':'svelte','settings':{'PROJECT_NAME':'clone-demo','DB_ENGINE':'postgres','DB_UI':'none','QUEUE_ENGINE':'sync','MAIL_ENGINE':'log','HTTPS_ENABLED':'0','TENANCY_MODE':'none'}}))
    bin_dir=work/'bin';bin_dir.mkdir()
    docker=bin_dir/'docker'
    docker.write_text('''#!/usr/bin/env python3
import os,sys,subprocess,json
from pathlib import Path
args=sys.argv[1:]
with open('docker.log','a') as f: f.write(json.dumps(args)+'\\n')
if 'php' in args:
    i=args.index('php'); command=args[i+1:]
    if command and command[0].startswith('/opt/letsgo/'):
        command[0]='scripts/'+Path(command[0]).name
        sys.exit(subprocess.call([os.environ['PHP_BIN']]+command))
''')
    docker.chmod(0o755)
    env=dict(os.environ, PATH=str(bin_dir)+os.pathsep+os.environ['PATH'], PHP_BIN=php, LETSGO_PROJECT_ROOT=str(work), FOUNDRY_APP_ROOT=str(app))
    for _ in range(2):
        subprocess.run(['make','build'],cwd=work,env=env,stdin=subprocess.DEVNULL,check=True,stdout=subprocess.PIPE)
    calls=[json.loads(line) for line in (work/'docker.log').read_text().splitlines()]
    text=json.dumps(calls)
    assert 'checkout-starter' not in text and 'key:generate' not in text
    assert 'remove' not in text and '--volumes' not in text and 'down' not in text
    assert (app/'composer.lock').read_text()=='{}'
    assert 'APP_KEY=base64:existing-key' in (app/'.env').read_text()
    assert (app/'storage/framework/views').is_dir()
    assert json.loads((work/'.foundry.json').read_text())['starter']=='svelte'
    install=next(i for i,c in enumerate(calls) if 'install' in c)
    prepare=next(i for i,c in enumerate(calls) if '/opt/letsgo/prepare-app.php' in c)
    migrate=next(i for i,c in enumerate(calls) if 'migrate' in c)
    assets=next(i for i,c in enumerate(calls) if c[-3:]==['node','run','build'])
    assert prepare < install < migrate < assets
print('PASS cloned configured project: unattended repeat builds, source/key preserved, dependency and asset ordering')
