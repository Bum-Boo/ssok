#!/usr/bin/env python3
"""Exercise the exported WebGL app in Chromium and retain screenshots/console logs."""

from __future__ import annotations

import argparse
import base64
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import shutil
import threading

from playwright.sync_api import sync_playwright


class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_args) -> None:
        pass


def load_layout(directory: Path, output: Path) -> dict:
    path = directory.resolve().parent / "export-logs/browser-layout.json"
    layout = json.loads(path.read_text())
    shutil.copy2(path, output / "browser-layout.json")
    return layout


def capture_view(page, path: Path) -> None:
    # Godot renders its own fonts; capture Chromium's view without DOM-font stabilization.
    page.evaluate("() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(() => resolve())))")
    session = page.context.new_cdp_session(page)
    try:
        captured = session.send("Page.captureScreenshot", {
            "format": "png", "fromSurface": False, "captureBeyondViewport": False})
        path.write_bytes(base64.b64decode(captured["data"]))
    finally:
        session.detach()


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
    # The app opens on menus; this gate exercises the workshop coordinates directly.
    url += ("&" if "?" in url else "?") + "ssok_workshop=1"
    logs, errors = [], []
    result = {"url": url, "passed": False, "errors": errors,
        "viewport": [1400, 950],
        "scope": "Export loading, canvas rendering, servo-arm starter, program run and stop; screenshots require review"}

    def persist():
        (output / "console.json").write_text(json.dumps(logs, indent=2) + "\n")
        (output / "result.json").write_text(json.dumps(result, indent=2) + "\n")

    def capture(page, name):
        result["stage"] = name
        print(name, flush=True)
        persist()
        capture_view(page, output / (name + ".png"))

    persist()
    try:
        layout = load_layout(args.directory, output)
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(headless=True, executable_path=args.executable,
                args=["--enable-unsafe-swiftshader", "--use-gl=angle", "--use-angle=swiftshader"])
            page = browser.new_page(viewport=dict(zip(("width", "height"), layout["viewport"])), locale="en-US")
            page.on("console", lambda message: logs.append({"type": message.type, "text": message.text}))
            page.on("pageerror", lambda error: errors.append(str(error)))
            try:
                page.goto(url, wait_until="networkidle", timeout=120000)
                page.wait_for_function("!document.querySelector('#status') || getComputedStyle(document.querySelector('#status')).display === 'none'", timeout=120000)
                page.wait_for_function("typeof GODOT_THREADS_ENABLED !== 'undefined' && GODOT_THREADS_ENABLED === false")
                canvas = page.locator("canvas")
                assert canvas.is_visible(), "WebGL canvas is not visible"
                capture(page, "01-workshop")
                # Canvas controls have no DOM selectors; the build captures their actual layout.
                page.mouse.click(*layout["points"]["flag_starter"])
                page.wait_for_timeout(400)
                capture(page, "02-servo-arm")
                page.mouse.click(*layout["points"]["flag_action"])
                page.wait_for_timeout(30000)
                capture(page, "03-flag-result")
                page.mouse.click(*layout["points"]["stop"])
                page.wait_for_timeout(200)
                errors.extend(item["text"] for item in logs if item["type"] == "error" or item["text"].startswith(("ERROR:", "SCRIPT ERROR:")))
                result.update(single_threaded=True, browser=browser.version)
                if errors:
                    raise SystemExit("Browser errors: " + "\n".join(errors))
                result["passed"] = True
                print(f"WebGL browser smoke passed. Review screenshots and console: {output}")
            except BaseException as error:
                result["failure"] = f"{type(error).__name__}: {error}"
                persist()
                try:
                    capture_view(page, output / "failure.png")
                except Exception:
                    pass  # Keep the actual test failure even if Chromium has already exited.
                raise
            finally:
                browser.close()
    except BaseException as error:
        result.setdefault("failure", f"{type(error).__name__}: {error}")
        raise
    finally:
        persist()
        if server:
            server.shutdown()
            server.server_close()


if __name__ == "__main__":
    main()
