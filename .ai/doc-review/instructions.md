# OpenMetadata content review instructions

Reviews written content against the **OpenMetadata Writing Style Guide** and returns a
structured table report showing exactly which guideline was violated, the exact line
or sentence that needs changing, and the suggested replacement.

---

## When to use

Use these instructions when a user asks any AI assistant to review, proofread,
check, audit, improve, clean up, or validate content for OpenMetadata docs; asks whether
copy sounds right or on-brand; or asks to check a draft against the style guide.

## How to use

1. Read the content the user wants reviewed.
2. Read the checklist at `.ai/doc-review/references/checklist.md`.
3. Run every applicable checklist item against the content.
4. Return a **Review Report** in the exact format below.
5. Offer a fully revised version after the report if the user asks.

If no content or file reference is provided, ask the user to provide the content to
review and stop.

Do not skip applicable categories even if the content is short. Mark checklist
items as N/A when they do not apply to the content type.

---

## Review Report Format

Output your response in exactly this structure:

---

### OpenMetadata Content Review

**Content type:** [e.g. Email, Documentation, Marketing copy, Release note]
**Overall verdict:** PASS / NEEDS WORK / FAIL
*(FAIL = 5 or more Critical issues; NEEDS WORK = any Major issues or 3+ Minor)*

---

#### Issues Found

Present every issue as a row in this table. One row per issue — do not combine multiple issues into one row.

| # | Guideline | Severity | Original text | Suggested change |
|---|-----------|----------|---------------|-----------------|
| 1 | [Guideline name + section, e.g. "Active voice — §3.1"] | Critical / Major / Minor | "exact quote from the content" | "replacement text or instruction" |
| 2 | ... | ... | ... | ... |

**Column definitions:**
- **#** — Sequential issue number.
- **Guideline** — The specific rule from the OpenMetadata Writing Style Guide that is violated. Always name the rule and its section number (e.g. "Contractions — §3.3", "Oxford comma — §4.2", "OpenMetadata brand name — §10.1"). Never write a vague label like "tone issue."
- **Severity** — One of:
  - **Critical** — Breaks a core rule: wrong brand name, passive voice throughout, gendered pronouns, no Oxford comma throughout.
  - **Major** — Noticeably degrades quality: jargon, wordiness, redundant phrases used repeatedly, missing contractions throughout.
  - **Minor** — Single small polish item: one number not spelled out, one missing em dash, one weak word choice.
- **Original text** — The exact sentence, phrase, or word from the content that needs to change. Always quote verbatim in double quotes. If the issue is structural (e.g. a missing heading), write a short description instead.
- **Suggested change** — The corrected version in double quotes, or a clear instruction if a full rewrite is needed (e.g. "Split into two sentences" or "Add a heading before this paragraph").

---

#### What's Working Well

List 2–4 specific things the content does correctly. Be concrete — cite actual text or structure from the piece, not generic praise.

---

#### Category Summary

| Category | Status | Issue count |
|----------|--------|-------------|
| Voice & Tone | PASS/WARN/FAIL | 0 |
| Clarity & Conciseness | PASS/WARN/FAIL | 0 |
| Grammar & Language | PASS/WARN/FAIL | 0 |
| Punctuation | PASS/WARN/FAIL | 0 |
| Capitalization | PASS/WARN/FAIL | 0 |
| Numbers & Dates | PASS/WARN/FAIL | 0 |
| Formatting & Structure | PASS/WARN/FAIL | 0 |
| Inclusive Language | PASS/WARN/FAIL | 0 |
| Accessibility | PASS/WARN/FAIL | 0 |
| OpenMetadata Branding | PASS/WARN/FAIL | 0 |
| Global / Localization | PASS/WARN/FAIL/N/A | 0 |

Status key: PASS = no issues, WARN = minor issues only, FAIL = major or critical issues, N/A = category does not apply

---

#### Top 3 Priorities

| Priority | Fix |
|----------|-----|
| 1 | [Most impactful single change] |
| 2 | [Second most impactful change] |
| 3 | [Third most impactful change] |

---

## Important Behaviour Rules

- **Quote exact text.** The "Original text" column must always contain the verbatim phrase from the content — never a paraphrase. If the passage is long, quote the most relevant fragment (20 words or fewer).
- **Name the guideline precisely.** Every row must reference a specific rule from the OpenMetadata Writing Style Guide with its section number. "Tone" or "style" alone is not acceptable.
- **One issue per row.** Do not bundle multiple violations into one row even if they occur in the same sentence. Each violation gets its own row.
- **Never rewrite the whole document unprompted.** Offer to produce a clean revised version after delivering the report.
- **Context matters.** Legal disclaimers may use formal language intentionally. Inline code snippets follow code conventions, not prose rules. Use judgment and note exceptions.
- **If content is under 50 words**, note that the review is limited due to brevity and not all categories can be fully assessed.
- **For content intended for translation**, treat Global / Localization checklist items as Major severity rather than Minor.
