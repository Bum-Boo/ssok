#!/usr/bin/env python3
"""Exercise the exported WebGL app in Chromium and retain screenshots/console logs."""

from __future__ import annotations

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import threading

from playwright.sync_api import sync_playwright


class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_args) -> None:
        pass


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, default=Path("build/web"))
    parser.add_argument("--output", type=Path, default=Path("build/browser-smoke"))
    parser.add_argument("--executable", help="Optional local Chromium executable")
    parser.add_argument("--url", help="Test an already deployed URL instead of the local export")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    server = None
    if not args.url:
        server = ThreadingHTTPServer(("127.0.0.1", 0), partial(Handler, directory=str(args.directory.resolve())))
        threading.Thread(target=server.serve_forever, daemon=True).start()
    url = args.url or f"http://127.0.0.1:{server.server_address[1]}/"
    logs, errors = [], []
    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(headless=True, executable_path=args.executable,
                args=["--enable-unsafe-swiftshader", "--use-gl=angle", "--use-angle=swiftshader"])
            page = browser.new_page(viewport={"width": 1400, "height": 950}, locale="en-US")
            page.on("console", lambda message: logs.append({"type": message.type, "text": message.text}))
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.goto(url, wait_until="networkidle", timeout=120000)
            page.wait_for_function("!document.querySelector('#status') || getComputedStyle(document.querySelector('#status')).display === 'none'", timeout=120000)
            page.wait_for_function("typeof GODOT_THREADS_ENABLED !== 'undefined' && GODOT_THREADS_ENABLED === false")
            canvas = page.locator("canvas")
            assert canvas.is_visible(), "WebGL canvas is not visible"
            page.screenshot(path=str(output / "01-workshop.png"))
            # Godot renders its own UI into the canvas. Fixed desktop coordinates intentionally
            # cover a starter click and run/stop; screenshots are retained for product review.
            page.mouse.click(640, 528)
            page.wait_for_timeout(400)
            page.screenshot(path=str(output / "02-biped.png"))
            page.mouse.click(910, 43)
            page.wait_for_timeout(1200)
            page.screenshot(path=str(output / "03-running.png"))
            page.mouse.click(910, 43)
            page.wait_for_timeout(200)
            errors.extend(item["text"] for item in logs if item["type"] == "error" or item["text"].startswith(("ERROR:", "SCRIPT ERROR:")))
            (output / "console.json").write_text(json.dumps(logs, indent=2) + "\n")
            (output / "result.json").write_text(json.dumps({"url": url, "errors": errors,
                "single_threaded": True, "viewport": [1400, 950], "browser": browser.version,
                "scope": "Export loading, canvas rendering, starter and run/stop input; screenshots require review"}, indent=2) + "\n")
            browser.close()
            if errors:
                raise SystemExit("Browser errors: " + "\n".join(errors))
            print(f"WebGL browser smoke passed. Review screenshots and console: {output}")
    finally:
        if server:
            server.shutdown()
            server.server_close()


if __name__ == "__main__":
    main()
