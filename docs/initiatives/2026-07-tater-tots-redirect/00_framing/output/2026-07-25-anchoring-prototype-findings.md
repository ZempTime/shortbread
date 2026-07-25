# Anchoring prototype — findings

**Date:** 2026-07-25
**Type:** throwaway prototype (LOGIC branch of the `prototype` skill). No production code written.
**Code:** `tmp/prototype-anchoring/` — `anchoring.rb` (resolution core) and `extract.rb`
(HTML/markdown → visible text) are the portable modules; `tui.rb` is a throwaway shell; `sweep.rb`,
`probe.rb`, `html_sweep.rb`, `scenarios.rb`, `html_scenarios.rb` are evidence harnesses.
`tmp/` is gitignored; see "Capturing this" below.

**Question:** when a reviewer selects text inside a published document and comments on it, how is
that selection stored so it still points at the right text later — and what happens when the
author publishes a new Release?

**Verdict:** the approach is sound. Anchor to a specific `(Release, path)` with a **quote +
prefix/suffix + offset + block index** composite, and resolve through **ordered tiers that each
report how they succeeded**. Four defects surfaced while building it; three were real design
errors, and one of them was the exact plannotator failure reproduced in my own first-cut model.

**Two decisions were taken after the prototype ran and supersede parts of it:**

1. **Release-scoped, not carry-forward** — annotations belong to the Release they were made on;
   continuity comes from a diff view. See "Decision: Release-scoped" below.
2. **HTML Releases are in v1**, anchoring to *extracted visible text* rather than source bytes.
   Subsequently **validated** against markup churn — see "Extracted-text anchoring" below.
3. **Anchoring is computed on both client and server**, deliberately duplicated across TypeScript
   and Ruby, because the CLI feedback path has no browser.

---

## Recommended anchor model

```ruby
Anchor = Struct.new(
  :release_number, :path,        # which immutable document this was captured against
  :quote,                        # the exact selected text
  :prefix, :suffix,              # 32 chars either side — the disambiguator
  :start_offset,                 # character offset into the source
  :block_index, :block_offset    # structural position, tie-breaker only
)
```

Four resolution states, all first-class in the data model. Within its own Release, an anchor
resolves to place the highlight. Against a *later* Release, the
same resolution runs to classify the comment for the diff view:

| status | meaning | within its own Release | in the Release N→N+1 diff view |
| --- | --- | --- | --- |
| `exact` | offset + both context sides agree, uniquely | highlight in place | "text unchanged" |
| `moved` | text found elsewhere, context corroborates | highlight in place | "text unchanged, moved in the document" |
| `ambiguous` | ≥2 equally-good candidates, nothing distinguishes them | unplaced tray | "cannot tell — review manually" |
| `orphaned` | quote gone, or context cannot confirm identity | unplaced tray with original quote | "text you changed" |

`ambiguous` and `orphaned` are informational in the diff view, not a queue of things to rescue —
nothing is being placed on N+1, so there is nothing to fix. They tell the author which parts of
the previous conversation their edit invalidated.

### Why each field earns its place

- **Quote** — the only thing that survives a re-render or a reflow. Necessary, nowhere near
  sufficient.
- **Prefix/suffix (32 chars)** — this is what does the actual work. It is the difference between
  the two design-axis-4 cases: a repeated string resolved correctly (2/2 context match) versus a
  coin flip. plannotator has no equivalent and that is its central defect.
- **Offset** — earns its place as *corroboration*, not as a locator. In the model it is only
  trusted when context independently agrees, and it serves as a legitimate tie-break when a
  document has genuinely symmetric duplicates but has not changed.
- **Block index** — earns its place narrowly, as a tie-breaker when two candidates have identical
  context. It resolved the duplicated-verbatim-block case. I nearly cut it; the pathological
  scenario 7 is what kept it.

### Source, not rendered HTML — for markdown Releases

