---
name: content-review
description: Review written content — a PR, a file, or pasted text — against the OpenMetadata Writing Style Guide checklist. Flags branding, style, punctuation, formatting, and technical-accuracy issues with the exact fix for each.
user-invocable: true
argument-hint: "<PR-number | file-path> (leave blank to be asked)"
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# Content Review Skill

Runs the same checklist review this repo's automatic CI workflow
(`doc-review-auto.yml`) and manual `/content-review` PR-comment trigger
both use — but locally, on demand, without needing an open PR or a GitHub
Actions run. Useful for checking a draft before opening a PR, reviewing
someone else's PR without waiting for CI, or reviewing pasted content that
isn't in a PR at all.

## When to activate

When invoked directly as `/content-review`, or when a user asks to review,
proofread, check, audit, clean up, or validate content against the
OpenMetadata writing style guide.

## How to run

1. **Determine the target** from the argument:
   - A number → treat as a PR number. Run `gh pr diff <n>` to get its
     changed content.
   - A file path → read that file directly.
   - Pasted text in the request itself → review it as given.
   - No argument → ask the user what to review, then stop.
2. Read `.ai/doc-review/instructions.md` and
   `.ai/doc-review/references/checklist.md` in this repo.
3. Run every applicable checklist item against the target content, exactly
   as `instructions.md` specifies — do not skip categories, mark items N/A
   when they genuinely don't apply.
4. Return the Review Report in the exact format `instructions.md` defines
   (Issues Found table, What's Working Well, Category Summary, Top 3
   Priorities).
5. If the user asks for a fully revised version afterward, produce one —
   but never rewrite unprompted.

## Notes

- This is the same checklist the automatic CI review and the manual
  `/content-review` PR-comment trigger both read from — running this skill
  locally will produce the same findings a PR would get, before it's even
  opened.
- Wait for the user to say "yes" before applying any suggested edit,
  exactly as `instructions.md` requires.
