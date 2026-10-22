#!/usr/bin/env python3
"""Measure the bundled learned policy through real WebGL controls and keyboard input."""

from __future__ import annotations

import argparse
from functools import partial
from http.server import ThreadingHTTPServer
import json
from pathlib import Path
import threading
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

from playwright.sync_api import sync_playwright

from browser_smoke import Handler, capture_view, load_layout


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, default=Path("build/web"))
    parser.add_argument("--output", type=Path, default=Path("build/browser-physics"))
    parser.add_argument("--executable", help="Optional local Chromium executable")
    parser.add_argument("--url", help="Deployed URL; --directory must contain that exact downloaded build")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    server = None
    if not args.url:
        server = ThreadingHTTPServer(("127.0.0.1", 0), partial(Handler, directory=str(args.directory.resolve())))
        threading.Thread(target=server.serve_forever, daemon=True).start()
    base_url = args.url or f"http://127.0.0.1:{server.server_address[1]}/"
    parts = urlsplit(base_url)
    query = dict(parse_qsl(parts.query))
    query["ssok_verify"] = "1"
    url = urlunsplit(parts._replace(query=urlencode(query)))
    logs, errors = [], []
    result = {"url": url, "passed": False, "errors": errors, "checks": []}

    def persist():
        (output / "console.json").write_text(json.dumps(logs, indent=2) + "\n")
        (output / "result.json").write_text(json.dumps(result, indent=2) + "\n")

    def stage(name):
        result["stage"] = name
        print(name, flush=True)
        persist()

    def check(condition, description):
        if not condition:
            raise AssertionError(description)
        result["checks"].append(description)

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
                stage("load")
                page.goto(url, wait_until="networkidle", timeout=120000)
                page.wait_for_function("!document.querySelector('#status') || getComputedStyle(document.querySelector('#status')).display === 'none'", timeout=120000)
                page.wait_for_function("typeof GODOT_THREADS_ENABLED !== 'undefined' && GODOT_THREADS_ENABLED === false")
                page.mouse.click(*layout["points"]["learned_starter"])
                page.wait_for_timeout(300)
                page.mouse.click(*layout["points"]["run_mode"])
                page.evaluate("() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))")
                page.mouse.click(*layout["points"]["world_focus"])
                stage("settle")
                page.wait_for_function("window.__ssokPhysics?.ready && window.__ssokPhysics.settle_frames >= 60", timeout=180000)
                initial = page.evaluate("window.__ssokPhysics")
                result["initial"] = initial
                check(initial["bundled_policy"] and initial["physics_hz"] == 60, "Actual bundled policy at 60 Hz")
                check(initial["graph_fingerprint"] == initial["policy_graph_fingerprint"], "Policy matches actual graph")
                check(initial["runtime_fingerprint"] == initial["policy_runtime_fingerprint"], "Policy matches actual runtime")
                stage("hold_w")
                page.keyboard.down("w")
                page.wait_for_function("Boolean(window.__ssokPhysics?.walk)", polling=100, timeout=180000)
                measured = page.evaluate("window.__ssokPhysics")
                result["measurement"] = measured
                persist()
                # Release real input immediately; the completed 720-frame snapshot cannot extend.
                page.keyboard.up("w")
                stage("stop")
                page.wait_for_function("Boolean(window.__ssokPhysics?.stop)", polling=100, timeout=120000)
                final = page.evaluate("window.__ssokPhysics")
                result["measurement"] = final
                result["browser"] = browser.version
                persist()
                walk, stop = final["walk"], final["stop"]
                check(walk == measured["walk"], "Completed walking snapshot remains immutable after polling and stop")
                check(walk["frames"] == 720 and walk["seconds"] == 12.0 and not walk["failure"], "Actual W command covers exactly 720 physics intervals / 12 seconds")
                check(walk["finite"], "Walking trajectory is finite")
                check(walk["forward"] >= 0.30, "Forward displacement is at least 0.30 m")
                check(abs(walk["lateral"]) <= 0.10, "Lateral displacement is at most 0.10 m")
                check(abs(walk["yaw_degrees"]) <= 30.0, "Heading drift is at most 30 degrees")
                check(walk["minimum_upright"] >= 0.85 and walk["minimum_height"] > 0.09, "Robot remains upright and above the app height gate throughout walking")
                check(len(walk["foot_air_frames"]) == 2 and min(walk["foot_air_frames"]) > 0, "Both feet have actual airborne frames")
                check(min(walk["maximum_foot_clearance_m"]) > 0.0005, "Both collision soles clear the floor by more than 0.5 mm")
                check(stop["frames"] == 90 and stop["command"] == [0, 0], "W release stops commands for 90 physics intervals")
                check(stop["finite"] and stop["upright"] >= 0.90, "Robot remains upright 1.5 seconds after stopping")
                for snapshot in (walk, stop):
                    check(snapshot["graph_fingerprint"] == initial["graph_fingerprint"], "Authored graph stays unchanged")
                    check(snapshot["runtime_fingerprint"] == initial["runtime_fingerprint"], "Physics configuration stays unchanged")
                errors.extend(item["text"] for item in logs if item["type"] == "error" or item["text"].startswith(("ERROR:", "SCRIPT ERROR:")))
                check(not errors, "No browser or engine errors")
                stage("measured")
                # The robot can walk out of the initial camera view; Home frames actual run bodies.
                page.keyboard.press("Home")
                capture_view(page, output / "learned-after-stop.png")
                result["passed"] = True
                print(json.dumps(walk, indent=2), flush=True)
            except BaseException as error:
                result["failure"] = f"{type(error).__name__}: {error}"
                persist()
                try:
                    result["last_observation"] = page.evaluate("window.__ssokPhysics || null")
                    persist()
                    capture_view(page, output / "failure.png")
                except Exception:
                    pass
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
