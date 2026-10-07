# OpenMetadata Content Review Checklist

Review only changed user-facing content. Report only rules below, group repeated violations, and ignore personal preferences. Exempt code, commands, paths, identifiers, quoted text, and literal UI labels from prose rules.

**Critical** = technical errors, contradictions, safety/accessibility risks, discriminatory language, or wrong branding. **Major** = essential terminology, grammar, heading structure, prerequisites, procedure clarity, or explicitly tagged formatting rules. **Minor** = other style, formatting, and editorial polish. **Exception: not flagged** = never report.

## Category 1: Voice & Tone

- [ ] **Clear technical voice** (Minor) — Be direct and neutral; avoid promotional language and first-person product voice (“we,” “us,” “our”).

## Category 2: Clarity

- [ ] **Clear and concise** (Minor) — State the purpose early; remove repetition and irrelevant detail.
- [ ] **Consistent terminology** (Major) — Use one verified name for each product, feature, field, and action.
- [ ] **Plain wording** (Minor) — Avoid corporate filler and Latin abbreviations: use “use,” “start,” “for example,” “that is,” and “and so on.”
- [ ] **Short sentences** (Minor) — Split sentences with more than two commas plus end punctuation.

## Category 3: Grammar & Instructions

- [ ] **Usable language** (Major) — Use correct grammar, direct imperatives for instructions, and active voice when it prevents ambiguity.
- [ ] **Purposeful passive voice** (Exception: not flagged) — Passive voice is acceptable when the actor is unknown, obvious, or unimportant.
- [ ] **Contractions fit the context** (Minor) — Use natural contractions in general prose; avoid awkward forms such as “should’ve.”
- [ ] **Formal wording is permitted** (Exception: not flagged) — Legal, compliance, and highly formal content need not use contractions.

## Category 4: Mechanics

- [ ] **Meaning is unambiguous** (Minor) — Keep sentence structure unambiguous; apply the explicit mechanics rules below.
- [ ] **No typos** (Minor) — Flag misspelled prose words.
- [ ] **Oxford comma** (Minor) — Use a comma before the final conjunction in a list.
- [ ] **Correct apostrophes and clauses** (Minor) — Avoid apostrophes in plurals and comma splices; use correct possessives.
- [ ] **Sentence punctuation** (Minor) — End sentences with periods, use one space afterward, and punctuate introductory clauses.
- [ ] **Restrained punctuation** (Minor) — Avoid unnecessary em dashes, semicolons, exclamation marks, scare quotes, and prose ampersands; use en dashes for ranges.
- [ ] **Correct hyphens and quotes** (Minor) — Hyphenate compound modifiers before nouns, not after “-ly”; place periods/commas inside quotes and colons/semicolons outside.

## Category 5: Names & Headings

- [ ] **Official names are exact** (Major) — Preserve verified names and capitalization; spell “OpenMetadata” correctly.
- [ ] **Title-case headings** (Major) — Capitalize major words in headings.
- [ ] **Heading introductions** (Minor) — Use descriptive, parallel headings without trailing periods; add body text before another heading or code block.
- [ ] **Capitalization** (Minor) — Start list items with capitals; preserve proper names without capitalizing generic technical terms.
- [ ] **Acronym capitalization** (Minor) — Use official uppercase forms, such as API.

## Category 6: Technical Values

- [ ] **Values are exact** (Major) — Verify versions, defaults, limits, ports, counts, units, and ranges against the PR evidence.
- [ ] **Number style** (Minor) — Spell out zero–nine and use numerals for 10+; technical values and measurements are exempt.
- [ ] **Technical numerals** (Minor) — Use numerals for measurements, percentages, versions, money, and specs; add separators to 4+ digit numbers.
- [ ] **Date/time format** (Minor) — Spell out months, use en dashes for date ranges, and write spaced uppercase AM/PM in 12-hour times.
- [ ] **Other numeric formatting** (Minor) — Avoid date ordinals and sentence-leading numerals; use “noon,” “midnight,” %, and currency symbols.

