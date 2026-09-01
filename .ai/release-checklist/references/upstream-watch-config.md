# Upstream watch config

Repo and filters for the pre-release breaking-changes check.

## Repo

- `open-metadata/OpenMetadata` (public) — this repo's sibling source repo
  (per `CLAUDE.md`, checked out alongside as `../OpenMetadata` for
  connector-doc-review); the same repo the pre-release checklist widens its
  merged-PR query against.

## Query

```
gh pr list --repo open-metadata/OpenMetadata --state merged --search "merged:>=<since>" --json number,title,url,labels,mergedAt
```

`<since>` is the previous release's date for a pre-release pass (from
`release.config.json`'s `releaseDate`, or the target version directory's
prior patch release date).

## Doc-relevance filter

Flag a PR if any of:
- Touches connector code, API/schema, config defaults, UI-facing strings, or
  migration files.
- Labeled `feature` or `breaking-change` (or repo equivalents).
- Title/description mentions a new setting, endpoint, or user-facing
  behavior change.

Call out anything labeled/described as a breaking change on its own line.
