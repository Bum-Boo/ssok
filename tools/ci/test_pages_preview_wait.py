"""The preview wait must accept an already-served site and fail only on errored or absent publication."""

from __future__ import annotations

import json
from pathlib import Path
import re
import tempfile
import unittest

from tools.ci import pages_preview_wait as wait

PROJECT = Path(__file__).resolve().parents[2]
COMMIT = "162cabf47e2637568b13f6fb9a428ed3c1480ed2"
SOURCE = "578ca797ffb458fef74d79963b4232a29d97910a"
URL = "https://example.invalid/ssok/preview/feat-own-build-r3-20261022-26b1d9214e02/"


class FakeClock:
    def __init__(self) -> None:
        self.now = 1000.0

    def __call__(self) -> float:
        return self.now

    def sleep(self, seconds: float) -> None:
        self.now += seconds


class Scenario:
    """Scripted API and HTTP answers, consumed one poll at a time."""

    def __init__(self, polls: list[dict]) -> None:
        self.polls = polls
        self.index = -1
        self.api_calls: list[tuple[str, str]] = []
        self.fetched: list[str] = []
        self.lines: list[str] = []
        self.clock = FakeClock()

    def api(self, method: str, path: str) -> tuple[int, object]:
        self.api_calls.append((method, path))
        if method == "POST":
            return self.polls[0].get("post", (201, {"status": "queued"}))
        poll = self.polls[min(self.index, len(self.polls) - 1)]
        if path.endswith("/pages"):
            return poll.get("site", (200, {"status": "built", "html_url": "https://example.invalid/ssok/"}))
        return poll.get("builds", (200, []))

    def fetch(self, url: str) -> tuple[int, bytes]:
        self.fetched.append(url)
        poll = self.polls[min(self.index, len(self.polls) - 1)]
        return poll.get("served", (404, b""))

    def waiter(self) -> wait.PreviewWaiter:
        scenario = self

        class CountingWaiter(wait.PreviewWaiter):
            def observe(self, started: float) -> wait.Observation:
                scenario.index += 1
                return super().observe(started)

        return CountingWaiter("Bum-Boo/ssok", COMMIT, SOURCE, URL, api=self.api, fetch=self.fetch,
                              clock=self.clock, sleep=self.clock.sleep, log=self.lines.append)


def marker(source: str) -> tuple[int, bytes]:
    return 200, json.dumps({"schema": 1, "source": source}).encode()


