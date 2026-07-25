# Open questions and next actions

Date: 2026-07-25. **Read this first when resuming.** Nothing in this initiative has been
implemented — no code, no PRD, no tickets, no controller.

## State of the repository

`main` is clean. The only change from this session is this documentation workspace. No product
code was touched. Shortbread v1 remains paused exactly as `RUN.md` describes it.

## Decisions Chris made (settled)

1. **Major scope redirect** to a plannotator-shaped annotation/review product. Previous
   approach "no longer relevant unless useful here."
2. **Target full infra** — deployment work proceeds regardless of product shape.
3. **Start by prototyping the anchoring model**, before writing a spec.
4. Blob storage: **implement the R2 port**, not a persistent volume.
5. Domain: **`*.sites.<apex>`**, keep the `.sites.` infix (platform-forced, see deployment doc).
6. Rename to **Tater Tots** (anno-**tate**) — deferred until the spec settles.
7. Earlier in the same session, before the redirect: ship single-file HTML, defer the Shelf.
   **Both are superseded** — a review product needs multi-page documents.

## Open questions (blocking, in priority order)

### 1. Local agent loop vs. durable multi-person review

Chris said "other people me and my agents" — both. These pull in opposite directions
(ephemeral/identity-free vs. persistent/authenticated). This is the **main scope risk**.

**Recommendation on record, not yet accepted:** build remote-first — the durable
multi-person surface that Shortbread is uniquely positioned for — and keep using plannotator
itself for the local agent loop until the annotation model is proven. plannotator already does
the local loop well; what it cannot do is durable, authenticated, multi-person review with
history.

### 2. What does the anchoring model actually look like?

The one design question everything else rests on. plannotator's model is **not** a good
template (DOM position + exact substring fallback, no prefix/suffix context, silent drops — see
the plannotator analysis). Our immutable Releases are a better substrate.

Specific sub-questions:
- Text-quote anchor with prefix/suffix context (W3C style), or something simpler?
- What happens to annotations across a republish — carried forward, or scoped to their Release
  with a diff for continuity? (plannotator does the latter by default.)
- Do annotations anchor to the markdown source or the rendered HTML?

### 3. Scope cuts to confirm

- Cut Offline Copies / service workers (U21/U22)? Probably yes.
- Keep View Receipts (U25)? Undecided.
- Resolve states: currently a PRD non-goal, but an iteration loop needs them. Confirm.

### 4. Unverified facts worth closing

- Northflank **managed Postgres pricing** — never confirmed from a primary source. Do not
  quote the ~$3.91/mo figure that surfaced in search.
- **Netlify DNS wildcard CNAME** support.
- `@plannotator/web-highlighter` **license** — unpublished-looking scoped package, load-bearing
  for anchoring if harvested.
- `packages/review-editor/App.tsx` internals — same propless shape expected, unverified.
- Northflank **volume `fsGroup`** behavior for UID 10001 (moot if R2 is used).

## Recommended next actions

**In parallel — they do not block each other:**

Both tracks now have written handoffs:
[Track A](2026-07-25-handoff-track-a-anchoring.md) ·
[Track B](2026-07-25-handoff-track-b-infra.md)

**Track A: prototype the anchoring model** (Chris's chosen starting point)
Throwaway prototype per the `prototype` skill. Answer: what does a range-anchored annotation on
an immutable Release feel like, and what happens across a republish? Cheap to get wrong now,
expensive later. Do **not** write the PRD before this.

**Track B: infra** (unblocked, no credentials needed to build)
1. R2 blob port (U15/U16) — `LocalBlobStore` is already a clean five-method port with five call
   sites. Add `R2BlobStore` behind the same interface, select by config.
2. Build `infra/` modeled on brunch-club: `app.env`, Northflank service manifests, provisioning
   script, phased HUMAN/AGENT runbook. One service, not four.

**Then, once Track A answers the design question:** run `to-spec` for a new canonical PRD, then
`to-tickets`. Then the rename, once, as a dedicated pass (168 files / 868 occurrences).

## What NOT to do

- Do not resume the Shortbread v1 initiative or its ticket graph — it describes the old product.
- Do not treat the v1 PRD as current truth; it is partially wrong.
- Do not attempt to harvest `packages/editor/App.tsx` — verified unextractable.
- Do not rename before the spec settles.
- Do not write the PRD before the anchoring prototype.
- `/ask-matt` is configured `disable-model-invocation` — Chris must invoke it himself. He asked
  for it this session and it was never run.
