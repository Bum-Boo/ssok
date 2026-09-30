"""Distribution checks for portable app permissions and uninstaller boundaries."""

from pathlib import Path
import tempfile
import unittest
import zipfile
from unittest.mock import patch

from tools.ci.desktop_package import build_installer, extract_macos, package_zip


class DesktopPackageTest(unittest.TestCase):
    def test_macos_executable_permission_survives_zip_roundtrip(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            payload = root / 'payload'
            executable = payload / 'ssok.app/Contents/MacOS/ssok'
            executable.parent.mkdir(parents=True)
            executable.write_bytes(b'example')
            executable.chmod(0o755)
            package_zip(payload, root / 'app.zip')
            extract_macos(root / 'app.zip', root / 'unpacked')
            self.assertTrue((root / 'unpacked/ssok.app/Contents/MacOS/ssok').stat().st_mode & 0o111)

    def test_macos_extraction_cannot_escape_destination(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with zipfile.ZipFile(root / 'bad.zip', 'w') as archive:
                archive.writestr('../outside', 'unexpected')
            with self.assertRaises(ValueError):
                extract_macos(root / 'bad.zip', root / 'unpacked')
            self.assertFalse((root / 'outside').exists())

    def test_uninstaller_only_removes_packaged_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            payload = root / 'payload'
            (payload / 'docs').mkdir(parents=True)
            (payload / 'ssok.exe').write_bytes(b'example')
            (payload / 'docs/readme.md').write_text('example')
            target = root / 'setup.exe'
            target.touch()
            with patch('tools.ci.desktop_package.subprocess.run') as run:
                run.return_value.returncode = 0
                run.return_value.stdout = 'compiled'
                build_installer(payload, target, 'development', 'makensis', root / 'installer.log')
            manifest = (root / 'windows-uninstall.nsh').read_text()
            self.assertIn('Delete "$INSTDIR\\ssok.exe"', manifest)
            self.assertIn('Delete "$INSTDIR\\docs\\readme.md"', manifest)
            self.assertNotIn('/r', manifest.lower())
            self.assertNotIn('user://', manifest)


if __name__ == '__main__':
    unittest.main()
