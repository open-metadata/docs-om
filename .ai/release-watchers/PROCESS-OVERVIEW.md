# Release Watchers — Process Overview

Reference doc for the automated doc-need detection built into this repo.
Explains the whole flow, both workflows, what each step actually does, and
where the prompts/code live. Covers only the automated front half of the
pipeline (detecting a doc need) -- pre/post-release checklist verification
is a separate, manually-triggered process, kept out of this branch
entirely.

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
  today" or "what version is current."** Cadence (which days, which
  lookback window) and the current/next version numbers are all decided
  by plain bash before Claude ever runs — the AI's job is judging PR
  content, not deciding whether today is a scan day or what version comes
  next.
- **Self-healing lookback, not a fixed day-count.** Both workflows ask
  "when did I last succeed?" via `gh run list` (filtered to real `schedule`
  runs, so a manual dry-run test can never contaminate the baseline), and
  use that as the actual cutoff. A missed or failed run widens the next
  lookback automatically instead of silently dropping PRs. A `since`
  workflow_dispatch input can override this outright for a one-off
  catch-up run -- needed the first time each workflow runs for real, when
  there's no prior run to compute a baseline from.
- **Current version comes from this repo's own published release notes,
  not a separately-maintained config file.** `snippets/releases/latest.mdx`
  is replaced wholesale on every real release -- it's the one thing that's
  already guaranteed to reflect an actual publish decision a human made,
  so both workflows parse the version straight out of it and compute
  next-minor/next-major from that, deterministically, in bash.
- **Verify before notify.** Every candidate is classified as CONFIRMED,
  RULED OUT, NEEDS A LOOK, or HELD before anything reaches an issue — a
  passing title is never taken at face value.
- **Dry-run is a real feature, not a testing hack.** Both workflows accept
  a `dry_run` input that runs every read-only step for real but never
  writes anything — useful for previewing before trusting a new filter
  tweak, not just something built for this one round of testing. A
  workflow-level `FORCE_DRY_RUN` switch additionally forces this on
  regardless of trigger (schedule included), by removing the write tools
  from Claude's allowed list outright -- see "First live rollout" below.
- **No guessing on ambiguity, ever.** Major-vs-minor classification,
  doc-relevance, and feature completeness all have an explicit "I don't
  know" outcome that surfaces the evidence to a human instead of forcing a
  binary call.

---

## Workflow 1 — Minor Release Watcher

**File:** `.github/workflows/minor-release-watcher.yml`
**Schedule:** `0 6 * * 1,4` — 06:00 UTC, every Monday and Thursday
**Scope:** the single current minor/patch line only (e.g.
`2.0.0 → 2.0.1 → 2.0.2`). Never touches `main` — that's the other
workflow's job, and a PR merged straight to a release branch is
unambiguously minor-bound, so there's no classification judgment needed on
this side. Older lines (e.g. a still-patched `1.13.x`) are not watched --
a deliberate scope decision, not an oversight.

| Step | What it does | Where |
|---|---|---|
| Lookback | Finds the last successful *scheduled* run of this workflow via `gh run list --event schedule`; falls back to a 4-day window if none found or the lookup itself fails; a `since` input overrides both outright | Deterministic bash step, `id: cadence` |
| Version | Parses the current version out of this repo's own `snippets/releases/latest.mdx`, then computes the next minor version, the minor release branch name, and the current version's doc directory | Deterministic bash step, `id: version` |
| 1. Read config | Uses the already-computed version values above, and reads `upstream-watch-config.md` for the doc-relevance filter rules | Prompt step 1 |
| 2. Scan | `gh pr list --base <minor-release-branch>` since the lookback cutoff | Prompt step 2 |
| 3. Filter | Applies the doc-relevance filter; for survivors, reads the real PR body/diff and writes a plain-English evidence note — never guesses from the title | Prompt step 3 |
| 4. Verify | Classifies each survivor as **HELD** (PR discloses it's unverified/unapproved), **RULED OUT** (bug fix restoring existing behavior, checked against this repo's actual docs), **NEEDS A LOOK** (genuinely inconclusive), or **CONFIRMED** | Prompt step 4 |
| 5. Group | Groups CONFIRMED PRs belonging to the same feature; cumulative across runs, never guesses whether a feature is "done" | Prompt step 5 |
| 6. Notify | Dedups three ways before creating anything: (i) this PR's number under *either* marker prefix — old `daily-watcher:pr-X` or this workflow's `minor-watcher:pr-X`, (ii) a shared "Fixes #X" tracking issue, (iii) a shared original PR if this item is itself a backport ("Backport #Y"). Creates or updates one issue; assigns `DAILY_WATCHER_ASSIGNEES` if set | Prompt step 6 |
| 7. Digest | Posts a comment to a persistent "Minor Release Watcher — Scan Digest" issue every run, listing all four categories — this is what makes routine, uneventful runs visible too | Prompt step 7 |
| 8. Slack | Only if something was CONFIRMED this run (and not forced/dry-run): writes `slack-digest.txt`, which a separate non-AI step posts to `SLACK_WEBHOOK_URL` | Prompt step 8 + final bash step |

