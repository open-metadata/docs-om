# Create Release Notes — Process Reference

Detailed mechanics behind `SKILL.md`'s high-level flow. Read this in full
before the first real run; skim it on repeat runs for whichever section
you need.

---

## 1. Per-target source config

| Target | Source repo(s) | Content scope | Output path |
|---|---|---|---|
| `getcollate` | `open-metadata/openmetadata-collate`, `open-metadata/OpenMetadata`, `open-metadata/ai-platform` | Collate + OSS + AI Platform, Collate-branded intro ("Collate X.Y.Z is a maintenance release...") | `content/product-updates/vX.Y.Z.md` + `versions.json` |
| `openmetadata-site` | `open-metadata/OpenMetadata` only | OSS only — never mention Collate-only features, never cite `openmetadata-collate` or `ai-platform` | `content/product-updates/vX.Y.Z.md` + `versions.json` |
| `docs-om` | none (reuses openmetadata-site's file) | Same content as openmetadata-site, wrapped for Mintlify | `snippets/releases/X.Y.Z.mdx`, imported into `vX.Y.x/releases/X.Y-release.mdx` |

`getcollate` and `openmetadata-site` have **separate, independent `id`
counters and `versions.json` files** — do not cross-reference their id
numbers. Two versions with the same `vX.Y.Z` string in both repos are
expected and fine; their `id` values will differ.

A Collate-only patch (no matching OSS tag exists — e.g. historically
`v1.12.6`, `v1.12.9`) has **no `openmetadata-site`/`docs-om` counterpart**.
Check for the OSS tag first (`gh api repos/open-metadata/OpenMetadata/releases/tags/X.Y.Z-release`)
before attempting those two targets; if it 404s, do `getcollate` only and
say so.

## 2. Resolving the commit range

For each source repo:

```bash
gh api repos/<owner>/<repo>/releases/tags/PREV-release   # confirm prev tag exists
gh api repos/<owner>/<repo>/releases/tags/X.Y.Z-release  # does the target tag exist yet?
```

- **If the target tag exists**: use `PREV-release...X.Y.Z-release` — this
  is the ground truth. Always prefer this once available.
- **If it doesn't yet**: use `PREV-release...<default-branch>` (e.g.
  `2.0`) as a working approximation, but say explicitly in the summary
  that this is unreleased-branch data and may need re-verification once
  the real tag lands. `ai-platform` in particular rarely tags releases at
  all — branch-to-branch is normal there, not a fallback.
- **Confirm the version bump commit** exists somewhere in the range
  (`chore(release): bump version to \`X.Y.Z\`` or similar) as a sanity
  check that you have the right range at all.

**Always check `.total_commits` and paginate** (`per_page=100&page=N`)
before drawing any conclusion from a compare — a 100+-commit range
silently truncates to one page otherwise. This has caused real omissions
in past runs.

### Re-verifying a previously-drafted version once its tag lands

If asked to fix or double-check an already-written file, don't assume the
original branch-based fetch was accurate. Re-run the compare against the
now-real `PREV-release...X.Y.Z-release` tag pair, and for every citation
already in the file, spot-check with:

```bash
gh pr view <n> --repo <owner>/<repo> --json baseRefName,mergedAt
gh api repos/<owner>/<repo>/releases/tags/X.Y.Z-release -q '.published_at'
```

If a cited PR's `mergedAt` is *after* the tag's `published_at`, that fix
did not ship in this version — it belongs in the next one instead. This
exact bug shipped once already (getcollate v2.0.2 cited `#33186`,
`#6375`, `#6675`, and over-bundled `#33153` — all four had actually
merged after the 2.0.2 tag, via different wrapper/backport PR numbers
that were the real ones to cite).

## 3. Filtering commits

Drop:

- `ci:`, `test(...)`, `chore:`, build-only, dependency-pin-only commits
  with no product effect (e.g. bumping a CI-only tool version).
- Merge commits, branch-sync commits (`Merge remote-tracking branch...`).
- The version-bump commit itself.
- A commit that was reverted later in the same range with no re-apply.
  If reverted *then* re-applied, cite only the final, re-applied PR.

Keep everything else, even if it looks minor — the customer-facing filter
pass (§6) is the real quality gate, not this step. This step is only
about removing pure process/tooling noise.

## 4. Categorizing

Use headings sized to what the range actually contains — don't force a
fixed template. Sections used successfully so far, roughly in this order
when all are present:

