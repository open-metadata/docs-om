# OpenMetadata docs (docs-om) release checklist instructions

Runs a pre-release or post-release pass over the docs so nothing gets missed
around a release. Mirrors `docs-collate`'s `.ai/release-checklist/`, adapted
for this repo's multi-version-directory structure (`v1.13.x`, `v2.0.x`,
`v2.1.x-SNAPSHOT`, ... all live simultaneously, unlike a single "current"
tree).

---

## When to use

- **Pre-release**: a new OpenMetadata version is about to ship (a new
  `vX.Y.x` directory is being added, or an existing one is getting a new
  patch release).
- **Post-release**: a release just shipped and you're verifying the docs.

If the user doesn't say which, ask.

## Step-by-step execution protocol (both passes)

This is a **guided walkthrough, not a batch job**. Execute exactly one step,
present its result, then stop and ask the user how to proceed — one of:
*looks good, continue* / *fix this before continuing* / *skip this step* /
*stop here for now*. Never run multiple steps and dump a combined report;
never silently move to the next step without the user's go-ahead. If a step
finds nothing to review (clean), still say so explicitly and still pause for
confirmation before moving on — brief, but never skipped.

## How to run a pre-release pass

Run these as separate, confirmed steps:

1. **Get the new version.** Ask for the version directory name (new
   `vX.Y.x`, or an existing one getting a patch bump) and its
   `openmetadataVersion` / `airflowVersion`. Show the exact diff to
   `release.config.json` and apply only after confirmation.
2. **Run the consistency script.** Present the full `OK`/`CHECK` output,
   then go through the `CHECK` lines one at a time (or in small logical
   batches per file): real drift vs. intentional (a historical note, an "as
   of version X" comparison) — ask before editing. Remember `CHECK` in one
   version directory says nothing about another.
3. **Redirect plumbing**, only if this is a new version directory: confirm
   `.github/workflows/bump-latest-version.yml` has been or will be run to
   update `/latest/...` redirects in `docs.json`. This is separate from step
   2 (which only covers hardcoded versions inside pages, not redirects).
4. **Breaking-changes-have-doc-coverage check.** Pull the merged-PR list
   from `references/upstream-watch-config.md`'s query, widened to the
   release window. One at a time: pull the PR diff, pull the related doc
   excerpt, show both side by side, ask *matches / doesn't match — draft an
   update / unclear — I'll dig deeper*. Only edit after "draft an update."
5. **Doc-relevant PR accuracy check.** Same side-by-side/ask pattern as step
   4, for the broader doc-relevant PR list (not just breaking changes).
6. **Broken-links pass.** Run
   `mint broken-links --check-external --check-snippets --check-redirects`
   locally (CI runs it too via `mint-broken-links.yml`, but confirm locally
   before merging). Present failures before asking to continue.

## How to run a post-release pass

Same protocol, one confirmed step at a time:

1. Re-run `scripts/check-release-consistency.sh` against the now-current
   `release.config.json`; walk any `CHECK` lines same as pre-release step 2.
2. Confirm the `/latest/...` redirects point to the right version directory
   on the deployed site (via `bump-latest-version.yml`'s PR, if one was
   opened).
3. Confirm the new version directory is reachable/selectable in the
   deployed site's version switcher.
4. Confirm the release-notes page for this version is published and
   reachable, and still covers every breaking change from the pre-release
   pass.
5. Re-run the full broken-links check against the deployed site.
6. Confirm older version directories still resolve correctly — a redirect
   bump for the new version shouldn't break navigation into still-supported
   older versions.

## Behaviour rules

- **Evidence before verdict.** Every check surfaces what it found before any
  edit happens.
- **Per-directory, not global.** A `CHECK` in `v1.13.x/` doesn't mean
  `v2.0.x/` has the same problem, and vice versa — each version directory
  tracks its own expected version independently.
- **This is release-scoped.** Don't fold the PR-diff comparison or the full
  broken-links sweep into routine, non-release commits — that stays with
  this repo's existing `.ai/doc-review/references/checklist.md` for
  everyday content review.
