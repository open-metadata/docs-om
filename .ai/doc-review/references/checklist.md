# OpenMetadata Content Review Checklist

Review only changed user-facing content. Report only rules below, group repeated violations, and ignore personal preferences. Exempt code, commands, paths, identifiers, quoted text, and literal UI labels from prose rules.

**Critical** = incorrect, unsafe, contradictory, inaccessible, or unusable. **Major** = materially harms clarity, consistency, or task completion. **Exception: not flagged** = never report.

## Category 1: Voice & Tone

- [ ] **Clear technical voice** (Minor) — Be direct and neutral; avoid promotional language and first-person product voice (“we,” “us,” “our”).

## Category 2: Clarity

- [ ] **Clear and concise** (Minor) — State the purpose early; remove repetition and irrelevant detail.
- [ ] **Consistent terminology** (Major) — Use one verified name for each product, feature, field, and action.

## Category 3: Grammar & Instructions

- [ ] **Usable language** (Major) — Use correct grammar, direct imperatives for instructions, and active voice when it prevents ambiguity.
- [ ] **Purposeful passive voice** (Exception: not flagged) — Passive voice is acceptable when the actor is unknown, obvious, or unimportant.

## Category 4: Mechanics

- [ ] **Meaning is unambiguous** (Minor) — Flag spelling, punctuation, or sentence structure only when it changes meaning or impedes use.

## Category 5: Names & Headings

- [ ] **Official names are exact** (Critical) — Preserve verified names and capitalization; spell “OpenMetadata” correctly.
- [ ] **Heading structure is valid** (Major) — Use logical levels and title case.

## Category 6: Technical Values

- [ ] **Values are exact** (Major) — Verify versions, defaults, limits, ports, counts, units, and ranges against the PR evidence.

## Category 7: Procedures

- [ ] **Tasks are executable** (Major) — Put prerequisites first and keep steps complete, correctly ordered, and technically possible.
- [ ] **Procedure structure is clear** (Critical) — Number sequential steps; use parallel bullets for options or reference information.
- [ ] **Risks are explicit** (Major) — Warn about data loss, security exposure, downtime, or irreversible actions.

## Category 8: Inclusive Language

- [ ] **Language is respectful** (Minor) — Exclude discriminatory, gendered, ableist, demeaning, or biased language, except literal external names.

## Category 9: Accessibility

- [ ] **Content is accessible** (Minor) — Use descriptive valid links, useful image alt text, logical reading order, and more than position or color to convey meaning.

## Category 10: OpenMetadata Scope

- [ ] **Scope and claims are valid** (Major) — Don't present Collate features as OpenMetadata or make unsupported performance, security, compatibility, or availability claims.
- [ ] **Use OpenMetadata branding** (Critical) — Use OpenMetadata names, terminology, and assets; don't use Collate branding, logos, or product language in OpenMetadata documentation.

## Category 11: Localization

- [ ] **Global meaning is clear** (Major) — Avoid culture-specific assumptions and clarify dates, time zones, and units when ambiguous.

## Category 12: Technical & Logical Accuracy

- [ ] **No technical errors** (Critical) — Code, commands, schemas, APIs, configuration, links, navigation, and expected behavior must work with the available PR evidence.
- [ ] **Claims are internally consistent** (Major) — Check names, counts, versions, fields, defaults, availability, examples, and the PR description for contradictions.
- [ ] **Unknown is not wrong** (Exception: not flagged) — Request verification when evidence is missing; don't invent a contradiction.