> Scoped by the later decision to support HTML Releases in v1. This section's conclusion holds
> for **markdown** Releases. For prebuilt HTML Releases there is no separate source layer; the
> approach there is extracted-text anchoring, validated below.

Confirmed for markdown. Anchors point at the markdown **source** bytes, matching what the Release
is content-addressed to. `Release#manifest_sha256` + `ManifestEntry#path` → `Blob#sha256` already
resolves to an exact, unchanging byte sequence, so a source anchor against Release N is
permanently verifiable server-side. Projecting into the render is a display concern and can
change freely without invalidating stored anchors. Anchoring into rendered HTML would have made
every renderer change a silent data migration.

### Across a republish: Release-scoped, with resolution used for a diff view

> **Decided 2026-07-25, after the prototype.** This section supersedes the prototype's original
> recommendation of hybrid carry-forward. See "Decision: Release-scoped" below for the reasoning.

Annotations belong to the Release they were made against, period. Publishing Release N+1 starts
with no annotations. Continuity comes from a **diff view** between N and N+1, not from
re-anchoring.

The anchor is **immutable and stays bound to Release N** — same discipline as `attr_readonly` on
`Release`. Viewing Release N always shows its comments exactly where they were left, forever.

Resolution is still needed, but for **classification rather than placement**: to tell the author
"2 of these 12 comments touch text you changed, 10 don't," each Release N anchor is resolved
against Release N+1 and its status reported. No new anchor is minted and nothing is painted on
N+1.

---

## What each required scenario actually did

Driven across 8 selections × 7 scenarios (`sweep.rb`).

1. **Reload, same Release** — `EXACT` at confidence 1.00 for all 8 selections. Stable.
2. **Unrelated earlier paragraph edited (everything shifts)** — `MOVED` at 1.00 for text with
   intact context; offsets were stale by 76 chars and context carried it correctly. Selections
   whose quote *spanned* the edited region correctly `ORPHANED`.
3. **The annotated text itself edited** — `ORPHANED` for the directly-edited selection (h).
   Neighbouring selections resolved `MOVED`/`EXACT` correctly. This is the right split: the
   comment on the changed sentence needs a human, its neighbours do not.
4. **Annotated text deleted entirely** — `ORPHANED`. This is the case that exposed the worst
   defect (below).
5. **Repeated string** — R1 deliberately contains "We must handle the case where the disk fills
   up." twice. Anchoring the first and the second each resolved to *its own* occurrence at 1.00,
   distinguished purely by suffix. A quote-only model would have collapsed both onto the first.
6. **Republish reordering the two repeated blocks** — the interesting one. Context follows the
   text; offset and block index do not. Resolution correctly tracked the *semantic* occurrence to
   its new position rather than keeping the offset.
7. **Heading / code block / table cell** — all three anchor and resolve identically. Nothing about
   markdown structure required special handling, because anchoring is over source bytes and never
   consults a parse tree except for the block tie-break.
8. **Overlapping annotations** — selection (g) deliberately overlaps (a). They resolve
   independently with no interference; the model has no concept of collision because anchors are
   read-only ranges, not owned regions. Rendering overlapping highlights is a UI problem, not an
   anchoring one.

---

## Defects found (the actual value of the prototype)

**1. Silent relocation onto different text — the plannotator failure, reproduced.**
My first cut treated "only one occurrence survives" as sufficient to relocate. Scenario 4 deletes
the entire "Failure modes" section, including the sentence a reviewer commented on. An *identical*
sentence exists under "Retry policy". The model reported `MOVED`, confidence 0.50, `0/2 context
sides match` — and moved the reviewer's comment onto a different section's sentence. Silently.

Fix: a **confidence floor**. If neither context side agrees *and* the text has moved, orphan
instead of relocating. A comment parked in a tray is recoverable; a comment silently attached to
the wrong paragraph is worse than a lost one, because nobody knows to doubt it.

