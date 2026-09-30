"""Regressions for drift detection and explicit review, using synthetic repositories."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import maintain


class DocumentationCheckTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        for name in ("scenes", "src/core", "presets", "docs/adr", "docs/generated"):
            (self.root / name).mkdir(parents=True)
        for name in ("AGENTS.md", "docs/START_HERE.md", "docs/STATUS.md", "docs/DATA_MODEL.md"):
            (self.root / name).write_text("# Start\n", encoding="utf-8")
        self.source = self.root / "src/core/item.gd"
        self.source.write_text("class_name Item\nextends Resource\n\nfunc value() -> int:\n\treturn 1\n", encoding="utf-8")
        (self.root / "docs/contract.md").write_text("# Contract\n[Source](../src/core/item.gd)\n", encoding="utf-8")
        (self.root / "docs/adr/0000-policy.md").write_text(
            "# 0000 — Policy\n\n- Status: accepted; partially superseded\n- Date: 2026-09-30\n"
            "- Extends: prior context\n\n## Decision\nKeep boundaries.\n", encoding="utf-8")
        self.data = {
            "schema": 1,
            "managed": ["AGENTS.md", "docs/START_HERE.md", "docs/STATUS.md", "docs/contract.md"],
            "routes": {"storage": {"docs": ["docs/contract.md"], "sources": ["src/core/item.gd"],
                                    "adrs": ["0000"], "watch": ["src/core/*"]}},
            "symbols": {"src/core/item.gd": {"class": "Item", "methods": ["value"]}},
            "contracts": {"storage": {"document": "docs/contract.md", "sources": {
                "src/core/item.gd": hashlib.sha256(self.source.read_bytes()).hexdigest()}}},
        }
        self.registry = self.root / maintain.REGISTRY
        self.registry.write_text(json.dumps(self.data), encoding="utf-8")
        self.generate()

    def generate(self) -> None:
        (self.root / maintain.MAP).write_text(maintain.code_map(self.root), encoding="utf-8")
        (self.root / maintain.ADR_INDEX).write_text(maintain.adr_index(self.root), encoding="utf-8")

    def errors(self) -> list[str]:
        return maintain.validate(self.root, maintain.read_registry(self.root))

    def test_valid_registry_and_deterministic_maps(self) -> None:
        self.assertEqual([], self.errors())
        previous = (self.root / maintain.MAP).read_bytes()
        self.generate()
        self.assertEqual(previous, (self.root / maintain.MAP).read_bytes())

    def test_behavior_change_requires_explicit_review_even_after_generation(self) -> None:
        self.source.write_text(self.source.read_text().replace("return 1", "return 2"))
        self.generate()
        self.assertTrue(any("--review storage" in error for error in self.errors()))
        data = maintain.read_registry(self.root)
        maintain.review(self.root, data, ["storage"])
        self.assertEqual([], self.errors())

    def test_removed_source_reports_both_routes_and_links(self) -> None:
        self.source.unlink()
        errors = self.errors()
        self.assertTrue(any("Broken local link" in error for error in errors))
        self.assertTrue(any("Missing storage route file" in error for error in errors))

    def test_class_and_method_rename_are_not_hidden_by_review(self) -> None:
        self.source.write_text(self.source.read_text().replace("Item", "Renamed").replace("func value", "func renamed"))
        maintain.review(self.root, self.data, ["storage"])
        self.generate()
        errors = self.errors()
        self.assertTrue(any("Missing class Item" in error for error in errors))
        self.assertTrue(any("Missing method value" in error for error in errors))

    def test_generated_map_detects_new_source(self) -> None:
        (self.root / "src/core/new.gd").write_text("class_name NewItem\nextends Resource\n")
        self.assertTrue(any("Stale generated" in error for error in self.errors()))

    def test_local_links_checked_but_examples_and_urls_ignored(self) -> None:
        contract = self.root / "docs/contract.md"
        contract.write_text("[missing](missing.md)\n[external](https://example.invalid/no.md)\n"
                            "```md\n[example](not-a-file.md)\n```\n")
        errors = maintain.link_errors(self.root, ["docs/contract.md"])
        self.assertEqual(1, len(errors))
        self.assertIn("missing.md", errors[0])

    def test_outside_repository_links_and_registry_paths_rejected(self) -> None:
        (self.root / "docs/contract.md").write_text("[outside](../../outside.md)\n")
        self.assertTrue(maintain.link_errors(self.root, ["docs/contract.md"]))
        with self.assertRaises(ValueError):
            maintain.contained(self.root, "../outside.md")

    def test_entry_budget_and_adr_partial_status_preserved(self) -> None:
        index = maintain.adr_index(self.root)
        self.assertIn("accepted; partially superseded", index)
        self.assertIn("Extends: prior context", index)
        (self.root / "AGENTS.md").write_text("entry\n" * 251)
        self.assertTrue(any("Entry context" in error for error in self.errors()))

    def test_unknown_contract_does_not_partially_mutate_registry(self) -> None:
        before = self.registry.read_bytes()
        with self.assertRaises(ValueError):
            maintain.review(self.root, self.data, ["storage", "unknown"])
        self.assertEqual(before, self.registry.read_bytes())

    def test_route_is_compact_and_resolves_adr_file(self) -> None:
        lines = maintain.route_lines(self.root, self.data, "storage")
        self.assertIn("Source: src/core/item.gd", lines)
        self.assertIn("ADR: docs/adr/0000-policy.md", lines)
        with self.assertRaises(ValueError):
            maintain.route_lines(self.root, self.data, "unknown")


if __name__ == "__main__":
    unittest.main()
