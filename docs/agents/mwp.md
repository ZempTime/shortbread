# Model Workspace Protocol (MWP)

MWP is Shortbread's repo-local Model Workspace Protocol for agent work that must survive context changes, parallel execution, and human inspection. It adds only the process needed to turn a bounded input into verified output; it is not an application architecture or a substitute for tests.

## Ownership

| Surface | Owns |
|---|---|
| GitHub issue | Cross-session intent, acceptance, blockers, assignment, and status |
| Pull request | One reviewable implementation attempt and its checks |
| Initiative workspace | Inputs, decisions, stage contracts, harnesses, evidence, review, and handoff |
| `RUN.md` | Authoritative live state, authority, frontier, stops, and promotion history |
| Code and executable tests | Implemented behavior |
| `agents/` | Reusable execution factory |

No single surface replaces another. In particular, a branch, merge, label, or folder cannot prove that a cognitive stage ran; the `RUN.md` and its evidence must say so.

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

1. Rehydrate from `AGENTS.md`, the active `RUN.md`, the canonical PRD/ADRs, and tracker state.
2. Reconcile stale or conflicting state before assigning work.
3. Select only unblocked frontier tickets. Give each implementation agent an isolated branch/worktree and a bounded contract.
4. Serialize shared schema, dependency manifests/lockfiles, central routing, and release-state edits; parallelize genuinely independent work. Only the controller edits dependency surfaces after the approved bootstrap.
5. Require TDD at the agreed behavioral seam, regular targeted checks, then the full relevant suite.
6. Run independent Standards and Spec reviews. The controller resolves findings, reruns evidence, and alone decides integration.
7. Persist the result in `RUN.md` and GitHub, close the completed edge, and recompute the frontier.
8. Record a harvest decision. Promote only reusable, evidenced process knowledge to `agents/`; keep product knowledge with the product.

Subagents report uncertainty and failure to the controller. The controller monitors, interrupts, reassigns, or splits work as needed and keeps state durable enough for a fresh session to resume.

## Approval model

An initiative's `RUN.md` defines its authority envelope. When it grants autonomous execution, starting the goal is the operator's approval of the canonical PRD, initial ticket graph, and actions inside that envelope. The controller may approve routine subordinate output and reversible implementation decisions without returning to the operator.

Authority is still bounded. Missing credentials are inputs; they are not invitations to bypass security. Changes to fixed product invariants, paid commitments, destructive production actions, new external processors, or authority outside the named repository/resources remain stop conditions unless the `RUN.md` explicitly says otherwise.

## Evidence and completion

Evidence should be reproducible and proportionate to risk: commands and results, behavioral tests, screenshots from the real app, provider command contracts, review findings and repairs, links to commits/PRs, and a clean-room rehearsal. A controller reports completion only when the goal's terminal criteria are observed; nearing a context or token limit is never completion.

## Factory harvest

Harvest is mandatory as a decision, not as churn. For each completed run:

1. identify a recurring correction or a harness/process pattern that materially helped;
2. state why it generalizes beyond Shortbread;
3. make the narrowest factory change and validate it; or
4. record `No reusable harvest`.

Never promote credentials, private data, transcripts, temporary exhaust, or one-off product choices into the factory.
