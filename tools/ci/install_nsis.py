"""Fetch verified Debian NSIS 3.08 build tools without root or global installation."""

from __future__ import annotations

import hashlib
import io
from pathlib import Path
import platform
import tarfile
import urllib.request

BASE = 'https://deb.debian.org/debian/pool/main/n/nsis/'
ASSETS = {
    'nsis_3.08-3+deb12u1_amd64.deb': 'b9ca8de84341753dd1c071a3f65453dc06bd7b6f2230140a36755d7e402827c2',
    'nsis-common_3.08-3+deb12u1_all.deb': 'f1c9e63389c947442fddd5ca446e22966e8f03fc10663f998cf7df58642f9b52',
}


def install(directory: Path) -> Path:
    if platform.system() != 'Linux' or platform.machine() not in {'x86_64', 'AMD64'}:
        raise RuntimeError('Provide makensis explicitly on this build host')
    directory.mkdir(parents=True, exist_ok=True)
    (directory / '.gdignore').touch()
    for name, expected in ASSETS.items():
        package = directory / name
        if not package.is_file() or hashlib.sha256(package.read_bytes()).hexdigest() != expected:
            with urllib.request.urlopen(BASE + name, timeout=60) as response:
                content = response.read()
            if hashlib.sha256(content).hexdigest() != expected:
                raise RuntimeError(f'NSIS package checksum mismatch: {name}')
            package.write_bytes(content)
        content = package.read_bytes()
        if content[:8] != b'!<arch>\n':
            raise ValueError('Invalid Debian build-tool archive')
        position = 8
        found = False
        while position + 60 <= len(content):
            header = content[position:position+60]
            size = int(header[48:58])
            member = header[:16].decode().strip().rstrip('/')
            position += 60
            if member.startswith('data.tar.'):
                with tarfile.open(fileobj=io.BytesIO(content[position:position+size])) as archive:
                    archive.extractall(directory, filter='data')
                found = True
                break
            position += size + size % 2
        if not found:
            raise ValueError('Debian package has no data archive')
    return directory / 'usr/bin/makensis'
