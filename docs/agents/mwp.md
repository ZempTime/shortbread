# Model Workspace Protocol (MWP)

MWP is Shortbread's repo-local Model Workspace Protocol for agent work that must survive context changes, parallel execution, and human inspection. It adds only the process needed to turn a bounded input into verified output; it is not an application architecture or a substitute for tests.

MWP distinguishes a long-lived **initiative** from a bounded **campaign** and one PR-sized **delivery unit**. An initiative may span many fresh controller contexts. A campaign normally integrates one to four leaf units and then completes or emits a pause capsule; continuity is not permission to give one model goal an entire product.

## Ownership

| Surface | Owns |
|---|---|
| GitHub issue | Cross-session intent, acceptance, blockers, assignment, and status |
| Pull request | One live reviewable implementation attempt, fixed heads, checks, and dispositions |
| Initiative workspace | Inputs, decisions, stage contracts, harnesses, evidence, review, and handoff |
| `RUN.md` | Authoritative live state, authority, frontier, stops, and promotion history |
| Code and executable tests | Implemented behavior |
| `agents/` | Reusable execution factory |

No single surface replaces another, but they must share stable work/unit identifiers and freshness metadata. A branch, merge, label, or folder cannot prove that a cognitive stage ran; the `RUN.md` and its linked evidence must say so without copying every detail from the owning surface.

## Workspace shape

A bounded workspace normally contains:

```text
README.md        why this workspace exists and where to start
RUN.md           authority, inputs, current stage, evidence, stops
inputs/          immutable or explicitly human-owned source material
NN_stage/        only stages justified by the work
  CONTEXT.md     the stage contract
  output/        durable results when needed
```

Do not scaffold all possible stages. Add one when it has a distinct cognitive job and a useful review boundary.

## Stage contract

Every stage contract names:

- **Inputs** — the exact, scoped material the stage may rely on;
- **Process** — one transformation or decision job;
- **Outputs** — named edit surfaces, not vague deliverables;
- **Verify** — observable evidence that the job succeeded;
- **Stop** — conditions that prevent safe promotion;
- **Promote** — where accepted results go next.

Plain Markdown is preferred. Introduce a script, test fixture, browser capture, fake provider, or other harness only when it makes the uncertain seam executable and repeatable.

## Controller loop

1. Rehydrate from `AGENTS.md`, the active `RUN.md` resume capsule, campaign tracker, active unit contract, and only the PRD/ADR excerpts relevant to that unit. Read the full corpus when reconciling scope or terminal coverage, not by default on every worker/reviewer reset.
2. Reconcile local/remote heads, dirty state, PR/check/review target, assignments, worktrees, locks, and stale projections before assigning work.
3. Select only unblocked leaf units. Give each implementation agent an isolated branch/worktree, fixed baseline, one behavioral outcome, evidence contract, and explicit central edit reservations.
4. Open a draft PR at the first green checkpoint and push every meaningful green checkpoint. Record local and remote durability separately.
5. Serialize shared schema, dependency manifests/lockfiles, central routing, CLI registration, generated assets, release/deployment state, and root docs unless a concrete file/module reservation proves independence.
6. Require TDD at the agreed behavioral seam, regular targeted checks, and the full relevant suite at the fixed review candidate and proportionately before integration.
7. Run one author-independent Standards/Spec review for an ordinary bounded diff; add independent security/data/operations/supply-chain specialists for the named risk. The controller resolves findings and alone decides integration.
8. Link one durable evidence/PR record from `RUN.md` and GitHub, close the leaf, update its acceptance umbrella, recompute the frontier, and record a harvest decision.

Subagents report uncertainty and failure to the controller. The controller monitors, interrupts, reassigns, or splits work as needed and keeps state durable enough for a fresh session to resume.

## Fit and pause

A delivery unit must fit one fresh implementation context and one fresh review context. If it grows across multiple actor outcomes, undeclared shared hotspots, or an incoherent diff, stop at a remotely durable green checkpoint and split by observable behavior. Line/file counts are warning signals rather than acceptance criteria.

A pause is a successful protocol transition, not completion. Its capsule records:

- initiative, campaign, unit, state, controller/worker, and reconciliation time;
- integration baseline, local branch/SHA/dirty state, remote branch/SHA/PR, and fixed review verdict;
- blockers, reserved surfaces, current authority/true stop, one exact next action, and evidence links.

Temporary worktree paths are convenience state. A resume cannot depend on them existing.

## Approval model

An initiative's `RUN.md` defines its authority envelope. When it grants autonomous execution, starting the goal is the operator's approval of the canonical PRD, initial ticket graph, and actions inside that envelope. The controller may approve routine subordinate output and reversible implementation decisions without returning to the operator.

Authority is still bounded. Missing credentials are inputs; they are not invitations to bypass security. Changes to fixed product invariants, paid commitments, destructive production actions, new external processors, or authority outside the named repository/resources remain stop conditions unless the `RUN.md` explicitly says otherwise.

## Evidence and completion

Evidence should be reproducible and proportionate to risk: commands and results, behavioral tests, screenshots from the real app, provider command contracts, review findings and repairs, links to commits/PRs, and a clean-room rehearsal. Keep one canonical evidence record or CI artifact per fixed checkpoint; other surfaces link and summarize rather than copying SHAs/test counts into competing prose. A controller reports completion only when the unit/campaign/initiative terminal criteria are observed. Nearing a context, time, or token budget triggers a pause capsule, never a false completion.

## Factory harvest

Harvest is mandatory as a decision, not as churn. For each completed run:

1. identify a recurring correction or a harness/process pattern that materially helped;
2. state why it generalizes beyond Shortbread;
3. make the narrowest factory change and validate it; or
4. record `No reusable harvest`.

Never promote credentials, private data, transcripts, temporary exhaust, or one-off product choices into the factory.
