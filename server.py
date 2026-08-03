#!/usr/bin/env python3
"""Server della soundboard: file statici + monitor locale fuori da Chrome.

Il monitor deve suonare FUORI da Chrome: l'echo cancellation di Chrome usa
l'audio riprodotto dal browser come riferimento e cancellerebbe in Meet
gli stessi suoni in arrivo da BlackHole.
"""
import glob
import os
import subprocess
import tempfile
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

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

    def do_POST(self):
        url = urlparse(self.path)
        if url.path == "/monitor":
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
