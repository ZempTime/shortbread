---
name: code-review
description: Review a fixed implementation diff independently for repository standards and originating specification. Use before integration and after every blocking repair.
---

# Code Review

Review both Standards and Spec axes read-only from the same fixed point. Review is evidence for repair and integration, not a substitute for tests.

## Fix the review target

The controller supplies the ticket, PRD/ADRs, baseline SHA or merge-base, head SHA, and verification evidence. Refuse an ambiguous moving target. Review only the diff and relevant context; do not edit the implementation branch.

## Review topology

For an ordinary bounded leaf, one reviewer independent of the implementation author may cover both axes in one pass. A controller may use two reviewers when the diff is unusually broad or independent challenge is valuable. Auth, sessions, authorization, deletion, data integrity, secrets, infrastructure, deployment, release, and final-composition work requires the named independent specialist in addition to the general review.

Reviewers do not recursively delegate. A reviewer who authors a repair loses approval eligibility for the repaired head.

## Axes

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

The specialist review may run alongside the general axes on the same fixed target.

## Finding format

Return findings first, ordered by consequence:

- `BLOCKER` — correctness, security, privacy, data loss, missing acceptance, failing evidence, or documented-standard violation that prevents integration;
- `SHOULD FIX` — concrete maintainability/operability defect whose cost is material;
- `NOTE` — non-blocking observation or follow-up outside the ticket.

Each finding names the file/line or exact evidence, expected behavior/rule, consequence, and smallest useful repair direction. Do not invent a problem to fill a category. If no findings exist, state that explicitly and name residual risks or tests not run.

## Reconcile

The controller combines all axes without voting blockers away. Every blocker is fixed or rejected with concrete contradictory evidence. Repairs rerun targeted checks, the full suite when the repair changes full-suite risk, and only the affected review axes unless the target's whole risk surface changed. The implementation author cannot approve their own work.

Record reviewer identities/eligibility, fixed SHAs, findings, dispositions, rerun evidence, residual risks, and final controller integration decision in one PR/evidence record. Other documents link to it instead of copying the same counts and SHAs.
