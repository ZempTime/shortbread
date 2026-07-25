# T7 outcome — Anchor capture validated in a real browser

**Ticket:** [#66](https://github.com/ZempTime/shortbread/issues/66) · **Parent:** [#64](https://github.com/ZempTime/shortbread/issues/64)
**Date:** 2026-07-25 · **Branch point:** `main` at `2b5d83d`
**Harness:** `test/browser_capture/` — headless Chrome via the existing Capybara/selenium-webdriver stack.

## Verdict

**The PRD's capture approach survives unchanged.** A live `Selection`/`Range` maps cleanly to an
offset in extracted text, and the offset a browser produces selects the identical text in the Ruby
extraction. 12 of 13 driven cases pass; the 13th is a real finding but not a capture failure.

**#65 is not re-scoped.** Three constraints below must be honoured when its capture layer is built.

## What was run

Real Chrome, real `Selection` objects built with `setBaseAndExtent`, against the `H1` fixture from
`tmp/prototype-anchoring/html_scenarios.rb` served as a document so the browser applied its own
whitespace and visibility rules.

| # | Case | Result |
|---|---|---|
| a | Wholly inside one text node | ✓ |
| b/c | Repeated sentence, 1st and 2nd occurrence | ✓ both, distinguished correctly |
| d | Crosses an inline `<em>` boundary | ✓ |
| e | Is exactly the emphasised word | ✓ |
| f | A heading | ✓ |
| g | Inside `<pre>` (whitespace preserved) | ✓ |
| h | A table cell | ✓ |
| i | Spans a block boundary (`<p>` into `<h2>`) | ✓ |
| j | **Backwards drag** (right-to-left) | ✓ |
| k | Endpoints on collapsed whitespace | ✓ |
| l | Starts at an entity (`&mdash;`) | ✓ |
| m | CSS-hidden text | ✗ — see finding 1 |

Every captured Anchor round-tripped through `Anchoring.capture` → `Anchoring.resolve` against the
same document at `EXACT`, confidence 1.00.

## Extractor agreement (criterion 3)

**Ruby and the JS twin produce byte-identical text and offset maps for the fixture** — 577
characters, no divergence.

They did not start that way. The first run diverged at character 23 because `extract.rb` scans
tags linearly and therefore emits a block break on a **closing** tag as well as an opening one; a
DOM walker that breaks only on entering an element lets the whitespace after `</h1>` survive as a
space, desyncing every subsequent offset. The JS twin was corrected to match. This is exactly the
class of silent client/server disagreement the conformance suite exists to catch, and it was found
within one run of having a browser in the loop.

## Findings

### 1. CSS-hidden text is unreachable but harmless — and constrains the extractor choice

Both extractors emit `display:none` and `visibility:hidden` text, because both skip by tag name
only. No browser will let a reviewer select it.

This does **not** corrupt capture. Hidden text shifts subsequent offsets (354 → 378 in the probe)
but shifts them *identically on both sides*, so client and server stay in lockstep and the anchor
still verifies against the Blob.

It survives only because the JS twin deliberately ignores CSS. The failure mode is real if that
changes:

```
innerText includes hidden: false      ruby includes hidden: true
innerText index of "Retries are capped": 359
ruby      index of "Retries are capped": 378   → 19-character divergence
```

**Constraint for #65:** the client extractor must walk the DOM with the same tag-name rules as the
Ruby extractor. It must **not** use `innerText`, `getClientRects`, or any CSS-aware visibility
test. Doing so silently breaks server-side verification for every anchor after a hidden element.

### 2. Collapsed whitespace — rule adopted, and it is benign

A DOM position inside a collapsed whitespace run has no 1:1 character in extracted text. The run
`"us\n      roll"` is 3 DOM characters mapping to 1 extracted space, and position within the run
selects between two adjacent offsets (102 = the collapsed space, 103 = `r` of "roll").

**Rule adopted:** both endpoints move *inward onto real content* — a start endpoint takes the first
extracted character at or after the DOM position, an end endpoint the last at or before it.

The ambiguity is benign. It only decides whether a leading space is inside the quote, and **both
variants produced a quote matching `selection.toString()` exactly and resolved `EXACT` at 1.00**.
This was the risk ranked most likely to bite; it does not.

### 3. Block-boundary newlines are synthesised, and selections cross them correctly

The fixture's extracted text contains 12 synthesised `\n` characters that correspond to a tag, not
to anything selectable. A cross-block selection maps to a slice *containing* one:

```
extracted slice:    "halfway through.\nFailure modes"
selection.toString: "halfway through.\n\nFailure modes"
```

Note the arity difference — the browser reports two newlines where extraction has one. The stored
quote is the extracted form, which round-trips and resolves `EXACT`. **Constraint for #65:** the
quote must be taken from the extraction, never from `selection.toString()`.

### 4. `<pre>`, entities, and backwards selections all behave

- **`<pre>`** — a selection spanning its preserved newline round-tripped exactly. The mapping rule
  differs inside `<pre>` (whitespace is content) but needed no special handling on the capture side.
- **Entities** — a selection starting immediately after `&mdash;` mapped correctly; the decoded
  character maps to the `&` position and nothing downstream shifted.
- **Backwards drags** — the case the prototype never considered. `Selection` reports `anchorNode`
  after `focusNode`, and normalising by `Math.min`/`Math.max` on the mapped endpoints handles it.
  **Constraint for #65:** normalise direction at capture; do not assume `anchor` precedes `focus`.

## Answers to the acceptance criteria

1. **A real browser selection maps to an offset in extracted text, verified against the Ruby
   extractor** — yes, 12/13 cases, all resolving `EXACT` at 1.00.
2. **Selections spanning inline tags and block boundaries covered** — yes, cases d, e, i.
3. **Ruby and TypeScript extractors produce identical text and offset maps** — yes, after
   correcting the JS twin's closing-tag block break. The one divergence found is enumerated above.
4. **Written outcome** — this document. The capture approach survives unchanged.

## What this did NOT test

Carried forward from the prototype's own list; still open:

- **A real HTML parser.** `extract.rb` is a hand-rolled scanner and the JS twin mirrors its quirks
  deliberately. A production extractor on both sides must be re-validated against this harness.
- **Unicode, multi-byte, grapheme clusters.** All fixtures are ASCII. Offsets are character
  offsets in both languages, which is *not* the same unit for astral-plane characters.
- **Shadow DOM, `<template>`, SVG/MathML, script-injected content.** Untouched.
- **`white-space: pre-wrap` / `pre-line` CSS on non-`<pre>` elements**, which would make the
  browser preserve whitespace the extractor collapses. Related to finding 1 and worth a decision.
- **Selections inside iframes**, and multi-Range selections (Firefox permits them; Chrome does not).

## Harvest

Per the ticket, the extractor-agreement check promotes into T2's conformance matrix. The harness in
`test/browser_capture/` is the natural seed: it already drives both extractors over one fixture and
diffs them, which is the shape T2 needs.

## Boundaries honoured

No changes under `app/`, `lib/`, `cli/`, or `db/`. No migrations. No product code. Test and fixture
surface only. #65 not claimed. `tmp/prototype-anchoring/` was checked out from the throwaway branch
for reference and is gitignored.
