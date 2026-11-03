"""Exercise the HTTP server with a temporary stand-in for the CSI mount."""
import http.client
import json
import tempfile
import threading
import unittest
from pathlib import Path
from unittest.mock import patch

from app import server


class ServerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.httpd = server.ThreadingHTTPServer(('127.0.0.1', 0), server.Handler)
        cls.thread = threading.Thread(target=cls.httpd.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.httpd.shutdown()
        cls.httpd.server_close()
        cls.thread.join()

    def request(self, path):
        conn = http.client.HTTPConnection(*self.httpd.server_address, timeout=3)
        try:
            conn.request('GET', path)
            response = conn.getresponse()
            return response.status, response.read()
        finally:
            conn.close()

    def test_probe_lifecycle_and_secret_non_disclosure(self):
        with tempfile.TemporaryDirectory() as directory:
            secret = Path(directory) / 'example-message'
            with patch.object(server, 'SECRET', secret):
                for path in ('/', '/healthz'):
                    status, body = self.request(path)
                    self.assertEqual(status, 200)
                    self.assertFalse(json.loads(body)['key_vault_secret_mounted'])
                self.assertEqual(self.request('/readyz')[0], 503)
                secret.touch()
                self.assertEqual(self.request('/readyz')[0], 503)
                secret.write_text('private-test-value')
                status, body = self.request('/readyz')
                self.assertEqual(status, 200)
                self.assertTrue(json.loads(body)['key_vault_secret_mounted'])
                self.assertNotIn(b'private-test-value', body)
                secret.unlink()
                self.assertEqual(self.request('/readyz')[0], 503)
                self.assertEqual(self.request('/missing')[0], 404)
