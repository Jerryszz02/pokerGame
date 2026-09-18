"""The file-to-Secret path must never put a real key in arguments or output."""
import contextlib
import io
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest

from configure_coach_worker import upload_secret


class ConfigureWorkerTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.key = 'test-only-never-a-real-credential'
        self.env_file = self.root / '.env.local'
        self.env_file.write_text('DEEPSEEK_API_KEY=' + self.key + '\n')
        executable = self.root / 'node_modules/wrangler/bin/wrangler.js'
        executable.parent.mkdir(parents=True)
        executable.touch()

    def test_secret_uses_pipe_and_provider_output_is_not_echoed(self):
        calls = []

        def runner(command, **kwargs):
            calls.append((command, kwargs))
            return SimpleNamespace(returncode=0, stdout=self.key, stderr=self.key)

        output = io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
            upload_secret(self.env_file, self.root, runner)
        command, kwargs = calls[0]
        self.assertNotIn(self.key, ' '.join(command))
        self.assertEqual(kwargs['input'], self.key + '\n')
        self.assertTrue(kwargs['capture_output'])
        self.assertNotIn('shell', kwargs)
        self.assertEqual(output.getvalue(), '')

    def test_invalid_private_file_never_invokes_wrangler(self):
        self.env_file.write_text('DEEPSEEK_API_KEY=\n')
        with self.assertRaises(ValueError):
            upload_secret(self.env_file, self.root, lambda *a, **k: self.fail('must not invoke Wrangler'))

    def test_provider_failure_does_not_expose_secret(self):
        def runner(*_args, **_kwargs):
            return SimpleNamespace(returncode=1, stdout=self.key, stderr=self.key)

        with self.assertRaises(RuntimeError) as raised:
            upload_secret(self.env_file, self.root, runner)
        self.assertNotIn(self.key, str(raised.exception))


if __name__ == '__main__':
    unittest.main()
