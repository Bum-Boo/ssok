#!/usr/bin/env python3
"""Exercise Stage solutions and interrupt a loop through actual Web canvas controls."""
from __future__ import annotations

import argparse
from functools import partial
from http.server import ThreadingHTTPServer
import json
from pathlib import Path
import threading

from playwright.sync_api import sync_playwright
from browser_smoke import Handler, capture_view, load_layout


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--executable")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    layout = load_layout(args.directory, output)
    server = ThreadingHTTPServer(("127.0.0.1", 0), partial(Handler, directory=str(args.directory.resolve())))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    url = f"http://127.0.0.1:{server.server_address[1]}/?ssok_verify=1"
    result = {"passed": False, "checks": [], "stages": [], "url": url}
    console = []
    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(headless=True, executable_path=args.executable,
                args=["--enable-unsafe-swiftshader", "--use-gl=angle", "--use-angle=swiftshader"])
            context = browser.new_context(viewport=dict(zip(("width", "height"), layout["viewport"])),
                permissions=["clipboard-read", "clipboard-write"], locale="en-US")
            page = context.new_page()
            clipboard = context.new_page()
            clipboard.route("**/__clipboard__", lambda route: route.fulfill(body="Synthetic learner code"))
            clipboard.goto(url.split("?")[0] + "__clipboard__")
            page.on("console", lambda message: console.append({"type": message.type, "text": message.text}))
            page.on("pageerror", lambda error: console.append({"type": "error", "text": str(error)}))

            def click(name):
                page.mouse.click(*layout["points"][name], delay=100)
                page.wait_for_timeout(700)

            try:
                print("Loading Web export", flush=True)
                page.goto(url, wait_until="networkidle", timeout=120000)
                page.bring_to_front()
                page.wait_for_function("window.__ssokLearning !== undefined", timeout=120000)
                print("Web observations ready", flush=True)
                result["browser"] = browser.version
                for index, name in enumerate(["flag", "finish", "sonar"]):
                    print(f"Starting Web {name}", flush=True)
                    click("stop")
                    click("stages_tab")
                    if index:
                        click("stage_picker")
                        # A mouse-opened Godot menu starts without keyboard item focus.
                        for _ in range(index + 1):
                            page.keyboard.press("ArrowDown", delay=100)
                            page.wait_for_timeout(500)
                        page.keyboard.press("Enter", delay=100)
                        page.wait_for_timeout(1000)
                    click("stage_load")
                    if index:
                        click("stage_confirm")
                    page.wait_for_function("window.__ssokLearning.scene.source.length === 0", timeout=30000)
                    click("stage_answer")
                    page.wait_for_function("window.__ssokLearning.scene.graph.parts?.length > 0", timeout=30000)
                    page.wait_for_function("window.__ssokLearning.scene.source.length > 0", timeout=30000)
                    observation = page.evaluate("window.__ssokLearning")
                    expected_parts = 4 if index == 0 else 9 if index == 1 else 10
                    assert len(observation["scene"]["graph"]["parts"]) == expected_parts, observation
                    capture_view(page, output / f"{name}-before.png")
                    click("run_code")
                    page.wait_for_function("window.__ssokLearning.result.stage.success === true", timeout=120000)
                    observation = page.evaluate("window.__ssokLearning")
                    expected_metrics = [["height"], ["x", "upright"], ["sonar_distance", "speed", "wall_contact"]][index]
                    assert [rule["metric"] for rule in observation["result"]["stage"]["measurements"]] == expected_metrics, observation
                    result["stages"].append({"name": name, "observation": observation})
                    result["checks"].append(f"{name}: actual Web physics cleared declarative stage")
                    capture_view(page, output / f"{name}-success.png")
                    print(f"PASS Web {name}: {observation['result']['stage']}", flush=True)
                click("stop")
                click("code_tab")
                source = "while True:\n    pass\n"
                clipboard.bring_to_front()
                clipboard.evaluate("text => navigator.clipboard.writeText(text)", source)
                page.bring_to_front()
                click("code_editor")
                page.keyboard.press("Control+A")
                page.keyboard.press("Control+V")
                page.wait_for_function("window.__ssokLearning.scene.source === 'while True:\\n    pass\\n'")
                click("run_code")
                page.wait_for_function("window.__ssokLearning.result.running === true")
                page.wait_for_timeout(1500)
                assert page.evaluate("window.__ssokLearning.result.running"), "Loop unexpectedly finished"
                click("stop")
                page.wait_for_function("window.__ssokLearning.result.state === 'stopped'")
                result["checks"].append("Infinite Web loop yields; UI Stop interrupts it")
                capture_view(page, output / "loop-stopped.png")
                errors = [entry for entry in console if entry["type"] == "error" or entry["text"].startswith(("ERROR:", "SCRIPT ERROR:"))]
                assert not errors, errors
                result["passed"] = True
            except BaseException as error:
                result["failure"] = str(error)
                result["last_observation"] = page.evaluate("window.__ssokLearning")
                capture_view(page, output / "failure.png")
                raise
            finally:
                browser.close()
    finally:
        (output / "result.json").write_text(json.dumps(result, indent=2) + "\n")
        (output / "console.json").write_text(json.dumps(console, indent=2) + "\n")
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
