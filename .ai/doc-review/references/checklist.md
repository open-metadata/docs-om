# OpenMetadata Content Review Checklist

Full item-by-item checklist derived from the OpenMetadata Writing Style Guide.
Check every item. Mark each as PASS, FAIL, or N/A.

---

## Category 1: Voice & Tone

### 1.1 Brand Voice
- [ ] **Warm and clear** — Does the content feel like a knowledgeable colleague rather than a formal institution? Flag overly stiff or robotic phrasing.
- [ ] **Honest and confident** — Does it say what it means without overselling, hedging excessively, or obscuring issues?
- [ ] **Human and inclusive** — Is it written for real people, not a faceless audience?

### 1.2 Conversational Naturalness
- [ ] **Read-aloud test** — Would this sound natural spoken aloud? Flag anything that wouldn't be said in a meeting.
- [ ] **No corporate filler** — Flag: "synergize," "leverage" (when "use" works), "holistic approach," "move the needle," "circle back," "deep dive," "best-in-class."
- [ ] **No Latin abbreviations in body text** — Flag "i.e." (use "that is"), "e.g." (use "for example"), "etc." (use "and so on").
- [ ] **"Please" used sparingly** — Flag "please" outside genuine requests or apologies; don't use it to soften routine instructions.
- [ ] **No "let's" framing** — Flag "let's configure..." → "Configure..."

### 1.3 Tone Matching
- [ ] Is the tone appropriate for the content type?
  - Customer support: empathetic, patient, solution-focused
  - Technical docs: precise, neutral, instructional
  - Marketing: energetic, confident, benefit-led
  - Internal comms: friendly, direct, collegial
  - Incident/crisis: calm, factual, accountable

---

## Category 2: Clarity & Conciseness

### 2.1 Sentence Length & Complexity
- [ ] **Short sentences** — Flag sentences with more than two commas plus end punctuation. Suggest breaking them up.
- [ ] **One idea per sentence** — Flag sentences that try to do too much.
- [ ] **No modifier stacks** — Flag long chains of nouns used as modifiers (e.g., "extremely well thought-out Windows migration project plan").

### 2.2 Word Economy
- [ ] **No "you can"** — Flag "you can [verb]" and suggest replacing with the direct imperative or verb alone. E.g., "You can export the report" → "Export the report."
- [ ] **No "there is/are/were"** — Flag and suggest rewriting. E.g., "There are three options available" → "Three options are available."
- [ ] **No redundant phrases** — Flag:
  - "in order to" → "to"
  - "at this point in time" → "now"
  - "due to the fact that" → "because"
  - "prior to" → "before"
  - "subsequent to" → "after"
  - "with regard to" → "about"
  - "in the event that" → "if"
  - "on a regular basis" → "regularly"
- [ ] **"Lets you" over "allows you to"** — Flag "allows you to [verb]"; prefer the shorter "lets you [verb]."

### 2.3 Word Choice
- [ ] **Simple over complex** — Flag:
  - "utilize" → "use"
  - "initiate" → "start"
  - "facilitate" → "help"
  - "terminate" → "end" or "stop"
  - "endeavour" → "try"
  - "ascertain" → "find out"
  - "commence" → "start" or "begin"
- [ ] **Jargon check** — Is every technical term necessary and understandable to the target audience? Flag undefined jargon.
- [ ] **Consistent terminology** — Is the same concept always called the same thing? Flag synonyms used interchangeably for the same concept.
- [ ] **"Can" vs. "might" vs. "may"** — Use "can" for capability or permission, "might" for uncertain possibility. Flag "may" for either — it's ambiguous between the two.
- [ ] **"Because" vs. "since"** — Use "because" for causation. Reserve "since" for time-based meaning only ("since version 1.5," not "since it's faster").

### 2.4 Front-Loading
- [ ] **Key point first** — Does the most important information appear in the first sentence or paragraph?
- [ ] **Purpose clear early** — In emails and articles, is the purpose stated in the first two sentences?

---

## Category 3: Grammar & Language

### 3.1 Voice
- [ ] **Active voice preferred** — Flag passive constructions. E.g., "The file was rejected by the system" → "The system rejected the file."
- [ ] **Passive voice acceptable when** — the actor is unknown, or the action matters more than who did it (e.g., "The database was last updated in March"). Do not flag these.
- [ ] **No first-person "we/us/our" in reference or technical content** — Flag "we read the query log"; describe what the product does instead ("OpenMetadata reads the query log"). Second person ("you") is fine when addressing the reader directly.

