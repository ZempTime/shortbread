---
name: fix-and-pr
description: Take a diagnosed bug through a regression test, minimal repair, repository checks, independent review, and controller integration. Use after diagnosing-bugs has produced a red-capable loop.
---

# Fix and PR

Carry one diagnosed bug from a confirmed hypothesis to a reviewed implementation handoff. The implementation agent does not approve its own work, merge, close the issue, or expand the governing contract.

## Preconditions

1. Read `AGENTS.md`, the active initiative `RUN.md`, the issue and agent brief, relevant PRD/ADRs, and repository standards.
2. Confirm the controller supplied a pinned baseline, isolated branch/worktree, allowed and forbidden edit surfaces, and the ticket-defined behavioral seam.
3. Confirm `diagnosing-bugs` produced a red-capable loop, minimal reproduction, and falsified alternatives. No red loop, no fix.
4. Inspect existing dirty changes and preserve work you do not own.

The active `RUN.md` is the authority boundary. Sensitive code receives enhanced review; it is not automatically outside agent authority. Report to the controller when the repair would change accepted behavior, cross an explicit stop, require an unapproved dependency or central edit surface, or exceed the assigned ticket.

## Repair loop

1. Turn the minimal reproduction into one failing regression at the ticket-defined public seam, following `tdd`.
2. Run it and retain the meaningful red result.
3. Apply the smallest coherent repair that satisfies the brief. Avoid drive-by refactors.
4. Run the focused regression to green, then rerun the original unminimized diagnostic loop.
5. Run the repository-defined targeted and full relevant test, lint, type, security, and build checks.
6. Commit the bounded change and open or update the assigned PR with the confirmed hypothesis, acceptance mapping, commands/results, compatibility or migration impact, and harvest result.

If the diagnosis exposes architectural friction, record a bounded follow-up for `improve-codebase-architecture`; do not widen the bug fix.

## Review and integration

Hand the fixed baseline/head SHAs and evidence to `code-review` for independent Standards and Spec reviews. Add independent security/operations review when the changed surface involves authentication, authorization, sessions, deletion, data integrity, secrets, providers, or deployment.

Blocking findings return through the same regression-first repair loop and require relevant rereview. The controller alone resolves findings, performs final verification, integrates the PR, updates tracker/run state, and closes the issue.
