#!/usr/bin/env python3
"""Search Console index status for every sitemap URL, plus clicks and impressions.

Needs `pip install google-auth requests` and a service account that has been added
as a user on the Search Console property. Env:
  GSC_SERVICE_ACCOUNT_JSON   service account key (JSON text)
  GSC_SITE_URL               property, e.g. sc-domain:open-metadata.org or https://docs.open-metadata.org/
URL Inspection allows 2,000 calls/day per property; the sitemap has ~1,100 URLs.

Writes a Markdown section to --out and a small JSON summary to --summary-out, which
docs-health-report.py merges into its report and Slack message. This script never
fails the workflow: if Search Console cannot be reached, both files say so.

An inspection that fails (403, rate limit, timeout) tells us nothing about whether the
page is indexed, so failures are counted separately and never listed as "not indexed".
Also lists pages whose impressions fell by half or more in the last 28 days compared
with the 28 days before.
"""
import argparse
import datetime as dt
import json
import os
import sys
import xml.etree.ElementTree as ET
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import quote

ROOT = Path(__file__).resolve().parent.parent.parent
SCOPES = ["https://www.googleapis.com/auth/webmasters.readonly"]
INDEXED = ("submitted and indexed", "indexed")


def run(a):
    from google.auth.transport.requests import AuthorizedSession
    from google.oauth2 import service_account

    site = os.environ["GSC_SITE_URL"]
    creds = service_account.Credentials.from_service_account_info(
        json.loads(os.environ["GSC_SERVICE_ACCOUNT_JSON"]), scopes=SCOPES
    )
    s = AuthorizedSession(creds)
    urls = [e.text.strip() for e in ET.parse(ROOT / "sitemap.xml").iter() if e.tag.endswith("loc")]
    if a.limit:
        urls = urls[: a.limit]

    def inspect(u):
        """Return (url, coverage state, Google's canonical, error). Exactly one of state and error is set."""
        try:
            r = s.post(
                "https://searchconsole.googleapis.com/v1/urlInspection/index:inspect",
                json={"inspectionUrl": u, "siteUrl": site}, timeout=60,
            )
        except Exception as e:  # timeout, connection error
            return u, None, "", f"{type(e).__name__}: {str(e)[:80]}"
        if r.status_code != 200:
            try:
                msg = r.json()["error"]["message"][:80]
            except Exception:
                msg = ""
            return u, None, "", f"HTTP {r.status_code} {msg}".strip()
        idx = r.json().get("inspectionResult", {}).get("indexStatusResult", {})
        return u, idx.get("coverageState", "unknown"), idx.get("googleCanonical", ""), None

    with ThreadPoolExecutor(4) as ex:
        res = list(ex.map(inspect, urls))
    ok = [(u, c, g) for u, c, g, e in res if e is None]
    failed = [(u, e) for u, c, g, e in res if e is not None]
    counts = Counter(c for _, c, _ in ok)
    not_indexed = [(u, c) for u, c, _ in ok if not c.lower().startswith(INDEXED)]
    other = [(u, g) for u, _, g in ok if g and g.rstrip("/") != u.rstrip("/")]

    lines = ["", "## Search Console index status", ""]
    lines += [f"- {k}: {v}" for k, v in counts.most_common()]
    if failed:
        reasons = Counter(e for _, e in failed)
        lines += ["", f"**{len(failed)} of {len(res)} inspections failed, so their index status is unknown.** "
                  "Check the service account access, the property name and that the Search Console API is enabled.", ""]
        lines += [f"- {n} × {e}" for e, n in reasons.most_common(5)]
    lines += ["", f"### Sitemap URLs not indexed ({len(not_indexed)})", ""]
    lines += [f"- {u} — {c}" for u, c in not_indexed[:50]]
    lines += ["", f"### Google chose a different canonical ({len(other)})", ""]
    lines += [f"- {u} → {g}" for u, g in other[:50]]

    base_url = f"https://searchconsole.googleapis.com/webmasters/v3/sites/{quote(site, safe='')}/searchAnalytics/query"

    def query(start, end, dims):
        try:
            r = s.post(base_url, json={"startDate": str(start), "endDate": str(end), "dimensions": dims, "rowLimit": 25000}, timeout=120)
        except Exception:
            return None
        return r.json().get("rows", []) if r.status_code == 200 else None

    # Search data lags by about 3 days.
    end = dt.date.today() - dt.timedelta(days=3)

    # Impressions by week for the last 8 weeks, to spot site-wide drops.
    rows = query(end - dt.timedelta(weeks=8), end, ["date"])
    lines += ["", "### Weekly clicks and impressions", ""]
    if rows is None:
        lines.append("Search analytics query failed.")
    else:
        weeks = {}
        for row in rows:
            d = dt.date.fromisoformat(row["keys"][0])
            k = str(d - dt.timedelta(days=d.weekday()))
            c, i = weeks.get(k, (0, 0))
            weeks[k] = (c + row["clicks"], i + row["impressions"])
        lines += [f"- week of {k}: {c:.0f} clicks, {i:.0f} impressions" for k, (c, i) in sorted(weeks.items())]

    # Pages that lost at least half their impressions: last 28 days vs the 28 before.
    recent_start = end - dt.timedelta(days=27)
    prior_end = recent_start - dt.timedelta(days=1)
    recent = query(recent_start, end, ["page"])
    prior = query(prior_end - dt.timedelta(days=27), prior_end, ["page"])
    lines += ["", "### Pages with impressions down 50% or more (last 28 days vs the 28 before)", ""]
    drops = []
    if recent is None or prior is None:
        lines.append("Search analytics query failed.")
    else:
        now = {r["keys"][0]: r["impressions"] for r in recent}
        drops = sorted(
            ((r["impressions"], now.get(r["keys"][0], 0), r["keys"][0]) for r in prior if r["impressions"] >= 50),
            reverse=True,
        )
        drops = [(b, n, u) for b, n, u in drops if n <= b / 2]
        lines += [f"- {u}: {b:.0f} → {n:.0f} impressions" for b, n, u in drops[:30]] or ["None."]

    summary = {
        "inspected": len(ok), "failed": len(failed), "not_indexed": len(not_indexed),
        "other_canonical": len(other), "impression_drops": len(drops),
    }
    return lines, summary


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="gsc-report.md")
    ap.add_argument("--summary-out", default="gsc-summary.json")
    ap.add_argument("--limit", type=int, default=0)
    a = ap.parse_args()
    try:
        lines, summary = run(a)
    except Exception as e:  # bad key, missing package, network down: report it, don't fail the run
        reason = f"{type(e).__name__}: {str(e)[:120]}"
        lines = ["", "## Search Console index status", "", f"**Search Console could not be checked:** {reason}"]
        summary = {"unavailable": reason}
    Path(a.out).write_text("\n".join(lines) + "\n")
    Path(a.summary_out).write_text(json.dumps(summary) + "\n")
    print(f"Search Console: {summary}")


if __name__ == "__main__":
    sys.exit(main())
