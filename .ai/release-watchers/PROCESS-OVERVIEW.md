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
  "when did I last succeed for real?" via `gh run list` on `main`,
  scheduled or manual, and keep only runs whose "Ensure tracking labels
  exist" step actually ran, so a dry-run or off-week run can never
  contaminate the baseline. They use that as the actual cutoff. A missed
  or failed run widens the next lookback automatically instead of
  silently dropping PRs. A `since` workflow_dispatch input can override
  this outright for a one-off catch-up run -- needed the first time each
  workflow runs for real, when there's no prior run to compute a baseline
  from. That manual run then becomes the baseline for the scheduled runs
  after it. A live run with no baseline and no `since` fails instead of
  guessing a window.
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
  regardless of trigger (schedule included) -- see "First live rollout"
  below. The notify job runs no model at all: `.github/scripts/watcher-notify.sh`
  only calls `gh issue create/edit/comment` when neither is set (any
  value other than an explicit `false` counts as dry), and otherwise
  writes what it would have created, updated, or commented to the run's
  job summary, since a dry run creates no digest issue to read.
- **Deterministic work stays out of the model.** Listing PRs (exhaustively,
  splitting the date range whenever a query hits GitHub's 1,000-result
  cap), dropping noise, backport and bug-fix classification, diff
  fetching and trimming, doc-coverage grepping, the Part B completeness
  check, and every issue write are plain bash/jq
  (`watcher-prefetch.sh`, `watcher-assemble.sh`, `watcher-notify.sh`, the
  same scripts docs-collate runs, configured by env). The model only
  judges prefiltered candidates and returns verdicts through
  `--json-schema`; URLs, counts, versions, and tracking references are
  filled in from prefetch data, so the model cannot invent a PR, a
  version, or a count.
- **Drafting and publishing run in separate jobs.** The drafting model
  reads source PRs with a read-only token. A deterministic step packages
  only documentation changes, and a fresh runner validates the patch
  before it commits and opens a draft PR. The publishing job never runs
  a model or reads upstream PR content.
- **No guessing on ambiguity, ever.** Major-vs-minor classification,
  doc-relevance, and feature completeness all have an explicit "I don't
  know" outcome that surfaces the evidence to a human instead of forcing a
  binary call.

---

## Token budget (lossless)

Before this design each watcher ran one `claude-code-action` session that
listed, fetched, and judged PRs turn by turn through `gh`. None of the
three recorded runs on 2026-10-01..05 produced a handoff file (5 to 39
permission denials each, then "summary.json missing"), at $0.33-1.00 per
scan. The current design, the same one docs-collate uses:

- **Every scanned PR reaches a model session.** PRs the prefilter flags
  (noise, dependency bots, and in major mode `backport_found` /
  `bugfix_type`) stay in the session's index with the path of their full
  diff; the model can promote any of them.
- **Trimmed views, full files on disk.** Each candidate's view keeps one
  context line, lists schema/config/UI files first, drops imports, tests,
  lockfiles, and assets, and caps the diff (9 KB minor, 7 KB major). The
  complete body and untrimmed diff sit next to it, and the prompt requires
  reading them whenever a view is truncated or leaves something out.
- **No session grows until it compacts.** Candidates are split into chunks
  of about 160 KB; `watcher-verify.sh` runs one fresh `claude -p` session
  per chunk (Claude Code 2.1.285, pinned, Sonnet 5.5 at `--effort high`,
  Read/Grep only, `/proc` denied, custom system prompt, no CLAUDE.md,
  skills, MCP, or subagents, five-minute prompt cache).
- **Every candidate ends with a verdict.** One a session skips becomes
  NEEDS A LOOK in the digest.

Local replays (2026-10-05): minor window from 2026-10-01, 14 PRs and 13
candidates in one session, 11 turns, about $0.20. Major window from
2026-09-20, 472 PRs and 171 candidates in 9 sessions; one session of 22
candidates took 37 turns, about $0.52, so roughly $4.5 per biweekly run.
65 of those candidates are backported PRs this repo does not track yet,
which the major watcher keeps reviewing by design (see A3).

