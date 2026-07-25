# Handoff — Track A: prototype the annotation anchoring model

**Type:** throwaway prototype. Use the `prototype` skill. Do NOT write production code, do NOT
write the PRD, do NOT touch `app/`.

**Why this exists:** the anchoring model is the one design question the whole product rests on.
plannotator's model is weak (see the plannotator analysis) and our immutable Releases are a
better substrate than it has. Get this wrong and everything above it is built on sand. It is
cheap to answer badly now and expensive later.

## The question to answer

> When a reviewer selects text inside a published document and comments on it, how is that
> selection stored so it still points at the right text later — and what happens when the
> author publishes a new Release?

Everything below serves that question.

## Required reading first

1. `docs/initiatives/2026-07-tater-tots-redirect/00_framing/output/2026-07-25-plannotator-analysis.md`
   — especially the anchoring section and the design caution at its end.
2. `CONTEXT.md` — canonical vocabulary. Use `Release`, `Site`, `Person`, `Comment`,
   `Manifest Entry`, `Blob`. Do not invent synonyms.
3. `app/models/release.rb`, `app/models/manifest_entry.rb`, `app/models/blob.rb` — the existing
   immutable-Release shape you are anchoring into.

## What already exists (do not rebuild)

- **Releases are immutable and content-addressed.** `Release` has `attr_readonly :site_id,
  :number, :manifest_sha256`. A `ManifestEntry` maps `path` → `Blob`, and `Blob` is keyed by
  `sha256`. So "Release 4's `/chapter-2.html`" resolves to an exact, unchanging byte sequence.
  This is your advantage over plannotator — lean on it.
- Today's `Comment` concept (specified, unbuilt) anchors to **Release + path only**, server-side.
  Range anchoring is the delta.

## Design axes to explore

Explore at least these; the prototype exists to make them concrete, not to pick one on paper.

**1. What the anchor is made of.** Candidates:
   - Text quote + prefix/suffix context (W3C Web Annotation TextQuoteSelector style)
   - Character offset range into the source bytes
   - Structural path (block index from a markdown parse) + offset within block
   - Some combination, with fallback ordering

   plannotator uses DOM position + exact quote with **no context**, verification off by default,
   and an exact-substring fallback that silently hits the first match of a repeated string.
   Treat that as a worked example of what not to ship.

**2. Source vs. rendered.** Does the anchor point at the markdown source or the rendered HTML?
   The framing decision is that Releases stay content-addressed to the **source**, with
   rendering for display only. So an anchor into rendered HTML must survive a re-render.
   Anchoring to source and projecting into the render is probably cleaner — verify that.

**3. Behavior across a republish.** The real question. Options:
   - **Release-scoped** (plannotator's implicit model): annotations belong to Release N,
     period. Continuity comes from a diff view between N and N+1. Simple, honest, no drift.
   - **Carried forward**: attempt to re-anchor onto Release N+1, with explicit states for
     `moved`, `unchanged`, `orphaned`. Much more useful, much harder, and needs an orphan UI.
   - Hybrid: carry forward where the quote matches exactly, orphan otherwise.

   **Have an explicit orphan state in the data model either way.** plannotator's silent
   `console.warn`-and-drop is the single worst thing about its design.

**4. Repeated text.** What happens when the selected string appears five times in the document?
   This is where naive models fail. Make the prototype reproduce it.

## Concrete scenarios the prototype must demonstrate

Build a small document set and drive these:

1. Anchor a comment mid-paragraph; reload; it lands on the same text.
2. The document is republished with **an unrelated earlier paragraph edited** (everything shifts).
3. The document is republished with **the annotated text itself edited**.
4. The document is republished with **the annotated text deleted entirely**.
5. The annotated string **appears multiple times** in the document.
6. A comment on a **heading** vs. inside a **code block** vs. inside a **table cell**.
7. Two overlapping annotations on the same text.

For each: what does the reviewer see, and what does the Owner pulling feedback via CLI see?

## Deliverables

Write to `docs/initiatives/2026-07-tater-tots-redirect/00_framing/output/`:

- `2026-07-25-anchoring-prototype-findings.md` — what you built, what each scenario did, and a
  **recommended anchor model with reasoning**. Include what you'd reject and why.
- Throwaway code under `tmp/` or a scratch dir — NOT under `app/`. It is evidence, not product.

Be explicit about what you did not test.

## Boundaries

- No production code. No migrations. No changes under `app/`, `lib/`, `cli/`, or `db/`.
- Do not write or amend the PRD — that is a later stage, gated on this result.
- Do not rename anything (Tater Tots is deferred).
- Do not resume the Shortbread v1 ticket graph.
- If you conclude the whole approach is wrong, say so — a negative result is a valid outcome and
  is exactly what a prototype is for.
