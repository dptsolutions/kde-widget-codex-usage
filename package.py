#!/usr/bin/env python3
"""Build self-contained Plasma 5 and 6 packages."""

from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile


ROOT = Path(__file__).resolve().parent
DIST = ROOT / "dist"


def build(version: int) -> Path:
    package = ROOT / f"plasma{version}"
    (package / "contents/code/codex_usage.py").write_bytes((ROOT / "codex_usage.py").read_bytes())
    DIST.mkdir(exist_ok=True)
    archive = DIST / f"codex-usage-plasma{version}.plasmoid"
    with ZipFile(archive, "w", ZIP_DEFLATED) as output:
        for path in sorted(package.rglob("*")):
            if path.is_file():
                output.write(path, path.relative_to(package))
    return archive


if __name__ == "__main__":
    for version in (5, 6):
        print(build(version))
