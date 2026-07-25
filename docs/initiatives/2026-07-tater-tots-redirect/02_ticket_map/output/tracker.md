# Stage 02 Tracker

- Parent PRD: [#64 — PRD: Range-anchored Comments](https://github.com/ZempTime/shortbread/issues/64)
- Published: 2026-07-25
- Source graph: [`2026-07-25-ticket-map.md`](2026-07-25-ticket-map.md)
- Operator approval: Chris, 2026-07-25 (both challenged items confirmed explicitly)

## Published tickets

| Ticket | Issue | Title | Blocked by | Label |
|---|---|---|---|---|
| T1 | [#65](https://github.com/ZempTime/shortbread/issues/65) | A Viewer can comment on selected text and the Owner can pull it | — | `ready-for-agent` |
| T7 | [#66](https://github.com/ZempTime/shortbread/issues/66) | Validate Anchor capture in a real browser | — | **closed 2026-07-25** |
| T2 | [#67](https://github.com/ZempTime/shortbread/issues/67) | Anchors resolve honestly when the document changes | #65 | none |
| T3 | [#68](https://github.com/ZempTime/shortbread/issues/68) | Multiple and overlapping Comments render without obscuring the document | #65 | none |
| T5 | [#69](https://github.com/ZempTime/shortbread/issues/69) | A Viewer can comment on a Site without selecting text | #65 | none |
| T6 | [#70](https://github.com/ZempTime/shortbread/issues/70) | Revocation and attribution boundaries hold | #65 | none |
| T4 | [#71](https://github.com/ZempTime/shortbread/issues/71) | The Owner can compare a new Release against the previous one | #67 | none |

## Edges

```
#65 ──┬── #67 ── #71
      ├── #68
      ├── #69
      └── #70

#66  (independent)
```

## Current frontier

`#65` only. It is the sole ticket carrying `ready-for-agent`.

**#66 closed 2026-07-25 with a positive outcome** — a live `Selection`/`Range` maps cleanly to
extracted-text offsets, so the PRD's capture approach survives and **#65 is not re-scoped**. The
caveat previously recorded here (a negative result re-scopes #65's capture layer) is discharged.

#66 landed on `main` at `53fd83b`, adding `test/browser_capture/` and its outcome doc — test and
docs surface only, none of #65's reserved files. Whoever claims #65 should branch from current
`main` and read the Addendum in
[`2026-07-25-handoff-t1-walking-skeleton.md`](2026-07-25-handoff-t1-walking-skeleton.md), which
carries three constraints #66 placed on the capture layer.

## Parent label state

`ready-for-agent` was never applied to #64 and must not be. The parent PRD is not executable
frontier work.

## Surface reservations

`#65` reserves `config/routes.rb`, `db/schema.rb` + its migration,
`app/controllers/site_contents_controller.rb`, and `package.json`. No ticket may run
concurrently against these except `#66`, which touches none of them.

`#65` must model the Anchor as **optional** on Comment, or `#69` requires a second migration.
Recorded as a constraint on `#65`.

## Coverage

Every PRD story maps to at least one ticket; see the coverage table in the source graph. Story 11
(Invitation acceptance) is existing behavior covered by regression rather than a new ticket.

## Shortbread v1 backlog closed

On Operator instruction 2026-07-25, all 50 open issues below #64 were closed as **not planned**
and superseded by this graph, leaving #64–#71 as the only open work. Each received a closing
comment naming the redirect, the new PRD, and the new graph.

Ten of them describe capability the new product still needs, so their closing comments name
where the work went rather than implying it was dropped:

| Closed | Carried to |
|---|---|
| #35 [U17], #36 [U18] multi-page Bundle validation and serving | prerequisite inside #65 (criterion 1) |
| #7 serve real static Bundles | prerequisite inside #65 |
| #41 [U23], #9 Release/path-anchored feedback | superseded by range anchoring: #65, #67 |
| #43 [U25], #10 View Receipts | retained; boundary covered by #70 |
| #33 [U15], #34 [U16], #6 R2 Blob port and finalize | already implemented under redirect Track B (B1) |

The v1 initiative remains as acceptance history in `docs/initiatives/2026-07-shortbread-v1/`.
Its `RUN.md` was already marked superseded on 2026-07-25.

## Not done in this stage

- No per-ticket workspaces. `implement` creates one only where a slice's uncertainty justifies it.
- No `RUN.md` for this initiative. One must exist before autonomous execution begins — it is the
  authority for stage state, controller identity, and recovery, and this graph assumes a
  controller will exist to honour the `#65` checkpoint and split rule.
