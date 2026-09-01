# Pre-release checklist (docs-om)

Run via `.ai/release-checklist/instructions.md`. Each item maps to a concrete
file or command — report each as done / missing / needs-a-decision, with the
evidence that led to that call.

- [ ] **`release.config.json` updated** — new/bumped entry in `versions[]`
      for the version being released.
- [ ] **Run `scripts/check-release-consistency.sh`** and walk every `CHECK`
      line with the user before deciding it's fine or needs a fix. Fix
      directly at each flagged file/line — no consolidated version page (the
      existing `VersionMatrix` component covers minimum infra versions only
      and is a separate, unrelated concern).
- [ ] **Breaking changes have doc coverage.** Pull the merged-PR list for the
      release window from the `OpenMetadata` core repo. For every PR labeled
      or described as a breaking change, confirm a doc page describes the
      new behavior, not just a release-notes mention.
- [ ] **New version directory wired in, if applicable** — `vX.Y.x/` created
      with the standard page structure, added to `docs.json`'s
      `navigation.versions`, and `.github/workflows/bump-latest-version.yml`
      run (or scheduled to run) to update `/latest/...` redirects.
- [ ] **Release notes page(s) exist** for the new version under the relevant
      `vX.Y.x/releases/` directory (and `snippets/releases/` if a shared
      snippet is used).
- [ ] **Full `mint broken-links --check-external --check-snippets --check-redirects`**
      run locally, not just relying on CI.
- [ ] **Previous version directories untouched** unless the release
      specifically requires a backport — a new release should not silently
      change older `vX.Y.x/` content.