**2. `exact` claimed without checking rivals.** Tier 1 returned `exact` at 1.00 the moment the
recorded offset still matched, without looking at whether another occurrence scored equally well.
On symmetric duplicates that is a coin flip that happened to land right. Fix: tier 1 must confirm
the position is *uniquely* best before claiming `exact`.

**3. `ambiguous` was unreachable.** It only fired when context scored 0/2 — but 0/2 is the
*orphan* case after fix 1, so the state was dead code. Real ambiguity is two candidates scoring
*equally well*. Rewritten to trigger on ties at any score, with proximity permitted as a
tie-break only when the anchor's own offset is one of the tied candidates. Verified reachable
(`probe.rb`, defect 3b).

**4. Fixture bug in my own scenario 2.** My "unrelated earlier paragraph" edit overlapped one
selection's quote, so an expected `MOVED` came back `ORPHANED`. Worth recording because it is the
failure mode of this *kind* of test: it is easy to write a scenario that does not test what its
name claims.

---

## What I would reject, and why

- **Quote-only (no context).** Fails scenario 5 outright. This is plannotator's effective model
  once its DOM positions go stale.
- **Offset-only / DOM-position-only.** Fails scenario 2 completely — an edit anywhere earlier in
  the document invalidates every anchor after it. plannotator trusts exactly this by default
  (`verifyRestoredContent` defaults to false).
- **Structural path as the primary anchor** (block index + offset within block). Fails scenario 6:
  reordering blocks moves every anchor to the wrong content while looking perfectly valid. Good
  tie-breaker, terrible primary.
- **Fuzzy/similarity matching (diff-match-patch) as a recovery tier.** Deliberately rejected for
  now. It converts a clean `orphaned` into a plausible-looking wrong answer, and the threshold
  becomes a permanent tuning liability. The immutable Release means the reviewer's original
  context is never lost, so an orphan is always recoverable by hand — a much better failure mode.
  Revisit only if orphan rates prove painful in practice.
- **Hybrid carry-forward.** This is what the prototype originally recommended, and it was
  **rejected in favour of Release-scoped** — see below. The sweep did show context-based
  carry-forward succeeding on the common cases, but succeeding-in-a-prototype is a weaker claim
  than it looks: every defect found here was a carry-forward defect, and each was a wrong
  *placement* rather than a missing one.

---

## Decision: Release-scoped (2026-07-25, post-prototype)

The prototype recommended hybrid carry-forward. After reviewing it we chose **Release-scoped**
storage with a diff view. Recorded here because the prototype's own text argues the other way.

**Why.** Storage is Release-scoped in *both* models — carry-forward mints a new anchor rather
than mutating the original, so it was never a different data model, only a read-time convenience
layered on top. That makes carry-forward a deferrable feature, not a foundational choice, and it
can be added later with no migration. Given that, the question became "do we run the re-resolve
step at publish time yet," and the answer for v1 is no:

- Every defect the prototype found was a carry-forward defect, and each produced a *wrong
  placement* rather than a missing one. Release-scoped cannot produce them.
- A comment on Release 3's wording is about Release 3's wording. Carrying it onto Release 4
  quietly asserts it still applies, which is often false.
- With HTML Releases now in v1 scope, carry-forward would have to survive republishes where the
  markup changed *and* the text moved — a combination the prototype never tested.

**What it costs.** The conversation does not automatically continue across a republish. In the
motivating case — twelve comments on Release 3, the author fixes two and publishes Release 4 —
Release 4 starts empty and the ten still-applicable comments are not re-shown in place. The diff
view mitigates this by telling the author which of the twelve their edit invalidated, but the
reviewer does not see their prior highlights on the new Release. **If this proves painful in
practice, carry-forward is the designed remedy and the stored anchors already support it.**

**Consequences for the model.**