🤖 AI & Automations · 💳 Billing · 🔗 AI Context & MCP Server ·
🔎 Query Runner & SQL Studio · 🔍 Search & Discovery ·
🛡️ Data Governance & Quality · 👥 Teams & Access Control ·
🔐 Authentication & SSO · 🔌 Connectors & Ingestion · 🔀 Lineage ·
📣 Alerts & Events · ⚙️ Platform & Operations · 🎛️ UI · 🔒 Security ·
🔄 Migration Fixes

Split a section further (e.g. pull Teams & Access Control or
Authentication & SSO out of a general Governance bucket) once it has
enough distinct items to justify it — a 3-section, 20-bullet file reads
worse than a 10-section one. Drop a heading entirely if nothing in this
range belongs there.

## 5. Bundling

Bundle commits into one bullet only when they share a **real** root
cause or theme (same connector, same component, same CVE family) — not
just adjacency in the commit log. Each bundle:

- Cites at most 3 PR links. If a natural bundle has 4+, split it into two
  bullets along whatever line makes each half coherent on its own (see
  the CVE-bump splits in getcollate v1.13.5/v2.0.2 for the pattern:
  "JVM/backend CVE bumps", "UI dependency CVE bumps", etc., each ≤3
  links).
- States what each part does in one sentence, not a title-only list —
  the reader should understand the bundle without opening any of the
  links.
- If the same underlying fix landed as separate PRs in
  `open-metadata/OpenMetadata` and `open-metadata/openmetadata-collate`,
  cite the OpenMetadata one only (this doesn't apply to
  `openmetadata-site`, which never cites Collate anyway).

## 6. Customer-facing filter pass

After the first full draft, re-read every single bullet and ask: *does
this sentence describe something a user or admin would actually notice
or hit?* Drop it if not. Concretely, drop:

