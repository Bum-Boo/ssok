#!/usr/bin/env python3
"""Verify exported settings through real canvas input and browser reload."""

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
    parser.add_argument("--url")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    layout = load_layout(args.directory, output)
    server = None
    if not args.url:
        server = ThreadingHTTPServer(("127.0.0.1", 0), partial(Handler, directory=str(args.directory.resolve())))
        threading.Thread(target=server.serve_forever, daemon=True).start()
    url = args.url or f"http://127.0.0.1:{server.server_address[1]}/"
    url += ("&" if "?" in url else "?") + "ssok_verify=1"
    logs, errors, checks = [], [], []
    result = {"passed": False, "url": url, "checks": checks, "errors": errors,
        "scope": "Real canvas input, system appearance, explicit override, independent text sizes, mute/volume, draft hashes, persisted reload"}

    def persist():
        (output / "result.json").write_text(json.dumps(result, indent=2) + "\n")
        (output / "console.json").write_text(json.dumps(logs, indent=2) + "\n")

    def check(condition, label):
        checks.append({"label": label, "passed": bool(condition)})
        print(("PASS " if condition else "FAIL ") + label, flush=True)
        persist()
        assert condition, label

    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(headless=True, executable_path=args.executable,
                args=["--enable-unsafe-swiftshader", "--use-gl=angle", "--use-angle=swiftshader"])
            context = browser.new_context(viewport=dict(zip(("width", "height"), layout["viewport"])),
                locale="en-US", color_scheme="light")
            page = context.new_page()
            page.on("console", lambda message: logs.append({"type": message.type, "text": message.text}))
            page.on("pageerror", lambda error: errors.append(str(error)))

            def state():
                return page.evaluate("window.__ssokInterface")

            def wait(expression):
                page.wait_for_function("window.__ssokInterface && (" + expression + ")", timeout=30000)

            def click(name):
                page.mouse.click(*layout["points"][name])
                page.wait_for_timeout(400)

            def choose(name, index):
                print(f"Select {name} item {index}", flush=True)
                click(name)
                # Mouse-opened Godot menus start without keyboard item focus.
                for _ in range(index + 1):
                    page.keyboard.press("ArrowDown")
                    page.evaluate("() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))")
                if name == "settings_appearance" and not (output / "00-appearance-menu.png").exists():
                    capture_view(page, output / "00-appearance-menu.png")
                page.keyboard.press("Enter")
                page.evaluate("() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))")
                page.wait_for_timeout(500)

            try:
                page.goto(url, wait_until="networkidle", timeout=120000)
                wait("window.__ssokInterface.locale === 'en'")
                wait("!window.__ssokInterface.dark")
                check(state()["values"]["appearance"] == "system", "fresh browser follows light system appearance")
                click("flag_starter")
                wait("window.__ssokLearning?.scene?.graph?.parts?.length > 0")
                before = state()
                click("settings_button")
                wait("window.__ssokInterface.settings_open")
                choose("settings_appearance", 2)
                wait("window.__ssokInterface.values.appearance === 'dark' && window.__ssokInterface.dark")
                page.emulate_media(color_scheme="light")
                page.wait_for_timeout(1500)
                check(state()["dark"], "explicit dark ignores light system appearance")
                choose("settings_appearance", 0)
                wait("!window.__ssokInterface.dark")
                page.emulate_media(color_scheme="dark")
                wait("window.__ssokInterface.dark")
                check(state()["values"]["appearance"] == "system", "system appearance updates while settings are open")
                choose("settings_language", 0)
                wait("window.__ssokInterface.locale === 'ko'")
                choose("settings_code", 4)
                wait("window.__ssokInterface.code_font_size === 30")
                check(state()["ui_font_size"] == 14, "code 200 percent does not enlarge interface text")
                click("settings_mute")
                wait("window.__ssokInterface.values.muted")
                click("settings_volume")
                page.keyboard.press("Home")
                for _ in range(5):
                    page.keyboard.press("ArrowRight")
                    page.evaluate("() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))")
                wait("window.__ssokInterface.values.volume === 25")
                choose("settings_appearance", 2)
                choose("settings_text", 4)
                wait("window.__ssokInterface.ui_font_size === 28")
                capture_view(page, output / "03-text-200-settings.png")
                page.keyboard.press("Escape")
                wait("!window.__ssokInterface.settings_open")
                after = state()
                check(after["program_panel_right"] <= after["viewport_width"], "Korean 200 percent program panel stays inside browser viewport")
                for key in ("source_hash", "graph_hash", "draft_hash", "run_mode", "code_running"):
                    check(after[key] == before[key], key + " preserved through live settings")
                check(after["code_font_size"] == 30, "interface 200 percent leaves code at its independent 200 percent")
                # Godot's user:// sync to IndexedDB is asynchronous.
                page.wait_for_timeout(8000)
                page.reload(wait_until="networkidle", timeout=120000)
                wait("window.__ssokInterface.locale === 'ko'")
                restored = state()
                check(restored["values"] == after["values"], "all five preferences persist through real browser reload")
                check(restored["dark"] and restored["ui_font_size"] == 28 and restored["code_font_size"] == 30,
                    "persisted theme and both font sizes apply on new app startup")
                capture_view(page, output / "05-reloaded.png")
                errors.extend(item["text"] for item in logs if item["type"] == "error" or item["text"].startswith(("ERROR:", "SCRIPT ERROR:")))
                check(not errors, "browser console and page have no errors")
                result.update(passed=True, browser=browser.version, before=before, after=after, restored=restored)
                print(f"Browser settings: {len(checks)} checks passed; evidence {output}", flush=True)
            except BaseException as error:
                result["failure"] = f"{type(error).__name__}: {error}"
                result["observed"] = state()
                capture_view(page, output / "failure.png")
                raise
            finally:
                browser.close()
    finally:
        persist()
        if server:
            server.shutdown()
            server.server_close()


if __name__ == "__main__":
    main()
