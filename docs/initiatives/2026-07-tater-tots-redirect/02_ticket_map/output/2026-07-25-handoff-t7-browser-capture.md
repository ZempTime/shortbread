# Handoff — #66: Validate Anchor capture in a real browser

**Ticket:** [#66](https://github.com/ZempTime/shortbread/issues/66) · **Parent PRD:** [#64](https://github.com/ZempTime/shortbread/issues/64)
**Blocked by:** nothing. On the frontier with [#65](https://github.com/ZempTime/shortbread/issues/65).
**Branch point:** `main` at `2163fb6`.

## Why this exists

Every anchoring result so far came from **Ruby operating on strings**. No browser has ever been
involved. The PRD's capture approach assumes a reviewer's live `Selection`/`Range` can be mapped
back to an offset in extracted text — and that assumption is **untested and load-bearing**.

If it is wrong, #65's capture layer changes shape. Doing this now is cheap; discovering it
mid-#65 is not. **A negative result is a valid and valuable outcome.**

Do not build product features here. This is a spike with a written outcome.

## Required reading, in order

1. `docs/initiatives/2026-07-tater-tots-redirect/00_framing/output/2026-07-25-anchoring-prototype-findings.md`
   — especially "Extracted-text anchoring for HTML Releases — validated" and "What I did NOT test".
2. The prototype code: `git checkout prototype/anchoring-2026-07-25 -- tmp/prototype-anchoring/`
   then read `extract.rb` (the extractor and its offset map) and `anchoring.rb` (`capture`/`resolve`).
3. `CONTEXT.md` — canonical vocabulary. **Anchor**, Release, Site, Comment, Blob. Note that
   "annotation" is explicitly banned as a synonym for Comment.

## What already exists

- `Extract.from_html(html)` returns `Extraction(text:, map:)` where `map[i]` is the source byte
  offset of extracted character `i`. Validated: the map round-trips exactly.
- `Anchoring.capture(source:, start_offset:, length:, ...)` builds an Anchor from a text offset.
- A validated sweep: 9 selections × 8 scenarios in `html_sweep.rb`, all markup-only churn holding
  except one known `<pre>` case.

What does **not** exist: anything that turns a browser `Selection` into `start_offset`.

## The question to answer

> When a reviewer drags across rendered content in a real browser, can the resulting DOM Range be
> mapped to the same character offset that `Extract.from_html` produces for that document — and
> does the Ruby extractor agree with a JavaScript one on the same bytes?

## Acceptance criteria (from the ticket)

1. A real browser selection maps to an offset in extracted text, verified against the Ruby
   extractor's output for the same document.
2. Selections spanning inline tags and block boundaries are covered.
3. Ruby and TypeScript extractors are shown to produce identical text and offset maps for the
   fixture set, **or the differences are enumerated**.
4. A written outcome states whether the PRD's capture approach survives unchanged, and what must
   change if not.

## Specific cases to drive

Use `tmp/prototype-anchoring/html_scenarios.rb`'s `H1` fixture — it already contains the awkward
shapes:

- A selection wholly inside one text node (baseline).
- A selection **crossing an inline tag** — e.g. starting before `<em>operator</em>` and ending
  after it. The prototype's selection (d) covers this in string space; confirm in DOM space.
- A selection that **is** the emphasised word only (selection (e)).
- A selection **spanning a block boundary** — a `<p>` into an `<h2>` (selection (i)).
- A selection inside `<pre>`, where whitespace is preserved rather than collapsed.
- A selection inside a table cell.
- A **backwards** selection (drag right-to-left). The prototype never considered direction.
- A selection whose endpoints land on whitespace that the extractor collapses. This is the case
  most likely to disagree, because collapsed whitespace has no 1:1 character in extracted text.

## Where the risk actually is

Ranked by likelihood of biting, from reading the extractor:

1. **Collapsed whitespace.** The extractor collapses runs of whitespace to one space. A DOM offset
   landing inside a collapsed run has no exact counterpart. Decide and document the rule.
2. **`<pre>` opting out of collapsing.** The extractor preserves whitespace there, so the mapping
   rule differs inside `<pre>` from everywhere else.
3. **Block-boundary newlines.** The extractor synthesises `\n` at block edges; those characters
   exist in extracted text but correspond to a tag, not to any rendered character a user can
   select.
4. **`display:none` / CSS-hidden text.** The extractor only skips `script`/`style`/`head`/`title`
   by tag name. CSS-hidden text is extracted but not visible or selectable in a browser.
5. **Entities.** `&mdash;` decodes to one character mapped to the `&` position; verify a selection
   starting there behaves.

## Boundaries

- **No product code.** No changes under `app/`, `lib/`, `cli/`, or `db/`.
- Do **not** implement the Comment model, the API, or the review UI — that is #65.
- Do **not** claim #65 as well. If #65 is already claimed by another session, coordinate before
  touching shared files; this ticket should touch only test and fixture surfaces.
- Keep any throwaway harness out of `app/`.

## Deliverable

Post the written outcome as a comment on [#66](https://github.com/ZempTime/shortbread/issues/66),
stating plainly:

- whether a browser selection maps cleanly to extracted-text offsets;
- the rule adopted for each ambiguous case above;
- whether the Ruby and JS extractors agree, with any differences enumerated;
- **whether #65's capture approach survives unchanged, and if not, exactly what must change.**

If the approach does not survive, say so directly and stop — do not attempt to redesign the anchor
model in this ticket. Re-scoping #65 is a separate decision.

## Context you should know

- Stack is React 19, Tailwind 4, Inertia, Vite — already in `package.json`. `app/frontend/pages/`
  is empty; there is no frontend yet, so pick a browser-driving approach that does not require
  building the review UI first.
- The `prototype/anchoring-2026-07-25` branch is throwaway evidence, not product. Lift ideas from
  it; do not merge it.
- Local Postgres: `bin/db start` then `bin/db prepare`. Four `production_worker_health` black-box
  errors are pre-existing on `main` (unset `SHORTBREAD_DATABASE_HOST`) and are not yours.
