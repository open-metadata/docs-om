#!/usr/bin/env python3
"""Weekly health report for the published docs site. Standard library only.

  sitemap   fetch every URL in sitemap.xml and report non-200 answers, redirects,
            canonicals that point elsewhere, noindex, and missing or duplicate
            titles and descriptions
  history   replay every page path that ever existed in git history, plus the
            /latest and unversioned forms, and report the ones that end on a 404

Writes a Markdown report to --out (default: docs-health-report.md) and prints a
one-line summary. Exit code is always 0 unless --fail-on-problems is given.

  python3 .github/scripts/docs-health-report.py --limit 40      # quick local run
  python3 .github/scripts/docs-health-report.py                  # full run
"""
import argparse
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
UA = "docs-om-health-report/1.0 (+https://github.com/open-metadata/docs-om)"


class NoFollow(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k):
        return None


class Head(HTMLParser):
    def __init__(self):
        super().__init__()
        self.title = ""
        self.canonical = None
        self.description = None
        self.robots = ""
        self._in_title = False

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "title":
            self._in_title = True
        elif tag == "link" and a.get("rel") == "canonical":
            self.canonical = a.get("href")
        elif tag == "meta":
            n = (a.get("name") or "").lower()
            if n == "description":
                self.description = a.get("content")
            elif n == "robots":
                self.robots = (a.get("content") or "").lower()

    def handle_endtag(self, tag):
        if tag == "title":
            self._in_title = False

    def handle_data(self, data):
        if self._in_title:
            self.title += data


def request(url, method="GET", follow=False, timeout=30):
    """Return (status, headers, body). Does not raise on HTTP errors."""
    opener = urllib.request.build_opener() if follow else urllib.request.build_opener(NoFollow)
    req = urllib.request.Request(url, method=method, headers={"User-Agent": UA})
    try:
        with opener.open(req, timeout=timeout) as r:
            body = r.read(400_000).decode("utf-8", "replace") if method == "GET" else ""
            return r.status, dict(r.headers), body
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers or {}), ""
    except Exception as e:  # network error, timeout
        return 0, {"error": str(e)}, ""


def final_status(url, max_hops=6):
    """Follow redirects manually; return (final_status, hops)."""
    for hops in range(max_hops + 1):
        st, h, _ = request(url, "HEAD")
        if st in (301, 302, 307, 308) and h.get("Location"):
            url = urllib.request.urljoin(url, h["Location"])
            continue
        return st, hops
    return -1, max_hops


def sitemap_urls(base):
    local = ROOT / "sitemap.xml"
    text = local.read_text() if local.exists() else request(f"{base}/sitemap.xml", follow=True)[2]
    return [e.text.strip() for e in ET.fromstring(text).iter() if e.tag.endswith("loc")]


def audit_page(url):
    st, h, body = request(url)
    row = {"url": url, "status": st}
    if st != 200:
        row["location"] = h.get("Location") or h.get("location") or h.get("error", "")
        return row
    p = Head()
    p.feed(body)
    row.update(
        title=p.title.strip(),
        description=(p.description or "").strip(),
        canonical=p.canonical,
        noindex="noindex" in p.robots or "noindex" in (h.get("X-Robots-Tag") or h.get("x-robots-tag") or "").lower(),
    )
    return row


def history_routes():
    out = subprocess.run(
        ["git", "log", "--all", "--no-renames", "--name-only", "--format=", "--", "v*"],
        cwd=ROOT, capture_output=True, text=True,
    ).stdout
    routes = set()
    for line in out.splitlines():
        if re.match(r"^v\d+\.\d+\.x(-SNAPSHOT)?/.*\.mdx?$", line):
            r = "/" + re.sub(r"\.mdx?$", "", line)
            routes.add(r[:-6] if r.endswith("/index") else r)
    return routes


