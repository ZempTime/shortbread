# Stage 03 — Persistent Goal Handoff

## Inputs

- `../RUN.md`
- `../01_spec/output/2026-07-18-shortbread-v1-prd.md`
- `../01_spec/output/tracker.md`
- `../02_ticket_map/output/2026-07-18-ticket-map.md`
- `../02_ticket_map/output/tracker.md`
- `/agents/README.md` and the controller factory skills

## Process

Produce one self-contained, copy-paste goal that directs a top-level controller to ship Shortbread v1. It must reference canonical artifacts instead of duplicating them, grant the exact safe authority in `RUN.md`, define delegation and parallelism, identify evidence and repair loops, explain credential handling, require continuous state updates and harvest, and state the terminal condition. Record the front-loaded dependency baseline as a named controller input.

Also create a controller runbook that a fresh session can execute without reconstructing this conversation. Then use the handoff skill to write a redacted temporary handoff outside the repository.

## Outputs

- `output/GOAL.md` — copy-paste persistent goal
- `output/controller-runbook.md` — execution loop and recovery rules
- `output/dependency-baseline.md` — reviewed starting kit and post-bootstrap freeze rule
- `output/handoff.md` — lifecycle note for the non-durable convenience handoff
- an OS-temporary redacted handoff file whose path is returned directly to the user, not committed as durable state

## Verify

- The goal authorizes routine approvals but preserves the destructive/trust boundary.
- The controller can resume from `RUN.md` plus GitHub state after interruption.
- Parallel agents cannot claim the same ticket or merge unreviewed changes.
- The run cannot claim completion without clean-clone, app, CLI, documentation, screenshot, packaging, and credential-bound deployment evidence.
- The dependency baseline is concrete about reviewed pins versus bootstrap-resolved choices and is controller-exclusive after freeze.
- The handoff contains no secrets and does not duplicate the PRD or ticket bodies.

## Stop

Do not launch implementation as part of setup. Stop after the goal is ready, validated, and handed back for the user's `/goal` invocation.

## Promote

The user launches `output/GOAL.md` as the persistent goal. The controller then owns execution to the terminal condition or a genuine `RUN.md` stop.
