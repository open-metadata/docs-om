# Release Watchers — Process Overview

Reference doc for the automated doc-need detection built into this repo.
Explains the whole flow, both workflows, what each step actually does, and
where the prompts/code live. Mirrors the shape of
`.ai/release-checklist/`'s own overview doc in spirit — this one covers the
automated front half of the pipeline (detecting a doc need), that one
covers the manual release-time back half (verifying nothing was missed).

---

## Overview — the problem this solves

Before this existed, the gap between "code merged upstream" and "someone
realizes a doc is needed" was entirely manual, and mostly only caught
around release time. Everything *after* a doc PR already exists was
already automated (style review, broken-link checks); nothing watched for
the need to exist in the first place.

Two independent, symmetric workflows close that gap — one per release
type, because they're genuinely different problems with different
cadences and different risks, not one problem with a mode switch.

```
                 ┌─────────────────────────┐        ┌─────────────────────────┐
                 │  Minor Release Watcher   │        │  Major Release Watcher  │
                 │  (Mon + Thu)             │        │  (every other Monday)   │
                 │  2.0.0 → 2.0.1 → 2.0.2…  │        │  2.0 (current) → 2.1 →…  │
                 └────────────┬─────────────┘        └────────────┬─────────────┘
                              │                                    │
                              ▼                                    ▼
                     tracked GitHub issue in the "needs-docs" sense (no label needed —
                     every issue either workflow files already means that by existing)
                              │                                    │
                              ▼                                    ▼
                     you comment /create-draft on it (create-draft.yml)
                              │
                              ▼
              doc-review-auto.yml (TW standards) + mint-broken-links.yml (links)
                              │
                              ▼
                         human review, then merge
```

Both watchers feed the same downstream: a human-triggered draft
(`/create-draft`), then the same review automation everything else in this
repo already goes through.

---

## Design principles

- **Deterministic gates, never an AI judgment call for "should this run
  today."** Cadence (which days, which lookback window) is decided by
  plain bash before Claude ever runs — the AI's job is judging PR content,
  not deciding whether today is a scan day.
- **Self-healing lookback, not a fixed day-count.** Both workflows ask
  "when did I last succeed?" via `gh run list`, and use that as the actual
  cutoff. A missed or failed run widens the next lookback automatically
  instead of silently dropping PRs.
- **Verify before notify.** Every candidate is classified as CONFIRMED,
  RULED OUT, NEEDS A LOOK, or HELD before anything reaches an issue — a
  passing title is never taken at face value.
- **Dry-run is a real feature, not a testing hack.** Both workflows accept
  a `dry_run` input that runs every read-only step for real but never
  writes anything — useful for previewing before trusting a new filter
  tweak, not just something built for this one round of testing.
- **No guessing on ambiguity, ever.** Major-vs-minor classification,
  doc-relevance, and feature completeness all have an explicit "I don't
  know" outcome that surfaces the evidence to a human instead of forcing a
  binary call.

---

## Workflow 1 — Minor Release Watcher

**File:** `.github/workflows/minor-release-watcher.yml`
**Schedule:** `0 6 * * 1,4` — 06:00 UTC, every Monday and Thursday
**Scope:** the current minor/patch line only (e.g. `2.0.0 → 2.0.1 → 2.0.2`
for however many version directories `release.config.json` lists with a
live release branch). Never touches `main` — that's the other workflow's
job, and a PR merged straight to a release branch is unambiguously
minor-bound, so there's no classification judgment needed on this side.

| Step | What it does | Where |
|---|---|---|
| Lookback | Finds the last successful run of *this* workflow via `gh run list`; falls back to a 4-day window if none found or the lookup itself fails | Deterministic bash step, `id: cadence` |
| 1. Read config | Reads `release.config.json` for current versions, and `upstream-watch-config.md` for the doc-relevance filter rules | Prompt step 1 |
| 2. Scan | `gh pr list --base <release-branch>` for every live minor branch, since the lookback cutoff | Prompt step 2 |
| 3. Filter | Applies the doc-relevance filter; for survivors, reads the real PR body/diff and writes a plain-English evidence note — never guesses from the title | Prompt step 3 |
| 4. Verify | Classifies each survivor as **HELD** (PR discloses it's unverified/unapproved), **RULED OUT** (bug fix restoring existing behavior, checked against this repo's actual docs), **NEEDS A LOOK** (genuinely inconclusive), or **CONFIRMED** | Prompt step 4 |
| 5. Group | Groups CONFIRMED PRs belonging to the same feature; cumulative across runs, never guesses whether a feature is "done" | Prompt step 5 |
| 6. Notify | Dedups three ways before creating anything: (i) this PR's number under *either* marker prefix — old `daily-watcher:pr-X` or this workflow's `minor-watcher:pr-X`, (ii) a shared "Fixes #X" tracking issue, (iii) a shared original PR if this item is itself a backport ("Backport #Y"). Creates or updates one issue; assigns `DAILY_WATCHER_ASSIGNEES` if set | Prompt step 6 |
| 7. Digest | Posts a comment to a persistent "Minor Release Watcher — Scan Digest" issue every run, listing all four categories — this is what makes routine, uneventful runs visible too | Prompt step 7 |
| 8. Slack | Only if something was CONFIRMED this run: writes `slack-digest.txt`, which a separate non-AI step posts to `SLACK_WEBHOOK_URL` | Prompt step 8 + final bash step |