def variants(route, current):
    yield route
    m = re.match(r"^/v\d+\.\d+\.x(?:-SNAPSHOT)?(/.*)?$", route)
    if m and m.group(1):
        yield "/latest" + m.group(1)
        yield m.group(1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="https://docs.open-metadata.org")
    ap.add_argument("--out", default="docs-health-report.md")
    ap.add_argument("--limit", type=int, default=0, help="only check the first N URLs of each list")
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--slack-out", default="", help="also write the Slack message payload (JSON, Block Kit) to this file")
    ap.add_argument("--skip-history", action="store_true")
    ap.add_argument("--fail-on-problems", action="store_true")
    a = ap.parse_args()
    base = a.base.rstrip("/")
    current = json.loads((ROOT / "release.config.json").read_text())["defaultVersionDir"]

    urls = sitemap_urls(base)
    if a.limit:
        urls = urls[: a.limit]
    with ThreadPoolExecutor(a.workers) as ex:
        rows = list(ex.map(audit_page, urls))

    problems = defaultdict(list)
    titles, descs = defaultdict(list), defaultdict(list)
    for r in rows:
        u = r["url"]
        if r["status"] != 200:
            problems["Sitemap URL does not answer 200"].append(f"{u} → {r['status']} {r.get('location', '')}")
            continue
        if r["noindex"]:
            problems["Sitemap URL is noindex"].append(u)
        if r["canonical"] and r["canonical"].rstrip("/") != u.rstrip("/"):
            problems["Canonical differs from the sitemap URL"].append(f"{u} → {r['canonical']}")
        if not r["title"]:
            problems["Missing title"].append(u)
        else:
            titles[r["title"]].append(u)
        if not r["description"]:
            problems["Missing description"].append(u)
        else:
            descs[r["description"]].append(u)
    for kind, d in (("title", titles), ("description", descs)):
        for text, us in d.items():
            if len(us) > 1:
                problems[f"Duplicate {kind}"].append(f"{text[:80]!r}: " + ", ".join(us[:4]))

    replayed = 0
    if not a.skip_history:
        routes = sorted(history_routes())
        if a.limit:
            routes = routes[: a.limit]
        paths = sorted({v for r in routes for v in variants(r, current)})
        replayed = len(paths)
        with ThreadPoolExecutor(a.workers) as ex:
            results = list(ex.map(lambda p: (p, *final_status(base + p)), paths))
        for p, st, hops in results:
            if st != 200:
                problems["Historic path ends on an error"].append(f"{p} → {st}")
            elif hops > 1:
                problems["Historic path takes more than one redirect"].append(f"{p} ({hops} hops)")

    lines = [f"# Docs health report — {base}", "", f"- Sitemap URLs checked: {len(rows)}", f"- Historic paths replayed: {replayed}", ""]
    if not problems:
        lines.append("No problems found.")
    for k, v in sorted(problems.items()):
        lines += [f"## {k} ({len(v)})", ""] + [f"- {x}" for x in v[:50]]
        if len(v) > 50:
            lines.append(f"- … and {len(v) - 50} more")
        lines.append("")
    Path(a.out).write_text("\n".join(lines) + "\n")
    total = sum(len(v) for v in problems.values())
    if a.slack_out:
        # Same layout as the CI updater posts in #docs-linkchecker. Errors are
        # pages that fail or drop out of search; warnings are quality issues.
        error_kinds = {
            "Sitemap URL does not answer 200",
            "Sitemap URL is noindex",
            "Canonical differs from the sitemap URL",
            "Historic path ends on an error",
        }
        errors = sum(len(v) for k, v in problems.items() if k in error_kinds)
        warnings = total - errors
        run_url = os.environ.get("RUN_URL", "")
        actor = os.environ.get("GITHUB_ACTOR", "scheduled run")
        ping = "<!here> " if os.environ.get("PING_CHANNEL") == "true" else ""
        status = "Success" if not errors else "Errors found"

        def cell(text, bold=False):
            el = {"type": "text", "text": str(text)}
            if bold:
                el["style"] = {"bold": True}
            return {"type": "rich_text", "elements": [{"type": "rich_text_section", "elements": [el]}]}

        data = [("Sitemap URLs checked", len(rows)), ("Historic paths replayed", replayed),
                ("Warnings", warnings), ("Errors", errors)]
        payload = {
            "text": f"Docs health report: {status}",
            "blocks": [
                {"type": "section", "text": {"type": "mrkdwn", "text": (
                    f"{ping}Docs health report: *{status}*\n"
                    f" Please check the <{run_url}|Build URL> for the full report.\n\n"
                    f"Run by: `{actor}`")}},
                {"type": "table", "column_settings": [{"align": "left"}, {"align": "right"}],
                 "rows": [[cell("Metric", True), cell("Count", True)]]
                         + [[cell(k), cell(v)] for k, v in data]},
            ],
        }
        Path(a.slack_out).write_text(json.dumps(payload, indent=2) + "\n")
    print(f"{len(rows)} URLs, {replayed} historic paths, {total} problem(s) → {a.out}")
    sys.exit(1 if (a.fail_on_problems and total) else 0)


if __name__ == "__main__":
    main()