### 3.2 Verbs
- [ ] **Strong verbs** — Flag verb-to-noun conversions: "make a decision" → "decide," "carry out an implementation" → "implement."
- [ ] **Imperative mood in instructions** — Instructions should use imperative: "Select the file," not "You should select the file."
- [ ] **Present tense where possible** — Especially for product descriptions and instructions.

### 3.3 Contractions
- [ ] **Use contractions in general content** — Flag missing contractions where formal phrasing sounds stiff: "it is" → "it's," "you will" → "you'll," "do not" → "don't."
- [ ] **No contractions in** legal, compliance, or highly formal documents (these should not be flagged).
- [ ] **No awkward contractions** — Flag "should've," "there'd," "would've" in professional content.

### 3.4 Sentence Structure
- [ ] **Standard word order** — Subject + verb + object. Flag inverted or convoluted structures.
- [ ] **Modifiers close to what they modify** — Flag dangling modifiers and misplaced "only."
- [ ] **No more than two clauses joined by and/or/but** — Flag run-ons; suggest splitting or using a list.

---

## Category 4: Punctuation

### 4.1 End Punctuation
- [ ] **Every sentence ends with a period** — Even two-word sentences.
- [ ] **One space after periods** — Flag double spaces.
- [ ] **No multiple exclamation marks** — Flag "!!" or "!!!".
- [ ] **Exclamation marks used sparingly** — Flag if more than one appears in a short document.

### 4.2 Commas
- [ ] **Oxford (serial) comma used** — "files, folders, and documents" not "files, folders and documents."
- [ ] **Comma after introductory clause** — Flag missing commas after opening subordinate clauses.
- [ ] **No comma splice** — Two independent clauses must not be joined by a comma alone without a conjunction.
- [ ] **No "&" as a stand-in for "and"** — Flag ampersands in prose or headings; reserve "&" for literal UI labels being referenced.

### 4.3 Colons and Semicolons
- [ ] **Colon before a list** — Used at the end of an introducing phrase, not a complete sentence that already contains a list.
- [ ] **First word after colon** — Capitalize if it begins an independent clause.
- [ ] **Avoid semicolons in general content** — Flag; suggest splitting the sentence.

### 4.4 Dashes and Hyphens
- [ ] **Em dash with no spaces** — "use pipelines—logical groups—to" not "use pipelines — logical groups — to."
- [ ] **No spaced en dashes used as em dashes** — Flag " – " used mid-sentence.
- [ ] **En dash for ranges** — "2020–2026," "pages 10–15" (not hyphens).
- [ ] **Hyphen in compound modifiers before a noun** — "well-known author" but "the author is well known."
- [ ] **No hyphen after -ly adverbs** — "a highly effective tool" not "a highly-effective tool."

### 4.5 Apostrophes
- [ ] **No apostrophe in plurals** — "PDFs" not "PDF's," "the 1990s" not "the 1990's."
- [ ] **Correct possessives** — "the team's results," "OpenMetadata's brand."

### 4.6 Quotation Marks
- [ ] **Periods and commas inside quotes** — Place commas and periods inside the closing quotation mark, as in "like this."
- [ ] **Colons and semicolons outside quotes.**
- [ ] **No scare quotes for emphasis** — Use precise wording instead of ironic quotes.

### 4.7 Parentheses
- [ ] **No important information in parentheses** — Some readers skip parenthetical content; don't hide anything the reader needs there.
- [ ] **Keep parenthetical asides brief** — If a parenthetical would run long (e.g., a list of code identifiers), split it into a separate sentence or use a dash instead.

---

## Category 5: Capitalization

### 5.1 Heading Case
- [ ] **Headings use title case on this site** — Capitalize all major words (e.g., "Bulk Import Test Cases"). This is a deliberate house style across the OpenMetadata docs — do not flag title-case headings as a violation.
- [ ] **List items start with a capital letter.**
- [ ] **No all-caps for emphasis** — Flag ANY WORD IN ALL CAPS used for emphasis. Italic is acceptable.
- [ ] **No all-lowercase as a style choice.**

