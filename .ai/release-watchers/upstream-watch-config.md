# Upstream watch config

Repo and filters for the Minor/Major Release Watchers' doc-relevance scan.

## Repo

- `open-metadata/OpenMetadata` (public) — this repo's sibling source repo
  (per `CLAUDE.md`, checked out alongside as `../OpenMetadata` for
  connector-doc-review).

## Doc-relevance filter

Flag a PR if any of:
- Touches connector code, API/schema, config defaults, UI-facing strings, or
  migration files.
- Labeled `feature` or `breaking-change` (or repo equivalents).
- Title/description mentions a new setting, endpoint, or user-facing
  behavior change.

Call out anything labeled/described as a breaking change on its own line.

## Where this is applied

The deterministic prefilter (`.github/scripts/watcher-prefetch.sh`) only
flags obvious noise (dependency bots, test/CI/lockfile/asset-only PRs,
conventional `test:`/`ci:`/`chore:` titles) and keeps those PRs in the
verify session's index. The filter above is applied by the verify session
through `scan-system-prompt.md`; keep the two in sync when editing either.
