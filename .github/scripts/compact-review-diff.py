#!/usr/bin/env python3
"""Collapse exact MDX patches for the same page in different version trees.

Only ordinary, unquoted, same-path text patches qualify. Hunk positions,
context, and all changed text must match. Original diffs remain available
for hashing, incremental matching, and reference reads.
"""

import json
import re
import sys


def page_key(path):
    parts = path.split("/", 1)
    if len(parts) == 2 and re.fullmatch(r"v\d+\.\d+\.x(?:-SNAPSHOT)?|ai-\d+-\d+", parts[0]):
        return parts[1], parts[0]
    return path, "root"


def compact(text):
    blocks = re.split(r"(?=^diff --git )", text, flags=re.MULTILINE)
    entries = []
    groups = {}
    for block in blocks:
        match = re.match(r"diff --git a/([^\s\"]+) b/([^\s\"]+)\n", block)
        if not match or match[1] != match[2] or not match[2].endswith(".mdx"):
            entries.append((block, None))
            continue
        path = match[2]
        if f"--- a/{path}\n+++ b/{path}\n" not in block or "@@ " not in block:
            entries.append((block, None))
            continue
        relative, version = page_key(path)
        signature = re.sub(r"^index [0-9a-f]+\.\.[0-9a-f]+(?: [0-7]+)?\n", "", block, flags=re.MULTILINE)
        signature = signature.replace(match[0], "diff --git PAGE\n", 1)
        signature = signature.replace(f"--- a/{path}\n+++ b/{path}\n", "--- PAGE\n+++ PAGE\n", 1)
        key = (relative, signature)
        group = groups.get(key)
        # Never merge separate pages within the same version tree.
        if group is not None and version not in group["versions"]:
            group["paths"].append(path)
            group["versions"].add(version)
        else:
            group = {"paths": [path], "versions": {version}}
            groups[key] = group
            entries.append((block, group))

    result = []
    for block, group in entries:
        if group and len(group["paths"]) > 1:
            marker = "# Identical versioned patches (same hunk lines and context): " + json.dumps(group["paths"]) + "\n"
            block = block.replace("+++ b/" + group["paths"][0] + "\n",
                                  "+++ b/" + group["paths"][0] + "\n" + marker, 1)
        result.append(block)
    return "".join(result)


if __name__ == "__main__":
    # Decode permissively: a diff can carry non-UTF-8 bytes (latin-1 source,
    # binary hunks), and a strict read would crash the whole review. Round-trip
    # the undecodable bytes unchanged through surrogateescape on the way out.
    text = sys.stdin.buffer.read().decode("utf-8", errors="surrogateescape")
    sys.stdout.buffer.write(compact(text).encode("utf-8", errors="surrogateescape"))