Prompts and schemas: `.ai/release-watchers/scan-system-prompt.md` and
`verdicts.schema.json`.

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
| Lookback | Finds the last successful live run of this workflow on `main`, scheduled or manual, via `gh run list --branch main` plus a check that the label step actually ran, and starts at that run's exact start time; a live run with none found fails, and a preview run falls back to a 4-day window; a validated `since` input overrides all of this outright | `prepare` job, `id: cadence` |
| Version | Parses the current version out of this repo's own `snippets/releases/latest.mdx`, then computes the next minor version, the minor release branch name, and the current version's doc directory | `prepare` job, `id: version` |
| 1. Select | `gh pr list --base <minor-release-branch>` since the lookback, split by date range until no query is cut off (fails if one day alone hits the cap); flags noise titles, dependency bots, and PRs touching only tests/CI/locks/assets as `skipped` (still indexed). Backports stay candidates | `watcher-prefetch.sh select minor` |
| 2. Bundle | Full body and diff of every PR on disk; trimmed candidate views with doc-coverage hints grepped in `CURRENT_VERSION_DIR` and its snippets (release notes and other versions excluded); chunks with per-session indexes | `watcher-prefetch.sh bundle` |
| 3. Verify | One Sonnet session per chunk: **HELD**, **RULED OUT**, **NEEDS A LOOK**, or **CONFIRMED**, each citing a path, a quoted diff line, or a docs page; same-feature PRs grouped | `watcher-verify.sh`, `scan-system-prompt.md` |
| 4. Assemble + validate | Builds `summary.json` from verdicts plus prefetch data (candidates without a verdict become NEEDS A LOOK); validated before upload and again in the notify job: fixed shape, `target_version` equal to the computed version, every source URL an `open-metadata/OpenMetadata` PR, no blank titles or reasons | `watcher-assemble.sh`, `validate-watcher-summary.sh` |
| 5. Notify | Dedups by exact hidden markers before creating anything: this PR, a shared tracking issue, or the original PR of a backport, under `minor-watcher`, `major-watcher`, or the legacy `daily-watcher` prefix, on issues filed by `github-actions[bot]` (or the hand-filed legacy ones). Creates or updates one issue with `<!-- minor-watcher:pr-<n> -->` markers; assigns `DAILY_WATCHER_ASSIGNEES` if set | `watcher-notify.sh` |
| 6. Digest | Comments on "Minor Release Watcher -- Scan Digest" every run, listing counts and every needs-a-look/held item | `watcher-notify.sh` |
| 7. Slack | Only if something was CONFIRMED this run (and not forced/dry-run): the notify job writes `slack-digest.txt`, which the separate `slack` job posts to `SLACK_WEBHOOK_URL` | `watcher-notify.sh` + `slack` job |

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
| A1. Config | Uses the already-computed version values (current version, minor release branch, next major version, next major's doc directory) |
| A2. Scan | `gh pr list --base main` since the lookback (`watcher-prefetch.sh select major`); splits the date range whenever a query comes back full, and fails the run if a single day still does |
| A3. Classify major vs. minor (bash) | **The judgment call this workflow exists to make.** A `main` merge isn't automatically major-only — it might just be minor work that hasn't been backported yet. First checks for a backport PR on the current minor branch (upstream's own "Backport #X to Y" title convention). If one exists, the PR is excluded only once this repo already tracks the change under either PR number; otherwise it's still reviewed here, so a change can't fall between the two watchers. If none exists, reads the PR's own "Type of change": a bug/security fix is treated as provisionally minor-bound (excluded here) since those almost always get backported eventually; a genuinely new capability is the real major-only signal. Genuinely ambiguous cases become their own NEEDS A LOOK item instead of a guess |
| A4. Filter + Verify | Same bundle and verify steps as the minor watcher, doc hints grepped in `NEXT_MAJOR_DIR`; excluded PRs stay in the index, and the model can promote any of them |
| A5. Group | Same cumulative grouping as the minor watcher |
| A6. Notify | Same marker dedup as the minor watcher, with `<!-- major-watcher:pr-<n> -->` markers |

### Part B — completeness check on already-tracked features

| Step | What it does |
|---|---|
| B1. Find candidates (bash) | Open issues filed by `github-actions[bot]` containing more than one `major-watcher:pr-X` marker — single-PR issues have nothing to check here (`watcher-prefetch.sh completeness`) |
| B2. Check completeness | For each linked PR, finds its real tracking issue upstream and checks: is it closed, and are *all* PRs referencing it actually merged (not just the ones already known about) |
| B3. Report back | After a deterministic check that every target is an open, bot-filed issue carrying the exact marker of every PR named (any mismatch fails the job), comments on the *existing* issue (never opens a new one) with **COMPLETE** (ready to draft now), **INCOMPLETE** (how many still outstanding), or **UNCLEAR** (the exact conflicting evidence quoted, not summarized away) |

### Part C / D — Digest and Slack

Same shape as the minor watcher's steps 7–8, but the digest issue is
titled "Major Release Watcher — Scan Digest" and covers both Part A and
Part B in one comment per run.

---

## First live rollout

Both workflows carry a workflow-level `env: FORCE_DRY_RUN: "true"`. While
set, this overrides `dry_run` regardless of trigger (schedule included),
and the bash notify step skips every `gh issue create`/`edit`/`comment`;
no model is involved in that decision. This makes the first pass after merging safe by
construction: the schedule can fire for real before anyone tests it
manually, and that run can only ever read and report.

The intended sequence once merged:
1. Run each workflow via `workflow_dispatch` from `main`.
2. Open that run's job summary in the Actions UI and sanity-check the
   dry-run preview against what's actually open upstream -- forced
   dry-run creates no digest issue to read instead.
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
  `daily-watcher:pr-X` marker** and were filed by hand (`kiran1287`).
  Dedup matches exact markers under all three prefixes, and those issues'
  author is listed in `TRUSTED_AUTHOR_RE` in both workflows so they keep
  counting; they were never migrated to a `minor-watcher`/`major-watcher`
  marker of their own.
- **First run for each workflow has no history to look back on** — the
  `since` input handles this deliberately. Without it, a live run fails
  rather than guessing a window. Preview runs fall back to a fixed window
  (4 days for minor, 15 for major), since they don't track anything.
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
repo's default branch. The prefetch, verify, assemble, validate, and
dry-run notify steps were replayed locally against live data (see "Token
budget"), but have not executed inside a real Actions run yet — only the surrounding bash/`gh` logic
above has been proven live. See "First live rollout" above for how this
is being handled safely.
