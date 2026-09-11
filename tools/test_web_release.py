#!/usr/bin/env python3
"""Focused packaging and local-server checks for the Godot Web export.

These tests never launch a browser or run a Godot export. They catch the failures
that matter for broken web packaging: a drifted preset, missing template selection,
wrong target metadata, an incomplete export directory, a malformed ZIP, or a local
server that cannot make the page cross-origin isolated.
"""
import http.client
from pathlib import Path
import re
import sys
import tempfile
import threading
import unittest
import zipfile

TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import bootstrap_godot  # noqa: E402
import build_release  # noqa: E402
import serve_web  # noqa: E402

ROOT = TOOLS.parent


def read_sections(text):
    sections = {}
    name = None
    for line in text.splitlines():
        match = re.match(r'\[(.+)\]', line)
        if match:
            name = match.group(1)
            sections[name] = {}
        elif name is not None and '=' in line:
            key, value = line.split('=', 1)
            sections[name][key.strip()] = value.strip()
    return sections


def make_web_export(directory):
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    payloads = {
        'index.html': b'<!doctype html><html></html>',
        'index.js': b'console.log("godot");',
        'index.wasm': b'\0asm' + b'x' * (1024 * 1024),
        'index.pck': b'pck-data',
        'index.audio.worklet.js': b'console.log("worklet");',
        'index.audio.position.worklet.js': b'console.log("position");',
        'index.icon.png': b'\x89PNG\r\n\x1a\n',
    }
    for name, data in payloads.items():
        (directory / name).write_bytes(data)
    return directory


class ExportPresetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sections = read_sections((ROOT / 'export_presets.cfg').read_text())

    def test_web_preset_declared(self):
        web = self.sections['preset.2']
        self.assertEqual(web['name'], '"Web"')
        self.assertEqual(web['platform'], '"Web"')
        self.assertEqual(web['export_filter'], '"resources"')
        self.assertEqual(web['export_path'], '"export/web/index.html"')

    def test_resources_and_filters_match_desktop(self):
        desktop = self.sections['preset.0']
        macos = self.sections['preset.1']
        web = self.sections['preset.2']
        for key in ('export_files', 'include_filter', 'exclude_filter'):
            self.assertEqual(web[key], desktop[key], key)
            self.assertEqual(web[key], macos[key], key)

    def test_threads_extensions_and_pwa(self):
        options = self.sections['preset.2.options']
        self.assertEqual(options['variant/thread_support'], 'true')
        self.assertEqual(options['variant/extensions_support'], 'false')
        self.assertEqual(options['progressive_web_app/enabled'], 'false')
        self.assertEqual(options['progressive_web_app/ensure_cross_origin_isolation_headers'], 'false')


class ProjectSettingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = (ROOT / 'project.godot').read_text()

    def test_web_renderer_override(self):
        self.assertIn('renderer/rendering_method.web="gl_compatibility"', self.text)

    def test_desktop_renderer_unchanged(self):
        self.assertIn('renderer/rendering_method="mobile"', self.text)
        self.assertNotIn('renderer/rendering_method="gl_compatibility"', self.text)


class BootstrapTemplateTests(unittest.TestCase):
    def test_threaded_web_templates_selected(self):
        for name in ('web_debug.zip', 'web_release.zip'):
            self.assertTrue(bootstrap_godot.is_template_file(name), name)

    def test_non_matching_web_templates_excluded(self):
        for name in (
            'web_nothreads_debug.zip',
            'web_nothreads_release.zip',
            'web_dlink_debug.zip',
            'web_dlink_release.zip',
            'web_dlink_nothreads_debug.zip',
            'web_dlink_nothreads_release.zip',
        ):
            self.assertFalse(bootstrap_godot.is_template_file(name), name)

    def test_desktop_templates_preserved(self):
        for name in ('macos.zip', 'version.txt', 'windows_release_x86_64.exe',
                     'windows_debug_x86_64_console.exe'):
            self.assertTrue(bootstrap_godot.is_template_file(name), name)


class TargetMetadataTests(unittest.TestCase):
    def test_target_presets_and_labels(self):
        self.assertEqual(build_release.export_preset('web'), 'Web')
        self.assertEqual(build_release.target_label('web'), 'web')
        self.assertEqual(build_release.output_name('web'), 'index.html')
        self.assertEqual(build_release.export_preset('windows'), 'Windows Desktop')
        self.assertEqual(build_release.export_preset('macos'), 'macOS')

    def test_web_manifest_does_not_overclaim(self):
        fields = build_release.manifest_platform_fields('web')
        self.assertEqual(fields['target'], 'web')
        self.assertFalse(fields['package_self_test_passed'])
        self.assertIsNone(fields['macos_signing'])
        self.assertIn('not established', fields['browser_validation'])
        self.assertIn('not established', fields['web_native_self_test'])

    def test_desktop_manifest_fields_unchanged(self):
        self.assertIsNone(build_release.manifest_platform_fields('windows')['macos_signing'])
        self.assertEqual(
            build_release.manifest_platform_fields('macos')['macos_signing'],
            'ad-hoc; not notarized',
        )


