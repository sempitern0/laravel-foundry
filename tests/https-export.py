"""Run the Unix HTTPS helper against a fake Docker CLI, without a daemon or CA trust."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[1]


class HttpsExportTest(unittest.TestCase):
    def run_export(self, succeed_at=1, up_code=0):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'scripts').mkdir()
            (root / 'bin').mkdir()
            shutil.copy(SOURCE / 'scripts/https-setup.sh', root / 'scripts')
            docker = root / 'bin/docker'
            docker.write_text('''#!/bin/sh
if [ "$4" = up ]; then exit "$UP_CODE"; fi
count=0
[ ! -f count ] || count=$(cat count)
count=$((count + 1))
echo "$count" > count
if [ "$count" -lt "$SUCCEED_AT" ]; then echo pending >&2; exit 1; fi
printf certificate > "$6"
''')
            docker.chmod(0o755)
            sleep = root / 'bin/sleep'
            sleep.write_text('#!/bin/sh\nexit 0\n')
            sleep.chmod(0o755)
            env = dict(os.environ, PATH=f'{root / "bin"}:{os.environ["PATH"]}',
                       SUCCEED_AT=str(succeed_at), UP_CODE=str(up_code))
            result = subprocess.run(['sh', str(root / 'scripts/https-setup.sh')],
                                    env=env, capture_output=True, text=True)
            attempts = int((root / 'count').read_text()) if (root / 'count').exists() else 0
            return result, attempts

    def test_immediate_export(self):
        result, attempts = self.run_export()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(attempts, 1)

    def test_delayed_ca(self):
        result, attempts = self.run_export(3)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(attempts, 3)

    def test_bounded_failure(self):
        result, attempts = self.run_export(11)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(attempts, 10)
        self.assertIn('certificate not available', result.stderr)

    def test_start_failure(self):
        result, attempts = self.run_export(up_code=7)
        self.assertEqual(result.returncode, 7)
        self.assertEqual(attempts, 0)


if __name__ == '__main__':
    unittest.main()
