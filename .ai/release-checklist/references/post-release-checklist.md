# Post-release checklist (docs-om)

Run via `.ai/release-checklist/instructions.md`, after the release has
shipped. Confirms what pre-release prepared is actually live and correct.

- [ ] **Re-run `scripts/check-release-consistency.sh`** against the
      now-current `release.config.json`.
- [ ] **`/latest/...` redirects point to the new version** on the deployed
      site, not just in `docs.json` locally.
- [ ] **New version directory is reachable and selectable** in the deployed
      site's version switcher.
- [ ] **Release notes page for this version is published and reachable** —
      not a 404, not stuck on a draft slug.
- [ ] **Re-run the full broken-links check** against the deployed site.
- [ ] **Confirm older version directories still resolve correctly** — a
      redirect bump for the new version shouldn't have broken navigation
      into `v1.13.x/` or other still-supported versions.
