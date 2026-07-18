# Stage 02 — Autonomous Ticket Map

## Inputs

- `../01_spec/output/2026-07-18-shortbread-v1-prd.md`
- `../01_spec/output/tracker.md`
- the `to-tickets` factory skill
- the authority envelope in `../RUN.md`

## Process

Create vertical tracer-bullet tickets with explicit parent and blocking edges. The first ticket must establish the approved dependency baseline and produce a running publish → invite → view path, even if it contains the minimum application and CLI scaffolding required to do so. Its bootstrap commit resolves lockfiles, records the open-source audit, and freezes dependency surfaces before later work fans out. Later tickets deepen behavior and may run in parallel only when their blockers are satisfied.

Each ticket declares observable acceptance, required testing seams, evidence, documentation impact, security/privacy checks, and a factory-harvest prompt. Include explicit slices for the setup/deployment path, open-source packaging, example bundle, screenshots, clean-room rehearsal, and final release verification.

Chris has delegated ticket granularity and publication approval to the top-level controller. The controller must independently review the graph for missing scope, false parallelism, and oversized slices before publishing it; no further human approval is required inside the accepted PRD.

## Outputs

- `output/2026-07-18-ticket-map.md`
- `output/tracker.md` containing every child issue number, URL, and dependency

## Verify

- Every PRD user story is owned by at least one ticket and traceable in a coverage table.
- Every ticket can be completed in one focused implementation context or explicitly contains a controller checkpoint for safe splitting.
- The dependency graph has an unambiguous frontier and exposes useful parallel work.
- No ticket is a pure infrastructure layer with no runnable user-visible tracer.
- Published issue bodies match the local map and carry `ready-for-agent` only when unblocked; blocked tickets state their edges without falsely entering the frontier.

## Stop

Stop only if the graph reveals a contradiction in the accepted PRD. Do not stop for routine granularity choices; the controller owns them.

## Promote

Pass the reviewed graph and tracker references to Stage 03 and the persistent goal.