## Category 7: Procedures

- [ ] **Tasks are executable** (Major) — Put prerequisites first and keep steps complete, correctly ordered, and technically possible.
- [ ] **Procedure structure is clear** (Major) — Number sequential steps; use parallel bullets for options or reference information.
- [ ] **Risks are explicit** (Critical) — Warn about data loss, security exposure, downtime, or irreversible actions.
- [ ] **Optional step** (Minor) — Label optional steps “(Optional)” or “Optional:”; keep the form consistent within a procedure.
- [ ] **Step orientation** (Minor) — State the location first; use goal-first phrasing when natural.
- [ ] **List shape** (Minor) — Introduce lists, prefer 2–10 items or grouped lists, and use periods for complete sentences.
- [ ] **Bold before colon** (Major) — Write “**Example**:” rather than “**Example:**”.
- [ ] **Bold and underline** (Minor) — Reserve bold for first-use terms, UI names, and critical warnings; underline only hyperlinks.
- [ ] **Callouts fit their purpose** (Major) — Use Note for nonessential information, Warning for irreversible risk, and Tip for optional help.
- [ ] **Navigation separators** (Major) — Write “**Settings** > **Database**”, with each segment bold; do not use arrows.

## Category 8: Inclusive Language

- [ ] **Language is respectful** (Critical) — Exclude discriminatory, gendered, ableist, demeaning, or biased language, except literal external names.

## Category 9: Accessibility

- [ ] **Content is accessible** (Major) — Keep reading order usable; do not make essential instructions depend on inaccessible content. Apply specific link/image rules below.
- [ ] **Meaningful image descriptions** (Major) — Provide useful alt text for meaningful images; never convey information only through color.
- [ ] **Named locations** (Minor) — Do not use position alone, such as “on the left,” to identify content.
- [ ] **Acronyms on first use** (Minor) — Expand unfamiliar abbreviations and acronyms on first use.
- [ ] **Link wording** (Major) — Use descriptive text matching the destination; introduce full-sentence cross-references with “For more information, see [X]”.
- [ ] **Link formatting** (Minor) — Put trailing punctuation outside links.

## Category 10: OpenMetadata Scope

- [ ] **Scope and claims are valid** (Major) — Don't present Collate features as OpenMetadata or make unsupported performance, security, compatibility, or availability claims.
- [ ] **Use OpenMetadata branding** (Critical) — Present OpenMetadata with its names, terminology, and assets, not Collate branding. Permit accurate, intentional cross-product references (such as “managed by Collate”), comparisons, links, literal UI labels, and code identifiers (packages, environment variables, API fields, commands, and paths).
- [ ] **Customer-facing messages** (Minor) — Address the reader as “you” not users; state the result/action first and explain failures with a next step.
- [ ] **Approved product wording** (Minor) — Avoid unofficial abbreviations, taglines, and shortened product names.
- [ ] **Product version format** (Minor) — Write “OpenMetadata 2.0.4”, not “OpenMetadata v2.0.4” or unofficial shorthand.

## Category 11: Localization

- [ ] **Global meaning is clear** (Minor) — Avoid culture-specific assumptions and clarify dates, time zones, and units when ambiguous.
- [ ] **Translation-friendly prose** (Minor) — Avoid idioms, humor, wordplay, noun stacks, and list items completing sentence fragments; aim for UI strings under 80 characters.

## Category 12: Technical & Logical Accuracy

- [ ] **No technical errors** (Critical) — Code, commands, schemas, APIs, configuration, navigation instructions, and expected behavior must work with the available PR evidence. Link validity belongs to automated link checks.
- [ ] **Claims are internally consistent** (Critical) — Check names, counts, versions, fields, defaults, availability, examples, and the PR description for contradictions.
- [ ] **Unknown is not wrong** (Exception: not flagged) — Request verification when evidence is missing; don't invent a contradiction.
