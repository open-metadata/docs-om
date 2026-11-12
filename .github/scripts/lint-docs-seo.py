#!/usr/bin/env python3
"""SEO and redirect lint for docs-om.

Checks (each can be run alone with --check NAME; default is all):

  redirects     every redirect destination exists, and every existing page
                under a wildcard source maps to an existing page
  moved-pages   (needs --base REF) a page removed or renamed since REF in a
                live version must have a redirect for its old path
  frontmatter   pages in the current version need a title and description,
                and titles and descriptions must be unique per version
  duplicates    two pages in the same version must not have the same body
  near-duplicates  a page added since --base must not share 80% or more of its
                text with another page in the same version. Existing pairs are
                only listed as warnings, so they never block unrelated edits

Live versions and the current version come from release.config.json.
Exit code 1 if any check fails. Standard library only.

Usage:
  python3 .github/scripts/lint-docs-seo.py
  python3 .github/scripts/lint-docs-seo.py --check moved-pages --base origin/main
"""
import argparse
import hashlib
import json
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
CFG = json.loads((ROOT / "release.config.json").read_text())
LIVE = [v["dir"] for v in CFG["versions"]]
CURRENT = CFG["defaultVersionDir"]

# Pages that legitimately share a title/description or body (add paths here
# with a reason, relative to the repo root without extension).
ALLOW_DUPLICATE = set()

# Versions held to the frontmatter and duplicate-content rules: the current
# version plus pre-release ones. Older versions are legacy and only get
# redirect checks.
CHECKED = [v for v in LIVE if v == CURRENT or v.endswith("-SNAPSHOT")]


def to_route(rel):
    """v2.0.x/foo/index.mdx -> /v2.0.x/foo ; v2.0.x/foo.mdx -> /v2.0.x/foo"""
    p = "/" + re.sub(r"\.mdx?$", "", rel)
    return p[: -len("/index")] if p.endswith("/index") else p


def version_pages():
    pages = {}
    for v in LIVE:
        for f in sorted((ROOT / v).rglob("*.md*")):
            if f.suffix in (".md", ".mdx"):
                pages[to_route(str(f.relative_to(ROOT)))] = f
    return pages


def split_frontmatter(text):
    m = re.match(r"^---\n(.*?)\n---\n?(.*)$", text, re.S)
    if not m:
        return {}, text
    fm = {}
    for line in m.group(1).splitlines():
        k = re.match(r"^([A-Za-z][\w-]*):\s*(.*)$", line)
        if k:
            fm[k.group(1)] = k.group(2).strip().strip("\"'")
    return fm, m.group(2)


def load_redirects():
    return json.loads((ROOT / "docs.json").read_text()).get("redirects", [])


def wildcard_map(rule, route):
    """Map a page route through a `/prefix/:slug*` rule, or None."""
    src, dst = rule["source"], rule["destination"]
    if not src.endswith("/:slug*"):
        return None
    prefix = src[: -len(":slug*")]
    if not route.startswith(prefix):
        return None
    slug = route[len(prefix):]
    return dst.replace(":slug*", slug) if dst.endswith(":slug*") else dst


def check_redirects(pages, redirects):
    errs = []
    routes = set(pages)
    live_roots = {f"/{v}" for v in LIVE}
    for r in redirects:
        src, dst = r["source"], r["destination"]
        if dst.startswith("http"):
            continue
        if ":slug*" in dst:
            continue
        target = dst.split("#")[0].split("?")[0].rstrip("/") or "/"
        if target not in routes and target not in live_roots:
            errs.append(f"redirect destination missing: {src} -> {dst}")
    # The first matching rule wins, so only that rule's target must exist.
    for route in sorted(routes):
        for r in redirects:
            if r["source"] == route:
                break
            mapped = wildcard_map(r, route)
            if mapped is None:
                continue
            if ":slug*" not in mapped and mapped.split("#")[0] not in routes:
                errs.append(
                    f"page under wildcard maps to a missing page: {route} -> {mapped} (rule {r['source']})"
                )
            break
    errs += check_wildcard_bases(pages, redirects)
    return errs


def redirect_covers(redirects, route):
    for r in redirects:
        if r["source"] == route:
            return True
        if wildcard_map(r, route) is not None:
            return True
    return False


def check_wildcard_bases(pages, redirects):
    """`/a/:slug*` may or may not match bare `/a`; require an explicit rule."""
    errs = []
    exact = {r["source"] for r in redirects}
    for r in redirects:
        if r["source"].endswith("/:slug*"):
            base = r["source"][: -len("/:slug*")]
            if base in pages and base not in exact:
                errs.append(f"page at the base of wildcard {r['source']} needs its own redirect: {base}")
    return errs


def check_moved(pages, redirects, base):
    errs = []
    # Compares the working tree to BASE, so it also sees uncommitted changes.
    out = subprocess.run(
        ["git", "diff", "--name-status", "-M", base, "--", *LIVE],
        cwd=ROOT, capture_output=True, text=True,
    )
    if out.returncode != 0:
        return [f"git diff against {base} failed: {out.stderr.strip()}"]
    for line in out.stdout.splitlines():
        parts = line.split("\t")
        status = parts[0]
        if status.startswith("D") or status.startswith("R"):
            old = parts[1]
            if not old.endswith((".md", ".mdx")):
                continue
            route = to_route(old)
            if route in pages:  # path still served (e.g. .md -> .mdx)
                continue
            if not redirect_covers(redirects, route):
                errs.append(f"page removed or renamed without a redirect: {route}")
    return errs


