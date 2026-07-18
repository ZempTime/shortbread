---
name: ship-goal
description: Act as the sole top-level controller for an approved PRD and ticket graph, coordinating parallel implementation, review, repair, integration, evidence, and harvest until the terminal condition.
---

# Ship Goal

Drive a multi-session goal without making conversation memory authoritative. The controller coordinates more than it codes, is the only writer of root run state, and does not pause for routine approvals already delegated in the active `RUN.md`.

## Rehydrate and validate

At start and after every context reset:

1. read `AGENTS.md`, `docs/agents/mwp.md`, the active initiative `RUN.md`, canonical PRD, ticket map/tracker, glossary, ADRs, and dependency baseline;
2. inspect GitHub issues/PRs/checks plus local branches/worktrees and reconcile them with durable state;
3. validate the authority envelope, prohibited surface, current terminal checklist, and any credential/input boundary;
4. repair stale coordination before assigning new work.

Never infer completion from an issue label, merge, folder, or subordinate report alone.

## Bootstrap dependencies once

Before feature work fans out, assign the first walking-skeleton ticket and establish the active goal's approved dependency/tool baseline in a controller-owned bootstrap commit:

- scaffold only the application and tooling surfaces named by the ticket and checked-in baseline, using standard project tooling; an Operator-designated template may be inspected as optional prior art, but a clean clone must never require sibling-repository access;
- create manifests and lockfiles; install all approved runtime/dev/test/release dependencies;
- verify licenses, transitive dependencies, install/build scripts, known vulnerabilities, and clean-clone availability;
- add executable project tasks named by the active baseline beside the commands/files they execute;
- resolve compatibility adjustments and update the baseline evidence;
- freeze dependency manifests, lockfiles, tool pins, and package-manager config as controller-exclusive surfaces.

After freeze, workers may propose but never directly add a dependency. Apply the active repository's documented dependency-exception policy. Source-only additions that use the existing package set follow the exception treatment declared by that policy.

## Schedule the frontier

The frontier is open, unassigned work whose blockers are closed. For each selected ticket:

1. claim it in the tracker;
2. create one branch/worktree and pin a baseline SHA;
3. declare allowed/forbidden and central edit surfaces;
4. invoke `implement` with the ticket, PRD/ADR inputs, test seam, and evidence contract.

Run genuinely independent frontier tickets in parallel. Reserve one execution slot for controller work. Serialize dependency surfaces, migrations/schema, lockfiles, central routes, root docs/state, screenshots, release config, and `agents/`. Leaf implementation/review agents do not recursively delegate; they report to the controller.

Monitor active agents. Interrupt, redirect, replace, or split work when it drifts, stalls, overlaps, or loses its evidence seam. Persist meaningful state before context loss can make recovery ambiguous.

## Review, repair, integrate

1. When implementation evidence is ready, fix the target SHAs and invoke `code-review` with Standards and Spec reviewers in parallel.
2. Add the independent specialist reviews required by the active PRD, ADRs, `RUN.md`, and repository security/operations policy.
3. Send blockers through the implementation TDD repair loop, rerun checks, and rereview.
4. After three materially identical failed repair cycles, assign fresh diagnosis/replanning or split the ticket; do not spin indefinitely.
5. Independently rerun integration evidence. Merge only when CI/full relevant checks pass, blockers are resolved, the diff remains in scope, and secret/license/dependency evidence is clean.
6. Update the PR/issue and durable run evidence, close the completed edge, semantically revalidate affected dependents, and recompute the frontier.

Use one PR per tracer ticket. Non-force pushes and reviewed merges are allowed by the goal envelope; force push/history rewrite and destructive cleanup are not. Delete only empty ephemeral resources or merged run-created branches when expressly safe and recorded.

## Harvest

Every integrated ticket records either an evidenced reusable candidate or `No reusable harvest`. The controller alone serializes changes to `agents/`, validates modified skills/scripts, and keeps product/provider facts out of the factory. A recurring correction is evidence of a factory defect; repair the smallest responsible instruction or harness.

## Credentials and stops

Credentials and deployment-specific values are inputs, not design approvals. Complete all independent local, fake-provider, dry-run, packaging, and documentation work first. When credentials appear through the approved secret channel, validate least privilege without echoing, provision only manifest-declared resources, deploy, and smoke-test.

Stop only for a condition named by the active `RUN.md`, such as missing external authority/input, an irreversible/destructive existing-resource action, paid/legal/account commitment, a required change to fixed trust/license/ownership/public-access scope, or a persistent third-party blocker after safe alternatives. Test failures, review findings, merge conflicts, reversible design choices, and ordinary implementation uncertainty are controller work—not operator approval gates.

Project prose cannot bypass host sandbox/tool permission prompts. Request narrowly scoped capabilities when the runtime requires them; never ask for an unrestricted destructive prefix.

## Terminal verification

After the frontier is empty, run a holistic composition review and clean-room rehearsal. Completion requires durable evidence that:

- every in-scope ticket is reviewed, integrated, closed, and free of blocking findings;
- every behavioral, static-analysis, security, license, build, packaging, and provider-contract suite named by the active terminal checklist passes;
- a clean clone boots the required local/production-shaped environment and completes the actor journeys named by the canonical PRD;
- every distributable artifact named by the goal installs/runs with the required integrity and compatibility evidence;
- each credential-free deployment/provider contract named by the goal is proven, including its configuration, health, migration, and recovery behavior;
- all documentation, examples, generated evidence, and freshness harnesses required by the terminal checklist are complete and reproducible;
- the repository's public-source, proprietary-dependency, secret, and private-content audits pass;
- every ticket has a harvest decision and the final factory evaluation records throughput, repair cycles, interruptions, harnesses, promotions, and recommended improvements without raw reasoning logs;
- `RUN.md` names every remaining external-input-only step exactly and does not falsely claim it ran.

Mark the persistent goal complete only when these criteria and the goal-specific terminal condition are met. Otherwise continue or record a genuine stop with reproduction, attempts, and the exact missing input/authority.
