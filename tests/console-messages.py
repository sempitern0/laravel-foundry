"""Guard Foundry's terminal language and diagnostic semantics."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
ps=(root/'scripts/status.ps1').read_text(encoding='utf-8')
sh=(root/'scripts/status.sh').read_text(encoding='utf-8')
for label in ('ENDPOINTS','CONFIGURATION','SERVICES','NEXT STEPS'):
    assert label in sh, label
for label in ('Endpoints','Configuration','Services','Next steps'):
    assert label in ps, label
for phrase in ('healthy','running','unhealthy'):
    assert phrase in ps, phrase
for content in (ps, sh):
    assert 'Primary app' in content
    assert 'Application HTTP' in content
    assert 'Laravel' in content
    assert 'DB_PASSWORD' not in content
    assert not any(word in content for word in ('En marcha','Contenedores','Configuracion','Accesos web','Aplicacion HTTP'))
make=(root/'Makefile').read_text()
assert 'doctor:' in make and 'status:' in make
assert 'up:\n\t@$(HOST_PREPARE)' in make
print('PASS console headings, health terminology, and cross-platform command consistency')
