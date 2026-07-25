# Ticket map — Range-anchored Comments

**Parent PRD:** [#64 — PRD: Range-anchored Comments](https://github.com/ZempTime/shortbread/issues/64)
**Drafted:** 2026-07-25
**Status:** Approved by Chris (Operator) 2026-07-25. Published.

## Verified starting state

Read from the working tree, not assumed:

| Fact | Evidence |
|---|---|
| No `Comment` model, no Feedback Thread of any kind | `app/models/` contains no comment or thread model |
| No frontend at all | `app/frontend/pages/` is empty; only `entrypoints/` and `types/` exist |
| Serving is hardcoded to one file | `SiteContentsController#current_index` does `find_by(path: "index.html")`; route is `get "/"` only |
| Publish pipeline, Releases, People, Grants, Invitations, View Receipts, CLI all exist | `app/models/`, `app/controllers/api/v1/`, `cli/` |
| Anchoring logic validated but not in the repo | `prototype/anchoring-2026-07-25` branch; findings doc |

Consequence: **multi-page serving is a hard prerequisite**, not a parallel nicety. A Comment
cannot anchor to `/chapter-2.html` while only `index.html` is reachable. It is therefore inside
ticket 1 rather than a separate horizontal ticket.

## The walking skeleton

**T1** is the smallest slice that produces an actor-visible outcome across every necessary layer:
a Viewer opens a real multi-page document, selects text, leaves a Comment, and the Owner pulls it
back through the CLI with the quote attached. It deliberately crosses serving, model, API,
frontend, and CLI, because a slice that stops short of any of those proves nothing end to end.

It carries minimum scaffolding (first Inertia page, first frontend build of substance) because
there is no frontend to extend. It is not a scaffolding ticket: its acceptance is the Viewer
outcome, not the scaffolding.

## Graph

```
T1  Comment on selected text, end to end          (frontier)
     |
     +-- T2  Anchor survives markup and content change
     |        |
     |        +-- T4  Release comparison view
     |
     +-- T3  Multiple and overlapping Comments in place
     |
     +-- T5  Site-level Comments without a selection
     |
     +-- T6  Authorization and revocation boundary

T7  Browser validation of Anchor capture           (frontier, independent)
```

`T7` has no blockers and is deliberately on the frontier alongside `T1`. It closes the PRD's
largest unresolved risk and its result can force a change to `T1`'s capture approach, so it must
not wait behind the graph.

---

## T1 — A Viewer can comment on selected text and the Owner can pull it

**Blocked by:** none. **Parent:** #64.

**Actor-visible behavior.** A Viewer with a valid Grant opens a multi-page document at a real
path, selects a passage, and leaves a Comment. Reloading shows the Comment highlighted on the
same text. The Owner runs `shortbread feedback pull` and receives that Comment with its Release,
path, quoted text, placement state, and body.

**Failure/recovery behavior.** Submitting an Anchor whose quote does not match the stored Blob at
the claimed offset is rejected with a clear error rather than stored. A Comment posted against a
path that is not in the Release Manifest is rejected.

**Acceptance criteria.**
1. A path other than `index.html` in a published Release is served at its Manifest path.
2. A Viewer can select text and post a Comment; it persists with an Anchor recording quote,
   prefix, suffix, offset, block index, Release, and path.
3. Reloading the Release paints the Comment on the same text.
4. The server verifies the submitted Anchor against the Release's stored bytes and rejects a
   mismatch.
5. `shortbread feedback pull` and `--json` both return Release, path, quote, placement, body,
   and attributed Person.
6. Anchoring resolution is implemented once in Ruby and once in TypeScript, both exercised.

**Seams.** Request specs for serving and Comment creation; unit tests on the Ruby anchoring
module; TypeScript unit tests on its twin; CLI integration test for `feedback pull`.

**Edit surface.** Central and reserved: `config/routes.rb`, `db/schema.rb` plus one migration,
`app/controllers/site_contents_controller.rb`, `package.json`. No other ticket may run
concurrently against these.

**Security/privacy.** Comment creation requires a valid Grant-backed Site session. Anchor payload
is verified server-side, never trusted. No Comment body or quote enters logs.

**Docs/ops.** `README` gains the review surface; API contract documents the Comment endpoint.

**Evidence.** Passing suites, a screenshot of a placed Comment, and CLI output showing a pulled
Comment with its quote.

**Harvest.** Promote the Ruby anchoring module and the shared fixture matrix as the factory
seam for T2.

**Size note.** This is the largest ticket in the graph and is justified only because nothing
smaller reaches an actor. **Controller checkpoint** after acceptance criterion 3 (Comment
persists and repaints). **Safe split rule:** if it exceeds one context, split at the CLI boundary
— criteria 1–4 and 6 stay, criterion 5 becomes T1b blocked by T1.

---

## T2 — Anchors resolve honestly when the document changes

**Blocked by:** T1. **Parent:** #64.

**Actor-visible behavior.** After a republish, a Comment made on a previous Release still points
at the right text where the text survived, and is explicitly marked unplaced where it did not. A
Comment whose anchored text was deleted is never shown attached to a similar-looking passage
elsewhere.

**Failure/recovery behavior.** `orphaned` and `ambiguous` are stored states surfaced to both
Viewer and Owner with the original quote, never silent omissions.

**Acceptance criteria.**
1. The four resolution states are persisted and returned by the API and CLI.
2. The shared conformance fixture matrix runs against both the Ruby and TypeScript
   implementations and asserts identical states.
3. The matrix covers every scenario named in the PRD's Testing Decisions.
4. A regression test asserts that a Comment whose anchored text was deleted resolves to
   `orphaned` and never to an identical string elsewhere.
5. A Viewer opening a Release sees unplaceable Comments listed with their original quote.

**Seams.** Unit tests at the anchoring module in both languages, driven by one shared fixture
file; request spec for the API's placement field.

**Edit surface.** Anchoring modules and fixtures only. No routes, no schema.

**Security/privacy.** None beyond T1.

**Docs.** The four states and their meaning documented for CLI consumers.

**Evidence.** Both language suites green against the identical matrix, with the matrix file
itself in the diff.

**Harvest.** The fixture matrix becomes the durable cross-language conformance artifact.

---

## T3 — Multiple and overlapping Comments render without obscuring the document

**Blocked by:** T1. **Parent:** #64.

**Actor-visible behavior.** A Viewer sees several Comments on one page, including two that
overlap the same words, and can read the underlying document and open either Comment.

**Acceptance criteria.**
1. Multiple Comments on one path render simultaneously.
2. Two Comments whose ranges overlap are both reachable and neither hides the text.
3. Selecting an existing highlight opens its Comment rather than starting a new selection.

**Seams.** Browser test driving two overlapping selections; component test for the highlight layer.

**Edit surface.** Frontend review surface only.

**Docs/screenshots.** Screenshot of overlapping highlights required.

**Evidence.** Browser test plus screenshot.

**Harvest.** `No reusable harvest` expected unless the highlight layer generalizes.

---

## T4 — The Owner can compare a new Release against the previous one

**Blocked by:** T2. **Parent:** #64.

**Actor-visible behavior.** After publishing, the Owner opens a comparison view and sees the
previous Release's Comments classified as *text unchanged*, *text unchanged but moved*, *text you
changed*, or *cannot be determined*, and can open the previous Release to read them in place.

**Failure/recovery behavior.** A Site with only one Release shows an explicit empty state, not an
error.

**Acceptance criteria.**
1. The view lists the previous Release's Comments with a classification each.
2. Classification is computed server-side by resolving each Anchor against the new Release.
3. No Comment is created on, or moved to, the new Release by this view.
4. Counts match the underlying resolution states.

**Seams.** Request spec asserting classification counts against a fixture republish; unit tests
reuse T2's matrix.

**Edit surface.** One new read-only route and controller, plus a frontend page. Coordinate with
T1's routes reservation — must not run concurrently with T1.

**Security/privacy.** Owner-only. A Viewer requesting it is denied.

**Docs/screenshots.** Screenshot of the comparison view required.

**Evidence.** Request spec output plus screenshot.

**Harvest.** `No reusable harvest` expected.

---

## T5 — A Viewer can comment on a Site without selecting text

**Blocked by:** T1. **Parent:** #64.

**Actor-visible behavior.** A Viewer leaves a Comment with no selection; it appears in the same
chronological Feedback Thread and is pulled by the CLI with no quote and no placement.

**Acceptance criteria.**
1. A Comment can be created with no Anchor.
2. It appears in the Feedback Thread ordered with anchored Comments.
3. CLI output renders it without a quote and without a placement state.

**Seams.** Request spec; CLI integration test.

**Edit surface.** Comment model nullable-anchor path and the thread view. No schema change if T1
models the Anchor as optional — **T1 must do so**, recorded here as a constraint on T1.

**Evidence.** Request spec plus CLI output.

**Harvest.** `No reusable harvest`.

---

## T6 — Revocation and attribution boundaries hold

**Blocked by:** T1. **Parent:** #64.

**Actor-visible behavior.** A Person whose Grant is revoked can no longer read the Site or post a
Comment, while the Comments they already left remain in the Feedback Thread attributed to them.
No Viewer can edit or delete another Person's Comment, or their own.

**Acceptance criteria.**
1. Revoked Grant → read denied and Comment creation denied at the request boundary.
2. Existing Comments from that Person remain, attributed.
3. No endpoint exists to edit or delete a Comment.
4. No Viewer can retrieve another Viewer's View Receipts.

**Seams.** Request specs at the authorization boundary.

**Security/privacy.** This ticket *is* the security boundary; it must not be folded into T1.

**Docs.** Trust boundary documented.

**Evidence.** Request spec output covering each denial.

**Harvest.** `No reusable harvest`.

---

## T7 — Validate Anchor capture in a real browser

**Blocked by:** none. **Parent:** #64. **On the frontier with T1.**

**Actor-visible behavior.** None directly; this is a risk-closing spike with a written outcome.
Its product value is that T1's capture approach is either confirmed or corrected before the rest
of the graph is built on it.

**Why it is not blocked.** Every anchoring result to date came from strings in Ruby. A live
`Selection`/`Range` mapped back to an extracted-text offset is untested and is the PRD's largest
technical risk. If it fails, T1's capture layer changes shape.

**Acceptance criteria.**
1. A real browser selection across rendered content maps to an offset in extracted text, verified
   against the Ruby extractor's output for the same document.
2. Selections spanning inline tags and block boundaries are covered.
3. The Ruby and TypeScript extractors are shown to produce identical text and offset maps for the
   fixture set, or the differences are enumerated.
4. A written outcome states whether the PRD's capture approach survives unchanged, and what must
   change if not.

**Seams.** Browser-driven test against a fixture document.

**Edit surface.** Test and fixture surface only; no product code.

**Evidence.** Browser test output and the written outcome, recorded on the issue.

**Harvest.** The extractor-agreement check promotes into T2's conformance matrix.

**Note.** If T7 invalidates the capture approach, T1 is re-scoped before its remaining criteria
are built. This is the cheap-now, expensive-later ordering the prototype was run to protect.

---

## PRD story coverage

| Story | Ticket |
|---|---|
| 1 — multi-page Release served and reviewable | T1 |
| 2 — Site marked as accepting range Comments | T1 |
| 3 — Feedback Thread with quote and state | T1, T2 |
| 4 — open any Release, Comments unchanged | T1, T2 |
| 5 — compare Releases, Comments classified | T4 |
| 6 — see which Comments an edit invalidated | T4 |
| 7 — `shortbread feedback pull` with context | T1, T2 |
| 8 — Owner-only View Receipts | T6 |
| 9 — revoke Grant, Comments remain attributed | T6 |
| 10 — delete Site removes Comments and Anchors | T6 |
| 11 — Invitation acceptance unchanged | existing behavior; regression only |
| 12 — select text and leave a Comment | T1 |
| 13 — see Comments highlighted in place | T1, T3 |
| 14 — overlapping Comments readable | T3 |
| 15 — Site-level Comment without selection | T5 |
| 16 — Comments append-only | T6 |
| 17 — unplaceable Comment listed with quote | T2 |
| 18 — offline reading retained, commenting online-only | T1 (no offline write path) |
| 19 — publish markdown or HTML unchanged | T1 |
| 20 — agent pulls structured feedback | T1, T2 |

Story 11 is existing behavior with no new work; it is covered by regression rather than a ticket.

## Runnable frontier

**T1** and **T7** are unblocked. They touch disjoint surfaces (T7 is test-and-fixture only) and
may run concurrently, with the caveat that a T7 negative result re-scopes T1.

Everything else is blocked until T1 lands.

## Campaign grouping

One campaign, four integrations:

| Campaign | Tickets | Exit condition |
|---|---|---|
| C1 — Range-anchored Comments | T7, T1, T2, then T3/T5/T6/T4 | A Viewer can comment on text, resolution is honest across republish, and the Owner can compare Releases |

T3, T5 and T6 are small and may integrate together. T4 is the last integration because it depends
on T2.

## Constraints recorded as graph edges

- **T1 reserves** `config/routes.rb`, `db/schema.rb` + migration, `site_contents_controller.rb`,
  `package.json`. T4 also needs routes; it must not run concurrently with T1 (it cannot anyway —
  T4 is blocked by T2 which is blocked by T1).
- **T1 must model the Anchor as optional on Comment**, or T5 requires a second migration.
- **No dependency additions after T1's bootstrap** without an explicit decision; T1 establishes
  the frontend stack usage on the existing React 19 / Tailwind 4 / Inertia / Vite baseline.

## Controller review

Challenged before publication:

- **Is T1 oversized?** Yes, and deliberately. Nothing smaller reaches an actor: there is no
  frontend, no Comment model, and serving is single-file. A checkpoint and a safe split rule at
  the CLI boundary are recorded rather than pretending the slice is smaller than it is.
- **Is T7 correctly on the frontier?** Yes. It has no product blockers, and delaying it would
  mean building T1's capture layer on an unvalidated assumption.
- **Is security deferred into a bucket?** T6 is a named ticket with its own acceptance criteria,
  not a final cleanup. Anchor verification lives in T1 because storing unverified Anchors is not
  an acceptable intermediate state.
- **Is docs/setup deferred?** No — T1 carries its own docs and evidence.
- **Any ticket that cannot show value on completion?** T7 is a spike; its value is a written
  outcome that gates T1's shape. It is scoped with explicit criteria rather than left open-ended.
- **False parallelism?** Schema, routes, and `package.json` are reserved to T1 and no ticket runs
  beside it except T7, which touches neither.
- **Stale-status risk?** Coverage lives in this file only; tickets carry no duplicated status.

**Approval:** Chris (Operator), 2026-07-25. Both challenged items were put to the Operator
explicitly and confirmed as drafted: T1 stays whole with a checkpoint and a recorded CLI split
rule; T7 stays on the frontier alongside T1.
