# Shortbread v1 Controller Runbook

This is the recovery-oriented operating procedure for the fresh session that launches [`GOAL.md`](GOAL.md). Product behavior stays in the canonical PRD/tickets; this file explains how to keep execution coherent.

## 1. Startup and rehydration

1. Read the goal's ordered artifact list and invoke `agents/skills/ship-goal`.
2. Inspect `git status`, current branch/commit, remotes, worktrees, open issues/PRs/checks, and current assignments.
3. Reconcile contradictions in this order: accepted PRD/ADRs for intent, code/tests for implemented behavior, issue/PR for cross-session lifecycle, root `RUN.md` for controller state, per-slice evidence for stage completion.
4. Do not destroy or overwrite unknown changes. Identify ownership, isolate them, or record the collision.
5. Confirm the authority envelope and stop conditions before external mutations.

## 2. Durable controller state

Only the controller edits the root initiative `RUN.md`. Record durable transitions, not every keystroke:

- execution start/resume and current controller;
- dependency baseline frozen;
- frontier set and claimed issue/worktree mapping;
- integration of a ticket and any semantic effect on dependents;
- a genuine blocker and exact missing input/authority;
- clean-room/final verification start/result;
- terminal evidence and credential-only remainder.

GitHub owns detailed issue/PR status. Per-ticket workspaces own reasoning/harness/evidence. Avoid mirroring all tracker fields into `RUN.md`.

## 3. Dependency bootstrap

Issue #2 is the only initial frontier. Before parallel implementation:

1. scaffold the application/CLI in its isolated worktree from Rails defaults and the checked-in reviewed dependency baseline; a local template may be consulted as optional generic prior art, but the run must not require sibling-repository access;
2. adopt the exact approved dependency groups, excluding telemetry/product-specific packages;
3. resolve Ruby/JavaScript/Go lockfiles and add executable mise tasks;
4. audit direct/transitive license, vulnerability, maintenance, install/build script, and proprietary-service coupling;
5. test the clean tool/bootstrap path;
6. commit the baseline checkpoint and set controller locks on manifests, lockfiles, `mise.toml`, package-manager config, schema, root routes/state, and `agents/`;
7. continue #2 until the full publish → invite → view tracer passes. Scaffolding alone is not promotable.

After freeze, a worker sends a dependency exception proposal to the controller. The controller applies ADR 0007 and uses an isolated dependency commit only when the accepted behavior cannot be met safely with the standard library/current kit.

## 4. Frontier scheduling

Recompute from open issues whose textual/native blockers are closed and which are unassigned. The planned order/frontier lives in the ticket map; evidence may justify splitting or adding an edge, but never dropping PRD coverage.

For each assignment record:

- issue, PRD stories/ADRs, baseline SHA;
- branch/worktree path and agent identity;
- allowed/forbidden/central edit surfaces;
- public test seam and red evidence expected;
- exact verification and documentation/security/harvest requirements;
- completion handoff format.

Reserve one agent/thread slot for the controller. Parallelize independent work; serialize hidden interface hotspots. Leaf agents do not spawn more agents.

## 5. Monitor and redirect

Poll active agents often enough to prevent long silent drift. Compare intermediate work to acceptance/evidence, not prose confidence. Send corrections at message/tool boundaries. Interrupt and replace an agent when it leaves scope, edits a locked surface, stops testing, or repeats a failure without new evidence.

If a ticket cannot fit one fresh context, split at a controller checkpoint into independently reviewable vertical outcomes, update blocker/coverage maps, and preserve the parent acceptance. Do not create horizontal “backend/frontend/tests” tickets.

## 6. Review and repair

When a worker hands off:

1. freeze baseline/head SHAs and independently inspect status/diff/evidence;
2. run Standards and Spec reviewers in parallel through `agents/skills/code-review`;
3. add security/operations review for sensitive surfaces;
4. reconcile findings; never dismiss a blocker by majority vote;
5. send blocking repairs through `agents/skills/implement` with a failing/regression seam;
6. rerun targeted/full checks and affected review axes.

After three materially identical unsuccessful repair cycles, use a fresh diagnosing/replanning agent or split the problem. Mark blocked only when the `RUN.md` condition is genuinely outside controller authority.

## 7. Integrate and advance

The controller alone performs final verification and integration. Require:

- acceptance-to-evidence mapping complete;
- CI and full relevant local checks green;
- no blocking review/security/operations finding;
- dependency/secret/license/private-data checks clean;
- migrations/backward compatibility/recovery documented where relevant;
- docs/screenshots/examples updated through their harness;
- harvest candidate or `No reusable harvest` recorded.

Merge the one-ticket PR non-forcefully, update/close the issue with evidence, remove only safe run-created worktrees/merged branches, update durable state, assess dependent tickets for changed assumptions, and recompute the frontier.

## 8. Credential boundary

Do not interrupt implementation for provider values. Enter this section only after the full credential-free readiness rehearsal is green, then present one consolidated setup ceremony. The workflow must enumerate and validate, without echoing:

- GitHub repository/package permissions;
- Northflank account/project/region and least-privilege API credential;
- PlanetScale organization/database/branch/role and credential;
- Cloudflare account, R2 bucket API credential, zone/domain, and DNS permission;
- apex host, wildcard Site host, namespaced resource prefix, allowed plan choices, and any deployment-specific non-secret values.

Provider fakes/command contracts prove inventory, plan, apply, resume, doctor, and failures. Never adopt/delete unknown resources, upgrade plans, buy/transfer domains, or put production secrets in chat, agent prompts, Git, process arguments, captured tool output, mise, or repo fnox files.

The credential ingress is exact: the generated setup program is run directly by the Operator in an interactive terminal and reads secrets through no-echo stdin/provider-native browser auth or references values the Operator places directly in OS keychain/provider/GitHub secret stores. It retains them only in process memory long enough to write the target secret store and emits redacted status. Agents can run plan and consume redacted `doctor`/smoke results. If the active runtime cannot guarantee secrets stay outside model/tool logs, the controller must not execute live apply; terminal output gives one exact Operator-run command and truthfully calls the repository credential-ready.

## 9. Final composition

After all ticket edges close, run issue #17 as a holistic rehearsal from a fresh clone. Verify the PRD terminal checklist, not just individual ticket results. Commission independent final Standards, Spec, security/operations, open-source/private-content, and clean-room reviews.

The final controller evaluation records:

- ticket throughput and actual frontier/concurrency;
- review/repair counts and repeated failure classes;
- genuine human/credential interruptions;
- useful problem-specific harnesses;
- per-ticket harvest decisions and validated factory promotions;
- MWP/controller changes recommended for future projects.

Do not preserve chain-of-thought, raw transcripts, secrets, or noisy logs. Link concise reproducible evidence.

## 10. Recovery after interruption

A fresh controller repeats Startup, checks open assignments/PRs/worktrees, and either resumes a valid claimed ticket or reclaims it with an explicit tracker note. In-memory agent status is never authoritative. Never restart completed work merely because the prior conversation is unavailable.
