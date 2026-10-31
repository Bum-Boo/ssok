#!/usr/bin/env python3
"""Wait until a committed branch preview is actually served by GitHub Pages.

The preview workflow commits one directory to ``gh-pages`` and then needs to know when the
site serves it. ``GET /pages/builds/latest`` is not a reliable signal: after a requested
build it can keep answering the ``{"status": "queued"}`` placeholder (without a commit)
while the pushed revision is already built and served. This script therefore treats the
served marker file as the authoritative success signal, uses the Pages API only for
diagnostics and fast failure, and bounds the whole wait with one explicit deadline.

Success requires the preview URL to return ``preview.json`` whose ``source`` equals the
expected application commit. A Pages build that errored for the pushed ``gh-pages`` commit
fails immediately. Nothing here changes Pages settings, force-pushes or deletes files.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass, field
import json
import os
import subprocess
import sys
import time
from typing import Callable
import urllib.error
import urllib.request

MARKER_NAME = "preview.json"


def gh_api(method: str, path: str) -> tuple[int, object]:
    """Call the GitHub REST API through the authenticated ``gh`` CLI.

    Returns an HTTP-like status and the decoded JSON body. ``gh`` exits nonzero for HTTP
    errors; the status is then taken from the body when possible and 599 otherwise, so the
    caller can log it instead of raising.
    """
    command = ["gh", "api", "--method", method, path, "-H", "Accept: application/vnd.github+json"]
    completed = subprocess.run(command, capture_output=True, text=True, timeout=60)
    body: object = None
    if completed.stdout.strip():
        try:
            body = json.loads(completed.stdout)
        except json.JSONDecodeError:
            body = {"raw": completed.stdout[-500:]}
    if completed.returncode == 0:
        return 200, body
    status = 599
    if isinstance(body, dict) and isinstance(body.get("status"), str) and body["status"].isdigit():
        status = int(body["status"])
    if body is None:
        body = {"message": completed.stderr.strip()[-500:]}
    return status, body


def http_get(url: str, timeout: float = 30.0) -> tuple[int, bytes]:
    request = urllib.request.Request(url, headers={
        "Cache-Control": "no-cache", "Pragma": "no-cache", "User-Agent": "ssok-preview-wait"})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as error:
        return error.code, b""
    except (urllib.error.URLError, TimeoutError, OSError) as error:
        return 0, str(error).encode()


def write_marker(directory: str, source: str, branch: str, slug: str, run_id: str) -> dict:
    marker = {"schema": 1, "source": source, "branch": branch, "slug": slug, "run_id": run_id,
              "exported_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
    path = os.path.join(directory, MARKER_NAME)
    with open(path, "w", encoding="utf-8") as stream:
        json.dump(marker, stream, indent=2)
        stream.write("\n")
    return marker


@dataclass
class Observation:
    elapsed: float
    site_status: str = "unknown"
    build_status: str = "not listed"
    build_error: str = ""
    latest: str = "unknown"
    served_http: int = 0
    served_source: str = ""
    served_match: bool = False
    api_notes: list[str] = field(default_factory=list)

    def line(self, commit: str) -> str:
        served = f"served={self.served_http}"
        if self.served_source:
            served += f" source={self.served_source[:7]}"
        served += " MATCH" if self.served_match else ""
        return (f"[{self.elapsed:6.1f}s] site={self.site_status} build[{commit[:7]}]={self.build_status} "
                f"latest={self.latest} {served}")


class PreviewWaiter:
    def __init__(self, repository: str, commit: str, source: str, url: str, *,
                 api: Callable[[str, str], tuple[int, object]] = gh_api,
                 fetch: Callable[[str], tuple[int, bytes]] = http_get,
                 clock: Callable[[], float] = time.monotonic,
                 sleep: Callable[[float], None] = time.sleep,
                 log: Callable[[str], None] = lambda message: print(message, flush=True)) -> None:
        self.repository = repository
        self.commit = commit
        self.source = source
        self.url = url if url.endswith("/") else url + "/"
        self.api = api
        self.fetch = fetch
        self.clock = clock
        self.sleep = sleep
        self.log = log
        self.history: list[Observation] = []

    def request_build(self) -> None:
        # GITHUB_TOKEN pushes may not trigger branch-source builds, so ask for one. A refusal
        # is logged, not fatal: the served marker decides success below.
        status, body = self._safe_api("POST", f"repos/{self.repository}/pages/builds")
        detail = body.get("status") or body.get("message") if isinstance(body, dict) else body
        self.log(f"Requested a Pages build: HTTP {status}, {detail!r}")

    def _safe_api(self, method: str, path: str) -> tuple[int, object]:
        try:
            return self.api(method, path)
        except (subprocess.SubprocessError, OSError, ValueError) as error:
            return 0, {"message": f"{type(error).__name__}: {error}"}

    def observe(self, started: float) -> Observation:
        observation = Observation(elapsed=self.clock() - started)
        status, site = self._safe_api("GET", f"repos/{self.repository}/pages")
        if status == 200 and isinstance(site, dict):
            observation.site_status = str(site.get("status"))
        else:
            observation.api_notes.append(f"pages: HTTP {status}")
        status, builds = self._safe_api("GET", f"repos/{self.repository}/pages/builds?per_page=20")
        if status == 200 and isinstance(builds, list):
            if builds and isinstance(builds[0], dict):
                first = builds[0]
                observation.latest = f"{str(first.get('commit') or '-')[:7]}:{first.get('status')}"
            for build in builds:
                if isinstance(build, dict) and build.get("commit") == self.commit:
                    observation.build_status = str(build.get("status"))
                    error = build.get("error") or {}
                    observation.build_error = str(error.get("message") or "") if isinstance(error, dict) else str(error)
                    break
        else:
            observation.api_notes.append(f"builds: HTTP {status}")
        marker_url = f"{self.url}{MARKER_NAME}?source={self.source}"
        try:
            observation.served_http, payload = self.fetch(marker_url)
        except (OSError, ValueError) as error:
            observation.served_http, payload = 0, str(error).encode()
        if observation.served_http == 200:
            try:
                marker = json.loads(payload.decode("utf-8"))
                observation.served_source = str(marker.get("source", "")) if isinstance(marker, dict) else ""
            except (UnicodeDecodeError, json.JSONDecodeError):
                observation.served_source = "(not JSON)"
            observation.served_match = observation.served_source == self.source
        self.history.append(observation)
        return observation

    def wait(self, timeout: float, interval: float) -> int:
        started = self.clock()
        self.log(f"Waiting up to {timeout:.0f}s for {self.url}{MARKER_NAME} to report source {self.source}")
        while True:
            observation = self.observe(started)
            line = observation.line(self.commit)
            if observation.api_notes:
                line += " api(" + ", ".join(observation.api_notes) + ")"
            self.log(line)
            if observation.build_status == "errored":
                self.log(f"Pages build for gh-pages {self.commit} errored: {observation.build_error or 'no message'}")
                self.log("The committed files remain on gh-pages; inspect Pages build history before rerunning.")
                return 1
            if observation.served_match:
                suffix = "" if observation.build_status == "built" else \
                    f" (Pages API reported build {observation.build_status}; the served site is authoritative)"
                self.log(f"Preview is served with the expected source after {observation.elapsed:.0f}s{suffix}")
                return 0
            if self.clock() - started + interval > timeout:
                self.log(f"Timed out after {timeout:.0f}s: the preview never served source {self.source}.")
                if observation.served_http == 200:
                    self.log(f"The URL serves an older marker (source {observation.served_source or '?'}); "
                             "Pages or its CDN has not published the new commit yet.")
                elif observation.served_http:
                    self.log(f"The marker URL returned HTTP {observation.served_http}.")
                else:
                    self.log("The marker URL could not be fetched.")
                self.log("Nothing was rolled back. Rerun this workflow once Pages build history shows the commit as built.")
                return 1
            self.sleep(interval)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--repository", required=True, help="OWNER/REPO")
    parser.add_argument("--commit", required=True, help="gh-pages commit that contains the preview")
    parser.add_argument("--source", required=True, help="application commit recorded in preview.json")
    parser.add_argument("--url", required=True, help="public preview directory URL")
    parser.add_argument("--timeout", type=float, default=900.0, help="total seconds to wait (default 900)")
    parser.add_argument("--interval", type=float, default=15.0, help="seconds between polls (default 15)")
    parser.add_argument("--no-request-build", action="store_true", help="do not POST a Pages build request")
    parser.add_argument("--summary", help="file that receives one Markdown result line (GITHUB_STEP_SUMMARY)")
    args = parser.parse_args(argv)
    if args.timeout <= 0 or args.interval <= 0:
        parser.error("--timeout and --interval must be positive")
    waiter = PreviewWaiter(args.repository, args.commit, args.source, args.url)
    if not args.no_request_build:
        waiter.request_build()
    code = waiter.wait(args.timeout, args.interval)
    if args.summary:
        last = waiter.history[-1] if waiter.history else None
        verdict = "served" if code == 0 else "not served"
        detail = f"Pages API build `{last.build_status}`, marker HTTP {last.served_http}" if last else "no observation"
        with open(args.summary, "a", encoding="utf-8") as stream:
            stream.write(f"Preview {verdict} after {last.elapsed if last else 0:.0f}s ({detail}).\n\n")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
