# Stage 01 Tracker

- Parent PRD: [#64 — PRD: Range-anchored Comments](https://github.com/ZempTime/shortbread/issues/64)
- Published: 2026-07-25
- Current labels: none
- Source body: [`2026-07-25-annotation-review-prd.md`](2026-07-25-annotation-review-prd.md)

## Label status

`ready-for-agent` **not applied.** The PRD records five unresolved items that must be closed
during decomposition (browser validation of Anchor capture, Ruby/TypeScript extractor agreement,
production HTML parser, Unicode offset semantics, markdown whitespace normalization). Apply the
label once `to-tickets` has represented these as blockers, or once they are separately closed.

## Inputs consumed

| Input | Role |
|---|---|
| `00_framing/output/2026-07-25-redirect-framing.md` | Canonical framing; scope redirect and md-to-HTML boundary |
| `00_framing/output/2026-07-25-open-questions.md` | Open questions 1 and 3, resolved by Chris this session |
| `00_framing/output/2026-07-25-anchoring-prototype-findings.md` | Track A result; anchor model, four states, Release-scoped decision, HTML validation |
| `00_framing/output/2026-07-25-plannotator-analysis.md` | Rejected anchoring model; component reuse constraints |
| `CONTEXT.md` | Canonical vocabulary |

## Decisions taken during this stage

Both were open questions the framing flagged as blocking; Chris resolved them 2026-07-25.

1. **Open question 1 — remote-first.** v1 serves durable multi-person review. The local
   ephemeral agent loop is out of scope; plannotator continues to serve it.
2. **Open question 3 — scope cuts.** Keep View Receipts. Multi-page Bundle serving is
   load-bearing. **Offline Copies are retained** for reading, with commenting online-only —
   this refines rather than accepts the framing's proposed cut. Resolve states remain a non-goal.

## Domain model change

`CONTEXT.md` gained **Anchor** as a canonical term and `Comment`'s definition was widened to
allow anchoring to a text range within a path. Committed alongside the PRD.

## Not done in this stage

- No child tickets. That is `to-tickets`' job.
- No `RUN.md` for this initiative. One should exist before autonomous execution begins; the
  initiative README still describes the workspace as framing-only and needs updating.
