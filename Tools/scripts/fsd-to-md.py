#!/usr/bin/env python3
"""Convert a .docx FSD to a .md file using pandoc.

Usage:
    python fsd-to-md.py <path-to-docx>

Output: same directory, same name, .md extension.
"""
import subprocess
import sys
from pathlib import Path


def convert(docx_path: str) -> None:
    src = Path(docx_path).resolve()
    if not src.exists():
        print(f"Error: file not found — {src}")
        sys.exit(1)
    if src.suffix.lower() != ".docx":
        print(f"Error: expected a .docx file, got {src.suffix}")
        sys.exit(1)

    out = src.with_suffix(".md")
    result = subprocess.run(
        ["pandoc", str(src), "-t", "markdown", "--wrap=none", "-o", str(out)],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"pandoc error:\n{result.stderr}")
        sys.exit(result.returncode)

    print(f"Converted → {out}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python fsd-to-md.py <path-to-docx>")
        sys.exit(1)
    convert(sys.argv[1])
