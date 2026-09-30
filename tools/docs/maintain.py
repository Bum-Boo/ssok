#!/usr/bin/env python3
"""Generate contributor maps and detect unreviewed documentation contracts offline."""
from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote, urlsplit

REGISTRY = "docs/context.json"
MAP = "docs/generated/CODE_MAP.md"
ADR_INDEX = "docs/adr/INDEX.md"
ENTRY_LIMIT = 250
ROOTS = ("scenes", "src", "presets", "assets", "addons", "tests", "tools", ".github")


def contained(root: Path, name: str) -> Path:
    path = (root / name).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError(f"Path outside repository: {name}")
    return path


def read_registry(root: Path) -> dict:
    data = json.loads(contained(root, REGISTRY).read_text(encoding="utf-8"))
    if data.get("schema") != 1:
        raise ValueError("Unsupported documentation registry schema")
    for key in ("managed", "routes", "contracts"):
        if key not in data:
            raise ValueError(f"Missing registry field: {key}")
    return data


def own_scripts(root: Path) -> list[Path]:
    return sorted(p for folder in ("scenes", "src", "presets")
                  for p in (root / folder).rglob("*.gd") if p.is_file())


def code_map(root: Path) -> str:
    lines = ["# 파일 구조와 코드 위치", "",
             "자동 생성: `python3 tools/docs/maintain.py --write`. 이 checkout의 위치 지도이며 구현 검증 보고서가 아니에요.",
             "수정 진입점은 [START_HERE](../START_HERE.md), 데이터 관계는 [DATA_MODEL](../DATA_MODEL.md)를 읽어요.",
             "", "## 디렉터리 트리", "", "```text", "ssok/", "  project.godot", "  scenes/"]
    for path in sorted((root / "scenes").glob("*.gd")):
        lines.append(f"    {path.name}")
    lines.append("  src/")
    for folder in sorted((root / "src").iterdir()):
        if folder.is_dir():
            files = sorted(folder.rglob("*.gd"))
            lines.append(f"    {folder.name}/  ({len(files)} GDScript files)")
            if not files:
                lines.append("      (placeholder; inspect before assuming implementation)")
    for name in ROOTS[2:]:
        folder = root / name
        if not folder.exists():
            continue
        lines.append(f"  {name}/")
        for child in sorted(p for p in folder.iterdir() if p.is_dir()):
            if child.name not in ("__pycache__", "runs"):
                lines.append(f"    {child.name}/")
    lines.extend(["  docs/", "    START_HERE.md / STATUS.md", "    DATA_MODEL.md / FLOWS.md",
                  "    POLICIES.md / MAINTENANCE.md", "    context.json", "    adr/", "    generated/",
                  "    evidence/  (open only relevant reports)", "```", "",
                  "## 자체 GDScript 클래스 위치", "",
                  "서드파티 내부와 빌드 산출물은 펼치지 않아요. `.uid`는 클래스 본문이 아니에요.", "",
                  "| 파일 | 선언된 클래스 |", "|---|---|"])
    for path in own_scripts(root):
        match = re.search(r"^class_name\s+(\w+)", path.read_text(encoding="utf-8"), re.M)
        rel = path.relative_to(root).as_posix()
        lines.append(f"| [{rel}](../../{rel}) | {match.group(1) if match else '(scene script)'} |")
    lines.extend(["", "보드와 언어는 논리 계층이에요. 실제 BoardProfile은 `src/core/`, MiniRuntime은",
                  "`src/runtime/`에 있어요. `src/profiles/`의 폴더 존재만으로 구현을 판단하지 않아요.", ""])
    return "\n".join(lines)


def adr_index(root: Path) -> str:
    lines = ["# ADR 색인", "", "자동 생성: `python3 tools/docs/maintain.py --write`.",
             "전체 목록을 검토한 뒤 작업과 관련된 결정과 연결된 확장/대체 결정을 읽어요.",
             "상태는 원문을 그대로 보존해요. 일부 대체된 결정을 전부 폐기하지 않아요.", "",
             "| 결정 | 원문 상태와 확장/대체 주석 |", "|---|---|"]
    for path in sorted((root / "docs/adr").glob("[0-9][0-9][0-9][0-9]-*.md")):
        content = path.read_text(encoding="utf-8")
        title = content.splitlines()[0].removeprefix("# ")
        header = content.split("\n## ", 1)[0]
        notes = [line[2:] for line in header.splitlines()
                 if line.startswith("- ") and not line.startswith("- Date:")]
        status = "<br>".join(notes).replace("|", "\\|")
        lines.append(f"| [{title}]({path.name}) | {status} |")
    return "\n".join(lines) + "\n"


def without_fences(text: str) -> str:
    return re.sub(r"(?ms)^\s*(`{3,}|~{3,})[^\n]*\n.*?^\s*\1\s*$", "", text)


def link_errors(root: Path, names: list[str]) -> list[str]:
    errors = []
    for name in names:
        path = contained(root, name)
        if not path.is_file():
            errors.append(f"Missing managed document: {name}")
            continue
        content = without_fences(path.read_text(encoding="utf-8"))
        targets = re.findall(r"!?\[[^\]\n]*\]\((<[^>]+>|[^)\n]+)\)", content)
        targets += re.findall(r"(?m)^\s*\[[^\]]+\]:\s*(\S+)", content)
        for target in targets:
            target = target[1:-1] if target.startswith("<") else target.split(' "', 1)[0]
            parsed = urlsplit(target)
            if parsed.scheme or target.startswith(("#", "//")):
                continue
            if not parsed.path:
                continue
            destination = (path.parent / unquote(parsed.path)).resolve()
            if not destination.is_relative_to(root.resolve()) or not destination.exists():
                errors.append(f"Broken local link in {name}: {target}")
    return errors


