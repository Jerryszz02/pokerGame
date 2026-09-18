#!/usr/bin/env python3
"""Preflight and command-construction tests for tools/upload_itch.py.

Every package and manifest here is synthetic and every Butler invocation is a
mock: the tests never need Butler, the network, Godot, or a real upload.
"""
import contextlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock
import zipfile

TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import build_release  # noqa: E402
import upload_itch  # noqa: E402

ROOT = TOOLS.parent
COMMIT = 'a' * 40


def write_web_zip(path):
    """A Web ZIP that satisfies the real build_release.validate_web_archive."""
    with zipfile.ZipFile(path, 'w') as archive:
        for name in build_release.WEB_REQUIRED_MEMBERS:
            archive.writestr(name, b'x' * 8)
        archive.writestr('README.md', b'readme')
        archive.writestr('THIRD_PARTY_NOTICES.md', b'notices')
        archive.writestr('licenses/NotoSansSC-OFL.txt', b'ofl')
        for item in (ROOT / 'assets/licenses').glob('*.txt'):
            archive.writestr('licenses/' + item.name, item.read_bytes())
    return path


def make_package(packages, target, version='1.2.0', commit=COMMIT, dirty=False,
                 filename=None, sha256=None, size=None):
    packages = Path(packages)
    packages.mkdir(parents=True, exist_ok=True)
    label = build_release.target_label(target)
    name = f'PokerGame-{version}-{label}.zip' if filename is None else filename
    package = packages / name
    if target == 'web':
        write_web_zip(package)
    else:
        package.write_bytes(b'synthetic-package')
    manifest = {
        'version': version,
        'commit': commit,
        'dirty': dirty,
        'target': label,
        'filename': name,
        'sha256': build_release.sha256(package) if sha256 is None else sha256,
        'bytes': package.stat().st_size if size is None else size,
        'public_release_ready': False,
    }
    (packages / f'{label}-manifest.json').write_text(json.dumps(manifest), encoding='utf-8')
    return package, manifest


def write_manifest(packages, target, manifest):
    label = build_release.target_label(target)
    (Path(packages) / f'{label}-manifest.json').write_text(json.dumps(manifest), encoding='utf-8')


def run_main(packages, *args):
    return upload_itch.main(['--packages-dir', str(packages), *args])


def quiet_run_main(packages, *args):
    """Run the CLI while swallowing its normal output for tests that assert only a code."""
    with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
        return run_main(packages, *args)


class ChannelCommandTests(unittest.TestCase):
    def test_channel_names(self):
        self.assertEqual(upload_itch.channel_for('web'), 'web')
        self.assertEqual(upload_itch.channel_for('windows'), 'windows-x64')
        self.assertEqual(upload_itch.channel_for('macos'), 'macos-universal')

    def test_expected_filename(self):
        self.assertEqual(upload_itch.expected_filename('windows', '1.2.0'),
                         'PokerGame-1.2.0-windows-x64.zip')

    def test_command_shape_and_version(self):
        entry = {'target': 'windows', 'version': '1.2.0', 'commit': COMMIT,
                 'package': Path('/tmp/export/packages/PokerGame-1.2.0-windows-x64.zip')}
        command = upload_itch.butler_command('butler', 'jerryszz02/poker-game', entry)
        self.assertEqual(command[:2], ['butler', 'push'])
        self.assertEqual(command[2], str(entry['package']))
        self.assertEqual(command[3], 'jerryszz02/poker-game:windows-x64')
        self.assertEqual(command[4:], ['--userversion', '1.2.0'])
        self.assertNotIn('--hidden', command)

    def test_hidden_flag_appended(self):
        entry = {'target': 'web', 'version': '1.2.0', 'commit': COMMIT,
                 'package': Path('/tmp/web.zip')}
        command = upload_itch.butler_command('butler', 'u/g', entry, hidden=True)
        self.assertEqual(command[-1], '--hidden')

    def test_help_exits_zero(self):
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as caught:
                upload_itch.main(['--help'])
        self.assertEqual(caught.exception.code, 0)


