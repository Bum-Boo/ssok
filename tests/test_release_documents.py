"""Check offline navigation through the actual release documentation payload."""

from pathlib import Path
import re
import tempfile
import unittest
from urllib.parse import unquote, urlsplit
import zipfile

from tools.ci.build import copy_notices


class ReleaseDocumentsTest(unittest.TestCase):
    def test_documentation_links_survive_packaging_and_extraction(self):
        with tempfile.TemporaryDirectory(prefix="ssok-release-docs-") as temporary:
            root = Path(temporary)
            payload = root / "payload"
            payload.mkdir()
            copy_notices(payload)
            archive_path = root / "release.zip"
            with zipfile.ZipFile(archive_path, "w", zipfile.ZIP_DEFLATED) as archive:
                for source in payload.rglob("*"):
                    if source.is_file():
                        archive.write(source, source.relative_to(payload))
            extracted = root / "extracted"
            with zipfile.ZipFile(archive_path) as archive:
                archive.extractall(extracted)
            missing = []
            links_checked = 0
            for document in extracted.rglob("*.md"):
                for match in re.finditer(r"\]\((<[^>]+>|[^\s)]+)(?:\s+[^)]*)?\)", document.read_text()):
                    destination = urlsplit(match.group(1).strip("<>"))
                    if destination.scheme or destination.netloc or not destination.path:
                        continue
                    target = (document.parent / unquote(destination.path)).resolve()
                    links_checked += 1
                    if not target.is_relative_to(extracted) or not target.exists():
                        missing.append(f"{document.relative_to(extracted)} -> {destination.path}")
            self.assertGreater(links_checked, 100, "check the complete bundled documentation")
            self.assertEqual([], missing, "archive contains broken documentation links")
            for notice in ["LICENSE", "THIRD_PARTY_NOTICES.md", "licenses/Godot-LICENSE.txt",
                           "licenses/Godot-COPYRIGHT.txt", "licenses/Lucide-LICENSE.txt", "licenses/Noto-OFL.txt"]:
                self.assertTrue((extracted / notice).is_file(), notice)


if __name__ == "__main__":
    unittest.main()
