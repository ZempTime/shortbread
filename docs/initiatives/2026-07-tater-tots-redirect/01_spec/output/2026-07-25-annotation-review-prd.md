# PRD: Range-anchored Comments

**Status:** Proposed
**Repository:** `ZempTime/shortbread`
**License:** MIT
**Canonical framing:** [`docs/initiatives/2026-07-tater-tots-redirect/00_framing/output/2026-07-25-redirect-framing.md`](https://github.com/ZempTime/shortbread/blob/main/docs/initiatives/2026-07-tater-tots-redirect/00_framing/output/2026-07-25-redirect-framing.md)
**Supersedes:** [`docs/initiatives/2026-07-shortbread-v1/01_spec/output/2026-07-18-shortbread-v1-prd.md`](https://github.com/ZempTime/shortbread/blob/main/docs/initiatives/2026-07-shortbread-v1/01_spec/output/2026-07-18-shortbread-v1-prd.md) — that PRD describes the previous product and is partially wrong. It stays as history.

## Problem Statement

An Owner shares a document — a plan, a spec, a draft — with named people and wants their reactions attached to the specific words that provoked them, not summarized in a separate channel. Existing options force a choice. General-purpose comment tools require every reviewer to hold an account in someone else's system and lose the connection between a remark and the exact text it was about. Local agent-review tools like plannotator anchor comments to text well, but are deliberately ephemeral: no identity, no durable history, no way to ask what a named person said about version 3 after version 4 shipped.

Shortbread already has the half that is hard to retrofit: immutable content-addressed Releases, a named People roster, revocable Grants, accountless Invitations, and a Producer CLI. What it lacks is the ability to anchor a Comment to a *range of text within* a document rather than to a page path, and any interface for a reviewer to produce one.

The Owner needs to publish a document, invite named people, have them highlight specific passages and comment on them, and pull that feedback back through the CLI with enough context for a human or an agent to act on it. Feedback must stay honest across republishing: a comment made against Release 3 must remain readable, correctly placed, and unambiguously *about Release 3*, forever. Shortbread must remain a host and access layer — not a CMS, an authoring tool, a notification service, or a workflow engine.

## Solution

Shortbread gains range-anchored Comments and a review surface for producing them. A Producer publishes a Bundle as an immutable Release exactly as today. A Viewer opens a Site through an Invitation-activated Grant, reads the document, selects text, and leaves a Comment anchored to that selection. The Owner retrieves the Feedback Thread through the web UI or `shortbread feedback pull`, with each Comment carrying its Release, path, quoted text, and placement.

An **Anchor** is captured against the visible text of one immutable `(Release, path)` and stores a quote, the surrounding prefix and suffix, a character offset, and a structural block index. Resolution proceeds through ordered tiers that each report *how* they succeeded, yielding one of four states: `exact`, `moved`, `ambiguous`, or `orphaned`. Failure is always an explicit state, never a silently dropped highlight. This model was validated by prototype against markdown source and prebuilt HTML, including markup churn, repeated strings, reordered blocks, and deletions.

Anchors are **Release-scoped**. A Comment belongs to the Release it was made against and stays correctly placed there permanently. Publishing Release N+1 starts with no Comments on it. Continuity comes from a **Release comparison view**: the Owner sees the prior Release's Comments classified by whether the text each one points at survived the republish. Nothing is silently re-anchored onto content the reviewer never saw.

Markdown becomes a reviewable document type, rendered server-side for the review surface only. The Release stays content-addressed to the uploaded source, so the no-CMS boundary holds and the same bytes always produce the same hash.

Review is a **remote, authenticated, multi-person** surface. The local ephemeral agent-feedback loop is explicitly out of scope; plannotator already serves it well and this product does not replicate it.

## User Stories

### Owner

1. As the Owner, I can publish a multi-page Bundle as an immutable Release and have every safe path in it served and reviewable, not collapsed into a single file.
2. As the Owner, I can mark a Site as accepting Comments on text ranges, so that publishing a Site whose content is not a reviewable document does not present a review surface.
3. As the Owner, I can see the single chronological Feedback Thread for a Site with each Comment's Person, Release, path, quoted text, resolution state, and timestamp.
4. As the Owner, I can open any Release — current or superseded — and see its Comments placed on the text they were anchored to, unchanged by anything published since.
5. As the Owner, after publishing a new Release, I can compare it against the previous Release and see the previous Release's Comments classified as *text unchanged*, *text unchanged but moved*, *text you changed*, or *cannot be determined*.
6. As the Owner, I can see, from that comparison, which specific Comments my edit invalidated, without Shortbread deciding on my behalf that a Comment still applies to new text.
7. As the Owner, I can retrieve the Feedback Thread through `shortbread feedback pull`, receiving each Comment's Release, path, quoted text, placement state, and body in both human-readable and `--json` form.
8. As the Owner, I can see which Person opened which Release through Owner-only View Receipts, with no Viewer able to see another Viewer's receipt and no third-party analytics receiving the event.
9. As the Owner, I can revoke a Grant and have that Person immediately lose the ability to read the Site or add Comments, while their existing Comments remain in the Feedback Thread attributed to them.
10. As the Owner, I can delete a Site through an explicit confirmation that names the effects, including that its Comments and Anchors are removed with it.

### Viewer

11. As an invited Person, I can accept an Invitation in one tap and reach the Site without creating an account or password, exactly as today.
12. As a Viewer, I can select a range of text in a document and leave a Comment anchored to that selection.
13. As a Viewer, I can see my own and other Viewers' Comments highlighted in place on the text they refer to.
14. As a Viewer, I can see Comments that overlap the same text without them obscuring one another or preventing me from reading the document.
15. As a Viewer, I can add a Comment to a Site-level Feedback Thread without selecting any text, for remarks that are not about one passage.
16. As a Viewer, I cannot edit or delete another Person's Comment, and my own Comments are append-only once posted.
17. As a Viewer opening a Release where a Comment's text cannot be confidently placed, I see that Comment listed with its original quote rather than silently omitted or attached to the wrong passage.
18. As a Viewer with an offline-eligible Grant, I can still keep a complete eligible Release offline for reading, with commenting being an online-only capability.

### Producer

19. As a Producer, I can publish a Bundle containing markdown or HTML documents through the existing API and CLI without Shortbread rewriting, building, or reformatting the content.
20. As a Producer or agent, I can pull structured feedback for a Site and receive enough context — Release, path, quote, placement — to locate what each Comment refers to without access to a browser.

## Implementation Decisions

### Hard product constraints

- **Anchors are Release-scoped and immutable.** An Anchor records the Release it was captured against and is never mutated or re-pointed at a different Release. Viewing a Release always shows its own Comments as they were left.
- **Four explicit resolution states.** `exact`, `moved`, `ambiguous`, `orphaned`. `orphaned` is a first-class stored state, not a rendering failure. A Comment is never silently dropped from view and never attached to text whose identity cannot be corroborated.
- **No automatic carry-forward in this scope.** Publishing a Release never creates Comments on it. Continuity is presented through the comparison view only.
- **Releases stay content-addressed to uploaded bytes.** Markdown is rendered for display; rendered output is never the stored Release content.
- **Review is authenticated.** Every Comment is attributed to a Person acting through a valid Grant. There is no anonymous or identity-free path for leaving a Comment.
- **Comments are append-only.** No editing, no deletion by Viewers, no threading, no reactions, no assignment.

### Reversible implementation choices

- **Anchor composition:** quote, prefix, suffix, character offset, block index. Context window of 32 characters either side was sufficient across every prototype fixture; the exact width is tunable.
- **Anchoring targets extracted visible text** for both HTML and markdown documents, so markup changes that do not change visible text do not disturb anchors. Validated against inline-tag changes, added classes and wrappers, and minification.
- **Resolution is computed in both TypeScript and Ruby.** Capture happens in the browser, which is the only thing that knows what was selected. Resolution for the comparison view and for CLI retrieval happens on the server, which is the only thing holding both Releases and the only path available to a browserless CLI client. The two implementations must agree.
- **Resolution timing is lazy.** Anchors are stored as captured; resolution against a later Release runs when the comparison view or a feedback pull asks for it. No publish-time re-resolution pass.
- **Server-side verification.** Because a Release resolves to exact unchanging bytes, the server can verify a submitted Anchor against the stored Blob rather than trusting client-supplied offsets.

### Known characteristics

- Comments anchored inside preformatted blocks are more fragile than prose comments. Whitespace inside `<pre>` is content, so reformatting a code block changes the anchor's context and correctly orphans the Comment. Prose survives reformatting because whitespace is collapsed there.
- Anchors are currently exact on visible text. A markdown document whose prose is rewrapped will orphan Comments that a whitespace-normalizing comparison would have preserved.

## Testing Decisions

- **The behavioral seam is the anchoring module** — `capture` and `resolve` over a plain document string, with no I/O. Both the Ruby and TypeScript implementations are tested at this seam.
- **A shared conformance fixture matrix** drives both implementations: a document set crossed with republish scenarios, asserting identical resolution states from each. This matrix is the mechanism that keeps client and server capture/resolution in agreement, and it is a deliverable, not an optional extra. The prototype harnesses are its starting point.
- **The matrix must cover**, at minimum: unchanged reload; an unrelated earlier passage edited so everything shifts; the anchored text itself edited; the anchored text deleted while an identical string survives elsewhere; a string repeated within one document; reordered blocks; overlapping Anchors; Anchors on headings, code blocks, and table cells; and for HTML, inline markup changes, added wrapper elements, and whole-document reformatting.
- **Regression guard on silent misplacement.** A test must assert that a Comment whose anchored text was deleted resolves to `orphaned` and never to a same-looking string elsewhere in the document. This was a real defect found in prototype and is the specific failure this product exists to avoid.
- **API and CLI retrieval are tested end to end**, asserting that a browserless client receives Release, path, quote, and placement state for each Comment.
- **Authorization is tested at the request boundary**: a revoked Grant cannot read a Site or post a Comment, and no Viewer can retrieve another Viewer's View Receipts.

## Out of Scope

- **The local ephemeral agent-feedback loop.** No random-port local server, no editor-hook integration, no identity-free review session. plannotator serves this and continues to.
- **Automatic carry-forward of Comments onto a new Release.** Deliberately deferred. The stored Anchor composite is sufficient to add it later without migration or re-anchoring.
- **Resolve states on Comments.** No `open`/`resolved` lifecycle, no marking a Comment addressed. Remains a non-goal.
- **Threading, replies, reactions, assignment, mentions, and notifications.** The Feedback Thread stays one flat chronological conversation.
- **Editing or deleting a Comment.** Append-only.
- **Commenting on an Offline Copy.** Offline reading is retained; leaving a Comment requires connectivity.
- **Fuzzy or similarity-based re-anchoring.** Explicitly rejected: it converts a clean `orphaned` into a plausible-looking wrong placement and introduces a permanent tuning liability. The immutable Release means an orphan is always recoverable by hand.
- **Authoring or editing documents in Shortbread.** Not a CMS. Markdown is rendered for review; content arrives only through publishing.
- **The rename to Tater Tots.** Deferred to a dedicated mechanical pass after this spec settles.
- **Diffing document content between Releases.** The comparison view classifies *Comments* by whether their anchored text survived. It does not render a textual diff of the documents themselves.

## Further Notes

### Traceability

| Decision | Source |
|---|---|
| Remote-first; local agent loop out of scope | Open question 1, resolved by Chris 2026-07-25 |
| Keep View Receipts | Open question 3, resolved by Chris 2026-07-25 |
| Multi-page Bundle serving is load-bearing | Open question 3 + redirect framing; supersedes the single-file-HTML compromise |
| Offline retained, commenting online-only | Chris 2026-07-25, refining the framing's proposed cut of Offline Copies |
| Resolve states remain a non-goal | Open question 3, not selected |
| Markdown rendered for review, Release addressed to source | Redirect framing, "The md-to-HTML question, resolved" |
| Anchor composite, four states, Release-scoped | Anchoring prototype findings, 2026-07-25 |
| Extracted-text anchoring for HTML | Anchoring prototype findings, HTML validation section |
| Client and server both compute anchoring | Anchoring prototype findings, "Where this runs" |
| Reject fuzzy matching; reject DOM-position anchoring | Anchoring prototype findings, "What I would reject"; plannotator analysis |

### Unresolved before implementation

These do not block ticket decomposition but must be closed during it:

1. **No browser validation of anchor capture.** Every prototype result came from strings in Ruby. A live `Selection`/`Range` mapped back to an extracted-text offset is untested, and is the largest technical risk in this PRD.
2. **Ruby and TypeScript extractors must produce byte-identical text and offset maps**, or anchors captured in the browser will not resolve server-side. Nothing tests this yet; the conformance matrix is the intended mechanism.
3. **The prototype extractor is a hand-rolled scanner**, not a parser. A production extractor needs a real HTML parser and must be re-validated against the same matrix.
4. **Unicode, multi-byte text, and grapheme clusters are untested.** All fixtures were ASCII. Offset semantics need an explicit decision.
5. **Whitespace normalization for markdown** is unresolved, including whether preformatted blocks opt out.

### Frontend

`app/frontend/pages/` is currently empty; there is no review UI of any kind. The stack is already React 19, Tailwind 4, Inertia, and Vite. Whether to vendor plannotator's `Viewer` component or build the surface directly is **not decided here** and is left to decomposition. The plannotator analysis found its top-level `App.tsx` unextractable; a lower-level component seam was reported but is unverified, and `@plannotator/web-highlighter`'s license was never confirmed. Its anchoring model is explicitly not adopted regardless.

### Relationship to existing work

The publish pipeline, Blobs, PublishPlan/finalize, Releases, rollback, passkey Owner bootstrap, People, Grants, Invitations, View Receipts, the Go CLI, and the production container all survive unchanged and are prerequisites rather than new work. The Shortbread v1 ticket graph describes the previous product and must not be resumed.
