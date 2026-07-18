# Shortbread v1 Tracer-Ticket Map

**Parent:** [PRD issue #1](https://github.com/ZempTime/shortbread/issues/1)
**Controller approval:** Accepted 2026-07-18 under the authority envelope in `RUN.md` after independent graph and controller/factory audits. This approval replaces a further operator ticket-granularity gate.
**Canonical ticket bodies:** [`tickets/`](tickets/)

## Definition of done for every ticket

- Work from one claimed issue, isolated branch/worktree, pinned baseline, and bounded edit surfaces.
- Create only the MWP workspace/harness justified by the problem; never write root `RUN.md` from a worker.
- Deliver observable behavior through the ticket's browser/request/black-box CLI/unit/provider seam using red → green TDD.
- Run focused checks regularly and the full relevant test/lint/type/security/license/build suite before review.
- Receive independent Standards and Spec reviews; sensitive work also receives security/operations review. Repair blockers and rereview.
- Preserve glossary/ADRs, trust/redaction rules, open-source boundaries, setup/docs impact, and dependency freeze.
- Record reproducible commands/results, real screenshots where applicable, commit/PR links, and acceptance mapping.
- Propose an evidenced reusable factory improvement or record `No reusable harvest`.

## Graph

| ID | Ticket | Blocked by | Main evidence |
|---:|---|---|---|
| 01 | [Publish, invite, and view one private page locally](tickets/01-walking-skeleton.md) | — | Real Go binary → Rails API → private Viewer browser system test; dependency locks/audits |
| 02 | [Republish immutable Releases and roll back safely](tickets/02-releases-and-rollback.md) | 01 | Publish/finalize concurrency, history, rollback, current-pointer tests |
| 03 | [Secure the Owner and remote Producer control plane](tickets/03-owner-and-cli-auth.md) | 01 | Passkey bootstrap/recovery, deployed-server CLI login, token scope/revocation tests |
| 04 | [Manage People, Grants, Invitations, and the Shelf](tickets/04-people-grants-invitations-shelf.md) | 03 | Preview-safe Invitation and apex↔Site isolation journeys |
| 05 | [Store content-addressed Blobs in private R2](tickets/05-private-r2-blobs.md) | 02 | S3 contract harness, missing-only upload, finalize/idempotency/private-read tests |
| 06 | [Serve real static Bundles safely](tickets/06-safe-bundle-serving.md) | 04, 05 | Host/path/range/ETag/injection/isolation and hostile Bundle tests |
| 07 | [Keep a Site offline under Viewer control](tickets/07-offline-copies.md) | 04, 06 | Real browser keep/offline/update/failure/remove tests |
| 08 | [Collect Release- and path-anchored feedback](tickets/08-feedback.md) | 04, 06 | Viewer/Owner/CLI Comment ordering and anchoring tests |
| 09 | [Show Owner-only View Receipts](tickets/09-view-receipts.md) | 04, 06 | Receipt privacy/deduplication/request-classification tests |
| 10 | [Delete Sites and reclaim unshared Blobs truthfully](tickets/10-site-deletion.md) | 04, 05, 08, 09 | Retry/partial failure/shared-Blob/Comment/receipt/recovery tests |
| 11 | [Produce release-candidate application and CLI artifacts](tickets/11-release-artifacts.md) | 03, 05, 06 | Clean candidate image/binary builds, checksums, install and walking-skeleton smoke |
| 12 | [Provision the reference stack from credentials only](tickets/12-reference-provisioner.md) | 11, 13 | Command contracts, plan/apply/resume/doctor, clean-room dry run, optional live smoke |
| 13 | [Establish core security and trust controls](tickets/13-security-and-trust.md) | 03, 04, 05, 06 | Core threat/data-flow baseline, hostile suites, current dependency/container/log review |
| 14 | [Ship a public-source tour and repeatable screenshots](tickets/14-example-and-screenshots.md) | 07, 08, 09, 10 | Deterministic example publish/tour and screenshot freshness harness |
| 15 | [Make a clean clone understandable and operable](tickets/15-clean-clone-docs.md) | 12, 13, 14 | Independent clean-room guide rehearsal and command/link verification |
| 16 | [Rehearse release readiness and close the factory loop](tickets/16-release-readiness.md) | 10, 12, 13, 15 | Full composition report, artifacts, dry run/live boundary, controller evaluation/harvest |

## Runnable frontier

```text
01 -> {02, 03}
02 -> 05
03 -> 04
{04, 05} -> 06
06 -> {07, 08, 09, 11, 13}       (subject to each row's other blockers)
{05, 08, 09} -> 10               (04 is also explicit)
{11, 13} -> 12
{07, 08, 09, 10} -> 14
{12, 13, 14} -> 15
{10, 12, 13, 15} -> 16
```

- Initial frontier: **01 only**.
- After 01: **02 and 03** can run in parallel.
- After 02: **05**; after 03: **04**.
- After 04 + 05: **06** becomes eligible.
- After 06: **07, 08, 09, 11, and 13** become independently eligible subject to their other stated blockers and edit-surface locks.
- After 08 + 09 (and 04 + 05): **10**.
- After 11 + 13: **12**.
- After 07 + 08 + 09 + 10: **14**.
- After 12 + 13 + 14: **15**.
- After 10 + 12 + 13 + 15: **16**.

The controller serializes schema, dependency/lock, root routing/state/docs, release, screenshot, and `agents/` edits even when tracker edges permit conceptual parallelism.

## PRD coverage

| PRD stories | Primary ticket(s) |
|---|---|
| 1–3 Owner bootstrap/passkeys/recovery | 03 |
| 4–5 Site creation/control surface | 01, 02, 15 |
| 6–10 People/Grants/Invitations/revocation | 04 |
| 11 Release history/rollback | 02 |
| 12 Feedback | 08 |
| 13 View Receipts | 09 |
| 14 CLI/automation credentials | 03 |
| 15–16 deletion/cleanup | 10 |
| 17 UI/CLI parity | 03, 04, 08, 09, 10 |
| 18–23 Invitation/Shelf/handoff/passkey | 04 |
| 24 safe multi-page serving/downloads | 06 |
| 25 Comments | 08 |
| 26–30 Offline Copy/revocation | 07, 04 |
| 31 released binary | 11, 16 |
| 32–35 remote profiles/auth/CI | 03 |
| 36 management command surface | 01, 02, 03, 04, 08, 09, 10 |
| 37 validation | 01, 06 |
| 38–41 Manifest/delta/upload/finalize | 01, 02, 05, 06 |
| 42 feedback JSON | 08 |
| 43–45 JSON/compatibility/API | 03 |
| 46–49 clean local setup/dependency freeze | 01 |
| 50–57 credential-driven operations | 12, 15, 16 |
| 58 app/CLI release artifacts | 11, 16 |
| 59 README/open project | 15 |
| 60–61 public-source tour/screenshots | 14 |
| 62–63 inspectable process/harvest | 16 and every ticket |
| 64 threat/trust evidence | 13 core baseline, 16 holistic proof |

All 64 stories have an owner. Cross-cutting integration appears only where behavior crosses actors; no “miscellaneous” completion ticket absorbs unmapped scope.

## Controller review findings resolved

- **Dependency drift:** Ticket 01 now contains a controller-owned dependency bootstrap/audit checkpoint and freezes manifests before parallel work.
- **Remote CLI ambiguity:** Ticket 03 explicitly authenticates profiles against deployed Shortbread instances; Ticket 01 may use a bootstrap automation credential only for its first local tracer.
- **Unsafe self-approval:** every ticket requires independent Standards and Spec review; sensitive tickets add security/operations review.
- **Credential blocking:** Ticket 12 must finish plan/contract/clean-room proof without credentials; live smoke is an exact later input boundary.
- **Public demo ambiguity:** Ticket 14 publishes source and evidence, while hosted access remains invite-only.
- **Large first slice:** Ticket 01 has a mandatory checkpoint after dependency scaffold/locks/audit; the controller may split implementation assignments within its one tracer outcome, but it cannot promote horizontal scaffolding alone.
- **Deletion ordering:** Ticket 10 waits for feedback and receipts so its record-retention/deletion acceptance can be tested against real records.
- **Security proof timing:** Ticket 13 establishes and propagates the core baseline; Ticket 16 repeats the trust audit over all later product/provider/evidence surfaces before stable release.