def validate(root: Path, data: dict) -> list[str]:
    errors = []
    managed = list(data["managed"]) + [ADR_INDEX, MAP]
    managed += [p.relative_to(root).as_posix() for p in (root / "docs/adr").glob("[0-9]*.md")]
    errors.extend(link_errors(root, sorted(set(managed))))
    entry = ["AGENTS.md", "docs/START_HERE.md", "docs/STATUS.md"]
    size = sum(len(contained(root, name).read_text(encoding="utf-8").splitlines())
               for name in entry if contained(root, name).is_file())
    if size > ENTRY_LIMIT:
        errors.append(f"Entry context is {size} lines; limit {ENTRY_LIMIT}")
    for route, spec in data["routes"].items():
        for name in spec["docs"] + spec["sources"]:
            if not contained(root, name).is_file():
                errors.append(f"Missing {route} route file: {name}")
        for number in spec["adrs"]:
            if len(list((root / "docs/adr").glob(f"{number}-*.md"))) != 1:
                errors.append(f"Missing/ambiguous {route} ADR: {number}")
    for name, spec in data["symbols"].items():
        path = contained(root, name)
        if not path.is_file():
            errors.append(f"Missing symbol source: {name}")
            continue
        content = path.read_text(encoding="utf-8")
        if spec.get("class") and not re.search(r"^class_name\s+" + re.escape(spec["class"]) + r"\b", content, re.M):
            errors.append(f"Missing class {spec['class']}: {name}")
        for method in spec.get("methods", []):
            if not re.search(r"^(?:static )?func\s+" + re.escape(method) + r"\s*\(", content, re.M):
                errors.append(f"Missing method {method}: {name}")
    for ident, contract in data["contracts"].items():
        if not contained(root, contract["document"]).is_file():
            errors.append(f"Missing contract document: {contract['document']}")
        for name, expected in contract["sources"].items():
            path = contained(root, name)
            if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
                errors.append(f"Review {contract['document']} for changed {name}; after actual review use --review {ident}")
    for name, expected in ((MAP, code_map(root)), (ADR_INDEX, adr_index(root))):
        path = contained(root, name)
        if not path.exists() or path.read_text(encoding="utf-8") != expected:
            errors.append(f"Stale generated {name}; run --write")
    return errors


def review(root: Path, data: dict, identifiers: list[str]) -> None:
    for ident in identifiers:
        if ident not in data["contracts"]:
            raise ValueError(f"Unknown contract: {ident}")
    updates = {}
    for ident in identifiers:
        contract = data["contracts"][ident]
        updates[ident] = {name: hashlib.sha256(contained(root, name).read_bytes()).hexdigest()
                          for name in contract["sources"]}
    for ident, hashes in updates.items():
        data["contracts"][ident]["sources"] = hashes
    contained(root, REGISTRY).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def route_lines(root: Path, data: dict, name: str) -> list[str]:
    if name not in data["routes"]:
        raise ValueError(f"Unknown route {name}; choose {', '.join(data['routes'])}")
    route = data["routes"][name]
    lines = [f"Route: {name}", "Read: AGENTS.md, docs/START_HERE.md, docs/STATUS.md"]
    lines += [f"Document: {path}" for path in route["docs"]]
    lines += [f"Source: {path}" for path in route["sources"]]
    lines += [f"ADR: {p.relative_to(root).as_posix()}" for n in route["adrs"]
              for p in sorted((root / "docs/adr").glob(f"{n}-*.md"))]
    return lines


def impact(root: Path, data: dict, base: str) -> list[str]:
    if base.startswith("-"):
        raise ValueError("Base must be a Git revision, not an option")
    result = subprocess.run(["git", "diff", "--name-only", base, "--"], cwd=root,
                            capture_output=True, text=True, check=True)
    untracked = subprocess.run(["git", "ls-files", "--others", "--exclude-standard"], cwd=root,
                               capture_output=True, text=True, check=True)
    changed = sorted(set(result.stdout.splitlines() + untracked.stdout.splitlines()))
    lines = []
    for route, spec in data["routes"].items():
        hits = [name for name in changed if any(fnmatch.fnmatchcase(name, pat) for pat in spec["watch"])]
        if hits:
            lines.append(f"Review route {route}: {', '.join(spec['docs'])} ({len(hits)} changed files)")
    return lines or ["No registered source routes affected; still review direction, UI and evidence impact."]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--review", action="append", default=[], metavar="CONTRACT")
    parser.add_argument("--route")
    parser.add_argument("--base", help="Diff actual working tree against this Git revision")
    args = parser.parse_args(argv)
    root = args.root.resolve()
    try:
        data = read_registry(root)
        if args.route:
            print("\n".join(route_lines(root, data, args.route)))
        if args.review:
            review(root, data, args.review)
            print("Recorded explicit source review: " + ", ".join(args.review))
        if args.write:
            for name, body in ((MAP, code_map(root)), (ADR_INDEX, adr_index(root))):
                path = contained(root, name)
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(body, encoding="utf-8")
            print("Generated code map and ADR index")
        if args.base:
            print("\n".join(impact(root, data, args.base)))
        if args.check or not any((args.write, args.review, args.route, args.base)):
            errors = validate(root, data)
            if errors:
                print("\n".join(errors), file=sys.stderr)
                return 1
            print("Documentation checks passed (maps, links, routes, symbols, source reviews, entry size)")
        return 0
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        print(f"Documentation check error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