- `capture` and `resolve` are kept as-is, and the four states are kept.
- `carry_forward` is dropped. Nothing mints an anchor against a Release it was not made on.
- Anchors store the full composite (quote + prefix + suffix + offset + block index) even though
  Release-scoped placement alone needs less. Those fields are what a future carry-forward and the
  present diff view both consume; storing less now would mean re-annotating history later.
- The `orphaned` state stays in the schema even though v1 never needs to rescue anything. The
  framing was emphatic on this and it holds: retrofitting a state the UI never had to handle is
  exactly where silent drops appear.
- The confidence floor (defect 1) still matters. Without it the diff view would report a comment
  as "text unchanged" when its text was deleted and an identical string elsewhere matched.

`CONTEXT.md` defines a **Feedback Thread** as spanning a Site's Releases. Release-scoped
*anchors* do not contradict that — the Thread remains one chronological conversation; only the
highlight placement is Release-bound.

---

## Extracted-text anchoring for HTML Releases — validated

HTML Releases are in v1. Their Blob *is* the HTML, so there is no source layer to anchor to. The
approach is to anchor to **extracted visible text plus context**, making markup invisible to the
anchor. Markdown is extracted the same way, so both document kinds land in one text space and the
validated resolution core serves both unchanged.

**Result: the bet holds.** `extract.rb` + `html_sweep.rb`, 9 selections × 8 scenarios against a
prebuilt HTML fixture. Markup-only scenarios must resolve `exact`/`moved`, since the visible text
did not change.

| scenario | result |
| --- | --- |
| Byte-identical republish | all 9 `EXACT` 1.00 |
| `<em>` → `<strong>` | all 9 `EXACT` 1.00 |
| Classes + wrapper divs added | all 9 `EXACT` 1.00 |
| Whole document minified | 8/9 `EXACT` 1.00 — one failure, below |
| Entities introduced (`&mdash;`) | all 9 resolved, `MOVED` (text genuinely shifted) |
| Content changes (edit / delete / expand) | behaved as in the markdown sweep |

Specifically confirmed:

- **Selections spanning tag boundaries survive.** Selection (d) crosses an `<em>`, (e) *is* the
  emphasised word, (i) spans a `<p>` into an `<h2>`. All resolve `EXACT` through markup churn.
  This was the main risk in extracted-text anchoring and it did not materialise.
- **The text-offset → source-offset map round-trips.** Every extracted offset points back at the
  identical bytes in the original HTML, so an anchor stored in text space can still be verified
  against the content-addressed Blob.
- **`<script>`, `<style>` and `<title>` never leak into the extracted text.**

### The one failure: code blocks vs. reformatting

A comment inside a `<pre>` block **orphans when the document is minified**. The extractor
preserves whitespace inside `<pre>` (correct — browsers do), but minification rewrites the `<pre>`
contents too, so `def provision(site)\n  site.releases…` becomes `def provision(site)
site.releases…`. The surrounding context genuinely changed, so `orphaned` is the *correct*
verdict — but it means **code-block comments are materially more fragile than prose comments**
against a generator or formatter change. Prose survives reformatting because the extractor already
collapses whitespace there; `<pre>` opts out of that protection by design.

Not a blocker, and not a bug to fix in the anchor. It is a property to know about, and it argues
for the whitespace-normalization follow-up being scoped to *include* a decision about `<pre>`.

### Where this runs: both client and server

**Decided.** `Anchoring` + `Extract` are implemented twice — once in TypeScript, once in Ruby —
because the two callers have genuinely different needs:

| operation | where | why |
| --- | --- | --- |
| Reviewer selects text → capture anchor | **client** | only the browser knows what was visible and selected |
| Store the anchor | **server** | it is part of an append-only Comment |
| Resolve for display within one Release | **client** | no round trip needed |
| Resolve for the Release N→N+1 diff view | **server** | needs both Releases' bytes |
| Resolve for `shortbread feedback pull` | **server** | no browser exists in the CLI path |

