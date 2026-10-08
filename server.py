#!/usr/bin/env python3
"""Soundboard server: static files + local monitor outside Chrome.

The monitor MUST play OUTSIDE Chrome: Chrome's echo cancellation uses the
audio played by the browser as a reference signal and would cancel the very
same sounds arriving in Meet through BlackHole.

Voice FX endpoints (/voice*) proxy to the native VoiceFX helper, see voice.py.
"""
import glob
import json
import os
import subprocess
import tempfile
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

import voice

DIR = os.path.dirname(os.path.abspath(__file__))
PORT = 8765
MONITOR_PREFIX = "sb_monitor_"


def cleanup_temp() -> None:
    for path in glob.glob(os.path.join(tempfile.gettempdir(), f"{MONITOR_PREFIX}*")):
        try:
            os.remove(path)
        except OSError:
            pass


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIR, **kwargs)

    def log_message(self, *args):
        pass

    def _respond(self, code: int) -> None:
        self.send_response(code)
        self.end_headers()

    def _respond_json(self, payload: dict) -> None:
        body = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if urlparse(self.path).path == "/voice":
            self._respond_json(voice.status().to_dict())
        else:
            super().do_GET()

    def do_POST(self):
        url = urlparse(self.path)
        if url.path == "/voice/start":
            self._respond_json(voice.start().to_dict())
        elif url.path == "/voice/stop":
            self._respond_json(voice.stop().to_dict())
        elif url.path == "/voice/preset":
            name = parse_qs(url.query).get("name", [""])[0]
            self._respond_json(voice.select(name).to_dict())
        elif url.path == "/monitor":
            try:
                vol = min(max(float(parse_qs(url.query).get("vol", ["0.5"])[0]), 0.0), 1.0)
            except ValueError:
                vol = 0.5
            length = int(self.headers.get("Content-Length", 0))
            data = self.rfile.read(length)
            f = tempfile.NamedTemporaryFile(
                prefix=MONITOR_PREFIX, suffix=".audio", delete=False
            )
            f.write(data)
            f.close()
            subprocess.Popen(["afplay", "-v", str(vol), f.name])
            self._respond(204)
        elif url.path == "/stop":
            subprocess.run(["pkill", "-f", MONITOR_PREFIX], check=False)
            self._respond(204)
        else:
            self._respond(404)


if __name__ == "__main__":
    cleanup_temp()
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
