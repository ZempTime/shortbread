# Handoff — #65: A Viewer can comment on selected text and the Owner can pull it

**Ticket:** [#65](https://github.com/ZempTime/shortbread/issues/65) · **Parent PRD:** [#64](https://github.com/ZempTime/shortbread/issues/64)
**Blocked by:** nothing. On the frontier with [#66](https://github.com/ZempTime/shortbread/issues/66).
**Branch point:** `main` at `2163fb6`.
**Use the `implement` skill.**

## Read #66 first

[#66](https://github.com/ZempTime/shortbread/issues/66) validates Anchor capture in a real
browser, and **its result can change this ticket's capture layer**. Before starting:

- If #66 is unstarted, you may proceed — but treat the browser capture mapping as the riskiest
  part of this slice and build it first, behind the checkpoint below.
- If #66 is in flight, read its comments before writing capture code.
- If #66 has reported a negative outcome, **stop and get this ticket re-scoped.** Do not build
  on an invalidated assumption.

## Why this is one big ticket

Nothing smaller reaches a real actor. Verified against the working tree:

| Fact | Evidence |
|---|---|
| No `Comment` model, no Feedback Thread | `app/models/` has neither |
| No frontend at all | `app/frontend/pages/` is empty |
| Serving is hardcoded to one file | `SiteContentsController#current_index` does `find_by(path: "index.html")`; route is `get "/"` |

So multi-page serving is a **prerequisite inside this slice**, not a separate ticket. A Comment
cannot anchor to `/chapter-2.html` while that path is unreachable.

**Controller checkpoint:** after acceptance criterion 3 (a Comment persists and repaints on
reload). Stop and report there before continuing to the CLI.

**Safe split rule:** if this exceeds one context, split at the CLI boundary — criteria 1–4 and 6
stay here, criterion 5 becomes a new ticket blocked by this one.

## Required reading, in order

1. The ticket body on [#65](https://github.com/ZempTime/shortbread/issues/65) — the authoritative
   acceptance criteria.
2. [PRD #64](https://github.com/ZempTime/shortbread/issues/64) — especially *Implementation
   Decisions* (hard constraints vs. reversible choices) and *Testing Decisions*.
3. `docs/initiatives/2026-07-tater-tots-redirect/00_framing/output/2026-07-25-anchoring-prototype-findings.md`
   — the validated anchor model and, importantly, the defects found while building it.
4. `CONTEXT.md` — **Anchor** and **Comment** are canonical terms. "Annotation" is banned.
5. `docs/agents/mwp.md` and `docs/agents/issue-tracker.md` — repo method and tracker conventions.

## What to lift, and from where

The anchoring logic is **already validated**. Do not redesign it.

```
git checkout prototype/anchoring-2026-07-25 -- tmp/prototype-anchoring/
```

- `anchoring.rb` — `Anchor` struct, `capture`, `resolve`, the four states. **Lift this.**
  Drop `carry_forward`; the Release-scoped decision removed it.
- `extract.rb` — `Extract.from_html`, visible-text extraction plus the offset map. **Lift this**,
  but note it is a hand-rolled scanner; production needs a real HTML parser (see PRD open item 3).
- `sweep.rb` / `html_sweep.rb` / fixtures — the conformance harness. Becomes the shared matrix.
- `tui.rb` — throwaway shell. **Do not lift.**

The branch is evidence, not product. Do not merge it.

## Hard constraints from the PRD

These are not negotiable in this ticket:

- **Anchors are Release-scoped and immutable.** An Anchor records the Release it was captured
  against and is never re-pointed at another Release.
- **Four explicit states**: `exact`, `moved`, `ambiguous`, `orphaned`. `orphaned` is stored, not a
  render failure. Never silently drop a Comment; never attach one to uncorroborated text.
- **Server verifies the Anchor** against the Release's stored bytes. Never trust client offsets.
- **Comments are append-only.** No edit, no delete, no threading, no reactions.
- **Model the Anchor as optional on Comment** — [#69](https://github.com/ZempTime/shortbread/issues/69)
  (Site-level Comments with no selection) depends on this, and getting it wrong costs a second
  migration.
- **Releases stay content-addressed to uploaded bytes.** Markdown renders for display only.

## The defect to protect against

The prototype's first cut reproduced plannotator's worst failure: a Comment on **deleted** text was
silently relocated onto an identical sentence in a **different section**, reported as `moved` at
0.50 confidence with `0/2` context match.

The fix was a confidence floor — if neither context side agrees *and* the text moved, orphan
rather than relocate. **Carry that rule across, and write the regression test for it** (it is
explicitly required by [#67](https://github.com/ZempTime/shortbread/issues/67), but the rule must
be right here first).

## Reserved surfaces

This ticket **reserves** and no other work may touch concurrently:

- `config/routes.rb`
- `db/schema.rb` and its migration
- `app/controllers/site_contents_controller.rb`
- `package.json`

#66 touches none of these, so the two can run in parallel.

## Acceptance criteria

Verbatim from the ticket:

1. A path other than `index.html` in a published Release is served at its Manifest path.
2. A Viewer can select text and post a Comment; it persists with an Anchor recording quote,
   prefix, suffix, offset, block index, Release, and path.
3. Reloading the Release paints the Comment on the same text. **← checkpoint here**
4. The server verifies the submitted Anchor against the Release's stored bytes and rejects a
   mismatch.
5. `shortbread feedback pull` and `--json` both return Release, path, quote, placement, body, and
   attributed Person.
6. Anchoring resolution is implemented once in Ruby and once in TypeScript, both exercised.

## Seams and evidence

- Request specs: multi-page serving, Comment creation, Anchor rejection on mismatch.
- Unit tests: the Ruby anchoring module, and its TypeScript twin.
- CLI integration test: `feedback pull`.
- Evidence for integration: passing suites, a screenshot of a placed Comment, and CLI output
  showing a pulled Comment with its quote.

## Boundaries

- Do not implement the Release comparison view ([#71](https://github.com/ZempTime/shortbread/issues/71)),
  overlapping-highlight UX ([#68](https://github.com/ZempTime/shortbread/issues/68)), or the
  revocation test suite ([#70](https://github.com/ZempTime/shortbread/issues/70)).
- Do not add carry-forward. It is explicitly out of scope in the PRD.
- Do not rename anything — Tater Tots is deferred to a dedicated pass.
- No new frontend dependencies beyond the existing React 19 / Tailwind 4 / Inertia / Vite
  baseline without an explicit decision.
- Do not resume the Shortbread v1 ticket graph; all 50 of its issues were closed as not planned.

## Environment

- `bin/db start` then `bin/db prepare` for local Postgres.
- `bin/rails test` and `cd cli && go test ./...`.
- **Known pre-existing failures:** four `production_worker_health` black-box errors from an unset
  `SHORTBREAD_DATABASE_HOST`. They fail identically on `main` and are not yours to fix.
- Whether to vendor plannotator's `Viewer` component is **undecided** and deliberately left open.
  Its top-level `App.tsx` is verified unextractable; a lower-level seam was reported but never
  verified, and `@plannotator/web-highlighter`'s license was never confirmed. Its anchoring model
  is not adopted regardless.
