
## Release tracking mode (overrides the matching parts above)

In this mode every `confirmed` entry becomes one sub-issue of the next major release's tracker issue, grouped there by feature area. Verdicts, the doc-relevance filter, the evidence rule, and the trust boundary above still apply. PRs the repo already tracks were removed before you saw them. The changes below apply on top.

### Extra fields

Every entry also returns `area`, `summary`, and `checkboxes`. For any verdict other than `confirmed`, return `area: ""`, `summary: ""`, `checkboxes: []`.

- `area`: the feature area the entry belongs to, a short Title Case name such as `Data Governance`, `Observability`, `API and SDK`, `Connectors`, or `AI Analytics`. These are examples, not a fixed list: use any area that fits, and add new ones when none do. If `areas.md` is listed in your input, it holds the areas already used for this release. Reuse one of those names exactly when it fits, and only coin a new area when none does. Never put several features in a catch-all area when a specific one fits.
- `summary`: two or three plain sentences saying what changed and for whom. No file paths, no code.
- `checkboxes`: the doc work this sub-issue needs, one checkbox per page to create or update, each under 160 characters, such as `Update Snowflake connector page: new key-pair auth option`. Base them on the doc hints and the page names you found in this repo. At most six per entry.
- `suggested_title`: for `confirmed`, a short plain-language title (under 80 characters) that names the feature, without the area or release.

### Grouping and sizing (replaces "Grouping" above)

- Size each entry so a docs writer can finish it in one small PR.
- Bundle small, related changes (same area, same pages) into one entry, listing all their PRs in `prs`.
- Split a large feature across several entries in the same `area`, one per page or cluster of pages. If you would need more than six checkboxes, split it.
- A PR belongs to exactly one entry.
