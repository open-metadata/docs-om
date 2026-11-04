#!/usr/bin/env python3
"""Point every non-current version's pages at the current version via a `canonical` frontmatter tag.

The current version is read from the `/latest/:slug*` redirect in docs.json, so after that
redirect moves (bump-latest-version.yml), running this with no arguments re-points everything:

    python3 .github/scripts/set-canonicals.py           # version from docs.json
    python3 .github/scripts/set-canonicals.py v2.1.x    # explicit override

Runs automatically from bump-latest-version.yml and sync-canonicals.yml.

- Pages in other version folders whose path also exists in the current version get
  `canonical: "https://docs.open-metadata.org/<current>/<path>"`.
- Pages with no counterpart in the current version, and all pages of the current version,
  have any `canonical` line removed so they fall back to Mintlify's self-referencing canonical.

The script is idempotent; re-running it with the same version changes nothing.
"""
import json
import re
import sys
from pathlib import Path

BASE_URL = "https://docs.open-metadata.org"
ROOT = Path(__file__).resolve().parent.parent.parent
VERSION_DIR = re.compile(r"^v\d+\.\d+\.x(-SNAPSHOT)?$")
CANONICAL_LINE = re.compile(r"^canonical:.*\n", re.MULTILINE)


def page_url(version, rel):
    slug = rel.with_suffix("").as_posix()
    if slug == "index":
        return f"{BASE_URL}/{version}"
    if slug.endswith("/index"):
        slug = slug[: -len("/index")]
    return f"{BASE_URL}/{version}/{slug}"


def set_canonical(path, url):
    text = path.read_text()
    end = text.find("\n---", 3)
    if not text.startswith("---") or end == -1:
        print(f"skipped (no frontmatter): {path.relative_to(ROOT)}")
        return False
    frontmatter = CANONICAL_LINE.sub("", text[: end + 1])
    if url:
        frontmatter += f'canonical: "{url}"\n'
    updated = frontmatter + text[end + 1 :]
    if updated == text:
        return False
    path.write_text(updated)
    return True


def latest_version():
    docs = json.loads((ROOT / "docs.json").read_text())
    for redirect in docs.get("redirects", []):
        if redirect["source"] == "/latest/:slug*":
            return redirect["destination"].strip("/").split("/")[0]
    sys.exit("no /latest/:slug* redirect in docs.json; pass the version explicitly")


def sync_version(version, current):
    pointed = cleared = 0
    pages = (p for p in sorted((ROOT / version).rglob("*.md*")) if p.suffix in (".md", ".mdx"))
    for path in pages:
        rel = path.relative_to(ROOT / version)
        has_counterpart = version != current and (ROOT / current / rel).exists()
        url = page_url(current, rel) if has_counterpart else None
        if not set_canonical(path, url):
            continue
        if url:
            pointed += 1
        else:
            cleared += 1
    print(f"{version}: {pointed} canonicals set, {cleared} removed")


def main():
    if len(sys.argv) > 2:
        sys.exit("usage: set-canonicals.py [current-version]  (e.g. v2.0.x)")
    current = sys.argv[1] if len(sys.argv) == 2 else latest_version()
    print(f"current version: {current}")
    if not (ROOT / current).is_dir():
        sys.exit(f"no such version folder: {current}")

    versions = sorted(d.name for d in ROOT.iterdir() if d.is_dir() and VERSION_DIR.match(d.name))
    for version in versions:
        sync_version(version, current)


if __name__ == "__main__":
    main()
