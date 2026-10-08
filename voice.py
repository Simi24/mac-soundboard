"""Voice FX control: starts/stops VoiceFX.app and talks to it over UDP.

VoiceFX is a native helper (voicefx/): mic -> effects -> BlackHole. While it
runs, the call app must use "BlackHole 2ch" as microphone, NOT "Mic + Soundboard",
or the raw mic and the processed voice would both reach the call.
"""
from __future__ import annotations

import os
import socket
import subprocess
import tempfile
import time
from dataclasses import asdict, dataclass, field

DIR = os.path.dirname(os.path.abspath(__file__))
APP = os.path.join(DIR, "voicefx", "build", "VoiceFX.app")
BINARY = "VoiceFX.app/Contents/MacOS/voicefx"
LOG = os.path.join(tempfile.gettempdir(), "voicefx.log")
CONTROL = ("127.0.0.1", 8766)
TIMEOUT_S = 0.3


@dataclass
class VoiceStatus:
    running: bool
    built: bool
    preset: str | None = None
    presets: list[str] = field(default_factory=list)
    error: str | None = None

    def to_dict(self) -> dict:
        return asdict(self)


def _send(command: str) -> str | None:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.settimeout(TIMEOUT_S)
        try:
            sock.sendto(command.encode(), CONTROL)
            return sock.recv(256).decode()
        except OSError:
            return None


def _parse(reply: str | None) -> VoiceStatus:
    built = os.path.isdir(APP)
    if reply is None:
        return VoiceStatus(running=False, built=built)
    if not reply.startswith("ok "):
        return VoiceStatus(running=True, built=built, error=reply)
    _, preset, presets = reply.split(" ", 2)
    return VoiceStatus(running=True, built=built, preset=preset, presets=presets.split(","))


def status() -> VoiceStatus:
    return _parse(_send("status"))


def select(preset: str) -> VoiceStatus:
    return _parse(_send(preset))


def start() -> VoiceStatus:
    current = status()
    if current.running:
        return current
    if not current.built:
        return VoiceStatus(running=False, built=False, error="VoiceFX not built: run voicefx/build.sh")
    # Launched through LaunchServices so the app is its own TCC subject and
    # macOS can show the microphone prompt on first run.
    subprocess.run(
        ["open", "-n", "-g", APP, "--stdout", LOG, "--stderr", LOG, "--args", "run"],
        check=False,
    )
    deadline = time.monotonic() + 3
    while time.monotonic() < deadline:
        current = status()
        if current.running:
            return current
        time.sleep(0.2)
    return VoiceStatus(
        running=False,
        built=True,
        error=f"VoiceFX did not answer yet (microphone permission prompt?). Log: {LOG}",
    )


def stop() -> VoiceStatus:
    subprocess.run(["pkill", "-TERM", "-f", BINARY], check=False)
    return VoiceStatus(running=False, built=os.path.isdir(APP))