def check_frontmatter(pages, redirects):
    errs = []
    for v in CHECKED:
        titles, descs = defaultdict(list), defaultdict(list)
        for route, f in pages.items():
            if not route.startswith(f"/{v}/") or str(f.relative_to(ROOT)) in ALLOW_DUPLICATE:
                continue
            if redirect_covers(redirects, route):  # never served
                continue
            fm, _ = split_frontmatter(f.read_text())
            if fm.get("noindex") in ("true", "True"):
                continue
            if fm.get("title"):
                titles[fm["title"]].append(route)
            elif v == CURRENT:
                errs.append(f"missing title: {route}")
            if fm.get("description"):
                descs[fm["description"]].append(route)
            elif v == CURRENT:
                errs.append(f"missing description: {route}")
        for kind, d in (("title", titles), ("description", descs)):
            for text, rs in d.items():
                if len(rs) > 1:
                    errs.append(f"duplicate {kind} in {v} ({len(rs)} pages): {text[:70]!r}: " + ", ".join(sorted(rs)[:4]))
    return errs


def check_duplicates(pages, redirects):
    errs = []
    for v in CHECKED:
        seen = defaultdict(list)
        for route, f in pages.items():
            if not route.startswith(f"/{v}/") or redirect_covers(redirects, route):
                continue
            fm, body = split_frontmatter(f.read_text())
            if fm.get("noindex") in ("true", "True"):
                continue
            norm = re.sub(r"\s+", " ", body).strip()
            if len(norm) < 200:
                continue
            seen[hashlib.sha1(norm.encode()).hexdigest()].append(route)
        for rs in seen.values():
            if len(rs) > 1:
                errs.append(f"identical body in {v}: " + ", ".join(sorted(rs)))
    return errs


NEAR_DUPLICATE_THRESHOLD = 0.8
MIN_WORDS = 60  # shorter pages share too many phrases by chance
MAX_PAGES_PER_PHRASE = 60  # skip boilerplate phrases found on many pages


def added_routes(base):
    out = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=AR", "-M", base, "--", *LIVE],
        cwd=ROOT, capture_output=True, text=True,
    )
    return {to_route(l) for l in out.stdout.splitlines() if l.endswith((".md", ".mdx"))}


def check_near_duplicates(pages, redirects, base):
    """Compare pages by shared 4-word phrases (Jaccard). Returns (errors, warnings)."""
    errs, warns = [], []
    new = added_routes(base) if base else set()
    for v in CHECKED:
        phrases = {}
        for route, f in pages.items():
            if not route.startswith(f"/{v}/") or redirect_covers(redirects, route):
                continue
            fm, body = split_frontmatter(f.read_text())
            if fm.get("noindex") in ("true", "True"):
                continue
            words = re.findall(r"[a-z0-9]+", re.sub(r"```.*?```", " ", body, flags=re.S).lower())
            if len(words) >= MIN_WORDS:
                phrases[route] = {" ".join(words[i:i + 4]) for i in range(len(words) - 3)}
        index = defaultdict(list)
        for route, ps in phrases.items():
            for p in ps:
                index[p].append(route)
        shared = defaultdict(int)
        for routes in index.values():
            if 1 < len(routes) <= MAX_PAGES_PER_PHRASE:
                for i in range(len(routes)):
                    for j in range(i + 1, len(routes)):
                        shared[(routes[i], routes[j])] += 1
        for (a, b), n in sorted(shared.items()):
            score = n / (len(phrases[a]) + len(phrases[b]) - n)
            if score < NEAR_DUPLICATE_THRESHOLD:
                continue
            msg = f"{score:.0%} of text shared in {v}: {a} and {b}"
            (errs if (a in new or b in new) else warns).append(msg)
    return errs, warns


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="append", choices=["redirects", "moved-pages", "frontmatter", "duplicates", "near-duplicates"])
    ap.add_argument("--base", help="git ref to compare against for moved-pages")
    a = ap.parse_args()
    checks = a.check or ["redirects", "moved-pages", "frontmatter", "duplicates", "near-duplicates"]
    pages, redirects = version_pages(), load_redirects()
    failed = False
    for c in checks:
        if c == "moved-pages" and not a.base:
            print("moved-pages: skipped (no --base)")
            continue
        if c == "near-duplicates":
            errs, warns = check_near_duplicates(pages, redirects, a.base)
            print(f"{c}: {'OK' if not errs else str(len(errs)) + ' problem(s)'}"
                  + (f" ({len(warns)} existing pair(s), warning only)" if warns else ""))
            for e in errs:
                print(f"  - {e}")
            for w in warns:
                print(f"  ~ {w}")
            failed |= bool(errs)
            continue
        errs = {
            "redirects": lambda: check_redirects(pages, redirects),
            "moved-pages": lambda: check_moved(pages, redirects, a.base),
            "frontmatter": lambda: check_frontmatter(pages, redirects),
            "duplicates": lambda: check_duplicates(pages, redirects),
        }[c]()
        print(f"{c}: {'OK' if not errs else str(len(errs)) + ' problem(s)'}")
        for e in errs:
            print(f"  - {e}")
        failed |= bool(errs)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
