#!/usr/bin/env python3
"""Frozen candidate: six predeclared real-browser episodes, retaining every result."""
import argparse
from functools import partial
from http.server import ThreadingHTTPServer
import json
from pathlib import Path
import threading

from playwright.sync_api import sync_playwright
from browser_smoke import Handler, capture_view, load_layout


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--schedule", type=Path, required=True)
    args = parser.parse_args()
    plan = json.loads(args.schedule.read_text())
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer(("127.0.0.1", 0),
        partial(Handler, directory=str(args.directory.resolve())))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    url = f"http://127.0.0.1:{server.server_address[1]}/?ssok_verify=1"
    results = []
    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(headless=True,
                args=["--enable-unsafe-swiftshader", "--use-gl=angle", "--use-angle=swiftshader"])
            try:
                for case in plan:
                    folder = output / case["name"]
                    folder.mkdir()
                    layout = load_layout(args.directory, folder)
                    context = browser.new_context(
                        viewport=dict(zip(("width", "height"), layout["viewport"])), locale="en-US")
                    page = context.new_page()
                    logs, errors = [], []
                    page.on("console", lambda message: logs.append(
                        {"type": message.type, "text": message.text}))
                    page.on("pageerror", lambda error: errors.append(str(error)))
                    result = {"case": case, "passed": False, "checks": [], "errors": errors,
                              "browser": browser.version, "url": url}

                    def persist():
                        (folder / "result.json").write_text(json.dumps(result, indent=2) + "\n")
                        (folder / "console.json").write_text(json.dumps(logs, indent=2) + "\n")

                    def stage(name):
                        result["stage"] = name
                        print(case["name"], name, flush=True)
                        persist()

                    def check(condition, description):
                        result["checks"].append({"passed": bool(condition), "description": description})

                    def read():
                        return page.evaluate("window.__ssokPhysics")

                    try:
                        stage("load")
                        page.goto(url, wait_until="networkidle", timeout=120000)
                        page.wait_for_function("!document.querySelector('#status') || "
                            "getComputedStyle(document.querySelector('#status')).display === 'none'",
                            timeout=120000)
                        page.wait_for_function("GODOT_THREADS_ENABLED === false")
                        page.mouse.click(*layout["points"]["learned_starter"])
                        page.wait_for_timeout(300)
                        page.mouse.click(*layout["points"]["run_mode"])
                        page.evaluate("() => new Promise(resolve => requestAnimationFrame("
                            "() => requestAnimationFrame(resolve)))")
                        page.mouse.click(*layout["points"]["world_focus"])
                        stage("settle")
                        page.wait_for_function("n => window.__ssokPhysics?.ready && "
                            "window.__ssokPhysics.settle_frames >= n", arg=case["settle"], timeout=180000)
                        initial = read()
                        result["initial"] = initial
                        check(initial["bundled_policy"] and initial["physics_hz"] == 60,
                              "Bundled actual application at 60 Hz")
                        check(initial["graph_fingerprint"] == initial["policy_graph_fingerprint"],
                              "Exact graph fingerprint")
                        check(initial["runtime_fingerprint"] == initial["policy_runtime_fingerprint"],
                              "Exact version-aware runtime fingerprint")
                        target_episode = 1
                        if "warmup" in case:
                            stage("warmup")
                            page.keyboard.down("w")
                            page.wait_for_function("n => window.__ssokPhysics?.episode === 1 && "
                                "window.__ssokPhysics.command_frames >= n",
                                arg=case["warmup"], timeout=120000)
                            result["warmup_before_release"] = read()
                            page.keyboard.up("w")
                            page.wait_for_function("window.__ssokPhysics?.walk && "
                                "window.__ssokPhysics.command[1] === 0", timeout=30000)
                            result["warmup"] = read()
                            warmup = result["warmup"]["walk"]
                            check(warmup["failure"] == "command_released_before_horizon",
                                  "Warmup early release remains explicitly recorded")
                            check(warmup["finite"] and warmup["minimum_upright"] >= 0.85
                                  and warmup["minimum_height"] > 0.09,
                                  "Warmup remains finite, upright and above the app height limit")
                            stage("pause")
                            page.wait_for_function("n => window.__ssokPhysics?.released_frames >= n",
                                arg=case["pause"], timeout=120000)
                            result["before_restart"] = read()
                            target_episode = 2
                        stage("measure")
                        page.keyboard.down("w")
                        page.wait_for_function("episode => window.__ssokPhysics?.episode === episode && "
                            "Boolean(window.__ssokPhysics.walk)", arg=target_episode,
                            polling=100, timeout=180000)
                        measured = read()
                        result["before_stop"] = measured
                        persist()
                        page.keyboard.up("w")
                        stage("stop")
                        page.wait_for_function("episode => window.__ssokPhysics?.episode === episode && "
                            "Boolean(window.__ssokPhysics.stop)", arg=target_episode,
                            polling=100, timeout=120000)
                        final = read()
                        result["measurement"] = final
                        walk, stop = final["walk"], final["stop"]
                        check(walk == measured["walk"], "Completed measurement stays immutable")
                        check(walk["frames"] == 720 and walk["seconds"] == 12 and not walk["failure"],
                              "Exactly 720 physics intervals / 12 seconds")
                        check(walk["finite"], "Finite complete trajectory")
                        check(walk["forward"] >= 0.30, "At least 0.30 m forward")
                        check(abs(walk["lateral"]) <= 0.10, "At most 0.10 m lateral")
                        check(abs(walk["yaw_degrees"]) <= 30.0, "At most 30 degrees heading drift")
                        check(walk["minimum_upright"] >= 0.85 and walk["minimum_height"] > 0.09,
                              "App uprightness and height thresholds throughout walking")
                        check(len(walk["foot_air_frames"]) == 2 and min(walk["foot_air_frames"]) > 0,
                              "Both feet have airborne frames")
                        check(min(walk["maximum_foot_clearance_m"]) > 0.0005,
                              "Both actual collision soles clear 0.5 mm")
                        check(stop["frames"] == 90 and stop["command"] == [0, 0],
                              "Released command for 90 physics intervals")
                        check(stop["finite"] and stop["upright"] >= 0.90,
                              "Finite and upright 1.5 seconds after release")
                        for snapshot in (walk, stop):
                            check(snapshot["graph_fingerprint"] == initial["graph_fingerprint"],
                                  "Authored graph remains unchanged")
                            check(snapshot["runtime_fingerprint"] == initial["runtime_fingerprint"],
                                  "Runtime configuration remains unchanged")
                        if target_episode == 2:
                            check(len(final["previous_episodes"]) == 1 and
                                  final["previous_episodes"][0]["walk"] == result["warmup"]["walk"],
                                  "First episode is preserved without rewriting its outcome")
                        errors.extend(item["text"] for item in logs if item["type"] == "error" or
                            item["text"].startswith(("ERROR:", "SCRIPT ERROR:")))
                        check(not errors, "No browser or engine errors")
                        result["passed"] = all(item["passed"] for item in result["checks"])
                        capture_view(page, folder / "after-stop.png")
                        stage("complete")
                    except Exception as error:
                        result["failure"] = f"{type(error).__name__}: {error}"
                        try:
                            result["last_observation"] = read()
                            capture_view(page, folder / "failure.png")
                        except Exception as capture_error:
                            result["capture_failure"] = str(capture_error)
                    finally:
                        persist()
                        context.close()
                    results.append(result)
                    (output / "results.json").write_text(json.dumps({
                        "schedule": plan, "passed": sum(item["passed"] for item in results),
                        "completed": len(results), "total": len(plan), "results": results}, indent=2) + "\n")
                    print(case["name"], "PASS" if result["passed"] else "FAIL", flush=True)
            finally:
                browser.close()
    finally:
        server.shutdown()
        server.server_close()
    raise SystemExit(0 if len(results) == len(plan) and all(item["passed"] for item in results) else 1)


if __name__ == "__main__":
    main()