---

## Workflow 2 — Major Release Watcher

**File:** `.github/workflows/major-release-watcher.yml`
**Schedule:** `0 6 * * 1` — every Monday, but a deterministic ISO-week-parity
check (`date -u +%V`, even weeks only) means it only actually does anything
every other Monday. `workflow_dispatch` accepts a `force_run` input to
override this for a manual run.
**Scope:** `main` only, targeting the next major (whichever version
directory's own note says it's the pre-release snapshot, e.g.
`v2.1.x-SNAPSHOT`). Does two jobs in one run:

### Part A — scan for new major-bound doc needs

| Step | What it does |
|---|---|
| A1. Read config | Same as the minor watcher, identifies the major/pre-release target directory |
| A2. Scan | `gh pr list --base main` since the lookback |
| A3. Classify major vs. minor | **The judgment call this workflow exists to make.** A `main` merge isn't automatically major-only — it might just be minor work that hasn't been backported yet. First checks for a backport PR on the current minor branch (upstream's own "Backport #X to Y" title convention). If none exists, reads the PR's own "Type of change": a bug/security fix is treated as provisionally minor-bound (excluded here) since those almost always get backported eventually; a genuinely new capability is the real major-only signal. Genuinely ambiguous cases become their own NEEDS A LOOK item instead of a guess |
| A4. Filter + Verify | Same four-way classification as the minor watcher, applied to whatever survived A3 |
| A5. Group | Same cumulative grouping as the minor watcher |
| A6. Notify | Same three-way dedup as the minor watcher (own prefix, old prefix, shared tracking issue, shared original PR) |

### Part B — completeness check on already-tracked features

| Step | What it does |
|---|---|
| B1. Find candidates | Open issues containing more than one `major-watcher:pr-X` marker — single-PR issues have nothing to check here |
| B2. Check completeness | For each linked PR, finds its real tracking issue upstream and checks: is it closed, and are *all* PRs referencing it actually merged (not just the ones already known about) |
| B3. Report back | Comments on the *existing* issue (never opens a new one) with **COMPLETE** (ready to draft now), **INCOMPLETE** (how many still outstanding), or **UNCLEAR** (the exact conflicting evidence quoted, not summarized away) |

### Part C / D — Digest and Slack

Same shape as the minor watcher's steps 7–8, but the digest issue is
titled "Major Release Watcher — Scan Digest" and covers both Part A and
Part B in one comment per run.

---

## Schedule summary

| Workflow | Trigger | Actual cadence |
|---|---|---|
| Minor Release Watcher | `schedule` | Every Monday and Thursday, 06:00 UTC |
| Major Release Watcher | `schedule` + internal week-parity gate | Every other Monday, 06:00 UTC |
| Create Draft (`create-draft.yml`) | `issue_comment` | On demand — comment `/create-draft` on any tracked issue |
| TW-standards review (`doc-review-auto.yml`) | `pull_request` | Automatic on every PR touching `.mdx` — **still on its own unmerged branch (PR #412), not live yet** |
| Broken-links check (`mint-broken-links.yml`) | `pull_request` | Automatic on every PR — already live |

---

## Secrets and variables this depends on

| Name | Kind | Used for |
|---|---|---|
| `CLAUDE_CODE_OAUTH_TOKEN` | secret | Auth for every Claude-powered step, both workflows plus `create-draft.yml` |
| `SLACK_WEBHOOK_URL` | secret | Posts the confirmed-only digest as a Slack DM |
| `DAILY_WATCHER_ASSIGNEES` | variable | Comma-separated GitHub usernames assigned to every tracked issue and both digest issues |

A Projects-board integration (org project #105, "Documentation") was
scoped during design but never wired in — still needs a token with
Projects (v2) write access if that's wanted later.

---

## Known limitations / what's still open

- **No project-board integration yet** — issues are tracked as plain
  GitHub issues with assignees, not added to project #105.
- **Email notification was scoped, not built** — parked pending a decision
  on sending method (SMTP vs. a transactional API) and frequency.
- **`doc-review-auto.yml` still isn't merged** — the automatic TW-standards
  half of the downstream pipeline exists but isn't live on `main` yet
  (tracked separately as PR #412).
- **Old pre-split tracked issues (#428, #450, #452) use the original
  `daily-watcher:pr-X` marker.** Dedup searches by number rather than
  prefix specifically to keep recognizing these, but they were never
  retroactively migrated to carry a `minor-watcher`/`major-watcher`
  marker of their own.
- **First run for each workflow has no history to look back on** — falls
  back to a fixed generous window (4 days for minor, 15 for major) rather
  than guessing; this only matters once, on each workflow's very first
  successful run.

## Verified before this went anywhere near `main`

Tested via disposable branches (never a PR) — see the commit history on
`docs/daily-watcher-docs-om` for the full detail. In short: the real
`GITHUB_TOKEN` permission chain was confirmed end-to-end (label/issue
create/comment/edit/close), a real bug in the lookback step's error
handling was caught and fixed (an unhandled `gh run list` failure would
have aborted the whole step under GitHub Actions' default `bash -e`), and
two real de-duplication gaps were caught and fixed by walking the exact
prompt logic against live upstream data by hand — a marker-prefix mismatch
with pre-split issues, and a missing check for the "Backport #X" title
pattern real backport PRs actually use.