class WebExportValidationTests(unittest.TestCase):
    def test_required_members_accepted(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_web_export(tmp)
            members = build_release.validate_web_export(tmp)
            for name in build_release.WEB_REQUIRED_MEMBERS:
                self.assertIn(name, members)

    def test_missing_member_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_web_export(tmp)
            (Path(tmp) / 'index.pck').unlink()
            with self.assertRaises(RuntimeError):
                build_release.validate_web_export(tmp)

    def test_small_wasm_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_web_export(tmp)
            (Path(tmp) / 'index.wasm').write_bytes(b'small')
            with self.assertRaises(RuntimeError):
                build_release.validate_web_export(tmp)

    def test_tiny_html_is_not_size_gated(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_web_export(tmp)
            (Path(tmp) / 'index.html').write_bytes(b'<html></html>')
            build_release.validate_web_export(tmp)

    def test_archive_without_licenses_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            package = Path(tmp) / 'web.zip'
            with zipfile.ZipFile(package, 'w') as archive:
                for name in build_release.WEB_REQUIRED_MEMBERS:
                    archive.writestr(name, b'x')
                archive.writestr('README.md', b'readme')
                archive.writestr('THIRD_PARTY_NOTICES.md', b'notices')
            with self.assertRaises(RuntimeError):
                build_release.validate_web_archive(package)

    def test_complete_archive_accepted(self):
        with tempfile.TemporaryDirectory() as tmp:
            package = Path(tmp) / 'web.zip'
            with zipfile.ZipFile(package, 'w') as archive:
                for name in build_release.WEB_REQUIRED_MEMBERS:
                    archive.writestr(name, b'x')
                # Splash and icons observed in the actual Godot 4.7.2 export.
                for name in ('index.png', 'index.icon.png', 'index.apple-touch-icon.png'):
                    archive.writestr(name, b'png')
                archive.writestr('README.md', b'readme')
                archive.writestr('THIRD_PARTY_NOTICES.md', b'notices')
                archive.writestr('licenses/NotoSansSC-OFL.txt', b'ofl')
                for item in (ROOT / 'assets/licenses').glob('*.txt'):
                    archive.writestr('licenses/' + item.name, item.read_bytes())
            names = build_release.validate_web_archive(package)
            self.assertIn('index.html', names)

    def test_add_release_docs_then_validate(self):
        with tempfile.TemporaryDirectory() as tmp:
            package = Path(tmp) / 'web.zip'
            with zipfile.ZipFile(package, 'w') as archive:
                for name in build_release.WEB_REQUIRED_MEMBERS:
                    archive.writestr(name, b'x')
                build_release.add_release_docs(archive)
            names = build_release.validate_web_archive(package)
            self.assertIn('licenses/NotoSansSC-OFL.txt', names)
            self.assertIn('THIRD_PARTY_NOTICES.md', names)

    def test_archive_with_unexpected_nested_member_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            package = Path(tmp) / 'web.zip'
            with zipfile.ZipFile(package, 'w') as archive:
                for name in build_release.WEB_REQUIRED_MEMBERS:
                    archive.writestr(name, b'x')
                archive.writestr('README.md', b'readme')
                archive.writestr('THIRD_PARTY_NOTICES.md', b'notices')
                archive.writestr('licenses/NotoSansSC-OFL.txt', b'ofl')
                for item in (ROOT / 'assets/licenses').glob('*.txt'):
                    archive.writestr('licenses/' + item.name, item.read_bytes())
                archive.writestr('extra/nested.txt', b'x')
            with self.assertRaises(RuntimeError):
                build_release.validate_web_archive(package)


class ServeWebHeaderTests(unittest.TestCase):
    def test_isolation_header_contract(self):
        headers = dict(serve_web.ISOLATION_HEADERS)
        self.assertEqual(headers['Cross-Origin-Opener-Policy'], 'same-origin')
        self.assertEqual(headers['Cross-Origin-Embedder-Policy'], 'require-corp')
        self.assertEqual(headers['Cross-Origin-Resource-Policy'], 'cross-origin')

    def test_wasm_content_type(self):
        self.assertEqual(serve_web.WebReleaseHandler.extensions_map['.wasm'], 'application/wasm')

    def test_live_server_is_loopback_and_isolated(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'index.html').write_text('<!doctype html>', encoding='utf-8')
            (root / 'index.wasm').write_bytes(b'\0asm')
            server = serve_web.create_server(root, 0)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                self.assertEqual(server.server_address[0], '127.0.0.1')
                host, port = server.server_address[:2]
                connection = http.client.HTTPConnection(host, port, timeout=5)
                connection.request('GET', '/index.html')
                response = connection.getresponse()
                body = response.read()
                self.assertEqual(response.status, 200)
                self.assertEqual(response.getheader('Cross-Origin-Opener-Policy'), 'same-origin')
                self.assertEqual(response.getheader('Cross-Origin-Embedder-Policy'), 'require-corp')
                self.assertEqual(response.getheader('Cross-Origin-Resource-Policy'), 'cross-origin')
                self.assertIn(b'doctype', body)
                connection.request('GET', '/index.wasm')
                wasm = connection.getresponse()
                wasm.read()
                self.assertEqual(wasm.getheader('Content-Type'), 'application/wasm')
                connection.close()
            finally:
                server.shutdown()
                server.server_close()
                thread.join(timeout=5)


if __name__ == '__main__':
    unittest.main()