### 5.2 Proper Nouns
- [ ] **Product and service names capitalized** — Flag lowercase product names.
- [ ] **"OpenMetadata" always capitalized** — Flag "openmetadata," "Openmetadata," or "OPENMETADATA."
- [ ] **Acronyms in full caps** — API, SLA, CRM (no mixed case like "Api").

### 5.3 What Not to Capitalize
- [ ] **Generic job titles lowercase** — "the engineering manager" (not "Engineering Manager") unless used as a formal title before a name.
- [ ] **Common tech terms lowercase** — "application," "platform," "database" (not "Platform" or "Database").
- [ ] **Spelled-out acronyms lowercase** — "application programming interface" not "Application Programming Interface."

---

## Category 6: Numbers & Dates

### 6.1 Numbers
- [ ] **Spell out zero through nine** — "three options" not "3 options" (unless in a technical/measurement context).
- [ ] **Numerals for 10 and above** — "15 users" not "fifteen users."
- [ ] **Numerals always for** measurements, percentages, version numbers, money, technical specs.
- [ ] **No sentence starting with a numeral** — Rewrite or spell out.
- [ ] **Commas in 4+ digit numbers** — "1,000" not "1000."

### 6.2 Dates
- [ ] **Month spelled out** — "May 12, 2026" not "5/12/2026" or "12/5/2026."
- [ ] **No ordinals in dates** — "June 1" not "June 1st."
- [ ] **En dash for date ranges** — "May 10–14, 2026."

### 6.3 Time
- [ ] **12-hour clock with AM/PM in capitals with a space** — "9:00 AM" not "9am" or "9:00am."
- [ ] **"noon" and "midnight"** — not "12:00 PM" or "12:00 AM."

### 6.4 Percentages & Currency
- [ ] **% symbol with numerals** — "45%" not "45 percent" (except at the start of a sentence).
- [ ] **Currency symbol with numeral** — "$500" not "500 dollars."

---

## Category 7: Formatting & Structure

### 7.1 Headings
- [ ] **Every section has a clear, descriptive heading.**
- [ ] **Parallel structure in headings** — Same grammatical form within the same section.
- [ ] **No period at end of headings** — Question marks are acceptable.
- [ ] **No heading immediately after another heading** with no body text between.

### 7.2 Lists
- [ ] **At least 2 items** — Single-item lists should be prose.
- [ ] **No more than 7 items** — Suggest grouping if more.
- [ ] **Parallel structure** — All items use the same grammatical form.
- [ ] **Introduced with a complete sentence or colon-ending phrase.**
- [ ] **No semicolons or commas at end of list items.**
- [ ] **Period only if items are complete sentences or complete an introductory fragment.**

### 7.3 Bold & Italic
- [ ] **Bold used only for** key terms on first use, UI element names, or critical warnings. Not for general emphasis.
- [ ] **No underline** except hyperlinks.
- [ ] **Italic used for** titles of works or introducing new technical terms.

### 7.4 Instructions
- [ ] **Numbered list for steps** — Not bullets, not prose.
- [ ] **One action per step.**
- [ ] **Imperative verb starts each step** — "Select," "Enter," "Open."
- [ ] **Location stated first in step** — "On the Settings page, select..."
- [ ] **Optional steps marked with "Optional:"** — Flag optional steps indicated by parentheses instead; use "Optional: ..." at the start of the step.
- [ ] **Goal-first phrasing where it reads naturally** — Prefer "To do X, do Y" over burying the goal at the end of the step.

### 7.5 Notices & Callouts
- [ ] **Used sparingly** — Flag more than one Note/Tip/Warning stacked back-to-back; overuse diminishes their effectiveness.
- [ ] **Right type for the content** — Note = non-critical, skippable information; Warning = risk of data loss, security issues, or other irreversible harm; Tip = optional helpful suggestion.
- [ ] **Not used for prerequisites** — Information the reader needs before starting belongs in the main flow, not a callout.
- [ ] **Not used for essential information** — If the reader can't succeed without it, it isn't a Note — put it in the body text.
- [ ] **Not used for cross-references** — Link to related content directly in the body text rather than via a callout.
- [ ] **Not used for procedural steps** — Full steps belong in the numbered instructions, not offset in a box.

---

## Category 8: Inclusive Language

