#!/usr/bin/env python3
"""Merge equivalent findings from chunked documentation-review reports."""

from __future__ import annotations

import re
import sys
from collections import OrderedDict
from pathlib import Path


SEVERITIES = {"Critical", "Major", "Minor"}


def split_row(line: str) -> list[str] | None:
    """Return the five cells from a Markdown finding row."""
    if not re.match(r"^\|\s*\d+\s*\|", line):
        return None
    cells = re.split(r"(?<!\\)\|", line.strip())[1:-1]
    if len(cells) != 5:
        raise ValueError(f"finding row has {len(cells)} cells instead of 5: {line}")
    return [cell.strip() for cell in cells]


def normalized(value: str) -> str:
    return " ".join(value.split())


def merge(paths: list[Path]) -> list[list[str]]:
    # The policy defines a repeated finding by its rule and correction. Keep
    # severity in the key so inconsistent model classifications remain visible.
    findings: OrderedDict[tuple[str, str, str], list[str]] = OrderedDict()
    originals: dict[tuple[str, str, str], list[str]] = {}

    for path in paths:
        for line in path.read_text().splitlines():
            cells = split_row(line)
            if cells is None:
                continue
            _, guideline, severity_cell, original, correction = cells
            severity = severity_cell.strip("* ")
            if severity not in SEVERITIES:
                raise ValueError(f"unsupported finding severity {severity_cell!r} in {path}")
            key = (normalized(guideline), severity, normalized(correction))
            if key not in findings:
                findings[key] = ["", guideline, severity_cell, original, correction]
                originals[key] = [original]
            elif original not in originals[key]:
                originals[key].append(original)
                findings[key][3] = "<br>".join(originals[key])

    return list(findings.values())


def main(argv: list[str]) -> int:
    severity_only = len(argv) > 1 and argv[1] == "--severities"
    names = argv[2:] if severity_only else argv[1:]
    try:
        rows = merge([Path(name) for name in names])
    except (OSError, ValueError) as exc:
        print(f"merge-review-findings: {exc}", file=sys.stderr)
        return 1
    for number, row in enumerate(rows, 1):
        if severity_only:
            print(row[2].strip("* "))
            continue
        row[0] = str(number)
        print("| " + " | ".join(row) + " |")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
