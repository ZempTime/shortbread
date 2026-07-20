# Stage 05 — Delivery Replan

## Inputs

- `../inputs/2026-07-20-delivery-replan-addendum.md` — Chris's accepted recovery and delivery direction
- `../01_spec/output/2026-07-18-shortbread-v1-prd.md` and GitHub #1 — unchanged product contract
- `../02_ticket_map/output/2026-07-18-ticket-map.md` and GitHub #2–#17 — original acceptance graph and issue history
- `../04_execution/` plus Git/GitHub branch, worktree, issue, and PR state — observed execution evidence
- `../../agents/mwp.md`, root `CONTEXT.md`, and accepted ADRs — ownership, domain, authority, and trust constraints

## Process

1. Preserve every recoverable implementation checkpoint before changing coordination state.
2. Retain #2–#17 as acceptance umbrellas and decompose their remaining scope into fresh-context delivery units.
3. Put the production runtime and credential-free provider contract on an early delivery spine without requesting credentials.
4. Build an explicit dependency graph from behavioral and edit-surface dependencies, not conceptual issue edges alone.
5. Map every PRD story and terminal criterion to integrated evidence or at least one delivery unit.
6. Challenge the graph for oversized units, hidden shared surfaces, setup/security/docs deferred to a final bucket, false parallelism, and units that cannot demonstrate actor-visible value.
7. Publish the reviewed units, make only the first leaf `ready-for-agent`, and convert the original executable issues into non-frontier acceptance umbrellas.

## Outputs

- `output/2026-07-20-delivery-plan.md` — canonical campaign and delivery-unit graph
- `output/UNIT-CONTRACT.md` — common fresh-context implementation/review/handoff contract
- `output/tracker.md` — local-unit to GitHub issue mapping, blocking edges, and frontier

## Verify

- The interrupted branch heads are remote-durable and named exactly.
- Every unit has one observable outcome, explicit blockers, public evidence seam, central edit warnings, risk/operations impact, and safe split rule.
- All 64 PRD stories and the credential-ready terminal condition remain covered.
- No pair is represented as parallel merely because its original umbrella issues were parallel.
- The root `RUN.md`, GitHub tracker, and local tracker agree on the one executable frontier and exact resume action.
- A fresh controller can begin the first campaign without reading the whole initiative corpus.

## Stop

Do not resume product implementation, recreate worktrees, merge either interrupted branch, request credentials, or mark the persistent goal complete during this stage. Stop if preservation fails, accepted product scope would need to change, or published tracker state cannot be reconciled safely.

## Promote

The reviewed graph supersedes the original ticket map for execution only. The PRD, ADRs, original ticket bodies, and their GitHub history remain product acceptance sources. Future work begins through one bounded campaign goal and the first leaf issue in `output/tracker.md`.
