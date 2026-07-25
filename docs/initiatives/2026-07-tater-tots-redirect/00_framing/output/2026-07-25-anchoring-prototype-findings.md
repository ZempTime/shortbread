# Anchoring prototype — findings

**Date:** 2026-07-25
**Type:** throwaway prototype (LOGIC branch of the `prototype` skill). No production code written.
**Code:** `tmp/prototype-anchoring/` — `anchoring.rb` (pure module), `tui.rb` (throwaway shell),
`sweep.rb` / `probe.rb` (evidence harnesses). `tmp/` is gitignored; see "Capturing this" below.

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
   This is **not yet validated** — see "Open: extracted-text anchoring" below.

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

Within its own Release, an anchor resolves to place the highlight. Against a *later* Release, the
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
> for **markdown** Releases. For prebuilt HTML Releases there is no separate source layer, and
> the chosen approach is extracted-text anchoring — unvalidated, see "Open" below.

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

## What I did NOT test

- **Real markdown rendering or a browser.** No DOM, no selection API, no projection of a source
  anchor into rendered HTML. The projection direction is argued above but **not empirically
  verified** — it is the obvious next prototype, and it is where a browser-side surprise would
  live (e.g. selections that span rendered elements mapping back to non-contiguous source).
- **Prebuilt HTML Releases.** This prototype assumed markdown source throughout. HTML Releases
  were subsequently put in v1 scope; the approach is described under "Open" below and is **not
  validated**. This is the largest outstanding risk in the model.
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

## Open: extracted-text anchoring for HTML Releases

HTML Releases are in v1. Their Blob *is* the HTML, so there is no source layer to anchor to. The
chosen approach is to anchor to **extracted visible text plus context** — markup invisible to the
anchor, so `<em>` becoming `<strong>` or a class being added leaves it intact.

If markdown is *also* extracted to visible text, both document kinds land in one text space and
the validated resolution core serves both unchanged. That is the appeal, and it is the reason to
prefer it over raw HTML byte offsets (where a selection spanning a tag puts markup inside the
quote, and any reformat orphans everything).

**None of this is validated.** A partial extractor exists at `tmp/prototype-anchoring/extract.rb`
on the prototype branch; it was written but never exercised. The open questions:

1. Does extracted text stay stable across realistic markup churn — reformatting, wrapper divs,
   changed classes, a different generator version?
2. Does the text-offset → source-offset map survive well enough to verify an anchor against the
   content-addressed Blob?
3. What does a reviewer's DOM selection map back to when it spans element boundaries?
4. Whitespace collapsing is doing real work in the extractor. How much does that widen or narrow
   the whitespace-normalization problem noted above?

Question 3 needs a browser and is the UI-branch prototype the original findings called for.
Questions 1, 2 and 4 can be answered with the existing terminal harness.

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
