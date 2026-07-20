# Ticket #3 Run

| Field | Value |
|---|---|
| Issue | `ZempTime/shortbread#3` / local ticket `T02` |
| Branch | `ticket-3-releases-rollback` |
| Product baseline | `f2e03262a0da76e30ff105a51b775055dba5037e` (merged ticket #2) |
| Worktree | `/private/tmp/shortbread-ticket-3` |
| Owner | `ZempTime` |
| Current phase | Behavioral TDD implementation |
| State | Claimed; bounded workspace seeded; no implementation checkpoint yet |

## Inputs

- root `AGENTS.md`, `CONTEXT.md`, and active initiative `RUN.md`
- canonical PRD user stories 11, 36, 40, 41 and publishing/testing decisions
- canonical T02 ticket and ADR 0003
- integrated T01 publishing, Manifest Entry, Blob, Release, CLI, and private-serving seams
- repo-local `implement` and `tdd` skills

## Owned outcome

Repeated `shortbread publish` calls produce immutable numbered Releases, deterministically reuse unchanged Blobs, atomically advance one Site current pointer, expose history, and roll back by pointer change without rewriting historical content.

This ticket owns Release/Manifest/publish-plan/current-pointer data and services, Release list/rollback API and Owner UI, corresponding CLI commands and stable JSON, content-hash ETags, and data-integrity/concurrency evidence.

## Boundaries

- Dependency manifests, lockfiles, tool pins, and dependency-policy digests are controller-only and frozen.
- Do not implement R2, full multi-page serving, Owner authentication, People/Shelf management, offline copies, feedback, receipts, deletion, or deployment.
- Coordinate before editing shared API authentication/base-controller or CLI server/profile transport surfaces owned by parallel ticket #4.
- Historical Releases and Manifest Entries never mutate. Rollback changes only the current pointer and records a precise result.
- Finalize must remain transactional/idempotent, reject incomplete/inconsistent uploads, and never expose a half-visible Release.

## Behavioral loop

Start with black-box/request failures for a second publish, unchanged reuse, changed/removed paths, retry/interruption, history, rollback, conditional serving, and concurrent finalize/current-pointer behavior. Use pure units only for canonical Manifest hashing/delta logic. Preserve the existing real CLI and Rails boundaries rather than introducing a parallel implementation seam.

## Verification and promotion

- focused red/green evidence for every acceptance promise;
- full Rails and Go suites, race/concurrency checks, lint/type/security/license/build gates, and the walking skeleton;
- independent Standards + Spec + data-integrity review on a fixed SHA;
- detached clean-checkout verification, named findings/dispositions, scope residuals, and harvest decision;
- controller-owned PR integration only after all blockers and should-fixes are repaired.
