# Persistent Goal: Ship Shortbread v1

> **Superseded for execution on 2026-07-20.** This whole-initiative Ultra goal is retained as historical evidence and must not be relaunched. Use the bounded campaign graph and fresh-context start packet in [`05_delivery_replan/output/2026-07-20-delivery-plan.md`](../../05_delivery_replan/output/2026-07-20-delivery-plan.md), with live state from the root [`RUN.md`](../../RUN.md).

**Recommended launch profile:** Start a fresh Codex/Work session in **Ultra** when available, then create a persistent `/goal` from the objective below. Ultra is recommended for the controller's parallel decomposition/review work; bounded workers need not all use Ultra.

## Copy-paste goal objective

Ship Shortbread v1 to the terminal condition defined in the canonical PRD and active initiative, leaving the public MIT repository fully implemented, reviewed, documented, packaged, and ready for an Operator to supply credentials/deployment values and execute the verified Northflank + PlanetScale Postgres + private Cloudflare R2 deployment path.

Act as the sole top-level controller and use the repo-local `$ship-goal` skill. Begin by reading, in order:

1. `AGENTS.md`;
2. `docs/agents/mwp.md`;
3. `docs/initiatives/2026-07-shortbread-v1/RUN.md`;
4. `CONTEXT.md` and accepted `docs/adr/*.md`;
5. `docs/initiatives/2026-07-shortbread-v1/01_spec/output/2026-07-18-shortbread-v1-prd.md` and GitHub PRD #1;
6. `docs/initiatives/2026-07-shortbread-v1/02_ticket_map/output/2026-07-18-ticket-map.md` plus its tracker and GitHub issues #2–#17;
7. `docs/initiatives/2026-07-shortbread-v1/03_goal_handoff/output/dependency-baseline.md`;
8. `docs/initiatives/2026-07-shortbread-v1/03_goal_handoff/output/controller-runbook.md`.

Starting this goal is the Operator's single approval of the canonical PRD, initial ticket graph, dependency baseline, and authority envelope in `RUN.md`. Do not ask the Operator for routine product, ticket, implementation, auth/session/deletion, review, merge, release, or in-scope deployment-preparation approvals already delegated there. You may approve/reject/revise subordinate-agent work, choose reversible implementation details, split or reorder in-scope tickets while preserving coverage/edges, and continue through tests, review findings, repairs, merge conflicts, and other ordinary uncertainty.

Coordinate more than you code. Rehydrate durable state at every session start; reconcile GitHub with local branches/worktrees and `RUN.md`; compute the unblocked frontier; claim tickets; give each independent implementation one isolated branch/worktree, pinned baseline, edit-surface lock, behavioral test seam, and evidence contract. Keep one controller slot available. Parallelize genuinely independent frontier work, but serialize dependency manifests/lockfiles/tool pins, migrations/schema, central routes, root state/docs, generated screenshots, release config, and `agents/`. Leaf agents report to you and do not recursively delegate.

The initial frontier is GitHub #2. Its first mandatory checkpoint front-loads the complete approved Rails/browser/Go/toolchain dependency kit, resolves and commits manifests/lockfiles, audits open-source licenses/security/build scripts, adds working mise tasks, and freezes dependency surfaces before work fans out. Thereafter only the controller may approve a documented ADR 0007 exception; small shadcn component source additions are allowed only when they use existing packages.

For every ticket, invoke the repo-local `$implement` workflow: smallest justified MWP workspace/harness, red → green behavioral TDD at the PRD seam, regular focused checks, full relevant suite, durable evidence, real screenshots where applicable, docs/operations/security impact, and an explicit factory harvest or `No reusable harvest`. Then invoke `$code-review` with independent Standards and Spec reviewers in parallel; add an independent security/operations reviewer for auth, sessions, authorization, deletion, data integrity, secrets, provider, or deployment work. Repair all blocking findings and rereview before integration. The implementation author cannot be the sole approver.

Use GitHub issues/PRs for cross-session coordination and the workspace for inputs, meaningful stage state, harnesses, evidence, and handoffs. Only the controller writes the root initiative `RUN.md` and shared factory surfaces. Persist meaningful transitions before context loss. Merge one reviewed PR per tracer ticket after CI/full checks are green, update/close its issue with evidence, recompute the frontier, and continue without returning for another approval.

Credentials and deployment-specific values are inputs, not design gates. Do not request them during implementation. Complete every local, fake-provider, command-contract, clean-room, packaging, screenshot, documentation, and final credential-free readiness check first; then present one consolidated end-of-goal credential setup ceremony. Never print, commit, pass to agents/chat, place in process arguments/captured tool output, or publish credentials, Invitation values, private Bundle content, or Viewer PII. Build a setup program the Operator runs directly: it accepts secrets only through no-echo interactive stdin, provider-native browser authentication, OS keychain, or direct provider/GitHub secret-store entry and emits redacted status. Agents may inspect plans and redacted `doctor` output. If the execution runtime cannot guarantee that live values stay out of model/tool logs, do not request or handle them; finish a credential-ready repository and leave the exact Operator-run apply/smoke command as the one named step.

Do not stop for test failures, review feedback, merge conflicts, reversible design uncertainty, or a worker failure. Diagnose, repair, replace/reassign, or split work. Stop only for a condition explicitly outside the `RUN.md` envelope: missing external authority/input after all independent work is complete; an irreversible/destructive action against existing external data/resources without proven recovery; a paid/legal/account/domain commitment; a required change to the trust contract, MIT/public ownership, single-Owner model, invite-only v1, reference-provider scope, or other accepted invariant; or a persistent third-party blocker after safe alternatives are exhausted. Never force-push/rewrite history, overwrite unrelated/user changes, weaken security to pass a check, contact real Viewers, add a proprietary dependency/service, or delete existing production resources.

Continue across sessions until the PRD's v1 terminal condition is evidenced. Completion requires all #2–#17 scope integrated/closed, no blocking reviews, all browser/request/black-box Go/unit/provider-contract and full lint/type/security/license/build suites green, clean-clone local and production-shaped rehearsals, remote-instance CLI authentication, installable app/CLI release artifacts with checksums/compatibility, credential-free idempotent deployment plan, complete setup/operations/backup-restore/deletion/security/contributing/API/CLI docs, a synthetic public-source tour, fresh real-app screenshots, proprietary/private-data audit, and a per-ticket plus final factory harvest/evaluation. Record terminal evidence and the exact remaining credential-only live step in `RUN.md`; then mark the persistent goal complete.

## Expected first action

Read/reconcile the listed artifacts and GitHub state, update `RUN.md` from `handoff-ready` to `execution-active`, claim issue #2, establish its branch/worktree and dependency-bootstrap checkpoint, and begin the walking skeleton. Do not re-interview the Operator or re-synthesize the PRD.
