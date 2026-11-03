"""Dependency-free probe server; proves Key Vault CSI mounting, never returns secrets."""
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

SECRET = Path('/mnt/secrets-store/example-message')

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path not in ('/', '/healthz', '/readyz'):
            self.send_error(404)
            return
        mounted = SECRET.is_file() and SECRET.stat().st_size > 0
        status = 503 if self.path == '/readyz' and not mounted else 200
        data = json.dumps({'app': 'hybrid-demo', 'environment': os.getenv('APP_ENV', 'prod'),
                           'key_vault_secret_mounted': mounted}).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

if __name__ == '__main__':
    ThreadingHTTPServer(('0.0.0.0', 8080), Handler).serve_forever()
