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
- So do pages marked `noindex: true` (Google advises against combining noindex with canonical),
  and sidebar pages whose counterpart is hidden from the current version's sidebar.
- Pages listed in .shared-docs-manifest.json are skipped: they are generated from docs-collate's
  shared/ by its sync, which writes their canonical with the same rules.

It then writes sitemap.xml at the repo root, which overrides Mintlify's generated sitemap, listing
only the sidebar pages search engines should index: no canonical pointing elsewhere, and not
`noindex` or `hidden`. Without it the sitemap lists every version and contradicts the canonicals.

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
NOINDEX_LINE = re.compile(r"^noindex:\s*true\s*$", re.MULTILINE)
HIDDEN_LINE = re.compile(r"^(noindex|hidden):\s*true\s*$", re.MULTILINE)


INDEX_SUFFIX = "/index"


def strip_index(slug):
    return slug[: -len(INDEX_SUFFIX)] if slug.endswith(INDEX_SUFFIX) else slug


def page_slug(version, rel):
    """Site path of a page, as docs.json navigation and URLs write it (no extension or /index)."""
    return strip_index(f"{version}/{rel.with_suffix('').as_posix()}")


def nav_strings(node):
    """Yield every string in a navigation tree's lists (page entries); dict scalars are labels."""
    if isinstance(node, str):
        yield node
    elif isinstance(node, list):
        for item in node:
            yield from nav_strings(item)
    elif isinstance(node, dict):
        for value in node.values():
            if isinstance(value, (list, dict)):
                yield from nav_strings(value)


def sidebar_pages(docs):
    """Map each version to the set of page slugs listed anywhere in its navigation."""
    return {
        v["version"]: {strip_index(page) for page in nav_strings(v)}
        for v in docs["navigation"]["versions"]
    }


def set_canonical(path, url):
    """Write or clear the page's canonical line; return "set", "removed", or None if unchanged."""
    text = path.read_text()
    end = text.find("\n---", 3)
    if not text.startswith("---") or end == -1:
        print(f"skipped (no frontmatter): {path.relative_to(ROOT)}")
        return None
    frontmatter = CANONICAL_LINE.sub("", text[: end + 1])
    if NOINDEX_LINE.search(frontmatter):
        url = None
    if url:
        frontmatter += f'canonical: "{url}"\n'
    updated = frontmatter + text[end + 1 :]
    if updated == text:
        return None
    path.write_text(updated)
    return "set" if url else "removed"


def latest_version(docs):
    for redirect in docs.get("redirects", []):
        if redirect["source"] == "/latest/:slug*":
            return redirect["destination"].strip("/").split("/")[0]
    sys.exit("no /latest/:slug* redirect in docs.json; pass the version explicitly")


def canonical_url(version, current, rel, sidebars):
    if version == current or not (ROOT / current / rel).exists():
        return None
    target = page_slug(current, rel)
    # A page readers can navigate to shouldn't defer to one they can't.
    if page_slug(version, rel) in sidebars.get(version, ()) and target not in sidebars.get(current, ()):
        return None
    return f"{BASE_URL}/{target}"


def generated_pages():
    """Files the docs-collate sync owns, relative to the repo root."""
    manifest = ROOT / ".shared-docs-manifest.json"
    return set(json.loads(manifest.read_text())["files"]) if manifest.exists() else set()


def sync_version(version, current, sidebars, generated):
    pointed = cleared = 0
    pages = (p for p in sorted((ROOT / version).rglob("*.md*")) if p.suffix in (".md", ".mdx"))
    for path in pages:
        if path.relative_to(ROOT).as_posix() in generated:
            continue
        url = canonical_url(version, current, path.relative_to(ROOT / version), sidebars)
        change = set_canonical(path, url)
        if change == "set":
            pointed += 1
        elif change == "removed":
            cleared += 1
    print(f"{version}: {pointed} canonicals set, {cleared} removed")


def page_file(slug):
    for candidate in (f"{slug}.mdx", f"{slug}.md", f"{slug}/index.mdx", f"{slug}/index.md"):
        if (ROOT / candidate).is_file():
            return ROOT / candidate
    return None


def frontmatter_of(path):
    text = path.read_text()
    end = text.find("\n---", 3)
    return text[:end] if text.startswith("---") and end != -1 else ""


def write_sitemap(versions, sidebars):
    urls = []
    for version in versions:
        for slug in sorted(sidebars.get(version, ())):
            path = page_file(slug) if slug.startswith(f"{version}/") or slug == version else None
            if not path:
                continue
            frontmatter = frontmatter_of(path)
            if not CANONICAL_LINE.search(frontmatter + "\n") and not HIDDEN_LINE.search(frontmatter):
                urls.append(f"{BASE_URL}/{slug}")
    entries = "".join(f"  <url>\n    <loc>{url}</loc>\n  </url>\n" for url in urls)
    (ROOT / "sitemap.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        f"{entries}</urlset>\n"
    )
    print(f"sitemap.xml: {len(urls)} pages")


def main():
    if len(sys.argv) > 2:
        sys.exit("usage: set-canonicals.py [current-version]  (e.g. v2.0.x)")
    docs = json.loads((ROOT / "docs.json").read_text())
    current = sys.argv[1] if len(sys.argv) == 2 else latest_version(docs)
    print(f"current version: {current}")
    if not (ROOT / current).is_dir():
        sys.exit(f"no such version folder: {current}")

    sidebars = sidebar_pages(docs)
    versions = sorted(d.name for d in ROOT.iterdir() if d.is_dir() and VERSION_DIR.match(d.name))
    generated = generated_pages()
    for version in versions:
        sync_version(version, current, sidebars, generated)
    write_sitemap(versions, sidebars)


if __name__ == "__main__":
    main()
