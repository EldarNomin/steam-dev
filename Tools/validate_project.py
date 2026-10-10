"""Repository checks only. This does not compile C# or run Unity."""

import argparse
import json
import re
import sys
from pathlib import Path


def code_mentions_unity_editor(source: str) -> bool:
    """True when UnityEditor appears in actual code, not in comments."""

    def strip_line_comment(line: str) -> str:
        # Drop // comments while respecting quoted strings (e.g. "https://").
        parts = line.split('"')
        kept = []
        for index, part in enumerate(parts):
            if index % 2 == 1:  # inside a quoted string: keep verbatim
                kept.append(part)
                continue
            comment = part.find("//")
            kept.append(part if comment < 0 else part[:comment])
            if comment >= 0:
                break
        return "".join(kept)

    without_block_comments = re.sub(r"/\*.*?\*/", " ", source, flags=re.DOTALL)
    code_lines = [strip_line_comment(line) for line in without_block_comments.splitlines()]
    return re.search(r"\bUnityEditor\b", "\n".join(code_lines)) is not None


def validate(root: Path, syntax: bool) -> list[str]:
    failures = []
    assets = root / "Assets"
    for required in (assets, root / "Packages/manifest.json", root / "ProjectSettings/ProjectVersion.txt"):
        if not required.exists():
            failures.append(f"Missing project marker: {required.relative_to(root)}")
    if failures:
        return failures

    for path in [*(root / "Packages").glob("*.json"), *assets.rglob("*.asmdef")]:
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except (ValueError, OSError) as error:
            failures.append(f"Invalid JSON: {path.relative_to(root)}: {error}")

    guid_paths = {}
    for path in sorted(assets.rglob("*")):
        if path.suffix == ".meta":
            source = path.with_suffix("")
            if not source.exists():
                failures.append(f"Orphan metadata: {path.relative_to(root)}")
            match = re.search(r"^guid: ([0-9a-f]{32})$", path.read_text(encoding="utf-8"), re.MULTILINE)
            if not match:
                failures.append(f"Invalid GUID: {path.relative_to(root)}")
                continue
            guid = match.group(1)
            if guid in guid_paths:
                failures.append(f"Duplicate GUID: {path.relative_to(root)} and {guid_paths[guid]}")
            guid_paths[guid] = path.relative_to(root)
        elif not path.with_name(path.name + ".meta").exists():
            failures.append(f"Missing metadata: {path.relative_to(root)}")

    assemblies = {}
    for path in assets.rglob("*.asmdef"):
        try:
            definition = json.loads(path.read_text(encoding="utf-8"))
            name = definition["name"]
            if name in assemblies:
                failures.append(f"Duplicate assembly name: {name}")
            assemblies[name] = definition
            if "/Editor/" in path.as_posix() and definition.get("includePlatforms") != ["Editor"]:
                failures.append(f"Editor assembly is not isolated: {path.relative_to(root)}")
        except (ValueError, KeyError):
            continue

    package_assemblies = {
        "Unity.RenderPipelines.Core.Runtime",
        "Unity.RenderPipelines.Universal.Runtime",
        "Unity.InputSystem",
    }
    for name, definition in assemblies.items():
        for reference in definition.get("references", []):
            if reference not in assemblies and reference not in package_assemblies:
                failures.append(f"Review unrecognized assembly reference: {name} -> {reference}")
    for path in (assets / "_Game/Runtime").rglob("*.cs"):
        if code_mentions_unity_editor(path.read_text(encoding="utf-8")):
            failures.append(f"Runtime depends on UnityEditor: {path.relative_to(root)}")

    documents = [root / "README.md", *(root / "Docs").rglob("*.md")]
    for path in documents:
        for target in re.findall(r"\[[^\]]*\]\(([^)]+)\)", path.read_text(encoding="utf-8")):
            if "://" in target or target.startswith("#"):
                continue
            target = target.split("#", 1)[0]
            if target and not (path.parent / target).exists():
                failures.append(f"Broken document link: {path.relative_to(root)} -> {target}")

    if syntax:
        try:
            from tree_sitter import Language, Parser
            import tree_sitter_c_sharp
        except ImportError:
            failures.append("C# parser unavailable. Install Tools/requirements-validation.txt or omit --syntax.")
            return failures
        parser = Parser(Language(tree_sitter_c_sharp.language()))
        for path in assets.rglob("*.cs"):
            if parser.parse(path.read_bytes()).root_node.has_error:
                failures.append(f"C# syntax error: {path.relative_to(root)}")
    return failures


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--syntax", action="store_true", help="Also parse C# syntax using tree-sitter.")
    args = parser.parse_args()
    failures = validate(Path(__file__).resolve().parents[1], args.syntax)
    if failures:
        print("Repository checks: FAIL")
        for failure in failures:
            print(f"- {failure}")
        return 1
    print("Repository checks: PASS" + ("; C# syntax: PASS" if args.syntax else ""))
    print("Unity compilation, import, Play Mode and Windows build: NOT RUN")
    return 0


if __name__ == "__main__":
    sys.exit(main())
