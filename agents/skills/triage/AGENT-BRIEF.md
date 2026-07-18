# Writing Agent Briefs

An agent brief is a durable coordination comment on a GitHub issue when it becomes executable. It summarizes one accepted slice for a fresh agent; it never replaces the canonical PRD, ADRs, active `RUN.md`, or executable behavior.

Use this precedence when sources differ:

1. the active `RUN.md` owns live authority, stage, and controller state;
2. the canonical PRD and accepted ADRs own product intent and invariants;
3. the issue and its latest agent brief own slice acceptance, blockers, assignment, and cross-session status;
4. code and executable tests own implemented behavior.

External requests begin as issues. A pull request carries an already-accepted issue through implementation and review; it is not a second request or specification surface.

## Principles

### Durable and traceable

Link the canonical contract rather than copying it. Describe actor-visible behavior and stable interfaces. Paths are appropriate when they define an allowed, forbidden, or controller-exclusive edit surface, but do not rely on brittle line numbers.

### Behavioral and bounded

State current and desired behavior, including failure/recovery cases. Separate acceptance from suggested implementation. Name what is explicitly out of scope so the agent cannot silently widen the slice.

### Executable

Every criterion must map to a behavioral seam and reproducible evidence. A brief is not `ready-for-agent` until its blockers are closed, the baseline is fixed, edit surfaces are safe, and the authority envelope covers the work.

### Security-aware

Carry the repository's privacy, security, data, credential, documentation, operations, and harvest requirements into the brief. Sensitive work names its required independent specialist review; it does not weaken the governing invariant.

## Template

```markdown
## Agent Brief

**Category:** bug / enhancement
**Summary:** one actor-visible outcome

### Canonical contract

- Parent PRD: issue/path
- Relevant ADRs: paths
- Active run: path
- Ticket/workspace: issue/path

### Current behavior and evidence

What happens now, including the failing or missing behavior and the evidence that establishes it.

### Desired behavior

What the actor observes after completion, including failure and recovery behavior.

### Dependencies and baseline

- Blocked by: issue numbers or `none`
- Baseline commit: immutable SHA
- Assignment/branch/worktree: controller-supplied claim

### Edit surfaces

- Allowed: semantic modules and paths this assignment may change
- Forbidden: unrelated or protected surfaces
- Controller-exclusive/central: manifests, lockfiles, schema, routes, root state, generated assets, release config, or factory surfaces that require an explicit lock

### Behavioral seam

- Public seam: browser / request / black-box CLI / provider contract / deterministic unit
- Red evidence: exact observable failure expected before implementation

### Acceptance criteria

- [ ] Specific observable behavior
- [ ] Failure/recovery behavior
- [ ] Compatibility and out-of-scope boundary preserved

### Verification and evidence

- Focused checks: exact commands or harness
- Full relevant checks: test/lint/type/security/license/build commands
- Required screenshots/artifacts: named outputs or `none`
- Review: Standards + Spec, plus required specialist review

### Security, privacy, and data

Threats, trust promises, secret/private-data handling, migrations, deletion, or recovery implications; write `none` only after checking.

### Documentation and operations

Required setup, API/CLI, user, deployment, recovery, compatibility, or troubleshooting updates; write `none` only after checking.

### Harvest

Propose one reusable, evidenced factory improvement or record `No reusable harvest`.

### Out of scope

- Adjacent behavior this issue must not add or change
```

## Readiness check

Before applying `ready-for-agent`, verify that the issue has one category, no open blocker, a fixed baseline, a controller-approved edit-surface assignment, testable acceptance, proportionate review, and authority inside the active `RUN.md`. Dependency-blocked children retain their category and explicit edges but no readiness-state label until they enter the frontier.
