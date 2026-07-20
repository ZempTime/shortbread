# Initiative: Shortbread v1

**Goal:** Prepare and then drive an autonomous, evidence-backed build of Shortbread v1: accepted product contract, issue graph, reusable agent factory, implementation controller, setup/deployment path, CLI, public documentation, and verified handoff.

**Why a workspace fits:** The work moves through bounded transformations whose inputs and evidence must remain inspectable. GitHub issues and pull requests coordinate work across sessions; this workspace owns the decisions, stage state, harness choices, evidence, and handoff. [`RUN.md`](RUN.md) is authoritative.

**Status:** Execution active. GitHub #2's dependency baseline is frozen, its publish/invite/private-view tracer is implemented, and fixed-SHA review is the current promotion gate. [`RUN.md`](RUN.md) owns the exact live checkpoint.

## Execution Model

1. Stage 00 reconciles the human framing into a traceable contract.
2. Stage 01 creates the canonical PRD and publishes its parent GitHub issue.
3. Stage 02 creates a dependency-aware tracer-ticket map and publishes it. Chris has delegated routine ticket approval to the controller.
4. Stage 03 packages the authority envelope, controller loop, terminal criteria, and exact goal handoff.
5. The persistent controller selects the unblocked frontier, creates the smallest justified slice workspace and harness, delegates independent work, applies TDD, reviews against standards and spec, repairs findings, records evidence, and advances.
6. Stage 99 harvests only demonstrated reusable learning into `agents/`; product facts stay in product artifacts.

The workspaces follow Shortbread's repo-local MWP method: one stage has one cognitive job, explicit inputs, named edit surfaces, verification, and a stop condition. See [`docs/agents/mwp.md`](../../agents/mwp.md).

## Input Lifecycle and Precedence

Files under `inputs/` are attributed, frozen historical sources. Their internal status lines, unchecked boxes, open questions, and superseded proposals describe the moment they were captured; they are not live gates or current product truth.

For current decisions, read the [reconciled framing contract](00_framing/output/2026-07-18-framing-contract.md), then the canonical [PRD](01_spec/output/2026-07-18-shortbread-v1-prd.md) and accepted [`docs/adr/`](../../adr/). [`RUN.md`](RUN.md) alone owns live execution state and authority. When a historical input conflicts with those promoted artifacts, the promoted artifact controls according to the framing contract's source order.

- [`inputs/request.md`](inputs/request.md) — original request and attribution
- [`inputs/design-notes.md`](inputs/design-notes.md) — initial architecture synthesis
- [`inputs/chris-framing.md`](inputs/chris-framing.md) — detailed human framing
- [`inputs/2026-07-18-goal-addendum.md`](inputs/2026-07-18-goal-addendum.md) — open-source, factory, deployment, evidence, and autonomy decisions

## Stage Contracts

- [`00_framing/CONTEXT.md`](00_framing/CONTEXT.md)
- [`01_spec/CONTEXT.md`](01_spec/CONTEXT.md)
- [`02_ticket_map/CONTEXT.md`](02_ticket_map/CONTEXT.md)
- [`03_goal_handoff/CONTEXT.md`](03_goal_handoff/CONTEXT.md)
- [`99_harvest/CONTEXT.md`](99_harvest/CONTEXT.md)

## Safety Boundary

The controller owns routine choices and approvals inside the accepted PRD. It stops for missing credentials or authority, irreversible changes to existing external state, or a needed change to the trust/scope contract—not for ordinary implementation uncertainty. See [`RUN.md`](RUN.md) for the exact envelope.