class PreflightTests(unittest.TestCase):
    def test_all_targets_preflight_and_dry_run(self):
        with tempfile.TemporaryDirectory() as tmp:
            for target in ('web', 'windows', 'macos'):
                make_package(tmp, target)
            with mock.patch.object(upload_itch.subprocess, 'run') as run:
                code = quiet_run_main(tmp, '--target', 'all', '--dry-run')
            self.assertEqual(code, 0)
            run.assert_not_called()

    def test_dry_run_prints_exact_commands(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_package(tmp, 'web')
            buffer = io.StringIO()
            with mock.patch('sys.stdout', buffer), \
                    mock.patch.object(upload_itch.subprocess, 'run') as run:
                code = run_main(tmp, '--target', 'web', '--dry-run')
            output = buffer.getvalue()
            self.assertEqual(code, 0)
            run.assert_not_called()
            self.assertIn('jerryszz02/poker-game:web', output)
            self.assertIn('--userversion 1.2.0', output)
            self.assertIn('PokerGame-1.2.0-web.zip', output)

    def test_expected_commit_match(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_package(tmp, 'windows', commit=COMMIT)
            self.assertEqual(quiet_run_main(tmp, '--target', 'windows', '--dry-run',
                                            '--expected-commit', COMMIT.upper()), 0)

    def test_expected_commit_mismatch(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_package(tmp, 'windows', commit=COMMIT)
            with mock.patch.object(upload_itch.subprocess, 'run') as run:
                code = quiet_run_main(tmp, '--target', 'windows', '--expected-commit', 'b' * 40)
            self.assertEqual(code, 2)
            run.assert_not_called()

    def test_public_release_ready_false_is_not_blocking(self):
        with tempfile.TemporaryDirectory() as tmp:
            _, manifest = make_package(tmp, 'windows')
            self.assertFalse(manifest['public_release_ready'])
            self.assertEqual(quiet_run_main(tmp, '--target', 'windows', '--dry-run'), 0)


class RejectionTests(unittest.TestCase):
    def assert_rejected(self, tmp, target='windows', needle=None, **kwargs):
        with mock.patch.object(upload_itch.subprocess, 'run') as run:
            with mock.patch('sys.stderr', new_callable=io.StringIO) as err, \
                    contextlib.redirect_stdout(io.StringIO()):
                code = run_main(tmp, '--target', target, **kwargs)
        self.assertEqual(code, 2)
        run.assert_not_called()
        if needle:
            self.assertIn(needle, err.getvalue())
        return err.getvalue()

    def test_missing_manifest(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assert_rejected(tmp, needle='missing manifest')

    def test_malformed_json(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / 'windows-x64-manifest.json').write_text('{not json')
            self.assert_rejected(tmp, needle='cannot read')

    def test_manifest_not_object(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / 'windows-x64-manifest.json').write_text('[1, 2]')
            self.assert_rejected(tmp, needle='JSON object')

    def test_wrong_target(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_package(tmp, 'windows')
            manifest = json.loads((Path(tmp) / 'windows-x64-manifest.json').read_text())
            manifest['target'] = 'web'
            write_manifest(tmp, 'windows', manifest)
            self.assert_rejected(tmp, needle='manifest target')

    def test_dirty_candidate_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_package(tmp, 'windows', dirty=True)
            self.assert_rejected(tmp, needle='dirty must be exactly false')

    def test_bad_version_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_package(tmp, 'windows')
            manifest = json.loads((Path(tmp) / 'windows-x64-manifest.json').read_text())
            manifest['version'] = '../escape'
            write_manifest(tmp, 'windows', manifest)
            self.assert_rejected(tmp, needle='version')

    def test_bad_commit_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_package(tmp, 'windows', commit='deadbeef')
            self.assert_rejected(tmp, needle='full Git SHA')

    def test_missing_field_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_package(tmp, 'windows')
            manifest = json.loads((Path(tmp) / 'windows-x64-manifest.json').read_text())
            del manifest['sha256']
            write_manifest(tmp, 'windows', manifest)
            self.assert_rejected(tmp, needle='sha256')

    def test_tampered_size_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            _, manifest = make_package(tmp, 'windows', size=999)
            self.assertEqual(manifest['bytes'], 999)
            self.assert_rejected(tmp, needle='size')

    def test_tampered_sha_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            package, manifest = make_package(tmp, 'windows')
            # Same byte length as the manifest recorded, so only the digest differs.
            package.write_bytes(b'X' * manifest['bytes'])
            self.assert_rejected(tmp, needle='sha256')

    def test_filename_mismatch_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_package(tmp, 'windows', filename='PokerGame-1.2.0-windows.zip')
            self.assert_rejected(tmp, needle='filename')

    def test_symlink_escape_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            packages = Path(tmp) / 'packages'
            outside = Path(tmp) / 'outside.zip'
            outside.write_bytes(b'outside')
            packages.mkdir()
            name = 'PokerGame-1.2.0-windows-x64.zip'
            (packages / name).symlink_to(outside)
            manifest = {
                'version': '1.2.0', 'commit': COMMIT, 'dirty': False, 'target': 'windows-x64',
                'filename': name, 'sha256': build_release.sha256(outside),
                'bytes': outside.stat().st_size,
            }
            write_manifest(packages, 'windows', manifest)
            with mock.patch.object(upload_itch.subprocess, 'run') as run:
                with mock.patch('sys.stderr', new_callable=io.StringIO) as err, \
                        contextlib.redirect_stdout(io.StringIO()):
                    code = run_main(packages, '--target', 'windows')
            self.assertEqual(code, 2)
            run.assert_not_called()
            self.assertIn('escapes the packages directory', err.getvalue())

    def test_mixed_versions_rejected_for_all(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_package(tmp, 'web', version='1.2.0')
            make_package(tmp, 'windows', version='1.2.1')
            make_package(tmp, 'macos', version='1.2.1')
            self.assert_rejected(tmp, target='all', needle='mixed versions')

    def test_mixed_commits_rejected_for_all(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_package(tmp, 'web', commit=COMMIT)
            make_package(tmp, 'windows', commit='b' * 40)
            make_package(tmp, 'macos', commit='b' * 40)
            self.assert_rejected(tmp, target='all', needle='mixed source commits')

    def test_all_targets_preflight_before_any_push(self):
        # A late invalid target must stop the run before any valid package is pushed.
        with tempfile.TemporaryDirectory() as tmp:
            make_package(tmp, 'web')
            make_package(tmp, 'windows')
            make_package(tmp, 'macos')
            (Path(tmp) / 'macos-universal-manifest.json').write_text('{broken')
            with mock.patch.object(upload_itch.subprocess, 'run') as run:
                code = quiet_run_main(tmp, '--target', 'all')
            self.assertEqual(code, 2)
            run.assert_not_called()


class WebArchiveTests(unittest.TestCase):
    def test_valid_web_archive_accepted(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_package(tmp, 'web')
            self.assertEqual(quiet_run_main(tmp, '--target', 'web', '--dry-run'), 0)

    def test_invalid_root_rejected_by_real_validator(self):
        with tempfile.TemporaryDirectory() as tmp:
            packages = Path(tmp)
            name = 'PokerGame-1.2.0-web.zip'
            package = packages / name
            with zipfile.ZipFile(package, 'w') as archive:
                # Every required member is nested under web/, so index.html is not at root.
                for member in build_release.WEB_REQUIRED_MEMBERS:
                    archive.writestr('web/' + member, b'x' * 8)
                archive.writestr('README.md', b'readme')
                archive.writestr('THIRD_PARTY_NOTICES.md', b'notices')
                archive.writestr('licenses/NotoSansSC-OFL.txt', b'ofl')
                for item in (ROOT / 'assets/licenses').glob('*.txt'):
                    archive.writestr('licenses/' + item.name, item.read_bytes())
            manifest = {
                'version': '1.2.0', 'commit': COMMIT, 'dirty': False, 'target': 'web',
                'filename': name, 'sha256': build_release.sha256(package),
                'bytes': package.stat().st_size,
            }
            write_manifest(packages, 'web', manifest)
            with self.assertRaises(upload_itch.PreflightError) as caught:
                upload_itch.preflight_target('web', packages)
            self.assertIn('index.html', str(caught.exception))


class UploadRunTests(unittest.TestCase):
    def test_missing_butler_stops_without_traceback(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_package(tmp, 'web')
            error = io.StringIO()
            with mock.patch.object(upload_itch.subprocess, 'run', side_effect=FileNotFoundError) as run, \
                    contextlib.redirect_stderr(error), contextlib.redirect_stdout(io.StringIO()):
                code = run_main(tmp, '--target', 'web')
            self.assertEqual(code, 2)
            run.assert_called_once()
            self.assertIn('cannot run Butler', error.getvalue())

    def test_actual_mode_invokes_list_argv(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_package(tmp, 'web')
            with mock.patch.object(upload_itch.subprocess, 'run') as run:
                run.return_value = mock.Mock(returncode=0)
                code = quiet_run_main(tmp, '--target', 'web')
            self.assertEqual(code, 0)
            run.assert_called_once()
            called = run.call_args.args[0]
            self.assertIsInstance(called, list)
            self.assertEqual(called[0], 'butler')
            self.assertEqual(called[1], 'push')
            self.assertEqual(called[3], 'jerryszz02/poker-game:web')
            self.assertNotIn('shell', run.call_args.kwargs)

    def test_failure_propagation_and_stop(self):
        with tempfile.TemporaryDirectory() as tmp:
            for target in ('web', 'windows', 'macos'):
                make_package(tmp, target)
            with mock.patch.object(upload_itch.subprocess, 'run') as run:
                run.side_effect = [mock.Mock(returncode=0), mock.Mock(returncode=5),
                                   mock.Mock(returncode=0)]
                code = quiet_run_main(tmp, '--target', 'all')
            self.assertEqual(code, 5)
            self.assertEqual(run.call_count, 2)

    def test_bad_project_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_package(tmp, 'web')
            with mock.patch.object(upload_itch.subprocess, 'run') as run:
                code = quiet_run_main(tmp, '--target', 'web', '--project', 'not-a-project')
            self.assertEqual(code, 2)
            run.assert_not_called()


if __name__ == '__main__':
    unittest.main()