class PreviewWaitTest(unittest.TestCase):
    def test_served_marker_succeeds_even_when_latest_build_stays_queued(self) -> None:
        # Observed in run 39797157788: builds/latest answered {"status": "queued"} for ten minutes
        # although the pushed revision was already served with HTTP 200.
        scenario = Scenario([{"builds": (200, [{"status": "queued"}]), "served": marker(SOURCE)}])
        code = scenario.waiter().wait(timeout=600, interval=10)
        self.assertEqual(code, 0)
        self.assertEqual(scenario.index, 0)
        self.assertTrue(any("MATCH" in line for line in scenario.lines))
        self.assertTrue(any("served site is authoritative" in line for line in scenario.lines))
        self.assertEqual(scenario.fetched, [URL + "preview.json?source=" + SOURCE])

    def test_waits_through_older_marker_until_the_new_source_is_served(self) -> None:
        scenario = Scenario([
            {"builds": (200, [{"commit": COMMIT, "status": "building"}]), "served": marker("0" * 40)},
            {"builds": (200, [{"commit": COMMIT, "status": "building"}]), "served": marker("0" * 40)},
            {"builds": (200, [{"commit": COMMIT, "status": "built"}]), "served": marker(SOURCE)},
        ])
        code = scenario.waiter().wait(timeout=600, interval=10)
        self.assertEqual(code, 0)
        self.assertEqual(scenario.index, 2)
        self.assertRegex(scenario.lines[1], r"build\[162cabf\]=building .*served=200 source=0000000$")
        self.assertRegex(scenario.lines[3], r"build\[162cabf\]=built .*MATCH$")
        self.assertNotIn("authoritative", scenario.lines[-1])

    def test_errored_build_for_the_pushed_commit_fails_immediately(self) -> None:
        scenario = Scenario([{"builds": (200, [{"commit": COMMIT, "status": "errored",
                                                 "error": {"message": "Jekyll failed"}}]),
                             "served": (404, b"")}])
        code = scenario.waiter().wait(timeout=600, interval=10)
        self.assertEqual(code, 1)
        self.assertEqual(scenario.index, 0)
        self.assertTrue(any("errored: Jekyll failed" in line for line in scenario.lines))
        self.assertTrue(any("remain on gh-pages" in line for line in scenario.lines))

    def test_timeout_is_bounded_and_explains_the_last_observation(self) -> None:
        scenario = Scenario([{"builds": (200, [{"status": "queued"}]), "served": (404, b"")}])
        code = scenario.waiter().wait(timeout=60, interval=10)
        self.assertEqual(code, 1)
        # Polls at 0, 10, ..., 60 seconds; the loop never sleeps past the deadline.
        self.assertEqual(scenario.index, 6)
        self.assertLessEqual(scenario.clock.now - 1000.0, 60.0)
        self.assertTrue(any(line.startswith("Timed out after 60s") for line in scenario.lines))
        self.assertTrue(any("returned HTTP 404" in line for line in scenario.lines))
        self.assertTrue(any("Nothing was rolled back" in line for line in scenario.lines))

    def test_api_failures_are_logged_and_do_not_hide_a_served_preview(self) -> None:
        def broken_api(method: str, path: str) -> tuple[int, object]:
            raise OSError("gh unavailable")

        lines: list[str] = []
        waiter = wait.PreviewWaiter("Bum-Boo/ssok", COMMIT, SOURCE, URL, api=broken_api,
                                    fetch=lambda url: marker(SOURCE), clock=FakeClock(),
                                    sleep=lambda seconds: None, log=lines.append)
        waiter.request_build()
        self.assertEqual(waiter.wait(timeout=60, interval=10), 0)
        self.assertIn("HTTP 0", lines[0])
        self.assertTrue(any("api(pages: HTTP 0, builds: HTTP 0)" in line for line in lines))

    def test_unreadable_marker_counts_as_not_served(self) -> None:
        scenario = Scenario([{"served": (200, b"<html>soft 404</html>")}])
        code = scenario.waiter().wait(timeout=20, interval=10)
        self.assertEqual(code, 1)
        self.assertTrue(any("source=(not JS" in line for line in scenario.lines))

    def test_marker_file_records_the_source_identity(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ssok-preview-marker-") as temporary:
            written = wait.write_marker(temporary, SOURCE, "feat/own-build-r3-20261022", "slug-1", "42")
            stored = json.loads((Path(temporary) / wait.MARKER_NAME).read_text())
        self.assertEqual(stored, written)
        self.assertEqual(stored["source"], SOURCE)
        self.assertEqual(stored["branch"], "feat/own-build-r3-20261022")
        self.assertRegex(stored["exported_at"], r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")

    def test_main_rejects_non_positive_budgets(self) -> None:
        with self.assertRaises(SystemExit) as raised:
            wait.main(["--repository", "o/r", "--commit", COMMIT, "--source", SOURCE, "--url", URL,
                       "--timeout", "0"])
        self.assertNotEqual(raised.exception.code, 0)

    def test_preview_workflow_uses_the_marker_and_the_bounded_wait(self) -> None:
        workflow = (PROJECT / ".github/workflows/preview.yml").read_text()
        self.assertIn("tools/ci/pages_preview_wait.py", workflow)
        self.assertIn("write_marker", workflow)
        self.assertNotIn("pages/builds/latest", workflow)
        # The wait must stay inside the job timeout with room for export and publication.
        timeout = int(re.search(r"--timeout (\d+)", workflow).group(1))
        job_minutes = int(re.search(r"timeout-minutes: (\d+)", workflow).group(1))
        self.assertLessEqual(timeout, (job_minutes - 15) * 60)
        self.assertIn("git push origin HEAD:refs/heads/gh-pages", workflow)
        self.assertNotIn("--force", workflow)


if __name__ == "__main__":
    unittest.main()
