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
