"""Explicit developer-only image ablations; preserve real/delivered evidence separately."""
import hashlib
from pathlib import Path
import struct
import zlib

from .desktop_client import DesktopError, Observation, write_observation
from .desktop_session import DesktopGoalSession


def blank_png(width: int = 640, height: int = 480) -> bytes:
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    rows = (b'\0' + bytes([127, 127, 127]) * width) * height
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b''))


class ExperimentSession:
    """The base session binds physics frames; the actor binds only delivered PNG hashes.

    A control receipt in the app describes a REAL frame and is explicitly labeled as
    an experiment. It does not claim that the actor received that real camera frame.
    """
    def __init__(self, session: DesktopGoalSession, mode: str):
        if mode not in ('blank', 'frozen'):
            raise DesktopError('Unsupported image control.')
        self.session, self.mode = session, mode
        self.closed = session.closed
        self.fixed = None
        self.pending = None
        session.provider = 'Experiment control / ' + mode + ' / Astra'
        session.record('image_control', {'mode': mode, 'real_camera_sent': False})

    def observe(self) -> Observation:
        real = self.session.observe()
        if self.fixed is None:
            self.fixed = blank_png(real.metadata['width'], real.metadata['height']) if self.mode == 'blank' else real.png
        delivered = Observation(real.metadata | {'sha256': hashlib.sha256(self.fixed).hexdigest()}, self.fixed)
        delivered.verify()
        write_observation(delivered, self.session.output / f'delivered-{self.session.observations}.png')
        self.pending = (delivered.metadata['sha256'], real.metadata['sha256'])
        self.session.record('delivery', {'observation': self.session.observations, 'mode': self.mode,
                                         'delivered_sha256': self.pending[0], 'real_sha256': self.pending[1]})
        return delivered

    def decide(self, frame_sha256: str, summary: str, action: str, ticks: int) -> dict:
        if self.pending is None or frame_sha256 != self.pending[0]:
            self.session.stop('control_hash_mismatch')
            raise DesktopError('Decision hash does not match the delivered image.')
        real_sha = self.pending[1]
        self.pending = None
        return self.session.decide(real_sha, summary, action, ticks)

    def stop(self, reason='actor_stop') -> dict:
        return self.session.stop(reason)

    def record(self, kind, data):
        return self.session.record(kind, data)
