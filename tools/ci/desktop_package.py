"""Package desktop exports without changing their signed application payload."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import plistlib
import stat
import struct
import subprocess
import zipfile

PROJECT = Path(__file__).resolve().parents[2]


def package_zip(source: Path, target: Path) -> None:
    with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in sorted(source.rglob('*')):
            if path.is_file():
                archive.write(path, path.relative_to(source))


def extract_macos(archive: Path, target: Path) -> None:
    with zipfile.ZipFile(archive) as package:
        for entry in package.infolist():
            destination = target / entry.filename
            if not destination.resolve().is_relative_to(target.resolve()):
                raise ValueError('macOS archive contains an escaping path')
            if stat.S_ISLNK(entry.external_attr >> 16):
                raise ValueError('Unexpected symbolic link in Godot application bundle')
            package.extract(entry, target)
            if destination.is_file():
                destination.chmod((entry.external_attr >> 16) & 0o777 or 0o644)


def audit_windows(binary: Path, report: Path) -> dict:
    with binary.open('rb') as source:
        header = source.read(64)
        if header[:2] != b'MZ':
            raise ValueError('Windows export is not an executable')
        source.seek(struct.unpack_from('<I', header, 0x3c)[0])
        pe = source.read(96)
    if pe[:4] != b'PE\0\0' or struct.unpack_from('<H', pe, 4)[0] != 0x8664:
        raise ValueError('Expected an x86_64 Windows executable')
    if struct.unpack_from('<H', pe, 24)[0] != 0x20b:
        raise ValueError('Expected a PE32+ application')
    result = {'architecture': 'x86_64', 'format': 'PE32+', 'publisher_signed': False,
              'native_runtime_verified': False}
    report.write_text(json.dumps(result, indent=2) + '\n')
    return result


def audit_macos(bundle: Path, report: Path) -> dict:
    info = plistlib.loads((bundle / 'Contents/Info.plist').read_bytes())
    if info['CFBundleIdentifier'] != 'io.github.bum-boo.ssok':
        raise ValueError('Unexpected macOS application identity')
    executable = bundle / 'Contents/MacOS' / info['CFBundleExecutable']
    if not executable.stat().st_mode & 0o111:
        raise ValueError('macOS executable lost its executable permission')
    with executable.open('rb') as source:
        magic, count = struct.unpack('>II', source.read(8))
        if magic != 0xcafebabe or count != 2:
            raise ValueError('Expected a Universal 2 Mach-O executable')
        slices = [struct.unpack('>IIIII', source.read(20)) for _ in range(count)]
        if {part[0] for part in slices} != {0x1000007, 0x100000c}:
            raise ValueError('Missing Intel or Apple Silicon architecture')
        for _, _, offset, _, _ in slices:
            source.seek(offset)
            header = source.read(32)
            if struct.unpack_from('<I', header)[0] != 0xfeedfacf:
                raise ValueError('Invalid Mach-O slice')
            commands = struct.unpack_from('<I', header, 16)[0]
            signed = False
            for _ in range(commands):
                position = source.tell()
                command, size = struct.unpack('<II', source.read(8))
                signed |= command == 0x1d  # LC_CODE_SIGNATURE
                source.seek(position + size)
            if not signed:
                raise ValueError('Missing built-in ad-hoc code signature')
    seal = plistlib.loads((bundle / 'Contents/_CodeSignature/CodeResources').read_bytes())
    resources = seal.get('files2', {})
    verified = 0
    for relative, entry in resources.items():
        path = bundle / 'Contents' / relative
        expected = entry.get('hash2') if isinstance(entry, dict) else None
        if expected is not None:
            if hashlib.sha256(path.read_bytes()).digest() != expected:
                raise ValueError(f'Signed resource changed after export: {relative}')
            verified += 1
    if not verified:
        raise ValueError('No signed resource hashes found')
    result = {'architectures': ['x86_64', 'arm64'], 'bundle_identifier': info['CFBundleIdentifier'],
              'executable_permission': True, 'ad_hoc_signature_present': True,
              'sealed_resources_verified': verified, 'notarized': False,
              'native_runtime_verified': False}
    report.write_text(json.dumps(result, indent=2) + '\n')
    return result


def nsis_quote(value: str) -> str:
    if '\n' in value or '\r' in value:
        raise ValueError('Newlines are not valid installer paths')
    return value.replace('$', '$$').replace('"', '$\\"')


def build_installer(payload: Path, target: Path, version: str, makensis: str, log: Path) -> None:
    manifest = log.parent / 'windows-uninstall.nsh'
    files = [path.relative_to(payload) for path in payload.rglob('*') if path.is_file()]
    directories = [path.relative_to(payload) for path in payload.rglob('*') if path.is_dir()]
    lines = [f'  Delete "$INSTDIR\\{nsis_quote(str(path).replace(os.sep, chr(92)))}"' for path in sorted(files)]
    lines += [f'  RMDir "$INSTDIR\\{nsis_quote(str(path).replace(os.sep, chr(92)))}"'
              for path in sorted(directories, key=lambda p: (-len(p.parts), str(p)))]
    manifest.write_text('\n'.join(lines) + '\n')
    command = [makensis, '-V3', f'-DPAYLOAD={payload}', f'-DOUTPUT={target}',
               f'-DAPP_VERSION={version}', f'-DUNINSTALL_FILES={manifest}',
               str(PROJECT / 'tools/release/windows/installer.nsi')]
    result = subprocess.run(command, cwd=PROJECT, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=300)
    log.write_text(result.stdout)
    if result.returncode or not target.is_file():
        raise RuntimeError(f'Windows installer failed; see {log}')