---

## Workflow 2 — Major Release Watcher

**File:** `.github/workflows/major-release-watcher.yml`
**Schedule:** `0 6 * * 1` — every Monday, but a deterministic ISO-week-parity
check (`date -u +%V`, even weeks only) means it only actually does anything
every other Monday. `workflow_dispatch` accepts a `force_run` input to
override this for a manual run.
**Scope:** `main` only, targeting the next major version (computed
deterministically from the current version -- e.g. current `2.0` → next
major `2.1`). Does two jobs in one run:

### Part A — scan for new major-bound doc needs

| Step | What it does |
|---|---|
| A1. Read config | Uses the already-computed version values (current version, minor release branch, next major version, next major's doc directory) |
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

## First live rollout

Both workflows carry a workflow-level `env: FORCE_DRY_RUN: "true"`. While
set, this overrides `dry_run` regardless of trigger (schedule included),
and Claude's allowed tools have the write commands (`gh issue
create`/`edit`/`comment`) removed outright -- not just described as
off-limits in the prompt. This makes the first pass after merging safe by
construction: the schedule can fire for real before anyone tests it
manually, and that run can only ever read and report.

The intended sequence once merged:
1. Run each workflow via `workflow_dispatch` from `main`.
2. Read the digest issue each produces and sanity-check it against what's
   actually open upstream.
3. Flip `FORCE_DRY_RUN` to `"false"` in its own separate, reviewable
   commit -- that's the actual go-live moment.

---

## Schedule summary

| Workflow | Trigger | Actual cadence |
|---|---|---|
| Minor Release Watcher | `schedule` | Every Monday and Thursday, 06:00 UTC |
| Major Release Watcher | `schedule` + internal week-parity gate | Every other Monday, 06:00 UTC |
| Create Draft (`create-draft.yml`) | `issue_comment` | On demand — comment `/create-draft` on any tracked issue |
| TW-standards review (`doc-review-auto.yml`) | `pull_request` | Automatic on every PR touching `.mdx` — merged and live (PR #412, 2026-09-08) |
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
- **Old pre-split tracked issues (#428, #450, #452) use the original
  `daily-watcher:pr-X` marker.** Dedup searches by number rather than
  prefix specifically to keep recognizing these, but they were never
  retroactively migrated to carry a `minor-watcher`/`major-watcher`
  marker of their own.
- **First run for each workflow has no history to look back on** — the
  `since` input handles this deliberately; without it, falls back to a
  fixed generous window (4 days for minor, 15 for major) rather than
  guessing.
- **Older minor lines (e.g. `1.13.x`) are no longer watched** — a
  deliberate scope reduction to a single current line, not a bug.
- **`create-draft.yml`'s real git-push/PR-open path has never executed
  successfully** — `issue_comment` only fires from the default branch, so
  this can only be tested for real after merging.

## Verified before this went anywhere near `main`

Everything below was checked on disposable branches (never a PR) --
see the commit history on `docs/daily-watcher-docs-om` for full detail.
Being specific here on purpose: an earlier version of this doc overstated
what had actually been confirmed.

**Confirmed working, via real live-API calls:**
- The plain `gh` CLI commands both workflows depend on (label create,
  issue create/comment/edit/close) work against the live API
- The lookback mechanism: an earlier repo-*variable* approach was
  confirmed broken (the default `GITHUB_TOKEN` gets a 403 regardless of
  declared permissions) before being replaced with `gh run list --event
  schedule`, itself confirmed to filter correctly by trigger event
- The major watcher's off-week-run detection (Jobs API step-conclusion
  check, not just run status)
- The `since` override and the `FORCE_DRY_RUN` safety switch (gating
  logic, tool-list construction, and `DRY_RUN` resolution all confirmed
  on disposable branches)
- The version-derivation step: confirmed the parsed version, computed
  next-minor/next-major/branch, and the two derived directory names all
  match real data and real directories on disk
- De-duplication against both marker prefixes and the "Backport #X" title
  pattern, verified against real upstream PRs
- Major/minor classification logic, walked against real PRs both ways

**NOT yet verified — and can't be, before this merges:**
`schedule`, `workflow_dispatch`, and `issue_comment` only fire from a
repo's default branch. The actual `claude-code-action` step (the part
that reads real PRs and would create/update issues) has never executed
successfully in a real run yet — only the surrounding bash/`gh` logic
above has been proven live. See "First live rollout" above for how this
is being handled safely.
