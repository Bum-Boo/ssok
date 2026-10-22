#!/usr/bin/env python3
"""Optionally render documentation Mermaid blocks with an explicitly supplied local bundle."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mermaid-js", type=Path, required=True)
    parser.add_argument("--renderer-version", required=True)
    parser.add_argument("--output", type=Path, default=Path("build/docs-diagrams"))
    parser.add_argument("--browser-executable")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print("Optional renderer requires Playwright; documentation checks do not.", file=sys.stderr)
        return 2
    if not args.mermaid_js.is_file():
        print("Missing local Mermaid JavaScript bundle", file=sys.stderr)
        return 2
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    records = []
    bundle_hash = hashlib.sha256(args.mermaid_js.read_bytes()).hexdigest()
    with sync_playwright() as playwright:
        launch = {"headless": True, "args": ["--disable-dev-shm-usage"]}
        if args.browser_executable:
            launch["executable_path"] = args.browser_executable
        browser = playwright.chromium.launch(**launch)
        try:
            page = browser.new_page(viewport={"width": 1600, "height": 1100}, device_scale_factor=1)
            page.set_content('<html><head><style>body{background:white;margin:20px}#mount{width:1500px}svg{max-width:100%}</style></head><body><div id="mount"></div></body></html>')
            page.add_script_tag(path=str(args.mermaid_js.resolve()))
            page.evaluate('mermaid.initialize({startOnLoad:false,securityLevel:"strict",theme:"default",fontFamily:"Arial,Noto Sans CJK KR,sans-serif"})')
            for name in ("docs/DATA_MODEL.md", "docs/FLOWS.md"):
                content = (root / name).read_text(encoding="utf-8")
                for index, source in enumerate(re.findall(r"```mermaid\n(.*?)\n```", content, re.S), 1):
                    stem = Path(name).stem.lower() + "-" + str(index)
                    result = page.evaluate('''async ({source,id}) => {
                        try {
                            const result = await mermaid.render(id, source);
                            document.querySelector('#mount').innerHTML = result.svg;
                            return {ok:true,svg:result.svg};
                        } catch (error) { return {ok:false,error:String(error)}; }
                    }''', {"source": source, "id": "diagram_" + stem.replace("-", "_")})
                    record = {"document": name, "block": index,
                              "source_sha256": hashlib.sha256(source.encode()).hexdigest(),
                              "renderer": args.renderer_version, "bundle_sha256": bundle_hash,
                              "ok": result["ok"]}
                    if result["ok"]:
                        (output / (stem + ".svg")).write_text(result["svg"], encoding="utf-8")
                        page.locator("#mount").screenshot(path=str(output / (stem + ".png")))
                        record["svg"] = stem + ".svg"
                    else:
                        record["error"] = result["error"]
                    records.append(record)
        finally:
            browser.close()
    (output / "render.json").write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    good = sum(bool(record["ok"]) for record in records)
    print(f"Rendered {good}/{len(records)} Mermaid blocks to {output}")
    return 0 if records and good == len(records) else 1


if __name__ == "__main__":
    raise SystemExit(main())