- Pure internal refactors, type-safety changes, or code-organization
  fixes with no described symptom ("X is now handled as a value instead
  of a type" with nothing else — no).
- Defensive/hygiene fixes with no stated failure mode ("a lookup result
  is now validated" — validated against *what breaking how*? If the
  commit body doesn't say, it's not clearly customer-facing; check the
  PR body before deciding, don't guess).
- Test-only fixes that slipped past §3's filter under a non-`test(...)`-
  prefixed commit message.

Keep, even without an explicit story:

- All security/CVE items — convention across every prior release is to
  list these regardless of whether an exploit scenario is spelled out.
- Data-integrity bugs (wrong data written, wrong data returned, a
  transaction committed when it shouldn't be) even if the commit message
  doesn't narrate a user story — the consequence is inherent to the bug
  class.

When in doubt, fetch the PR body (`gh pr view <n> --json body`) rather
than guessing from the commit subject alone — several "looks internal"
commits turned out to describe a real, if narrow, user-facing bug once
the body was read.

## 7. Doc-review pass

Each target repo may have its **own** `.ai/doc-review/` checklist —
don't assume they're identical. Confirm which exists before running:

```bash
ls <repo>/.ai/doc-review/instructions.md <repo>/.ai/doc-review/references/checklist.md
```

- `docs-collate` and `docs-om` are both confirmed to have one as of this
  writing.
- Check `getcollate` and `openmetadata-site` for their own; if absent,
  ask the user which checklist to apply instead of silently picking one.

Run the checklist against the actual bullets written (not the raw
commit list), fix every flagged issue, and re-verify nothing broke
(bullet/link counts unchanged except for the specific text fixed).

Common findings from past runs, worth checking proactively even before
the full pass: missing Oxford commas in the intro sentence's item list,
semicolons inside bullet titles or bodies (split into two clauses
instead), a code/type identifier not wrapped in backticks
(`` `STRUCT` ``, `` `CHAR` ``, etc.), and inconsistent capitalization of
a recurring proper noun (e.g. "Query Runner" vs "query runner") within
the same file.

## 8. Live link verification

Never rely on a raw unauthenticated `curl` to a private repo's PR page —
GitHub's web UI requires a session cookie, not an API token, so a bearer
token in the `Authorization` header returns a false 404 even for a real,
merged PR. Verify through the REST API instead:

```bash
gh api repos/<owner>/<repo>/pulls/<n> -q '.state'
```

Batch this with a small parallel loop (`xargs -P 8`) rather than one
`gh api` call per link in a slow sequential loop — a release with 80+
citations makes the sequential version time out. Use a real script file
for the per-link check rather than inlining the token into each `xargs`
invocation (embedding a long token once per parallel worker has hit
`ARG_MAX` in practice).

For a commit-SHA fallback link (used only when a real PR truly can't be
found — never fabricate one), verify the full SHA resolves:

```bash
gh api repos/<owner>/<repo>/commits/<short-sha> -q '.sha'
```

## 9. Build check

```bash
cd <repo> && HOST_NAME=https://<site-host> yarn build
```

If `node_modules` is stale (common after a large upstream `git pull`),
`yarn install` first. If the build fails on something unrelated to the
content change (a missing module, a webpack error naming a file you
didn't touch), that's a pre-existing repo issue — say so plainly, don't
silently work around it, and don't let it block reporting the content
work as otherwise done.

After a successful build, start the server for a live preview rather
than only reporting "build passed":

```bash
lsof -ti:3000 -sTCP:LISTEN 2>/dev/null | xargs -r kill
HOST_NAME=https://<site-host> nohup yarn start > /tmp/yarn_start.log 2>&1 &
disown
# poll until curl -sf http://localhost:3000 succeeds, then hand over the URL
```

Give the user `http://localhost:3000/en/product-updates` (or the
equivalent path) and stop — do not commit.

## 10. docs-om reformat

Once openmetadata-site's file for this version is finished and approved,
wrap its `## Changelog` section (everything from that heading down) into:

```mdx
<Update label="X.Y.Z Release" description="Nth Month YYYY">

You can find the GitHub release [here](https://github.com/open-metadata/OpenMetadata/releases/tag/X.Y.Z-release).

## Changelog

...(the exact same section content, verbatim)...

</Update>
```

Save as `snippets/releases/X.Y.Z.mdx`. Then in
`vX.Y.x/releases/X.Y-release.mdx`:

- Add a new import above the existing ones:
  `import ReleaseNotes from '/snippets/releases/X.Y.Z.mdx';`
- Renumber the existing `ReleaseNotes`, `ReleaseNotes2`, ... imports and
  their corresponding `<ReleaseNotesN />` tags down by one (the newest
  import is always unsuffixed `ReleaseNotes`).
- Add the new `<ReleaseNotes />` tag at the very top of the render list,
  before the others.
- Update the `<Card>` text ("Learn how to upgrade your OpenMetadata
  instance to X.Y.Z!") to the new version.

This is a **reformat of already-approved content**, not an independent
editorial pass — don't re-filter or re-bundle here. Do still run docs-om's
own doc-review checklist and the link check, since the GitHub-release
link line is new to this format and wasn't present in the source file.

## 11. Incidents this process has actually hit (why each check above exists)

- **Wrong repo entirely, first pass.** Early in this process a release
  was drafted from `openmetadata-collate` when the version's own
  `versions.json` history showed it should have come from
  `open-metadata/OpenMetadata` (a real, tagged OSS release) instead —
  caught by comparing PR-link-repo distribution against the two most
  recent already-published files before trusting a new source choice.
  **Lesson**: before sourcing a new version, check whether the last 2-3
  published versions for that *version-number track* came from OSS tags
  or from Collate-only branches, and match that.
- **Bootstrap deadlock in a CI gate** (docs-collate PR #568): a new gate
  script required output from a prompt template that was intentionally
  still being read from the base branch (so a PR can't rewrite its own
  grading rules) — the check could never pass on the very PR introducing
  it. Fixed by falling back to a field present in both the old and new
  formats rather than hard-failing on the new one's absence. **Lesson**:
  any new machine-readable contract between a prompt and a CI script
  needs a fallback path for the version-skew window before it's fully
  rolled out everywhere that reads it.
- **Citing an issue number instead of the merged PR number.** A commit
  message's `Fixes #NNNNN: ...` prefix is an issue reference, not the PR
  that fixed it — the real PR number is elsewhere in the same message
  (often in trailing parens). Citing the issue number produces a dead
  link. **Lesson**: when a commit message shows both an issue-style
  reference and a `(#NNNNN)`-style PR reference, always cite the latter,
  and verify it resolves via the API before finalizing.
- **Fabricating a commit SHA.** A fallback link once used a short SHA
  padded out with invented hex characters to look like a full SHA.
  **Lesson**: always fetch the real full SHA
  (`gh api .../commits/<short> -q '.sha'`) before writing a commit-based
  fallback link — never hand-extend a short SHA.
