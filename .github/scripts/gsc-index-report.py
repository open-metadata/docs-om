#!/usr/bin/env python3
"""Search Console index status for every sitemap URL, plus clicks and impressions.

Needs `pip install google-auth requests` and a service account that has been added
as a user on the Search Console property. Env:
  GSC_SERVICE_ACCOUNT_JSON   service account key (JSON text)
  GSC_SITE_URL               property, e.g. sc-domain:open-metadata.org or https://docs.open-metadata.org/
URL Inspection allows 2,000 calls/day per property; the sitemap has ~1,100 URLs.
Appends a Markdown section to --out.
"""
import argparse
import datetime as dt
import json
import os
import re
import sys
import xml.etree.ElementTree as ET
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import quote

import requests
from google.auth.transport.requests import AuthorizedSession
from google.oauth2 import service_account

ROOT = Path(__file__).resolve().parent.parent.parent
SCOPES = ["https://www.googleapis.com/auth/webmasters.readonly"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="docs-health-report.md")
    ap.add_argument("--limit", type=int, default=0)
    a = ap.parse_args()
    site = os.environ["GSC_SITE_URL"]
    creds = service_account.Credentials.from_service_account_info(
        json.loads(os.environ["GSC_SERVICE_ACCOUNT_JSON"]), scopes=SCOPES
    )
    s = AuthorizedSession(creds)
    urls = [e.text.strip() for e in ET.parse(ROOT / "sitemap.xml").iter() if e.tag.endswith("loc")]
    if a.limit:
        urls = urls[: a.limit]

    def inspect(u):
        r = s.post(
            "https://searchconsole.googleapis.com/v1/urlInspection/index:inspect",
            json={"inspectionUrl": u, "siteUrl": site}, timeout=60,
        )
        if r.status_code != 200:
            return u, f"API error {r.status_code}", ""
        idx = r.json().get("inspectionResult", {}).get("indexStatusResult", {})
        return u, idx.get("coverageState", "unknown"), idx.get("googleCanonical", "")

    with ThreadPoolExecutor(4) as ex:
        res = list(ex.map(inspect, urls))
    counts = Counter(c for _, c, _ in res)
    lines = ["", "## Search Console index status", ""]
    lines += [f"- {k}: {v}" for k, v in counts.most_common()]
    not_indexed = [(u, c) for u, c, _ in res if not c.lower().startswith(("submitted and indexed", "indexed"))]
    lines += ["", f"### Sitemap URLs not indexed ({len(not_indexed)})", ""]
    lines += [f"- {u} — {c}" for u, c in not_indexed[:50]]
    other = [(u, g) for u, c, g in res if g and g.rstrip("/") != u.rstrip("/")]
    lines += ["", f"### Google chose a different canonical ({len(other)})", ""]
    lines += [f"- {u} → {g}" for u, g in other[:50]]

    # Impressions by week for the last 8 weeks, to spot drops.
    end = dt.date.today() - dt.timedelta(days=3)
    start = end - dt.timedelta(weeks=8)
    r = s.post(
        f"https://searchconsole.googleapis.com/webmasters/v3/sites/{quote(site, safe='')}/searchAnalytics/query",
        json={"startDate": str(start), "endDate": str(end), "dimensions": ["date"], "rowLimit": 100}, timeout=60,
    )
    if r.status_code == 200:
        weeks = {}
        for row in r.json().get("rows", []):
            d = dt.date.fromisoformat(row["keys"][0])
            k = str(d - dt.timedelta(days=d.weekday()))
            c, i = weeks.get(k, (0, 0))
            weeks[k] = (c + row["clicks"], i + row["impressions"])
        lines += ["", "### Weekly clicks and impressions", ""]
        lines += [f"- week of {k}: {c:.0f} clicks, {i:.0f} impressions" for k, (c, i) in sorted(weeks.items())]
    with open(a.out, "a") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    sys.exit(main())
