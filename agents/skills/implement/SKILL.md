---
name: implement
description: Deliver one unblocked ticket through a bounded MWP workspace, behavioral TDD, verification, review handoff, and harvest proposal. Use only after the controller claims a frontier ticket.
---

# Implement

Ship one ticket from a pinned baseline. The implementation agent does not coordinate the overall goal, approve its own review, merge, or change the dependency baseline.

## Claim and bound

1. Read `AGENTS.md`, `docs/agents/mwp.md`, the active root `RUN.md`, ticket/parent PRD, glossary, relevant ADRs, and documented standards.
2. Confirm blockers are closed and the controller assigned one issue, branch/worktree, baseline SHA, and allowed/forbidden edit surfaces.
3. Inspect existing dirty changes before editing. Never overwrite user or another agent's work.
4. If the slice crosses sessions, has multiple substantive transformations, or needs durable evidence, create the smallest issue-scoped workspace. Otherwise the issue, failing test, branch, PR, and evidence comment are sufficient.
5. Treat dependency manifests, lockfiles, schema, central routing, root `RUN.md`, root docs, screenshots, release config, and `agents/` as controller-exclusive unless the assignment explicitly grants one of them.
6. Record both the local and remote baseline/head. A temporary worktree path is never the recovery source.

## Behavioral TDD

Use the pre-agreed public seam from the ticket:

1. write one failing browser, request, black-box CLI, provider-contract, or deterministic unit test that expresses observable behavior;
2. run it and retain the meaningful red result;
3. make the smallest coherent implementation pass;
4. run the focused test to green;
5. refactor only with green evidence;
6. repeat one behavior at a time.

Do not mock code you own when a real boundary is affordable. Avoid tests coupled to private class structure. For security/failure behavior, prove fail-closed outcomes, redaction, idempotency, and recovery—not merely happy paths.

## Work loop

- Search before inventing a new pattern; use existing deep module/public seams.
- Run targeted tests, lint, and type checks regularly rather than batching surprises.
- Keep commits reviewable and scoped. Open a draft PR at the first green checkpoint and push every meaningful green checkpoint. Never force-push or rewrite shared history.
- If the work crosses an undeclared shared hotspot or no longer fits one fresh implementation/review context, stop at a remotely durable green checkpoint and ask the controller to apply the ticket's safe split rule.
- If accepted behavior requires a new dependency, stop that edit and send the controller an exception proposal using ADR 0007; continue independent work if possible.
- If evidence contradicts a permanent PRD/ADR/trust boundary, report it to the controller. Reversible design uncertainty belongs to the implementation agent and controller, not the operator.

## Handoff

Before declaring the implementation ready for review:

- run the full relevant test, lint, type, security, and build suite at the fixed review candidate;
- map acceptance criteria to tests/evidence;
- record commands/results and screenshots from the real app when relevant;
- explain security/privacy, migrations/data, setup/docs, and compatibility impact;
- commit the bounded change and provide the fixed baseline/diff;
- propose one reusable factory lesson with evidence or state `No reusable harvest`.

Open/update the PR and issue as authorized, then hand off to `code-review`. Do not merge or close the issue. Blocking review findings return through this same test-first repair loop and require rereview.

If the turn must pause before review, provide the MWP capsule: unit, baseline, local/remote heads, dirty state, draft PR/check state, reserved surfaces, next failing/green seam, and one exact continuation action.
