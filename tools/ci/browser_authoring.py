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
import traceback

from playwright.sync_api import sync_playwright

from browser_smoke import Handler, capture_view, load_layout

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
    parser.add_argument("--hardware", action="store_true", help="Use the local display and OpenGL for GPU verification")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    server = None
    if not args.url:
        server = ThreadingHTTPServer(("127.0.0.1", 0), partial(Handler, directory=str(args.directory.resolve())))
        threading.Thread(target=server.serve_forever, daemon=True).start()
    base_url = args.url or f"http://127.0.0.1:{server.server_address[1]}/"
    # The app opens on menus; this gate exercises the workshop coordinates directly.
    url = base_url + ("&" if "?" in base_url else "?") + "ssok_workshop=1"
    logs, checks = [], []
    result = {"url": url, "passed": False, "checks": checks}

    def persist():
        (output / "result.json").write_text(json.dumps(result, indent=2) + "\n")
        (output / "console.json").write_text(json.dumps(logs, indent=2) + "\n")
        (output / "completed-checks.json").write_text(json.dumps(checks, indent=2) + "\n")

    def stage(message):
        result["stage"] = message
        print(message, flush=True)
        persist()

    persist()
    try:
        layout = load_layout(args.directory, output)
        with sync_playwright() as playwright:
            graphics = ["--enable-gpu", "--ignore-gpu-blocklist", "--use-gl=angle", "--use-angle=gl"] if args.hardware else ["--enable-unsafe-swiftshader", "--use-gl=angle", "--use-angle=swiftshader"]
            browser = playwright.chromium.launch(headless=not args.hardware, executable_path=args.executable, args=graphics)
            context = browser.new_context(viewport=dict(zip(("width", "height"), layout["viewport"])),
                locale="en-US", accept_downloads=True, permissions=["clipboard-read", "clipboard-write"])
            page = context.new_page()
            clipboard_page = context.new_page()
            clipboard_url = base_url.split("?")[0].rstrip("/") + "/__ssok_test_clipboard__"
            clipboard_page.route(clipboard_url, lambda route: route.fulfill(body="<p>Synthetic project transfer</p>"))
            clipboard_page.goto(clipboard_url)
            def record_console(message):
                logs.append({"type": message.type, "text": message.text})
                if message.text.startswith("SSOK_TEST_PASTE"):
                    print(message.text, flush=True)

            page.on("console", record_console)
            page.on("pageerror", lambda error: logs.append({"type": "error", "text": str(error)}))
            page.add_init_script("window.readSsokDocuments = " + READ_DOCUMENTS)
            page.add_init_script("window.addEventListener('paste', event => console.log('SSOK_TEST_PASTE ' + event.clipboardData.getData('text').length))")

            def click(name):
                stage(f"Click {name}")
                page.mouse.click(*layout["points"][name])
                # Browser input acknowledgements precede Godot's next canvas/UI frame.
                page.evaluate("() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))")

            def ready():
                page.wait_for_function("!document.querySelector('#status')", timeout=120000)
                stage("Workshop ready")

            def capture(name):
                stage(name)
                capture_view(page, output / (name + ".png"))

            def replace_text(name, value):
                stage(f"Paste {len(value)} characters into {name}")
                clipboard_page.bring_to_front()
                clipboard_page.evaluate("""value => Promise.race([
                    navigator.clipboard.writeText(value),
                    new Promise((_, reject) => setTimeout(() => reject(new Error('Clipboard write timed out')), 5000))
                ])""", value)
                stage(f"Clipboard contains {len(value)} characters")
                page.bring_to_front()
                click(name)
                page.keyboard.press("Control+A")
                page.wait_for_timeout(250)
                page.keyboard.press("Control+V")
                page.evaluate("() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))")
                stage(f"Paste dispatched to {name}")

            def export_document(name):
                with page.expect_download(timeout=30000) as pending:
                    click("export")
                download = pending.value
                path = output / (name + ".json")
                download.save_as(path)
                return json.loads(path.read_text())

            try:
                page.goto(url, wait_until="networkidle", timeout=120000)
                page.bring_to_front()
                ready()
                click("starter")
                page.wait_for_timeout(400)
                click("projects")
                replace_text("project_name", "Browser saved biped")
                click("save")
                deadline = time.monotonic() + 30
                saved = None
                documents = []
                while time.monotonic() < deadline:
                    documents = page.evaluate(READ_DOCUMENTS)
                    saved = next((d for d in documents if d["title"] == "Browser saved biped"), None)
                    if saved:
                        break
                    page.wait_for_timeout(250)
                (output / "persisted-documents.json").write_text(json.dumps(documents, indent=2) + "\n")
                assert saved is not None, "Named project was not persisted to IndexedDB"
                assert len(saved["graph"]["parts"]) == 11, "The saved graph must be the actual biped"
                assert "Servo(" in saved["source"], "Learner code is missing from saved project"
                checks.append("Real user:// project persisted to browser IndexedDB")
                capture("01-saved")
                page.reload(wait_until="networkidle", timeout=120000)
                ready()
                assert page.evaluate(READ_DOCUMENTS)[0] == saved, "Project changed or disappeared after reload"
                click("projects")
                click("saved_first")
                click("open")
                capture("02-replace-confirmation")
                click("project_confirm")
                page.wait_for_timeout(300)
                capture("03-reopened")
                click("projects")
                reopened = export_document("reopened")
                assert reopened["title"] == saved["title"], "Open failed to restore the project title"
                assert reopened["graph"] == saved["graph"] and reopened["source"] == saved["source"], "Open failed to restore graph and source"
                checks.append("Reload, open confirmation and exported JSON preserve graph and learner code")
                capture("04-exported")
                transferred = dict(reopened, title="Browser imported biped")
                replace_text("transfer_text", json.dumps(transferred))
                click("import")
                capture("05-import-confirmation")
                click("project_confirm")
                page.wait_for_timeout(300)
                click("projects")
                imported = export_document("after-valid-import")
                assert imported["title"] == transferred["title"], "Pasted JSON import failed to restore its distinct project title"
                assert imported["graph"] == saved["graph"] and imported["source"] == saved["source"], "Clipboard JSON import changed graph or source"
                checks.append("Actual clipboard paste, import confirmation and re-export preserve the shared project")
                replace_text("transfer_text", '{"format":"ssok-project","version":999}')
                click("import")
                capture("06-invalid-import-rejected")
                unchanged = export_document("after-invalid-import")
                assert unchanged["title"] == imported["title"] and unchanged["graph"] == saved["graph"] and unchanged["source"] == saved["source"], "Invalid import changed current work"
                checks.append("Malformed/incompatible project import leaves the current project unchanged")
                click("close_projects")
                click("blocks_tab")
                capture("07-blocks")
                page.mouse.move(*layout["points"]["blocks_scroll"])
                page.mouse.wheel(0, 10000)
                page.wait_for_timeout(300)
                capture("08-blocks-bottom")
                click("block_operation")
                # Mouse-opened Godot menus start without keyboard focus. Select the
                # semantic Wait entry; added motor operations can follow it.
                for _ in range(layout["block_wait_index"] + 1):
                    page.keyboard.press("ArrowDown")
                    page.evaluate("() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))")
                capture("08a-wait-operation")
                page.keyboard.press("Enter")
                page.evaluate("() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))")
                click("add_block")
                page.mouse.move(*layout["points"]["blocks_scroll"])
                page.mouse.wheel(0, 10000)
                page.wait_for_timeout(300)
                replace_text("block_seconds", "0.2")
                click("apply_blocks")
                capture("09-blocks-applied")
                click("projects")
                edited = export_document("after-block-edit")
                assert edited["graph"] == saved["graph"], "Block edit changed assembly graph"
                assert edited["source"].startswith(saved["source"]) and edited["source"].endswith("sleep(0.2)"), "Added/edited sleep block was not applied to learner code"
                checks.append("Actual block addition, numeric editing and Apply preserve prior source and update exported code")
                click("close_projects")
                replace_text("block_seconds", "0.3")
                click("run_code")
                page.wait_for_timeout(400)
                click("projects")
                executed = export_document("after-pending-block-run")
                assert executed["graph"] == saved["graph"], "Running pending blocks changed the authored graph"
                assert executed["source"].endswith("sleep(0.3)"), "Run code did not apply the visible pending block value"
                checks.append("Run code applies pending blocks without requiring a separate Apply action")
                click("close_projects")
                click("run_mode")
                click("wiring_tab")
                capture("10-wiring-before")
                click("wire_disconnect_first")
                click("wire_pin")
                # Mouse-opened Godot menus start without keyboard item focus.
                # Navigate past the freed original pin to the next free pin, 10.
                for _ in range(2):
                    page.keyboard.press("ArrowDown")
                    page.evaluate("() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))")
                page.keyboard.press("Enter")
                page.evaluate("() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))")
                click("wire_connect")
                capture("11-wiring-after")
                click("projects")
                rewired = export_document("after-rewire")
                assert rewired["graph"]["parts"] == saved["graph"]["parts"], "Electrical rewiring moved or rotated an assembled part"
                old_links, new_links = saved["graph"]["links"], rewired["graph"]["links"]
                removed = [link for link in old_links if link not in new_links]
                added = [link for link in new_links if link not in old_links]
                assert len(removed) == len(added) == 1, "Rewiring must replace exactly one electrical connection"
                first_signal = next(link for link in old_links if "signal_pin" in (link["a_port"], link["b_port"]))
                assert removed == [first_signal] and "pin_10" in (added[0]["a_port"], added[0]["b_port"]), "Selected pin was not reflected in the graph"
                assert added[0]["a_part"] == first_signal["a_part"] and added[0]["a_port"] == first_signal["a_port"], "Rewiring changed the selected motor endpoint"
                checks.append("Wiring controls move the selected motor signal to pin 10 while preserving every part transform")
                click("close_projects")
                page.keyboard.press("Control+z")
                # Keyboard acknowledgement can precede Godot's input frame.
                page.evaluate("() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))")
                click("projects")
                undone = export_document("after-wire-undo")
                assert len(undone["graph"]["links"]) == len(old_links) - 1, "Undo did not remove the newly connected wire"
                click("close_projects")
                page.keyboard.press("Control+Shift+z")
                page.evaluate("() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))")
                click("projects")
                redone = export_document("after-wire-redo")
                assert redone["graph"] == rewired["graph"], "Redo did not restore the chosen wire and original transforms"
                checks.append("Actual keyboard Undo/Redo restores electrical edits in the exported graph")
                click("close_projects")
                page.set_viewport_size({"width": 1152, "height": 577})
                capture("12-compact-workshop")
                checks.append("Rendered Blocks/Wiring tabs and compact 1152×577 workshop captured for review")
                errors = [entry for entry in logs if entry["type"] == "error" or entry["text"].startswith(("ERROR:", "SCRIPT ERROR:"))]
                assert not errors, f"Browser reported errors: {errors}"
                result.update(passed=True, errors=errors, browser=browser.version)
                print(f"Browser authoring checks passed: {output}")
            except BaseException as error:
                result["failure"] = f"{type(error).__name__}: {error}"
                persist()
                print(traceback.format_exc(), flush=True)
                try:
                    capture_view(page, output / "failure.png")
                except Exception:
                    pass  # A browser crash can prevent screenshots; preserve the original failure.
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
