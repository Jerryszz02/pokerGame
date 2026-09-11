#!/usr/bin/env python3
"""Serve an exported web build from disk for local browser testing.

The server is loopback-only and adds the cross-origin isolation headers a threaded
Godot Web export needs (SharedArrayBuffer). It uses only the Python standard library:
no telemetry, no plugins, and no runtime requests to external services.
"""
import argparse
from functools import partial
import http.server
from pathlib import Path

LOOPBACK = '127.0.0.1'
# Required for crossOriginIsolated / SharedArrayBuffer in threaded builds.
ISOLATION_HEADERS = (
    ('Cross-Origin-Opener-Policy', 'same-origin'),
    ('Cross-Origin-Embedder-Policy', 'require-corp'),
    ('Cross-Origin-Resource-Policy', 'cross-origin'),
    ('Cache-Control', 'no-store'),
)
EXTRA_CONTENT_TYPES = {
    '.wasm': 'application/wasm',
    '.js': 'text/javascript',
    '.mjs': 'text/javascript',
    '.pck': 'application/octet-stream',
}


class WebReleaseHandler(http.server.SimpleHTTPRequestHandler):
    """Static handler that adds isolation headers and a correct wasm content type."""

    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        **EXTRA_CONTENT_TYPES,
    }

    def end_headers(self):
        for header, value in ISOLATION_HEADERS:
            self.send_header(header, value)
        super().end_headers()


def create_server(directory, port=8060):
    directory = Path(directory).resolve()
    if not directory.is_dir():
        raise NotADirectoryError(f'Web build directory not found: {directory}')
    handler = partial(WebReleaseHandler, directory=str(directory))
    return http.server.ThreadingHTTPServer((LOOPBACK, port), handler)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', required=True, type=Path,
                        help='Directory containing an exported web build (with index.html at its root).')
    parser.add_argument('--port', type=int, default=8060, help='Loopback port to listen on (default: 8060).')
    args = parser.parse_args()
    server = create_server(args.directory, args.port)
    host, port = server.server_address[:2]
    print(f'Serving {Path(args.directory).resolve()} at http://{host}:{port}/ (Ctrl+C to stop)')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