The CLI path is what makes server-side resolution non-optional: `feedback pull` is a Go client
hitting the HTTP API, and without server-side resolution it can report *what* was said but not
*where*. Server-side resolution is also what lets an anchor be **verified** against the immutable
Blob rather than trusted — the property that distinguishes this from plannotator's model.

The duplication is a real cost. It is bounded by the modules being small and pure (~200 lines, no
I/O), and the sweep harnesses are the shared conformance suite: both implementations must produce
identical statuses across the same fixture matrix.

**Not yet decided:** whether the server resolves eagerly at publish time or lazily on read. Lazy
fits Release-scoped well — nothing needs resolving until someone opens the diff view or pulls
feedback — and avoids a publish-time pass entirely.

## What I did NOT test

- **A real browser.** Still the largest gap. Extraction and resolution were validated against HTML
  *strings* in Ruby, not against a live DOM. What remains untested is the capture side: a real
  `Selection`/`Range` from a reviewer dragging across rendered content, mapped back to an offset
  in the extracted text. The string-level evidence is encouraging — selections spanning tag and
  block boundaries resolve correctly — but a browser can still surprise here (shadow DOM,
  `white-space` CSS altering what "visible text" means, content injected by script after load).
- **A real HTML parser.** `extract.rb` is a hand-rolled scanner, not a parser. It handles the
  fixture's tags, entities, `<pre>`, and skip-elements, but has no story for malformed markup,
  CDATA, SVG/MathML, or `<template>`. A production extractor would use a real parser, and its
  output would need to be re-validated against this same sweep.
- **Client/server extractor agreement.** The decision to compute in both places means a Ruby and a
  TypeScript extractor must produce **byte-identical** text and offset maps, or anchors captured
  in the browser will not resolve on the server. Nothing tests this yet; the sweep matrix is the
  natural conformance suite.
- **Unicode, multi-byte, and grapheme clusters.** All offsets are Ruby character offsets over
  ASCII fixtures. Emoji, combining characters, and CRLF will need explicit decisions.
- **Whitespace normalization — partially resolved.** For HTML this is now handled: the extractor
  collapses whitespace the way a browser renders it, which is why minification left 8 of 9 anchors
  intact. Two pieces remain: (a) **markdown** anchors are still byte-exact, so rewrapping prose
  will orphan them — markdown should probably get the same collapsing treatment; (b) **`<pre>`
  content deliberately opts out** of collapsing, which is why the one minification failure landed
  there. Scoping this follow-up must include an explicit decision for code blocks.
- **Performance.** `all_occurrences` is a naive scan per anchor. Fine for plans; unmeasured on
  large documents with many comments.
- **Concurrency, persistence, auth, threading model.** Out of scope by design — no database, no
  `app/` code, per the handoff boundaries.
- **The 32-character context window is unjustified.** It worked for every fixture; I did not test
  where it breaks.

---

## Boundaries honoured

No changes under `app/`, `lib/`, `cli/`, or `db/`. No migrations. No PRD written or amended.
Nothing renamed (Tater Tots deferred). Shortbread v1 ticket graph untouched. Vocabulary follows
`CONTEXT.md` — Release, Site, Comment, Manifest Entry, Blob.

## Capturing this

`tmp/` is gitignored, so the prototype is currently local-only. Per the `prototype` skill it
should be committed to a throwaway branch as a primary source, with a pointer left on the
implementation issue. Branch: **`prototype/anchoring-2026-07-25`**.

The pieces to lift later are `Anchoring` (the Struct plus `capture` / `resolve` — **not**
`carry_forward`, which the Release-scoped decision drops) and `Extract` (visible-text extraction
plus the offset map). Both are pure and portable, and both need a TypeScript twin.

`tui.rb` is shell and should not survive. The harnesses (`sweep.rb`, `html_sweep.rb`, and their
fixture files) **should** survive in some form — they are the conformance suite that keeps the
Ruby and TypeScript implementations in agreement.
