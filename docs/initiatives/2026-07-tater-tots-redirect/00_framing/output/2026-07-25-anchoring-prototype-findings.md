# Anchoring prototype — findings

**Date:** 2026-07-25
**Type:** throwaway prototype (LOGIC branch of the `prototype` skill). No production code written.
**Code:** `tmp/prototype-anchoring/` — `anchoring.rb` (pure module), `tui.rb` (throwaway shell),
`sweep.rb` / `probe.rb` (evidence harnesses). `tmp/` is gitignored; see "Capturing this" below.

**Question:** when a reviewer selects text inside a published document and comments on it, how is
that selection stored so it still points at the right text later — and what happens when the
author publishes a new Release?

**Verdict:** the approach is sound. Anchor to the **source bytes** of a specific `(Release, path)`
with a **quote + prefix/suffix + offset + block index** composite, resolve through **ordered
tiers that each report how they succeeded**, and treat carry-forward as **minting a new anchor
against Release N+1** rather than mutating the original. Four defects surfaced while building it;
three were real design errors, and one of them was the exact plannotator failure reproduced in my
own first-cut model.

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

Four resolution states, all first-class in the data model:

| status | meaning | Viewer sees | Owner CLI sees |
| --- | --- | --- | --- |
| `exact` | offset + both context sides agree, uniquely | highlight in place | normal comment |
| `moved` | text found elsewhere, context corroborates | highlight + "text moved" badge | comment + `anchor: moved` |
| `ambiguous` | ≥2 equally-good candidates, nothing distinguishes them | unplaced tray | `UNPLACED`, with last-known-good |
| `orphaned` | quote gone, or context cannot confirm identity | unplaced tray with original quote | `ORPHANED`, still anchored on Release N |

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

### Source, not rendered HTML

Confirmed. Anchors point at the markdown **source** bytes, matching what the Release is
content-addressed to. `Release#manifest_sha256` + `ManifestEntry#path` → `Blob#sha256` already
resolves to an exact, unchanging byte sequence, so a source anchor against Release N is
permanently verifiable server-side. Projecting into the render is a display concern and can
change freely without invalidating stored anchors. Anchoring into rendered HTML would have made
every renderer change a silent data migration.

### Carry-forward across a republish: hybrid, with the anchor re-minted

The original anchor is **immutable and stays bound to Release N** — same discipline as
`attr_readonly` on `Release`. Viewing Release N always shows the comment exactly where it was
left, forever. Carrying forward *mints a new anchor* against Release N+1 when resolution
confidently places it, and records `orphaned` on N+1 when it does not. Nothing is ever lost or
overwritten; a Comment can be placed on N and orphaned on N+1 simultaneously, which is the honest
representation.

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
- **Release-scoped only (no carry-forward).** Honest and simple, and I nearly recommended it. But
  the sweep shows context-based carry-forward succeeding cleanly on the common cases (an author
  edits one section; comments on the other twelve should not all die). Rejecting carry-forward
  would discard that for a problem the orphan state already solves.

---

## What I did NOT test

- **Real markdown rendering or a browser.** No DOM, no selection API, no projection of a source
  anchor into rendered HTML. The projection direction is argued above but **not empirically
  verified** — it is the obvious next prototype, and it is where a browser-side surprise would
  live (e.g. selections that span rendered elements mapping back to non-contiguous source).
- **Non-markdown Releases.** Shortbread publishes arbitrary prebuilt HTML directories. This
  prototype assumed markdown source. Anchoring into a Release whose Blob *is* the HTML — with no
  separate source — is a genuinely different problem and is unaddressed.
- **Unicode, multi-byte, and grapheme clusters.** All offsets are Ruby character offsets over
  ASCII fixtures. Emoji, combining characters, and CRLF will need explicit decisions.
- **Whitespace normalization.** Anchors are byte-exact. A reformat (rewrapping prose, changing
  indentation) will orphan comments that a whitespace-normalized comparison would have kept.
  Probably the single highest-value follow-up.
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
implementation issue. The validated piece to lift later is `Anchoring` — the Struct plus
`capture` / `resolve` / `carry_forward` are pure and portable; `tui.rb`, `sweep.rb`, and
`probe.rb` are shell and should not survive.