### 8.1 Gender-Neutral Language
- [ ] **No gendered pronouns in generic references** — Flag "he," "his," "she," "her" when referring to unspecified individuals.
- [ ] **"You" preferred over third person** — Use direct address, such as "Access your account," not third person, such as "the user can access their account."
- [ ] **No "he/she" or "s/he" constructions.**
- [ ] **Singular "they" acceptable** — Flag only if the sentence becomes confusing.

### 8.2 People-First Language
- [ ] **Person before disability** — "a user who is blind" not "a blind user" (unless the individual/community prefers identity-first).
- [ ] **No pity language** — Flag "suffering from," "afflicted with," "victim of."
- [ ] **Disability mentioned only if relevant.**

### 8.3 Culturally Sensitive Language
- [ ] **No unconscious bias in technical terms** — Flag "master/slave" → "primary/secondary"; "whitelist/blacklist" → "allowlist/blocklist."
- [ ] **No idioms or colloquialisms** that may not translate or that assume shared cultural background.
- [ ] **No assumptions about holidays, sports, or political systems** unless directly relevant.

### 8.4 Age & Generational Language
- [ ] **No age stereotypes** — Do not assume older users cannot use technology or younger users lack professionalism.

---

## Category 9: Accessibility

### 9.1 Structure
- [ ] **Heading levels reflect hierarchy** — Don't use bold as a substitute for a heading.
- [ ] **No directional language as sole locator** — "the table on the left" → "the following table."
- [ ] **Descriptive link text** — Flag "click here," "read more," "learn more" without context. Suggest "Download the Q1 report" or "Learn more about data privacy."
- [ ] **Link text matches the destination** — Where reasonable, link text should match the title or heading of the page it points to.
- [ ] **No duplicate links** — Flag the same destination linked more than once on a page, unless linking to distinct sections.
- [ ] **"For more information, see [X]"** — Use this as the standard phrasing when a full sentence is dedicated to a cross-reference.
- [ ] **Punctuation outside link text** — Don't include trailing punctuation inside the link. Link text also isn't wrapped in quotation marks.

### 9.2 Images & Media (if described or included)
- [ ] **Alt text described or present** for all meaningful images.
- [ ] **No information conveyed only through color.**

### 9.3 Plain Language
- [ ] **Abbreviations and acronyms spelled out on first use** — "application programming interface (API)" not just "API."
- [ ] **Consistent terminology throughout** — No synonyms for the same concept.

### 9.4 Interaction Language
- [ ] **Generic interaction verbs** — "select" not "click," "enter" not "type," "activate" not "tap."

---

## Category 10: OpenMetadata Branding

### 10.1 Project Name
- [ ] **"OpenMetadata" — correct capitalization** — Flag "openmetadata," "Openmetadata," "OPENMETADATA," "Open Metadata" (as two words), or "OM" as a stand-in.
- [ ] **First mention in a document uses "OpenMetadata"** — Subsequent uses may also use "OpenMetadata."
- [ ] **No unofficial abbreviations** — Flag informal shorthand in prose (code identifiers and config keys are exempt).

### 10.2 Product Names
- [ ] **Exact registered product/feature names used** — No abbreviations, shortened forms, or unofficial variants.
- [ ] **Product names capitalized as proper nouns.**
- [ ] **Version numbers formatted correctly** — "OpenMetadata 1.5" not "OpenMetadata v1.5" or "OM 1.5."

### 10.3 Customer-Facing Tone
- [ ] **Customer addressed as "you"** — Not "the user," "the client," or third person in direct communications.
- [ ] **Error messages and notifications state result or action first** — "Your file was saved" not "File save operation completed successfully."
- [ ] **Error messages explain what went wrong + what to do next** — No raw error codes without explanation.
- [ ] **No unofficial taglines or slogans** — Only approved project language in external content.
- [ ] **No unapproved product claims** — Performance commitments require maintainer sign-off.

---

## Category 11: Global / Localization (apply when content will be translated)

- [ ] **No idioms or culture-specific expressions.**
- [ ] **No list items completing an introductory sentence fragment** — These are hard to translate.
- [ ] **No noun stacks** — Long modifier chains often can't be translated.
- [ ] **No humor, wordplay, or puns** in content intended for translation.
- [ ] **UI strings under 80 characters** where possible (translations are often longer).
- [ ] **Time zones specified** in international scheduling content.
