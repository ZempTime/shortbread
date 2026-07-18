---
name: code-review
description: Review a fixed implementation diff independently for repository standards and originating specification. Use before integration and after every blocking repair.
---

# Code Review

Run two read-only reviews in parallel from the same fixed point. Review is evidence for repair and integration, not a substitute for tests.

## Fix the review target

The controller supplies the ticket, PRD/ADRs, baseline SHA or merge-base, head SHA, and verification evidence. Refuse an ambiguous moving target. Review only the diff and relevant context; do not edit the implementation branch.

## Parallel axes

Spawn two independent review agents:

### Standards review

Read repository guidance and inspect whether the diff:

- follows documented domain language, architecture, module boundaries, style, test, security, privacy, and dependency rules;
- hides implementation behind coherent public seams;
- handles errors, cleanup, concurrency, migrations, and compatibility safely;
- contains unrelated churn, secrets/private data, proprietary assets, stale generated output, or undocumented operational impact;
- has proportionate tests and durable evidence.

### Spec review

Read the parent PRD, ticket, ADRs, and acceptance mapping. Inspect whether the diff:

- implements every stated behavior and failure/recovery case;
- preserves explicit out-of-scope boundaries and trust promises;
- proves behavior at the required browser/request/black-box/unit/provider seam;
- updates required docs, screenshots, setup, CLI/API contracts, and evidence;
- introduces behavior or dependencies the specification did not authorize.

For auth, sessions, authorization, deletion, data integrity, secrets, infrastructure, or deployment, the controller also assigns an independent security/operations review. It may run alongside the two axes.

## Finding format

Return findings first, ordered by consequence:

- `BLOCKER` — correctness, security, privacy, data loss, missing acceptance, failing evidence, or documented-standard violation that prevents integration;
- `SHOULD FIX` — concrete maintainability/operability defect whose cost is material;
- `NOTE` — non-blocking observation or follow-up outside the ticket.

Each finding names the file/line or exact evidence, expected behavior/rule, consequence, and smallest useful repair direction. Do not invent a problem to fill a category. If no findings exist, state that explicitly and name residual risks or tests not run.

## Reconcile

The controller combines both reports without voting them away. Every blocker is fixed or rejected with concrete contradictory evidence. Repairs rerun targeted/full checks and both relevant review axes. The implementation author cannot be the sole approving reviewer.

Record review agent identities, fixed SHAs, findings, dispositions, rerun evidence, and final controller integration decision in the PR/workspace.
