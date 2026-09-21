#!/usr/bin/env python3
"""Check browser persistence, project transfer and canvas authoring on the real export."""

from __future__ import annotations

import argparse
from functools import partial
from http.server import ThreadingHTTPServer
import json
from pathlib import Path
import threading
import time

from playwright.sync_api import sync_playwright

from browser_smoke import Handler

READ_DOCUMENTS = """async () => {
    const documents = [];
    for (const info of await indexedDB.databases()) {
        const db = await new Promise((resolve, reject) => {
            const request = indexedDB.open(info.name);
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error);
        });
        for (const name of Array.from(db.objectStoreNames)) {
            const store = db.transaction(name, 'readonly').objectStore(name);
            const read = request => new Promise((resolve, reject) => {
                request.onsuccess = () => resolve(request.result);
                request.onerror = () => reject(request.error);
            });
            const [keys, values] = await Promise.all([read(store.getAllKeys()), read(store.getAll())]);
            for (let i = 0; i < keys.length; i++) {
                if (String(keys[i]).includes('/projects/') && String(keys[i]).endsWith('.json')) {
                    documents.push(JSON.parse(new TextDecoder().decode(values[i].contents)));
                }
            }
        }
        db.close();
    }
    return documents;
}"""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, default=Path("build/web"))
    parser.add_argument("--output", type=Path, default=Path("build/browser-authoring"))
    parser.add_argument("--executable")
    parser.add_argument("--url")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    server = None
    if not args.url:
        server = ThreadingHTTPServer(("127.0.0.1", 0), partial(Handler, directory=str(args.directory.resolve())))
        threading.Thread(target=server.serve_forever, daemon=True).start()
    url = args.url or f"http://127.0.0.1:{server.server_address[1]}/"
    logs, checks = [], []
    result = {"url": url, "passed": False, "checks": checks}
    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(headless=True, executable_path=args.executable,
                args=["--enable-unsafe-swiftshader", "--use-gl=angle", "--use-angle=swiftshader"])
            page = browser.new_page(viewport={"width": 1400, "height": 950}, locale="en-US", accept_downloads=True)
            page.on("console", lambda message: logs.append({"type": message.type, "text": message.text}))
            page.on("pageerror", lambda error: logs.append({"type": "error", "text": str(error)}))
            page.add_init_script("window.readSsokDocuments = " + READ_DOCUMENTS)

            def ready():
                page.wait_for_function("!document.querySelector('#status')", timeout=120000)

            def capture(name):
                page.screenshot(path=str(output / (name + ".png")))
                print(name, flush=True)

            def export_document(name):
                with page.expect_download(timeout=30000) as pending:
                    page.mouse.click(565, 365)
                download = pending.value
                path = output / (name + ".json")
                download.save_as(path)
                return json.loads(path.read_text())

            try:
                page.goto(url, wait_until="networkidle", timeout=120000)
                ready()
                page.mouse.click(640, 528)  # Empty-workspace biped starter.
                page.wait_for_timeout(400)
                page.mouse.click(175, 43)
                page.keyboard.press("Control+A")
                page.keyboard.type("Browser saved biped")
                page.mouse.click(410, 365)
                deadline = time.monotonic() + 30
                saved = None
                while time.monotonic() < deadline:
                    saved = next((d for d in page.evaluate(READ_DOCUMENTS) if d["title"] == "Browser saved biped"), None)
                    if saved:
                        break
                    page.wait_for_timeout(250)
                assert saved is not None, "Named project was not persisted to IndexedDB"
                assert len(saved["graph"]["parts"]) == 11, "The saved graph must be the actual biped"
                assert "Servo(" in saved["source"], "Learner code is missing from saved project"
                checks.append("Real user:// project persisted to browser IndexedDB")
                capture("01-saved")
                page.reload(wait_until="networkidle")
                ready()
                assert page.evaluate(READ_DOCUMENTS)[0] == saved, "Project changed or disappeared after reload"
                page.mouse.click(175, 43)
                page.mouse.click(580, 460)
                page.mouse.click(425, 655)
                capture("02-replace-confirmation")
                page.keyboard.press("Enter")
                page.wait_for_timeout(300)
                capture("03-reopened")
                page.mouse.click(175, 43)
                reopened = export_document("reopened")
                assert reopened["title"] == saved["title"], "Open failed to restore the project title"
                assert reopened["graph"] == saved["graph"] and reopened["source"] == saved["source"], "Open failed to restore graph and source"
                checks.append("Reload, open confirmation and exported JSON preserve graph and learner code")
                capture("04-exported")
                page.mouse.click(690, 530)
                page.keyboard.press("Control+A")
                page.keyboard.type('{"format":"ssok-project","version":999}')
                page.mouse.click(565, 655)
                capture("05-invalid-import-rejected")
                unchanged = export_document("after-invalid-import")
                assert unchanged["graph"] == saved["graph"] and unchanged["source"] == saved["source"], "Invalid import changed current work"
                checks.append("Malformed/incompatible project import leaves the current project unchanged")
                page.mouse.click(1070, 199)
                page.mouse.click(1217, 198)
                capture("06-blocks")
                page.mouse.move(1260, 710)
                page.mouse.wheel(0, 10000)
                page.wait_for_timeout(300)
                capture("07-blocks-bottom")
                page.set_viewport_size({"width": 1152, "height": 577})
                capture("08-compact-workshop")
                checks.append("Rendered Blocks tab and compact 1152×577 workshop captured for review")
                errors = [entry for entry in logs if entry["type"] == "error" or entry["text"].startswith(("ERROR:", "SCRIPT ERROR:"))]
                assert not errors, f"Browser reported errors: {errors}"
                result.update(passed=True, errors=errors, browser=browser.version)
                print(f"Browser authoring checks passed: {output}")
            except BaseException:
                try:
                    page.screenshot(path=str(output / "failure.png"), timeout=10000)
                except Exception:
                    pass  # A browser crash can prevent screenshots; preserve the original failure.
                raise
            finally:
                browser.close()
    except BaseException as error:
        result["failure"] = f"{type(error).__name__}: {error}"
        raise
    finally:
        (output / "result.json").write_text(json.dumps(result, indent=2) + "\n")
        (output / "console.json").write_text(json.dumps(logs, indent=2) + "\n")
        (output / "completed-checks.json").write_text(json.dumps(checks, indent=2) + "\n")
        if server:
            server.shutdown()
            server.server_close()


if __name__ == "__main__":
    main()
